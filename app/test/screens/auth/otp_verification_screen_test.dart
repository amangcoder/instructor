/// Widget tests for OtpVerificationScreen (TASK-009).
///
/// Tests cover:
/// 1. OTP input field rendering (6-digit, numeric keyboard)
/// 2. Countdown timer display
/// 3. 'Verify' button calls AuthService.verifyOtp
/// 4. 'Resend OTP' button calls requestOtp
/// 5. Error message display on verification failure
/// 6. Navigation to home on success (clears auth stack)
///
/// ## Running
/// ```
/// flutter test test/screens/auth/otp_verification_screen_test.dart
/// ```
library otp_verification_screen_test;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/screens/auth/otp_verification_screen.dart';
import 'package:instructor/services/auth_service.dart';
import 'package:instructor/providers/auth_providers.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeAuthService implements AuthService {
  AuthResult? verifyResult;
  Exception? verifyError;
  int requestOtpCount = 0;
  int verifyOtpCount = 0;
  String? lastOtp;

  @override
  Future<void> requestOtp(String email) async {
    requestOtpCount++;
  }

  @override
  Future<AuthResult> verifyOtp(String email, String otp) async {
    verifyOtpCount++;
    lastOtp = otp;
    if (verifyError != null) throw verifyError!;
    return verifyResult ??
        AuthResult(
          accessToken: 'test-access',
          refreshToken: 'test-refresh',
          user: AuthUser(id: 'u1', email: email),
        );
  }

  @override
  Future<void> refreshToken() async {}

  @override
  Future<void> logout() async {}

  @override
  AuthUser? getUser() => null;

  @override
  bool get isAuthenticated => false;

  @override
  Stream<AuthState> get authStateStream => const Stream.empty();

  @override
  Future<void> requestOtpWithAuth(String email) => requestOtp(email);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _kEmail = 'test@example.com';

Widget _wrap(Widget widget, {AuthService? authService}) {
  final fakeAuth = authService ?? _FakeAuthService();
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(fakeAuth),
    ],
    child: MaterialApp(
      home: widget,
    ),
  );
}

