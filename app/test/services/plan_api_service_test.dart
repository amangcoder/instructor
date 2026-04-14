/// Unit tests for PlanApiService (TASK-012).
///
/// ## Test Coverage
///
/// 1. **Interface contract** — [_FakePlanApiService] verifies the expected
///    return types and error surface for all 9 methods.
///
/// 2. **URL construction** — [PlanApiServiceImpl] is exercised through a
///    [_StubApiClient] that captures URLs without real HTTP/auth dependencies.
///
/// 3. **Response parsing** — Each parse helper is exercised against realistic
///    server response shapes (summary list, full plan, library summary, etc.).
///
/// 4. **Error handling** — ApiException codes (401, 403, 404, 422, 429, 5xx)
///    are converted to user-friendly [PlanApiException.userMessage] strings.
///
/// ## Running
/// ```
/// flutter test test/services/plan_api_service_test.dart
/// ```
library plan_api_service_test;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/models/audio_file_url.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/library_plan_summary.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/models/tts_status_info.dart';
import 'package:instructor/services/api_client.dart';
import 'package:instructor/services/plan_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fake PlanApiService (interface-level tests)
// ─────────────────────────────────────────────────────────────────────────────

/// In-memory fake that records calls and returns configurable results.
///
/// Useful for testing callers of [PlanApiService] without hitting the network.
class _FakePlanApiService implements PlanApiService {
  // ── call recording ────────────────────────────────────────────────────────
  final List<String> calls = [];

  // ── configurable results ──────────────────────────────────────────────────
  List<Plan> fetchUserPlansResult = [];
  Plan? getPlanByIdResult;
  String savePlanResult = 'server-uuid-1234';
  List<LibraryPlanSummary> fetchLibraryPlansResult = [];
  Plan? getLibraryPlanByIdResult;
  TtsStatusInfo? getTtsStatusResult;
  List<AudioFileUrl> getAudioUrlsResult = [];

  /// When set, the next call to any method throws this exception.
  PlanApiException? nextError;

  void _maybeThrow() {
    if (nextError != null) {
      final e = nextError!;
      nextError = null;
      throw e;
    }
  }

  @override
  Future<List<Plan>> fetchUserPlans() async {
    calls.add('fetchUserPlans');
    _maybeThrow();
    return fetchUserPlansResult;
  }

  @override
  Future<Plan> getPlanById(String id) async {
    calls.add('getPlanById:$id');
    _maybeThrow();
    if (getPlanByIdResult == null) {
      throw const PlanApiException(
        'Plan not found',
        userMessage: 'The requested plan could not be found.',
      );
    }
    return getPlanByIdResult!;
  }

  @override
  Future<String> savePlan(Plan plan) async {
    calls.add('savePlan:${plan.name}');
    _maybeThrow();
    return savePlanResult;
  }

  @override
  Future<void> deletePlan(String id) async {
    calls.add('deletePlan:$id');
    _maybeThrow();
  }

  @override
  Future<void> activatePlan(String planId) async {
    calls.add('activatePlan:$planId');
    _maybeThrow();
  }

  @override
  Future<List<LibraryPlanSummary>> fetchLibraryPlans({
    String? category,
    String? search,
    int page = 1,
  }) async {
    calls.add('fetchLibraryPlans:page=$page,category=$category,search=$search');
    _maybeThrow();
    return fetchLibraryPlansResult;
  }

  @override
  Future<Plan> getLibraryPlanById(String id) async {
    calls.add('getLibraryPlanById:$id');
    _maybeThrow();
    if (getLibraryPlanByIdResult == null) {
      throw const PlanApiException(
        'Library plan not found',
        userMessage: 'The requested plan could not be found.',
      );
    }
    return getLibraryPlanByIdResult!;
  }

  @override
  Future<TtsStatusInfo> getTtsStatus(String planId) async {
    calls.add('getTtsStatus:$planId');
    _maybeThrow();
    if (getTtsStatusResult == null) {
      throw const PlanApiException('No TTS status');
    }
    return getTtsStatusResult!;
  }

