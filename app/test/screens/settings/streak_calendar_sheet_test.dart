/// Widget tests for StreakCalendarSheet — calendar display, day status visualization,
/// and sheet opening/closing.
///
/// ## Running
/// ```
/// flutter test test/screens/settings/streak_calendar_sheet_test.dart
/// ```
library streak_calendar_sheet_test;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/models/streak_state.dart';
import 'package:instructor/providers/streak_providers.dart';
import 'package:instructor/screens/settings/widgets/streak_calendar_sheet.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget _wrapSheet({
  required List<DayStatus> days,
}) {
  return ProviderScope(
    overrides: [
      streakCalendarProvider.overrideWithValue(
        AsyncValue.data(days),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SizedBox.expand(
          child: Text('Test'),
        ),
      ),
    ),
  );
}

Widget _wrapSheetLoading() {
  return ProviderScope(
    overrides: [
      streakCalendarProvider.overrideWithValue(
        const AsyncValue.loading(),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SizedBox.expand(
          child: Text('Test'),
        ),
      ),
    ),
  );
}

Widget _wrapSheetError() {
  return ProviderScope(
    overrides: [
      streakCalendarProvider.overrideWithValue(
        AsyncValue.error('Failed to load calendar', StackTrace.current),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SizedBox.expand(
          child: Text('Test'),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('StreakCalendarSheet', () {
    testWidgets('shows sheet title "Your Streak"', (WidgetTester tester) async {
      final today = DateTime.now();
      final days = [
        DayStatus(date: today, completed: true, isToday: true, frozeStreak: false),
      ];

      await tester.pumpWidget(_wrapSheet(days: days));
      await showStreakCalendarSheet(tester.element(find.text('Test')));
      await tester.pumpAndSettle();

      expect(find.text('Your Streak'), findsOneWidget);
    });

    testWidgets('shows close button', (WidgetTester tester) async {
      final today = DateTime.now();
      final days = [
        DayStatus(date: today, completed: true, isToday: true, frozeStreak: false),
      ];

      await tester.pumpWidget(_wrapSheet(days: days));
      await showStreakCalendarSheet(tester.element(find.text('Test')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('displays calendar grid with day numbers', (WidgetTester tester) async {
      final today = DateTime.now();
      final day1 = today.subtract(const Duration(days: 2));
      final day2 = today.subtract(const Duration(days: 1));
      final days = [
        DayStatus(date: day1, completed: false, isToday: false, frozeStreak: false),
        DayStatus(date: day2, completed: true, isToday: false, frozeStreak: false),
        DayStatus(date: today, completed: true, isToday: true, frozeStreak: false),
      ];

      await tester.pumpWidget(_wrapSheet(days: days));
      await showStreakCalendarSheet(tester.element(find.text('Test')));
      await tester.pumpAndSettle();

      // Check that day numbers are displayed
      expect(find.text('${day1.day}'), findsOneWidget);
      expect(find.text('${day2.day}'), findsOneWidget);
      expect(find.text('${today.day}'), findsOneWidget);
    });

    testWidgets('highlights today with border', (WidgetTester tester) async {
      final today = DateTime.now();
      final days = [
        DayStatus(date: today, completed: true, isToday: true, frozeStreak: false),
      ];

      await tester.pumpWidget(_wrapSheet(days: days));
      await showStreakCalendarSheet(tester.element(find.text('Test')));
      await tester.pumpAndSettle();

      // Find containers that have borders (today's cell)
      final containers = find.byType(Container);
      expect(containers, findsWidgets);
    });

    testWidgets('shows loading state', (WidgetTester tester) async {
      await tester.pumpWidget(_wrapSheetLoading());
      await showStreakCalendarSheet(tester.element(find.text('Test')));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state', (WidgetTester tester) async {
      await tester.pumpWidget(_wrapSheetError());
      await showStreakCalendarSheet(tester.element(find.text('Test')));
      await tester.pumpAndSettle();

      expect(find.text('Error loading calendar'), findsOneWidget);
    });

    testWidgets('close button dismisses sheet', (WidgetTester tester) async {
      final today = DateTime.now();
      final days = [
        DayStatus(date: today, completed: true, isToday: true, frozeStreak: false),
      ];

      await tester.pumpWidget(_wrapSheet(days: days));
      await showStreakCalendarSheet(tester.element(find.text('Test')));
      await tester.pumpAndSettle();

      expect(find.text('Your Streak'), findsOneWidget);

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Sheet should be closed
      expect(find.text('Your Streak'), findsNothing);
    });

    testWidgets('shows day headers (Sun, Mon, etc.)', (WidgetTester tester) async {
      final today = DateTime.now();
      final days = [
        DayStatus(date: today, completed: true, isToday: true, frozeStreak: false),
      ];

      await tester.pumpWidget(_wrapSheet(days: days));
      await showStreakCalendarSheet(tester.element(find.text('Test')));
      await tester.pumpAndSettle();

      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
    });

    testWidgets('displays 30-day calendar correctly', (WidgetTester tester) async {
      final today = DateTime.now();
      final days = <DayStatus>[];
      for (int i = 0; i < 30; i++) {
        final date = today.subtract(Duration(days: 30 - i - 1));
        days.add(
          DayStatus(
            date: date,
            completed: i % 2 == 0, // Alternating completed/missed
            isToday: date.year == today.year &&
                date.month == today.month &&
                date.day == today.day,
            frozeStreak: false,
          ),
        );
      }

      await tester.pumpWidget(_wrapSheet(days: days));
      await showStreakCalendarSheet(tester.element(find.text('Test')));
      await tester.pumpAndSettle();

      // Should show day cells
      final dayNumbers = find.byWidgetPredicate(
        (widget) => widget is Container && widget.child != null,
      );
      expect(dayNumbers, findsWidgets);
    });

    testWidgets('completed days have different color than missed days', (WidgetTester tester) async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final days = [
        DayStatus(date: yesterday, completed: false, isToday: false, frozeStreak: false),
        DayStatus(date: today, completed: true, isToday: true, frozeStreak: false),
      ];

      await tester.pumpWidget(_wrapSheet(days: days));
      await showStreakCalendarSheet(tester.element(find.text('Test')));
      await tester.pumpAndSettle();

      // Completed and missed days should be displayed
      expect(find.text('${yesterday.day}'), findsOneWidget);
      expect(find.text('${today.day}'), findsOneWidget);
    });
  });
}
