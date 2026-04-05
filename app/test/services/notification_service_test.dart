/// Unit tests for [NotificationService] and [FlutterNotificationService].
///
/// ## Test strategy
///
/// [FlutterLocalNotificationsPlugin] delegates to a platform channel, so we
/// avoid calling [FlutterNotificationService] methods that invoke the plugin
/// directly (they would throw [MissingPluginException] in the Dart-only test
/// environment).
///
/// Instead, the tests focus on:
///   1. **Duration formatting** — pure logic, no platform calls.
///   2. **Step notification ID rotation** — internal counter wraps correctly.
///   3. **Static routing interface** — [NotificationService.routeStream],
///      [pendingRoute], and [clearPendingRoute] work as documented.
///   4. **_FakeNotificationService** — a fake implementation used to verify
///      the callers' interaction with the [NotificationService] interface.
///
/// Full integration tests (verifying real notifications appear in the system
/// tray) are performed in the manual QA pass on a physical device.
library notification_service_test;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/services/notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fake implementation
// ─────────────────────────────────────────────────────────────────────────────

/// A [NotificationService] fake whose side-effects are fully observable.
///
/// Used to verify that callers (e.g. [PlanExecutionEngine]) invoke the correct
/// methods with the correct arguments.
class _FakeNotificationService implements NotificationService {
  // Call counts
  int initializeCount = 0;
  int cancelAllCount = 0;

  // Captured arguments
  final List<({String title, String body})> stepNotifications = [];
  final List<String> resumePromptPlanNames = [];
  final List<({String stepText, Duration remaining})> foregroundUpdates = [];

  @override
  Future<void> initialize() async {
    initializeCount++;
  }

  @override
  Future<void> showStepNotification(String title, String body) async {
    stepNotifications.add((title: title, body: body));
  }

  @override
  Future<void> showResumePrompt(String planName) async {
    resumePromptPlanNames.add(planName);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
  }

