/// AudioDownloadService — downloads pre-generated TTS audio files from S3.
///
/// ## Responsibilities
/// 1. Fetch pre-signed S3 URLs via [PlanApiService.getAudioUrls].
/// 2. Skip files already present in [TtsCacheTable] with their audio file on disk.
/// 3. Download up to [kMaxConcurrentDownloads] files concurrently.
/// 4. On HTTP 403 (expired pre-signed URL), re-fetch URLs and retry once.
/// 5. Persist each downloaded file to the TTS audio directory.
/// 6. Upsert a [TtsCacheTable] row for each downloaded file.
/// 7. Emit download progress as a broadcast [Stream].
library audio_download_service;

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/exceptions/app_exception.dart';
import 'package:instructor/models/audio_file_url.dart';
import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/services/api_client.dart';
import 'package:instructor/services/plan_api_service.dart';

part 'audio_download_service.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// Maximum number of concurrent audio file downloads.
const int kMaxConcurrentDownloads = 4;

/// HTTP timeout for each individual audio file download.
const Duration kAudioDownloadTimeout = Duration(seconds: 60);

/// Voice ID written to [TtsCacheTable] rows created by this service.
///
/// Pre-generated audio files are synthesised server-side by the Kokoro TTS
/// engine; the voice ID is embedded in the cache key rather than stored as a
/// separate column, so we use a well-known sentinel.
const String kGenAiVoiceId = 'genai';

/// TTS provider tag written to [TtsCacheTable] rows created by this service.
const String kGenAiProvider = 'kokoro';

// ─────────────────────────────────────────────────────────────────────────────
// Progress type
// ─────────────────────────────────────────────────────────────────────────────

/// Snapshot of download progress for a single [AudioDownloadService.downloadPlanAudio]
/// call.
///
/// [completed] — number of files that have been saved to disk.
/// [total] — total number of audio files expected for the plan.
typedef DownloadProgress = ({int completed, int total});

// ─────────────────────────────────────────────────────────────────────────────
// Exception
// ─────────────────────────────────────────────────────────────────────────────

/// Thrown when [AudioDownloadService] encounters an unrecoverable error.
final class AudioDownloadException implements Exception {
  const AudioDownloadException(this.message);

  final String message;

  @override
  String toString() => 'AudioDownloadException: $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class AudioDownloadService {
  /// Broadcast stream that emits a [DownloadProgress] record each time a file
  /// is saved to disk (or when the initial progress is computed).
  ///
  /// The stream never closes. Callers should cancel their subscription when
  /// the download they are tracking has finished.
  Stream<DownloadProgress> get downloadProgress;

  /// Downloads all TTS audio files for [planId] that are not yet cached.
  ///
  /// ## Steps
  /// 1. Calls [PlanApiService.getAudioUrls] to retrieve pre-signed S3 URLs.
  /// 2. Queries [TtsCacheTable] and skips files already on disk.
  /// 3. Downloads the remaining files with at most [kMaxConcurrentDownloads]
  ///    concurrent HTTP requests.
  /// 4. On HTTP 403, re-fetches the URL list and retries the download once.
  /// 5. Writes each file to the TTS audio directory and upserts a cache row.
  ///
  /// Progress is emitted on [downloadProgress] throughout the operation.
  ///
  /// Throws [AudioDownloadException] when one or more files could not be
  /// downloaded after retrying.
  Future<void> downloadPlanAudio(String planId);

