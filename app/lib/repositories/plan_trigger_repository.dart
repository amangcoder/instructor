// Plan-trigger repository — CRUD and sync-state queries for the
// [PlanTriggersTable] Drift table.
//
// Responsibilities:
//   * Create / update / soft-delete trigger rows (bumps updated_at so sync
//     picks them up).
//   * Expose reactive lists for UI (upcoming, recurring, all active).
//   * Serve as the bridge between UI, native scheduler, and server sync:
//     every state change is recorded here first, then downstream consumers
//     (AndroidAlarmService, SyncService) read from this source of truth.

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/database/app_database.dart';

part 'plan_trigger_repository.g.dart';

class PlanTriggerRepository {
  PlanTriggerRepository(this._db);

  final AppDatabase _db;

  // ── Create / update / delete ─────────────────────────────────────────────

  /// Inserts or replaces a trigger by [clientId]. Returns the row id.
  Future<int> upsert({
    required String clientId,
    required String userId,
    required String planId,
    required String title,
    required DateTime startUtc,
    required int durationMinutes,
    required String recurrence,
    String? serverId,
  }) {
    final now = DateTime.now();
    return _db.into(_db.planTriggersTable).insertOnConflictUpdate(
          PlanTriggersTableCompanion.insert(
            clientId: clientId,
            userId: userId,
            planId: planId,
            title: title,
            startUtc: startUtc,
            durationMinutes: durationMinutes,
            recurrence: Value(recurrence),
            serverId: Value(serverId),
            updatedAt: Value(now),
            // syncedAt intentionally left null so the row is picked up on the
            // next push cycle.
          ),
        );
  }

  /// Marks a trigger as deleted. Actual row deletion happens after the
  /// tombstone has been acknowledged by the server (in [purgeSyncedTombstones]).
  Future<void> softDelete(String clientId) async {
    final now = DateTime.now();
    await (_db.update(_db.planTriggersTable)
          ..where((t) => t.clientId.equals(clientId)))
        .write(
      PlanTriggersTableCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Records that [clientId] was successfully pushed to the server, storing
  /// the server-assigned id and clearing its dirty state.
  Future<void> markSynced({
    required String clientId,
    required String serverId,
    required DateTime serverUpdatedAt,
  }) async {
    await (_db.update(_db.planTriggersTable)
          ..where((t) => t.clientId.equals(clientId)))
        .write(
      PlanTriggersTableCompanion(
        serverId: Value(serverId),
        syncedAt: Value(serverUpdatedAt),
      ),
    );
  }

  /// Deletes tombstoned rows that have already been synced — the server knows
  /// they're gone, so we no longer need to retain the local ghost.
  Future<int> purgeSyncedTombstones() {
    return (_db.delete(_db.planTriggersTable)
          ..where((t) =>
              t.deletedAt.isNotNull() & t.syncedAt.isBiggerOrEqual(t.updatedAt)))
        .go();
  }

  // ── Reads ────────────────────────────────────────────────────────────────

  /// Returns a trigger by its client UUID, or null when absent.
  Future<PlanTriggersTableData?> getByClientId(String clientId) {
    return (_db.select(_db.planTriggersTable)
          ..where((t) => t.clientId.equals(clientId)))
        .getSingleOrNull();
  }

  /// Watches active (non-deleted) triggers for [userId], most-recent first.
  Stream<List<PlanTriggersTableData>> watchActive(String userId) {
    return (_db.select(_db.planTriggersTable)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.startUtc)]))
        .watch();
  }

  /// Returns every active trigger for [userId] whose first occurrence is in
  /// the future. Used at app startup to re-arm native alarms.
  Future<List<PlanTriggersTableData>> getUpcoming(String userId, DateTime now) {
    return (_db.select(_db.planTriggersTable)
          ..where((t) =>
              t.userId.equals(userId) &
              t.deletedAt.isNull() &
              t.startUtc.isBiggerThanValue(now)))
        .get();
  }

  /// Returns rows that need to be pushed to the server — anything that has
  /// changed since its last sync, plus brand-new rows that have never synced.
  Future<List<PlanTriggersTableData>> getDirty(String userId) async {
    final rows = await (_db.select(_db.planTriggersTable)
          ..where((t) => t.userId.equals(userId)))
        .get();
    return rows
        .where((r) => r.syncedAt == null || r.updatedAt.isAfter(r.syncedAt!))
        .toList();
  }
}

@Riverpod(keepAlive: true)
PlanTriggerRepository planTriggerRepository(Ref ref) {
  return PlanTriggerRepository(ref.watch(appDatabaseProvider));
}
