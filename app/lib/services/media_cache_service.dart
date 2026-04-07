/// MediaCacheService — parameter-aware TTS audio caching with L1 (disk) lookup.
///
/// ## Responsibilities
/// 1. Compute a deterministic cache key from all synthesis parameters
///    (text, voice, locale, provider, speechRate) that matches the server-side
///    format exactly.
/// 2. Check the local [TtsCacheTable] (L1 cache) before making any API call.
/// 3. On a cache miss, call the backend `/api/tts/synthesize` with all params.
/// 4. Persist the received audio to disk and insert a [TtsCacheTable] row.
/// 5. Expose [clearCache] to wipe all local cache entries and files.
///
/// ## Cache key format
/// Both client and server JSON-serialise the parameters with alphabetically
/// sorted keys, then SHA-256 hash the result. This guarantees that keys are
/// identical on both sides even across platforms.
library media_cache_service;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/database/tables/tts_cache_table.dart';
import 'package:instructor/services/api_client.dart';
import 'package:instructor/services/app_settings.dart';
import 'package:instructor/services/auth_service.dart';
import 'package:instructor/utils/hash_utils.dart';

part 'media_cache_service.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// Default locale sent to the backend when none is specified.
const String kDefaultLocale = 'en-IN';

/// Default provider when none is specified.
const String kDefaultTtsProvider = 'gemini';

/// HTTP timeout for synthesis requests.
const Duration kSynthesisTimeout = Duration(seconds: 60);

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class MediaCacheService {
  /// Returns a local [File] containing the synthesised audio for the given
  /// parameters.
  ///
  /// ## Resolution order
  /// 1. L1 cache hit — [TtsCacheTable] row with matching [computeCacheKey] and
  ///    file present on disk → return immediately.
  /// 2. L1 miss — call backend `/api/tts/synthesize`, write to disk, insert
  ///    cache row, return [File].
  ///
  /// Throws an [Exception] on API or I/O errors.
  Future<File> getOrFetchAudio({
    required String text,
    required String voice,
    required String locale,
    required String provider,
    required String speechRate,
  });

  /// Computes the cache key for a given set of synthesis parameters.
  ///
  /// The key is the SHA-256 hex digest of the JSON-serialised parameter map
  /// with alphabetically sorted keys. This must match the server-side
  /// `cacheKey()` function exactly.
  String computeCacheKey({
    required String text,
    required String voice,
    required String locale,
    required String provider,
    required String speechRate,
  });

  /// Saves audio [bytes] to disk and inserts (or ignores) a [TtsCacheTable]
  /// row for the given parameters.
  Future<File> saveToCache({
    required String text,
    required String voice,
    required String locale,
    required String provider,
    required String speechRate,
    required List<int> bytes,
    int? planId,
  });

  /// Deletes all cache entries and their associated audio files from disk.
  Future<void> clearCache();
}

// ─────────────────────────────────────────────────────────────────────────────
// Production implementation
// ─────────────────────────────────────────────────────────────────────────────

class MediaCacheServiceImpl implements MediaCacheService {
  MediaCacheServiceImpl({
    required AppDatabase db,
    required AppSettings settings,
    required String audioDirectory,
    AuthService? authService,
    http.Client? httpClient,
  })  : _db = db,
        _settings = settings,
        _audioDirectory = audioDirectory,
        _authService = authService,
        _httpClient = httpClient ?? LoggingClient();

  final AppDatabase _db;
  final AppSettings _settings;
  final String _audioDirectory;
  final AuthService? _authService;
  final http.Client _httpClient;

  @override
  String computeCacheKey({
    required String text,
    required String voice,
    required String locale,
    required String provider,
    required String speechRate,
  }) {
    return fullParamCacheKey(
      text: text,
      voice: voice,
      locale: locale,
      provider: provider,
      speechRate: speechRate,
    );
  }

  @override
  Future<File> getOrFetchAudio({
    required String text,
    required String voice,
    required String locale,
    required String provider,
    required String speechRate,
  }) async {
    final cacheKey = computeCacheKey(
      text: text,
      voice: voice,
      locale: locale,
      provider: provider,
      speechRate: speechRate,
    );

    // L1 — check local disk cache.
    final cached = await _findCachedFile(cacheKey);
    if (cached != null) {
      debugPrint(
          'MediaCacheService: L1 cache hit — key=${cacheKey.substring(0, 8)}…');
      return cached;
    }

    debugPrint(
        'MediaCacheService: cache miss — fetching from backend (provider=$provider)');

    // Call the backend TTS API.
    final bytes = await _synthesize(
      text: text,
      voice: voice,
      locale: locale,
      provider: provider,
      speechRate: speechRate,
    );

    return saveToCache(
      text: text,
      voice: voice,
      locale: locale,
      provider: provider,
      speechRate: speechRate,
      bytes: bytes,
    );
  }

