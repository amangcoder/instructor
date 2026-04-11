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

// ── Internal stream controller ────────────────────────────────────────────────

final _tapController = StreamController<void>.broadcast();

// ── Channel handler ───────────────────────────────────────────────────────────

/// Registers the [MethodChannel] handler for Android notification body taps.
///
/// Must be called once, after [WidgetsFlutterBinding.ensureInitialized].
/// Subsequent calls are safe — the handler is replaced atomically.
///
/// Only active on Android; on iOS this is a no-op.
void initNotificationTapChannel() {
  if (!defaultTargetPlatform.isAndroid) return;

  const channel = MethodChannel(kNotificationMethodChannel);
  channel.setMethodCallHandler((call) async {
    if (call.method == 'notificationTapped') {
      _tapController.add(null);
    }
  });
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

// ── Extension helper ──────────────────────────────────────────────────────────

extension on TargetPlatform {
  bool get isAndroid => this == TargetPlatform.android;
}
