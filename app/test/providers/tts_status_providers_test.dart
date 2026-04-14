/// Unit tests for [planTtsStatusProvider] (TASK-032) and
/// [isTtsReadyProvider] (TASK-033).
///
/// ## Test Coverage
///
/// ### planTtsStatus / $pollTtsStatus
/// 1. **Polling sequence** — yields TtsStatusInfo on each successful poll.
/// 2. **Backoff formula** — delay multiplies by 1.5× up to 30s max.
/// 3. **Terminal state `completed`** — polling stops after one `completed` event.
/// 4. **Terminal state `partial`** — polling stops after one `partial` event.
/// 5. **Terminal state `failed`** — polling stops after one `failed` event.
/// 6. **Non-terminal states** — polling continues for `none`, `pending`, `processing`.
/// 7. **API error recovery** — PlanApiException is swallowed; stream stays open.
/// 8. **Unexpected error recovery** — non-PlanApiException also swallowed.
/// 9. **10-minute timeout** — stream closes when deadline expires with no terminal state.
/// 10. **Local cache update** — DB rows are written after each successful poll.
/// 11. **Auto-cancel on dispose** — cancellation flag halts the loop promptly.
/// 12. **Cache update failure** — DB write error is non-fatal; status still yielded.
///
/// ### isTtsReady
/// 13. **Returns false while loading** — AsyncLoading from planByIdProvider.
/// 14. **Returns true from cache** — ttsStatus=='completed' in local cache.
/// 15. **Non-completed cache statuses** — returns false for all non-'completed' values.
/// 16. **Null plan** — returns false when plan does not exist.
/// 17. **Polling fallback** — returns true when poll yields 'completed'.
/// 18. **Non-completed terminal poll states** — 'partial'/'failed' polls return false.
/// 19. **Cache takes priority over poll** — cache 'completed' wins over stale poll.
///
/// ## Strategy
///
/// Tests target [$$pollTtsStatus] directly so they can inject:
/// - Zero-duration [delayFn] to avoid real wall-clock waits.
/// - A fake [PlanApiService] that returns a pre-programmed sequence.
/// - An in-memory [AppDatabase] to verify cache writes.
///
/// ## Running
/// ```
/// flutter test test/providers/tts_status_providers_test.dart
/// ```
library tts_status_providers_test;

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/models/audio_file_url.dart';
import 'package:instructor/models/library_plan_summary.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/tts_status_info.dart';
import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/providers/tts_status_providers.dart';
import 'package:instructor/services/plan_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Creates a fresh in-memory [AppDatabase] for each test.
AppDatabase _inMemoryDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// No-op delay function — replaces [Future.delayed] so tests run instantly.
Future<void> _noDelay(Duration _) async {}

/// Builds a [TtsStatusInfo] with sensible defaults for the given [status].
TtsStatusInfo _makeStatus(String status, {int total = 10, int completed = 0}) {
  return TtsStatusInfo(
    planId: 'plan-test-id',
    status: status,
    total: total,
    completed: completed,
  );
}

