/// Riverpod providers for TTS playback mode selection and TTS status polling.
///
/// [TtsPlaybackMode] distinguishes between the device-native platform TTS
/// (always available, no network needed) and the server-generated GenAI TTS
/// (pre-rendered audio files downloaded from the backend).
///
/// [ttsPlaybackModeProvider] is session-scoped in-memory state — it resets to
/// [TtsPlaybackMode.platform] each time the app is launched and is never
/// persisted to disk or the backend.
///
/// [planTtsStatusProvider] polls the server for TTS generation progress with
/// adaptive exponential backoff and updates the local SQLite cache on every
/// successful response.
library tts_status_providers;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:drift/drift.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/models/tts_status_info.dart';
import 'package:instructor/services/audio_download_service.dart';
import 'package:instructor/services/plan_api_service.dart';

import 'package:instructor/providers/plan_providers.dart';

part 'tts_status_providers.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enum
// ─────────────────────────────────────────────────────────────────────────────

/// Selects which TTS rendering path is active for plan step narration.
///
/// - [platform] — use the device-native TTS engine (flutter_tts / AVSpeechSynthesizer).
///   Always available, no network dependency.
/// - [genai] — use server-generated audio files pre-rendered by the Kokoro TTS
///   backend. Requires the plan to have been activated and audio downloaded.
enum TtsPlaybackMode {
  platform,
  genai,
}

// ─────────────────────────────────────────────────────────────────────────────
// TtsPlaybackMode provider
// ─────────────────────────────────────────────────────────────────────────────

/// Session-scoped [StateProvider] that holds the current [TtsPlaybackMode].
///
/// Defaults to [TtsPlaybackMode.platform] on every app launch.
/// Toggle this provider at runtime (e.g. from the NowPlaying TTS toggle widget)
/// to switch between platform voice and GenAI pre-rendered audio.
///
/// This value is **not** persisted — it resets to [TtsPlaybackMode.platform]
/// each session.
final StateProvider<TtsPlaybackMode> ttsPlaybackModeProvider =
    StateProvider<TtsPlaybackMode>(
  (ref) => TtsPlaybackMode.platform,
);

// ─────────────────────────────────────────────────────────────────────────────
// Polling constants
// ─────────────────────────────────────────────────────────────────────────────

/// TTS status values that indicate generation has finished (success or failure).
///
/// Once any of these is received, polling stops immediately.
const _kTerminalStates = {'completed', 'partial', 'failed'};

// ─────────────────────────────────────────────────────────────────────────────
// planTtsStatus StreamProvider
// ─────────────────────────────────────────────────────────────────────────────

