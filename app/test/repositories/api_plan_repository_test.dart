/// Unit tests for ApiPlanRepository (TASK-015).
///
/// ## Test Coverage
///
/// 1. **createPlan** — calls API savePlan, writes server-assigned id to cache.
/// 2. **updatePlan** — calls API savePlan, writes updated row to cache.
/// 3. **deletePlan** — calls API deletePlan, removes plan + TTS cache rows.
/// 4. **getPlanById** — reads from local cache only (no API call).
/// 5. **activatePlan** — calls API activatePlan, optimistically marks cache.
/// 6. **updateLastUsed** — updates local cache timestamp (no API call).
/// 7. **watchUserPlans** — returns reactive Drift stream with sorting/filters.
/// 8. **refreshFromServer** — bulk-syncs atomically; replaces entire cache.
/// 9. **remapPlanVoices** — remaps voices through API for changed plans.
/// 10. **Error propagation** — API exceptions bubble up without corrupting cache.
///
/// ## Running
/// ```
/// flutter test test/repositories/api_plan_repository_test.dart
/// ```
library api_plan_repository_test;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/models/audio_file_url.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/library_plan_summary.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/models/tts_status_info.dart';
import 'package:instructor/repositories/plan_repository.dart';
import 'package:instructor/services/plan_api_service.dart';

// ---------------------------------------------------------------------------
// In-memory Drift database
// ---------------------------------------------------------------------------

AppDatabase _inMemoryDb() => AppDatabase.forTesting(NativeDatabase.memory());

// ---------------------------------------------------------------------------
// Fake PlanApiService
// ---------------------------------------------------------------------------

/// In-memory fake [PlanApiService] that records all calls and returns
/// configurable results. Optionally throws a [PlanApiException] on any method.
class _FakePlanApiService implements PlanApiService {
  final List<String> calls = [];

  // Configurable return values
  List<Plan> fetchUserPlansResult = [];
  String savePlanResult = 'server-uuid-001';
  PlanApiException? nextError;

  void _maybeThrow(String callName) {
    if (nextError != null) {
      final e = nextError!;
      nextError = null;
      throw e;
    }
    calls.add(callName);
  }

  @override
  Future<List<Plan>> fetchUserPlans() async {
    _maybeThrow('fetchUserPlans');
    return fetchUserPlansResult;
  }

  @override
  Future<Plan> getPlanById(String id) async {
    _maybeThrow('getPlanById:$id');
    throw const PlanApiException('not implemented in fake');
  }

  @override
  Future<String> savePlan(Plan plan) async {
    _maybeThrow('savePlan:${plan.name}');
    return savePlanResult;
  }

  @override
  Future<void> deletePlan(String id) async {
    _maybeThrow('deletePlan:$id');
  }

  @override
  Future<void> activatePlan(String planId) async {
    _maybeThrow('activatePlan:$planId');
  }

  @override
  Future<List<LibraryPlanSummary>> fetchLibraryPlans({
    String? category,
    String? search,
    int page = 1,
  }) async {
    _maybeThrow('fetchLibraryPlans');
    return [];
  }

  @override
  Future<Plan> getLibraryPlanById(String id) async {
    _maybeThrow('getLibraryPlanById:$id');
    throw const PlanApiException('not implemented in fake');
  }

  @override
  Future<TtsStatusInfo> getTtsStatus(String planId) async {
    _maybeThrow('getTtsStatus:$planId');
    throw const PlanApiException('not implemented in fake');
  }

  @override
  Future<List<AudioFileUrl>> getAudioUrls(String planId) async {
    _maybeThrow('getAudioUrls:$planId');
    return [];
  }
}

// ---------------------------------------------------------------------------
// Test data builders
// ---------------------------------------------------------------------------

