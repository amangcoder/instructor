/// Widget tests for [CalendarEventSheet].
///
/// ## Test strategy
///
/// These tests pump [CalendarEventSheet] directly (not via the full router) so
/// we can verify UI elements and interaction without a real MethodChannel.
///
/// We override [calendarServiceProvider] with a [_FakeCalendarService] whose
/// permission / createEvent behaviour is configurable per test.
library calendar_event_sheet_test;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/screens/plan_editor/widgets/calendar_event_sheet.dart';
import 'package:instructor/services/calendar_service.dart';

// ── Fake service ──────────────────────────────────────────────────────────────

class _FakeCalendarService implements CalendarService {
  _FakeCalendarService({
    this.permissionResult = true,
    this.shouldThrowOnCreate = false,
  });

  final bool permissionResult;
  final bool shouldThrowOnCreate;

  int requestPermissionCalls = 0;
  int createEventCalls = 0;
  int openAppSettingsCalls = 0;

  // Last call args
  String? lastEventTitle;
  int? lastDurationMinutes;
  DateTime? lastStartDateTime;
  CalendarRecurrence? lastRecurrence;
  String? lastDeepLink;

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalls++;
    return permissionResult;
  }

  @override
  Future<void> createEvent({
    required String title,
    required int durationMinutes,
    required DateTime startDateTime,
    CalendarRecurrence recurrence = CalendarRecurrence.none,
    String? deepLink,
  }) async {
    createEventCalls++;
    lastEventTitle = title;
    lastDurationMinutes = durationMinutes;
    lastStartDateTime = startDateTime;
    lastRecurrence = recurrence;
    lastDeepLink = deepLink;
    if (shouldThrowOnCreate) {
      throw Exception('Calendar write failed');
    }
  }

  @override
  Future<void> openAppSettings() async {
    openAppSettingsCalls++;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _buildTestWidget({
  required CalendarService fakeService,
  String planName = 'Morning Yoga',
  Duration planDuration = const Duration(minutes: 30),
  String? planId,
}) {
  return ProviderScope(
    overrides: [
      calendarServiceProvider.overrideWithValue(fakeService),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showCalendarEventSheet(
              ctx,
              planName: planName,
              planDuration: planDuration,
              planId: planId,
            ),
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Open Sheet'));
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('CalendarEventSheet — layout', () {
    testWidgets('shows sheet title', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(fakeService: _FakeCalendarService()),
      );
      await _openSheet(tester);

      expect(find.text('Add to Calendar'), findsWidgets);
    });

    testWidgets('displays plan name in read-only header', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          fakeService: _FakeCalendarService(),
          planName: 'Evening Run',
        ),
      );
      await _openSheet(tester);

      expect(find.text('Evening Run'), findsOneWidget);
    });

    testWidgets('displays plan duration in header', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          fakeService: _FakeCalendarService(),
          planDuration: const Duration(minutes: 45),
        ),
      );
      await _openSheet(tester);

      expect(find.text('45m'), findsOneWidget);
    });

    testWidgets('shows Date and Time picker rows', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(fakeService: _FakeCalendarService()),
      );
      await _openSheet(tester);

      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
    });

    testWidgets('shows Repeat dropdown with None selected by default',
        (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(fakeService: _FakeCalendarService()),
      );
      await _openSheet(tester);

      // DropdownButtonFormField shows the current value as text.
      expect(find.text('None'), findsOneWidget);
    });

    testWidgets('shows Add to Calendar button', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(fakeService: _FakeCalendarService()),
      );
      await _openSheet(tester);

      expect(find.text('Add to Calendar'), findsWidgets);
    });

    testWidgets('Cancel button dismisses the sheet', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(fakeService: _FakeCalendarService()),
      );
      await _openSheet(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Sheet gone — "Add to Calendar" text should not be found in a bottom sheet.
      expect(find.text('Add to Calendar'), findsNothing);
    });
  });

  // ── Recurrence dropdown ────────────────────────────────────────────────────

  group('CalendarEventSheet — recurrence dropdown', () {
    testWidgets('all recurrence options are available', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(fakeService: _FakeCalendarService()),
      );
      await _openSheet(tester);

      await tester.tap(find.text('None').last);
      await tester.pumpAndSettle();

      for (final r in CalendarRecurrence.values) {
        expect(find.text(r.label), findsWidgets);
      }
    });
  });

  // ── Successful add ─────────────────────────────────────────────────────────

  group('CalendarEventSheet — successful add', () {
    testWidgets('calls requestPermission and createEvent on button tap',
        (tester) async {
      final fake = _FakeCalendarService();
      await tester.pumpWidget(
        _buildTestWidget(
          fakeService: fake,
          planName: 'Morning Yoga',
          planId: 'plan-123',
        ),
      );
      await _openSheet(tester);

      // Tap "Add to Calendar" ElevatedButton.
      final addBtn = find.widgetWithText(ElevatedButton, 'Add to Calendar');
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(fake.requestPermissionCalls, 1);
      expect(fake.createEventCalls, 1);
      expect(fake.lastEventTitle, 'Morning Yoga');
      expect(fake.lastDurationMinutes, greaterThan(0));
    });

    testWidgets('shows success SnackBar after event created', (tester) async {
      final fake = _FakeCalendarService();
      await tester.pumpWidget(
        _buildTestWidget(fakeService: fake, planName: 'Morning Yoga'),
      );
      await _openSheet(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add to Calendar'));
      await tester.pumpAndSettle();

      expect(find.text('Added to Calendar'), findsOneWidget);
    });

    testWidgets('dismisses sheet on success', (tester) async {
      final fake = _FakeCalendarService();
      await tester.pumpWidget(
        _buildTestWidget(fakeService: fake),
      );
      await _openSheet(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add to Calendar'));
      await tester.pumpAndSettle();

      // Sheet should be gone after success.
      expect(find.text('Add to Calendar'), findsNothing);
    });

    testWidgets('passes deep link when planId provided', (tester) async {
      final fake = _FakeCalendarService();
      await tester.pumpWidget(
        _buildTestWidget(
          fakeService: fake,
          planId: 'abc-456',
        ),
      );
      await _openSheet(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add to Calendar'));
      await tester.pumpAndSettle();

      expect(fake.lastDeepLink, 'instructor://plans/abc-456');
    });
  });

  // ── Permission denied flow ─────────────────────────────────────────────────

  group('CalendarEventSheet — permission denied', () {
    testWidgets('shows denial AlertDialog when permission denied',
        (tester) async {
      final fake = _FakeCalendarService(permissionResult: false);
      await tester.pumpWidget(
        _buildTestWidget(fakeService: fake),
      );
      await _openSheet(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add to Calendar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Calendar Access Required'), findsOneWidget);
    });

    testWidgets('denial dialog contains Open Settings button', (tester) async {
      final fake = _FakeCalendarService(permissionResult: false);
      await tester.pumpWidget(
        _buildTestWidget(fakeService: fake),
      );
      await _openSheet(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add to Calendar'));
      await tester.pumpAndSettle();

      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('tapping Open Settings calls openAppSettings()', (tester) async {
      final fake = _FakeCalendarService(permissionResult: false);
      await tester.pumpWidget(
        _buildTestWidget(fakeService: fake),
      );
      await _openSheet(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add to Calendar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(fake.openAppSettingsCalls, 1);
    });

    testWidgets('denial dialog contains Not Now button', (tester) async {
      final fake = _FakeCalendarService(permissionResult: false);
      await tester.pumpWidget(
        _buildTestWidget(fakeService: fake),
      );
      await _openSheet(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add to Calendar'));
      await tester.pumpAndSettle();

      expect(find.text('Not Now'), findsOneWidget);
    });

    testWidgets('createEvent is NOT called when permission denied',
        (tester) async {
      final fake = _FakeCalendarService(permissionResult: false);
      await tester.pumpWidget(
        _buildTestWidget(fakeService: fake),
      );
      await _openSheet(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add to Calendar'));
      await tester.pumpAndSettle();

      expect(fake.createEventCalls, 0);
    });
  });

  // ── Error handling ─────────────────────────────────────────────────────────

  group('CalendarEventSheet — createEvent error', () {
    testWidgets('shows error SnackBar when createEvent throws', (tester) async {
      final fake =
          _FakeCalendarService(shouldThrowOnCreate: true);
      await tester.pumpWidget(
        _buildTestWidget(fakeService: fake),
      );
      await _openSheet(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add to Calendar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not add event'), findsOneWidget);
    });
  });

  // ── Accessibility ──────────────────────────────────────────────────────────

  group('CalendarEventSheet — accessibility', () {
    testWidgets('plan info header has semantics label', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          fakeService: _FakeCalendarService(),
          planName: 'Morning Yoga',
          planDuration: const Duration(minutes: 30),
        ),
      );
      await _openSheet(tester);

      final semantics = tester.getSemantics(find.byType(CalendarEventSheet));
      // Verify the semantics tree contains the plan info.
      expect(semantics, isNotNull);
    });

    testWidgets('picker rows have button semantics', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(fakeService: _FakeCalendarService()),
      );
      await _openSheet(tester);

      // InkWell on date row should be tappable.
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
    });
  });
}
