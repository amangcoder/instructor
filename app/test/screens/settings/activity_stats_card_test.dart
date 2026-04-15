/// Widget tests for ActivityStatsCard — streak display, today's status, and calendar opening.
///
/// ## Running
/// ```
/// flutter test test/screens/settings/activity_stats_card_test.dart
/// ```
library activity_stats_card_test;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/models/streak_state.dart';
import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/providers/streak_providers.dart';
import 'package:instructor/screens/settings/widgets/activity_stats_card.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget _wrap({
  List<dynamic> plans = const [],
  int streakCount = 0,
  bool completedToday = false,
}) {
  return ProviderScope(
    overrides: [
      planListProvider().overrideWithValue(plans),
      currentStreakProvider.overrideWithValue(AsyncValue.data(streakCount)),
      completedTodayProvider.overrideWithValue(
        AsyncValue.data(completedToday),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ActivityStatsCard(),
        ),
      ),
    ),
  );
}

Widget _wrapWithLoading() {
  return ProviderScope(
    overrides: [
      planListProvider().overrideWithValue(const []),
      currentStreakProvider.overrideWithValue(const AsyncValue.loading()),
      completedTodayProvider.overrideWithValue(const AsyncValue.loading()),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ActivityStatsCard(),
        ),
      ),
    ),
  );
}

Widget _wrapWithError() {
  return ProviderScope(
    overrides: [
      planListProvider().overrideWithValue(const []),
      currentStreakProvider.overrideWithValue(
        AsyncValue.error('Failed to load streak', StackTrace.current),
      ),
      completedTodayProvider.overrideWithValue(
        AsyncValue.error('Failed to load status', StackTrace.current),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ActivityStatsCard(),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ActivityStatsCard', () {
    testWidgets('displays plans count', (WidgetTester tester) async {
      final plans = [1, 2, 3]; // Mock plan objects
      await tester.pumpWidget(_wrap(plans: plans));

      expect(find.text('Plans'), findsWidgets);
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('displays zero plans count when no plans', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(plans: const []));

      expect(find.text('Plans'), findsWidgets);
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('displays streak count with flame emoji', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(streakCount: 5));

      expect(find.text('Streak'), findsWidgets);
      expect(find.text('5'), findsWidgets);
      expect(find.text('🔥'), findsOneWidget);
    });

    testWidgets('displays "Completed today ✓" when completedToday is true', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(streakCount: 5, completedToday: true));

      expect(find.text('Completed today ✓'), findsOneWidget);
    });

    testWidgets('displays "Practice tomorrow" when completedToday is false', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(streakCount: 5, completedToday: false));

      expect(find.text('Practice tomorrow'), findsOneWidget);
    });

    testWidgets('displays loading state for streak', (WidgetTester tester) async {
      await tester.pumpWidget(_wrapWithLoading());

      expect(find.text('Streak'), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('displays error state for streak', (WidgetTester tester) async {
      await tester.pumpWidget(_wrapWithError());

      expect(find.text('Streak'), findsWidgets);
      expect(find.text('Error loading'), findsOneWidget);
    });

    testWidgets('streak tile is tappable and shows as button semantically', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(streakCount: 5));

      // Find the gesture detector in the streak tile
      final gestureDetector = find.byWidgetPredicate(
        (widget) =>
            widget is GestureDetector &&
            widget.onTap != null,
      );

      expect(gestureDetector, findsWidgets);
    });

    testWidgets('shows zero streak with flame icon', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(streakCount: 0));

      expect(find.text('0'), findsWidgets);
      expect(find.text('🔥'), findsOneWidget);
    });

    testWidgets('shows multi-digit streak correctly', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(streakCount: 123));

      expect(find.text('123'), findsWidgets);
      expect(find.text('🔥'), findsOneWidget);
    });

    testWidgets('streak count and status are displayed together', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        streakCount: 10,
        completedToday: true,
      ));

      expect(find.text('10'), findsWidgets);
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('Completed today ✓'), findsOneWidget);
    });

    testWidgets('plans, sessions, and streak tiles are all present', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(plans: const [1, 2], streakCount: 5));

      expect(find.text('Plans'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('Streak'), findsOneWidget);
    });

    testWidgets('sessions tile shows placeholder text', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(streakCount: 5));

      expect(find.text('Start a session to track'), findsOneWidget);
    });
  });
}