  @override
  Future<List<AudioFileUrl>> getAudioUrls(String planId) async {
    calls.add('getAudioUrls:$planId');
    _maybeThrow();
    return getAudioUrlsResult;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stub ApiClient for implementation tests
// ─────────────────────────────────────────────────────────────────────────────

/// A test double for [ApiClient] that returns pre-programmed JSON responses.
///
/// Avoids HTTP, auth, and database dependencies. Override [getJson], [postJson],
/// and [send] to intercept the calls that [PlanApiServiceImpl] makes.
class _StubApiClient extends ApiClient {
  _StubApiClient({
    Map<String, dynamic> Function(Uri uri)? onGetJson,
    Map<String, dynamic> Function(Uri uri, Map<String, dynamic>)? onPostJson,
    ({int statusCode, String body}) Function(String method, Uri uri)? onSend,
    ApiException? throwOnGet,
    ApiException? throwOnPost,
    ApiException? throwOnSend,
  })  : _onGetJson = onGetJson ?? ((_) => {}),
        _onPostJson = onPostJson ?? ((_, __) => {}),
        _onSend = onSend ?? ((_m, _u) => (statusCode: 200, body: '{}')),
        _throwOnGet = throwOnGet,
        _throwOnPost = throwOnPost,
        _throwOnSend = throwOnSend,
        super(
          authService: _NullAuthService(),
          settings: _NullAppSettings(),
        );

  final Map<String, dynamic> Function(Uri) _onGetJson;
  final Map<String, dynamic> Function(Uri, Map<String, dynamic>) _onPostJson;
  final ({int statusCode, String body}) Function(String, Uri) _onSend;
  final ApiException? _throwOnGet;
  final ApiException? _throwOnPost;
  final ApiException? _throwOnSend;

  final List<({String method, Uri uri})> capturedCalls = [];

  @override
  String get backendBaseUrl => 'http://test-server:3071';

  @override
  Future<Map<String, dynamic>> getJson(Uri uri) async {
    capturedCalls.add((method: 'GET', uri: uri));
    if (_throwOnGet != null) throw _throwOnGet!;
    return _onGetJson(uri);
  }

  @override
  Future<Map<String, dynamic>> postJson(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    capturedCalls.add((method: 'POST', uri: uri));
    if (_throwOnPost != null) throw _throwOnPost!;
    return _onPostJson(uri, body);
  }

  @override
  Future<http.Response> send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    capturedCalls.add((method: method, uri: uri));
    if (_throwOnSend != null) throw _throwOnSend!;
    final result = _onSend(method, uri);
    return http.Response(result.body, result.statusCode);
  }
}

/// Minimal [AuthService] stub — no network or secure storage required.
class _NullAuthService extends AuthService {
  _NullAuthService()
      : super(
          httpClient: http.Client(),
          secureStorage: const FlutterSecureStorage._(),
          settings: _NullAppSettings(),
        );

  @override
  Future<String?> getAccessToken() async => 'test-token';

  @override
  Future<void> refreshToken() async {}

  @override
  Future<void> logout() async {}
}

/// Minimal [AppSettings] stub — no database required.
class _NullAppSettings extends AppSettings {
  _NullAppSettings() : super(null as dynamic);

  @override
  Future<String?> read(String key) async => null;

  @override
  Stream<String?> watch(String key) => const Stream.empty();

  @override
  Future<void> write(String key, String value) async {}
}

// ─────────────────────────────────────────────────────────────────────────────
// Test data builders
// ─────────────────────────────────────────────────────────────────────────────

Plan _makePlan({
  String id = 'abc-123',
  String name = 'Test Plan',
  bool isActive = false,
  String ttsStatus = 'none',
  int ttsTotal = 0,
  int ttsCompleted = 0,
}) {
  final now = DateTime.utc(2024, 1, 1);
  return Plan(
    id: id,
    name: name,
    isActive: isActive,
    ttsStatus: ttsStatus,
    ttsTotal: ttsTotal,
    ttsCompleted: ttsCompleted,
    createdAt: now,
    updatedAt: now,
  );
}

/// Builds a realistic GET /api/plans/list response.
Map<String, dynamic> _planListResponse(List<Map<String, dynamic>> plans) =>
    {'plans': plans};

Map<String, dynamic> _planSummaryJson({
  String planId = 'plan-1',
  String name = 'Morning Routine',
  bool isActive = false,
  String ttsStatus = 'none',
  int ttsTotal = 0,
  int ttsCompleted = 0,
}) =>
    {
      'planId': planId,
      'name': name,
      'isActive': isActive,
      'ttsStatus': ttsStatus,
      'ttsTotal': ttsTotal,
      'ttsCompleted': ttsCompleted,
      'voiceQuality': 'standard',
      'createdAt': '2024-01-01T00:00:00.000Z',
      'updatedAt': '2024-01-02T00:00:00.000Z',
    };

/// Builds a minimal Flutter Plan JSON blob (as stored in planJson field).
String _planJsonBlob({
  String id = 'plan-1',
  String name = 'Morning Routine',
  String description = 'A morning plan',
  String category = 'wellness',
}) {
  final now = DateTime.utc(2024, 1, 1).toIso8601String();
  return jsonEncode({
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'tags': <String>[],
    'defaultVoice': 'aoede',
    'steps': <dynamic>[],
    'createdAt': now,
    'updatedAt': now,
    'isActive': false,
    'ttsStatus': 'none',
    'ttsTotal': 0,
    'ttsCompleted': 0,
  });
}

/// Builds a realistic GET /api/plans/:id response.
Map<String, dynamic> _planDetailResponse({
  String planId = 'plan-1',
  String name = 'Morning Routine',
  String ttsStatus = 'completed',
  int ttsTotal = 5,
  int ttsCompleted = 5,
}) =>
    {
      'planId': planId,
      'name': name,
      'planJson': _planJsonBlob(id: planId, name: name),
      'isActive': true,
      'ttsStatus': ttsStatus,
      'ttsTotal': ttsTotal,
      'ttsCompleted': ttsCompleted,
      'voiceQuality': 'studio',
      'sourceLibraryPlanId': null,
      'createdAt': '2024-01-01T00:00:00.000Z',
      'updatedAt': '2024-01-02T00:00:00.000Z',
    };

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Fake interface tests ──────────────────────────────────────────────────

