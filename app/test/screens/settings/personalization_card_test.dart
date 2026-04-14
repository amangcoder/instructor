/// Widget tests for PersonalizationCard — chip selection, persistence, saved
/// indicator, and unauthenticated note.
///
/// ## Running
/// ```
/// flutter test test/screens/settings/personalization_card_test.dart
/// ```
library personalization_card_test;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/providers/settings_providers.dart';
import 'package:instructor/screens/settings/widgets/personalization_card.dart';
import 'package:instructor/services/app_settings.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// In-memory fake for [AppSettings] that records writes.
class _FakeAppSettings implements AppSettings {
  final Map<String, String> _store = {};
  final List<({String key, String value})> writes = [];

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Stream<String?> watch(String key) =>
      Stream.value(_store[key]);

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
    writes.add((key: key, value: value));
  }

  @override
  Future<bool> hasCompletedOnboarding() async => true;

  @override
  Future<void> setHasCompletedOnboarding() async {}

  @override
  Future<bool> hasSeededStarterPlans() async => true;

  @override
  Future<void> setHasSeededStarterPlans() async {}

  @override
  Future<bool> plansMigratedV2() async => true;

  @override
  Future<void> setPlansMigratedV2() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap({
  bool authenticated = false,
  _FakeAppSettings? fakeSettings,
}) {
  final settings = fakeSettings ?? _FakeAppSettings();

  return ProviderScope(
    overrides: [
      appSettingsProvider.overrideWithValue(settings),
      isAuthenticatedProvider.overrideWithValue(authenticated),
      // Provide empty streams so the widget doesn't error out.
      activityLevelSettingProvider.overrideWith(
        (ref) => Stream.value(''),
      ),
      profileGoalsSettingProvider.overrideWith(
        (ref) => Stream.value(<String>[]),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: PersonalizationCard())),
    ),
  );
}