/// Seeds [db] with a minimal plan row so DB writes in [$$pollTtsStatus] have
/// an existing row to update.
Future<void> _seedPlan(AppDatabase db, String planId) async {
  final now = DateTime.now();
  await db.into(db.plansTable).insert(
    PlansTableCompanion(
      id: Value(planId),
      name: const Value('Test Plan'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake PlanApiService
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a pre-programmed sequence of [TtsStatusInfo] objects, one per call.
///
/// Throws [PlanApiException] when [throwOnNext] is true; resets after throw.
class _SequentialFakeApi implements PlanApiService {
  _SequentialFakeApi(this._sequence);

  final List<TtsStatusInfo> _sequence;
  int _index = 0;

  bool throwOnNext = false;
  bool throwUnexpectedOnNext = false;
  int getTtsStatusCallCount = 0;

  @override
  Future<TtsStatusInfo> getTtsStatus(String planId) async {
    getTtsStatusCallCount++;
    if (throwOnNext) {
      throwOnNext = false;
      throw const PlanApiException('Simulated API error');
    }
    if (throwUnexpectedOnNext) {
      throwUnexpectedOnNext = false;
      throw StateError('Simulated unexpected error');
    }
    if (_index >= _sequence.length) {
      throw const PlanApiException('No more statuses in sequence');
    }
    return _sequence[_index++];
  }

  // ── Unused stubs ──────────────────────────────────────────────────────────

  @override
  Future<List<Plan>> fetchUserPlans() async => [];
  @override
  Future<Plan> getPlanById(String id) => throw UnimplementedError();
  @override
  Future<String> savePlan(Plan plan) => throw UnimplementedError();
  @override
  Future<void> deletePlan(String id) => throw UnimplementedError();
  @override
  Future<void> activatePlan(String planId, {required String voice, required String locale, required String speechRate}) => throw UnimplementedError();
  @override
  Future<List<LibraryPlanSummary>> fetchLibraryPlans({
    String? category,
    String? search,
    int page = 1,
  }) =>
      throw UnimplementedError();
  @override
  Future<Plan> getLibraryPlanById(String id) => throw UnimplementedError();
  @override
  Future<List<AudioFileUrl>> getAudioUrls(String planId) => throw UnimplementedError();
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Collects all events from [stream] until it closes. Returns the list.
Future<List<TtsStatusInfo>> _collect(Stream<TtsStatusInfo> stream) async {
  final results = <TtsStatusInfo>[];
  await for (final item in stream) {
    results.add(item);
  }
  return results;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  const planId = 'plan-test-id';

  // ── 1. Polling sequence ────────────────────────────────────────────────────
  group('polling sequence', () {
    test('emits each status from the API in order', () async {
      final db = _inMemoryDb();
      addTearDown(db.close);
      await _seedPlan(db, planId);

      final api = _SequentialFakeApi([
        _makeStatus('processing', completed: 3),
        _makeStatus('processing', completed: 7),
        _makeStatus('completed', completed: 10),
      ]);

      final results = await _collect($pollTtsStatus(
        api: api,
        db: db,
        planId: planId,
        initialDelay: Duration.zero,
        maxDelay: const Duration(seconds: 30),
        delayFn: _noDelay,
      ));

      expect(results, hasLength(3));
      expect(results[0].status, 'processing');
      expect(results[0].completed, 3);
      expect(results[1].completed, 7);
      expect(results[2].status, 'completed');
      expect(results[2].completed, 10);
    });
  });

  // ── 2. Terminal states ─────────────────────────────────────────────────────
  group('terminal states', () {
    for (final terminalStatus in ['completed', 'partial', 'failed']) {
      test('stops polling after $terminalStatus status', () async {
        final db = _inMemoryDb();
        addTearDown(db.close);
        await _seedPlan(db, planId);

        final api = _SequentialFakeApi([
          _makeStatus(terminalStatus, completed: 10),
          // This should never be fetched:
          _makeStatus('processing', completed: 0),
        ]);

        final results = await _collect($pollTtsStatus(
          api: api,
          db: db,
          planId: planId,
          initialDelay: Duration.zero,
          delayFn: _noDelay,
        ));

        expect(results, hasLength(1));
        expect(results.first.status, terminalStatus);
        // Only one API call should have been made.
        expect(api.getTtsStatusCallCount, 1);
      });
    }

    for (final nonTerminal in ['none', 'pending', 'processing']) {
      test('continues polling for non-terminal state: $nonTerminal', () async {
        final db = _inMemoryDb();
        addTearDown(db.close);
        await _seedPlan(db, planId);

        // Two non-terminal statuses followed by a terminal.
        final api = _SequentialFakeApi([
          _makeStatus(nonTerminal),
          _makeStatus(nonTerminal),
          _makeStatus('completed', completed: 10),
        ]);

        final results = await _collect($pollTtsStatus(
          api: api,
          db: db,
          planId: planId,
          initialDelay: Duration.zero,
          delayFn: _noDelay,
        ));

        expect(results, hasLength(3));
        expect(results.last.status, 'completed');
      });
    }
  });

  // ── 3. API error recovery ──────────────────────────────────────────────────
  group('error recovery', () {
    test('swallows PlanApiException and continues polling', () async {
      final db = _inMemoryDb();
      addTearDown(db.close);
      await _seedPlan(db, planId);

      final api = _SequentialFakeApi([
        _makeStatus('processing', completed: 2),
        _makeStatus('completed', completed: 10),
      ]);

      // Inject an error before the first real status.
      api.throwOnNext = true;

      final results = await _collect($pollTtsStatus(
        api: api,
        db: db,
        planId: planId,
        initialDelay: Duration.zero,
        delayFn: _noDelay,
      ));

      // The error poll should be counted but not yield.
      expect(api.getTtsStatusCallCount, 3); // error + processing + completed
      expect(results, hasLength(2));
      expect(results[0].status, 'processing');
      expect(results[1].status, 'completed');
    });

    test('swallows unexpected exceptions and continues polling', () async {
      final db = _inMemoryDb();
      addTearDown(db.close);
      await _seedPlan(db, planId);

      final api = _SequentialFakeApi([
        _makeStatus('completed', completed: 10),
      ]);

      api.throwUnexpectedOnNext = true;

      final results = await _collect($pollTtsStatus(
        api: api,
        db: db,
        planId: planId,
        initialDelay: Duration.zero,
        delayFn: _noDelay,
      ));

      expect(results, hasLength(1));
      expect(results.first.status, 'completed');
    });
  });

  // ── 4. 10-minute timeout ───────────────────────────────────────────────────
  group('timeout', () {
    test('stops emitting after timeout expires', () async {
      final db = _inMemoryDb();
      addTearDown(db.close);
      await _seedPlan(db, planId);

      // API returns non-terminal status indefinitely.
      int callCount = 0;
      final api = _SequentialFakeApi(List.generate(
        1000,
        (_) => _makeStatus('processing', completed: callCount++),
      ));

      // Use an extremely short timeout so the test doesn't wait long.
      const veryShortTimeout = Duration(milliseconds: 5);

      final results = await _collect($pollTtsStatus(
        api: api,
        db: db,
        planId: planId,
        initialDelay: Duration.zero,
        timeout: veryShortTimeout,
        delayFn: (d) => Future.delayed(const Duration(milliseconds: 1)),
      ));

      // The stream should have closed before consuming all 1000 statuses.
      expect(results.length, lessThan(1000));
    });
  });

  // ── 5. Local cache update ──────────────────────────────────────────────────
  group('local cache update', () {
    test('writes ttsStatus, ttsTotal, ttsCompleted to DB on each poll', () async {
      final db = _inMemoryDb();
      addTearDown(db.close);
      await _seedPlan(db, planId);

      final api = _SequentialFakeApi([
        _makeStatus('processing', total: 10, completed: 4),
        _makeStatus('completed', total: 10, completed: 10),
      ]);

      await _collect($pollTtsStatus(
        api: api,
        db: db,
        planId: planId,
        initialDelay: Duration.zero,
        delayFn: _noDelay,
      ));

      // Check the final DB state reflects the last poll.
      final row = await (db.select(db.plansTable)
            ..where((t) => t.id.equals(planId)))
          .getSingleOrNull();

      expect(row, isNotNull);
      expect(row!.ttsStatus, 'completed');
      expect(row.ttsTotal, 10);
      expect(row.ttsCompleted, 10);
    });

    test('still yields status even when DB write fails (non-existent plan)', () async {
      final db = _inMemoryDb();
      addTearDown(db.close);
      // Intentionally NOT seeding the plan — DB update will be a no-op and
      // should not throw (Drift update silently matches 0 rows).

      final api = _SequentialFakeApi([
        _makeStatus('completed', completed: 10),
      ]);

      final results = await _collect($pollTtsStatus(
        api: api,
        db: db,
        planId: planId,
        initialDelay: Duration.zero,
        delayFn: _noDelay,
      ));

      // Should still emit the status even if no DB row was updated.
      expect(results, hasLength(1));
      expect(results.first.status, 'completed');
    });
  });

  // ── 6. Cancellation ───────────────────────────────────────────────────────
  group('cancellation', () {
    test('isCancelled flag stops the loop before next poll', () async {
      final db = _inMemoryDb();
      addTearDown(db.close);
      await _seedPlan(db, planId);

      var cancelled = false;

      // The delay function cancels the operation immediately after the first
      // delay so we can verify the loop exits cleanly.
      Future<void> cancellableDelay(Duration d) async {
        await Future.delayed(d);
        // Cancel after the first delay.
        cancelled = true;
      }

      final api = _SequentialFakeApi([
        _makeStatus('processing', completed: 2),
        // This second item should never be fetched after cancellation.
        _makeStatus('completed', completed: 10),
      ]);

      final results = await _collect($pollTtsStatus(
        api: api,
        db: db,
        planId: planId,
        initialDelay: Duration.zero,
        delayFn: cancellableDelay,
        isCancelled: () => cancelled,
      ));

      // Only the first status should have been emitted before cancellation.
      expect(results, hasLength(1));
      expect(results.first.status, 'processing');
    });

    test('isCancelled before first delay exits without emitting', () async {
      final db = _inMemoryDb();
      addTearDown(db.close);

      // Already cancelled before polling begins.
      final api = _SequentialFakeApi([_makeStatus('processing')]);

      final results = await _collect($pollTtsStatus(
        api: api,
        db: db,
        planId: planId,
        initialDelay: Duration.zero,
        delayFn: _noDelay,
        isCancelled: () => true,
      ));

      expect(results, isEmpty);
      expect(api.getTtsStatusCallCount, 0);
    });
  });

  // ── 7. isTtsReady ─────────────────────────────────────────────────────────
  group('isTtsReady', () {
    /// Creates a minimal [Plan] with the given [ttsStatus] for testing.
    Plan makePlan(String id, {String ttsStatus = 'none'}) {
      final now = DateTime.now();
      return Plan(
        id: id,
        name: 'Test Plan',
        createdAt: now,
        updatedAt: now,
        ttsStatus: ttsStatus,
      );
    }

    /// Waits for [isTtsReadyProvider] to settle by listening to it and
    /// allowing microtasks to flush.  Returns the final value.
    ///
    /// [listen] keeps the provider (and all its transitive watched providers)
    /// alive while we pump the event loop — this is necessary because
    /// [AutoDispose] providers are disposed as soon as they have no listeners.
    Future<bool> settleIsTtsReady(
      ProviderContainer container, {
      int pumps = 2,
    }) async {
      final values = <bool>[];
      final sub = container.listen(
        isTtsReadyProvider(planId),
        (_, next) => values.add(next),
        fireImmediately: true,
      );
      for (var i = 0; i < pumps; i++) {
        await Future.microtask(() {});
      }
      sub.close();
      return container.read(isTtsReadyProvider(planId));
    }

    test('returns false while plan is still loading (AsyncLoading)', () async {
      // planByIdProvider never resolves — simulates loading state.
      final container = ProviderContainer(
        overrides: [
          planByIdProvider(planId).overrideWith(
            (ref) => Completer<Plan?>().future, // never completes
          ),
          planTtsStatusProvider(planId).overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await settleIsTtsReady(container);
      expect(result, isFalse);
    });

    test('returns true when local cache shows completed after plan loads', () async {
      final plan = makePlan(planId, ttsStatus: 'completed');

      final container = ProviderContainer(
        overrides: [
          planByIdProvider(planId).overrideWith(
            (ref) => Future.value(plan),
          ),
          // planTtsStatusProvider should not matter — cache short-circuits it.
          planTtsStatusProvider(planId).overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Keep providers alive and allow the Future.value(plan) to settle.
      final result = await settleIsTtsReady(container, pumps: 3);
      expect(result, isTrue);
    });

    test('returns false when local cache shows non-completed status', () async {
      for (final status in ['none', 'pending', 'processing', 'partial', 'failed']) {
        final plan = makePlan(planId, ttsStatus: status);

        final container = ProviderContainer(
          overrides: [
            planByIdProvider(planId).overrideWith(
              (ref) => Future.value(plan),
            ),
            planTtsStatusProvider(planId).overrideWith(
              (ref) => const Stream.empty(), // no poll events
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await settleIsTtsReady(container, pumps: 3);
        expect(
          result,
          isFalse,
          reason: 'Expected false for ttsStatus=$status',
        );
      }
    });

    test('returns false when plan does not exist (null)', () async {
      final container = ProviderContainer(
        overrides: [
          planByIdProvider(planId).overrideWith(
            (ref) => Future.value(null), // plan not found
          ),
          planTtsStatusProvider(planId).overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await settleIsTtsReady(container, pumps: 3);
      expect(result, isFalse);
    });

    test('falls back to polling: returns true when poll yields completed', () async {
      final plan = makePlan(planId, ttsStatus: 'processing');
      final statusController = StreamController<TtsStatusInfo>();

      final container = ProviderContainer(
        overrides: [
          planByIdProvider(planId).overrideWith(
            (ref) => Future.value(plan),
          ),
          planTtsStatusProvider(planId).overrideWith(
            (ref) => statusController.stream,
          ),
        ],
      );
      addTearDown(() {
        container.dispose();
        statusController.close();
      });

      // Keep providers alive via an ongoing listener.
      final values = <bool>[];
      final sub = container.listen(
        isTtsReadyProvider(planId),
        (_, next) => values.add(next),
        fireImmediately: true,
      );
      addTearDown(sub.close);

      // Allow plan to load (Future.value resolves in next microtask).
      await Future.microtask(() {});
      // isTtsReady: plan is non-completed → still false.
      expect(container.read(isTtsReadyProvider(planId)), isFalse);

      // Poll returns a non-terminal status — still false.
      statusController.add(TtsStatusInfo(
        planId: planId,
        status: 'processing',
        total: 10,
        completed: 5,
      ));
      await Future.microtask(() {});
      expect(container.read(isTtsReadyProvider(planId)), isFalse);

      // Poll returns completed — now true.
      statusController.add(TtsStatusInfo(
        planId: planId,
        status: 'completed',
        total: 10,
        completed: 10,
      ));
      await Future.microtask(() {});
      expect(container.read(isTtsReadyProvider(planId)), isTrue);
    });

    test('returns false when poll yields non-completed terminal states', () async {
      for (final terminalStatus in ['partial', 'failed']) {
        final plan = makePlan(planId, ttsStatus: 'processing');
        final statusController = StreamController<TtsStatusInfo>();

        final container = ProviderContainer(
          overrides: [
            planByIdProvider(planId).overrideWith(
              (ref) => Future.value(plan),
            ),
            planTtsStatusProvider(planId).overrideWith(
              (ref) => statusController.stream,
            ),
          ],
        );
        addTearDown(() {
          container.dispose();
          statusController.close();
        });

        final sub = container.listen(
          isTtsReadyProvider(planId),
          (_, __) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        // Allow plan to load.
        await Future.microtask(() {});

        // Poll returns a non-completed terminal status.
        statusController.add(TtsStatusInfo(
          planId: planId,
          status: terminalStatus,
          total: 10,
          completed: terminalStatus == 'partial' ? 7 : 0,
        ));
        await Future.microtask(() {});

        expect(
          container.read(isTtsReadyProvider(planId)),
          isFalse,
          reason: 'Expected false for terminal poll status=$terminalStatus',
        );
      }
    });

    test('returns true from cache even when poll yields non-completed status', () async {
      // If local cache shows completed, isTtsReady should return true even if
      // the polling provider yields a stale non-completed status.
      final plan = makePlan(planId, ttsStatus: 'completed');
      final statusController = StreamController<TtsStatusInfo>();

      final container = ProviderContainer(
        overrides: [
          planByIdProvider(planId).overrideWith(
            (ref) => Future.value(plan),
          ),
          planTtsStatusProvider(planId).overrideWith(
            (ref) => statusController.stream,
          ),
        ],
      );
      addTearDown(() {
        container.dispose();
        statusController.close();
      });

      // Keep providers alive.
      final sub = container.listen(
        isTtsReadyProvider(planId),
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      // Allow plan to load (resolves to 'completed').
      await Future.microtask(() {});

      // Push a stale non-completed status from the poll.
      statusController.add(TtsStatusInfo(
        planId: planId,
        status: 'processing',
        total: 10,
        completed: 5,
      ));
      await Future.microtask(() {});

      // Cache shows completed, so isTtsReady must still be true.
      expect(container.read(isTtsReadyProvider(planId)), isTrue);
    });
  });

  // ── 8. Backoff computation (planTtsStatus) ────────────────────────────────
  group('backoff formula', () {
    test('delays increase by 1.5× capped at 30 s', () async {
      final db = _inMemoryDb();
      addTearDown(db.close);
      await _seedPlan(db, planId);

      final capturedDelays = <Duration>[];

      // We need enough non-terminal statuses to observe several backoff steps.
      final api = _SequentialFakeApi([
        _makeStatus('pending'),
        _makeStatus('processing'),
        _makeStatus('processing'),
        _makeStatus('processing'),
        _makeStatus('processing'),
        _makeStatus('completed', completed: 10),
      ]);

      await _collect($pollTtsStatus(
        api: api,
        db: db,
        planId: planId,
        initialDelay: const Duration(seconds: 2),
        maxDelay: const Duration(seconds: 30),
        backoffFactor: 1.5,
        delayFn: (d) async => capturedDelays.add(d),
      ));

      // Verify the backoff sequence: 2s, 3s, 4s (rounded), 6s (rounded), ...
      expect(capturedDelays[0], const Duration(seconds: 2)); // initial
      expect(capturedDelays[1], const Duration(milliseconds: 3000)); // 2 × 1.5
      expect(capturedDelays[2], const Duration(milliseconds: 4500)); // 3 × 1.5
      expect(capturedDelays[3], const Duration(milliseconds: 6750)); // 4.5 × 1.5
      expect(capturedDelays[4], const Duration(milliseconds: 10125)); // 6.75 × 1.5
    });

    test('delay is capped at maxDelay', () async {
      final db = _inMemoryDb();
      addTearDown(db.close);
      await _seedPlan(db, planId);

      final capturedDelays = <Duration>[];

      // Start at 20s — after one backoff it would be 30s; further would exceed max.
      final api = _SequentialFakeApi([
        _makeStatus('pending'),
        _makeStatus('pending'),
        _makeStatus('pending'),
        _makeStatus('completed', completed: 10),
      ]);

      await _collect($pollTtsStatus(
        api: api,
        db: db,
        planId: planId,
        initialDelay: const Duration(seconds: 20),
        maxDelay: const Duration(seconds: 30),
        backoffFactor: 1.5,
        delayFn: (d) async => capturedDelays.add(d),
      ));

      // 20s → 30s (20 × 1.5 = 30) → 30s (capped) → 30s (capped).
      expect(capturedDelays[0], const Duration(seconds: 20));
      expect(capturedDelays[1], const Duration(seconds: 30)); // 20 × 1.5
      expect(capturedDelays[2], const Duration(seconds: 30)); // capped
      expect(capturedDelays[3], const Duration(seconds: 30)); // capped
    });
  });
}
