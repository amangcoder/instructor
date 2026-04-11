import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/providers/execution_providers.dart';
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
class BottomNavShell extends ConsumerWidget {
  const BottomNavShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _NavItem(icon: Icons.auto_stories, label: 'Library', route: '/'),
    _NavItem(icon: Icons.edit_note, label: 'Create', route: '/editor/new'),
    _NavItem(icon: Icons.psychology, label: 'AI Genius', route: '/generate-plan'),
    _NavItem(icon: Icons.person, label: 'Profile', route: '/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSession = ref.watch(hasActiveSessionProvider);

    return Scaffold(
      body: navigationShell,
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
                    final isActive = i == navigationShell.currentIndex;
                    return _NavButton(
                      icon: item.icon,
                      label: item.label,
                      isActive: isActive,
                      colorScheme: colorScheme,
                      onTap: () => navigationShell.goBranch(i),
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