  @override
  Future<void> updateForegroundNotification(
    String stepText,
    Duration remaining,
  ) async {
    foregroundUpdates.add((stepText: stepText, remaining: remaining));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Duration formatting ───────────────────────────────────────────────────

  group('FlutterNotificationService — formatDurationForDisplay', () {
    late FlutterNotificationService service;

    setUp(() {
      service = FlutterNotificationService();
    });

    test('zero duration formats as "00:00"', () {
      expect(service.formatDurationForDisplay(Duration.zero), '00:00');
    });

    test('sub-minute duration formats as "00:SS"', () {
      expect(
        service.formatDurationForDisplay(const Duration(seconds: 7)),
        '00:07',
      );
      expect(
        service.formatDurationForDisplay(const Duration(seconds: 45)),
        '00:45',
      );
      expect(
        service.formatDurationForDisplay(const Duration(seconds: 59)),
        '00:59',
      );
    });

    test('exactly one minute formats as "01:00"', () {
      expect(
        service.formatDurationForDisplay(const Duration(minutes: 1)),
        '01:00',
      );
    });

    test('minute-and-second duration formats as "MM:SS"', () {
      expect(
        service.formatDurationForDisplay(
          const Duration(minutes: 5, seconds: 3),
        ),
        '05:03',
      );
      expect(
        service.formatDurationForDisplay(
          const Duration(minutes: 25, seconds: 30),
        ),
        '25:30',
      );
    });

    test('59 minutes 59 seconds formats as "59:59"', () {
      expect(
        service.formatDurationForDisplay(
          const Duration(minutes: 59, seconds: 59),
        ),
        '59:59',
      );
    });

    test('exactly one hour formats as "1:00:00"', () {
      expect(
        service.formatDurationForDisplay(const Duration(hours: 1)),
        '1:00:00',
      );
    });

    test('hour-level duration formats as "H:MM:SS"', () {
      expect(
        service.formatDurationForDisplay(
          const Duration(hours: 1, minutes: 5, seconds: 3),
        ),
        '1:05:03',
      );
    });

    test('multi-hour duration formats correctly', () {
      expect(
        service.formatDurationForDisplay(
          const Duration(hours: 2, minutes: 30, seconds: 0),
        ),
        '2:30:00',
      );
    });
  });

  // ── Notification ID rotation ──────────────────────────────────────────────

  group('FlutterNotificationService — step notification ID rotation', () {
    late FlutterNotificationService service;

    setUp(() {
      service = FlutterNotificationService();
    });

    test('first ID is 1 (kStepNotificationIdMin)', () {
      expect(service.nextStepIdForTesting(), 1);
    });

    test('IDs increment from 1 to 10', () {
      final ids = List.generate(10, (_) => service.nextStepIdForTesting());
      expect(ids, List.generate(10, (i) => i + 1));
    });

    test('ID wraps back to 1 after reaching 10', () {
      // Advance to 10.
      for (var i = 0; i < 10; i++) {
        service.nextStepIdForTesting();
      }
      // 11th call should wrap to 1.
      expect(service.nextStepIdForTesting(), 1);
    });

    test('IDs cycle correctly over multiple full rotations', () {
      final ids = List.generate(25, (_) => service.nextStepIdForTesting());

      // Cycle 1: 1–10
      expect(ids.sublist(0, 10), List.generate(10, (i) => i + 1));
      // Cycle 2: 1–10
      expect(ids.sublist(10, 20), List.generate(10, (i) => i + 1));
      // Partial cycle 3: 1–5
      expect(ids.sublist(20), List.generate(5, (i) => i + 1));
    });

    test('IDs are always in range [1, 10]', () {
      final ids = List.generate(100, (_) => service.nextStepIdForTesting());
      for (final id in ids) {
        expect(id, inInclusiveRange(1, 10));
      }
    });
  });

  // ── Static routing interface ──────────────────────────────────────────────

  group('NotificationService — static routing interface', () {
    tearDown(() {
      // Clean up static state after each test.
      NotificationService.clearPendingRoute();
    });

    test('pendingRoute is null initially', () {
      NotificationService.clearPendingRoute();
      expect(NotificationService.pendingRoute, isNull);
    });

    test('setPendingRouteForTesting stores a route', () {
      NotificationService.setPendingRouteForTesting('/now-playing');
      expect(NotificationService.pendingRoute, '/now-playing');
    });

    test('clearPendingRoute sets pendingRoute to null', () {
      NotificationService.setPendingRouteForTesting('/now-playing');
      expect(NotificationService.pendingRoute, isNotNull);

      NotificationService.clearPendingRoute();
      expect(NotificationService.pendingRoute, isNull);
    });

    test('clearPendingRoute is idempotent when route is already null', () {
      NotificationService.clearPendingRoute();
      NotificationService.clearPendingRoute(); // second call is safe
      expect(NotificationService.pendingRoute, isNull);
    });

    test('routeStream emits value produced by emitRouteForTesting', () async {
      const testRoute = '/now-playing';

      // Listen before emitting.
      final future = NotificationService.routeStream.first;
      NotificationService.emitRouteForTesting(testRoute);

      expect(await future, testRoute);
    });

    test('routeStream emits multiple routes sequentially', () async {
      const routes = ['/now-playing', '/', '/settings'];

      final received = <String>[];
      final sub = NotificationService.routeStream.listen(received.add);

      for (final route in routes) {
        NotificationService.emitRouteForTesting(route);
      }

      // Allow microtasks to run.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, routes);
    });

    test('routeStream is a broadcast stream (multiple listeners)', () async {
      final received1 = <String>[];
      final received2 = <String>[];

      final sub1 = NotificationService.routeStream.listen(received1.add);
      final sub2 = NotificationService.routeStream.listen(received2.add);

      NotificationService.emitRouteForTesting('/now-playing');
      await Future<void>.delayed(Duration.zero);

      await sub1.cancel();
      await sub2.cancel();

      expect(received1, ['/now-playing']);
      expect(received2, ['/now-playing']);
    });
  });

  // ── _FakeNotificationService contract tests ───────────────────────────────

  group('_FakeNotificationService — call recording', () {
    late _FakeNotificationService fake;

    setUp(() {
      fake = _FakeNotificationService();
    });

    test('initialize() increments initializeCount', () async {
      expect(fake.initializeCount, 0);
      await fake.initialize();
      expect(fake.initializeCount, 1);
    });

    test('initialize() is idempotent in the fake', () async {
      await fake.initialize();
      await fake.initialize();
      expect(fake.initializeCount, 2);
    });

    test('showStepNotification() records title and body', () async {
      await fake.showStepNotification('Drink Water', 'Time to hydrate!');

      expect(fake.stepNotifications, hasLength(1));
      expect(fake.stepNotifications.first.title, 'Drink Water');
      expect(fake.stepNotifications.first.body, 'Time to hydrate!');
    });

    test('showStepNotification() accumulates multiple calls', () async {
      await fake.showStepNotification('Step 1', 'Body 1');
      await fake.showStepNotification('Step 2', 'Body 2');
      await fake.showStepNotification('Step 3', 'Body 3');

      expect(fake.stepNotifications, hasLength(3));
      expect(fake.stepNotifications[0].title, 'Step 1');
      expect(fake.stepNotifications[1].title, 'Step 2');
      expect(fake.stepNotifications[2].title, 'Step 3');
    });

    test('showResumePrompt() records plan name', () async {
      await fake.showResumePrompt('Morning Yoga');

      expect(fake.resumePromptPlanNames, ['Morning Yoga']);
    });

    test('showResumePrompt() with special characters in plan name', () async {
      await fake.showResumePrompt('5-Minute "Focus" — v2');

      expect(fake.resumePromptPlanNames.first, '5-Minute "Focus" — v2');
    });

    test('cancelAll() increments cancelAllCount', () async {
      await fake.cancelAll();
      expect(fake.cancelAllCount, 1);

      await fake.cancelAll();
      expect(fake.cancelAllCount, 2);
    });

    test('updateForegroundNotification() records stepText and remaining', () async {
      const stepText = 'Inhale slowly';
      const remaining = Duration(minutes: 4, seconds: 15);

      await fake.updateForegroundNotification(stepText, remaining);

      expect(fake.foregroundUpdates, hasLength(1));
      expect(fake.foregroundUpdates.first.stepText, stepText);
      expect(fake.foregroundUpdates.first.remaining, remaining);
    });

    test('updateForegroundNotification() with zero remaining', () async {
      await fake.updateForegroundNotification('Last step', Duration.zero);

      expect(fake.foregroundUpdates.first.remaining, Duration.zero);
    });

    test('no calls before any method is invoked', () {
      expect(fake.initializeCount, 0);
      expect(fake.stepNotifications, isEmpty);
      expect(fake.resumePromptPlanNames, isEmpty);
      expect(fake.cancelAllCount, 0);
      expect(fake.foregroundUpdates, isEmpty);
    });
  });

  // ── FlutterNotificationService implements NotificationService ─────────────

  group('FlutterNotificationService — interface compliance', () {
    test('is a NotificationService', () {
      expect(FlutterNotificationService(), isA<NotificationService>());
    });

    test('two instances have independent step ID counters', () {
      final a = FlutterNotificationService();
      final b = FlutterNotificationService();

      a.nextStepIdForTesting(); // advance a to 2
      a.nextStepIdForTesting();

      // b should still start at 1.
      expect(b.nextStepIdForTesting(), 1);
    });
  });

  // ── Channel ID / action constants ─────────────────────────────────────────

  group('Notification constants', () {
    test('plan notifications channel ID matches architecture spec', () {
      // Architecture mandates id: "plan_notifications"
      expect(kPlanNotificationsChannelId, 'plan_notifications');
    });

    test('plan notifications channel name matches architecture spec', () {
      // Architecture mandates name: "Plan Notifications"
      expect(kPlanNotificationsChannelName, 'Plan Notifications');
    });

    test('resume action ID is stable', () {
      expect(kResumeActionId, 'resume_now_playing');
    });
  });
}
