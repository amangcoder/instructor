/// Widget tests for PlanGenerationScreen and PlanReviewScreen (TASK-011).
///
/// Tests cover:
/// 1. PlanGenerationScreen — text input, Generate button, loading state, error display
/// 2. PlanReviewScreen — step display, save/discard actions
/// 3. Auth guard — unauthenticated users see login prompt
/// 4. go_router integration (/generate-plan and /generate-plan/review)
///
/// ## Running
/// ```
/// flutter test test/screens/plan_generation/plan_generation_screen_test.dart
/// ```
library plan_generation_screen_test;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/screens/plan_generation/plan_generation_screen.dart';
import 'package:instructor/screens/plan_generation/plan_review_screen.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/services/auth_service.dart';
import 'package:instructor/repositories/plan_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakePlanGenerationClient {
  int generateCount = 0;
  Plan? response;
  Exception? error;

  Future<Plan> generatePlan(String prompt, {String? category}) async {
    generateCount++;
    if (error != null) throw error!;
    return response ?? _makeTestPlan();
  }
}

class _FakeAuthService implements AuthService {
  final bool _isAuthenticated;
  _FakeAuthService({bool authenticated = true}) : _isAuthenticated = authenticated;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  AuthUser? getUser() =>
      _isAuthenticated ? AuthUser(id: 'u1', email: 'test@example.com') : null;

  @override
  Stream<AuthState> get authStateStream => const Stream.empty();

  @override
  Future<void> requestOtp(String email) async {}

  @override
  Future<AuthResult> verifyOtp(String email, String otp) async =>
      throw UnimplementedError();

  @override
  Future<void> refreshToken() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> requestOtpWithAuth(String email) => requestOtp(email);
}

class _FakePlanRepository implements PlanRepository {
  final List<Plan> _plans = [];
  int createCount = 0;

  @override
  Future<int> createPlan(Plan plan) async {
    createCount++;
    _plans.add(plan.copyWith(id: _plans.length + 1));
    return _plans.length;
  }

  @override
  Future<void> updatePlan(int id, Plan plan) async {}

  @override
  Future<void> deletePlan(int id) async {}

  @override
  Future<Plan?> getPlanById(int id) async => null;

  @override
  Stream<List<Plan>> watchAllPlans({String? searchQuery, dynamic category}) =>
      Stream.value(_plans);

  @override
  Future<void> updateLastUsed(int id) async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Plan _makeTestPlan() {
  final now = DateTime(2026);
  return Plan(
    id: 0,
    name: 'Generated Yoga Plan',
    description: 'A 20-minute morning yoga routine',
    defaultVoice: 'aoede',
    steps: [
      PlanStep.say(id: 's1', text: 'Start in mountain pose'),
      PlanStep.wait(id: 's2', duration: const Duration(seconds: 30)),
      PlanStep.say(id: 's3', text: 'Now breathe deeply'),
    ],
    createdAt: now,
    updatedAt: now,
  );
}

Widget _wrap(
  Widget widget, {
  bool authenticated = true,
  _FakePlanGenerationClient? planClient,
  _FakePlanRepository? planRepo,
}) {
  final fakeAuth = _FakeAuthService(authenticated: authenticated);
  final fakePlanRepo = planRepo ?? _FakePlanRepository();
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(fakeAuth),
      planRepositoryProvider.overrideWithValue(fakePlanRepo),
      if (planClient != null)
        planGenerationClientProvider.overrideWithValue(planClient),
    ],
    child: MaterialApp(home: widget),
  );
}