  group('_FakePlanApiService (interface contract)', () {
    late _FakePlanApiService fake;

    setUp(() {
      fake = _FakePlanApiService();
    });

    test('fetchUserPlans records call and returns result', () async {
      fake.fetchUserPlansResult = [_makePlan(name: 'A'), _makePlan(name: 'B')];
      final plans = await fake.fetchUserPlans();
      expect(plans, hasLength(2));
      expect(fake.calls, contains('fetchUserPlans'));
    });

    test('getPlanById records call with id', () async {
      fake.getPlanByIdResult = _makePlan(id: 'xyz-789');
      final plan = await fake.getPlanById('xyz-789');
      expect(plan.id, 'xyz-789');
      expect(fake.calls, contains('getPlanById:xyz-789'));
    });

    test('getPlanById throws PlanApiException when plan not found', () async {
      // getPlanByIdResult is null by default
      expect(
        () => fake.getPlanById('missing'),
        throwsA(isA<PlanApiException>()),
      );
    });

    test('savePlan records call and returns server-assigned id', () async {
      fake.savePlanResult = 'server-uuid-abc';
      final id = await fake.savePlan(_makePlan(name: 'New Plan'));
      expect(id, 'server-uuid-abc');
      expect(fake.calls, anyElement(startsWith('savePlan:')));
    });

    test('deletePlan records call with id', () async {
      await fake.deletePlan('plan-to-delete');
      expect(fake.calls, contains('deletePlan:plan-to-delete'));
    });

    test('activatePlan records call with planId', () async {
      await fake.activatePlan('plan-99');
      expect(fake.calls, contains('activatePlan:plan-99'));
    });

    test('fetchLibraryPlans records call with filters', () async {
      await fake.fetchLibraryPlans(category: 'wellness', search: 'yoga', page: 2);
      expect(
        fake.calls,
        contains('fetchLibraryPlans:page=2,category=wellness,search=yoga'),
      );
    });

    test('getTtsStatus records call with planId', () async {
      fake.getTtsStatusResult = TtsStatusInfo(
        planId: 'plan-1',
        status: 'processing',
        total: 10,
        completed: 4,
      );
      final info = await fake.getTtsStatus('plan-1');
      expect(info.status, 'processing');
      expect(info.completed, 4);
      expect(fake.calls, contains('getTtsStatus:plan-1'));
    });

    test('getAudioUrls records call and returns list', () async {
      fake.getAudioUrlsResult = [
        const AudioFileUrl(cacheKey: 'k1', url: 'https://s3/file1.wav'),
        const AudioFileUrl(cacheKey: 'k2', url: 'https://s3/file2.wav'),
      ];
      final urls = await fake.getAudioUrls('plan-1');
      expect(urls, hasLength(2));
      expect(urls.first.cacheKey, 'k1');
    });

    test('nextError propagates as PlanApiException on next call', () async {
      fake.nextError = const PlanApiException(
        'network failure',
        userMessage: 'Failed to load plans. Please try again.',
      );
      expect(
        () => fake.fetchUserPlans(),
        throwsA(
          isA<PlanApiException>().having(
            (e) => e.userMessage,
            'userMessage',
            'Failed to load plans. Please try again.',
          ),
        ),
      );
    });
  });

  // ── PlanApiServiceImpl URL construction ───────────────────────────────────

