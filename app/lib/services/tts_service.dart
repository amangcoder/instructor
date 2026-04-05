/// TTSService — OpenAI TTS pre-rendering with platform fallback and local cache.
///
/// ## Architecture
///
/// [TTSService] is the abstract interface consumed by [PlanRepository] (on Plan
/// save) and [PlanExecutionEngine] (at step execution time).
///
/// [TTSServiceImpl] is the production implementation:
///
/// - **Primary path**: POST https://api.openai.com/v1/audio/speech with
///   `model: tts-1`, the step's voice (or Plan default), and
///   `response_format: mp3`. The response bytes are written to
///   `<documentsDir>/tts_audio/<hash>.mp3` and an entry is inserted in the
///   [TtsCacheTable].
///
/// - **Cache hit**: If a [TtsCacheTable] row with the same `textHash` and
///   `voiceId` exists AND the file is present on disk, the cached path is
///   returned immediately — no API call is made.
///
/// - **Fallback path**: When a [SocketException] indicates no network, the
///   on-device [PlatformTtsEngine] (backed by `flutter_tts`) synthesises the
///   audio to a local file and the result is cached in the same table.
///
/// ## Concurrency
/// [preRenderPlan] processes say steps in chunks of [kTtsMaxConcurrent] (5) to
/// respect OpenAI rate limits while still parallelising work.
///
/// ## API key
/// The OpenAI key is read via `String.fromEnvironment('OPENAI_API_KEY')`.
/// Inject it at build time with `--dart-define=OPENAI_API_KEY=<key>`.
library tts_service;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/utils/hash_utils.dart';

part 'tts_service.g.dart';

// ────────────────────────────────────────────────────────────────────────────
// Exceptions
// ────────────────────────────────────────────────────────────────────────────

/// Thrown when the OpenAI TTS API returns a non-200 status code.
final class TtsApiException implements Exception {
  const TtsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'TtsApiException(statusCode: $statusCode): $message';
}

/// Thrown when platform TTS synthesis fails (e.g. the device does not support
/// writing TTS output to a file).
final class TtsFallbackException implements Exception {
  const TtsFallbackException(this.message);

  final String message;

  @override
  String toString() => 'TtsFallbackException: $message';
}

// ────────────────────────────────────────────────────────────────────────────
// Platform TTS abstraction (enables mocking in tests)
// ────────────────────────────────────────────────────────────────────────────

/// Thin abstraction over [FlutterTts] to enable injection of a fake in tests.
///
/// Only [synthesizeToFile] is needed for TTS audio-file rendering.
abstract class PlatformTtsEngine {
  /// Synthesises [text] to [filePath] using the platform's on-device TTS.
  ///
  /// Returns `true` on success, `false` if the platform does not support file
  /// output.
  Future<bool> synthesizeToFile(String text, String filePath);

  /// Stops any ongoing synthesis or speech.
  Future<void> stop();
}

/// Production [PlatformTtsEngine] backed by the `flutter_tts` package.
final class FlutterTtsEngine implements PlatformTtsEngine {
  FlutterTtsEngine() : _tts = FlutterTts();

  final FlutterTts _tts;

  @override
  Future<bool> synthesizeToFile(String text, String filePath) async {
    await _tts.setLanguage('en-US');
    // flutter_tts returns 1 on success, 0 on failure.
    final result = await _tts.synthesizeToFile(text, filePath);
    return result == 1;
  }

  @override
  Future<void> stop() => _tts.stop();
}

// ────────────────────────────────────────────────────────────────────────────
// Public interface
// ────────────────────────────────────────────────────────────────────────────

/// Abstract interface for TTS audio pre-rendering and caching.
abstract class TTSService {
  /// Returns the local file path to a cached TTS audio file.
  ///
  /// Checks the [TtsCacheTable] first. On a cache hit the cached path is
  /// returned immediately. On a miss the OpenAI TTS API is called; if the
  /// network is unavailable a [SocketException] triggers the platform TTS
  /// fallback.
  Future<String> renderTTS({
    required String text,
    required String voiceId,
  });

  /// Batch pre-renders all [SayStep]s in [plan] — including those nested
  /// inside [RepeatStep] blocks — concurrently (≤ [kTtsMaxConcurrent] at a
  /// time).
  ///
  /// Failures for individual steps are logged and skipped; one bad step does
  /// not abort the entire plan pre-render.
  Future<void> preRenderPlan(Plan plan);

