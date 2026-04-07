import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/data/starter_templates.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/repositories/plan_repository.dart';
import 'package:instructor/router.dart';
import 'package:instructor/screens/onboarding/onboarding_screen.dart';
import 'package:instructor/services/app_settings.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

/// In-memory fake for [AppSettings] — avoids a real database in widget tests.
class _FakeAppSettings implements AppSettings {
  bool _completed = false;

  @override
  Future<bool> hasCompletedOnboarding() async => _completed;

  @override
  Future<void> setHasCompletedOnboarding() async => _completed = true;

  @override
  Future<bool> hasSeededStarterPlans() async => true;

  @override
  Future<void> setHasSeededStarterPlans() async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Stream<String?> watch(String key) => const Stream.empty();
}

/// In-memory fake for [PlanRepository].
class _FakePlanRepository implements PlanRepository {
  int _nextId = 1;
  final List<Plan> created = [];

  @override
  Future<int> createPlan(Plan plan) async {
    final id = _nextId++;
    created.add(plan.copyWith(id: id));
    return id;
  }

  @override
  Future<void> updatePlan(int id, Plan plan) async {}

  @override
  Future<void> deletePlan(int id) async {}

  @override
  Future<Plan?> getPlanById(int id) async => null;

  @override
  Stream<List<Plan>> watchAllPlans({
    String? searchQuery,
    PlanCategory? category,
  }) =>
      const Stream.empty();

  @override
  Future<void> updateLastUsed(int id) async {}
}

// ── Test helpers ──────────────────────────────────────────────────────────────

/// Wraps [child] in a [ProviderScope] with overridden providers.
///
/// Uses [MaterialApp] (no router) — suitable for pure widget tests that don't
/// need navigation.
Widget _wrapStandalone({
  required Widget child,
  _FakeAppSettings? settings,
  _FakePlanRepository? repo,
}) {
  return ProviderScope(
    overrides: [
      appSettingsProvider.overrideWithValue(settings ?? _FakeAppSettings()),
      planRepositoryProvider
          .overrideWithValue(repo ?? _FakePlanRepository()),
    ],
    child: MaterialApp(home: child),
  );
}

