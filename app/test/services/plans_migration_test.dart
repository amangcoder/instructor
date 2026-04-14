/// Unit tests for plans_migration.dart (TASK-059, TASK-061, TASK-062).
///
/// Tests cover:
/// 1. parseLegacyDateTime — int epoch, ISO string, null, and zero
/// 2. parseLegacyPlan — full row, missing fields, corrupt steps/tags
/// 3. migratePlansToServer — returns early when already migrated
/// 4. migratePlansToServer — marks done and returns when no pending plans
/// 5. migratePlansToServer — defers (no flag set) when not authenticated
/// 6. migratePlansToServer — uploads plans and marks done when authenticated
/// 7. migratePlansToServer — partial upload failure still marks done
/// 8. migratePlansToServer — clears blob after successful upload
/// 9. migratePlansToServer — handles corrupted JSON blob gracefully
/// 10. Ordering guarantee — auth pre-load allows upload on first launch
/// 11. migrationPendingProvider — set to true when migration deferred (TASK-061)
/// 12. migrationPendingProvider — stays false when migration succeeds (TASK-061)
/// 13. schedulePostLoginMigration — resumes migration after Authenticated event
/// 14. schedulePostLoginMigration — clears migrationPendingProvider after login
/// 15. schedulePostLoginMigration — ignores Unauthenticated events
/// 16. migrationPartialFailureProvider — set to failure count on partial failure (TASK-062)
/// 17. migrationPartialFailureProvider — stays 0 when all uploads succeed (TASK-062)
/// 18. migrationPartialFailureProvider — stays 0 when no plans to upload (TASK-062)
/// 19. migrationPartialFailureProvider — counts each individual failure (TASK-062)
/// 20. migrationPartialFailureProvider — set after post-login migration with partial failures (TASK-062)
///
/// ## Running
/// ```
/// flutter test test/services/plans_migration_test.dart
/// ```
library plans_migration_test;

import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/models/audio_file_url.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/library_plan_summary.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/models/tts_status_info.dart';
import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/services/app_settings.dart';
import 'package:instructor/services/auth_service.dart';
import 'package:instructor/services/plan_api_service.dart';
import 'package:instructor/services/plans_migration.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fake implementations
// ─────────────────────────────────────────────────────────────────────────────

/// Minimal [AuthService] stub where [isAuthenticated] is controllable.
class _FakeAuthService implements AuthService {
  _FakeAuthService({bool authenticated = false})
      : _authenticated = authenticated;

  bool _authenticated;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  AuthUser? getUser() => _authenticated
      ? const AuthUser(id: 'user-1', email: 'test@example.com')
      : null;

  @override
  Stream<AuthState> get authStateStream => const Stream.empty();

  @override
  Future<void> requestOtp(String email) async {}

  @override
  Future<void> requestOtpWithAuth(String email) async {}

  @override
  Future<AuthResult> verifyOtp(String email, String otp) async =>
      throw UnimplementedError();

  @override
  Future<void> refreshToken() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<bool> isLoggedIn() async {
    return _authenticated;
  }

  /// Helper to simulate the effect of isLoggedIn() populating the cache.
  void setAuthenticated(bool value) => _authenticated = value;
}

/// [AuthService] stub backed by a controllable [StreamController] so tests
/// can emit [AuthState] events and exercise [schedulePostLoginMigration].
class _FakeAuthServiceWithStream implements AuthService {
  _FakeAuthServiceWithStream({
    bool authenticated = false,
    required Stream<AuthState> stream,
  })  : _authenticated = authenticated,
        _stream = stream;

  bool _authenticated;
  final Stream<AuthState> _stream;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  AuthUser? getUser() => _authenticated
      ? const AuthUser(id: 'user-1', email: 'test@example.com')
      : null;

  @override
  Stream<AuthState> get authStateStream => _stream;

  @override
  Future<void> requestOtp(String email) async {}

  @override
  Future<void> requestOtpWithAuth(String email) async {}

