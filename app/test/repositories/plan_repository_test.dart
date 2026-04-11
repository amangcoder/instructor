import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/repositories/plan_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Opens an in-memory Drift database for tests — no file I/O required.
AppDatabase _inMemoryDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// Builds a minimal [Plan] for testing; [id] is ignored on create.
Plan _makePlan({
  String name = 'Test Plan',
  PlanCategory category = PlanCategory.custom,
  List<PlanStep> steps = const [],
  DateTime? lastUsedAt,
}) {
  final now = DateTime.now();
  return Plan(
    id: 0, // ignored on insert — auto-increment
    name: name,
    category: category,
    steps: steps,
    createdAt: now,
    updatedAt: now,
    lastUsedAt: lastUsedAt,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late PlanRepository repo;

  setUp(() {
    db = _inMemoryDb();
    repo = DriftPlanRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ─── createPlan ──────────────────────────────────────────────────────────

  group('createPlan', () {
    test('returns a positive auto-incremented ID', () async {
      final id = await repo.createPlan(_makePlan(name: 'Plan A'));
      expect(id, greaterThan(0));
    });

    test('assigns sequential IDs for multiple inserts', () async {
      final id1 = await repo.createPlan(_makePlan(name: 'A'));
      final id2 = await repo.createPlan(_makePlan(name: 'B'));
      expect(id2, greaterThan(id1));
    });

    test('persists all fields correctly', () async {
      final steps = [
        const PlanStep.wait(id: 'w1', duration: Duration(seconds: 30)),
      ];
      final id = await repo.createPlan(
        _makePlan(
          name: 'Yoga Morning',
          category: PlanCategory.yoga,
          steps: steps,
        ),
      );

      final fetched = await repo.getPlanById(id);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Yoga Morning');
      expect(fetched.category, PlanCategory.yoga);
      expect(fetched.steps, hasLength(1));
      expect(fetched.steps.first, isA<WaitStep>());
    });
  });

  // ─── updatePlan ──────────────────────────────────────────────────────────

  group('updatePlan', () {
    test('updates name and steps', () async {
      final id = await repo.createPlan(_makePlan(name: 'Old Name'));
      final updated = _makePlan(name: 'New Name').copyWith(
        steps: [
          const PlanStep.say(id: 's1', text: 'Hello'),
        ],
      );

      await repo.updatePlan(id, updated);

      final fetched = await repo.getPlanById(id);
      expect(fetched!.name, 'New Name');
      expect(fetched.steps.first, isA<SayStep>());
    });

    test('stamps updatedAt on write', () async {
      final before = DateTime.now();
      final id = await repo.createPlan(_makePlan());

      // Small artificial delay so updatedAt is definitely after createdAt.
      await Future<void>.delayed(const Duration(milliseconds: 5));

      await repo.updatePlan(id, _makePlan(name: 'Changed'));
      final fetched = await repo.getPlanById(id);
      expect(fetched!.updatedAt.isAfter(before), isTrue);
    });

    test('does not affect other plans', () async {
      final id1 = await repo.createPlan(_makePlan(name: 'Plan 1'));
      final id2 = await repo.createPlan(_makePlan(name: 'Plan 2'));

      await repo.updatePlan(id1, _makePlan(name: 'Plan 1 Updated'));

      final plan2 = await repo.getPlanById(id2);
      expect(plan2!.name, 'Plan 2');
    });
  });

  // ─── deletePlan ──────────────────────────────────────────────────────────

  group('deletePlan', () {
    test('removes the plan from the database', () async {
      final id = await repo.createPlan(_makePlan());
      await repo.deletePlan(id);
      expect(await repo.getPlanById(id), isNull);
    });

    test('does not throw when plan does not exist', () async {
      // Deleting a nonexistent plan should complete without error.
      await expectLater(repo.deletePlan(99999), completes);
    });

    test('watch stream emits updated list after deletion', () async {
      final id = await repo.createPlan(_makePlan(name: 'To Delete'));
      final stream = repo.watchAllPlans();

      // First event — plan is present.
      final first = await stream.first;
      expect(first.any((p) => p.id == id), isTrue);

      await repo.deletePlan(id);

      // Second event — plan is gone.
      final second = await stream.first;
      expect(second.any((p) => p.id == id), isFalse);
    });
  });

  // ─── getPlanById ─────────────────────────────────────────────────────────

  group('getPlanById', () {
    test('returns null for unknown ID', () async {
      expect(await repo.getPlanById(99999), isNull);
    });

    test('returns the correct plan for a known ID', () async {
      final id = await repo.createPlan(_makePlan(name: 'Known'));
      final plan = await repo.getPlanById(id);
      expect(plan, isNotNull);
      expect(plan!.id, id);
      expect(plan.name, 'Known');
    });
  });

  // ─── watchAllPlans — sorting ─────────────────────────────────────────────

  group('watchAllPlans sorting', () {
    test('returns plans sorted by lastUsedAt descending, nulls last', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      await repo.createPlan(_makePlan(name: 'Used Yesterday', lastUsedAt: yesterday));
      await repo.createPlan(_makePlan(name: 'Used Now', lastUsedAt: now));
      await repo.createPlan(_makePlan(name: 'Never Used')); // lastUsedAt null

      final plans = await repo.watchAllPlans().first;

      expect(plans[0].name, 'Used Now');
      expect(plans[1].name, 'Used Yesterday');
      expect(plans[2].name, 'Never Used');
    });

    test('returns all plans when no filters are applied', () async {
      await repo.createPlan(_makePlan(name: 'A'));
      await repo.createPlan(_makePlan(name: 'B'));
      await repo.createPlan(_makePlan(name: 'C'));

      final plans = await repo.watchAllPlans().first;
      expect(plans, hasLength(3));
    });
  });

  // ─── watchAllPlans — search filter ───────────────────────────────────────

  group('watchAllPlans search filter', () {
    setUp(() async {
      await repo.createPlan(_makePlan(name: 'Morning Yoga'));
      await repo.createPlan(_makePlan(name: 'Evening Yoga'));
      await repo.createPlan(_makePlan(name: 'Deep Focus'));
    });

    test('filters by case-insensitive LIKE match', () async {
      final plans = await repo.watchAllPlans(searchQuery: 'yoga').first;
      expect(plans, hasLength(2));
      expect(plans.every((p) => p.name.toLowerCase().contains('yoga')), isTrue);
    });

    test('matches uppercase search', () async {
      final plans = await repo.watchAllPlans(searchQuery: 'YOGA').first;
      expect(plans, hasLength(2));
    });

    test('returns empty list when no match', () async {
      final plans = await repo.watchAllPlans(searchQuery: 'nonexistent').first;
      expect(plans, isEmpty);
    });

    test('returns all plans for empty search query', () async {
      final plans = await repo.watchAllPlans(searchQuery: '').first;
      expect(plans, hasLength(3));
    });

    test('escapes LIKE special characters in query', () async {
      await repo.createPlan(_makePlan(name: '100% Effort'));
      // Searching for '%' literal should match only that plan.
      final plans = await repo.watchAllPlans(searchQuery: '%').first;
      expect(plans, hasLength(1));
      expect(plans.first.name, '100% Effort');
    });

    test('escapes underscore in LIKE query', () async {
      await repo.createPlan(_makePlan(name: 'Plan_A'));
      // '_' as a LIKE wildcard would match everything — ensure it's escaped.
      final plans = await repo.watchAllPlans(searchQuery: 'Plan_A').first;
      expect(plans, hasLength(1));
      expect(plans.first.name, 'Plan_A');
    });
  });

  // ─── watchAllPlans — category filter ─────────────────────────────────────

  group('watchAllPlans category filter', () {
    setUp(() async {
      await repo.createPlan(_makePlan(name: 'Morning Yoga', category: PlanCategory.yoga));
      await repo.createPlan(_makePlan(name: 'Meditation 1', category: PlanCategory.meditation));
      await repo.createPlan(_makePlan(name: 'Meditation 2', category: PlanCategory.meditation));
    });

    test('returns only plans in selected category', () async {
      final plans = await repo.watchAllPlans(category: PlanCategory.meditation).first;
      expect(plans, hasLength(2));
      expect(plans.every((p) => p.category == PlanCategory.meditation), isTrue);
    });

    test('returns empty list when category has no plans', () async {
      final plans = await repo.watchAllPlans(category: PlanCategory.workout).first;
      expect(plans, isEmpty);
    });
  });

  // ─── watchAllPlans — combined filters ────────────────────────────────────

  group('watchAllPlans combined search + category filter', () {
    test('applies both filters simultaneously', () async {
      await repo.createPlan(_makePlan(name: 'Yoga A', category: PlanCategory.yoga));
      await repo.createPlan(_makePlan(name: 'Yoga B', category: PlanCategory.yoga));
      await repo.createPlan(_makePlan(name: 'Focus A', category: PlanCategory.focus));

      final plans = await repo
          .watchAllPlans(searchQuery: 'yoga', category: PlanCategory.yoga)
          .first;
      expect(plans, hasLength(2));
      expect(plans.every((p) => p.category == PlanCategory.yoga), isTrue);
    });
  });

  // ─── watchAllPlans — reactivity ──────────────────────────────────────────

  group('watchAllPlans reactivity', () {
    test('stream emits when a new plan is created', () async {
      final stream = repo.watchAllPlans();

      // Initially empty.
      expect(await stream.first, isEmpty);

      await repo.createPlan(_makePlan(name: 'New Plan'));

      // Now has one plan.
      expect(await stream.first, hasLength(1));
    });

    test('stream emits when a plan is updated', () async {
      final id = await repo.createPlan(_makePlan(name: 'Original'));
      final stream = repo.watchAllPlans();

      await stream.first; // consume initial event

      await repo.updatePlan(id, _makePlan(name: 'Updated'));
      final after = await stream.first;
      expect(after.first.name, 'Updated');
    });
  });

  // ─── updateLastUsed ──────────────────────────────────────────────────────

  group('updateLastUsed', () {
    test('stamps lastUsedAt to approximately now', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final id = await repo.createPlan(_makePlan());

      await repo.updateLastUsed(id);

      final plan = await repo.getPlanById(id);
      expect(plan!.lastUsedAt, isNotNull);
      expect(plan.lastUsedAt!.isAfter(before), isTrue);
    });

    test('promotes plan to top of watchAllPlans', () async {
      final now = DateTime.now();

      final idA = await repo.createPlan(
        _makePlan(name: 'A', lastUsedAt: now.subtract(const Duration(hours: 1))),
      );
      final idB = await repo.createPlan(
        _makePlan(name: 'B', lastUsedAt: now.subtract(const Duration(hours: 2))),
      );

      // B is currently last; promote B.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.updateLastUsed(idB);

      final plans = await repo.watchAllPlans().first;
      // B should now appear before A.
      expect(plans.first.id, idB);
      expect(plans.last.id, idA);
    });
  });

  // ─── updatePlan persistence (integration) ────────────────────────────────

  group('updatePlan persistence (integration)', () {
    test(
        'createPlan → updatePlan modified steps → getPlanById verifies text matches exactly',
        () async {
      // 1. Create a plan with an initial SayStep.
      final original = _makePlan(
        name: 'Breathe Plan',
        steps: [
          const PlanStep.say(id: 'say-1', text: 'Breathe in'),
          const PlanStep.wait(id: 'wait-1', duration: Duration(seconds: 4)),
        ],
      );
      final id = await repo.createPlan(original);

      // 2. Fetch back and verify initial content.
      final created = await repo.getPlanById(id);
      expect(created, isNotNull);
      expect((created!.steps.first as SayStep).text, 'Breathe in');

      // 3. Build updated Plan with modified step text.
      final updatedPlan = created.copyWith(
        steps: [
          const PlanStep.say(id: 'say-1', text: 'Breathe in deeply'),
          const PlanStep.wait(id: 'wait-1', duration: Duration(seconds: 4)),
        ],
      );

      // 4. Persist via updatePlan.
      await repo.updatePlan(id, updatedPlan);

      // 5. Fetch again and confirm the modification persisted exactly.
      final fetched = await repo.getPlanById(id);
      expect(fetched, isNotNull);
      expect(fetched!.steps, hasLength(2));
      expect(fetched.steps.first, isA<SayStep>());
      expect(
        (fetched.steps.first as SayStep).text,
        'Breathe in deeply',
        reason: 'updatePlan must persist the modified SayStep text exactly',
      );
      expect(fetched.steps[1], isA<WaitStep>());
    });

    test('updatePlan persists modified plan name', () async {
      final id = await repo.createPlan(_makePlan(name: 'Original Name'));

      final created = await repo.getPlanById(id);
      await repo.updatePlan(id, created!.copyWith(name: 'Updated Name'));

      final fetched = await repo.getPlanById(id);
      expect(fetched!.name, 'Updated Name');
    });

    test('updatePlan persists RepeatStep children modifications', () async {
      // 1. Create plan with a RepeatStep containing a SayStep child.
      final id = await repo.createPlan(
        _makePlan(
          name: 'Repeat Plan',
          steps: [
            const PlanStep.repeat(
              id: 'rep-1',
              count: 3,
              children: [
                PlanStep.say(id: 'child-say-1', text: 'Original child text'),
              ],
            ),
          ],
        ),
      );

      // 2. Modify the RepeatStep child text.
      final created = await repo.getPlanById(id);
      expect(created, isNotNull);

      final updatedPlan = created!.copyWith(
        steps: [
          const PlanStep.repeat(
            id: 'rep-1',
            count: 3,
            children: [
              PlanStep.say(id: 'child-say-1', text: 'Modified child text'),
            ],
          ),
        ],
      );
      await repo.updatePlan(id, updatedPlan);

      // 3. Verify child text persisted through StepListConverter round-trip.
      final fetched = await repo.getPlanById(id);
      expect(fetched, isNotNull);
      final repeat = fetched!.steps.first as RepeatStep;
      expect(repeat.count, 3);
      expect(repeat.children, hasLength(1));
      expect(
        (repeat.children.first as SayStep).text,
        'Modified child text',
        reason:
            'StepListConverter must round-trip RepeatStep children correctly',
      );
    });

    test('updatePlan persists all 2+ step modifications simultaneously',
        () async {
      // 1. Create plan with multiple steps.
      final id = await repo.createPlan(
        _makePlan(
          name: 'Multi-Step Plan',
          steps: [
            const PlanStep.say(id: 's1', text: 'Step one'),
            const PlanStep.wait(id: 'w1', duration: Duration(seconds: 5)),
            const PlanStep.say(id: 's2', text: 'Step three'),
          ],
        ),
      );

      // 2. Modify name and 2+ steps.
      final created = await repo.getPlanById(id);
      final updatedPlan = created!.copyWith(
        name: 'Modified Multi-Step Plan',
        steps: [
          const PlanStep.say(id: 's1', text: 'Step one — modified'),
          const PlanStep.wait(id: 'w1', duration: Duration(seconds: 10)),
          const PlanStep.say(id: 's2', text: 'Step three — modified'),
        ],
      );
      await repo.updatePlan(id, updatedPlan);

      // 3. Verify all modifications persisted.
      final fetched = await repo.getPlanById(id);
      expect(fetched!.name, 'Modified Multi-Step Plan');
      expect(fetched.steps, hasLength(3));
      expect((fetched.steps[0] as SayStep).text, 'Step one — modified');
      expect(
        (fetched.steps[1] as WaitStep).duration,
        const Duration(seconds: 10),
      );
      expect((fetched.steps[2] as SayStep).text, 'Step three — modified');
    });
  });

  // ─── Riverpod provider wiring ─────────────────────────────────────────────

  group('planRepositoryProvider', () {
    test('provides a DriftPlanRepository instance', () {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(_inMemoryDb()),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(planRepositoryProvider);
      expect(repo, isA<DriftPlanRepository>());
    });

    test('createPlan and getPlanById round-trip via provider', () async {
      final testDb = _inMemoryDb();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(testDb.close);

      final repo = container.read(planRepositoryProvider);
      final id = await repo.createPlan(_makePlan(name: 'Provider Plan'));
      final plan = await repo.getPlanById(id);
      expect(plan!.name, 'Provider Plan');
    });
  });
}