  @override
  Future<File> saveToCache({
    required String text,
    required String voice,
    required String locale,
    required String provider,
    required String speechRate,
    required List<int> bytes,
    int? planId,
  }) async {
    final cacheKey = computeCacheKey(
      text: text,
      voice: voice,
      locale: locale,
      provider: provider,
      speechRate: speechRate,
    );

    final filePath = p.join(_audioDirectory, '$cacheKey.wav');
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    // INSERT OR IGNORE — safe for concurrent calls.
    await _db.into(_db.ttsCacheTable).insert(
          TtsCacheTableCompanion.insert(
            textHash: cacheKey,
            voiceId: voice,
            filePath: filePath,
            fileSizeBytes: Value(bytes.length),
            planId: Value(planId),
            provider: Value(provider),
            speechRate: Value(speechRate),
          ),
          mode: InsertMode.insertOrIgnore,
        );

    debugPrint(
        'MediaCacheService: saved ${bytes.length} bytes → $filePath');
    return file;
  }

  @override
  Future<void> clearCache() async {
    final entries = await _db.select(_db.ttsCacheTable).get();
    for (final entry in entries) {
      try {
        final file = File(entry.filePath);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('MediaCacheService.clearCache: could not delete ${entry.filePath}: $e');
      }
    }
    await _db.delete(_db.ttsCacheTable).go();
    debugPrint('MediaCacheService: cache cleared (${entries.length} entries)');
  }

  // ── Private helpers ────────────────────────────────────────────────────

  Future<File?> _findCachedFile(String cacheKey) async {
    final entry = await (_db.select(_db.ttsCacheTable)
          ..where((t) => t.textHash.equals(cacheKey)))
        .getSingleOrNull();
    if (entry == null) return null;

    final file = File(entry.filePath);
    if (!await file.exists()) {
      // Stale entry — remove and treat as miss.
      await (_db.delete(_db.ttsCacheTable)
            ..where((t) => t.textHash.equals(cacheKey)))
          .go();
      return null;
    }
    return file;
  }

  Future<List<int>> _synthesize({
    required String text,
    required String voice,
    required String locale,
    required String provider,
    required String speechRate,
  }) async {
    final serverUrl =
        await _settings.read(AppSettingsKeys.backendServerUrl) ??
            kDefaultBackendServerUrl;
    final apiKey =
        await _settings.read(AppSettingsKeys.backendApiKey) ?? '';

    final uri = Uri.parse('$serverUrl/api/tts/synthesize');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (apiKey.isNotEmpty) headers['x-api-key'] = apiKey;

    // Add JWT Authorization header for authenticated users.
    final token = await _authService?.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _httpClient
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'text': text,
            'voice': voice,
            'locale': locale,
            'provider': provider,
            'speechRate': speechRate,
          }),
        )
        .timeout(kSynthesisTimeout);

    if (response.statusCode != 200) {
      throw Exception(
          'TTS synthesis failed (HTTP ${response.statusCode}): ${response.body}');
    }
    return response.bodyBytes;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Directory initialisation
// ─────────────────────────────────────────────────────────────────────────────

/// Absolute path to the media cache audio directory.
String _mediaCacheDirectory = '';

/// Resolves and creates the media cache directory inside the app's documents
/// folder.
///
/// Must be called once from `main()` after [WidgetsFlutterBinding.ensureInitialized].
Future<void> initMediaCacheDirectory() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docsDir.path, 'tts_audio'));
  await dir.create(recursive: true);
  _mediaCacheDirectory = dir.path;
}

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ─────────────────────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
MediaCacheService mediaCacheService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final settings = ref.watch(appSettingsProvider);
  final authService = ref.watch(authServiceProvider);
  return MediaCacheServiceImpl(
    db: db,
    settings: settings,
    audioDirectory: _mediaCacheDirectory,
    authService: authService,
  );
}
