/// LiveActivityChannel — manages iOS Live Activity lifecycle via MethodChannel.
///
/// ## Architecture
///
/// This service bridges the Flutter execution engine to the native iOS
/// ActivityKit API. It subscribes to [PlanExecutionEngine.stateStream] and
/// forwards execution state updates to the native LiveActivityManager.
///
/// ## Channel contract
///
/// Flutter → Native (invokeMethod):
///   'startActivity'  → Start a Live Activity with plan metadata + initial state
///   'updateActivity' → Update the activity's dynamic content (step, progress, time)
///   'endActivity'    → End the Live Activity
///
/// ## Platform behaviour
///
/// On iOS 16.1+: Fully functional Live Activity with Dynamic Island + Lock Screen.
/// On iOS < 16.1 or non-iOS: All methods are no-ops (graceful degradation).
library live_activity_channel;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'live_activity_channel.g.dart';

// ── Channel identifier ────────────────────────────────────────────────────────

/// MethodChannel name that must match the native LiveActivityManager handler.
const String kLiveActivityChannel = 'com.layersiq.instructor/live_activity';

// ── LiveActivityChannel ─────────────────────────────────────────────────────

/// Manages iOS Live Activity for plan execution.
///
/// All public methods are safe to call on any platform — they return early
/// on non-iOS targets so the feature degrades gracefully.
class LiveActivityChannel {
  LiveActivityChannel._();

  static const _channel = MethodChannel(kLiveActivityChannel);

  /// Whether a Live Activity is currently active.
  bool _isActive = false;

  /// Returns true if a Live Activity is currently showing.
  bool get isActive => _isActive;

  // ── Start ─────────────────────────────────────────────────────────────

  /// Starts a new Live Activity for plan execution.
  ///
  /// [planName]       — Plan name shown in the activity header.
  /// [totalSteps]     — Total number of steps in the plan.
  /// [stepName]       — Current step name/text.
  /// [stepIndex]      — 0-based index of the current step.
  /// [timeRemainingMs] — Time remaining in current step (milliseconds).
  /// [status]         — "playing" or "paused".
  ///
  /// No-op on non-iOS platforms or iOS < 16.1.
  /// AC-018: Live Activity starts within 1 second of session start.
  Future<void> startActivity({
    required String planName,
    required int totalSteps,
    required String stepName,
    required int stepIndex,
    required int timeRemainingMs,
    required String status,
  }) async {
    if (!defaultTargetPlatform.isIOS) return;

    try {
      await _channel.invokeMethod<void>('startActivity', {
        'planName': planName,
        'totalSteps': totalSteps,
        'stepName': _truncateText(stepName),
        'stepIndex': stepIndex,
        'timeRemainingMs': timeRemainingMs,
        'status': status,
      });
      _isActive = true;
      debugPrint(
        '[LiveActivityChannel] Started: plan="$planName", '
        'steps=$totalSteps, step=$stepIndex',
      );
    } on PlatformException catch (e) {
      debugPrint('[LiveActivityChannel] startActivity failed: $e');
      _isActive = false;
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────

  /// Updates the Live Activity with new execution state.
  ///
  /// Called on every step transition, pause/resume, and timer tick.
  /// AC-019: Step transition updates Live Activity within 1 second.
  Future<void> updateActivity({
    required String stepName,
    required int stepIndex,
    required int timeRemainingMs,
    required String status,
  }) async {
    if (!defaultTargetPlatform.isIOS || !_isActive) return;

    try {
      await _channel.invokeMethod<void>('updateActivity', {
        'stepName': _truncateText(stepName),
        'stepIndex': stepIndex,
        'timeRemainingMs': timeRemainingMs,
        'status': status,
      });
    } on PlatformException catch (e) {
      debugPrint('[LiveActivityChannel] updateActivity failed: $e');
    }
  }

  // ── End ─────────────────────────────────────────────────────────────

  /// Ends the current Live Activity, transitioning to a dismissable final state
  /// that shows the completed plan name and total session duration.
  ///
  /// [planName]   — Plan name shown in the completed-state UI.
  /// [durationMs] — Total session duration in milliseconds.
  ///
  /// AC-022: Completion transitions to ended state, auto-dismissed after 4 sec.
  Future<void> endActivity({
    required String planName,
    required int durationMs,
  }) async {
    if (!defaultTargetPlatform.isIOS || !_isActive) return;

    try {
      await _channel.invokeMethod<void>('endActivity', {
        'planName': planName,
        'durationMs': durationMs,
      });
      _isActive = false;
      debugPrint('[LiveActivityChannel] Activity ended');
    } on PlatformException catch (e) {
      debugPrint('[LiveActivityChannel] endActivity failed: $e');
      _isActive = false;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Truncates text to stay within the 4KB ActivityKit payload limit.
  String _truncateText(String text) {
    if (text.length <= 100) return text;
    return '${text.substring(0, 97)}...';
  }
}

// ── Platform extension ────────────────────────────────────────────────────────

extension on TargetPlatform {
  bool get isIOS => this == TargetPlatform.iOS;
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
LiveActivityChannel liveActivityChannel(Ref ref) => LiveActivityChannel._();
