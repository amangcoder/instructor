/// Unit tests for [CalendarService].
///
/// ## Test strategy
///
/// [CalendarService] delegates to a native MethodChannel, so we avoid calling
/// real channel methods in the Dart-only test environment (they would throw
/// [MissingPluginException]).
///
/// Instead these tests focus on:
///   1. **[CalendarRecurrence] label formatting** — pure logic, no platform calls.
///   2. **[CalendarRecurrence.channelValue]** — correct string values for each enum.
///   3. **Non-iOS no-op contract** — verifies that all methods return gracefully
///      when the test runner is not iOS (defaultTargetPlatform != iOS).
///   4. **_FakeCalendarService** — a fake implementation used by widget tests.
library calendar_service_test;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/services/calendar_service.dart';

void main() {
  // ── CalendarRecurrence label / channelValue ────────────────────────────────

  group('CalendarRecurrence', () {
    test('label returns human-readable string', () {
      expect(CalendarRecurrence.none.label, 'None');
      expect(CalendarRecurrence.daily.label, 'Daily');
      expect(CalendarRecurrence.weekdays.label, 'Weekdays (Mon–Fri)');
      expect(CalendarRecurrence.weekly.label, 'Weekly');
    });

    test('channelValue returns correct wire string', () {
      expect(CalendarRecurrence.none.channelValue, 'none');
      expect(CalendarRecurrence.daily.channelValue, 'daily');
      expect(CalendarRecurrence.weekdays.channelValue, 'weekdays');
      expect(CalendarRecurrence.weekly.channelValue, 'weekly');
    });

    test('all values covered — no missing switch cases', () {
      // If a new enum value is added without updating the switch expressions,
      // calling label / channelValue on it would throw.
      for (final r in CalendarRecurrence.values) {
        expect(r.label, isNotEmpty);
        expect(r.channelValue, isNotEmpty);
      }
    });
  });

  // ── Non-iOS platform no-op contract ───────────────────────────────────────

  group('CalendarService non-iOS contract', () {
    // The test runner uses TargetPlatform.linux/android/etc., never iOS,
    // so CalendarService.requestPermission() must return false and
    // createEvent() must not throw.
    //
    // We cannot construct CalendarService directly (private constructor) so
    // we use the Riverpod provider via a ProviderContainer.

    test('requestPermission returns false on non-iOS', () async {
      // The test binary is never running on an iOS device, so the platform
      // guard inside CalendarService returns false without touching the channel.
      final container = _makeContainer();
      final service = container.read(calendarServiceProvider);
      final result = await service.requestPermission();
      expect(result, isFalse);
    });

    test('createEvent does not throw on non-iOS', () async {
      final container = _makeContainer();
      final service = container.read(calendarServiceProvider);
      await expectLater(
        service.createEvent(
          title: 'Morning Yoga',
          durationMinutes: 30,
          startDateTime: DateTime(2026, 5, 1, 8),
        ),
        completes,
      );
    });

    test('openAppSettings does not throw on non-iOS', () async {
      final container = _makeContainer();
      final service = container.read(calendarServiceProvider);
      await expectLater(service.openAppSettings(), completes);
    });
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

ProviderContainer _makeContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}
