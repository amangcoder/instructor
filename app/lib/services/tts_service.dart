/// TTSService — backend-routed TTS pre-rendering with platform fallback and
/// local cache.
///
/// ## Architecture
///
/// [TTSService] is the abstract interface consumed by [PlanRepository] (on Plan
/// save) and [PlanExecutionEngine] (at step execution time).
///
/// [TTSServiceImpl] is the production implementation that routes all synthesis
/// requests through the NestJS backend at `{backendServerUrl}/api/tts/synthesize`.
///
/// ### Backend TTS
/// POST `{backendServerUrl}/api/tts/synthesize` with JSON body
/// `{text, voice, locale, provider}` and `x-api-key` header. The backend
/// routes to the selected provider (gemini or kokoro) and returns WAV audio
/// bytes directly. The provider is read from the `tts_provider` app setting.
///
/// ### Common behaviour
/// - **Cache hit**: If a [TtsCacheTable] row with the same `textHash` and
///   `voiceId` exists AND the file is present on disk, the cached path is
///   returned immediately — no API call is made.
///
/// - **Fallback path**: When a [SocketException] or [TimeoutException] indicates
///   no network, the on-device [PlatformTtsEngine] (backed by `flutter_tts`)
///   synthesises the audio to a local file and the result is cached in the
///   same table.
///
/// ## Concurrency
/// [preRenderPlan] processes say steps in chunks of [kTtsMaxConcurrent] (5) to
/// respect API rate limits while still parallelising work.
///
/// ## Backend URL
/// Configured at build time via `--dart-define=BACKEND_URL=<url>` (see [kBackendUrl]).
library tts_service;

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
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
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/services/api_logger.dart';
import 'package:instructor/services/app_settings.dart';
import 'package:instructor/services/auth_service.dart';
import 'package:instructor/utils/hash_utils.dart';

part 'tts_service.g.dart';

// ────────────────────────────────────────────────────────────────────────────
// Exceptions
// ────────────────────────────────────────────────────────────────────────────

/// Thrown when the backend TTS API returns a non-200 status code.
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
  /// [speed] is applied as the platform speech rate (clamped to [0.0, 1.0])
  /// so that platform-fallback files match the user's configured speed,
  /// consistent with the backend API path which also applies [speechRate].
  ///
  /// Returns `true` on success, `false` if the platform does not support file
  /// output.
  Future<bool> synthesizeToFile(String text, String filePath,
      {double speed = 1.0});

  /// Speaks [text] directly through the device speaker (no file output).
  ///
  /// Completes when the utterance finishes. Use this as a last-resort fallback
  /// when [synthesizeToFile] fails.
  Future<void> speak(String text, {double speed});

  /// Stops any ongoing synthesis or speech.
  Future<void> stop();
}

/// Production [PlatformTtsEngine] backed by the `flutter_tts` package.
final class FlutterTtsEngine implements PlatformTtsEngine {
  FlutterTtsEngine() : _tts = FlutterTts();

  final FlutterTts _tts;

  /// Timeout for [synthesizeToFile] — if the platform TTS engine never fires
  /// its completion callback (common on some Android devices), this prevents
  /// hanging the execution loop forever.
  static const _kSynthesizeTimeout = Duration(seconds: 15);

  @override
  Future<bool> synthesizeToFile(String text, String filePath,
      {double speed = 1.0}) async {
    await _tts.setLanguage('en-US');
    // Apply the user's configured speech rate so platform-fallback files are
    // synthesised at the same speed as backend TTS files. Without this the
    // device default rate was always used.
    await _tts.setSpeechRate(speed.clamp(0.0, 1.0));
    // Wait for the file to actually be written before returning.
    await _tts.awaitSynthCompletion(true);
    // isFullPath: true bypasses MediaStore on Android 30+ and writes directly
    // to our path. Without it, the file ends up in MediaStore and never appears
    // at the expected location.
    //
    final result = await _tts
        .synthesizeToFile(text, filePath, true)
        .timeout(_kSynthesizeTimeout, onTimeout: () {
      debugPrint(
        'FlutterTtsEngine: synthesizeToFile timed out after '
        '${_kSynthesizeTimeout.inSeconds} s — completion callback never fired',
      );
      return 0; // Treat as failure so the caller falls through to speakDirect.
    });
    return result == 1;
  }

