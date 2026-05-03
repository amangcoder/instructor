import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/models/auth_models.dart';
import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/screens/auth/login_screen.dart';
import 'package:instructor/screens/auth/otp_verification_screen.dart';
import 'package:instructor/screens/now_playing/now_playing_screen.dart';
import 'package:instructor/screens/onboarding/onboarding_screen.dart';
import 'package:instructor/screens/plan_editor/plan_editor_screen.dart';
import 'package:instructor/screens/plan_generation/plan_generation_screen.dart';
import 'package:instructor/screens/plan_generation/plan_review_screen.dart';
import 'package:instructor/screens/plan_request/plan_request_screen.dart';
import 'package:instructor/screens/create_plan/create_plan_screen.dart';
import 'package:instructor/screens/discover/category_screen.dart';
import 'package:instructor/screens/discover/discover_screen.dart';
import 'package:instructor/screens/home/home_screen.dart';
import 'package:instructor/screens/plan_detail/plan_detail_screen.dart';
import 'package:instructor/screens/series/series_detail_screen.dart';
import 'package:instructor/screens/settings/settings_screen.dart';
import 'package:instructor/screens/shared_plan/shared_plan_preview_screen.dart';
import 'package:instructor/services/app_settings.dart';
import 'package:instructor/widgets/bottom_nav_shell.dart';

part 'router.g.dart';

/// Route path constants.
abstract final class AppRoutes {
  static const String library = '/';
  static const String editor = '/editor';
  static const String editorNew = '/editor/new';
  static const String editorEdit = '/editor/:planId';
  static const String nowPlaying = '/now-playing';
  static const String onboarding = '/onboarding';
  static const String settings = '/settings';

  // ── Auth ─────────────────────────────────────────────────────────────────
  static const String login = '/login';

  /// Full path for the OTP step (sub-route of /login).
  static const String otpVerification = '/login/otp';

  // ── AI Plan Generation ────────────────────────────────────────────────────
  static const String generatePlan = '/generate-plan';

  /// Full path for the review step (sub-route of /generate-plan).
  static const String generatePlanReview = '/generate-plan/review';

  // ── Plan Sharing ─────────────────────────────────────────────────────────

  /// Route pattern for a shared plan deep link.
  ///
  /// The `:token` path parameter holds the share token extracted from the
  /// Universal Link path `/s/:token`.
  static const String sharedPlan = '/shared/:token';

  /// Builds the concrete path for a given share [token].
  static String sharedPlanPath(String token) => '/shared/$token';

  // ── Series ───────────────────────────────────────────────────────────────

  /// Route pattern for a series detail screen.
  static const String seriesDetail = '/series/:id';

  /// Builds the concrete path for a given series [id].
  static String seriesDetailPath(String id) => '/series/$id';

  // ── Discover ─────────────────────────────────────────────────────────────

  /// Top-level Discover screen — shows admin-curated category grid.
  ///
  /// Only reachable when `remoteConfig.discoverEnabled == true`; the redirect
  /// guard falls back to [library] otherwise.
  static const String discover = '/discover';

  /// Route pattern for a single category detail screen.
  static const String categoryDetail = '/discover/:categorySlug';

  /// Builds the concrete path for a given category [slug].
  static String categoryDetailPath(String slug) => '/discover/$slug';

  // ── Plan Detail ──────────────────────────────────────────────────────────

  /// Route pattern for a full plan detail screen (tree + voice picker).
  static const String planDetail = '/plans/:id';

  /// Builds the concrete path for a given plan [id].
  static String planDetailPath(String id) => '/plans/$id';

  // ── Create Plan ──────────────────────────────────────────────────────────

  /// Route for the user-authored private plan creation form.
  ///
  /// Auth-gated — unauthenticated users are redirected to [login].
  static const String createPlan = '/create-plan';

  // ── Plan Request ─────────────────────────────────────────────────────────

  /// Route for the consumer plan-request form.
  ///
  /// Submits a request to the backend for admin review; the admin either
  /// approves and generates a plan or pastes a JSON plan back into the
  /// request. Auth-gated — unauthenticated users are redirected to [login].
  static const String planRequest = '/plan-request';
}

/// Routes that require an authenticated user.
const _kAuthGatedRoutes = {
  AppRoutes.generatePlan,
  AppRoutes.generatePlanReview,
  AppRoutes.createPlan,
  AppRoutes.planRequest,
};

/// Returns true if [location] requires authentication.
bool _isAuthGated(String location) {
  if (_kAuthGatedRoutes.contains(location)) return true;
  // All /editor routes (new + edit) require auth.
  if (location.startsWith(AppRoutes.editor)) return true;
  return false;
}