  /// Removes all [TtsCacheTable] entries (and their audio files on disk) that
  /// are associated with [planId].
  ///
  /// Also scans for and removes any orphaned cache entries whose audio file no
  /// longer exists on disk (regardless of planId).
  Future<void> clearCacheForPlan(int planId);

  /// Returns `true` when a valid cached audio file exists for [textHash] and
  /// [voiceId] — i.e. the DB row exists AND the file is present on disk.
  Future<bool> isCached(String textHash, String voiceId);

  /// Synthesises [text] using the platform's on-device TTS engine and saves
  /// the result to a local file.
  ///
  /// Returns the absolute path of the synthesised audio file.
  ///
  /// Throws [TtsFallbackException] when the device does not support TTS file
  /// output.
  Future<String> renderWithPlatformTTS(String text);
}

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

/// OpenAI TTS API endpoint.
const String kTtsApiUrl = 'https://api.openai.com/v1/audio/speech';

/// OpenAI TTS model identifier.
const String kTtsModel = 'tts-1';

/// Maximum number of concurrent OpenAI API calls during [TTSService.preRenderPlan].
///
/// Kept at 5 to stay comfortably within OpenAI's concurrency limits while
/// still providing meaningful parallelism for Plans with many say steps.
const int kTtsMaxConcurrent = 5;

/// HTTP timeout for a single TTS API call (30 seconds).
const Duration kTtsApiTimeout = Duration(seconds: 30);

// ────────────────────────────────────────────────────────────────────────────
// Concrete implementation
// ────────────────────────────────────────────────────────────────────────────

/// Production [TTSService] backed by the OpenAI TTS API and the [AppDatabase]
/// Drift ORM.
///
/// Inject a custom [httpClient] or [ttsEngine] for testing.
class TTSServiceImpl implements TTSService {
  TTSServiceImpl({
    required AppDatabase db,
    required String audioDirectory,
    http.Client? httpClient,
    PlatformTtsEngine? ttsEngine,
  })  : _db = db,
        _audioDirectory = audioDirectory,
        _httpClient = httpClient ?? http.Client(),
        _ttsEngine = ttsEngine ?? FlutterTtsEngine();

  final AppDatabase _db;
  final String _audioDirectory;
  final http.Client _httpClient;
  final PlatformTtsEngine _ttsEngine;

  // ── Public API ─────────────────────────────────────────────────────────

  @override
  Future<String> renderTTS({
    required String text,
    required String voiceId,
  }) async {
    final hash = ttsCacheKey(voiceId: voiceId, text: text);

    // Fast path: check cache before any I/O.
    final cached = await _findCachedPath(hash);
    if (cached != null) return cached;

    return _renderAndSave(
      text: text,
      voiceId: voiceId,
      hash: hash,
      planId: null,
    );
  }

  @override
  Future<void> preRenderPlan(Plan plan) async {
    // Collect all say steps recursively (including inside repeat blocks).
    final allSaySteps = _collectSaySteps(plan.steps, plan.defaultVoice);

    // Deduplicate by cache key to skip redundant API calls within one Plan.
    final seen = <String>{};
    final uniqueSteps = <({String text, String voiceId})>[];
    for (final step in allSaySteps) {
      final key = ttsCacheKey(voiceId: step.voiceId, text: step.text);
      if (seen.add(key)) {
        uniqueSteps.add(step);
      }
    }

    if (uniqueSteps.isEmpty) return;

    // Process in chunks to respect OpenAI rate limits.
    for (var i = 0; i < uniqueSteps.length; i += kTtsMaxConcurrent) {
      final chunk = uniqueSteps.skip(i).take(kTtsMaxConcurrent).toList();
      await Future.wait(
        chunk.map((step) => _preRenderStep(step, plan.id)),
      );
    }
  }

  @override
  Future<void> clearCacheForPlan(int planId) async {
    // 1. Find entries associated with this plan.
    final planEntries = await (
      _db.select(_db.ttsCacheTable)
        ..where((t) => t.planId.equals(planId))
    ).get();

    // Delete audio files from disk.
    for (final entry in planEntries) {
      final file = File(entry.filePath);
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint(
          'TTSService.clearCacheForPlan: could not delete file '
          '${entry.filePath}: $e',
        );
      }
    }

    // Delete DB rows for this plan.
    await (_db.delete(_db.ttsCacheTable)
          ..where((t) => t.planId.equals(planId)))
        .go();