  @override
  Future<void> speak(String text, {double speed = 1.0}) async {
    final completer = Completer<void>();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(speed.clamp(0.0, 1.0));
    _tts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    _tts.setErrorHandler((msg) {
      if (!completer.isCompleted) {
        completer.completeError(TtsFallbackException(
          'Platform TTS speak() failed: $msg',
        ));
      }
    });
    final result = await _tts.speak(text);
    if (result != 1) {
      if (!completer.isCompleted) {
        completer.completeError(TtsFallbackException(
          'Platform TTS speak() returned $result',
        ));
      }
    }
    // Guard against Android TTS silently dropping the utterance — if neither
    // the completion nor error handler fires within 30 s, complete anyway so
    // the execution engine is not stuck forever.
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        debugPrint(
          'FlutterTtsEngine: speak() timed out after 30 s — '
          'completion handler never fired',
        );
      },
    );
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
  /// returned immediately. On a miss the backend TTS API is called; if the
  /// network is unavailable a [SocketException] or [TimeoutException] triggers
  /// the platform TTS fallback.
  Future<String> renderTTS({
    required String text,
    required String voiceId,
  });

  /// Batch pre-renders all [SayStep]s in [plan] — including those nested
  /// inside [RepeatStep] blocks — concurrently (≤ [kTtsMaxConcurrent] at a
  /// time).
  ///
  /// [onProgress] is an optional callback invoked after every individual step
  /// completes (whether success or failure).  The first argument is the number
  /// of steps completed so far; the second is the total number of uncached
  /// steps that need rendering.
  ///
  /// Failures for individual steps are logged and skipped; one bad step does
  /// not abort the entire plan pre-render.
  Future<void> preRenderPlan(
    Plan plan, {
    void Function(int completed, int total)? onProgress,
  });

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

  /// Last-resort fallback: speaks [text] directly through the device speaker
  /// using [FlutterTts.speak], bypassing file output entirely.
  ///
  /// Use this when both backend TTS and [renderWithPlatformTTS] fail.
  /// Completes when the utterance finishes.
  Future<void> speakDirect(String text, {double speed = 0.5});

  /// Stops any in-progress platform TTS speech immediately.
  Future<void> stopSpeaking();
}

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

/// Backend TTS synthesis endpoint path.
const String kBackendTtsPath = '/api/tts/synthesize';

/// Maximum number of concurrent backend API calls during [TTSService.preRenderPlan].
///
/// Kept at 5 to provide meaningful parallelism for Plans with many say steps
/// while avoiding backend overload.
const int kTtsMaxConcurrent = 5;

/// HTTP timeout for a single backend TTS API call.
const Duration kTtsApiTimeout = Duration(seconds: 60);

// ────────────────────────────────────────────────────────────────────────────
// Concrete implementation
// ────────────────────────────────────────────────────────────────────────────

/// Production [TTSService] backed by the NestJS backend TTS endpoint and the
/// [AppDatabase] Drift ORM.
///
/// Inject a custom [httpClient] or [ttsEngine] for testing.
class TTSServiceImpl implements TTSService {
  TTSServiceImpl({
    required AppDatabase db,
    required String audioDirectory,
    required AuthService authService,
    http.Client? httpClient,
    PlatformTtsEngine? ttsEngine,
  })  : _db = db,
        _audioDirectory = audioDirectory,
        _auth = authService,
        _httpClient = httpClient ?? http.Client(),
        _ttsEngine = ttsEngine ?? FlutterTtsEngine();

  final AppDatabase _db;
  final String _audioDirectory;
  final AuthService _auth;
  final http.Client _httpClient;
  final PlatformTtsEngine _ttsEngine;

  /// In-flight requests keyed by cache hash — prevents duplicate concurrent
  /// API calls for the same text+voice.
  final _inflight = <String, Future<String>>{};

  // ── Public API ─────────────────────────────────────────────────────────