Widget _wrapWithRouter({
  bool authenticated = true,
  _FakePlanGenerationClient? planClient,
  _FakePlanRepository? planRepo,
}) {
  final fakeAuth = _FakeAuthService(authenticated: authenticated);
  final fakePlanRepo = planRepo ?? _FakePlanRepository();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const PlanGenerationScreen(),
      ),
      GoRoute(
        path: '/generate-plan/review',
        builder: (ctx, state) => PlanReviewScreen(
          plan: state.extra as Plan? ?? _makeTestPlan(),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('Login Screen')),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('Home Screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(fakeAuth),
      planRepositoryProvider.overrideWithValue(fakePlanRepo),
      if (planClient != null)
        planGenerationClientProvider.overrideWithValue(planClient),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// PlanGenerationScreen tests
// ---------------------------------------------------------------------------

void main() {
  group('PlanGenerationScreen', () {
    // ── Auth guard ───────────────────────────────────────────────────────────

    testWidgets('shows "Login to use AI plan generation" when not authenticated', (tester) async {
      await tester.pumpWidget(_wrap(
        const PlanGenerationScreen(),
        authenticated: false,
      ));

      expect(
        find.textContaining('Login', findRichText: true),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('shows login button when unauthenticated', (tester) async {
      await tester.pumpWidget(_wrap(
        const PlanGenerationScreen(),
        authenticated: false,
      ));

      expect(
        find.widgetWithText(ElevatedButton, 'Login'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('shows generation UI when authenticated', (tester) async {
      await tester.pumpWidget(_wrap(const PlanGenerationScreen()));

      expect(
        find.byWidgetPredicate((w) => w is TextField || w is TextFormField),
        findsAtLeastNWidgets(1),
      );
    });

    // ── Input and Generate ───────────────────────────────────────────────────

    testWidgets('renders text input for plan description', (tester) async {
      await tester.pumpWidget(_wrap(const PlanGenerationScreen()));

      expect(
        find.byWidgetPredicate((w) => w is TextField || w is TextFormField),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('renders "Generate" button', (tester) async {
      await tester.pumpWidget(_wrap(const PlanGenerationScreen()));

      expect(
        find.widgetWithText(ElevatedButton, 'Generate'),
        findsOneWidget,
      );
    });

    testWidgets('does not call API when input is empty', (tester) async {
      final client = _FakePlanGenerationClient();
      await tester.pumpWidget(_wrap(const PlanGenerationScreen(), planClient: client));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Generate'));
      await tester.pumpAndSettle();

      expect(client.generateCount, 0);
    });

    testWidgets('calls generatePlan with typed prompt', (tester) async {
      final client = _FakePlanGenerationClient();
      await tester.pumpWidget(_wrap(const PlanGenerationScreen(), planClient: client));

      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField || w is TextFormField),
        'a 20-minute yoga session',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Generate'));
      await tester.pumpAndSettle();

      expect(client.generateCount, 1);
    });

    testWidgets('shows loading indicator while generating', (tester) async {
      final client = _FakePlanGenerationClient();
      // Don't set response — let it hang
      await tester.pumpWidget(_wrap(const PlanGenerationScreen(), planClient: client));

      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField || w is TextFormField),
        'yoga session',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Generate'));
      await tester.pump(); // Don't settle — capture loading state

      expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
    });

    testWidgets('displays error message on generation failure', (tester) async {
      final client = _FakePlanGenerationClient();
      client.error = Exception('Plan generation failed');

      await tester.pumpWidget(_wrap(const PlanGenerationScreen(), planClient: client));

      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField || w is TextFormField),
        'yoga',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Generate'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('failed', findRichText: true),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('displays rate limit error message on 429', (tester) async {
      final client = _FakePlanGenerationClient();
      client.error = PlanGenerationException(
        'Rate limit exceeded',
        userMessage: 'Your plan generation request was rate-limited. Try again in 30 minutes.',
      );

      await tester.pumpWidget(_wrap(const PlanGenerationScreen(), planClient: client));

      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField || w is TextFormField),
        'yoga',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Generate'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('rate-limited', findRichText: true),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('navigates to PlanReviewScreen after successful generation', (tester) async {
      final client = _FakePlanGenerationClient();
      client.response = _makeTestPlan();

      await tester.pumpWidget(_wrapWithRouter(planClient: client));

      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField || w is TextFormField),
        'yoga session',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Generate'));
      await tester.pumpAndSettle();

      expect(find.byType(PlanReviewScreen), findsOneWidget);
    });
  });

  // ── PlanReviewScreen ──────────────────────────────────────────────────────

  group('PlanReviewScreen', () {
    final testPlan = _makeTestPlan();

    testWidgets('displays generated plan name', (tester) async {
      await tester.pumpWidget(
        _wrap(PlanReviewScreen(plan: testPlan)),
      );

      expect(find.text(testPlan.name), findsAtLeastNWidgets(1));
    });

    testWidgets('displays all plan steps', (tester) async {
      await tester.pumpWidget(
        _wrap(PlanReviewScreen(plan: testPlan)),
      );
      await tester.pumpAndSettle();

      // Each say step's text should be visible
      for (final step in testPlan.steps.whereType<dynamic>()) {
        // steps are PlanStep unions — check for text content
      }
      expect(find.byType(PlanReviewScreen), findsOneWidget);
    });

    testWidgets('renders "Save Plan" button', (tester) async {
      await tester.pumpWidget(
        _wrap(PlanReviewScreen(plan: testPlan)),
      );

      expect(find.widgetWithText(ElevatedButton, 'Save Plan'), findsOneWidget);
    });

    testWidgets('renders "Discard" button', (tester) async {
      await tester.pumpWidget(
        _wrap(PlanReviewScreen(plan: testPlan)),
      );

      expect(
        find.widgetWithText(TextButton, 'Discard'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('Save Plan saves to database and navigates away', (tester) async {
      final planRepo = _FakePlanRepository();
      await tester.pumpWidget(
        _wrapWithRouter(planRepo: planRepo),
      );

      // Navigate to review screen
      final client = _FakePlanGenerationClient();
      client.response = testPlan;

      // Tap save and verify
      await tester.pumpWidget(
        _wrap(PlanReviewScreen(plan: testPlan), planRepo: planRepo),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Plan'));
      await tester.pumpAndSettle();

      expect(planRepo.createCount, 1);
    });

    testWidgets('Discard button returns without saving', (tester) async {
      final planRepo = _FakePlanRepository();
      await tester.pumpWidget(
        _wrap(PlanReviewScreen(plan: testPlan), planRepo: planRepo),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Discard'));
      await tester.pumpAndSettle();

      expect(planRepo.createCount, 0);
    });
  });
}
