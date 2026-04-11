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
// ## UserDefaults keys
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
import 'package:instructor/models/enums.dart';

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

/// Bridges [PlanExecutionEngine] state updates to the iOS home-screen widget.
///
/// Instantiate once at startup via [widgetStateChannelProvider].  The channel
/// automatically listens to [PlanExecutionEngine.stateStream], throttles
/// writes, and forwards each update to the native AppDelegate via
/// [kWidgetStateChannel].
///
/// On iOS only — all methods are no-ops on other platforms.
class WidgetStateChannel {
  WidgetStateChannel._();

  static const _channel = MethodChannel(kWidgetStateChannel);
  static const _deepLinkChannel = MethodChannel(kWidgetDeepLinkChannel);

  // Throttle state
  Timer? _throttleTimer;
  Map<String, dynamic>? _pendingWrite;
  DateTime? _lastWrite;

  StreamSubscription<void>? _toggleSub;

  /// Initialise the channel: start listening for state updates and for the
  /// widget deep-link toggle intent from the native side.
  void init(PlanExecutionEngine engine) {
    if (!defaultTargetPlatform.isIOS) return;

    // Listen for state changes from the execution engine.
    engine.stateStream.listen(_onState);

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
    _writeState({
      'plan_name': '',
      'step_text': 'No active plan',
      'next_step_text': '',
      'status': 'stopped',
      'step_duration_ms': 0,
      'elapsed_ms': 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch / 1000.0,
    });
  }

  void _onState(ExecutionState state) {
    final payload = _buildPayload(state);
    _scheduleWrite(payload);
  }

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
    };
  }

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
  }
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
WidgetStateChannel widgetStateChannel(Ref ref) {
  final channel = WidgetStateChannel._();
  final engine = ref.read(planExecutionEngineProvider);

  // Wire up on first read.
  channel.init(engine);

  ref.onDispose(channel.dispose);
  return channel;
}

// ── Extension helper ──────────────────────────────────────────────────────────

extension on TargetPlatform {
  bool get isIOS => this == TargetPlatform.iOS;
}