Plan _makePlan({
  String id = '',
  String name = 'Test Plan',
  PlanCategory category = PlanCategory.custom,
  List<PlanStep> steps = const [],
  bool isActive = false,
  String ttsStatus = 'none',
  int ttsTotal = 0,
  int ttsCompleted = 0,
  String defaultVoice = 'aoede',
  DateTime? lastUsedAt,
}) {
  final now = DateTime.now();
  return Plan(
    id: id,
    name: name,
    category: category,
    steps: steps,
    defaultVoice: defaultVoice,
    isActive: isActive,
    ttsStatus: ttsStatus,
    ttsTotal: ttsTotal,
    ttsCompleted: ttsCompleted,
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
  late _FakePlanApiService api;
  late ApiPlanRepository repo;

  setUp(() {
    db = _inMemoryDb();
    api = _FakePlanApiService();
    repo = ApiPlanRepository(planApiService: api, db: db);
  });

  tearDown(() async {
    await db.close();
  });

  // ─── createPlan ──────────────────────────────────────────────────────────

  group('createPlan', () {
    test('calls API savePlan and returns server-assigned UUID', () async {
      api.savePlanResult = 'srv-uuid-abc';
      final id = await repo.createPlan(_makePlan(name: 'My Plan'));

      expect(id, 'srv-uuid-abc');
      expect(api.calls, contains('savePlan:My Plan'));
    });

    test('writes plan to local cache with server-assigned id', () async {
      api.savePlanResult = 'cached-uuid-1';
      await repo.createPlan(_makePlan(name: 'Cached Plan'));

      final cached = await repo.getPlanById('cached-uuid-1');
      expect(cached, isNotNull);
      expect(cached!.id, 'cached-uuid-1');
      expect(cached.name, 'Cached Plan');
    });

    test('local cache is searchable after createPlan', () async {
      api.savePlanResult = 'id-yoga';
      await repo.createPlan(
        _makePlan(name: 'Morning Yoga', category: PlanCategory.yoga),
      );

      final results =
          await repo.watchUserPlans(category: PlanCategory.yoga).first;
      expect(results, hasLength(1));
      expect(results.first.name, 'Morning Yoga');
    });

    test('no API call is made for getPlanById (reads from cache)', () async {
      api.savePlanResult = 'id-read-only';
      await repo.createPlan(_makePlan(name: 'Read Plan'));

      final callsBefore = List<String>.from(api.calls);
      await repo.getPlanById('id-read-only');
      // No new API calls should have been made for the read
      expect(api.calls, callsBefore);
    });

    test('API exception propagates without writing to cache', () async {
      api.nextError = const PlanApiException('Server error 500');

      expect(
        () => repo.createPlan(_makePlan(name: 'Failed Plan')),
        throwsA(isA<PlanApiException>()),
      );

      // Nothing should be in the cache.
      final stream = await repo.watchUserPlans().first;
      expect(stream, isEmpty);
    });
  });

  // ─── updatePlan ──────────────────────────────────────────────────────────

  group('updatePlan', () {
    test('calls API savePlan with the plan id', () async {
      api.savePlanResult = 'plan-1';
      await repo.createPlan(_makePlan(id: '', name: 'Original'));

      await repo.updatePlan('plan-1', _makePlan(id: 'plan-1', name: 'Updated'));
      expect(api.calls, contains('savePlan:Updated'));
    });

    test('updates local cache after successful API call', () async {
      api.savePlanResult = 'plan-upd';
      await repo.createPlan(_makePlan(name: 'Before Update'));

      await repo.updatePlan(
          'plan-upd', _makePlan(id: 'plan-upd', name: 'After Update'));

      final cached = await repo.getPlanById('plan-upd');
      expect(cached!.name, 'After Update');
    });

    test('API exception propagates; cache retains original value', () async {
      api.savePlanResult = 'plan-err';
      await repo.createPlan(_makePlan(name: 'Stable Plan'));

      api.nextError = const PlanApiException('503 unavailable');
      expect(
        () => repo.updatePlan(
            'plan-err', _makePlan(id: 'plan-err', name: 'Changed Plan')),
        throwsA(isA<PlanApiException>()),
      );

      // Cache must still have the original value.
      final cached = await repo.getPlanById('plan-err');
      expect(cached!.name, 'Stable Plan');
    });

    test('updatePlan stamps updatedAt', () async {
      api.savePlanResult = 'plan-ts';
      final before = DateTime.now();
      await repo.createPlan(_makePlan(name: 'TS Plan'));

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.updatePlan('plan-ts', _makePlan(id: 'plan-ts', name: 'TS'));

      final cached = await repo.getPlanById('plan-ts');
      expect(cached!.updatedAt.isAfter(before), isTrue);
    });
  });

  // ─── deletePlan ──────────────────────────────────────────────────────────

  group('deletePlan', () {
    test('calls API deletePlan', () async {
      api.savePlanResult = 'del-1';
      await repo.createPlan(_makePlan(name: 'To Delete'));

      await repo.deletePlan('del-1');
      expect(api.calls, contains('deletePlan:del-1'));
    });

    test('removes plan from local cache', () async {
      api.savePlanResult = 'del-2';
      await repo.createPlan(_makePlan(name: 'Delete Me'));

      await repo.deletePlan('del-2');
      expect(await repo.getPlanById('del-2'), isNull);
    });

    test('watchUserPlans emits updated list after deletion', () async {
      api.savePlanResult = 'del-stream';
      await repo.createPlan(_makePlan(name: 'Watch Delete'));

      final before = await repo.watchUserPlans().first;
      expect(before, hasLength(1));

      await repo.deletePlan('del-stream');

      final after = await repo.watchUserPlans().first;
      expect(after, isEmpty);
    });

    test('API exception propagates; plan remains in cache', () async {
      api.savePlanResult = 'del-fail';
      await repo.createPlan(_makePlan(name: 'Should Survive'));

      api.nextError = const PlanApiException('403 forbidden');
      expect(
        () => repo.deletePlan('del-fail'),
        throwsA(isA<PlanApiException>()),
      );

      // Plan must still be in the cache.
      expect(await repo.getPlanById('del-fail'), isNotNull);
    });
  });

  // ─── getPlanById ─────────────────────────────────────────────────────────

  group('getPlanById', () {
    test('returns null for unknown id', () async {
      expect(await repo.getPlanById('nonexistent-id'), isNull);
    });

    test('returns the correct plan from cache', () async {
      api.savePlanResult = 'get-1';
      await repo.createPlan(_makePlan(name: 'Known Plan'));

      final plan = await repo.getPlanById('get-1');
      expect(plan, isNotNull);
      expect(plan!.id, 'get-1');
      expect(plan.name, 'Known Plan');
    });

    test('makes no API calls (reads from cache only)', () async {
      api.savePlanResult = 'cache-only';
      await repo.createPlan(_makePlan(name: 'Cache Plan'));

      final callsBefore = List<String>.from(api.calls);
      await repo.getPlanById('cache-only');
      expect(api.calls, callsBefore); // no new API calls
    });
  });

  // ─── activatePlan ────────────────────────────────────────────────────────

  group('activatePlan', () {
    test('calls API activatePlan', () async {
      api.savePlanResult = 'act-1';
      await repo.createPlan(_makePlan(name: 'Activate Me'));

      await repo.activatePlan('act-1');
      expect(api.calls, contains('activatePlan:act-1'));
    });

    test('sets isActive=true in local cache', () async {
      api.savePlanResult = 'act-2';
      await repo.createPlan(_makePlan(name: 'Inactive Plan', isActive: false));

      await repo.activatePlan('act-2');

      final cached = await repo.getPlanById('act-2');
      expect(cached!.isActive, isTrue);
    });

    test('sets ttsStatus=pending in local cache', () async {
      api.savePlanResult = 'act-3';
      await repo.createPlan(_makePlan(name: 'TTS None Plan', ttsStatus: 'none'));

      await repo.activatePlan('act-3');

      final cached = await repo.getPlanById('act-3');
      expect(cached!.ttsStatus, 'pending');
    });

    test('API exception propagates; cache is not modified', () async {
      api.savePlanResult = 'act-fail';
      await repo.createPlan(
          _makePlan(name: 'Stable', isActive: false, ttsStatus: 'none'));

      api.nextError = const PlanApiException('500 server error');
      expect(
        () => repo.activatePlan('act-fail'),
        throwsA(isA<PlanApiException>()),
      );

      final cached = await repo.getPlanById('act-fail');
      expect(cached!.isActive, isFalse);
      expect(cached.ttsStatus, 'none');
    });
  });

  // ─── updateLastUsed ──────────────────────────────────────────────────────

  group('updateLastUsed', () {
    test('stamps lastUsedAt to approximately now', () async {
      api.savePlanResult = 'lused-1';
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      await repo.createPlan(_makePlan(name: 'Used Plan'));

      await repo.updateLastUsed('lused-1');

      final plan = await repo.getPlanById('lused-1');
      expect(plan!.lastUsedAt, isNotNull);
      expect(plan.lastUsedAt!.isAfter(before), isTrue);
    });

    test('makes no API calls (local cache only)', () async {
      api.savePlanResult = 'lused-no-api';
      await repo.createPlan(_makePlan(name: 'Local Only'));

      final callsBefore = List<String>.from(api.calls);
      await repo.updateLastUsed('lused-no-api');
      expect(api.calls, callsBefore);
    });

    test('promotes plan to top of watchUserPlans stream', () async {
      final now = DateTime.now();

      api.savePlanResult = 'lused-a';
      await repo.createPlan(
          _makePlan(name: 'A', lastUsedAt: now.subtract(const Duration(hours: 1))));

      api.savePlanResult = 'lused-b';
      await repo.createPlan(
          _makePlan(name: 'B', lastUsedAt: now.subtract(const Duration(hours: 2))));

      // B is currently last; promote B.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.updateLastUsed('lused-b');

      final plans = await repo.watchUserPlans().first;
      expect(plans.first.id, 'lused-b');
    });
  });

  // ─── watchUserPlans ──────────────────────────────────────────────────────

  group('watchUserPlans', () {
    test('returns empty stream when cache is empty', () async {
      final plans = await repo.watchUserPlans().first;
      expect(plans, isEmpty);
    });

    test('emits updated list when a plan is added', () async {
      final stream = repo.watchUserPlans();
      expect(await stream.first, isEmpty);

      api.savePlanResult = 'watch-new';
      await repo.createPlan(_makePlan(name: 'New Plan'));

      expect(await stream.first, hasLength(1));
    });

    test('sorts by lastUsedAt descending, nulls last', () async {
      final now = DateTime.now();

      api.savePlanResult = 'w-yesterday';
      await repo.createPlan(
          _makePlan(name: 'Used Yesterday',
              lastUsedAt: now.subtract(const Duration(days: 1))));

      api.savePlanResult = 'w-now';
      await repo.createPlan(
          _makePlan(name: 'Used Now', lastUsedAt: now));

      api.savePlanResult = 'w-never';
      await repo.createPlan(_makePlan(name: 'Never Used'));

      final plans = await repo.watchUserPlans().first;
      expect(plans[0].name, 'Used Now');
      expect(plans[1].name, 'Used Yesterday');
      expect(plans[2].name, 'Never Used');
    });

    test('filters by searchQuery (case-insensitive LIKE)', () async {
      api.savePlanResult = 'w-yoga-1';
      await repo.createPlan(_makePlan(name: 'Morning Yoga'));
      api.savePlanResult = 'w-yoga-2';
      await repo.createPlan(_makePlan(name: 'Evening Yoga'));
      api.savePlanResult = 'w-focus';
      await repo.createPlan(_makePlan(name: 'Deep Focus'));

      final results = await repo.watchUserPlans(searchQuery: 'yoga').first;
      expect(results, hasLength(2));
      expect(results.every((p) => p.name.toLowerCase().contains('yoga')),
          isTrue);
    });

    test('filters by category', () async {
      api.savePlanResult = 'w-yoga-cat';
      await repo.createPlan(
          _makePlan(name: 'Yoga Flow', category: PlanCategory.yoga));
      api.savePlanResult = 'w-meditate';
      await repo.createPlan(
          _makePlan(name: 'Meditation', category: PlanCategory.meditation));

      final results =
          await repo.watchUserPlans(category: PlanCategory.yoga).first;
      expect(results, hasLength(1));
      expect(results.first.category, PlanCategory.yoga);
    });

    test('applies both searchQuery and category filters simultaneously',
        () async {
      api.savePlanResult = 'w-combo-1';
      await repo.createPlan(
          _makePlan(name: 'Yoga A', category: PlanCategory.yoga));
      api.savePlanResult = 'w-combo-2';
      await repo.createPlan(
          _makePlan(name: 'Yoga B', category: PlanCategory.yoga));
      api.savePlanResult = 'w-combo-3';
      await repo.createPlan(
          _makePlan(name: 'Focus', category: PlanCategory.focus));

      final results = await repo
          .watchUserPlans(searchQuery: 'yoga', category: PlanCategory.yoga)
          .first;
      expect(results, hasLength(2));
    });

    test('escapes LIKE special characters in searchQuery', () async {
      api.savePlanResult = 'w-percent';
      await repo.createPlan(_makePlan(name: '100% Effort'));
      api.savePlanResult = 'w-other';
      await repo.createPlan(_makePlan(name: 'Other Plan'));

      final results =
          await repo.watchUserPlans(searchQuery: '%').first;
      expect(results, hasLength(1));
      expect(results.first.name, '100% Effort');
    });
  });

  // ─── refreshFromServer ───────────────────────────────────────────────────

  group('refreshFromServer', () {
    test('calls fetchUserPlans on the API', () async {
      api.fetchUserPlansResult = [];
      await repo.refreshFromServer();
      expect(api.calls, contains('fetchUserPlans'));
    });

    test('populates local cache from server response', () async {
      final now = DateTime.now();
      api.fetchUserPlansResult = [
        Plan(
          id: 'srv-1',
          name: 'Server Plan A',
          createdAt: now,
          updatedAt: now,
        ),
        Plan(
          id: 'srv-2',
          name: 'Server Plan B',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await repo.refreshFromServer();

      final plans = await repo.watchUserPlans().first;
      expect(plans, hasLength(2));
      final names = plans.map((p) => p.name).toSet();
      expect(names, containsAll(['Server Plan A', 'Server Plan B']));
    });

    test('replaces entire cache atomically (removes stale local plans)',
        () async {
      // Pre-populate cache with a plan that the server no longer knows about.
      api.savePlanResult = 'local-only';
      await repo.createPlan(_makePlan(name: 'Local Only Plan'));

      // Server returns a different plan.
      final now = DateTime.now();
      api.fetchUserPlansResult = [
        Plan(
          id: 'server-fresh',
          name: 'Server Fresh Plan',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await repo.refreshFromServer();

      final plans = await repo.watchUserPlans().first;
      expect(plans, hasLength(1));
      expect(plans.first.id, 'server-fresh');
      expect(plans.first.name, 'Server Fresh Plan');

      // The old local-only plan should be gone.
      expect(await repo.getPlanById('local-only'), isNull);
    });

    test('skips plans with empty id from server response', () async {
      final now = DateTime.now();
      api.fetchUserPlansResult = [
        Plan(id: '', name: 'No ID Plan', createdAt: now, updatedAt: now),
        Plan(
            id: 'valid-id',
            name: 'Valid Plan',
            createdAt: now,
            updatedAt: now),
      ];

      await repo.refreshFromServer();

      final plans = await repo.watchUserPlans().first;
      expect(plans, hasLength(1));
      expect(plans.first.id, 'valid-id');
    });

    test('clears cache when server returns empty list', () async {
      // Pre-populate with a plan.
      api.savePlanResult = 'pre-pop';
      await repo.createPlan(_makePlan(name: 'Pre-populated'));

      api.fetchUserPlansResult = [];
      await repo.refreshFromServer();

      final plans = await repo.watchUserPlans().first;
      expect(plans, isEmpty);
    });

    test('API exception leaves cache unchanged (transaction rolled back)',
        () async {
      // Pre-populate cache.
      api.savePlanResult = 'stable';
      await repo.createPlan(_makePlan(name: 'Stable Plan'));

      api.nextError = const PlanApiException('network error');
      expect(
        () => repo.refreshFromServer(),
        throwsA(isA<PlanApiException>()),
      );

      // Cache should still have the original plan.
      final plans = await repo.watchUserPlans().first;
      expect(plans, hasLength(1));
      expect(plans.first.name, 'Stable Plan');
    });
  });

  // ─── remapPlanVoices ─────────────────────────────────────────────────────

  group('remapPlanVoices', () {
    test('returns 0 when voiceMap is empty', () async {
      api.savePlanResult = 'remap-empty';
      await repo.createPlan(_makePlan(name: 'Plan', defaultVoice: 'aoede'));

      final count = await repo.remapPlanVoices({});
      expect(count, 0);
    });

    test('remaps defaultVoice via API update', () async {
      api.savePlanResult = 'remap-voice';
      await repo.createPlan(_makePlan(name: 'Voice Plan', defaultVoice: 'nova'));

      api.savePlanResult = 'remap-voice'; // same id for the update
      final count = await repo.remapPlanVoices({'nova': 'aoede'});
      expect(count, 1);
    });

    test('does not update plans where voice is not in the map', () async {
      api.savePlanResult = 'remap-skip';
      await repo.createPlan(_makePlan(name: 'Skip Plan', defaultVoice: 'puck'));

      final callsBefore = api.calls.length;
      final count = await repo.remapPlanVoices({'nova': 'aoede'}); // puck not in map
      expect(count, 0);
      expect(api.calls.length, callsBefore); // no update calls
    });
  });

  // ─── Integration: create → update → delete ───────────────────────────────

  group('integration: full CRUD lifecycle', () {
    test('create → read → update → delete', () async {
      // 1. Create
      api.savePlanResult = 'lifecycle-id';
      final id = await repo.createPlan(_makePlan(name: 'Lifecycle Plan'));
      expect(id, 'lifecycle-id');

      // 2. Read
      final created = await repo.getPlanById(id);
      expect(created!.name, 'Lifecycle Plan');

      // 3. Update
      api.savePlanResult = id; // server returns same id
      await repo.updatePlan(id, created.copyWith(name: 'Lifecycle Updated'));
      final updated = await repo.getPlanById(id);
      expect(updated!.name, 'Lifecycle Updated');

      // 4. Delete
      await repo.deletePlan(id);
      expect(await repo.getPlanById(id), isNull);
    });
  });

  // ─── ApiPlanRepository implements PlanRepository ─────────────────────────

  group('type conformance', () {
    test('ApiPlanRepository is a PlanRepository', () {
      expect(repo, isA<PlanRepository>());
    });

    test('ApiPlanRepository is an ApiPlanRepository', () {
      expect(repo, isA<ApiPlanRepository>());
    });
  });
}
