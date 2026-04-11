/// Unit tests for the notification body-tap channel service (REQ-004).
///
/// ## What is tested
///
/// 1. **Stream emission** — [notificationTapRawStream] emits when
///    [emitNotificationTapForTesting] is called, confirming the broadcast
///    StreamController is wired correctly.
///
/// 2. **MethodChannel round-trip** — [initNotificationTapChannelForTesting]
///    registers the channel handler (platform-agnostic); a fake platform
///    message via [TestDefaultBinaryMessengerBinding] confirms the channel
///    name and method name are matched correctly.
///
/// 3. **Deduplication guard** — pure logic tests for the `/now-playing` check
///    that prevents duplicate route entries from repeated taps.
library notification_tap_channel_test;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/router.dart';
import 'package:instructor/services/notification_tap_channel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper — simulate a native "notificationTapped" platform message
// ─────────────────────────────────────────────────────────────────────────────

/// Sends a fake [MethodCall('notificationTapped')] on the notification
/// MethodChannel, exactly as [MainActivity.onNewIntent] does on Android.
Future<void> _sendNativeNotificationTap() async {
  const codec = StandardMethodCodec();
  final encoded =
      codec.encodeMethodCall(const MethodCall('notificationTapped'));

  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    kNotificationMethodChannel,
    encoded,
    (_) {},
  );

  // Allow micro-task queue to flush so stream listeners fire.
  await Future<void>.delayed(Duration.zero);
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── 1. Stream emission via test helper ──────────────────────────────────────

  group('emitNotificationTapForTesting', () {
    test('stream emits one void event per tap', () async {
      final events = <void>[];
      final sub = notificationTapRawStream.listen(events.add);

      emitNotificationTapForTesting();
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      await sub.cancel();
    });

    test('three consecutive taps emit three events', () async {
      final events = <void>[];
      final sub = notificationTapRawStream.listen(events.add);

      emitNotificationTapForTesting();
      emitNotificationTapForTesting();
      emitNotificationTapForTesting();
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(3));
      await sub.cancel();
    });

    test('multiple subscribers receive the same events (broadcast)', () async {
      final events1 = <void>[];
      final events2 = <void>[];
      final sub1 = notificationTapRawStream.listen(events1.add);
      final sub2 = notificationTapRawStream.listen(events2.add);

      emitNotificationTapForTesting();
      await Future<void>.delayed(Duration.zero);

      expect(events1, hasLength(1));
      expect(events2, hasLength(1));

      await sub1.cancel();
      await sub2.cancel();
    });
  });

  // ── 2. Full MethodChannel round-trip ─────────────────────────────────────────

  group('MethodChannel round-trip', () {
    setUp(initNotificationTapChannelForTesting);

    test('"notificationTapped" method triggers stream event', () async {
      final events = <void>[];
      final sub = notificationTapRawStream.listen(events.add);

      await _sendNativeNotificationTap();

      expect(events, hasLength(1));
      await sub.cancel();
    });

    test('unknown method name is silently ignored (no event, no exception)',
        () async {
      const codec = StandardMethodCodec();
      final encoded =
          codec.encodeMethodCall(const MethodCall('unknownMethod'));

      final events = <void>[];
      final sub = notificationTapRawStream.listen(events.add);

      await expectLater(
        () async =>
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .handlePlatformMessage(
          kNotificationMethodChannel,
          encoded,
          (_) {},
        ),
        returnsNormally,
      );

      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);

      await sub.cancel();
    });

    test('channel name constant equals "com.instructor.app/notification"', () {
      expect(kNotificationMethodChannel,
          equals('com.instructor.app/notification'));
    });
  });

  // ── 3. Deduplication guard (pure logic) ──────────────────────────────────────

  group('deduplication — navigate-to-/now-playing guard', () {
    /// Mirrors the guard in [_InstructorAppState._navigateToNowPlaying].
    bool _shouldNavigate(String currentLocation) =>
        currentLocation != AppRoutes.nowPlaying;

    test('navigates from / (library)', () {
      expect(_shouldNavigate('/'), isTrue);
    });

    test('navigates from /settings', () {
      expect(_shouldNavigate('/settings'), isTrue);
    });

    test('navigates from /editor/new', () {
      expect(_shouldNavigate('/editor/new'), isTrue);
    });

    test('navigates from /generate-plan', () {
      expect(_shouldNavigate('/generate-plan'), isTrue);
    });

    test('does NOT navigate when already on /now-playing', () {
      expect(_shouldNavigate('/now-playing'), isFalse);
    });

    test('AppRoutes.nowPlaying constant is "/now-playing"', () {
      expect(AppRoutes.nowPlaying, equals('/now-playing'));
    });
  });
}
