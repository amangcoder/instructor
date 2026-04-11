import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/database/tables/plans_table.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/services/sync_service.dart';

part 'plan_repository.g.dart';

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

/// CRUD and query operations for [Plan] objects backed by the Drift database.
///
/// All database access is performed via the [AppDatabase] instance injected
/// through the Riverpod provider. Use [watchAllPlans] for reactive UI bindings.
abstract class PlanRepository {
  /// Creates a new Plan and returns its generated ID.
  Future<int> createPlan(Plan plan);

  /// Updates an existing Plan by ID.
  Future<void> updatePlan(int id, Plan plan);

  /// Deletes a Plan and its associated TTS cache entries.
  Future<void> deletePlan(int id);

  /// Fetches a single Plan by ID; returns null if not found.
  Future<Plan?> getPlanById(int id);

  /// Returns a reactive stream of all Plans, sorted by [lastUsedAt] descending
  /// (most recently used first, nulls last), with optional filters:
  ///
  /// - [searchQuery]: case-insensitive LIKE filter on [Plan.name].
  /// - [category]: exact match on [Plan.category].
  Stream<List<Plan>> watchAllPlans({
    String? searchQuery,
    PlanCategory? category,
  });

  /// Returns a reactive stream of user-created plans ([Plan.isUserCreated]=true).
  ///
  /// Supports the same [searchQuery] and [category] filters as [watchAllPlans].
  Stream<List<Plan>> watchUserPlans({
    String? searchQuery,
    PlanCategory? category,
  });

  /// Returns a reactive stream of starter/seeded plans ([Plan.isUserCreated]=false).
  ///
  /// Supports the same [searchQuery] and [category] filters as [watchAllPlans].
  Stream<List<Plan>> watchStarterPlans({
    String? searchQuery,
    PlanCategory? category,
  });

  /// Updates the [Plan.lastUsedAt] timestamp to now.
  Future<void> updateLastUsed(int id);

  /// Remaps all plan voices using the given [voiceMap].
  ///
  /// For each plan, maps [defaultVoice] and every [SayStep.voiceId] through
  /// [voiceMap]. Voices not in the map are left unchanged.
  ///
  /// Returns the number of plans that were actually updated.
  Future<int> remapPlanVoices(Map<String, String> voiceMap);
}

// ---------------------------------------------------------------------------
// Concrete Drift implementation
// ---------------------------------------------------------------------------

/// Drift-backed implementation of [PlanRepository].
///
/// All writes use [into] / [update] / [delete] so that Drift's built-in
/// change-tracking automatically notifies any active [watchAllPlans] streams.
///
/// After every mutation ([createPlan], [updatePlan], [deletePlan]) a debounced
/// sync is scheduled via [SyncService.scheduleDebouncedSync] — no more than
/// one upload per 30 seconds. The optional [syncService] parameter allows
/// tests to omit sync entirely.
class DriftPlanRepository implements PlanRepository {
  DriftPlanRepository(this._db, {SyncService? syncService})
      : _syncService = syncService;

  final AppDatabase _db;
  final SyncService? _syncService;

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Converts a Drift [PlansTableData] row into a domain [Plan].
  Plan _rowToPlan(PlansTableData row) {
    return Plan(
      id: row.id,
      name: row.name,
      description: row.description,
      category: PlanCategory.values.firstWhere(
        (c) => c.name == row.category,
        orElse: () => PlanCategory.custom,
      ),
      tags: row.tags,
      defaultVoice: row.defaultVoice,
      steps: row.steps,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      lastUsedAt: row.lastUsedAt,
      isUserCreated: row.isUserCreated,
    );
  }

  /// Converts a domain [Plan] into a Drift [PlansTableCompanion] for writes.
  ///
  /// [id] is omitted so that auto-increment works on insert; for updates the
  /// caller already has the ID in the WHERE clause.
  PlansTableCompanion _planToCompanion(Plan plan) {
    return PlansTableCompanion(
      name: Value(plan.name),
      description: Value(plan.description),
      category: Value(plan.category.name),
      tags: Value(plan.tags),
      defaultVoice: Value(plan.defaultVoice),
      steps: Value(plan.steps),
      createdAt: Value(plan.createdAt),
      updatedAt: Value(plan.updatedAt),
      lastUsedAt: Value(plan.lastUsedAt),
      isUserCreated: Value(plan.isUserCreated),
    );
  }

  // -------------------------------------------------------------------------
  // CRUD
  // -------------------------------------------------------------------------

  @override
  Future<int> createPlan(Plan plan) async {
    final now = DateTime.now();
    final companion = _planToCompanion(plan).copyWith(
      createdAt: Value(now),
      updatedAt: Value(now),
    );
    final id = await _db.into(_db.plansTable).insert(companion);
    _syncService?.scheduleDebouncedSync();
    return id;
  }

  @override
  Future<void> updatePlan(int id, Plan plan) async {
    final companion = _planToCompanion(plan).copyWith(
      updatedAt: Value(DateTime.now()),
    );
    await (_db.update(_db.plansTable)
          ..where((t) => t.id.equals(id)))
        .write(companion);
    _syncService?.scheduleDebouncedSync();
  }

  @override
  Future<void> deletePlan(int id) async {
    // Delete TTS cache rows associated with this Plan first.
    // The TTS cache table stores a planId column for exactly this purpose.
    await (_db.delete(_db.ttsCacheTable)
          ..where((t) => t.planId.equals(id)))
        .go();

    // Now delete the Plan row itself.
    await (_db.delete(_db.plansTable)
          ..where((t) => t.id.equals(id)))
        .go();

    _syncService?.scheduleDebouncedSync();
  }

