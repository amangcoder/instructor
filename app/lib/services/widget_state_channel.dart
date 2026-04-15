// TASK-017: iOS WidgetKit bridge — writes execution state to App Group
// UserDefaults so the InstructorWidget extension can read and display it.
//
// ## Architecture
//
// Flutter side calls [WidgetStateChannel.update] whenever [ExecutionState]
// changes. The call is rate-limited to at most 1 write per second to keep
// performance impact negligible (WidgetKit reloads at most every 15 minutes
// anyway, but we want state to be fresh when the widget does reload).
//
// The native AppDelegate Swift handler receives the map, writes each key to
// UserDefaults(suiteName: 'group.com.layersiq.instructor'), and calls
// WidgetCenter.shared.reloadAllTimelines() to trigger a widget refresh.
//
// ## UserDefaults keys — Playback
//
// All keys are prefixed with 'instructor_' to avoid collisions:
//   instructor_plan_name       — String  — display name of the active plan
//   instructor_step_text       — String  — current step description
//   instructor_next_step_text  — String? — next step description (or "")
//   instructor_status          — String  — "playing" | "paused" | "stopped"
//   instructor_step_duration_ms — Int    — total step duration in ms
//   instructor_elapsed_ms      — Int     — elapsed time in current step (ms)
//   instructor_updated_at      — Double  — Unix epoch seconds of last write
//
// ## UserDefaults keys — Streak (TASK-011)
//
// Three new keys are written alongside every playback write so both datasets
// are always atomically consistent in a single UserDefaults update:
//   instructor_streak_count        — Int  — current consecutive-day streak
//   instructor_completed_today     — Bool — true if user completed today
//   instructor_streak_freeze_count — Int  — available streak freezes (0–2)
//
// ## Deep-link URL scheme
//
// Widget tap → open instructor://toggle-playback → AppDelegate catches the
// URL and invokes the 'togglePlayback' MethodChannel method on Flutter.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/services/plan_execution_engine.dart';
import 'package:instructor/services/streak_service.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/streak_state.dart';

part 'widget_state_channel.g.dart';

// ── Channel identifiers ───────────────────────────────────────────────────────

/// MethodChannel name that must match [AppDelegate.widgetChannelName].
const String kWidgetStateChannel = 'com.layersiq.instructor/widget';

/// MethodChannel name used by AppDelegate to invoke Flutter when a widget tap
/// delivers the toggle-playback deep link.
const String kWidgetDeepLinkChannel = 'com.layersiq.instructor/widget_deeplink';

// ── Throttle interval ─────────────────────────────────────────────────────────

/// Maximum rate of UserDefaults writes: 1 per second.
const Duration _kWriteThrottle = Duration(seconds: 1);

// ── WidgetStateChannel ────────────────────────────────────────────────────────

/// Bridges [PlanExecutionEngine] state updates and [StreakService] state to the
/// iOS home-screen widget.
///
/// Instantiate once at startup via [widgetStateChannelProvider].  The channel
/// automatically listens to both [PlanExecutionEngine.stateStream] and
/// [StreakService.watchStreak], throttles writes, and forwards each merged
/// update to the native AppDelegate via [kWidgetStateChannel].
///
/// Every UserDefaults write includes both playback state AND streak data in a
/// single call so the widget always sees a consistent snapshot. The existing
/// 1-second throttle naturally coalesces rapid updates from both sources.
///
/// On iOS only — all methods are no-ops on other platforms.
class WidgetStateChannel {
  WidgetStateChannel._();

  /// Creates a [WidgetStateChannel] for use in unit tests.
  ///
  /// Callers are responsible for calling [init] and [dispose] manually.
  @visibleForTesting
  static WidgetStateChannel forTesting() => WidgetStateChannel._();

  static const _channel = MethodChannel(kWidgetStateChannel);
  static const _deepLinkChannel = MethodChannel(kWidgetDeepLinkChannel);

  // Throttle state
  Timer? _throttleTimer;
  Map<String, dynamic>? _pendingWrite;
  DateTime? _lastWrite;

  StreamSubscription<void>? _toggleSub;
  StreamSubscription<StreakState>? _streakSub;

  // Cached last-known state from each stream source
  StreakState? _latestStreakState;
  ExecutionState? _latestExecutionState;