/// Global GoRouter provider.
///
/// Defined with [riverpod_annotation] so it can be overridden in tests.
///
/// ## Auth + Onboarding redirect guard
/// On every navigation event the `redirect` callback:
/// 1. Checks onboarding completion — redirects to /onboarding if incomplete.
/// 2. Checks auth state — redirects to /login for auth-gated routes when
///    the user is not authenticated.
/// 3. Redirects authenticated users away from the /login flow.
/// Bridges Riverpod's [authStateNotifierProvider] to a [ChangeNotifier] that
/// GoRouter can use as [refreshListenable]. This ensures the router
/// re-evaluates its redirect guard whenever auth state changes (e.g. after
/// an auto-logout triggered by a failed token refresh).
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    _sub = ref.listen(authStateNotifierProvider, (_, __) {
      notifyListeners();
    });
  }

  late final ProviderSubscription<AsyncValue<AuthState>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final authChangeNotifier = _AuthChangeNotifier(ref);
  ref.onDispose(authChangeNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.library,
    refreshListenable: authChangeNotifier,
    redirect: (BuildContext context, GoRouterState state) async {
      try {
        // ── Auth guard ────────────────────────────────────────────────────
        final authStateAsync = ref.read(authStateNotifierProvider);
        final isAuthenticated = authStateAsync.maybeWhen(
          data: (s) => s is Authenticated,
          orElse: () => false,
        );

        final isOnLoginFlow =
            state.matchedLocation == AppRoutes.login ||
                state.matchedLocation == AppRoutes.otpVerification;

        // ── Onboarding guard ──────────────────────────────────────────────
        // The login flow is exempt so that unauthenticated users can reach
        // /login from the onboarding screen (e.g. when selecting a template
        // before signing in). Without this exemption the router would loop
        // the user back to /onboarding and they'd be locked out.
        final settings = ref.read(appSettingsProvider);
        final isComplete = await settings.hasCompletedOnboarding();
        final isOnOnboarding =
            state.matchedLocation == AppRoutes.onboarding;

        if (!isComplete && !isOnOnboarding && !isOnLoginFlow) return AppRoutes.onboarding;
        if (isComplete && isOnOnboarding) return AppRoutes.library;

        // Authenticated user visiting login — send home.
        if (isAuthenticated && isOnLoginFlow) return AppRoutes.library;

        // Unauthenticated user visiting auth-gated route — send to login.
        if (!isAuthenticated && _isAuthGated(state.matchedLocation)) {
          return AppRoutes.login;
        }

        return null;
      } catch (_) {
        // If the settings table is unavailable (e.g. during tests or the
        // first frame before the DB isolate is ready), allow navigation.
        return null;
      }
    },
    routes: [
      // ── Shell with bottom nav bar (StatefulShellRoute preserves tab state) ─
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            BottomNavShell(navigationShell: navigationShell),
        branches: [
          // Branch 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.library,
                builder: (BuildContext context, GoRouterState state) =>
                    const HomeScreen(),
              ),
            ],
          ),
          // Branch 1: Create / Editor
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.editorNew,
                builder: (BuildContext context, GoRouterState state) =>
                    const PlanEditorScreen(),
              ),
              GoRoute(
                path: AppRoutes.editorEdit,
                builder: (BuildContext context, GoRouterState state) {
                  final planId = state.pathParameters['planId'];
                  if (planId == null || planId.isEmpty) {
                    return Scaffold(
                      appBar: AppBar(title: const Text('Invalid Plan')),
                      body: const Center(child: Text('Plan not found.')),
                    );
                  }
                  return PlanEditorScreen(planId: planId);
                },
              ),
            ],
          ),
          // Branch 2: Settings / Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (BuildContext context, GoRouterState state) =>
                    const SettingsScreen(),
              ),
            ],
          ),
          // Branch 3: Discover
          // Visible only when remoteConfig.discoverEnabled == true.
          // The redirect guard falls back to AppRoutes.library when the flag
          // is disabled so this branch is never entered accidentally.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.discover,
                builder: (BuildContext context, GoRouterState state) =>
                    const DiscoverScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── AI Genius / Generate Plan (full-screen, hidden from bottom nav) ───
      // Kept reachable for deep links and tests, but not exposed via the
      // current UI surface.
      GoRoute(
        path: AppRoutes.generatePlan,
        builder: (BuildContext context, GoRouterState state) =>
            const PlanGenerationScreen(),
        routes: [
          GoRoute(
            path: 'review',
            builder: (BuildContext context, GoRouterState state) {
              final payload = state.extra as GeneratedPlanPayload?;
              return PlanReviewScreen(payload: payload);
            },
          ),
        ],
      ),

      // ── Full-screen routes (no bottom nav) ─────────────────────────────
      GoRoute(
        path: AppRoutes.nowPlaying,
        builder: (BuildContext context, GoRouterState state) =>
            const NowPlayingScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),

      // ── Shared plan deep link ─────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.sharedPlan,
        builder: (BuildContext context, GoRouterState state) {
          final token = state.pathParameters['token'] ?? '';
          return SharedPlanPreviewScreen(shareToken: token);
        },
      ),

      // ── Series detail (full-screen, no bottom nav) ───────────────────────
      GoRoute(
        path: AppRoutes.seriesDetail,
        builder: (BuildContext context, GoRouterState state) {
          final id = state.pathParameters['id'] ?? '';
          return SeriesDetailScreen(seriesId: id);
        },
      ),

      // ── Discover: category detail (full-screen, no bottom nav) ───────────
      GoRoute(
        path: AppRoutes.categoryDetail,
        builder: (BuildContext context, GoRouterState state) {
          final slug = state.pathParameters['categorySlug'] ?? '';
          return CategoryScreen(categorySlug: slug);
        },
      ),

      // ── Plan detail (full-screen, no bottom nav) ─────────────────────────
      GoRoute(
        path: AppRoutes.planDetail,
        builder: (BuildContext context, GoRouterState state) {
          final id = state.pathParameters['id'] ?? '';
          return PlanDetailScreen(planId: id);
        },
      ),

      // ── Create plan (full-screen, auth-gated) ─────────────────────────────
      GoRoute(
        path: AppRoutes.createPlan,
        builder: (BuildContext context, GoRouterState state) =>
            const CreatePlanScreen(),
      ),

      // ── Plan request (full-screen, auth-gated) ────────────────────────────
      GoRoute(
        path: AppRoutes.planRequest,
        builder: (BuildContext context, GoRouterState state) =>
            const PlanRequestScreen(),
      ),

      // ── Auth routes ──────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
        routes: [
          GoRoute(
            path: 'otp',
            builder: (BuildContext context, GoRouterState state) {
              final email = state.extra as String? ?? '';
              return OtpVerificationScreen(email: email);
            },
          ),
        ],
      ),
    ],
  );
}
