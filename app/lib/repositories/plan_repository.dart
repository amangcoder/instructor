import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/database/tables/plans_table.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/services/plan_api_service.dart';
import 'plan_repository_mixin.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

/// CRUD and query operations for [Plan] objects backed by the Drift database.
///
/// All database access is performed via the [AppDatabase] instance injected
/// through the Riverpod provider. Use [watchUserPlans] for reactive UI bindings.
abstract class PlanRepository {
  /// Creates a new Plan and returns its server-assigned String UUID.
  ///
  /// If [plan.id] is empty a new UUID is generated locally. The returned
  /// [String] is the UUID that was persisted.
  Future<String> createPlan(Plan plan);

  /// Updates an existing Plan by [id].
  Future<void> updatePlan(String id, Plan plan);

  /// Deletes a Plan and its associated TTS cache entries.
  Future<void> deletePlan(String id);

  /// Fetches a single Plan by [id]; returns null if not found.
  Future<Plan?> getPlanById(String id);

  /// Marks a Plan as active by [id].
  ///
  /// For the local Drift implementation this flips [Plan.isActive] to true.
  /// The server-first [ApiPlanRepository] will additionally call the backend
  /// activation endpoint to trigger server-side GenAI TTS pre-generation.
  ///
  /// [voice], [locale], and [speechRate] are forwarded to the server so that
  /// pre-generated audio cache keys match the client's runtime requests.
  Future<void> activatePlan(
    String id, {
    required String voice,
    required String locale,
    required String speechRate,
  });

  /// Returns a reactive stream of the current user's Plans, sorted by
  /// [lastUsedAt] descending (most recently used first, nulls last), with
  /// optional filters:
  ///
  /// - [searchQuery]: case-insensitive LIKE filter on [Plan.name].
  /// - [category]: exact match on [Plan.category].
  Stream<List<Plan>> watchUserPlans({
    String? searchQuery,
    PlanCategory? category,
  });

  /// Updates the [Plan.lastUsedAt] timestamp to now.
  Future<void> updateLastUsed(String id);

  /// Remaps all plan voices using the given [voiceMap].
  ///
  /// For each plan, maps [defaultVoice] and every [SayStep.voiceId] through
  /// [voiceMap]. Voices not in the map are left unchanged.
  ///
  /// Returns the number of plans that were actually updated.
  Future<int> remapPlanVoices(Map<String, String> voiceMap);

  /// Fetches all plans from the server and atomically replaces the local
  /// SQLite cache.
  ///
  /// Implementations backed solely by a local database (e.g.
  /// [DriftPlanRepository]) treat this as a no-op. The server-first
  /// [ApiPlanRepository] performs a full sync: fetch → clear → bulk-insert.
  ///
  /// Throws [PlanApiException] on network failure; local cache is unchanged.
  Future<void> refreshFromServer();
}

// ---------------------------------------------------------------------------
// Concrete Drift implementation
// ---------------------------------------------------------------------------

/// Drift-backed implementation of [PlanRepository].
///
/// All writes use [into] / [update] / [delete] so that Drift's built-in
/// change-tracking automatically notifies any active [watchUserPlans] streams.
class DriftPlanRepository with PlanRepositoryMixin implements PlanRepository {
  DriftPlanRepository(this._db);

  final AppDatabase _db;

  // -------------------------------------------------------------------------
  // CRUD
  // -------------------------------------------------------------------------