/// Polls `GET /api/tts/status/:planId` with adaptive exponential backoff and
/// updates the local SQLite plan cache after every successful response.
///
/// ### Polling schedule
/// - First poll fires after a 2-second initial delay.
/// - Each subsequent delay is multiplied by 1.5, capped at 30 seconds.
/// - Polling stops automatically when a terminal state is received
///   ([completed], [partial], or [failed]) or after 10 minutes have elapsed.
///
/// ### Local cache
/// After each successful poll the `plans` Drift table row for [planId] is
/// updated with the latest `ttsStatus`, `ttsTotal`, and `ttsCompleted` values.
/// This keeps [watchUserPlans] streams reactive so the UI reflects current
/// progress without a full server refresh.
///
/// ### Auto-cancel
/// The provider has auto-dispose semantics (default for `@riverpod`). When the
/// last widget listener unsubscribes (e.g. the widget leaves the tree), Riverpod
/// disposes the provider and a cancellation flag causes the in-progress delay
/// loop to exit on the next iteration — the stream closes promptly.
///
/// ### Error handling
/// [PlanApiException]s during polling are logged and swallowed — the stream
/// stays open so transient network errors do not abort the progress indicator.
/// The 10-minute timeout is still enforced across errors.
///
/// Usage:
/// ```dart
/// final ttsStatus = ref.watch(planTtsStatusProvider('plan-uuid-1234'));
/// ttsStatus.when(
///   data: (status) => Text('TTS: ${status.status} (${status.completed}/${status.total})'),
///   loading: () => const CircularProgressIndicator(),
///   error: (e, st) => Text('Error: $e'),
/// );
/// ```
@riverpod
Stream<TtsStatusInfo> planTtsStatus(Ref ref, String planId) {
  final api = ref.watch(planApiServiceProvider);
  final db = ref.watch(appDatabaseProvider);

  var cancelled = false;
  ref.onDispose(() => cancelled = true);

  return $pollTtsStatus(
    api: api,
    db: db,
    planId: planId,
    isCancelled: () => cancelled,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Core polling loop (exposed for testing)
// ─────────────────────────────────────────────────────────────────────────────

/// Core adaptive-backoff polling loop for TTS generation status.
///
/// This function is intentionally separated from the `@riverpod` provider so
/// that tests can inject short [initialDelay], [maxDelay], and a custom
/// [delayFn] to avoid real wall-clock waits.
///
/// Production code calls this via [planTtsStatusProvider]; tests call it
/// directly with `delayFn: (_) async {}` and a short [timeout].
@visibleForTesting
Stream<TtsStatusInfo> $pollTtsStatus({
  required PlanApiService api,
  required AppDatabase db,
  required String planId,
  Duration initialDelay = const Duration(seconds: 2),
  Duration maxDelay = const Duration(seconds: 30),
  double backoffFactor = 1.5,
  Duration timeout = const Duration(minutes: 10),
  Future<void> Function(Duration) delayFn = Future.delayed,
  bool Function()? isCancelled,
}) async* {
  var delay = initialDelay;
  final deadline = DateTime.now().add(timeout);

  while (!(isCancelled?.call() ?? false) && DateTime.now().isBefore(deadline)) {
    // Wait before each poll (first poll fires after `initialDelay`).
    await delayFn(delay);

    // Bail out promptly if the provider was disposed during the delay.
    if (isCancelled?.call() ?? false) return;

    // ── Fetch status from the server ────────────────────────────────────────
    TtsStatusInfo status;
    try {
      status = await api.getTtsStatus(planId);
    } on PlanApiException catch (e) {
      // Non-fatal: log and continue polling on next interval.
      debugPrint('planTtsStatus[$planId]: API error — ${e.message}');
      delay = _computeNextDelay(delay, backoffFactor, maxDelay);
      continue;
    } catch (e) {
      // Unexpected errors (e.g. socket errors wrapped by ApiClient) are also
      // swallowed to keep the stream alive through transient network issues.
      debugPrint('planTtsStatus[$planId]: unexpected error — $e');
      delay = _computeNextDelay(delay, backoffFactor, maxDelay);
      continue;
    }

    // ── Update local SQLite cache ───────────────────────────────────────────
    //
    // This write triggers Drift's table-change notification which causes any
    // active watchUserPlans() StreamProvider to re-emit with the updated
    // ttsStatus, ttsTotal, and ttsCompleted values.
    try {
      await (db.update(db.plansTable)
            ..where((t) => t.id.equals(planId)))
          .write(
        PlansTableCompanion(
          ttsStatus: Value(status.status),
          ttsTotal: Value(status.total),
          ttsCompleted: Value(status.completed),
        ),
      );
    } catch (e) {
      // Cache update failure is non-fatal: the status is still yielded to
      // the UI so the progress display remains accurate even if the local
      // write fails (e.g. DB not yet initialised in tests).
      debugPrint('planTtsStatus[$planId]: local cache update failed — $e');
    }

    yield status;

    // ── Stop polling on terminal states ─────────────────────────────────────
    if (_kTerminalStates.contains(status.status)) return;

    delay = _computeNextDelay(delay, backoffFactor, maxDelay);
  }
}

/// Returns the next backoff delay: `current × backoffFactor`, capped at [max].
Duration _computeNextDelay(Duration current, double factor, Duration max) {
  final nextMs = (current.inMilliseconds * factor).round();
  return Duration(milliseconds: nextMs.clamp(0, max.inMilliseconds));
}

// ─────────────────────────────────────────────────────────────────────────────
// isTtsReady provider
// ─────────────────────────────────────────────────────────────────────────────

/// Returns `true` when the GenAI TTS audio for [planId] is ready to play.
///
/// ### Check order
/// 1. **Local cache** — if the local SQLite plan row already has
///    `ttsStatus == 'completed'`, returns `true` immediately without starting
///    any network polling.  This is the fast path: no HTTP requests, no
///    subscriptions, instant result.
/// 2. **Live polling** — if the cached status is not yet `'completed'` (or the
///    plan hasn't loaded yet), falls back to watching [planTtsStatusProvider]
///    which polls `GET /api/tts/status/:planId` with adaptive exponential
///    backoff.  Returns `true` as soon as the first `'completed'` response
///    arrives from the server.
///
/// Returns `false` while:
/// - the plan is still loading from the local cache,
/// - TTS generation is still in progress (`pending` / `processing`),
/// - polling has not yet returned a `'completed'` status,
/// - the plan does not exist, or
/// - an API error occurred (the stream stays open but no `'completed'` value
///   has been received).
///
/// When the plan is already `'completed'` in the local cache, [isTtsReady]
/// does **not** subscribe to [planTtsStatusProvider] — polling never starts,
/// saving battery and network.
///
/// Usage:
/// ```dart
/// final ready = ref.watch(isTtsReadyProvider('plan-uuid-1234'));
/// if (ready) {
///   // safe to switch to GenAI TTS playback
/// }
/// ```
@riverpod
bool isTtsReady(Ref ref, String planId) {
  // ── 1. Check local plan cache ────────────────────────────────────────────
  final planAsync = ref.watch(planByIdProvider(planId));
  if (planAsync.valueOrNull?.ttsStatus == 'completed') return true;

  // ── 2. Fall back to live polling ─────────────────────────────────────────
  final pollAsync = ref.watch(planTtsStatusProvider(planId));
  return pollAsync.valueOrNull?.status == 'completed';
}

// ─────────────────────────────────────────────────────────────────────────────
// isFullyDownloaded FutureProvider
// ─────────────────────────────────────────────────────────────────────────────

/// Returns `true` if every TTS audio file for [planId] is locally cached and
/// present on disk.
///
/// Delegates to [AudioDownloadService.isFullyDownloaded] which checks the
/// [TtsCacheTable] for each expected cache key **and** verifies the audio file
/// exists on disk.  A `false` result means either the plan has not been
/// activated yet, audio generation is still in progress, or one or more files
/// failed to download.
///
/// Returns `false` on any error (API failure, IO exception, etc.) — it never
/// throws.
///
/// Usage:
/// ```dart
/// final downloaded = ref.watch(isFullyDownloadedProvider('plan-uuid-1234'));
/// downloaded.when(
///   data: (ready) => ready
///       ? const Icon(Icons.check_circle)
///       : const CircularProgressIndicator(),
///   loading: () => const CircularProgressIndicator(),
///   error: (e, _) => const Icon(Icons.error),
/// );
/// ```
@riverpod
Future<bool> isFullyDownloaded(Ref ref, String planId) {
  final service = ref.watch(audioDownloadServiceProvider);
  return service.isFullyDownloaded(planId);
}