Widget _wrapWithRouter(Widget widget, {AuthService? authService}) {
  final fakeAuth = authService ?? _FakeAuthService();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => widget),
      GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('Home Screen'))),
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
  group('OtpVerificationScreen', () {
    // ── Rendering ─────────────────────────────────────────────────────────────

    testWidgets('renders OTP input field', (tester) async {
      await tester.pumpWidget(
        _wrap(OtpVerificationScreen(email: _kEmail)),
      );

      // OTP input should be present (may be a custom OtpInputField or TextField)
      expect(
        find.byWidgetPredicate((w) => w is TextField || w is TextFormField),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('renders "Verify" button', (tester) async {
      await tester.pumpWidget(
        _wrap(OtpVerificationScreen(email: _kEmail)),
      );

      expect(find.widgetWithText(ElevatedButton, 'Verify'), findsOneWidget);
    });

    testWidgets('renders "Resend OTP" button', (tester) async {
      await tester.pumpWidget(
        _wrap(OtpVerificationScreen(email: _kEmail)),
      );

      expect(
        find.widgetWithText(TextButton, 'Resend OTP'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('displays countdown timer', (tester) async {
      await tester.pumpWidget(
        _wrap(OtpVerificationScreen(email: _kEmail)),
      );

      // Timer should show something like "5:00" or "300 seconds"
      expect(
        find.byWidgetPredicate((w) {
          if (w is Text) {
            return RegExp(r'\d+:\d\d|\d+ s').hasMatch(w.data ?? '');
          }
          return false;
        }),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('shows the email address the OTP was sent to', (tester) async {
      await tester.pumpWidget(
        _wrap(OtpVerificationScreen(email: _kEmail)),
      );

      expect(find.textContaining(_kEmail, findRichText: true), findsAtLeastNWidgets(1));
    });

    // ── Verify action ─────────────────────────────────────────────────────────

    testWidgets('calls verifyOtp when Verify button is tapped with OTP', (tester) async {
      final fakeAuth = _FakeAuthService();
      await tester.pumpWidget(
        _wrap(OtpVerificationScreen(email: _kEmail), authService: fakeAuth),
      );

      // Enter a 6-digit OTP
      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField || w is TextFormField),
        '123456',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pumpAndSettle();

      expect(fakeAuth.verifyOtpCount, 1);
      expect(fakeAuth.lastOtp, '123456');
    });

    testWidgets('does not call verifyOtp when OTP is less than 6 digits', (tester) async {
      final fakeAuth = _FakeAuthService();
      await tester.pumpWidget(
        _wrap(OtpVerificationScreen(email: _kEmail), authService: fakeAuth),
      );

      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField || w is TextFormField),
        '123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pumpAndSettle();

      expect(fakeAuth.verifyOtpCount, 0);
    });

    testWidgets('displays "Invalid OTP" error on 401 failure', (tester) async {
      final fakeAuth = _FakeAuthService();
      fakeAuth.verifyError = AuthException(
        'Invalid OTP',
        userMessage: 'Invalid OTP',
      );

      await tester.pumpWidget(
        _wrap(OtpVerificationScreen(email: _kEmail), authService: fakeAuth),
      );

      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField || w is TextFormField),
        '000000',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Invalid', findRichText: true),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('displays "OTP expired" error for expired OTP', (tester) async {
      final fakeAuth = _FakeAuthService();
      fakeAuth.verifyError = AuthException(
        'OTP expired',
        userMessage: 'OTP expired. Please request a new one.',
      );

      await tester.pumpWidget(
        _wrap(OtpVerificationScreen(email: _kEmail), authService: fakeAuth),
      );

      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField || w is TextFormField),
        '123456',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('expired', findRichText: true),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('navigates to home after successful verification', (tester) async {
      final fakeAuth = _FakeAuthService();
      await tester.pumpWidget(
        _wrapWithRouter(OtpVerificationScreen(email: _kEmail), authService: fakeAuth),
      );

      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField || w is TextFormField),
        '123456',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);
    });

    // ── Resend ─────────────────────────────────────────────────────────────────

    testWidgets('Resend OTP button calls requestOtp again', (tester) async {
      final fakeAuth = _FakeAuthService();
      await tester.pumpWidget(
        _wrap(OtpVerificationScreen(email: _kEmail), authService: fakeAuth),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Resend OTP'));
      await tester.pumpAndSettle();

      expect(fakeAuth.requestOtpCount, 1);
    });

    // ── OTP input field characteristics ───────────────────────────────────────

    testWidgets('OTP field uses numeric keyboard type', (tester) async {
      await tester.pumpWidget(
        _wrap(OtpVerificationScreen(email: _kEmail)),
      );

      final textFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();

      // At least one field should use numeric keyboard
      final hasNumericKeyboard = textFields.any(
        (f) =>
            f.keyboardType == TextInputType.number ||
            f.keyboardType == const TextInputType.numberWithOptions(),
      );
      expect(hasNumericKeyboard, isTrue);
    });

    // ── Responsive layout ────────────────────────────────────────────────────

    testWidgets('renders correctly on 375px wide screen', (tester) async {
      tester.view.physicalSize = const Size(375 * 3, 667 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrap(OtpVerificationScreen(email: _kEmail)),
      );
      expect(find.byType(OtpVerificationScreen), findsOneWidget);
    });

    testWidgets('renders correctly on 428px wide screen (iPhone 14 Pro Max)', (tester) async {
      tester.view.physicalSize = const Size(428 * 3, 926 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrap(OtpVerificationScreen(email: _kEmail)),
      );
      expect(find.byType(OtpVerificationScreen), findsOneWidget);
    });
  });
}
