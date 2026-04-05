import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/screens/plan_library/plan_library_screen.dart';
import 'package:instructor/screens/plan_editor/plan_editor_screen.dart';
import 'package:instructor/screens/now_playing/now_playing_screen.dart';
import 'package:instructor/screens/onboarding/onboarding_screen.dart';
import 'package:instructor/screens/settings/settings_screen.dart';
import 'package:instructor/services/app_settings.dart';

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
}

/// Global GoRouter provider.
///
/// Defined with [riverpod_annotation] so it can be overridden in tests.
///
/// ## Onboarding redirect guard
/// On every navigation event the `redirect` callback queries the
/// [AppSettings.hasCompletedOnboarding] flag:
/// - If `false` and the user is **not** on `/onboarding`, redirect there.
/// - If `true` and the user **is** on `/onboarding`, redirect to the library.
///
/// Because [OnboardingScreen] awaits [AppSettings.setHasCompletedOnboarding]
/// before calling `context.go(...)`, the flag is guaranteed to be written
/// before the redirect check runs on the subsequent navigation.
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.library,
    redirect: (BuildContext context, GoRouterState state) async {
      try {
        final settings = ref.read(appSettingsProvider);
        final isComplete = await settings.hasCompletedOnboarding();
        final isOnOnboarding =
            state.matchedLocation == AppRoutes.onboarding;

        if (!isComplete && !isOnOnboarding) return AppRoutes.onboarding;
        if (isComplete && isOnOnboarding) return AppRoutes.library;
        return null;
      } catch (_) {
        // If the settings table is unavailable (e.g. during tests or first
        // frame before the DB isolate is ready), allow navigation to proceed.
        return null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.library,
        builder: (BuildContext context, GoRouterState state) =>
            const PlanLibraryScreen(),
      ),
      GoRoute(
        path: AppRoutes.editorNew,
        builder: (BuildContext context, GoRouterState state) =>
            const PlanEditorScreen(),
      ),
      GoRoute(
        path: AppRoutes.editorEdit,
        builder: (BuildContext context, GoRouterState state) {
          final planId = int.parse(state.pathParameters['planId']!);
          return PlanEditorScreen(planId: planId);
        },
      ),
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
      GoRoute(
        path: AppRoutes.settings,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
    ],
  );
}
