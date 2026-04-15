// REQ-004: MethodChannel listener for Android notification body-tap navigation.
//
// When the user taps the body (non-button area) of the Android foreground
// notification, audio_service brings MainActivity to the foreground and
// MainActivity.onNewIntent() invokes this channel with "notificationTapped".
// The Flutter side emits an event on [notificationTapStream] which the root
// app widget listens to and uses to navigate to /now-playing.
//
// iOS: default system behaviour brings the app to the foreground on any
// notification tap — no MethodChannel is needed.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_tap_channel.g.dart';

// ── Channel identifier ────────────────────────────────────────────────────────

/// MethodChannel name that must match [MainActivity.NOTIFICATION_CHANNEL].
const String kNotificationMethodChannel = 'com.instructor.app/notification';

// ── Internal stream controllers ───────────────────────────────────────────────

final _tapController = StreamController<void>.broadcast();

/// Plan-trigger events forwarded from the native MainActivity when a scheduled
/// [PlanAlarmReceiver] deep-link (instructor://plan-start) opens the app.
final _planTriggerController = StreamController<PlanTriggerFiredEvent>.broadcast();

/// Buffer for a plan-trigger event that arrived before any subscriber attached
/// (cold-start scenario — the app was launched by tapping the notification).
/// Consumed by [takePendingPlanTrigger] once Dart is ready to route it.
PlanTriggerFiredEvent? _pendingPlanTrigger;

/// Event payload for a fired plan trigger. Carries the [planId] to start and
/// the [triggerId] so callers can reference the originating scheduled entry
/// (e.g. to mark it fired in local storage or clear the notification).
class PlanTriggerFiredEvent {
  const PlanTriggerFiredEvent({required this.planId, required this.triggerId});

  final String planId;
  final String triggerId;

  @override
  String toString() =>
      'PlanTriggerFiredEvent(planId: $planId, triggerId: $triggerId)';
}

// ── Channel handler ───────────────────────────────────────────────────────────

/// Registers the [MethodChannel] handler for Android notification body taps
/// and plan-trigger deep links.
///
/// Must be called once, after [WidgetsFlutterBinding.ensureInitialized].
/// Subsequent calls are safe — the handler is replaced atomically.
///
/// Only active on Android; on iOS this is a no-op.
void initNotificationTapChannel() {
  if (!defaultTargetPlatform.isAndroid) return;

  const channel = MethodChannel(kNotificationMethodChannel);
  channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'notificationTapped':
        _tapController.add(null);
      case 'planTriggerFired':
        final event = _parseTriggerArgs(call.arguments);
        if (event == null) return;
        if (_planTriggerController.hasListener) {
          _planTriggerController.add(event);
        } else {
          // Cold-start: buffer until the Riverpod stream provider attaches.
          _pendingPlanTrigger = event;
        }
    }
  });
}

PlanTriggerFiredEvent? _parseTriggerArgs(Object? args) {
  if (args is! Map) return null;
  final planId = args['planId'];
  final triggerId = args['triggerId'];
  if (planId is! String || triggerId is! String || planId.isEmpty) return null;
  return PlanTriggerFiredEvent(planId: planId, triggerId: triggerId);
}

/// Drains and returns any plan-trigger event that arrived before a subscriber
/// was ready (cold-start). Returns null when none is buffered.
PlanTriggerFiredEvent? takePendingPlanTrigger() {
  final pending = _pendingPlanTrigger;
  _pendingPlanTrigger = null;
  return pending;
}

// ── Test helpers ──────────────────────────────────────────────────────────────

/// For testing only — registers the MethodChannel handler on any platform
/// (bypasses the Android guard) and emits a tap event on [notificationTapStream].
///
/// Call this instead of [initNotificationTapChannel] in unit tests.
@visibleForTesting
void initNotificationTapChannelForTesting() {
  const channel = MethodChannel(kNotificationMethodChannel);
  channel.setMethodCallHandler((call) async {
    if (call.method == 'notificationTapped') {
      _tapController.add(null);
    }
  });
}

/// For testing only — emits a tap event directly on [notificationTapStream]
/// without going through the MethodChannel platform layer.
@visibleForTesting
void emitNotificationTapForTesting() => _tapController.add(null);

/// For testing only — the raw broadcast stream so tests can subscribe
/// independently of the Riverpod provider infrastructure.
@visibleForTesting
Stream<void> get notificationTapRawStream => _tapController.stream;

// ── Riverpod providers ────────────────────────────────────────────────────────

/// A broadcast stream that emits `void` each time the Android foreground
/// notification body is tapped (and the app is brought to the foreground).
///
/// Consume this with `ref.listen` in the root widget to navigate to the Now
/// Playing screen:
///
/// ```dart
/// ref.listen<AsyncValue<void>>(notificationTapStreamProvider, (_, next) {
///   next.whenData((_) => _navigateToNowPlaying(context, ref));
/// });
/// ```
@Riverpod(keepAlive: true)
Stream<void> notificationTapStream(Ref ref) => _tapController.stream;

/// Broadcast stream of plan-trigger events (Android scheduled session fired
/// and the user tapped the notification). On subscribe, emits any cold-start
/// event that was buffered before the stream had a listener.
@Riverpod(keepAlive: true)
Stream<PlanTriggerFiredEvent> planTriggerFiredStream(Ref ref) async* {
  final pending = takePendingPlanTrigger();
  if (pending != null) yield pending;
  yield* _planTriggerController.stream;
}

// ── Extension helper ──────────────────────────────────────────────────────────

extension on TargetPlatform {
  bool get isAndroid => this == TargetPlatform.android;
}