  /// Initialise the channel: start listening for execution state, streak state,
  /// and the widget deep-link toggle intent from the native side.
  ///
  /// [engine] provides playback state via [PlanExecutionEngine.stateStream].
  /// [streakService] provides streak data via [StreakService.watchStreak].
  ///
  /// On non-iOS platforms this is a no-op.
  void init(PlanExecutionEngine engine, StreakService streakService) {
    if (!defaultTargetPlatform.isIOS) return;

    // Listen for execution state changes from the engine.
    engine.stateStream.listen(_onState);

    // Listen for streak state changes. Every streak update triggers a write
    // so the widget sees the new streak count within the throttle window.
    _streakSub = streakService.watchStreak().listen(_onStreakState);

    // Register handler for widget-tap deep link (toggle-playback intent).
    _deepLinkChannel.setMethodCallHandler((call) async {
      if (call.method == 'togglePlayback') {
        final status = engine.currentState?.status;
        if (status == ExecutionStatus.running) {
          await engine.pause();
        } else if (status == ExecutionStatus.paused) {
          await engine.resume();
        }
      }
    });

    // Emit an initial "stopped" state so the widget shows something even
    // when the app is first installed and no plan has been run.
    _writeState(_buildIdlePayload());
  }

  // ── Private handlers ─────────────────────────────────────────────────────────

  void _onState(ExecutionState state) {
    _latestExecutionState = state;
    final payload = _buildPayload(state);
    _scheduleWrite(payload);
  }

  void _onStreakState(StreakState streakState) {
    _latestStreakState = streakState;
    // Merge streak data into whatever playback state we last saw.
    final payload = _latestExecutionState != null
        ? _buildPayload(_latestExecutionState!)
        : _buildIdlePayload();
    _scheduleWrite(payload);
  }

  // ── Payload builders ─────────────────────────────────────────────────────────

  Map<String, dynamic> _buildPayload(ExecutionState state) {
    final statusStr = switch (state.status) {
      ExecutionStatus.running => 'playing',
      ExecutionStatus.paused => 'paused',
      _ => 'stopped',
    };

    final durationMs = state.currentStepDuration.inMilliseconds;
    final remainingMs = state.timeRemaining.inMilliseconds;
    final elapsedMs = (durationMs - remainingMs).clamp(0, durationMs);

    return {
      'plan_name': state.plan.name,
      'step_text': state.currentStepText ?? '',
      'next_step_text': state.nextStepText ?? '',
      'status': statusStr,
      'step_duration_ms': durationMs,
      'elapsed_ms': elapsedMs,
      'updated_at': DateTime.now().millisecondsSinceEpoch / 1000.0,
      ..._streakPayload(),
    };
  }

  /// Builds a payload for when no plan is active (initial state or after stop).
  Map<String, dynamic> _buildIdlePayload() {
    return {
      'plan_name': '',
      'step_text': 'No active plan',
      'next_step_text': '',
      'status': 'stopped',
      'step_duration_ms': 0,
      'elapsed_ms': 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch / 1000.0,
      ..._streakPayload(),
    };
  }

  /// Returns the three streak keys derived from [_latestStreakState].
  ///
  /// Defaults to zeros/false when no streak state has been received yet
  /// (e.g. on first launch before the stream emits).
  Map<String, dynamic> _streakPayload() => {
        'streak_count': _latestStreakState?.currentStreak ?? 0,
        'completed_today': _latestStreakState?.completedToday ?? false,
        'streak_freeze_count': _latestStreakState?.freezesAvailable ?? 0,
      };

  // ── Throttle logic ───────────────────────────────────────────────────────────

  /// Throttle writes to at most 1 per [_kWriteThrottle].
  void _scheduleWrite(Map<String, dynamic> payload) {
    _pendingWrite = payload;

    final now = DateTime.now();
    final timeSinceLast =
        _lastWrite == null ? _kWriteThrottle : now.difference(_lastWrite!);

    if (timeSinceLast >= _kWriteThrottle) {
      // We're past the throttle window — write immediately.
      _flush();
    } else {
      // Schedule a write for when the window expires.
      _throttleTimer?.cancel();
      _throttleTimer = Timer(_kWriteThrottle - timeSinceLast, _flush);
    }
  }

  void _flush() {
    final payload = _pendingWrite;
    if (payload == null) return;
    _pendingWrite = null;
    _lastWrite = DateTime.now();
    _writeState(payload);
  }

  void _writeState(Map<String, dynamic> payload) {
    _channel.invokeMethod<void>('updateWidgetState', payload).catchError((e) {
      debugPrint('[WidgetStateChannel] Failed to update widget state: $e');
    });
  }

  /// Dispose subscriptions and timers.
  void dispose() {
    _throttleTimer?.cancel();
    _toggleSub?.cancel();
    _streakSub?.cancel();
  }
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
WidgetStateChannel widgetStateChannel(Ref ref) {
  final channel = WidgetStateChannel._();
  final engine = ref.read(planExecutionEngineProvider);
  final streakService = ref.read(streakServiceProvider);

  // Wire up on first read — subscribes to both execution and streak streams.
  channel.init(engine, streakService);

  ref.onDispose(channel.dispose);
  return channel;
}

// ── Extension helper ──────────────────────────────────────────────────────────

extension on TargetPlatform {
  bool get isIOS => this == TargetPlatform.iOS;
}