  @override
  Future<String> renderTTS({
    required String text,
    required String voiceId,
  }) async {
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'must not be empty');
    }
    if (voiceId.trim().isEmpty) {
      throw ArgumentError.value(voiceId, 'voiceId', 'must not be empty');
    }

    debugPrint('TTSService.renderTTS: ENTER voice=$voiceId, text="${text.length > 30 ? '${text.substring(0, 30)}…' : text}"');
    final provider = await _readTtsProvider();
    debugPrint('TTSService.renderTTS: provider=$provider');
    final locale = await _currentLocale();
    debugPrint('TTSService.renderTTS: locale=$locale');
    final speechRate = await _readSpeechRate();
    debugPrint('TTSService.renderTTS: speechRate=$speechRate');
    final hash = fullParamCacheKey(
      provider: provider,
      voice: voiceId,
      text: text,
      locale: locale.name,
      speechRate: speechRate.toString(),
    );
    debugPrint('TTSService.renderTTS: hash=${hash.substring(0, 8)}…');

    // Fast path: check cache before any I/O.
    debugPrint('TTSService.renderTTS: checking cache…');
    final cached = await _findCachedPath(hash);
    debugPrint('TTSService.renderTTS: cache result=${cached != null ? "HIT" : "MISS"}, inflight keys=${_inflight.keys.map((k) => k.substring(0, 8)).toList()}');
    if (cached != null) {
      debugPrint('TTSService: cache hit for voice=$voiceId');
      return cached;
    }

    // Deduplicate: if this exact request is already in-flight, await it.
    final existing = _inflight[hash];
    if (existing != null) {
      debugPrint('TTSService: joining in-flight request for voice=$voiceId (hash=${hash.substring(0, 8)}…)');
      // debugger(message: 'JOINING INFLIGHT — this future may never resolve if preRender already failed');
      return existing;
    }

    debugPrint('TTSService: cache miss — rendering via backend, voice=$voiceId');
    // Use try/finally instead of .whenComplete() to ensure errors propagate
    // cleanly through the async function's own stack frame.
    final future = _renderAndSave(
      text: text,
      voiceId: voiceId,
      hash: hash,
      provider: provider,
      planId: null,
    );
    _inflight[hash] = future;
    try {
      final result = await future;
      debugPrint('TTSService.renderTTS: _renderAndSave OK — $result');
      return result;
    } catch (e) {
      debugPrint('TTSService.renderTTS: _renderAndSave THREW ${e.runtimeType}: $e');
      rethrow;
    } finally {
      unawaited(_inflight.remove(hash));
    }
  }

  @override
  Future<void> preRenderPlan(
    Plan plan, {
    void Function(int completed, int total)? onProgress,
  }) async {
    // Collect all say steps recursively (including inside repeat blocks).
    final allSaySteps = _collectSaySteps(plan.steps, plan.defaultVoice);

    final provider = await _readTtsProvider();
    final locale = await _currentLocale();
    final speechRate = await _readSpeechRate();

    // Deduplicate by cache key to skip redundant API calls within one Plan.
    final seen = <String>{};
    final uniqueSteps = <({String text, String voiceId})>[];
    for (final step in allSaySteps) {
      final key = fullParamCacheKey(
        provider: provider,
        voice: step.voiceId,
        text: step.text,
        locale: locale.name,
        speechRate: speechRate.toString(),
      );
      if (seen.add(key)) {
        uniqueSteps.add(step);
      }
    }

    if (uniqueSteps.isEmpty) return;

    // Pre-pass: filter to only the steps that are not yet cached so we can
    // report an accurate total to the caller before processing begins.
    final uncachedSteps = <({String text, String voiceId})>[];
    for (final step in uniqueSteps) {
      final hash = fullParamCacheKey(
        provider: provider,
        voice: step.voiceId,
        text: step.text,
        locale: locale.name,
        speechRate: speechRate.toString(),
      );
      final cached = await _findCachedPath(hash);
      if (cached == null) {
        uncachedSteps.add(step);
      }
    }

    final total = uncachedSteps.length;
    if (total == 0) return;

    var completed = 0;

    // Process in chunks to respect API rate limits.
    // Steps within a chunk run in parallel; chunks run sequentially.
    for (var i = 0; i < uncachedSteps.length; i += kTtsMaxConcurrent) {
      final chunk = uncachedSteps.skip(i).take(kTtsMaxConcurrent).toList();
      await Future.wait(
        chunk.map((step) async {
          await _preRenderStep(step, plan.id, provider, locale.name, speechRate.toString());
          // Increment and report after every individual step (success or
          // failure — _preRenderStep never throws).
          completed++;
          onProgress?.call(completed, total);
        }),
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

    // Platform TTS uses a fixed speed of 0.5 for natural-sounding fallback
    // output, independent of the user's configured speech rate (which applies
    // to backend-generated TTS files played via the audio engine).
    const speed = 0.5;
    final success =
        await _ttsEngine.synthesizeToFile(text, filePath, speed: speed);
    if (!success || !await File(filePath).exists()) {
      throw TtsFallbackException(
        'Platform TTS failed to synthesise audio to file. '
        'Ensure the device has a TTS engine installed and supports file output.',
      );
    }
    return filePath;
  }

  @override
  Future<void> speakDirect(String text, {double speed = 0.5}) async {
    debugPrint('TTSService: using speakDirect (last-resort fallback), speed=$speed');
    await _ttsEngine.speak(text, speed: speed);
  }

  @override
  Future<void> stopSpeaking() async {
    await _ttsEngine.stop();
  }

  // ── Private helpers ────────────────────────────────────────────────────

  /// Pre-renders a single say step for [planId], swallowing errors so one
  /// failed step does not abort the full [preRenderPlan] batch.
  Future<void> _preRenderStep(
    ({String text, String voiceId}) step,
    int planId,
    String provider,
    String locale,
    String speechRate,
  ) async {
    final hash = fullParamCacheKey(
      provider: provider,
      voice: step.voiceId,
      text: step.text,
      locale: locale,
      speechRate: speechRate,
    );
    try {
      final cached = await _findCachedPath(hash);
      if (cached != null) return; // Already cached — nothing to do.

      // Deduplicate: if this exact request is already in-flight, await it.
      final existing = _inflight[hash];
      if (existing != null) {
        debugPrint('TTSService: joining in-flight request for voice=${step.voiceId}');
        await existing;
        return;
      }

      final future = _renderAndSave(
        text: step.text,
        voiceId: step.voiceId,
        hash: hash,
        provider: provider,
        planId: planId,
      ).whenComplete(() => _inflight.remove(hash));
      _inflight[hash] = future;
      await future;
    } catch (e, st) {
      final preview =
          step.text.length > 40 ? '${step.text.substring(0, 40)}…' : step.text;
      debugPrint(
        'TTSService.preRenderPlan: failed to render "$preview" '
        '(voice: ${step.voiceId}): $e\n$st',
      );
    }
  }

  /// Maximum number of retries when the backend returns a transient error
  /// before falling back to platform TTS.
  static const int _kMaxApiRetries = 2;

  /// Calls the backend TTS API, saves the audio file to [_audioDirectory],
  /// inserts a [TtsCacheTable] row, and returns the absolute file path.
  ///
  /// Retries up to [_kMaxApiRetries] times on non-401 [TtsApiException].
  /// All other errors ([SocketException], [TimeoutException], 401) are
  /// rethrown immediately so the caller can fall back to [speakDirect]
  /// without waiting.
  Future<String> _renderAndSave({
    required String text,
    required String voiceId,
    required String hash,
    required String provider,
    required int? planId,
  }) async {
    TtsApiException? lastApiError;

    for (var attempt = 0; attempt <= _kMaxApiRetries; attempt++) {
      try {
        // Primary path: call the backend TTS endpoint.
        final bytes = await _callBackendApi(
          text: text,
          voiceId: voiceId,
          provider: provider,
        );
        debugPrint(
          'TTSService: received ${bytes.length} bytes from backend',
        );
        const ext = 'wav'; // Backend returns WAV audio
        final filePath = p.join(_audioDirectory, '$hash.$ext');

        // Write audio bytes to disk, flushing via RandomAccessFile so the OS
        // buffer is committed before just_audio/ExoPlayer reads the file.
        final raf = await File(filePath).open(mode: FileMode.write);
        try {
          await raf.writeFrom(bytes);
          await raf.flush();
        } finally {
          await raf.close();
        }

        // Verify the file was written correctly.
        final writtenSize = await File(filePath).length();
        debugPrint(
          'TTSService: wrote $writtenSize bytes to $filePath',
        );

        // Cache DB entry (INSERT OR IGNORE — concurrent pre-renders are safe).
        // Wrapped in try-catch so a DB error does not prevent playback —
        // the audio file is already on disk and can be played regardless.
        try {
          await _insertCacheEntry(
            hash: hash,
            voiceId: voiceId,
            filePath: filePath,
            fileSizeBytes: bytes.length,
            planId: planId,
          );
        } catch (e) {
          debugPrint('TTSService: cache insert failed (non-fatal): $e');
        }

        debugPrint('TTSService: _renderAndSave returning path=$filePath');
        return filePath;
      } on SocketException {
        // Network unavailable — signal the caller so the engine can handle
        // the fallback (e.g. render via platform TTS to a file).
        debugPrint(
          'TTSService: backend unreachable (SocketException), signalling fallback',
        );
        // debugger(message: 'TTS: SocketException → TtsFallbackException');
        throw const TtsFallbackException('Backend unreachable (offline)');
      } on http.ClientException {
        // The http package wraps SocketException in ClientException when the
        // connection is refused or the host is unreachable.
        debugPrint(
          'TTSService: backend unreachable (ClientException), signalling fallback',
        );
        // debugger(message: 'TTS: ClientException → TtsFallbackException');
        throw const TtsFallbackException('Backend unreachable (offline)');
      } on TimeoutException {
        debugPrint(
          'TTSService: backend timed out, signalling fallback to caller',
        );
        throw const TtsFallbackException('Backend timed out');
      } on TtsApiException catch (e) {
        if (e.statusCode == 401) {
          // Auth failure — logout already triggered in _callBackendApi.
          // Fall back to platform TTS so the current session isn't interrupted.
          throw const TtsFallbackException('Auth expired (401)');
        }
        lastApiError = e;
        if (attempt < _kMaxApiRetries) {
          debugPrint(
            'TTSService: backend TTS attempt ${attempt + 1} failed '
            '($e), retrying…',
          );
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    // All retries exhausted — rethrow so the caller can use speakDirect.
    // debugger(message: 'TTS: retries exhausted — throwing TtsApiException: $lastApiError');
    throw lastApiError ?? const TtsApiException('Backend TTS failed');
  }

  /// POSTs to the backend TTS endpoint and returns the raw WAV bytes.
  ///
  /// Uses the build-time [kBackendUrl] and the API key from
  /// [AppSettingsKeys.backendApiKey].
  ///
  /// Throws [TtsApiException] for non-200 responses.
  /// Propagates [SocketException] (unwrapped) when the network is unavailable.
  Future<Uint8List> _callBackendApi({
    required String text,
    required String voiceId,
    required String provider,
  }) async {
    assert(text.trim().isNotEmpty, 'text must not be empty');
    assert(voiceId.trim().isNotEmpty, 'voiceId must not be empty');

    const serverUrl = kBackendUrl;

    final apiKeyRow = await (_db.select(_db.appSettingsTable)
          ..where((t) => t.key.equals(AppSettingsKeys.backendApiKey)))
        .getSingleOrNull();
    final apiKey = apiKeyRow?.value ?? '';

    final locale = await _currentLocale();

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    // Prefer JWT token for authentication.
    final token = await _auth.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else if (apiKey.isNotEmpty) {
      headers['x-api-key'] = apiKey;
    }

    debugPrint(
      'TTSService: calling backend TTS — '
      'url=$serverUrl$kBackendTtsPath, voice=$voiceId, provider=$provider, '
      'locale=${locale.name}',
    );

    final uri = Uri.parse('$serverUrl$kBackendTtsPath');
    final bodyJson = jsonEncode({
      'text': text,
      'voice': voiceId,
      'locale': locale.name,
      'provider': provider,
    });

    var response = await _httpClient
        .post(uri, headers: headers, body: bodyJson)
        .timeout(kTtsApiTimeout);

    debugPrint(
      'TTSService: backend TTS responded — status=${response.statusCode}',
    );

    // On 401, attempt a token refresh and retry once (mirrors ApiClient logic).
    if (response.statusCode == 401) {
      debugPrint('TTSService: 401 received, attempting token refresh…');
      try {
        await _auth.refreshToken();
        final freshToken = await _auth.getAccessToken();
        if (freshToken != null && freshToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $freshToken';
        }
        response = await _httpClient
            .post(uri, headers: headers, body: bodyJson)
            .timeout(kTtsApiTimeout);
        debugPrint(
          'TTSService: retry after refresh — status=${response.statusCode}',
        );
        if (response.statusCode == 401) {
          debugPrint('TTSService: retry still 401, logging out');
          await _auth.logout();
        }
      } catch (e) {
        debugPrint('TTSService: token refresh failed ($e), logging out');
        await _auth.logout();
      }
    }

    if (response.statusCode != 200) {
      throw TtsApiException(
        'Backend TTS error: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    return response.bodyBytes;
  }

  /// Reads the user's preferred speech rate from [AppSettingsTable].
  ///
  /// Returns `1.0` when the key is absent or unparseable.
  Future<double> _readSpeechRate() async {
    final row = await (_db.select(_db.appSettingsTable)
          ..where((t) => t.key.equals(AppSettingsKeys.speechRate)))
        .getSingleOrNull();
    return double.tryParse(row?.value ?? '') ?? 1.0;
  }

  /// Reads the selected TTS provider from [AppSettingsTable].
  ///
  /// Returns `'gemini'` when the key is absent or empty.
  Future<String> _readTtsProvider() async {
    final row = await (_db.select(_db.appSettingsTable)
          ..where((t) => t.key.equals(AppSettingsKeys.ttsProvider)))
        .getSingleOrNull();
    final raw = row?.value;
    if (raw == null || raw.trim().isEmpty) return 'gemini';
    return raw;
  }

  /// Reads the current [TtsLocale] from [AppSettingsTable].
  ///
  /// Handles both enum-format (`'enGB'`) and API-format (`'en-GB'`) locale
  /// strings stored by the settings screen.
  ///
  /// Returns [TtsLocale.enIN] when the key is absent or unrecognised.
  Future<TtsLocale> _currentLocale() async {
    final row = await (_db.select(_db.appSettingsTable)
          ..where((t) => t.key.equals(AppSettingsKeys.ttsLocale)))
        .getSingleOrNull();
    final raw = row?.value;
    if (raw == null || raw.isEmpty) return TtsLocale.enIN;
    // Normalise: strip hyphens and lowercase for comparison so both
    // 'en-GB'/'enGB' and 'en-IN'/'enIN' are matched correctly.
    final normalised = raw.replaceAll('-', '').toLowerCase();
    if (normalised == 'engb') return TtsLocale.enGB;
    return TtsLocale.enIN;
  }

  /// Queries [TtsCacheTable] for a row matching [hash] and verifies the file
  /// exists on disk.
  ///
  /// Returns the cached file path, or `null` on a cache miss or stale entry.
  /// Stale entries (row exists but file is missing) are deleted automatically.
  Future<String?> _findCachedPath(String hash) async {
    debugPrint('TTSService._findCachedPath: querying DB for hash=${hash.substring(0, 8)}…');
    final entry = await (
      _db.select(_db.ttsCacheTable)
        ..where((t) => t.textHash.equals(hash))
    ).getSingleOrNull();
    debugPrint('TTSService._findCachedPath: query returned ${entry != null ? "entry" : "null"}');

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
  final auth = ref.watch(authServiceProvider);
  final client = LoggingClient();
  ref.onDispose(client.close);
  return TTSServiceImpl(
    db: db,
    audioDirectory: _ttsAudioDirectory,
    authService: auth,
    httpClient: client,
  );
}