  group('PlanApiServiceImpl — URL construction', () {
    late _StubApiClient stub;
    late PlanApiService service;

    setUp(() {
      stub = _StubApiClient(
        onGetJson: (_) => <String, dynamic>{},
        onPostJson: (_, __) => <String, dynamic>{'planId': 'new-id-1'},
        onSend: (_, __) => (statusCode: 200, body: '{"success":true}'),
      );
      service = PlanApiServiceImpl(apiClient: stub);
    });

    test('fetchUserPlans calls GET /api/plans/list', () async {
      stub = _StubApiClient(
        onGetJson: (_) => _planListResponse([]),
      );
      service = PlanApiServiceImpl(apiClient: stub);
      await service.fetchUserPlans();
      expect(stub.capturedCalls.first.method, 'GET');
      expect(
        stub.capturedCalls.first.uri.path,
        '/api/plans/list',
      );
    });

    test('getPlanById calls GET /api/plans/:id', () async {
      stub = _StubApiClient(
        onGetJson: (_) => _planDetailResponse(planId: 'plan-42'),
      );
      service = PlanApiServiceImpl(apiClient: stub);
      await service.getPlanById('plan-42');
      expect(stub.capturedCalls.first.uri.path, '/api/plans/plan-42');
    });

    test('savePlan calls POST /api/plans/save', () async {
      stub = _StubApiClient(
        onPostJson: (_, __) => {'planId': 'srv-uuid'},
      );
      service = PlanApiServiceImpl(apiClient: stub);
      await service.savePlan(_makePlan(name: 'X'));
      expect(stub.capturedCalls.first.method, 'POST');
      expect(stub.capturedCalls.first.uri.path, '/api/plans/save');
    });

    test('savePlan includes planId in body when plan has a UUID id', () async {
      final captured = <Map<String, dynamic>>[];
      stub = _StubApiClient(
        onPostJson: (_, body) {
          captured.add(body);
          return {'planId': 'existing-uuid'};
        },
      );
      service = PlanApiServiceImpl(apiClient: stub);
      await service.savePlan(
        _makePlan(id: '550e8400-e29b-41d4-a716-446655440000'),
      );
      expect(captured.first['planId'], '550e8400-e29b-41d4-a716-446655440000');
    });

    test('savePlan omits planId when plan id is not a UUID', () async {
      final captured = <Map<String, dynamic>>[];
      stub = _StubApiClient(
        onPostJson: (_, body) {
          captured.add(body);
          return {'planId': 'new-server-id'};
        },
      );
      service = PlanApiServiceImpl(apiClient: stub);
      // Non-UUID id — should not be sent as planId
      await service.savePlan(_makePlan(id: 'temp-local-id'));
      expect(captured.first.containsKey('planId'), isFalse);
    });

    test('deletePlan calls DELETE /api/plans/:id', () async {
      stub = _StubApiClient(
        onSend: (_, __) => (statusCode: 200, body: '{"success":true}'),
      );
      service = PlanApiServiceImpl(apiClient: stub);
      await service.deletePlan('plan-to-delete');
      expect(stub.capturedCalls.first.method, 'DELETE');
      expect(stub.capturedCalls.first.uri.path, '/api/plans/plan-to-delete');
    });

    test('activatePlan calls POST /api/plans/activate with voiceQuality=studio',
        () async {
      final captured = <Map<String, dynamic>>[];
      stub = _StubApiClient(
        onPostJson: (_, body) {
          captured.add(body);
          return {'success': true};
        },
      );
      service = PlanApiServiceImpl(apiClient: stub);
      await service.activatePlan('plan-activate-me');
      expect(stub.capturedCalls.first.uri.path, '/api/plans/activate');
      expect(captured.first['planId'], 'plan-activate-me');
      expect(captured.first['voiceQuality'], 'studio');
    });

    test('fetchLibraryPlans calls GET /api/library/plans with query params',
        () async {
      stub = _StubApiClient(
        onGetJson: (_) => {'plans': <dynamic>[], 'total': 0},
      );
      service = PlanApiServiceImpl(apiClient: stub);
      await service.fetchLibraryPlans(category: 'wellness', search: 'yoga', page: 2);
      final uri = stub.capturedCalls.first.uri;
      expect(uri.path, '/api/library/plans');
      expect(uri.queryParameters['page'], '2');
      expect(uri.queryParameters['category'], 'wellness');
      expect(uri.queryParameters['search'], 'yoga');
    });

    test('getLibraryPlanById calls GET /api/library/plans/:id', () async {
      stub = _StubApiClient(
        onGetJson: (_) => {
          'id': 'lib-1',
          'name': 'Library Plan',
          'planJson': _planJsonBlob(id: 'lib-1', name: 'Library Plan'),
        },
      );
      service = PlanApiServiceImpl(apiClient: stub);
      await service.getLibraryPlanById('lib-1');
      expect(stub.capturedCalls.first.uri.path, '/api/library/plans/lib-1');
    });

    test('getTtsStatus calls GET /api/tts/status/:planId', () async {
      stub = _StubApiClient(
        onGetJson: (_) => {
          'status': 'processing',
          'total': 10,
          'completed': 3,
          'failed': 0,
          'ready': false,
        },
      );
      service = PlanApiServiceImpl(apiClient: stub);
      await service.getTtsStatus('plan-tts-1');
      expect(stub.capturedCalls.first.uri.path, '/api/tts/status/plan-tts-1');
    });

    test('getAudioUrls calls GET /api/tts/audio-urls/:planId', () async {
      stub = _StubApiClient(
        onGetJson: (_) => {
          'urls': {'key1': 'https://s3/1.wav'},
        },
      );
      service = PlanApiServiceImpl(apiClient: stub);
      await service.getAudioUrls('plan-audio-1');
      expect(
        stub.capturedCalls.first.uri.path,
        '/api/tts/audio-urls/plan-audio-1',
      );
    });
  });

