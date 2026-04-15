/// Unit tests for [PlanTriggerRepository] — CRUD + sync-state queries on the
/// plan_triggers Drift table.
///
/// Uses an in-memory Drift database (no file I/O) and covers:
///   - upsert (insert + update via clientId conflict)
///   - softDelete (tombstone semantics)
///   - markSynced + getDirty (sync-state filtering)
///   - purgeSyncedTombstones (garbage collection of acked deletes)
///   - getUpcoming (future + non-deleted filter for native rearm)
///   - watchActive (reactive UI stream)
library plan_trigger_repository_test;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/repositories/plan_trigger_repository.dart';

AppDatabase _inMemoryDb() => AppDatabase.forTesting(NativeDatabase.memory());

const _userA = 'user-a';
const _userB = 'user-b';

Future<void> _seed(
  PlanTriggerRepository repo, {
  required String clientId,
  String userId = _userA,
  String planId = 'plan-1',
  String title = 'Yoga Flow',
  required DateTime startUtc,
  String recurrence = 'none',
}) async {
  await repo.upsert(
    clientId: clientId,
    userId: userId,
    planId: planId,
    title: title,
    startUtc: startUtc,
    durationMinutes: 30,
    recurrence: recurrence,
  );
}

void main() {
  late AppDatabase db;
  late PlanTriggerRepository repo;

  setUp(() {
    db = _inMemoryDb();
    repo = PlanTriggerRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('upsert', () {
    test('inserts a new row and reads it back by clientId', () async {
      await _seed(
        repo,
        clientId: 'cid-1',
        startUtc: DateTime.utc(2026, 4, 20, 8),
      );

      final row = await repo.getByClientId('cid-1');
      expect(row, isNotNull);
      expect(row!.userId, _userA);
      expect(row.planId, 'plan-1');
      expect(row.title, 'Yoga Flow');
      expect(row.recurrence, 'none');
      // Drift stores DateTimeColumn as Unix epoch and returns a local-zone
      // DateTime. Compare the underlying instant, not the wall-clock zone.
      expect(row.startUtc.isAtSameMomentAs(DateTime.utc(2026, 4, 20, 8)), isTrue);
      expect(row.deletedAt, isNull);
      expect(row.syncedAt, isNull);
    });

    test('repeated upsert with same clientId updates fields and clears syncedAt',
        () async {
      await _seed(
        repo,
        clientId: 'cid-2',
        startUtc: DateTime.utc(2026, 4, 21, 7),
      );
      // Mark synced at a moment safely in the past so the subsequent re-upsert
      // produces an updated_at strictly greater than syncedAt and re-enters
      // the dirty set.
      await repo.markSynced(
        clientId: 'cid-2',
        serverId: 'srv-2',
        serverUpdatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      // Re-upsert with new title — should bump updated_at and leave the row
      // dirty for the next push.
      await _seed(
        repo,
        clientId: 'cid-2',
        title: 'Different Title',
        startUtc: DateTime.utc(2026, 4, 21, 7),
      );

      final dirty = await repo.getDirty(_userA);
      expect(dirty.map((r) => r.clientId), contains('cid-2'));
      final updated = await repo.getByClientId('cid-2');
      expect(updated!.title, 'Different Title');
    });
  });

  group('softDelete', () {
    test('sets deletedAt and bumps updatedAt', () async {
      await _seed(
        repo,
        clientId: 'cid-3',
        startUtc: DateTime.utc(2026, 4, 22, 9),
      );
      await repo.softDelete('cid-3');

      final row = await repo.getByClientId('cid-3');
      expect(row, isNotNull);
      expect(row!.deletedAt, isNotNull);
    });

    test('soft-deleted rows are excluded from getUpcoming', () async {
      final now = DateTime.utc(2026, 4, 15);
      await _seed(
        repo,
        clientId: 'cid-keep',
        startUtc: now.add(const Duration(days: 2)),
      );
      await _seed(
        repo,
        clientId: 'cid-gone',
        startUtc: now.add(const Duration(days: 3)),
      );
      await repo.softDelete('cid-gone');

      final upcoming = await repo.getUpcoming(_userA, now);
      expect(upcoming.map((r) => r.clientId), ['cid-keep']);
    });
  });

  group('getDirty', () {
    test('returns rows that have never been synced', () async {
      await _seed(
        repo,
        clientId: 'cid-fresh',
        startUtc: DateTime.utc(2026, 4, 23),
      );
      final dirty = await repo.getDirty(_userA);
      expect(dirty.map((r) => r.clientId), ['cid-fresh']);
    });

    test('omits rows whose syncedAt is up to date', () async {
      await _seed(
        repo,
        clientId: 'cid-clean',
        startUtc: DateTime.utc(2026, 4, 24),
      );
      // Mark it synced with a syncedAt strictly after its updatedAt.
      await repo.markSynced(
        clientId: 'cid-clean',
        serverId: 'srv-clean',
        serverUpdatedAt: DateTime.now().add(const Duration(minutes: 1)),
      );

      final dirty = await repo.getDirty(_userA);
      expect(
        dirty.map((r) => r.clientId),
        isNot(contains('cid-clean')),
      );
    });

    test('scopes by userId', () async {
      await _seed(
        repo,
        clientId: 'cid-a',
        userId: _userA,
        startUtc: DateTime.utc(2026, 4, 25),
      );
      await _seed(
        repo,
        clientId: 'cid-b',
        userId: _userB,
        startUtc: DateTime.utc(2026, 4, 25),
      );

      final dirtyA = await repo.getDirty(_userA);
      expect(dirtyA.map((r) => r.clientId), ['cid-a']);
    });
  });

  group('purgeSyncedTombstones', () {
    test('deletes only acked tombstones', () async {
      await _seed(
        repo,
        clientId: 'cid-acked',
        startUtc: DateTime.utc(2026, 4, 26),
      );
      await _seed(
        repo,
        clientId: 'cid-pending',
        startUtc: DateTime.utc(2026, 4, 27),
      );
      await repo.softDelete('cid-acked');
      await repo.softDelete('cid-pending');

      // Ack only the first delete by stamping syncedAt >= updatedAt.
      final acked = await repo.getByClientId('cid-acked');
      await repo.markSynced(
        clientId: 'cid-acked',
        serverId: 'srv-acked',
        serverUpdatedAt: acked!.updatedAt,
      );

      final removed = await repo.purgeSyncedTombstones();
      expect(removed, 1);
      expect(await repo.getByClientId('cid-acked'), isNull);
      expect(await repo.getByClientId('cid-pending'), isNotNull);
    });
  });

  group('getUpcoming', () {
    test('filters to future, non-deleted rows for the user', () async {
      final now = DateTime.utc(2026, 4, 15, 12);
      await _seed(
        repo,
        clientId: 'cid-past',
        startUtc: now.subtract(const Duration(hours: 2)),
      );
      await _seed(
        repo,
        clientId: 'cid-future',
        startUtc: now.add(const Duration(hours: 2)),
      );
      await _seed(
        repo,
        clientId: 'cid-other-user',
        userId: _userB,
        startUtc: now.add(const Duration(days: 1)),
      );

      final upcoming = await repo.getUpcoming(_userA, now);
      expect(upcoming.map((r) => r.clientId), ['cid-future']);
    });
  });

  group('watchActive', () {
    test('emits when a new row is inserted', () async {
      final stream = repo.watchActive(_userA);
      final emissions = <int>[];
      final sub = stream.listen((rows) => emissions.add(rows.length));

      // Initial empty emission.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await _seed(
        repo,
        clientId: 'cid-watch',
        startUtc: DateTime.utc(2026, 4, 30),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await sub.cancel();
      expect(emissions, contains(1));
    });
  });
}
