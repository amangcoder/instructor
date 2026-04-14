/// Integration tests for the plan editor save / update / load round-trip
/// (TASK-008 AC: Integration test: createPlan → updatePlan with modified steps
/// → getPlanById confirms all modifications persisted correctly).
///
/// These tests exercise the full SQLite persistence layer via the real
/// [DriftPlanRepository] backed by an in-memory [AppDatabase], verifying that:
///   1. A newly created plan is retrievable and matches the original data.
///   2. Updating a plan's steps persists correctly.
///   3. A new-plan save flow works end-to-end.
///   4. Updating an existing plan preserves all modified fields.
///
/// ## Running
/// ```
/// flutter test test/integration/plan_editor_integration_test.dart
/// ```
library plan_editor_integration_test;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/repositories/plan_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns an in-memory [AppDatabase] suitable for tests.
AppDatabase _makeTestDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// Builds a minimal [Plan] with the given [name] and optional [steps].
Plan _makePlan({
  required String name,
  List<PlanStep> steps = const [],
  String description = '',
}) {
  final now = DateTime.now();
  return Plan(
    id: '', // empty → createPlan will assign a new UUID
    name: name,
    description: description,
    category: PlanCategory.custom,
    steps: steps,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late DriftPlanRepository repo;

  setUp(() {
    db = _makeTestDb();
    // No syncService in integration tests — we only test persistence here.
    repo = DriftPlanRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── New-plan save flow ────────────────────────────────────────────────────

  group('new plan save flow', () {
    test('createPlan returns a non-empty String UUID', () async {
      final plan = _makePlan(name: 'Morning Routine');
      final id = await repo.createPlan(plan);
      expect(id, isA<String>());
      expect(id, isNotEmpty);
    });

    test('newly created plan is retrievable by ID', () async {
      final plan = _makePlan(name: 'Test Plan', description: 'desc');
      final id = await repo.createPlan(plan);

      final saved = await repo.getPlanById(id);
      expect(saved, isNotNull);
      expect(saved!.name, 'Test Plan');
      expect(saved.description, 'desc');
      expect(saved.id, id);
    });

    test('steps are persisted on createPlan', () async {
      const steps = [
        PlanStep.say(
            id: 's1',
            text: 'Hello world',
            estimatedDuration: Duration(seconds: 5)),
        PlanStep.wait(id: 't1', duration: Duration(seconds: 30)),
      ];
      final plan = _makePlan(name: 'Plan With Steps', steps: steps);
      final id = await repo.createPlan(plan);

      final saved = await repo.getPlanById(id);
      expect(saved, isNotNull);
      expect(saved!.steps, hasLength(2));
      expect((saved.steps[0] as SayStep).text, 'Hello world');
      expect((saved.steps[1] as WaitStep).duration,
          const Duration(seconds: 30));
    });
  });

  // ── Existing-plan update persistence ─────────────────────────────────────

  group('existing plan update persistence', () {
    test('updatePlan modifies name and retrieves updated value', () async {
      final id = await repo.createPlan(_makePlan(name: 'Original Name'));

      final original = await repo.getPlanById(id);
      final updated = original!.copyWith(name: 'Updated Name');
      await repo.updatePlan(id, updated);

      final saved = await repo.getPlanById(id);
      expect(saved!.name, 'Updated Name');
    });

    test(
        'createPlan → updatePlan with modified steps → getPlanById '
        'confirms all modifications persisted correctly', () async {
      // Step 1: create with initial steps.
      const initial = [
        PlanStep.wait(id: 't1', duration: Duration(seconds: 60)),
      ];
      final id = await repo.createPlan(
        _makePlan(name: 'Workout Plan', steps: initial),
      );

      // Step 2: modify steps and update.
      final saved = await repo.getPlanById(id);
      final modified = saved!.copyWith(
        steps: const [
          PlanStep.say(
              id: 's1',
              text: 'Begin warmup',
              estimatedDuration: Duration(seconds: 10)),
          PlanStep.wait(id: 't2', duration: Duration(seconds: 300)),
          PlanStep.say(
              id: 's2',
              text: 'Cool down',
              estimatedDuration: Duration(seconds: 10)),
        ],
      );
      await repo.updatePlan(id, modified);

      // Step 3: verify all modifications persisted.
      final result = await repo.getPlanById(id);
      expect(result, isNotNull);
      expect(result!.steps, hasLength(3));
      expect((result.steps[0] as SayStep).text, 'Begin warmup');
      expect((result.steps[1] as WaitStep).duration,
          const Duration(seconds: 300));
      expect((result.steps[2] as SayStep).text, 'Cool down');
    });

    test('updatePlan preserves fields not explicitly changed', () async {
      final id = await repo.createPlan(
        _makePlan(
          name: 'Yoga Flow',
          description: 'Original description',
          steps: const [
            PlanStep.wait(id: 't1', duration: Duration(seconds: 20)),
          ],
        ),
      );

      final saved = await repo.getPlanById(id);
      // Update only the name.
      await repo.updatePlan(id, saved!.copyWith(name: 'Yoga Flow v2'));

      final result = await repo.getPlanById(id);
      expect(result!.name, 'Yoga Flow v2');
      // Description and steps should be unchanged.
      expect(result.description, 'Original description');
      expect(result.steps, hasLength(1));
    });

    test('updatedAt is bumped on updatePlan', () async {
      final id = await repo.createPlan(_makePlan(name: 'Plan A'));
      final before = await repo.getPlanById(id);

      // Small delay to ensure timestamp difference is measurable.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final updated = before!.copyWith(name: 'Plan A v2');
      await repo.updatePlan(id, updated);

      final after = await repo.getPlanById(id);
      expect(after!.updatedAt.isAfter(before.updatedAt), isTrue);
    });
  });

  // ── Reactive streams ─────────────────────────────────────────────────────

  group('watchAllPlans stream', () {
    test('emits updated list after createPlan', () async {
      final stream = repo.watchAllPlans();

      await repo.createPlan(_makePlan(name: 'Plan X'));

      final list = await stream.first;
      expect(list, isNotEmpty);
      expect(list.any((p) => p.name == 'Plan X'), isTrue);
    });

    test('created plan appears in watchUserPlans', () async {
      final id = await repo.createPlan(
        _makePlan(name: 'My Plan'),
      );

      final userPlans = await repo.watchUserPlans().first;
      expect(userPlans.any((p) => p.id == id), isTrue);
    });
  });

  // ── TTS fields ────────────────────────────────────────────────────────────

  group('TTS fields persistence', () {
    test('isActive, ttsStatus, ttsTotal, ttsCompleted round-trip', () async {
      final now = DateTime.now();
      final plan = Plan(
        id: '',
        name: 'TTS Plan',
        createdAt: now,
        updatedAt: now,
        isActive: true,
        ttsStatus: 'processing',
        ttsTotal: 20,
        ttsCompleted: 5,
      );
      final id = await repo.createPlan(plan);

      final saved = await repo.getPlanById(id);
      expect(saved!.isActive, isTrue);
      expect(saved.ttsStatus, 'processing');
      expect(saved.ttsTotal, 20);
      expect(saved.ttsCompleted, 5);
    });

    test('updatePlan persists updated TTS fields', () async {
      final id = await repo.createPlan(_makePlan(name: 'Plan TTS'));
      final plan = await repo.getPlanById(id);

      await repo.updatePlan(
        id,
        plan!.copyWith(
          isActive: true,
          ttsStatus: 'completed',
          ttsTotal: 8,
          ttsCompleted: 8,
        ),
      );

      final result = await repo.getPlanById(id);
      expect(result!.isActive, isTrue);
      expect(result.ttsStatus, 'completed');
      expect(result.ttsTotal, 8);
      expect(result.ttsCompleted, 8);
    });
  });
}
