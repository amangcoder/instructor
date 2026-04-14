/// Widget tests for SettingsScreen — auth status and settings controls.
///
/// Tests cover:
/// 1. Auth status display (logged-in email / Login button)
/// 2. Logout button calls AuthService.logout
/// 3. Responsive layout rendering
///
/// ## Running
/// ```
/// flutter test test/screens/settings/settings_screen_test.dart
/// ```
library settings_screen_test;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/providers/settings_providers.dart';
import 'package:instructor/providers/tts_providers.dart';
import 'package:instructor/repositories/plan_repository.dart';
import 'package:instructor/screens/settings/settings_screen.dart';
import 'package:instructor/services/auth_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeAuthService implements AuthService {
  final bool _isAuthenticated;
  final String? _email;
  int logoutCount = 0;

  _FakeAuthService({bool authenticated = true, String? email = 'user@example.com'})
      : _isAuthenticated = authenticated,
        _email = email;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  AuthUser? getUser() =>
      _isAuthenticated && _email != null ? AuthUser(id: 'u1', email: _email!) : null;

  @override
  Stream<AuthState> get authStateStream => Stream.value(
        _isAuthenticated
            ? AuthenticatedState(user: getUser()!, accessToken: 'fake-access-token')
            : const UnauthenticatedState(),
      );

  @override
  Future<String?> getAccessToken() async =>
      _isAuthenticated ? 'fake-access-token' : null;

  @override
  Future<void> requestOtp(String email) async {}

  @override
  Future<AuthResult> verifyOtp(String email, String otp) async => throw UnimplementedError();

  @override
  Future<void> refreshToken() async {}

  @override
  Future<void> logout() async {
    logoutCount++;
  }

  @override
  Future<void> requestOtpWithAuth(String email) => requestOtp(email);
}

// ---------------------------------------------------------------------------
// Fake PlanRepository — returns empty streams, no database required.
// ---------------------------------------------------------------------------

class _FakePlanRepository implements PlanRepository {
  @override
  Stream<List<Plan>> watchUserPlans({
    String? searchQuery,
    PlanCategory? category,
  }) =>
      Stream.value(const []);

  @override
  Future<String> createPlan(Plan plan) async => plan.id;

  @override
  Future<void> updatePlan(String id, Plan plan) async {}

  @override
  Future<void> deletePlan(String id) async {}

  @override
  Future<Plan?> getPlanById(String id) async => null;

  @override
  Future<void> activatePlan(String id, {required String voice, required String locale, required String speechRate}) async {}

  @override
  Future<void> updateLastUsed(String id) async {}

  @override
  Future<int> remapPlanVoices(Map<String, String> voiceMap) async => 0;

  @override
  Future<void> refreshFromServer() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds the full set of [Override]s required by [SettingsScreen].
///
/// Overrides auth, all SQLite-backed settings stream providers, the TTS voice
/// providers, and the plan repository so no real database is needed in tests.
List<Override> _buildOverrides(_FakeAuthService auth) {
  return [
    authServiceProvider.overrideWithValue(auth),
    // Plan repository — no database
    planRepositoryProvider.overrideWithValue(_FakePlanRepository()),
    // Settings stream providers — emit safe defaults
    themeModeSettingProvider.overrideWith((ref) => Stream.value(ThemeMode.system)),
    speechRateSettingProvider.overrideWith((ref) => Stream.value(1.0)),
    ambientVolumeSettingProvider.overrideWith((ref) => Stream.value(0.7)),
    voiceVolumeSettingProvider.overrideWith((ref) => Stream.value(1.0)),
    notificationSoundSettingProvider.overrideWith((ref) => Stream.value(true)),
    vibrationSettingProvider.overrideWith((ref) => Stream.value(true)),
    activityLevelSettingProvider.overrideWith((ref) => Stream.value('')),
    profileGoalsSettingProvider.overrideWith((ref) => Stream.value(const [])),
    // TTS providers
    rawVoiceSettingProvider.overrideWith((ref) => Stream.value('af_heart')),
    availableVoicesProvider.overrideWith((ref) async => const []),
  ];
}

Widget _wrap(
  Widget widget, {
  bool authenticated = true,
  String? userEmail = 'user@example.com',
}) {
  final fakeAuth = _FakeAuthService(authenticated: authenticated, email: userEmail);

  return ProviderScope(
    overrides: _buildOverrides(fakeAuth),
    child: MaterialApp(home: widget),
  );
}

Widget _wrapWithRouter({
  bool authenticated = true,
  String? userEmail = 'user@example.com',
}) {
  final fakeAuth = _FakeAuthService(authenticated: authenticated, email: userEmail);

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Login Screen'))),
    ],
  );

  return ProviderScope(
    overrides: _buildOverrides(fakeAuth),
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SettingsScreen — auth status', () {
    testWidgets('shows logged-in email when authenticated', (tester) async {
      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('user@example.com', findRichText: true), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Log Out button when authenticated', (tester) async {
      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(
        find.text('Log Out'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('shows Log In button when not authenticated', (tester) async {
      await tester.pumpWidget(_wrap(const SettingsScreen(), authenticated: false, userEmail: null));
      await tester.pumpAndSettle();

      expect(
        find.text('Log In'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('does not show Log Out when not authenticated', (tester) async {
      await tester.pumpWidget(_wrap(const SettingsScreen(), authenticated: false, userEmail: null));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Log Out'), findsNothing);
    });

    testWidgets('Log Out button calls AuthService.logout', (tester) async {
      final fakeAuth = _FakeAuthService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _buildOverrides(fakeAuth),
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Log Out'));
      await tester.pumpAndSettle();

      expect(fakeAuth.logoutCount, 1);
    });
  });

  // ── Responsive layout ────────────────────────────────────────────────────────

  group('SettingsScreen — responsive layout', () {
    testWidgets('renders on 375px wide screen (iPhone SE)', (tester) async {
      tester.view.physicalSize = const Size(375 * 3, 812 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('renders on 428px wide screen (iPhone 14 Pro Max)', (tester) async {
      tester.view.physicalSize = const Size(428 * 3, 926 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('renders on 600px+ wide screen (tablet)', (tester) async {
      tester.view.physicalSize = const Size(768 * 2, 1024 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
