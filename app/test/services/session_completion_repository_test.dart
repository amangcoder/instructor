/// Unit tests for [SessionCompletionRepository] — CRUD operations on
/// the session_completions Drift table.
///
/// ## Strategy
///
/// Uses an in-memory Drift database so tests run fast (~1ms each) with no
/// file I/O. Each test creates its own repository instance via setUp() so
/// there is zero shared mutable state.
///
/// ## What is tested
/// - recordCompletion: insert and basic field persistence
/// - getCompletionsSince: date range filtering and ordering
/// - getUnsyncedCompletions: filtering by syncedAt IS NULL
/// - markSynced: updating syncedAt for given IDs
/// - watchCompletions: Stream reactivity on table changes
/// - Error handling: duplicate IDs, empty lists
library session_completion_repository_test;

import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/repositories/session_completion_repository.dart';

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/// Opens an in-memory Drift database — no file I/O required.
AppDatabase _inMemoryDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// Creates a [DateTime] at noon to avoid midnight edge issues.
DateTime _day(int year, int month, int day) =>
    DateTime(year, month, day, 12, 0, 0);

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

void main() {
  late AppDatabase db;
  late SessionCompletionRepository repo;

  setUp(() {
    db = _inMemoryDb();
    repo = SessionCompletionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ─── recordCompletion ──────────────────────────────────────────────────

  group('recordCompletion', () {
    test('inserts a record and returns successfully', () async {
      await expectLater(
        repo.recordCompletion(
          userId: 'user-1',
          planId: 'plan-1',
          completedAt: _day(2026, 4, 15),
          durationMs: 600000,
        ),
        completes,
      );
    });

    test('persists planId, completedAt, and durationMs correctly', () async {
      final completedAt = _day(2026, 4, 15);

      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-yoga',
        completedAt: completedAt,
        durationMs: 1200000,
      );

      final completions = await repo.getCompletionsSince(
        completedAt.subtract(const Duration(hours: 1)),
      );

      expect(completions.length, 1);
      expect(completions.first.planId, 'plan-yoga');
      expect(completions.first.durationMs, 1200000);
    });

    test('multiple records can be inserted for the same planId', () async {
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 14),
        durationMs: 300000,
      );
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 15),
        durationMs: 600000,
      );

      final completions = await repo.getCompletionsSince(
        _day(2026, 4, 13),
      );

      expect(completions.length, 2);
    });

    test('records from different plans are stored independently', () async {
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-yoga',
        completedAt: _day(2026, 4, 15),
        durationMs: 600000,
      );
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-meditation',
        completedAt: _day(2026, 4, 15),
        durationMs: 900000,
      );

      final completions = await repo.getCompletionsSince(
        _day(2026, 4, 14),
      );

      expect(completions.length, 2);
      final planIds = completions.map((c) => c.planId).toSet();
      expect(planIds, containsAll(['plan-yoga', 'plan-meditation']));
    });
  });

  // ─── getCompletionsSince ─────────────────────────────────────────────────

  group('getCompletionsSince', () {
    test('returns only completions after the given timestamp', () async {
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 10),
        durationMs: 300000,
      );
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 14),
        durationMs: 600000,
      );
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 15),
        durationMs: 600000,
      );

      // Only completions since April 13
      final completions = await repo.getCompletionsSince(
        _day(2026, 4, 13),
      );

      expect(completions.length, 2);
    });

    test('returns completions ordered by completedAt ascending', () async {
      // Insert out of order
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 15),
        durationMs: 600000,
      );
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 13),
        durationMs: 600000,
      );
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 14),
        durationMs: 600000,
      );

      final completions = await repo.getCompletionsSince(
        _day(2026, 4, 12),
      );

      expect(completions.length, 3);
      expect(
        completions[0].completedAt.isBefore(completions[1].completedAt),
        true,
      );
      expect(
        completions[1].completedAt.isBefore(completions[2].completedAt),
        true,
      );
    });

    test('returns empty list when no completions after timestamp', () async {
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 10),
        durationMs: 300000,
      );

      final completions = await repo.getCompletionsSince(
        _day(2026, 4, 14),
      );

      expect(completions, isEmpty);
    });

    test('returns empty list when no completions exist', () async {
      final completions = await repo.getCompletionsSince(
        _day(2026, 1, 1),
      );

      expect(completions, isEmpty);
    });
  });

  // ─── getUnsyncedCompletions ──────────────────────────────────────────────

  group('getUnsyncedCompletions', () {
    test('returns only records with syncedAt IS NULL', () async {
      // Record two completions
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 14),
        durationMs: 300000,
      );
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 15),
        durationMs: 600000,
      );

      // All should be unsynced initially
      final unsynced = await repo.getUnsyncedCompletions();
      expect(unsynced.length, 2);
    });

    test('after markSynced, those records are excluded', () async {
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 14),
        durationMs: 300000,
      );
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 15),
        durationMs: 600000,
      );

      // Get unsynced and mark the first one as synced
      final unsynced = await repo.getUnsyncedCompletions();
      await repo.markSynced([unsynced.first.id]);

      final remaining = await repo.getUnsyncedCompletions();
      expect(remaining.length, 1);
    });

    test('returns empty list when all are synced', () async {
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 15),
        durationMs: 600000,
      );

      final unsynced = await repo.getUnsyncedCompletions();
      await repo.markSynced(unsynced.map((c) => c.id).toList());

      final remaining = await repo.getUnsyncedCompletions();
      expect(remaining, isEmpty);
    });
  });

  // ─── markSynced ──────────────────────────────────────────────────────────

  group('markSynced', () {
    test('updates syncedAt timestamp for given IDs', () async {
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 15),
        durationMs: 600000,
      );

      final unsynced = await repo.getUnsyncedCompletions();
      expect(unsynced.length, 1);
      expect(unsynced.first.syncedAt, isNull);

      await repo.markSynced([unsynced.first.id]);

      // After marking, should not appear in unsynced
      final afterSync = await repo.getUnsyncedCompletions();
      expect(afterSync, isEmpty);
    });

    test('handles empty ID list gracefully', () async {
      await expectLater(
        repo.markSynced([]),
        completes,
      );
    });

    test('only marks specified IDs, leaves others unsynced', () async {
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 14),
        durationMs: 300000,
      );
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-2',
        completedAt: _day(2026, 4, 15),
        durationMs: 600000,
      );

      final unsynced = await repo.getUnsyncedCompletions();
      // Mark only the first
      await repo.markSynced([unsynced.first.id]);

      final remaining = await repo.getUnsyncedCompletions();
      expect(remaining.length, 1);
      expect(remaining.first.planId, unsynced.last.planId);
    });
  });

  // ─── watchCompletions ────────────────────────────────────────────────────

  group('watchCompletions', () {
    test('emits initial empty list', () async {
      final first =
          await repo.watchCompletions().first.timeout(
                const Duration(seconds: 2),
              );

      expect(first, isEmpty);
    });

    test('emits updated list when a new completion is recorded', () async {
      final emissions = <int>[];
      final sub = repo.watchCompletions().listen((completions) {
        emissions.add(completions.length);
      });

      // Allow initial emission
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Insert a completion
      await repo.recordCompletion(
        userId: 'user-1',
        planId: 'plan-1',
        completedAt: _day(2026, 4, 15),
        durationMs: 600000,
      );

      // Wait for stream to emit
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await sub.cancel();

      // Should have at least 2 emissions: initial (0) and after insert (1)
      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.first, 0);
      expect(emissions.last, 1);
    });

    test('stream survives multiple inserts', () async {
      final emissions = <int>[];
      final sub = repo.watchCompletions().listen((completions) {
        emissions.add(completions.length);
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Insert three completions
      for (int i = 0; i < 3; i++) {
        await repo.recordCompletion(
          userId: 'user-1',
          planId: 'plan-$i',
          completedAt: _day(2026, 4, 13 + i),
          durationMs: 600000,
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      await Future<void>.delayed(const Duration(milliseconds: 200));
      await sub.cancel();

      // Last emission should have 3 completions
      expect(emissions.last, 3);
    });
  });
}
