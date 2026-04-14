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

import 'package:instructor/screens/settings/settings_screen.dart';
import 'package:instructor/services/auth_service.dart';
import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/providers/tts_providers.dart';

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
  Stream<AuthState> get authStateStream =>
      Stream.value(_isAuthenticated ? AuthenticatedState(user: getUser()!) : const UnauthenticatedState());

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
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(
  Widget widget, {
  bool authenticated = true,
  String? userEmail = 'user@example.com',
}) {
  final fakeAuth = _FakeAuthService(authenticated: authenticated, email: userEmail);

  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(fakeAuth),
    ],
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
    overrides: [
      authServiceProvider.overrideWithValue(fakeAuth),
    ],
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

    testWidgets('shows Logout button when authenticated', (tester) async {
      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ElevatedButton, 'Logout'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('shows Login button when not authenticated', (tester) async {
      await tester.pumpWidget(_wrap(const SettingsScreen(), authenticated: false, userEmail: null));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ElevatedButton, 'Login'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('does not show Logout when not authenticated', (tester) async {
      await tester.pumpWidget(_wrap(const SettingsScreen(), authenticated: false, userEmail: null));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Logout'), findsNothing);
    });

    testWidgets('Logout button calls AuthService.logout', (tester) async {
      final fakeAuth = _FakeAuthService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(fakeAuth),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
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