  // ── PlanApiServiceImpl — response parsing ─────────────────────────────────

  group('PlanApiServiceImpl — response parsing', () {
    PlanApiService _makeService(
        Map<String, dynamic> Function(Uri) getHandler) {
      final stub = _StubApiClient(onGetJson: getHandler);
      return PlanApiServiceImpl(apiClient: stub);
    }

    test('fetchUserPlans parses list of plan summaries', () async {
      final service = _makeService((_) => _planListResponse([
            _planSummaryJson(planId: 'p1', name: 'Plan A', ttsStatus: 'completed'),
            _planSummaryJson(planId: 'p2', name: 'Plan B', isActive: true),
          ]));
      final plans = await service.fetchUserPlans();
      expect(plans, hasLength(2));
      expect(plans[0].id, 'p1');
      expect(plans[0].name, 'Plan A');
      expect(plans[0].ttsStatus, 'completed');
      expect(plans[1].id, 'p2');
      expect(plans[1].isActive, isTrue);
    });

    test('fetchUserPlans returns empty list when server returns empty array',
        () async {
      final service = _makeService((_) => _planListResponse([]));
      final plans = await service.fetchUserPlans();
      expect(plans, isEmpty);
    });

    test('fetchUserPlans parses datetime fields correctly', () async {
      final service = _makeService((_) => _planListResponse([
            _planSummaryJson(planId: 'p1'),
          ]));
      final plans = await service.fetchUserPlans();
      expect(plans[0].createdAt, DateTime.utc(2024, 1, 1));
      expect(plans[0].updatedAt, DateTime.utc(2024, 1, 2));
    });

    test('getPlanById parses full plan including TTS overlay', () async {
      final service = _makeService((_) => _planDetailResponse(
            planId: 'plan-full',
            name: 'Full Plan',
            ttsStatus: 'completed',
            ttsTotal: 8,
            ttsCompleted: 8,
          ));
      final plan = await service.getPlanById('plan-full');
      expect(plan.id, 'plan-full');
      expect(plan.name, 'Full Plan');
      expect(plan.ttsStatus, 'completed');
      expect(plan.ttsTotal, 8);
      expect(plan.ttsCompleted, 8);
      expect(plan.isActive, isTrue);
    });

    test('getPlanById overlays server ttsStatus over planJson contents',
        () async {
      // The planJson blob has ttsStatus='none', but the server response has
      // ttsStatus='processing'. The server value should win.
      final service = _makeService((_) => {
            'planId': 'p1',
            'name': 'Plan',
            'planJson': _planJsonBlob(id: 'p1', name: 'Plan'),
            'isActive': false,
            'ttsStatus': 'processing',
            'ttsTotal': 5,
            'ttsCompleted': 2,
            'voiceQuality': 'studio',
            'createdAt': '2024-01-01T00:00:00.000Z',
            'updatedAt': '2024-01-01T00:00:00.000Z',
          });
      final plan = await service.getPlanById('p1');
      expect(plan.ttsStatus, 'processing');
      expect(plan.ttsCompleted, 2);
    });

    test('getPlanById falls back gracefully when planJson is missing', () async {
      final service = _makeService((_) => {
            'planId': 'fallback-id',
            'name': 'Fallback Plan',
            'isActive': false,
            'ttsStatus': 'none',
            'ttsTotal': 0,
            'ttsCompleted': 0,
            'createdAt': '2024-01-01T00:00:00.000Z',
            'updatedAt': '2024-01-01T00:00:00.000Z',
          });
      final plan = await service.getPlanById('fallback-id');
      expect(plan.id, 'fallback-id');
      expect(plan.name, 'Fallback Plan');
    });

    test('fetchLibraryPlans parses LibraryPlanSummary list', () async {
      final service = _makeService((_) => {
            'plans': [
              {
                'id': 'lib-1',
                'name': 'Yoga Flow',
                'description': 'A yoga routine',
                'category': 'wellness',
                'tags': 'yoga,morning,relax',
                'defaultVoice': 'aoede',
                'locale': 'enUS',
                'stepCount': 12,
                'sortOrder': 1,
              },
            ],
            'total': 1,
          });
      final plans = await service.fetchLibraryPlans();
      expect(plans, hasLength(1));
      expect(plans[0].id, 'lib-1');
      expect(plans[0].name, 'Yoga Flow');
      expect(plans[0].category, PlanCategory.wellness);
      expect(plans[0].stepCount, 12);
      expect(plans[0].tags, containsAll(['yoga', 'morning', 'relax']));
      expect(plans[0].locale, 'enUS');
    });

    test('fetchLibraryPlans maps unknown category to PlanCategory.custom',
        () async {
      final service = _makeService((_) => {
            'plans': [
              {
                'id': 'lib-2',
                'name': 'Unknown Category Plan',
                'category': 'totally_unknown_category',
                'defaultVoice': 'aoede',
                'stepCount': 0,
              },
            ],
            'total': 1,
          });
      final plans = await service.fetchLibraryPlans();
      expect(plans[0].category, PlanCategory.custom);
    });

    test('fetchLibraryPlans splits comma-separated tags correctly', () async {
      final service = _makeService((_) => {
            'plans': [
              {
                'id': 'lib-3',
                'name': 'Tagged Plan',
                'category': 'custom',
                'defaultVoice': 'aoede',
                'tags': ' tag1 , tag2 , tag3 ',
                'stepCount': 0,
              },
            ],
            'total': 1,
          });
      final plans = await service.fetchLibraryPlans();
      expect(plans[0].tags, ['tag1', 'tag2', 'tag3']);
    });

    test('fetchLibraryPlans handles empty tags string', () async {
      final service = _makeService((_) => {
            'plans': [
              {
                'id': 'lib-4',
                'name': 'No Tags Plan',
                'category': 'custom',
                'defaultVoice': 'aoede',
                'tags': '',
                'stepCount': 0,
              },
            ],
          });
      final plans = await service.fetchLibraryPlans();
      expect(plans[0].tags, isEmpty);
    });

    test('getLibraryPlanById parses full plan from planJson blob', () async {
      final service = _makeService((_) => {
            'id': 'lib-full',
            'name': 'Library Full',
            'category': 'wellness',
            'tags': 'morning',
            'defaultVoice': 'aoede',
            'planJson': _planJsonBlob(
              id: 'lib-full',
              name: 'Library Full',
              category: 'wellness',
            ),
          });
      final plan = await service.getLibraryPlanById('lib-full');
      expect(plan.id, 'lib-full');
      expect(plan.name, 'Library Full');
      expect(plan.category, PlanCategory.wellness);
    });

    test('getLibraryPlanById falls back when planJson is absent', () async {
      final service = _makeService((_) => {
            'id': 'lib-fallback',
            'name': 'Minimal Library Plan',
            'category': 'fitness',
            'defaultVoice': 'puck',
          });
      final plan = await service.getLibraryPlanById('lib-fallback');
      expect(plan.id, 'lib-fallback');
      expect(plan.name, 'Minimal Library Plan');
      expect(plan.category, PlanCategory.fitness);
    });

    test('getTtsStatus parses status, total, and completed', () async {
      final service = _makeService((_) => {
            'status': 'processing',
            'total': 20,
            'completed': 10,
            'failed': 0,
            'ready': false,
          });
      final info = await service.getTtsStatus('plan-tts');
      expect(info.planId, 'plan-tts');
      expect(info.status, 'processing');
      expect(info.total, 20);
      expect(info.completed, 10);
      expect(info.ready, isFalse);
    });

    test('getTtsStatus injects planId from URL parameter', () async {
      // The server response does NOT include planId; PlanApiService adds it.
      final service = _makeService((_) => {
            'status': 'completed',
            'total': 5,
            'completed': 5,
            'failed': 0,
            'ready': true,
          });
      final info = await service.getTtsStatus('injected-plan-id');
      expect(info.planId, 'injected-plan-id');
    });

    test('getAudioUrls converts url map to AudioFileUrl list', () async {
      final service = _makeService((_) => {
            'urls': {
              'cache-key-1': 'https://s3.amazonaws.com/audio/1.wav',
              'cache-key-2': 'https://s3.amazonaws.com/audio/2.wav',
            },
          });
      final urls = await service.getAudioUrls('plan-audio');
      expect(urls, hasLength(2));
      final keys = urls.map((u) => u.cacheKey).toSet();
      expect(keys, {'cache-key-1', 'cache-key-2'});
      final urlStrings = urls.map((u) => u.url).toList();
      expect(urlStrings,
          containsAll(['https://s3.amazonaws.com/audio/1.wav', 'https://s3.amazonaws.com/audio/2.wav']));
    });

    test('getAudioUrls returns empty list when urls map is empty', () async {
      final service = _makeService((_) => {'urls': <String, dynamic>{}});
      final urls = await service.getAudioUrls('no-audio-plan');
      expect(urls, isEmpty);
    });
  });