  @override
  Future<String> createPlan(Plan plan) async {
    final now = DateTime.now();
    // Use the plan's existing id when non-empty (server-assigned UUID), or
    // generate a local UUID for plans created offline.
    final id = plan.id.isEmpty ? _uuid.v4() : plan.id;
    final companion = planToCompanion(plan).copyWith(
      id: Value(id),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
    await _db.into(_db.plansTable).insert(companion);
    return id;
  }

  @override
  Future<void> updatePlan(String id, Plan plan) async {
    final companion = planToCompanion(plan).copyWith(
      updatedAt: Value(DateTime.now()),
    );
    await (_db.update(_db.plansTable)
          ..where((t) => t.id.equals(id)))
        .write(companion);
  }

  @override
  Future<void> deletePlan(String id) async {
    // Delete TTS cache rows associated with this Plan first.
    // The TTS cache table stores a planId column for exactly this purpose.
    await (_db.delete(_db.ttsCacheTable)
          ..where((t) => t.planId.equals(id)))
        .go();

    // Now delete the Plan row itself.
    await (_db.delete(_db.plansTable)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  @override
  Future<Plan?> getPlanById(String id) async {
    final row = await (_db.select(_db.plansTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : rowToPlan(row);
  }

  @override
  Future<void> activatePlan(
    String id, {
    required String voice,
    required String locale,
    required String speechRate,
  }) async {
    // DriftPlanRepository is local-only — voice/locale/speechRate are unused
    // (no server-side pregen). Just flip the active flag.
    await (_db.update(_db.plansTable)
          ..where((t) => t.id.equals(id)))
        .write(const PlansTableCompanion(isActive: Value(true)));
  }

  // -------------------------------------------------------------------------
  // Reactive query
  // -------------------------------------------------------------------------

  @override
  Stream<List<Plan>> watchUserPlans({
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
        (t) => t.name.like('%${escapeLikePattern(searchQuery)}%'),
      );
    }

    if (category != null) {
      query.where((t) => t.category.equals(category.name));
    }

    return query.watch().map((rows) => rows.map(rowToPlan).toList());
  }

  // -------------------------------------------------------------------------
  // Timestamp helpers
  // -------------------------------------------------------------------------

  @override
  Future<void> updateLastUsed(String id) async {
    await (_db.update(_db.plansTable)
          ..where((t) => t.id.equals(id)))
        .write(PlansTableCompanion(lastUsedAt: Value(DateTime.now())));
  }

  // -------------------------------------------------------------------------
  // Server sync — no-op for local-only repository
  // -------------------------------------------------------------------------

  @override
  Future<void> refreshFromServer() async {
    // DriftPlanRepository is local-only; no server to sync with.
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
      final plan = rowToPlan(row);
      final newDefaultVoice =
          voiceMap[plan.defaultVoice] ?? plan.defaultVoice;
      final newSteps = remapSteps(plan.steps, voiceMap);

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
}

// ---------------------------------------------------------------------------
// Server-first implementation
// ---------------------------------------------------------------------------

/// Server-first implementation of [PlanRepository].
///
/// All mutations (create, update, delete, activate) are routed through the
/// [PlanApiService] first. On success the local SQLite cache is updated so that
/// [watchUserPlans] streams reflect the change immediately without requiring a
/// full server refresh.
///
/// Read operations ([getPlanById], [watchUserPlans]) are served from the local
/// Drift cache, which is populated either lazily (per-mutation) or in bulk via
/// [refreshFromServer].
class ApiPlanRepository with PlanRepositoryMixin implements PlanRepository {
  ApiPlanRepository({
    required PlanApiService planApiService,
    required AppDatabase db,
  })  : _api = planApiService,
        _db = db;

  final PlanApiService _api;
  final AppDatabase _db;

  // -------------------------------------------------------------------------
  // CRUD — API first, then cache
  // -------------------------------------------------------------------------

  @override
  Future<String> createPlan(Plan plan) async {
    // 1. Persist on the server; server returns the canonical UUID.
    final serverId = await _api.savePlan(plan);

    // 2. Write to local cache using the server-assigned id.
    //    Preserve createdAt from the caller; stamp updatedAt to now.
    final companion = planToCompanion(plan).copyWith(
      id: Value(serverId),
      updatedAt: Value(DateTime.now()),
    );
    await _db.into(_db.plansTable).insertOnConflictUpdate(companion);

    return serverId;
  }

  @override
  Future<void> updatePlan(String id, Plan plan) async {
    // 1. Send updated plan to server (id is embedded so server updates it).
    await _api.savePlan(plan.copyWith(id: id));

    // 2. Update local cache row.
    final companion = planToCompanion(plan).copyWith(
      updatedAt: Value(DateTime.now()),
    );
    await (_db.update(_db.plansTable)..where((t) => t.id.equals(id)))
        .write(companion);
  }

  @override
  Future<void> deletePlan(String id) async {
    // 1. Delete from server.
    await _api.deletePlan(id);

    // 2. Remove associated TTS cache entries first (FK constraint).
    await (_db.delete(_db.ttsCacheTable)..where((t) => t.planId.equals(id)))
        .go();

    // 3. Remove the plan row from the local cache.
    await (_db.delete(_db.plansTable)..where((t) => t.id.equals(id))).go();
  }

  // -------------------------------------------------------------------------
  // Read — from local SQLite cache
  // -------------------------------------------------------------------------

  @override
  Future<Plan?> getPlanById(String id) async {
    final row = await (_db.select(_db.plansTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : rowToPlan(row);
  }

  // -------------------------------------------------------------------------
  // Activation — API call + cache update
  // -------------------------------------------------------------------------

  @override
  Future<void> activatePlan(
    String id, {
    required String voice,
    required String locale,
    required String speechRate,
  }) async {
    // 1. Trigger server-side TTS pre-generation with the user's settings
    // so cache keys match runtime requests.
    await _api.activatePlan(id, voice: voice, locale: locale, speechRate: speechRate);

    // 2. Optimistically update local cache: mark active, set status to pending.
    await (_db.update(_db.plansTable)..where((t) => t.id.equals(id))).write(
      const PlansTableCompanion(
        isActive: Value(true),
        ttsStatus: Value('pending'),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Reactive stream — from local SQLite cache
  // -------------------------------------------------------------------------

  @override
  Stream<List<Plan>> watchUserPlans({
    String? searchQuery,
    PlanCategory? category,
  }) {
    final query = _db.select(_db.plansTable)
      ..orderBy([
        // Nulls-last ordering: isNull() returns 1 for NULL, 0 for non-NULL.
        (t) => OrderingTerm.asc(t.lastUsedAt.isNull()),
        // Most recently used first among non-null rows.
        (t) => OrderingTerm.desc(t.lastUsedAt),
        // Stable secondary sort by most recently updated.
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query.where(
        (t) => t.name.like('%${escapeLikePattern(searchQuery)}%'),
      );
    }

    if (category != null) {
      query.where((t) => t.category.equals(category.name));
    }

    return query.watch().map((rows) => rows.map(rowToPlan).toList());
  }

  // -------------------------------------------------------------------------
  // Timestamp — cache only (lastUsedAt is a client-side UX field)
  // -------------------------------------------------------------------------

  @override
  Future<void> updateLastUsed(String id) async {
    await (_db.update(_db.plansTable)..where((t) => t.id.equals(id)))
        .write(PlansTableCompanion(lastUsedAt: Value(DateTime.now())));
  }

  // -------------------------------------------------------------------------
  // Voice remapping — syncs each changed plan through the API
  // -------------------------------------------------------------------------

  @override
  Future<int> remapPlanVoices(Map<String, String> voiceMap) async {
    if (voiceMap.isEmpty) return 0;

    var updatedCount = 0;
    final allRows = await _db.select(_db.plansTable).get();
    for (final row in allRows) {
      final plan = rowToPlan(row);
      final newDefaultVoice =
          voiceMap[plan.defaultVoice] ?? plan.defaultVoice;
      final newSteps = remapSteps(plan.steps, voiceMap);

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

  // -------------------------------------------------------------------------
  // Bulk server sync
  // -------------------------------------------------------------------------

  /// Fetches all plans from the server and atomically replaces the local
  /// SQLite cache in a single Drift transaction.
  ///
  /// This is the primary mechanism for bootstrapping the cache after login
  /// or after a background sync. All existing plan rows are deleted and
  /// replaced by the server's authoritative list. TTS cache rows are not
  /// touched — audio files remain valid across refreshes.
  ///
  /// Throws [PlanApiException] if the server request fails; in that case the
  /// local cache is unchanged because the transaction is rolled back.
  Future<void> refreshFromServer() async {
    // Fetch before opening the transaction so a network failure does not hold
    // a write lock on the database.
    final serverPlans = await _api.fetchUserPlans();

    await _db.transaction(() async {
      // Clear all existing plan rows atomically.
      await _db.delete(_db.plansTable).go();

      // Bulk-insert server plans. Plans with no server id are skipped.
      for (final plan in serverPlans) {
        if (plan.id.isEmpty) continue;
        final companion = planToCompanion(plan).copyWith(
          id: Value(plan.id),
        );
        await _db.into(_db.plansTable).insert(companion);
      }
    });
  }
}