  /// Returns `true` if every TTS audio file for [planId] is present in
  /// [TtsCacheTable] and exists on disk.
  ///
  /// Returns `false` on API errors or when no URLs are found.
  Future<bool> isFullyDownloaded(String planId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Production implementation
// ─────────────────────────────────────────────────────────────────────────────

class AudioDownloadServiceImpl implements AudioDownloadService {
  AudioDownloadServiceImpl({
    required AppDatabase db,
    required PlanApiService api,
    required String audioDirectory,
    http.Client? httpClient,
  })  : _db = db,
        _api = api,
        _audioDirectory = audioDirectory,
        _httpClient = httpClient ?? LoggingClient();

  final AppDatabase _db;
  final PlanApiService _api;
  final String _audioDirectory;
  final http.Client _httpClient;

  final _progressController =
      StreamController<DownloadProgress>.broadcast();

  @override
  Stream<DownloadProgress> get downloadProgress =>
      _progressController.stream;

  // ── Public methods ────────────────────────────────────────────────────────

  @override
  Future<void> downloadPlanAudio(String planId) async {
    // 1. Fetch pre-signed URLs from the API.
    final List<AudioFileUrl> allUrls;
    try {
      allUrls = await _api.getAudioUrls(planId);
    } catch (e) {
      throw AudioAppException(
          'Failed to fetch audio URLs for planId=$planId: $e');
    }

    if (allUrls.isEmpty) {
      debugPrint(
          'AudioDownloadService: no audio URLs for planId=$planId');
      return;
    }

    final total = allUrls.length;

    // 2. Determine which files are already cached (DB row + file on disk).
    final cachedKeys = await _getCachedKeys(
      allUrls.map((u) => u.cacheKey).toList(),
    );

    final toDownload = allUrls
        .where((u) => !cachedKeys.contains(u.cacheKey))
        .toList();

    // 3. Emit initial progress to inform subscribers of already-cached files.
    int completed = cachedKeys.length;
    _emitProgress(completed: completed, total: total);

    if (toDownload.isEmpty) {
      debugPrint(
          'AudioDownloadService: all $total files already cached for '
          'planId=$planId');
      return;
    }

    debugPrint(
        'AudioDownloadService: downloading ${toDownload.length} of $total '
        'files for planId=$planId');

    // 4. Download with bounded concurrency.
    final semaphore = _Semaphore(kMaxConcurrentDownloads);
    final errors = <Object>[];

    final futures = toDownload.map((audioUrl) async {
      await semaphore.acquire();
      try {
        await _downloadAndCache(audioUrl, planId);
        completed++;
        _emitProgress(completed: completed, total: total);
      } catch (e) {
        debugPrint(
            'AudioDownloadService: failed to download '
            '${audioUrl.cacheKey}: $e');
        errors.add(e);
      } finally {
        semaphore.release();
      }
    });

    // eagerError: false — continue downloading remaining files even on error.
    await Future.wait(futures, eagerError: false);

    if (errors.isNotEmpty) {
      throw AudioAppException(
          '${errors.length} file(s) failed to download for '
          'planId=$planId');
    }
  }

  @override
  Future<bool> isFullyDownloaded(String planId) async {
    final List<AudioFileUrl> urls;
    try {
      urls = await _api.getAudioUrls(planId);
    } catch (_) {
      return false;
    }

    if (urls.isEmpty) return false;

    final cachedKeys =
        await _getCachedKeys(urls.map((u) => u.cacheKey).toList());
    return cachedKeys.length == urls.length;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Downloads [audioUrl] and persists it locally.
  ///
  /// On HTTP 403 (expired pre-signed URL), re-fetches the URL list for
  /// [planId] and retries once.
  Future<void> _downloadAndCache(
      AudioFileUrl audioUrl, String planId) async {
    var response = await _fetchWithTimeout(audioUrl.url);

    // 403 = expired pre-signed URL — re-fetch and retry exactly once.
    if (response.statusCode == 403) {
      debugPrint(
          'AudioDownloadService: 403 for ${audioUrl.cacheKey}, '
          're-fetching URLs and retrying…');
      final refreshed = await _refreshUrl(audioUrl.cacheKey, planId);
      response = await _fetchWithTimeout(refreshed.url);
    }

    if (response.statusCode != 200) {
      throw AudioAppException(
          'HTTP ${response.statusCode} downloading ${audioUrl.cacheKey}');
    }

    // Persist audio bytes to disk.
    final filePath =
        p.join(_audioDirectory, '${audioUrl.cacheKey}.wav');
    await File(filePath).writeAsBytes(response.bodyBytes);

    // Upsert a TtsCacheTable row — INSERT OR REPLACE for idempotency.
    await _db.into(_db.ttsCacheTable).insert(
          TtsCacheTableCompanion.insert(
            textHash: audioUrl.cacheKey,
            voiceId: kGenAiVoiceId,
            filePath: filePath,
            fileSizeBytes: Value(response.bodyBytes.length),
            planId: Value(planId),
            provider: const Value(kGenAiProvider),
            speechRate: const Value('1.0'),
          ),
          mode: InsertMode.insertOrReplace,
        );

    debugPrint(
        'AudioDownloadService: cached ${response.bodyBytes.length} bytes '
        '→ $filePath');
  }

  /// GETs [url] with [kAudioDownloadTimeout].
  Future<http.Response> _fetchWithTimeout(String url) =>
      _httpClient.get(Uri.parse(url)).timeout(kAudioDownloadTimeout);

  /// Re-fetches the audio URL list for [planId] and returns the refreshed URL
  /// whose [AudioFileUrl.cacheKey] matches [cacheKey].
  ///
  /// Throws [AudioDownloadException] when the key is absent from the response
  /// (the file may have been removed from the server).
  Future<AudioFileUrl> _refreshUrl(
      String cacheKey, String planId) async {
    final List<AudioFileUrl> refreshed;
    try {
      refreshed = await _api.getAudioUrls(planId);
    } catch (e) {
      throw AudioAppException(
          'URL refresh failed for cacheKey=$cacheKey, planId=$planId: $e');
    }
    final match =
        refreshed.where((u) => u.cacheKey == cacheKey).firstOrNull;
    if (match == null) {
      throw AudioAppException(
          'cacheKey=$cacheKey not found after URL refresh for '
          'planId=$planId');
    }
    return match;
  }

  /// Returns the subset of [cacheKeys] that have a [TtsCacheTable] row **and**
  /// whose audio file exists on disk.
  ///
  /// Stale rows (DB row present but file missing) are left in place — a
  /// subsequent [downloadPlanAudio] call will overwrite them via
  /// [InsertMode.insertOrReplace].
  Future<Set<String>> _getCachedKeys(List<String> cacheKeys) async {
    if (cacheKeys.isEmpty) return {};

    final rows = await (_db.select(_db.ttsCacheTable)
          ..where((t) => t.textHash.isIn(cacheKeys)))
        .get();

    final result = <String>{};
    for (final row in rows) {
      if (await File(row.filePath).exists()) {
        result.add(row.textHash);
      }
    }
    return result;
  }

  void _emitProgress({required int completed, required int total}) {
    if (!_progressController.isClosed) {
      _progressController.add((completed: completed, total: total));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Semaphore — limits the number of concurrent async operations
// ─────────────────────────────────────────────────────────────────────────────

/// A simple counting semaphore backed by a [Completer] queue.
///
/// Callers [acquire] a permit before starting an operation and [release] it
/// when done. When all permits are taken, [acquire] suspends until another
/// caller releases.
class _Semaphore {
  _Semaphore(int maxPermits)
      : assert(maxPermits > 0, 'maxPermits must be > 0'),
        _available = maxPermits;

  int _available;
  final _waiters = <Completer<void>>[];

  /// Acquires one permit, suspending until one becomes available.
  Future<void> acquire() async {
    if (_available > 0) {
      _available--;
      return;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    await waiter.future;
  }

  /// Releases one permit, unblocking the longest-waiting [acquire] call.
  void release() {
    if (_waiters.isNotEmpty) {
      // Hand the permit directly to the next waiter.
      _waiters.removeAt(0).complete();
    } else {
      _available++;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Directory initialisation
// ─────────────────────────────────────────────────────────────────────────────

/// Absolute path to the TTS audio download directory.
///
/// Set by [initAudioDownloadDirectory] and injected into
/// [AudioDownloadServiceImpl] via the Riverpod provider.
String _audioDownloadDirectory = '';

/// Resolves and creates the TTS audio directory inside the app's documents
/// folder.
///
/// Must be called once from `main()` after
/// [WidgetsFlutterBinding.ensureInitialized]. Uses the same `tts_audio`
/// subdirectory as [MediaCacheService] so both services share the audio store.
Future<void> initAudioDownloadDirectory() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docsDir.path, 'tts_audio'));
  await dir.create(recursive: true);
  _audioDownloadDirectory = dir.path;
}

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ─────────────────────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
AudioDownloadService audioDownloadService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(planApiServiceProvider);
  return AudioDownloadServiceImpl(
    db: db,
    api: api,
    audioDirectory: _audioDownloadDirectory,
  );
}