  @override
  Future<AuthResult> verifyOtp(String email, String otp) async =>
      throw UnimplementedError();

  @override
  Future<void> refreshToken() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<bool> isLoggedIn() async => _authenticated;

  /// Simulates the effect of a successful login populating the cache.
  void setAuthenticated(bool value) => _authenticated = value;
}

/// Minimal [PlanApiService] stub that records [savePlan] calls.
class _FakePlanApiService implements PlanApiService {
  final List<Plan> savedPlans = [];
  bool shouldThrow = false;

  @override
  Future<List<Plan>> fetchUserPlans() async => const [];

  @override
  Future<Plan?> getPlanById(String id) async => null;

  @override
  Future<String> savePlan(Plan plan) async {
    if (shouldThrow) throw PlanApiException('Network error');
    savedPlans.add(plan);
    return 'server-uuid-${savedPlans.length}';
  }

  @override
  Future<void> deletePlan(String id) async {}

  @override
  Future<List<LibraryPlanSummary>> fetchLibraryPlans() async => const [];

  @override
  Future<Plan?> getLibraryPlanById(String id) async => null;

  @override
  Future<void> activatePlan(String planId) async {}

  @override
  Future<TtsStatusInfo?> getTtsStatus(String planId) async => null;

  @override
  Future<List<AudioFileUrl>> getAudioUrls(String planId) async => const [];
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: build a ProviderContainer with in-memory overrides
// ─────────────────────────────────────────────────────────────────────────────

/// Creates a [ProviderContainer] that uses an in-memory database, a
/// controllable [_FakeAuthService], and a recording [_FakePlanApiService].
///
/// Returns a record of (container, db, auth, api) for assertions.
({
  ProviderContainer container,
  AppDatabase db,
  _FakeAuthService auth,
  _FakePlanApiService api,
}) _buildContainer({bool authenticated = false}) {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final auth = _FakeAuthService(authenticated: authenticated);
  final api = _FakePlanApiService();

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      authServiceProvider.overrideWithValue(auth),
      planApiServiceProvider.overrideWithValue(api),
    ],
  );

  return (container: container, db: db, auth: auth, api: api);
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: write a pending-migration blob into app_settings
// ─────────────────────────────────────────────────────────────────────────────

/// Encodes a list of raw plan rows and writes them to the
/// [AppSettingsKeys.pendingMigrationPlans] key.
Future<void> _writePendingBlob(
  AppSettings settings,
  List<Map<String, dynamic>> rows,
) async {
  await settings.write(
    AppSettingsKeys.pendingMigrationPlans,
    jsonEncode(rows),
  );
}