/// Builds a minimal [GoRouter] wired to the onboarding and editor stubs so
/// navigation assertions can be verified.
Widget _wrapWithRouter({
  required _FakeAppSettings settings,
  required _FakePlanRepository repo,
}) {
  final router = GoRouter(
    initialLocation: AppRoutes.onboarding,
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.editorNew,
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Editor (new)'))),
      ),
      GoRoute(
        path: '/editor/:planId',
        builder: (_, state) => Scaffold(
          body: Center(
            child: Text('Editor ${state.pathParameters['planId']}'),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.library,
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Library'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      appSettingsProvider.overrideWithValue(settings),
      planRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Carousel structure ──────────────────────────────────────────────────────

  group('OnboardingScreen — carousel structure', () {
    testWidgets('shows page 1 title and subtitle by default', (tester) async {
      await tester.pumpWidget(
        _wrapStandalone(child: const OnboardingScreen()),
      );
      await tester.pump();

      expect(find.text('Create Plans'), findsOneWidget);
      expect(find.textContaining('timed scripts'), findsOneWidget);
    });

    testWidgets('shows Next button on page 1', (tester) async {
      await tester.pumpWidget(
        _wrapStandalone(child: const OnboardingScreen()),
      );
      await tester.pump();

      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Get Started'), findsNothing);
    });

    testWidgets('shows Skip button on page 1', (tester) async {
      await tester.pumpWidget(
        _wrapStandalone(child: const OnboardingScreen()),
      );
      await tester.pump();

      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('tapping Next advances to page 2 content', (tester) async {
      await tester.pumpWidget(
        _wrapStandalone(child: const OnboardingScreen()),
      );
      await tester.pump();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Runs in Background'), findsOneWidget);
    });

    testWidgets('tapping Next twice advances to page 3 content', (tester) async {
      await tester.pumpWidget(
        _wrapStandalone(child: const OnboardingScreen()),
      );
      await tester.pump();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Start with Templates'), findsOneWidget);
    });

    testWidgets('shows Get Started button on page 3', (tester) async {
      await tester.pumpWidget(
        _wrapStandalone(child: const OnboardingScreen()),
      );
      await tester.pump();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('Skip button jumps to last page', (tester) async {
      await tester.pumpWidget(
        _wrapStandalone(child: const OnboardingScreen()),
      );
      await tester.pump();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Start with Templates'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('dot indicators have correct semantics label on page 1',
        (tester) async {
      await tester.pumpWidget(
        _wrapStandalone(child: const OnboardingScreen()),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);
    });

    testWidgets('dot indicator label updates on page change', (tester) async {
      await tester.pumpWidget(
        _wrapStandalone(child: const OnboardingScreen()),
      );
      await tester.pump();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Page 2 of 3'), findsOneWidget);
    });
  });

  // ── Template picker sheet ───────────────────────────────────────────────────

  group('OnboardingScreen — template picker sheet', () {
    testWidgets('Get Started opens template picker sheet', (tester) async {
      await tester.pumpWidget(
        _wrapStandalone(child: const OnboardingScreen()),
      );
      await tester.pump();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a Starter'), findsOneWidget);
    });

    testWidgets('template picker shows category headers', (tester) async {
      await tester.pumpWidget(
        _wrapStandalone(child: const OnboardingScreen()),
      );
      await tester.pump();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.textContaining('YOGA'), findsOneWidget);
      expect(find.textContaining('MEDITATION'), findsOneWidget);
    });

    testWidgets('template picker shows Start from scratch', (tester) async {
      await tester.pumpWidget(
        _wrapStandalone(child: const OnboardingScreen()),
      );
      await tester.pump();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.text('Start from scratch'), findsOneWidget);
    });
  });

  // ── Starter templates data ──────────────────────────────────────────────────

  group('kStarterTemplates — data correctness', () {
    test('contains exactly 15 templates', () {
      expect(kStarterTemplates.length, equals(15));
    });

    test('covers all expected categories', () {
      final categories = kStarterTemplates.map((t) => t.category).toSet();
      expect(categories, containsAll([
        PlanCategory.yoga,
        PlanCategory.meditation,
        PlanCategory.workout,
        PlanCategory.cooking,
        PlanCategory.routine,
        PlanCategory.focus,
      ]));
    });

    test('all templates have non-empty names', () {
      for (final t in kStarterTemplates) {
        expect(t.name.trim(), isNotEmpty,
            reason: 'Template "${t.name}" has an empty name');
      }
    });

    test('starterTemplatesByCategory groups correctly', () {
      final byCategory = starterTemplatesByCategory;
      expect(byCategory[PlanCategory.yoga]?.length, equals(3));
      expect(byCategory[PlanCategory.meditation]?.length, equals(3));
      expect(byCategory[PlanCategory.workout]?.length, equals(3));
      expect(byCategory[PlanCategory.cooking]?.length, equals(2));
      expect(byCategory[PlanCategory.routine]?.length, equals(2));
      expect(byCategory[PlanCategory.focus]?.length, equals(2));
    });

    test('categoryLabel returns human-readable strings', () {
      expect(categoryLabel(PlanCategory.yoga), equals('Yoga'));
      expect(categoryLabel(PlanCategory.meditation), equals('Meditation'));
      expect(categoryLabel(PlanCategory.workout), equals('Workout'));
      expect(categoryLabel(PlanCategory.cooking), equals('Cooking'));
      expect(categoryLabel(PlanCategory.routine), equals('Daily Routine'));
      expect(categoryLabel(PlanCategory.focus), equals('Focus'));
      expect(categoryLabel(PlanCategory.custom), equals('Custom'));
    });
  });

  // ── Onboarding completion flow ──────────────────────────────────────────────

  group('TemplatePickerSheet — completion flow', () {
    testWidgets(
        'selecting a template creates a plan and marks onboarding complete',
        (tester) async {
      final settings = _FakeAppSettings();
      final repo = _FakePlanRepository();

      await tester.pumpWidget(
        _wrapWithRouter(settings: settings, repo: repo),
      );
      await tester.pumpAndSettle();

      // Navigate through carousel
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Tap the first yoga template
      await tester.tap(find.text('108 Surya Namaskar'));
      await tester.pumpAndSettle();

      expect(await settings.hasCompletedOnboarding(), isTrue);
      expect(repo.created, hasLength(1));
      expect(repo.created.first.name, equals('108 Surya Namaskar'));
      expect(repo.created.first.category, equals(PlanCategory.yoga));
    });

    testWidgets(
        'Start from scratch marks onboarding complete without creating a plan',
        (tester) async {
      final settings = _FakeAppSettings();
      final repo = _FakePlanRepository();

      await tester.pumpWidget(
        _wrapWithRouter(settings: settings, repo: repo),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start from scratch'));
      await tester.pumpAndSettle();

      expect(await settings.hasCompletedOnboarding(), isTrue);
      expect(repo.created, isEmpty);
    });
  });
}
