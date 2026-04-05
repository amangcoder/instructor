import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/repositories/plan_repository.dart';
import 'package:instructor/screens/plan_library/plan_library_screen.dart';
import 'package:instructor/screens/plan_library/widgets/plan_card.dart';
import 'package:instructor/services/plan_execution_engine.dart';

// ────────────────────────────────────────────────────────────────────────────
// Fakes
// ────────────────────────────────────────────────────────────────────────────

/// In-memory [PlanRepository] for tests — no database required.
class _FakePlanRepository implements PlanRepository {
  final List<Plan> _plans = [];
  int _nextId = 1;

  // Broadcast controller so streams can emit multiple events.
  final StreamController<List<Plan>> _controller =
      StreamController<List<Plan>>.broadcast();

  void _emit() => _controller.add(List.unmodifiable(_plans));

  @override
  Future<int> createPlan(Plan plan) async {
    final id = _nextId++;
    _plans.add(plan.copyWith(id: id));
    _emit();
    return id;
  }

  @override
  Future<void> updatePlan(int id, Plan plan) async {
    final index = _plans.indexWhere((p) => p.id == id);
    if (index != -1) {
      _plans[index] = plan.copyWith(id: id);
      _emit();
    }
  }

  @override
  Future<void> deletePlan(int id) async {
    _plans.removeWhere((p) => p.id == id);
    _emit();
  }

  @override
  Future<Plan?> getPlanById(int id) async =>
      _plans.where((p) => p.id == id).firstOrNull;

  @override
  Stream<List<Plan>> watchAllPlans({
    String? searchQuery,
    PlanCategory? category,
  }) {
    return _controller.stream.map((plans) {
      var result = plans.toList();
      if (searchQuery != null && searchQuery.isNotEmpty) {
        result = result
            .where(
              (p) => p.name.toLowerCase().contains(searchQuery.toLowerCase()),
            )
            .toList();
      }
      if (category != null) {
        result = result.where((p) => p.category == category).toList();
      }
      return result;
    });
  }

  @override
  Future<void> updateLastUsed(int id) async {
    final index = _plans.indexWhere((p) => p.id == id);
    if (index != -1) {
      _plans[index] =
          _plans[index].copyWith(lastUsedAt: DateTime.now());
      _emit();
    }
  }

  void dispose() => _controller.close();
}

/// Minimal [PlanExecutionEngine] fake — records calls.
class _FakePlanExecutionEngine implements PlanExecutionEngine {
  Plan? startedPlan;
  bool pauseCalled = false;

  final _stateController = StreamController<ExecutionState>.broadcast();

  @override
  Future<void> startPlan(Plan plan) async => startedPlan = plan;

  @override
  Future<void> pause() async => pauseCalled = true;

  @override
  Future<void> resume() async {}

  @override
  Future<void> skipForward() async {}

  @override
  Future<void> skipBackward() async {}

  @override
  Future<void> stop() async {}

  @override
  Stream<ExecutionState> get stateStream => _stateController.stream;

  @override
  Future<ExecutionState?> getRecoverableSession() async => null;

  @override
  Future<void> startPreview(Plan plan) async {}

  @override
  bool get isPreview => false;

  void dispose() => _stateController.close();
}

// ────────────────────────────────────────────────────────────────────────────
// Test helpers
// ────────────────────────────────────────────────────────────────────────────

Plan _makePlan({
  int id = 1,
  String name = 'Test Plan',
  PlanCategory category = PlanCategory.custom,
  Duration duration = const Duration(minutes: 5),
  DateTime? lastUsedAt,
}) {
  final now = DateTime.now();
  return Plan(
    id: id,
    name: name,
    category: category,
    steps: [],
    createdAt: now,
    updatedAt: now,
    lastUsedAt: lastUsedAt,
  );
}