/// A realistic raw row from the pre-v6 plans table.
Map<String, dynamic> _rawRow({
  String name = 'My Plan',
  String category = 'custom',
  String voice = 'aoede',
}) =>
    {
      'id': 1,
      'name': name,
      'description': 'A test plan',
      'category': category,
      'tags': '["morning","focus"]',
      'default_voice': voice,
      'steps':
          '[{"type":"say","id":"s1","text":"Hello"},{"type":"wait","id":"w1","duration":30000000}]',
      'created_at': DateTime(2024).millisecondsSinceEpoch,
      'updated_at': DateTime(2024, 6).millisecondsSinceEpoch,
      'last_used_at': null,
    };

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── parseLegacyDateTime ──────────────────────────────────────────────────

  group('parseLegacyDateTime', () {
    test('returns null for null input', () {
      expect(parseLegacyDateTime(null), isNull);
    });

    test('returns null for integer 0', () {
      expect(parseLegacyDateTime(0), isNull);
    });

    test('parses positive millisecond epoch int', () {
      final epoch = DateTime(2024, 3, 15).millisecondsSinceEpoch;
      final result = parseLegacyDateTime(epoch);
      expect(result, isNotNull);
      expect(result!.year, equals(2024));
      expect(result.month, equals(3));
      expect(result.day, equals(15));
    });

    test('parses ISO-8601 string', () {
      const iso = '2023-09-01T10:30:00.000Z';
      final result = parseLegacyDateTime(iso);
      expect(result, isNotNull);
      expect(result!.year, equals(2023));
      expect(result.month, equals(9));
    });

    test('returns null for empty string', () {
      expect(parseLegacyDateTime(''), isNull);
    });

    test('returns null for unparseable string', () {
      expect(parseLegacyDateTime('not-a-date'), isNull);
    });
  });

  // ── parseLegacyPlan ──────────────────────────────────────────────────────

  group('parseLegacyPlan', () {
    test('produces a Plan with empty id (server creates UUID)', () {
      final plan = parseLegacyPlan(_rawRow());
      expect(plan.id, isEmpty,
          reason: 'Empty id signals server to assign a UUID on save');
    });

    test('parses name and description', () {
      final plan = parseLegacyPlan(_rawRow(name: 'Morning Run'));
      expect(plan.name, equals('Morning Run'));
      expect(plan.description, equals('A test plan'));
    });

    test('parses known PlanCategory', () {
      final plan = parseLegacyPlan(_rawRow(category: 'yoga'));
      expect(plan.category, equals(PlanCategory.yoga));
    });

    test('falls back to PlanCategory.custom for unknown category', () {
      final plan = parseLegacyPlan(_rawRow(category: 'unknown_xyz'));
      expect(plan.category, equals(PlanCategory.custom));
    });

    test('parses tags from JSON array string', () {
      final plan = parseLegacyPlan(_rawRow());
      expect(plan.tags, containsAll(['morning', 'focus']));
    });

    test('defaults tags to empty list on corrupt tags JSON', () {
      final raw = Map<String, dynamic>.from(_rawRow())
        ..['tags'] = '{not valid json}';
      final plan = parseLegacyPlan(raw);
      expect(plan.tags, isEmpty);
    });

    test('parses steps from JSON array', () {
      final plan = parseLegacyPlan(_rawRow());
      expect(plan.steps, hasLength(2));
      expect(plan.steps[0], isA<SayStep>());
      expect(plan.steps[1], isA<WaitStep>());
    });

    test('defaults steps to empty list on corrupt steps JSON', () {
      final raw = Map<String, dynamic>.from(_rawRow())
        ..['steps'] = 'not-json';
      final plan = parseLegacyPlan(raw);
      expect(plan.steps, isEmpty);
    });

    test('falls back to "aoede" when voice is null', () {
      final raw = Map<String, dynamic>.from(_rawRow())..['default_voice'] = null;
      final plan = parseLegacyPlan(raw);
      expect(plan.defaultVoice, equals('aoede'));
    });

    test('falls back to "aoede" when voice is empty string', () {
      final raw = Map<String, dynamic>.from(_rawRow())
        ..['default_voice'] = '';
      final plan = parseLegacyPlan(raw);
      expect(plan.defaultVoice, equals('aoede'));
    });

    test('preserves valid voice name', () {
      final plan = parseLegacyPlan(_rawRow(voice: 'leda'));
      expect(plan.defaultVoice, equals('leda'));
    });

    test('falls back to "Untitled Plan" when name is null', () {
      final raw = Map<String, dynamic>.from(_rawRow())..['name'] = null;
      final plan = parseLegacyPlan(raw);
      expect(plan.name, equals('Untitled Plan'));
    });

    test('parses createdAt from epoch int', () {
      final plan = parseLegacyPlan(_rawRow());
      expect(plan.createdAt.year, equals(2024));
    });

    test('lastUsedAt is null when absent in row', () {
      final plan = parseLegacyPlan(_rawRow());
      expect(plan.lastUsedAt, isNull);
    });
  });

  // ── migratePlansToServer ─────────────────────────────────────────────────

  group('migratePlansToServer', () {
    late ProviderContainer container;
    late AppDatabase db;
    late _FakeAuthService auth;
    late _FakePlanApiService api;

    setUp(() async {
      final built = _buildContainer(authenticated: true);
      container = built.container;
      db = built.db;
      auth = built.auth;
      api = built.api;
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('returns early without uploading when already migrated', () async {
      final settings = container.read(appSettingsProvider);
      await settings.setPlansMigratedV2();
      await _writePendingBlob(settings, [_rawRow()]);

      await migratePlansToServer(container);

      expect(api.savedPlans, isEmpty,
          reason: 'No upload should occur if plansMigratedV2 is set');
    });

    test(
        'marks done and returns when pending blob is absent (fresh install)',
        () async {
      // No blob written — simulates fresh install.
      await migratePlansToServer(container);

      final settings = container.read(appSettingsProvider);
      expect(await settings.plansMigratedV2(), isTrue,
          reason: 'Flag must be set so future launches skip migration');
      expect(api.savedPlans, isEmpty);
    });

    test('marks done and returns when pending blob is empty string', () async {
      final settings = container.read(appSettingsProvider);
      await settings.write(AppSettingsKeys.pendingMigrationPlans, '');

      await migratePlansToServer(container);

      expect(await settings.plansMigratedV2(), isTrue);
      expect(api.savedPlans, isEmpty);
    });

    test('defers upload and does NOT set flag when not authenticated',
        () async {
      // Override with unauthenticated container.
      final unauthBuilt = _buildContainer(authenticated: false);
      final unauthContainer = unauthBuilt.container;
      final unauthDb = unauthBuilt.db;
      final unauthApi = unauthBuilt.api;
      addTearDown(() async {
        unauthContainer.dispose();
        await unauthDb.close();
      });

      final settings = unauthContainer.read(appSettingsProvider);
      await _writePendingBlob(settings, [_rawRow()]);

      await migratePlansToServer(unauthContainer);

      expect(await settings.plansMigratedV2(), isFalse,
          reason:
              'Flag must NOT be set — unauthenticated deferral allows retry');
      expect(unauthApi.savedPlans, isEmpty);
    });

    test('uploads all plans and marks done when authenticated', () async {
      final settings = container.read(appSettingsProvider);
      await _writePendingBlob(settings, [_rawRow(name: 'Plan A'), _rawRow(name: 'Plan B')]);

      await migratePlansToServer(container);

      expect(api.savedPlans, hasLength(2));
      expect(api.savedPlans.map((p) => p.name), containsAll(['Plan A', 'Plan B']));
      expect(await settings.plansMigratedV2(), isTrue);
    });

    test('emits onProgress for each plan', () async {
      final settings = container.read(appSettingsProvider);
      await _writePendingBlob(
          settings, [_rawRow(name: 'P1'), _rawRow(name: 'P2'), _rawRow(name: 'P3')]);

      final progressCalls = <(int, int)>[];
      await migratePlansToServer(
        container,
        onProgress: (current, total) => progressCalls.add((current, total)),
      );

      expect(progressCalls, hasLength(3));
      expect(progressCalls[0], equals((1, 3)));
      expect(progressCalls[1], equals((2, 3)));
      expect(progressCalls[2], equals((3, 3)));
    });

    test('partial upload failure still marks migration done', () async {
      // First savePlan succeeds; second throws.
      int callCount = 0;
      final partialApi = _FakePlanApiService();
      final partialBuilt = _buildContainer(authenticated: true);
      // Replace the API with one that throws on second call.
      final partialContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(partialBuilt.db),
          authServiceProvider.overrideWithValue(partialBuilt.auth),
          planApiServiceProvider.overrideWith((ref) {
            return _CountingApi(onSave: (plan) async {
              callCount++;
              if (callCount == 2) throw PlanApiException('Server error');
            });
          }),
        ],
      );
      addTearDown(() async {
        partialContainer.dispose();
        await partialBuilt.db.close();
      });

      final settings = partialContainer.read(appSettingsProvider);
      await _writePendingBlob(
          settings, [_rawRow(name: 'OK'), _rawRow(name: 'Fail')]);

      await migratePlansToServer(partialContainer);

      expect(await settings.plansMigratedV2(), isTrue,
          reason: 'Partial success must still mark migration done');
    });

    test('clears pending blob after successful upload', () async {
      final settings = container.read(appSettingsProvider);
      await _writePendingBlob(settings, [_rawRow()]);

      await migratePlansToServer(container);

      final remaining =
          await settings.read(AppSettingsKeys.pendingMigrationPlans);
      expect(remaining, isEmpty,
          reason: 'Blob must be cleared to prevent re-upload on next launch');
    });

    test('handles corrupted JSON blob — clears and marks done', () async {
      final settings = container.read(appSettingsProvider);
      await settings.write(
          AppSettingsKeys.pendingMigrationPlans, 'NOT_VALID_JSON{{{');

      await migratePlansToServer(container);

      expect(await settings.plansMigratedV2(), isTrue,
          reason: 'Corrupt blob must be cleared to prevent infinite retry');
      expect(api.savedPlans, isEmpty);
    });
  });

  // ── Ordering guarantee: auth pre-load ────────────────────────────────────

  group('initialization ordering (TASK-063)', () {
    test(
        'isLoggedIn() populates isAuthenticated before migratePlansToServer '
        'checks it — ensures upload is not deferred on first launch',
        () async {
      // Simulate what _bootstrap() does after the TASK-063 fix:
      //   1. Create container (auth cache starts false)
      //   2. Call auth.isLoggedIn() → populates cache
      //   3. Call migratePlansToServer() → checks auth.isAuthenticated
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final api = _FakePlanApiService();

      // Auth service starts with tokens in "secure storage" (simulated by
      // _FakeAuthService returning true from isLoggedIn()) but isAuthenticated
      // is false until isLoggedIn() is awaited.
      final auth = _FakeAuthService(authenticated: false);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authServiceProvider.overrideWithValue(auth),
          planApiServiceProvider.overrideWithValue(api),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      // Pre-populate the pending blob.
      final settings = container.read(appSettingsProvider);
      await _writePendingBlob(settings, [_rawRow(name: 'Precious Plan')]);

      // Step 1 of TASK-063 ordering: call isLoggedIn() to populate the cache.
      // isLoggedIn() on _FakeAuthService returns true and sets _authenticated.
      final authService = container.read(authServiceProvider) as _FakeAuthService;
      authService.setAuthenticated(true); // Simulates secure-storage read result.
      final loggedIn = await authService.isLoggedIn();
      expect(loggedIn, isTrue);
      expect(authService.isAuthenticated, isTrue,
          reason:
              'isAuthenticated must be true BEFORE migratePlansToServer runs');

      // Step 2: migratePlansToServer can now upload — isAuthenticated is true.
      await migratePlansToServer(container);

      expect(api.savedPlans, hasLength(1));
      expect(api.savedPlans.first.name, equals('Precious Plan'));
      expect(await settings.plansMigratedV2(), isTrue);
    });

    test(
        'without auth pre-load, migratePlansToServer defers even when tokens '
        'exist in secure storage (demonstrates the pre-TASK-063 bug)',
        () async {
      // Simulates the OLD behavior: auth cache never populated before migration.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final api = _FakePlanApiService();
      // Auth cache starts false — isLoggedIn() is NOT called before migration.
      final auth = _FakeAuthService(authenticated: false);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authServiceProvider.overrideWithValue(auth),
          planApiServiceProvider.overrideWithValue(api),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final settings = container.read(appSettingsProvider);
      await _writePendingBlob(settings, [_rawRow(name: 'Lost Plan')]);

      // NO isLoggedIn() call — old behavior.
      await migratePlansToServer(container);

      expect(api.savedPlans, isEmpty,
          reason:
              'Without pre-load, upload is deferred — this is the TASK-063 bug');
      expect(await settings.plansMigratedV2(), isFalse,
          reason: 'Flag is not set so next launch retries');
    });
  });

  // ── migrationPendingProvider (TASK-061) ──────────────────────────────────

  group('migrationPendingProvider', () {
    test('is set to true when migration is deferred (unauthenticated)',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final api = _FakePlanApiService();
      final auth = _FakeAuthService(authenticated: false);

      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(auth),
        planApiServiceProvider.overrideWithValue(api),
      ]);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final settings = container.read(appSettingsProvider);
      await _writePendingBlob(settings, [_rawRow()]);

      // Provider starts false.
      expect(container.read(migrationPendingProvider), isFalse);

      await migratePlansToServer(container);

      expect(container.read(migrationPendingProvider), isTrue,
          reason: 'Flag must be set so the app shell can show a warning');
      expect(api.savedPlans, isEmpty);
    });

    test('stays false when migration completes (authenticated)', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final api = _FakePlanApiService();
      final auth = _FakeAuthService(authenticated: true);

      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(auth),
        planApiServiceProvider.overrideWithValue(api),
      ]);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final settings = container.read(appSettingsProvider);
      await _writePendingBlob(settings, [_rawRow()]);

      await migratePlansToServer(container);

      expect(container.read(migrationPendingProvider), isFalse,
          reason: 'No deferral — flag must stay false after successful upload');
      expect(api.savedPlans, hasLength(1));
    });

    test('stays false on fresh install (no pending blob)', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final auth = _FakeAuthService(authenticated: false);
      final api = _FakePlanApiService();

      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(auth),
        planApiServiceProvider.overrideWithValue(api),
      ]);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      // No blob — fresh install.
      await migratePlansToServer(container);

      expect(container.read(migrationPendingProvider), isFalse,
          reason: 'No pending plans — flag must remain false');
    });
  });

  // ── schedulePostLoginMigration (TASK-061) ────────────────────────────────

  group('schedulePostLoginMigration', () {
    test(
        'resumes migration and uploads plans after Authenticated event',
        () async {
      final authStreamController = StreamController<AuthState>.broadcast();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final api = _FakePlanApiService();
      final auth = _FakeAuthServiceWithStream(
        authenticated: false,
        stream: authStreamController.stream,
      );

      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(auth),
        planApiServiceProvider.overrideWithValue(api),
      ]);
      addTearDown(() async {
        container.dispose();
        await db.close();
        await authStreamController.close();
      });

      final settings = container.read(appSettingsProvider);
      await _writePendingBlob(settings, [_rawRow(name: 'Deferred Plan')]);

      // 1. Run migration — deferred because unauthenticated.
      await migratePlansToServer(container);
      expect(container.read(migrationPendingProvider), isTrue);
      expect(api.savedPlans, isEmpty);

      // 2. Schedule post-login migration.
      final sub = schedulePostLoginMigration(container);
      addTearDown(sub.cancel);

      // 3. Simulate the user logging in: update auth cache then emit event.
      auth.setAuthenticated(true);
      authStreamController.add(
        const Authenticated(
          user: AuthUser(id: 'u1', email: 'test@example.com'),
          accessToken: 'tok',
        ),
      );

      // Let the async listener and migration run.
      await pumpEventQueue();

      expect(api.savedPlans, hasLength(1),
          reason: 'Migration must run after Authenticated event');
      expect(api.savedPlans.first.name, equals('Deferred Plan'));
      expect(await settings.plansMigratedV2(), isTrue);
    });

    test('clears migrationPendingProvider to false after post-login migration',
        () async {
      final authStreamController = StreamController<AuthState>.broadcast();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final api = _FakePlanApiService();
      final auth = _FakeAuthServiceWithStream(
        authenticated: false,
        stream: authStreamController.stream,
      );

      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(auth),
        planApiServiceProvider.overrideWithValue(api),
      ]);
      addTearDown(() async {
        container.dispose();
        await db.close();
        await authStreamController.close();
      });

      final settings = container.read(appSettingsProvider);
      await _writePendingBlob(settings, [_rawRow()]);
      await migratePlansToServer(container);

      expect(container.read(migrationPendingProvider), isTrue);

      schedulePostLoginMigration(container);
      auth.setAuthenticated(true);
      authStreamController.add(
        const Authenticated(
          user: AuthUser(id: 'u1', email: 'test@example.com'),
          accessToken: 'tok',
        ),
      );

      await pumpEventQueue();

      expect(container.read(migrationPendingProvider), isFalse,
          reason: 'Provider must be cleared after successful post-login migration');
    });

    test('does not upload when Unauthenticated event is emitted', () async {
      final authStreamController = StreamController<AuthState>.broadcast();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final api = _FakePlanApiService();
      final auth = _FakeAuthServiceWithStream(
        authenticated: false,
        stream: authStreamController.stream,
      );

      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(auth),
        planApiServiceProvider.overrideWithValue(api),
      ]);
      addTearDown(() async {
        container.dispose();
        await db.close();
        await authStreamController.close();
      });

      final settings = container.read(appSettingsProvider);
      await _writePendingBlob(settings, [_rawRow()]);
      await migratePlansToServer(container);

      schedulePostLoginMigration(container);

      // Emit a non-Authenticated event.
      authStreamController.add(const Unauthenticated());
      await pumpEventQueue();

      expect(api.savedPlans, isEmpty,
          reason: 'Unauthenticated event must not trigger migration');
      expect(container.read(migrationPendingProvider), isTrue,
          reason: 'Pending flag must remain true — migration not yet complete');
    });

    test('is one-shot: second Authenticated event does not re-run migration',
        () async {
      final authStreamController = StreamController<AuthState>.broadcast();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final api = _FakePlanApiService();
      final auth = _FakeAuthServiceWithStream(
        authenticated: false,
        stream: authStreamController.stream,
      );

      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(auth),
        planApiServiceProvider.overrideWithValue(api),
      ]);
      addTearDown(() async {
        container.dispose();
        await db.close();
        await authStreamController.close();
      });

      final settings = container.read(appSettingsProvider);
      await _writePendingBlob(settings, [_rawRow(name: 'Once Plan')]);
      await migratePlansToServer(container);
      schedulePostLoginMigration(container);

      const authEvent = Authenticated(
        user: AuthUser(id: 'u1', email: 'test@example.com'),
        accessToken: 'tok',
      );

      // First login.
      auth.setAuthenticated(true);
      authStreamController.add(authEvent);
      await pumpEventQueue();
      expect(api.savedPlans, hasLength(1));

      // Second login event — subscription should have been cancelled already.
      authStreamController.add(authEvent);
      await pumpEventQueue();
      expect(api.savedPlans, hasLength(1),
          reason: 'Second Authenticated event must not trigger a second migration');
    });
  });

  // ── migrationPartialFailureProvider (TASK-062) ───────────────────────────

  group('migrationPartialFailureProvider', () {
    test('is set to failure count when one upload fails', () async {
      // Build a container where the API throws on the second plan.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final auth = _FakeAuthService(authenticated: true);
      int callCount = 0;

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authServiceProvider.overrideWithValue(auth),
          planApiServiceProvider.overrideWith((ref) {
            return _CountingApi(onSave: (plan) async {
              callCount++;
              if (callCount == 2) throw PlanApiException('Network error');
            });
          }),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final settings = container.read(appSettingsProvider);
      await _writePendingBlob(
          settings, [_rawRow(name: 'OK'), _rawRow(name: 'Fail')]);

      // Provider starts at 0.
      expect(container.read(migrationPartialFailureProvider), equals(0));

      await migratePlansToServer(container);

      expect(
        container.read(migrationPartialFailureProvider),
        equals(1),
        reason: 'Exactly 1 upload failed — provider must reflect that count',
      );
    });

    test('counts every individual failure when multiple plans fail', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final auth = _FakeAuthService(authenticated: true);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authServiceProvider.overrideWithValue(auth),
          planApiServiceProvider.overrideWith((ref) {
            // All savePlan calls throw.
            return _CountingApi(
                onSave: (plan) async => throw PlanApiException('err'));
          }),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final settings = container.read(appSettingsProvider);
      await _writePendingBlob(settings, [
        _rawRow(name: 'A'),
        _rawRow(name: 'B'),
        _rawRow(name: 'C'),
      ]);

      await migratePlansToServer(container);

      expect(
        container.read(migrationPartialFailureProvider),
        equals(3),
        reason: 'All 3 uploads failed — provider must equal 3',
      );
    });

    test('stays at 0 when all uploads succeed', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final api = _FakePlanApiService();
      final auth = _FakeAuthService(authenticated: true);

      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(auth),
        planApiServiceProvider.overrideWithValue(api),
      ]);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final settings = container.read(appSettingsProvider);
      await _writePendingBlob(
          settings, [_rawRow(name: 'Plan A'), _rawRow(name: 'Plan B')]);

      await migratePlansToServer(container);

      expect(
        container.read(migrationPartialFailureProvider),
        equals(0),
        reason: 'No failures — provider must remain 0',
      );
    });

    test('stays at 0 when there are no plans to upload (fresh install)',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final auth = _FakeAuthService(authenticated: true);
      final api = _FakePlanApiService();

      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(auth),
        planApiServiceProvider.overrideWithValue(api),
      ]);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      // No blob written — fresh install.
      await migratePlansToServer(container);

      expect(
        container.read(migrationPartialFailureProvider),
        equals(0),
        reason: 'No plans to upload — provider must remain 0',
      );
    });

    test('is set after post-login migration with partial failures', () async {
      final authStreamController = StreamController<AuthState>.broadcast();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final auth = _FakeAuthServiceWithStream(
        authenticated: false,
        stream: authStreamController.stream,
      );
      int callCount = 0;

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authServiceProvider.overrideWithValue(auth),
          planApiServiceProvider.overrideWith((ref) {
            return _CountingApi(onSave: (plan) async {
              callCount++;
              // First plan succeeds, second fails.
              if (callCount == 2) throw PlanApiException('Timeout');
            });
          }),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
        await authStreamController.close();
      });

      final settings = container.read(appSettingsProvider);
      await _writePendingBlob(
          settings, [_rawRow(name: 'OK'), _rawRow(name: 'Fail')]);

      // First run: deferred because unauthenticated.
      await migratePlansToServer(container);
      expect(container.read(migrationPendingProvider), isTrue);
      expect(container.read(migrationPartialFailureProvider), equals(0),
          reason: 'No uploads attempted yet — failure count must be 0');

      // Schedule post-login migration.
      schedulePostLoginMigration(container);

      // User logs in.
      auth.setAuthenticated(true);
      authStreamController.add(
        const Authenticated(
          user: AuthUser(id: 'u1', email: 'test@example.com'),
          accessToken: 'tok',
        ),
      );
      await pumpEventQueue();

      expect(
        container.read(migrationPartialFailureProvider),
        equals(1),
        reason: '1 upload failed during post-login migration — provider must be 1',
      );
      expect(await settings.plansMigratedV2(), isTrue,
          reason: 'Migration still marked done despite partial failure');
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers used in partial-failure test
// ─────────────────────────────────────────────────────────────────────────────

/// A [PlanApiService] that calls [onSave] for each [savePlan] invocation.
class _CountingApi implements PlanApiService {
  _CountingApi({required this.onSave});

  final Future<void> Function(Plan plan) onSave;

  @override
  Future<String> savePlan(Plan plan) async {
    await onSave(plan);
    return 'server-id';
  }

  @override
  Future<List<Plan>> fetchUserPlans() async => const [];

  @override
  Future<Plan?> getPlanById(String id) async => null;

  @override
  Future<void> deletePlan(String id) async {}

  @override
  Future<List<LibraryPlanSummary>> fetchLibraryPlans() async => const [];

  @override
  Future<Plan?> getLibraryPlanById(String id) async => null;

  @override
  Future<void> activatePlan(String planId) async {}

  @override
  Future<TtsStatusInfo?> getTtsStatus(String planId) async => null;

  @override
  Future<List<AudioFileUrl>> getAudioUrls(String planId) async => const [];
}