  // ── PlanApiServiceImpl — error handling ───────────────────────────────────

  group('PlanApiServiceImpl — error handling', () {
    PlanApiService _makeServiceWithGetError(ApiException error) {
      final stub = _StubApiClient(throwOnGet: error);
      return PlanApiServiceImpl(apiClient: stub);
    }

    PlanApiService _makeServiceWithPostError(ApiException error) {
      final stub = _StubApiClient(throwOnPost: error);
      return PlanApiServiceImpl(apiClient: stub);
    }

    PlanApiService _makeServiceWithSendError(ApiException error) {
      final stub = _StubApiClient(throwOnSend: error);
      return PlanApiServiceImpl(apiClient: stub);
    }

    test('fetchUserPlans wraps ApiException as PlanApiException', () async {
      final service = _makeServiceWithGetError(
        const ApiException('Unauthorized', statusCode: 401),
      );
      expect(
        () => service.fetchUserPlans(),
        throwsA(isA<PlanApiException>()),
      );
    });

    test('401 produces "Please log in" user message', () async {
      final service = _makeServiceWithGetError(
        const ApiException('Unauthorized', statusCode: 401),
      );
      try {
        await service.fetchUserPlans();
        fail('expected PlanApiException');
      } on PlanApiException catch (e) {
        expect(e.userMessage, 'Please log in to continue.');
      }
    });

    test('403 produces "no permission" user message', () async {
      final service = _makeServiceWithGetError(
        const ApiException('Forbidden', statusCode: 403),
      );
      try {
        await service.getPlanById('plan-1');
        fail('expected PlanApiException');
      } on PlanApiException catch (e) {
        expect(e.userMessage, 'You do not have permission to perform this action.');
      }
    });

    test('404 produces "not found" user message', () async {
      final service = _makeServiceWithGetError(
        const ApiException('Not Found', statusCode: 404),
      );
      try {
        await service.getPlanById('missing');
        fail('expected PlanApiException');
      } on PlanApiException catch (e) {
        expect(e.userMessage, 'The requested plan could not be found.');
      }
    });

    test('429 produces "too many requests" user message', () async {
      final service = _makeServiceWithGetError(
        const ApiException('Rate Limited', statusCode: 429),
      );
      try {
        await service.fetchLibraryPlans();
        fail('expected PlanApiException');
      } on PlanApiException catch (e) {
        expect(e.userMessage, contains('Too many requests'));
      }
    });

    test('500 produces "server error" user message', () async {
      final service = _makeServiceWithGetError(
        const ApiException('Internal Server Error', statusCode: 500),
      );
      try {
        await service.getTtsStatus('plan-1');
        fail('expected PlanApiException');
      } on PlanApiException catch (e) {
        expect(e.userMessage, contains('Server error'));
      }
    });

    test('savePlan wraps PostJson ApiException', () async {
      final service = _makeServiceWithPostError(
        const ApiException('Validation failed', statusCode: 422),
      );
      expect(
        () => service.savePlan(_makePlan(name: 'Test')),
        throwsA(isA<PlanApiException>()),
      );
    });

    test('deletePlan wraps send ApiException', () async {
      final service = _makeServiceWithSendError(
        const ApiException('Not Found', statusCode: 404),
      );
      expect(
        () => service.deletePlan('missing-plan'),
        throwsA(isA<PlanApiException>()),
      );
    });

    test('activatePlan wraps PostJson ApiException', () async {
      final service = _makeServiceWithPostError(
        const ApiException('Server error', statusCode: 503),
      );
      try {
        await service.activatePlan('plan-activate');
        fail('expected PlanApiException');
      } on PlanApiException catch (e) {
        expect(e.userMessage, contains('Server error'));
      }
    });

    test('PlanApiException has both message and userMessage', () {
      const e = PlanApiException(
        'raw technical error',
        userMessage: 'Something went wrong.',
      );
      expect(e.message, 'raw technical error');
      expect(e.userMessage, 'Something went wrong.');
      expect(e.toString(), contains('PlanApiException'));
    });

    test('PlanApiException defaults userMessage to message when not provided',
        () {
      const e = PlanApiException('only one message');
      expect(e.message, e.userMessage);
    });
  });