  @override
  Future<Plan?> getPlanById(int id) async {
    final row = await (_db.select(_db.plansTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _rowToPlan(row);
  }

  // -------------------------------------------------------------------------
  // Reactive query
  // -------------------------------------------------------------------------

  @override
  Stream<List<Plan>> watchAllPlans({
    String? searchQuery,
    PlanCategory? category,
  }) {
    final query = _db.select(_db.plansTable)
      ..orderBy([
        // Nulls-last ordering: isNull() returns 1 for NULL, 0 for non-NULL.
        // Sorting ASC puts non-null (0) before null (1).
        (t) => OrderingTerm.asc(t.lastUsedAt.isNull()),
        // Most recently used first among non-null rows.
        (t) => OrderingTerm.desc(t.lastUsedAt),
        // Stable secondary sort by most recently updated.
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query.where(
        (t) => t.name.like('%${_escapeLikePattern(searchQuery)}%'),
      );
    }

    if (category != null) {
      query.where((t) => t.category.equals(category.name));
    }

    return query.watch().map((rows) => rows.map(_rowToPlan).toList());
  }

  @override
  Stream<List<Plan>> watchUserPlans({
    String? searchQuery,
    PlanCategory? category,
  }) {
    final query = _db.select(_db.plansTable)
      ..where((t) => t.isUserCreated.equals(true))
      ..orderBy([
        (t) => OrderingTerm.asc(t.lastUsedAt.isNull()),
        (t) => OrderingTerm.desc(t.lastUsedAt),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query.where(
        (t) => t.name.like('%${_escapeLikePattern(searchQuery)}%'),
      );
    }

    if (category != null) {
      query.where((t) => t.category.equals(category.name));
    }

    return query.watch().map((rows) => rows.map(_rowToPlan).toList());
  }

  @override
  Stream<List<Plan>> watchStarterPlans({
    String? searchQuery,
    PlanCategory? category,
  }) {
    final query = _db.select(_db.plansTable)
      ..where((t) => t.isUserCreated.equals(false))
      ..orderBy([
        (t) => OrderingTerm.asc(t.lastUsedAt.isNull()),
        (t) => OrderingTerm.desc(t.lastUsedAt),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query.where(
        (t) => t.name.like('%${_escapeLikePattern(searchQuery)}%'),
      );
    }

    if (category != null) {
      query.where((t) => t.category.equals(category.name));
    }

    return query.watch().map((rows) => rows.map(_rowToPlan).toList());
  }

  // -------------------------------------------------------------------------
  // Timestamp helpers
  // -------------------------------------------------------------------------

  @override
  Future<void> updateLastUsed(int id) async {
    await (_db.update(_db.plansTable)
          ..where((t) => t.id.equals(id)))
        .write(PlansTableCompanion(lastUsedAt: Value(DateTime.now())));
  }

  // -------------------------------------------------------------------------
  // Voice remapping
  // -------------------------------------------------------------------------

  @override
  Future<int> remapPlanVoices(Map<String, String> voiceMap) async {
    if (voiceMap.isEmpty) return 0;

    var updatedCount = 0;
    final allRows = await _db.select(_db.plansTable).get();
    for (final row in allRows) {
      final plan = _rowToPlan(row);
      final newDefaultVoice =
          voiceMap[plan.defaultVoice] ?? plan.defaultVoice;
      final newSteps = _remapSteps(plan.steps, voiceMap);

      // Only update if something actually changed.
      if (newDefaultVoice == plan.defaultVoice && newSteps == null) continue;

      final updated = plan.copyWith(
        defaultVoice: newDefaultVoice,
        steps: newSteps ?? plan.steps,
      );
      await updatePlan(row.id, updated);
      updatedCount++;
    }
    return updatedCount;
  }

  /// Recursively remaps voiceId in SaySteps and RepeatStep children.
  /// Returns null if no step was changed.
  List<PlanStep>? _remapSteps(
      List<PlanStep> steps, Map<String, String> voiceMap) {
    var changed = false;
    final result = steps.map((step) {
      return switch (step) {
        SayStep(:final voiceId) when voiceId != null &&
            voiceMap.containsKey(voiceId) =>
          () {
            changed = true;
            return (step as SayStep).copyWith(voiceId: voiceMap[voiceId]);
          }(),
        RepeatStep(:final children) => () {
            final remapped = _remapSteps(children, voiceMap);
            if (remapped != null) {
              changed = true;
              return (step as RepeatStep).copyWith(children: remapped);
            }
            return step;
          }(),
        _ => step,
      };
    }).toList();
    return changed ? result : null;
  }

  // -------------------------------------------------------------------------
  // Private utilities
  // -------------------------------------------------------------------------

  /// Escapes special LIKE pattern characters (`%`, `_`, `\`) in [input] so
  /// that user-typed text is treated as a literal string rather than a
  /// pattern wildcard.
  String _escapeLikePattern(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Singleton [PlanRepository] provider.
///
/// [keepAlive: true] — the repository must outlive any individual screen so
/// that watch streams remain active and the database is not torn down.
///
/// Override in tests with a mock or an [AppDatabase.forTesting] instance:
/// ```dart
/// final container = ProviderContainer(overrides: [
///   planRepositoryProvider.overrideWithValue(FakePlanRepository()),
/// ]);
/// ```
@Riverpod(keepAlive: true)
PlanRepository planRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final sync = ref.watch(syncServiceProvider);
  return DriftPlanRepository(db, syncService: sync);
}
