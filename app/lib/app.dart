import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/providers/settings_providers.dart';
import 'package:instructor/router.dart';
import 'package:instructor/services/notification_tap_channel.dart';
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
    // Eagerly warm up the provider so the MethodChannel handler is alive
    // before the first frame is rendered.
    ref.read(notificationTapStreamProvider);
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

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // ── Android notification body-tap → Now Playing navigation (REQ-004) ────
    ref.listen<AsyncValue<void>>(
      notificationTapStreamProvider,
      (_, next) => next.whenData((_) => _navigateToNowPlaying()),
    );

    return MaterialApp.router(
      title: 'Instructor',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeSettingProvider).valueOrNull ?? ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
