import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/providers/settings_providers.dart';
import 'package:instructor/router.dart';
import 'package:instructor/theme/app_theme.dart';

/// Root application widget.
///
/// Configures [MaterialApp.router] with the GoRouter instance, the app theme,
/// and performs crash-recovery checks on startup.
class InstructorApp extends ConsumerWidget {
  const InstructorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

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
