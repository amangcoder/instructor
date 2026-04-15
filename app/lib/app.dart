import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/providers/settings_providers.dart';
import 'package:instructor/router.dart';
import 'package:instructor/screens/force_update/force_update_screen.dart';
import 'package:instructor/services/app_version_service.dart';
import 'package:instructor/services/notification_tap_channel.dart';
import 'package:instructor/services/plan_execution_engine.dart';
import 'package:instructor/theme/app_theme.dart';

/// Root application widget.
///
/// Configures [MaterialApp.router] with the GoRouter instance, the app theme,
/// and performs crash-recovery checks on startup.
///
/// ## Notification tap navigation (REQ-004)
///
/// [InstructorApp] listens to [notificationTapStreamProvider] and
/// [notificationRouteStreamProvider] (via the router shell) so that:
///
/// * Android: tapping the foreground notification body invokes the
///   `com.instructor.app/notification` MethodChannel → this widget
///   navigates to `/now-playing` with deduplication (no-op if already there).
/// * iOS: notification tap brings app to foreground natively; the mini-player
///   already provides session context — no extra navigation is required.
class InstructorApp extends ConsumerStatefulWidget {
  const InstructorApp({super.key});

  @override
  ConsumerState<InstructorApp> createState() => _InstructorAppState();
}

class _InstructorAppState extends ConsumerState<InstructorApp> {
  @override
  void initState() {
    super.initState();
    // Eagerly warm up the providers so the MethodChannel handler is alive
    // before the first frame is rendered.
    ref.read(notificationTapStreamProvider);
    ref.read(planTriggerFiredStreamProvider);
  }

  /// Navigates to `/now-playing` unless the current route is already there
  /// (deduplication guard — prevents duplicate route entries in the stack).
  void _navigateToNowPlaying() {
    final router = ref.read(routerProvider);
    final currentLocation =
        router.routerDelegate.currentConfiguration.uri.toString();
    if (currentLocation != AppRoutes.nowPlaying) {
      router.go(AppRoutes.nowPlaying);
    }
  }

  /// Loads the plan referenced by a fired trigger and begins execution.
  ///
  /// Runs when the user taps a plan-start notification on Android (or when
  /// the app was cold-started by that tap). Navigates to `/now-playing` on
  /// success; silently skips if the plan cannot be found (e.g. deleted after
  /// the trigger was scheduled).
  Future<void> _handlePlanTriggerFired(PlanTriggerFiredEvent event) async {
    try {
      final repo = ref.read(planRepositoryProvider);
      final plan = await repo.getPlanById(event.planId);
      if (plan == null) {
        debugPrint('[PlanTrigger] plan ${event.planId} not found — ignoring');
        return;
      }
      final engine = ref.read(planExecutionEngineProvider);
      await engine.startPlan(plan);
      _navigateToNowPlaying();
    } catch (e, st) {
      debugPrint('[PlanTrigger] failed to auto-start plan: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final theme = AppTheme.light();
    final darkTheme = AppTheme.dark();
    final themeMode =
        ref.watch(themeModeSettingProvider).valueOrNull ?? ThemeMode.system;

    // ── Android notification body-tap → Now Playing navigation (REQ-004) ────
    ref.listen<AsyncValue<void>>(
      notificationTapStreamProvider,
      (_, next) => next.whenData((_) => _navigateToNowPlaying()),
    );

    // ── Plan-trigger notification → auto-start plan (Android) ───────────────
    ref.listen<AsyncValue<PlanTriggerFiredEvent>>(
      planTriggerFiredStreamProvider,
      (_, next) => next.whenData(_handlePlanTriggerFired),
    );

    // ── Force-update gate ───────────────────────────────────────────────────
    // When the backend reports that the current build is below the minimum
    // supported version, short-circuit the whole app and render a blocking
    // update screen instead of the router. We intentionally do NOT block on
    // loading/error so a slow or failed check never locks the user out.
    final versionCheck = ref.watch(appVersionCheckProvider);
    final forceUpdateInfo = versionCheck.maybeWhen(
      data: (info) => info.forceUpdate ? info : null,
      orElse: () => null,
    );
    if (forceUpdateInfo != null) {
      return MaterialApp(
        title: 'Instructor',
        theme: theme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        home: ForceUpdateScreen(info: forceUpdateInfo),
      );
    }

    return MaterialApp.router(
      title: 'Instructor',
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
