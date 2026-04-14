import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/providers/execution_providers.dart';
import 'package:instructor/services/notification_service.dart';
import 'package:instructor/services/plans_migration.dart';
import 'package:instructor/widgets/mini_player_bar.dart';

/// Glassmorphic bottom navigation bar matching the Stitch design:
/// bg-white/70, backdrop-blur-3xl, shadow, rounded-t-2xl.
///
/// 4 destinations: Library, Create, AI Genius, Profile.
/// Active item: gradient bg (primary → primaryContainer), white text/icon.
/// Inactive: primary/60 color.
/// Labels: Inter 11px semibold uppercase tracking-0.5.
///
/// When a plan execution session is active (running or paused), a
/// [MiniPlayerBar] is displayed directly above the glassmorphic nav bar.
///
/// ## Migration warning (TASK-061)
/// On first mount, [BottomNavShell] checks [migrationPendingProvider]. If
/// `true`, it shows a one-time [AlertDialog] informing the user that their
/// pre-v6 plans are pending sync and will be uploaded automatically after
/// they sign in. The dialog is suppressed for the remainder of the session
/// once dismissed.
///
/// ## Partial-failure warning (TASK-062)
/// [BottomNavShell] also watches [migrationPartialFailureProvider]. When it
/// becomes positive (some plans failed to upload), a non-blocking floating
/// [SnackBar] is shown once per session informing the user that a subset of
/// their plans could not be synced.
class BottomNavShell extends ConsumerStatefulWidget {
  const BottomNavShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends ConsumerState<BottomNavShell> {
  /// Guards against showing the migration warning more than once per session.
  bool _migrationWarningShown = false;

  /// Guards against showing the partial-failure warning more than once per
  /// session.
  bool _migrationFailureWarningShown = false;

  static const _destinations = [
    _NavItem(icon: Icons.auto_stories, label: 'Library', route: '/'),
    _NavItem(icon: Icons.edit_note, label: 'Create', route: '/editor/new'),
    _NavItem(icon: Icons.psychology, label: 'AI Genius', route: '/generate-plan'),
    _NavItem(icon: Icons.person, label: 'Profile', route: '/settings'),
  ];

  @override
  void initState() {
    super.initState();
    // The provider may already be true if migration was deferred during
    // _bootstrap() (before runApp). Check once after the first frame is
    // rendered so showDialog has a valid Navigator context to work with.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Initialize the notification plugin and request OS permissions after
      // the UI is visible. This is intentionally deferred so the app renders
      // first and the OS permission dialog appears in context rather than
      // before any UI is shown. Safe to call on every cold start — the OS
      // only shows the dialog once (subsequent calls are no-ops if already
      // granted or denied).
      ref.read(notificationServiceProvider).initialize();

      if (ref.read(migrationPendingProvider) && !_migrationWarningShown) {
        _migrationWarningShown = true;
        _showMigrationDeferredDialog();
      }
      final failedCount = ref.read(migrationPartialFailureProvider);
      if (failedCount > 0 && !_migrationFailureWarningShown) {
        _migrationFailureWarningShown = true;
        _showMigrationPartialFailureSnackBar(failedCount);
      }
    });
  }

  /// Displays a non-blocking [AlertDialog] informing the user that their
  /// pre-v6 plans are queued for upload and will sync after sign-in.
  void _showMigrationDeferredDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Plans Pending Sync'),
        content: const Text(
          'Some of your plans couldn\u2019t be synced yet because you\u2019re '
          'not signed in.\n\n'
          'They\u2019ll be uploaded automatically once you sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Shows a non-blocking floating [SnackBar] informing the user that some
  /// of their pre-v6 plans could not be uploaded during migration.
  ///
  /// Uses [ScaffoldMessenger] so it floats above the bottom nav bar and
  /// dismisses automatically without blocking user interaction.
  void _showMigrationPartialFailureSnackBar(int failedCount) {
    final noun = failedCount == 1 ? 'plan' : 'plans';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$failedCount $noun couldn\u2019t be synced. '
          'You can recreate them manually in the editor.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Also respond to the provider becoming true after the initial build —
    // for example, if a background migration deferral races with first paint.
    ref.listen<bool>(migrationPendingProvider, (prev, next) {
      if (next == true && !_migrationWarningShown) {
        _migrationWarningShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showMigrationDeferredDialog();
        });
      }
    });

    // Also respond to partial-failure count becoming positive after build —
    // e.g. if a post-login migration completes after the shell is already shown.
    ref.listen<int>(migrationPartialFailureProvider, (prev, next) {
      if (next > 0 && !_migrationFailureWarningShown) {
        _migrationFailureWarningShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showMigrationPartialFailureSnackBar(next);
        });
      }
    });

    final colorScheme = Theme.of(context).colorScheme;
    final hasSession = ref.watch(hasActiveSessionProvider);

    return Scaffold(
      body: widget.navigationShell,
      extendBody: true,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Spotify-like mini-player: visible when a session is active ───
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: hasSession ? const MiniPlayerBar() : const SizedBox.shrink(),
          ),
          // ── Glassmorphic nav bar ─────────────────────────────────────────
          ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.85),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_destinations.length, (i) {
                    final item = _destinations[i];
                    final isActive = i == widget.navigationShell.currentIndex;
                    return _NavButton(
                      icon: item.icon,
                      label: item.label,
                      isActive: isActive,
                      colorScheme: colorScheme,
                      onTap: () => widget.navigationShell.goBranch(i),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.colorScheme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      selected: isActive,
      button: true,
      child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    colorScheme.primaryContainer,
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive
                  ? Colors.white
                  : colorScheme.primary.withValues(alpha: 0.6),
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: isActive
                    ? Colors.white
                    : colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