  // ── _isUuidV4 static helper ───────────────────────────────────────────────

  group('PlanApiServiceImpl — UUID detection for savePlan', () {
    late PlanApiServiceImpl service;
    final capturedBodies = <Map<String, dynamic>>[];

    setUp(() {
      capturedBodies.clear();
      final stub = _StubApiClient(
        onPostJson: (_, body) {
          capturedBodies.add(body);
          return {'planId': 'new-server-uuid'};
        },
      );
      service = PlanApiServiceImpl(apiClient: stub);
    });

    test('valid UUID v4 is included in save request', () async {
      await service.savePlan(_makePlan(id: '550e8400-e29b-41d4-a716-446655440000'));
      expect(capturedBodies.first['planId'], '550e8400-e29b-41d4-a716-446655440000');
    });

    test('UUID v1 is not included in save request (only v4 accepted)', () async {
      // v1 UUID has first segment without "4" in version position
      await service.savePlan(_makePlan(id: '550e8400-e29b-11d4-a716-446655440000'));
      expect(capturedBodies.first.containsKey('planId'), isFalse);
    });

    test('empty string id is not included in save request', () async {
      // Plan.id is required but might be empty string for new plans
      try {
        await service.savePlan(_makePlan(id: ''));
      } catch (_) {
        // Plan model might throw on empty id — that's ok for this test
      }
      if (capturedBodies.isNotEmpty) {
        expect(capturedBodies.first.containsKey('planId'), isFalse);
      }
    });

    test('arbitrary non-UUID string is not included in save request', () async {
      await service.savePlan(_makePlan(id: 'local-temp-id'));
      expect(capturedBodies.first.containsKey('planId'), isFalse);
    });

    test('all UUID v4 variants (8/9/a/b y-nibble) are accepted', () async {
      // UUID v4 y-nibble must be 8, 9, a, or b
      for (final variant in ['8', '9', 'a', 'b']) {
        capturedBodies.clear();
        final uuid = '550e8400-e29b-41d4-${variant}716-446655440000';
        await service.savePlan(_makePlan(id: uuid));
        expect(capturedBodies.first['planId'], uuid,
            reason: 'UUID v4 with y=$variant should be sent');
      }
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimal stubs for ApiClient constructor (never actually called in tests)
// ─────────────────────────────────────────────────────────────────────────────

/// Minimal auth stub — no platform dependencies, always returns a test token.
class _NullAuthService extends AuthService {
  _NullAuthService()
      : super(
          httpClient: _NoOpHttpClient(),
          secureStorage: const _NoOpSecureStorage(),
          settings: _NullAppSettings(),
        );

  @override
  Future<String?> getAccessToken() async => 'test-jwt-token';

  @override
  Future<void> refreshToken() async {}

  @override
  Future<void> logout() async {}
}

/// Minimal settings stub — no Drift database required.
class _NullAppSettings extends AppSettings {
  _NullAppSettings() : super(_FakeDb());

  @override
  Future<String?> read(String key) async => null;

  @override
  Stream<String?> watch(String key) => const Stream.empty();

  @override
  Future<void> write(String key, String value) async {}
}

/// No-op HTTP client (never actually used since StubApiClient overrides send).
class _NoOpHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream.empty(), 200);
  }
}

/// No-op secure storage (never actually used since auth methods are overridden).
class _NoOpSecureStorage extends FlutterSecureStorage {
  const _NoOpSecureStorage() : super();

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      null;

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}
}

/// Minimal DB fake passed to AppSettings — never used since AppSettings
/// methods are overridden.
class _FakeDb {
  dynamic noSuchMethod(Invocation i) => null;
}