    // 2. Scan for orphaned entries (DB row exists but file is missing on disk).
    await _cleanOrphanedEntries();
  }

  @override
  Future<bool> isCached(String textHash, String voiceId) async {
    final entry = await (
      _db.select(_db.ttsCacheTable)
        ..where(
          (t) =>
              t.textHash.equals(textHash) &
              t.voiceId.equals(voiceId),
        )
    ).getSingleOrNull();

    if (entry == null) return false;
    return File(entry.filePath).exists();
  }

  @override
  Future<String> renderWithPlatformTTS(String text) async {
    // Use a content-hash filename so repeat calls for the same text are
    // deduplicated without a database lookup.
    final hash = sha256Hex(text);
    final extension = Platform.isIOS ? 'caf' : 'wav';
    final filePath = p.join(_audioDirectory, '${hash}_platform.$extension');

    // Return immediately if already synthesised.
    if (await File(filePath).exists()) return filePath;

    final success = await _ttsEngine.synthesizeToFile(text, filePath);
    if (!success || !await File(filePath).exists()) {
      throw TtsFallbackException(
        'Platform TTS failed to synthesise audio to file. '
        'Ensure the device has a TTS engine installed and supports file output.',
      );
    }
    return filePath;
  }

  // ── Private helpers ────────────────────────────────────────────────────

  /// Pre-renders a single say step for [planId], swallowing errors so one
  /// failed step does not abort the full [preRenderPlan] batch.
  Future<void> _preRenderStep(
    ({String text, String voiceId}) step,
    int planId,
  ) async {
    final hash = ttsCacheKey(voiceId: step.voiceId, text: step.text);
    try {
      final cached = await _findCachedPath(hash);
      if (cached != null) return; // Already cached — nothing to do.

      await _renderAndSave(
        text: step.text,
        voiceId: step.voiceId,
        hash: hash,
        planId: planId,
      );
    } catch (e, st) {
      final preview =
          step.text.length > 40 ? '${step.text.substring(0, 40)}…' : step.text;
      debugPrint(
        'TTSService.preRenderPlan: failed to render "$preview" '
        '(voice: ${step.voiceId}): $e\n$st',
      );
    }
  }

  /// Calls the OpenAI TTS API (or falls back to platform TTS), saves the audio
  /// file to [_audioDirectory], inserts a [TtsCacheTable] row, and returns the
  /// absolute file path.
  Future<String> _renderAndSave({
    required String text,
    required String voiceId,
    required String hash,
    required int? planId,
  }) async {
    try {
      // Primary path: OpenAI TTS API.
      final bytes = await _callOpenAiApi(text: text, voiceId: voiceId);
      final filePath = p.join(_audioDirectory, '$hash.mp3');

      // Write audio bytes to disk.
      await File(filePath).writeAsBytes(bytes);

      // Cache DB entry (INSERT OR IGNORE — concurrent pre-renders are safe).
      await _insertCacheEntry(
        hash: hash,
        voiceId: voiceId,
        filePath: filePath,
        fileSizeBytes: bytes.length,
        planId: planId,
      );

      return filePath;
    } on SocketException catch (e) {
      // Network unavailable — use platform TTS as fallback.
      debugPrint('TTSService: network unavailable ($e), using platform TTS.');
      final filePath = await renderWithPlatformTTS(text);

      // Cache the platform TTS result.
      final size = await File(filePath).length();
      await _insertCacheEntry(
        hash: hash,
        voiceId: voiceId,
        filePath: filePath,
        fileSizeBytes: size,
        planId: planId,
      );

      return filePath;
    }
  }

  /// POSTs to the OpenAI TTS API and returns the raw MP3 bytes.
  ///
  /// Throws [TtsApiException] for non-200 responses.
  /// Propagates [SocketException] (unwrapped) when the network is unavailable.
  Future<Uint8List> _callOpenAiApi({
    required String text,
    required String voiceId,
  }) async {
    // ignore: do_not_use_environment — API key is injected at build time via
    // --dart-define=OPENAI_API_KEY=<key>; it is never a runtime lookup.
    const apiKey = String.fromEnvironment('OPENAI_API_KEY');
    if (apiKey.isEmpty) {
      throw const TtsApiException(
        'OPENAI_API_KEY is not set. '
        'Pass --dart-define=OPENAI_API_KEY=<key> at build time.',
      );
    }

    final response = await _httpClient
        .post(
          Uri.parse(kTtsApiUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': kTtsModel,
            'input': text,
            'voice': voiceId,
            'response_format': 'mp3',
          }),
        )
        .timeout(kTtsApiTimeout);

    if (response.statusCode != 200) {
      throw TtsApiException(
        'OpenAI TTS API error: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    return response.bodyBytes;
  }

  /// Queries [TtsCacheTable] for a row matching [hash] and verifies the file
  /// exists on disk.
  ///
  /// Returns the cached file path, or `null` on a cache miss or stale entry.
  /// Stale entries (row exists but file is missing) are deleted automatically.
  Future<String?> _findCachedPath(String hash) async {
    final entry = await (
      _db.select(_db.ttsCacheTable)
        ..where((t) => t.textHash.equals(hash))
    ).getSingleOrNull();

    if (entry == null) return null;

    if (!await File(entry.filePath).exists()) {
      // Stale cache entry — clean it up and treat as a miss.
      await (_db.delete(_db.ttsCacheTable)
            ..where((t) => t.textHash.equals(hash)))
          .go();
      return null;
    }

    return entry.filePath;
  }

  /// Inserts a row into [TtsCacheTable].
  ///
  /// Uses `INSERT OR IGNORE` so that concurrent pre-renders for the same text
  /// (e.g. two Plans sharing the same say step) do not cause constraint errors.
  Future<void> _insertCacheEntry({
    required String hash,
    required String voiceId,
    required String filePath,
    required int fileSizeBytes,
    required int? planId,
  }) =>
      _db.into(_db.ttsCacheTable).insert(
        TtsCacheTableCompanion.insert(
          textHash: hash,
          voiceId: voiceId,
          filePath: filePath,
          fileSizeBytes: Value(fileSizeBytes),
          planId: Value(planId),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  /// Recursively collects all [SayStep] entries in [steps], including those
  /// nested inside [RepeatStep] blocks at any depth.
  ///
  /// [defaultVoice] is used when a [SayStep] does not specify its own voice.
  List<({String text, String voiceId})> _collectSaySteps(
    List<PlanStep> steps,
    String defaultVoice,
  ) {
    final result = <({String text, String voiceId})>[];
    for (final step in steps) {
      switch (step) {
        case SayStep(:final text, :final voiceId):
          result.add((text: text, voiceId: voiceId ?? defaultVoice));
        case RepeatStep(:final children):
          // Recurse — RepeatStep can be nested at any depth.
          result.addAll(_collectSaySteps(children, defaultVoice));
        case NotifyStep() || PlayStep() || WaitStep() || StopAudioStep():
          // These step types produce no TTS audio.
          break;
      }
    }
    return result;
  }

  /// Scans all [TtsCacheTable] rows and deletes any whose audio file is no
  /// longer present on disk.
  Future<void> _cleanOrphanedEntries() async {
    final allEntries = await _db.select(_db.ttsCacheTable).get();
    final orphanHashes = <String>[];

    for (final entry in allEntries) {
      if (!await File(entry.filePath).exists()) {
        orphanHashes.add(entry.textHash);
      }
    }

    if (orphanHashes.isNotEmpty) {
      await (_db.delete(_db.ttsCacheTable)
            ..where((t) => t.textHash.isIn(orphanHashes)))
          .go();

      debugPrint(
        'TTSService: removed ${orphanHashes.length} orphaned cache entries.',
      );
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Global audio-directory initialisation
// ────────────────────────────────────────────────────────────────────────────

/// Absolute path to the directory where TTS audio files are stored.
///
/// Must be initialised by calling [initTtsAudioDirectory] from `main()` after
/// [WidgetsFlutterBinding.ensureInitialized].
String _ttsAudioDirectory = '';

/// Resolves and creates the TTS audio directory inside the app's documents
/// folder.
///
/// Call this once from `main()` before the [ttsServiceProvider] is first read.
Future<void> initTtsAudioDirectory() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final audioDir = Directory(p.join(docsDir.path, 'tts_audio'));
  await audioDir.create(recursive: true);
  _ttsAudioDirectory = audioDir.path;
}

// ────────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ────────────────────────────────────────────────────────────────────────────

/// Singleton [TTSService] provider.
///
/// [keepAlive: true] prevents garbage collection for the app's lifetime.
///
/// In tests, override this provider via [ProviderScope] overrides:
/// ```dart
/// ProviderScope(
///   overrides: [
///     ttsServiceProvider.overrideWithValue(FakeTTSService()),
///   ],
/// )
/// ```
@Riverpod(keepAlive: true)
TTSService ttsService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return TTSServiceImpl(
    db: db,
    audioDirectory: _ttsAudioDirectory,
  );
}