/// Builds the test widget tree with GoRouter and provider overrides.
Widget _buildApp({
  required _FakePlanRepository repo,
  required _FakePlanExecutionEngine engine,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const PlanLibraryScreen(),
      ),
      GoRoute(
        path: '/editor/new',
        builder: (_, __) => const Scaffold(body: Text('New Editor')),
      ),
      GoRoute(
        path: '/editor/:planId',
        builder: (_, __) => const Scaffold(body: Text('Editor')),
      ),
      GoRoute(
        path: '/now-playing',
        builder: (_, __) => const Scaffold(body: Text('Now Playing')),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: Text('Settings')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      planRepositoryProvider.overrideWithValue(repo),
      planExecutionEngineProvider.overrideWithValue(engine),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

void main() {
  late _FakePlanRepository repo;
  late _FakePlanExecutionEngine engine;

  setUp(() {
    repo = _FakePlanRepository();
    engine = _FakePlanExecutionEngine();
  });

  tearDown(() {
    repo.dispose();
    engine.dispose();
  });

  // ── Rendering ─────────────────────────────────────────────────────────────

  group('PlanLibraryScreen rendering', () {
    testWidgets('shows app bar with title "My Plans"', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await tester.pump();
      expect(find.text('My Plans'), findsOneWidget);
    });

    testWidgets('shows settings icon in app bar', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await tester.pump();
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('shows search bar', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows "All" category chip', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await tester.pump();
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('shows a FilterChip for each PlanCategory', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await tester.pump();
      for (final category in PlanCategory.values) {
        expect(
          find.text(planCategoryLabel(category)),
          findsOneWidget,
          reason: 'Missing chip for $category',
        );
      }
    });

    testWidgets('shows FAB with add icon', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows empty state when no plans', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      // Emit an empty list from the stream.
      repo._emit();
      await tester.pumpAndSettle();
      expect(find.text('No plans yet'), findsOneWidget);
    });

    testWidgets('shows plan cards when plans are available', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Yoga Flow'));
      await repo.createPlan(_makePlan(id: 2, name: 'Morning Routine'));
      await tester.pumpAndSettle();

      expect(find.text('Yoga Flow'), findsOneWidget);
      expect(find.text('Morning Routine'), findsOneWidget);
    });

    testWidgets('shows loading spinner while waiting for plans', (tester) async {
      // Use a completer so the stream never emits, keeping the loading state.
      final completer = Completer<List<Plan>>();
      final delayedRepo = _FakePlanRepository();

      await tester.pumpWidget(_buildApp(repo: delayedRepo, engine: engine));
      // Before the stream emits, the AsyncValue is loading.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete([]);
      delayedRepo.dispose();
    });
  });

  // ── PlanCard content ──────────────────────────────────────────────────────

  group('PlanCard displays correct content', () {
    testWidgets('shows plan name in bold', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Sunrise Yoga'));
      await tester.pumpAndSettle();

      // Name text should be visible.
      expect(find.text('Sunrise Yoga'), findsOneWidget);
    });

    testWidgets('shows category icon for yoga plan', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(
        name: 'Yoga Plan',
        category: PlanCategory.yoga,
      ));
      await tester.pumpAndSettle();

      // Yoga maps to Icons.self_improvement.
      expect(find.byIcon(Icons.self_improvement), findsOneWidget);
    });

    testWidgets('shows "Never used" when lastUsedAt is null', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(lastUsedAt: null));
      await tester.pumpAndSettle();

      expect(find.textContaining('Never used'), findsOneWidget);
    });

    testWidgets('shows popup menu button', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Plan'));
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuButton<Object>), findsOneWidget);
    });
  });

  // ── Search ────────────────────────────────────────────────────────────────

  group('Search bar', () {
    testWidgets('filters plans by name in real-time', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(id: 1, name: 'Morning Yoga'));
      await repo.createPlan(_makePlan(id: 2, name: 'Deep Focus'));
      await tester.pumpAndSettle();

      // Both plans visible initially.
      expect(find.text('Morning Yoga'), findsOneWidget);
      expect(find.text('Deep Focus'), findsOneWidget);

      // Type in search bar.
      await tester.enterText(find.byType(TextField), 'yoga');
      await tester.pumpAndSettle();

      expect(find.text('Morning Yoga'), findsOneWidget);
      expect(find.text('Deep Focus'), findsNothing);
    });

    testWidgets('shows clear button when query is non-empty', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      repo._emit();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clears search when clear button tapped', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(id: 1, name: 'Morning Yoga'));
      await repo.createPlan(_makePlan(id: 2, name: 'Deep Focus'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'yoga');
      await tester.pumpAndSettle();
      expect(find.text('Deep Focus'), findsNothing);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.text('Morning Yoga'), findsOneWidget);
      expect(find.text('Deep Focus'), findsOneWidget);
    });
  });

  // ── Category filter ───────────────────────────────────────────────────────

  group('CategoryFilter', () {
    testWidgets('filters by category when chip tapped', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(
        id: 1,
        name: 'Yoga Flow',
        category: PlanCategory.yoga,
      ));
      await repo.createPlan(_makePlan(
        id: 2,
        name: 'Deep Focus',
        category: PlanCategory.focus,
      ));
      await tester.pumpAndSettle();

      // Scroll to the Yoga chip and tap it.
      await tester.tap(find.text('Yoga'));
      await tester.pumpAndSettle();

      expect(find.text('Yoga Flow'), findsOneWidget);
      expect(find.text('Deep Focus'), findsNothing);
    });

    testWidgets('returns to all plans when All chip tapped', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(
        id: 1,
        name: 'Yoga Flow',
        category: PlanCategory.yoga,
      ));
      await repo.createPlan(_makePlan(
        id: 2,
        name: 'Deep Focus',
        category: PlanCategory.focus,
      ));
      await tester.pumpAndSettle();

      // Select Yoga filter.
      await tester.tap(find.text('Yoga'));
      await tester.pumpAndSettle();
      expect(find.text('Deep Focus'), findsNothing);

      // Tap All to reset.
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('Yoga Flow'), findsOneWidget);
      expect(find.text('Deep Focus'), findsOneWidget);
    });

    testWidgets('deselects category chip when tapped again', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(
        id: 1,
        name: 'Yoga Flow',
        category: PlanCategory.yoga,
      ));
      await repo.createPlan(_makePlan(
        id: 2,
        name: 'Deep Focus',
        category: PlanCategory.focus,
      ));
      await tester.pumpAndSettle();

      // Select then deselect.
      await tester.tap(find.text('Yoga'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yoga'));
      await tester.pumpAndSettle();

      expect(find.text('Yoga Flow'), findsOneWidget);
      expect(find.text('Deep Focus'), findsOneWidget);
    });
  });

  // ── Navigation ────────────────────────────────────────────────────────────

  group('Navigation', () {
    testWidgets('FAB navigates to new editor', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      repo._emit();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('New Editor'), findsOneWidget);
    });

    testWidgets('settings icon navigates to settings', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      repo._emit();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('Edit menu item navigates to editor with plan ID', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'My Plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<Object>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Editor'), findsOneWidget);
    });
  });

  // ── Duplicate ─────────────────────────────────────────────────────────────

  group('Duplicate plan', () {
    testWidgets('creates a copy with "(copy)" suffix', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Morning Yoga'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<Object>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();

      expect(find.text('Morning Yoga (copy)'), findsOneWidget);
    });

    testWidgets('shows snackbar after duplicate', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Plan A'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<Object>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();

      expect(find.textContaining('duplicated'), findsOneWidget);
    });
  });

  // ── Delete ────────────────────────────────────────────────────────────────

  group('Delete plan', () {
    testWidgets('shows confirmation dialog before deleting', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Plan to Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<Object>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Plan'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
    });

    testWidgets('removes plan when confirmed', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Gone Plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<Object>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirm deletion.
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(find.text('Gone Plan'), findsNothing);
      expect(find.textContaining('deleted'), findsOneWidget);
    });

    testWidgets('keeps plan when cancelled', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Kept Plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<Object>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Kept Plan'), findsOneWidget);
    });
  });

  // ── Countdown overlay ─────────────────────────────────────────────────────

  group('Countdown overlay', () {
    testWidgets('tapping plan card shows countdown overlay', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Run This'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Run This'));
      // Pump to show the overlay (don't settle — countdown is running).
      await tester.pump();

      // The overlay shows the first count (3).
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Cancel button dismisses overlay without starting', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Yoga'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yoga'));
      await tester.pump();
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // No navigation — still on library screen.
      expect(find.text('My Plans'), findsOneWidget);
      expect(engine.startedPlan, isNull);
    });
  });

  // ── Helper function tests ──────────────────────────────────────────────────

  group('formatRelativeTime', () {
    test('returns "Never used" for null', () {
      expect(formatRelativeTime(null), 'Never used');
    });

    test('returns "Just now" for less than 60 seconds', () {
      final now = DateTime.now().subtract(const Duration(seconds: 30));
      expect(formatRelativeTime(now), 'Just now');
    });

    test('returns minutes ago', () {
      final dt = DateTime.now().subtract(const Duration(minutes: 5));
      expect(formatRelativeTime(dt), '5 mins ago');
    });

    test('returns hours ago', () {
      final dt = DateTime.now().subtract(const Duration(hours: 2));
      expect(formatRelativeTime(dt), '2 hours ago');
    });

    test('returns days ago', () {
      final dt = DateTime.now().subtract(const Duration(days: 3));
      expect(formatRelativeTime(dt), '3 days ago');
    });

    test('returns "Yesterday" for 1 day ago', () {
      final dt = DateTime.now().subtract(const Duration(days: 1));
      expect(formatRelativeTime(dt), 'Yesterday');
    });
  });

  group('formatPlanDuration', () {
    test('formats seconds only', () {
      expect(formatPlanDuration(const Duration(seconds: 45)), '45s');
    });

    test('formats minutes only', () {
      expect(formatPlanDuration(const Duration(minutes: 10)), '10m');
    });

    test('formats minutes and seconds', () {
      expect(
        formatPlanDuration(const Duration(minutes: 5, seconds: 30)),
        '5m 30s',
      );
    });

    test('formats hours and minutes', () {
      expect(
        formatPlanDuration(const Duration(hours: 1, minutes: 15)),
        '1h 15m',
      );
    });

    test('formats hours only', () {
      expect(formatPlanDuration(const Duration(hours: 2)), '2h');
    });
  });

  group('planCategoryIcon', () {
    test('returns different icons for each category', () {
      final icons = PlanCategory.values.map(planCategoryIcon).toSet();
      // Each category should have a unique icon.
      expect(icons.length, PlanCategory.values.length);
    });
  });

  group('planCategoryLabel', () {
    test('returns non-empty label for every category', () {
      for (final category in PlanCategory.values) {
        expect(planCategoryLabel(category), isNotEmpty);
      }
    });
  });
}