Widget _wrapWithPresets({
  String activityLevel = '',
  List<String> goals = const [],
  bool authenticated = true,
  _FakeAppSettings? fakeSettings,
}) {
  final settings = fakeSettings ?? _FakeAppSettings();

  return ProviderScope(
    overrides: [
      appSettingsProvider.overrideWithValue(settings),
      isAuthenticatedProvider.overrideWithValue(authenticated),
      activityLevelSettingProvider.overrideWith(
        (ref) => Stream.value(activityLevel),
      ),
      profileGoalsSettingProvider.overrideWith(
        (ref) => Stream.value(goals),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: PersonalizationCard())),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PersonalizationCard — initial state', () {
    testWidgets('shows "Choose one" prompt when no activity level set',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Activity Level'), findsOneWidget);
      expect(find.text('Choose one'), findsOneWidget);
    });

    testWidgets('shows all three activity level chips', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Beginner'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
    });

    testWidgets('shows all six goal chips', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      for (final label in ['Yoga', 'Meditation', 'Workout', 'Cooking', 'Routine', 'Focus']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('shows "Choose all that apply" prompt', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Your Goals'), findsOneWidget);
      expect(find.text('Choose all that apply'), findsOneWidget);
    });
  });

  group('PersonalizationCard — ChoiceChip selection', () {
    testWidgets('tapping a ChoiceChip selects it and writes to settings',
        (tester) async {
      final fakeSettings = _FakeAppSettings();
      await tester.pumpWidget(_wrap(fakeSettings: fakeSettings));
      await tester.pumpAndSettle();

      // Tap "Intermediate"
      await tester.tap(find.text('Intermediate'));
      await tester.pumpAndSettle();

      // Verify the chip is now selected (ChoiceChip)
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Intermediate'),
      );
      expect(chip.selected, isTrue);

      // Verify persistence was triggered
      expect(
        fakeSettings.writes.any(
          (w) =>
              w.key == AppSettingsKeys.profileActivityLevel &&
              w.value == 'intermediate',
        ),
        isTrue,
      );

      // "Choose one" prompt should disappear
      expect(find.text('Choose one'), findsNothing);
    });

    testWidgets('shows "Saved" indicator after selection', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Initially "Saved" should be invisible (opacity 0)
      final savedBefore = tester.widget<AnimatedOpacity>(
        find.ancestor(of: find.text('Saved'), matching: find.byType(AnimatedOpacity)),
      );
      expect(savedBefore.opacity, 0.0);

      // Tap a chip
      await tester.tap(find.text('Beginner'));
      await tester.pump();

      // Now "Saved" should be visible (opacity 1)
      final savedAfter = tester.widget<AnimatedOpacity>(
        find.ancestor(of: find.text('Saved'), matching: find.byType(AnimatedOpacity)),
      );
      expect(savedAfter.opacity, 1.0);
    });

    testWidgets('"Saved" indicator fades after 1.5s', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Advanced'));
      await tester.pump();

      // Visible immediately
      var saved = tester.widget<AnimatedOpacity>(
        find.ancestor(of: find.text('Saved'), matching: find.byType(AnimatedOpacity)),
      );
      expect(saved.opacity, 1.0);

      // Advance time past the 1.5 s timer
      await tester.pump(const Duration(milliseconds: 1600));

      saved = tester.widget<AnimatedOpacity>(
        find.ancestor(of: find.text('Saved'), matching: find.byType(AnimatedOpacity)),
      );
      expect(saved.opacity, 0.0);
    });
  });

  group('PersonalizationCard — FilterChip goals', () {
    testWidgets('tapping multiple FilterChips selects them', (tester) async {
      final fakeSettings = _FakeAppSettings();
      await tester.pumpWidget(_wrap(fakeSettings: fakeSettings));
      await tester.pumpAndSettle();

      // Select Yoga
      await tester.tap(find.text('Yoga'));
      await tester.pump();

      // Select Meditation
      await tester.tap(find.text('Meditation'));
      await tester.pump();

      // Both should be selected
      final yogaChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Yoga'),
      );
      expect(yogaChip.selected, isTrue);

      final meditationChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Meditation'),
      );
      expect(meditationChip.selected, isTrue);

      // Should have comma-separated persistence
      final goalsWrite = fakeSettings.writes.lastWhere(
        (w) => w.key == AppSettingsKeys.profileGoals,
      );
      expect(goalsWrite.value, contains('yoga'));
      expect(goalsWrite.value, contains('meditation'));
    });

    testWidgets('deselecting a FilterChip removes it from goals',
        (tester) async {
      final fakeSettings = _FakeAppSettings();
      await tester.pumpWidget(_wrap(fakeSettings: fakeSettings));
      await tester.pumpAndSettle();

      // Select Workout
      await tester.tap(find.text('Workout'));
      await tester.pump();

      // Deselect Workout
      await tester.tap(find.text('Workout'));
      await tester.pump();

      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Workout'),
      );
      expect(chip.selected, isFalse);
    });
  });

  group('PersonalizationCard — unauthenticated note', () {
    testWidgets('shows device-only note when not authenticated',
        (tester) async {
      await tester.pumpWidget(_wrap(authenticated: false));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Preferences saved on this device only. Sign in to sync across devices.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides device-only note when authenticated', (tester) async {
      await tester.pumpWidget(_wrap(authenticated: true));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Preferences saved on this device only. Sign in to sync across devices.',
        ),
        findsNothing,
      );
    });
  });

  group('PersonalizationCard — surfaceVariant background', () {
    testWidgets('card uses surfaceVariant background color', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Find the Container that wraps the PersonalizationCard content
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(PersonalizationCard),
          matching: find.byType(Container),
        ).first,
      );

      final decoration = container.decoration as BoxDecoration;
      final colorScheme = Theme.of(
        tester.element(find.byType(PersonalizationCard)),
      ).colorScheme;

      expect(decoration.color, equals(colorScheme.surfaceVariant));
    });
  });

  group('PersonalizationCard — seeded values', () {
    testWidgets('seeds activity level from provider on first load',
        (tester) async {
      await tester.pumpWidget(_wrapWithPresets(activityLevel: 'advanced'));
      await tester.pumpAndSettle();

      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Advanced'),
      );
      expect(chip.selected, isTrue);

      // "Choose one" should not appear since a level is seeded
      expect(find.text('Choose one'), findsNothing);
    });

    testWidgets('seeds goals from provider on first load', (tester) async {
      await tester.pumpWidget(
        _wrapWithPresets(goals: ['yoga', 'focus']),
      );
      await tester.pumpAndSettle();

      final yogaChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Yoga'),
      );
      expect(yogaChip.selected, isTrue);

      final focusChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Focus'),
      );
      expect(focusChip.selected, isTrue);

      // Other chips should not be selected
      final workoutChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Workout'),
      );
      expect(workoutChip.selected, isFalse);
    });
  });
}
