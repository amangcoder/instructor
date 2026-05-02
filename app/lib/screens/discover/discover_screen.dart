// DiscoverScreen — displays a grid of published categories.
//
// Route: /discover  (Branch 3 of StatefulShellRoute in router.dart)
//
// Feature gate:
//   Controlled by [discoverEnabledProvider] — a runtime remote-config flag
//   fetched from GET /api/app-config.  Defaults to false (disabled) on error.
//   This replaces the former build-time constant (kDiscoverEnabled) so the
//   feature can be toggled without a new app build, enabling phased rollouts.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:instructor/models/category.dart';
import 'package:instructor/providers/categories_providers.dart';
import 'package:instructor/providers/remote_config_providers.dart';
import 'package:instructor/router.dart';

/// Top-level screen for the Discover tab.
///
/// Renders a 2-column grid of admin-curated published [Category] items sourced
/// from [categoriesProvider].  Only visible when [discoverEnabledProvider]
/// resolves to `true`; otherwise the user is redirected to the library home.
///
/// The runtime flag is fetched from `GET /api/app-config` so it can be toggled
/// server-side without shipping a new app build (phased rollout support).
///
/// ## States
/// - **Loading** — [CircularProgressIndicator] while the remote config or
///   [categoriesProvider] is fetching.
/// - **Error** — [_ErrorState] with a "Try again" retry button that invalidates
///   the provider.
/// - **Empty** — [_EmptyState] when the server returns no published categories.
/// - **Data** — [_CategoryGrid] 2-column grid; tapping a card navigates to
///   [AppRoutes.categoryDetailPath].
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Feature gate (runtime remote config) ───────────────────────────────
    // discoverEnabledProvider fetches the flag at runtime from the backend.
    // While loading, show a spinner. On error or disabled, redirect to library.
    final discoverEnabledAsync = ref.watch(discoverEnabledProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    // Determine enabled state: default to false while loading or on error.
    final isEnabled = discoverEnabledAsync.valueOrNull ?? false;
    final isLoading = discoverEnabledAsync.isLoading;

    if (!isLoading && !isEnabled) {
      // Remote config resolved: feature is disabled — redirect to library.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.library);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (isLoading) {
      // Waiting for remote config — show neutral loading state.
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ── Data ───────────────────────────────────────────────────────────────

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          await ref.read(categoriesProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
            pinned: true,
            expandedHeight: 110,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 12),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 22),
                  ),
                  Text(
                    'What are you working on?',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) {
                return const SliverFillRemaining(child: _EmptyState());
              }
              return SliverToBoxAdapter(
                child: _BentoCategoryGrid(
                  // Re-trigger animation if the list changes.
                  key: ValueKey(categories.map((c) => c.slug).join(',')),
                  categories: categories,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(categoriesProvider),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category grid
// ─────────────────────────────────────────────────────────────────────────────

/// A two-column "bento" masonry that animates each card into place with a
/// staggered scale + fade + height-settle effect on first build.
///
/// Cards start uniform-sized and small, then pop and grow into their varied
/// final heights using overlapping intervals on a shared [AnimationController].
class _BentoCategoryGrid extends StatefulWidget {
  const _BentoCategoryGrid({required this.categories, super.key});

  final List<Category> categories;

  @override
  State<_BentoCategoryGrid> createState() => _BentoCategoryGridState();
}

class _BentoCategoryGridState extends State<_BentoCategoryGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Final heights vary by index → bento masonry. Pattern is rotated so the two
  // columns stay roughly balanced for common counts (4–6 categories).
  static const _heightPattern = <double>[200, 160, 170, 220, 180, 190];
  static const _initialHeight = 150.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories;
    final leftCards = <Widget>[];
    final rightCards = <Widget>[];

    for (var i = 0; i < categories.length; i++) {
      final cat = categories[i];
      final finalHeight = _heightPattern[i % _heightPattern.length];

      // Per-card stagger: slice the master timeline so cards pop in sequence.
      final start = (i * 0.09).clamp(0.0, 0.55);
      final scaleAnim = CurvedAnimation(
        parent: _controller,
        curve: Interval(
          start,
          (start + 0.6).clamp(0.0, 1.0),
          curve: Curves.elasticOut,
        ),
      );
      final fadeAnim = CurvedAnimation(
        parent: _controller,
        curve: Interval(
          start,
          (start + 0.25).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      );
      final settleAnim = CurvedAnimation(
        parent: _controller,
        curve: Interval(
          start,
          (start + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      );

      final card = Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final h = _initialHeight +
                (finalHeight - _initialHeight) * settleAnim.value;
            final s = 0.4 + 0.6 * scaleAnim.value;
            return Opacity(
              opacity: fadeAnim.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: s,
                child: SizedBox(
                  height: h,
                  child: _CategoryCard(category: cat),
                ),
              ),
            );
          },
        ),
      );

      (i.isEven ? leftCards : rightCards).add(card);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: leftCards)),
          const SizedBox(width: 14),
          Expanded(child: Column(children: rightCards)),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final Category category;

  /// Parses a CSS-style hex color string (`#RRGGBB` or `RRGGBB`) into a
  /// Flutter [Color].  Returns `null` on parse failure.
  static Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      final value = int.tryParse('FF$clean', radix: 16);
      return value != null ? Color(value) : null;
    }
    if (clean.length == 8) {
      final value = int.tryParse(clean, radix: 16);
      return value != null ? Color(value) : null;
    }
    return null;
  }

  /// Maps icon name strings (stored in the database) to [IconData].
  static IconData _resolveIcon(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'fitness_center':
      case 'workout':
        return Icons.fitness_center;
      case 'spa':
      case 'meditation':
        return Icons.spa;
      case 'self_improvement':
      case 'yoga':
        return Icons.self_improvement;
      case 'restaurant':
      case 'cooking':
        return Icons.restaurant;
      case 'checklist':
      case 'routine':
        return Icons.checklist;
      case 'center_focus_strong':
      case 'focus':
        return Icons.center_focus_strong;
      case 'run_circle':
      case 'running':
        return Icons.run_circle_outlined;
      case 'favorite':
      case 'health':
        return Icons.favorite_outline;
      case 'music_note':
      case 'music':
        return Icons.music_note;
      case 'school':
      case 'learning':
        return Icons.school_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor =
        _parseHexColor(category.color) ?? colorScheme.primaryContainer;

    final isDark =
        ThemeData.estimateBrightnessForColor(bgColor) == Brightness.dark;
    final fgColor = isDark ? Colors.white : Colors.black87;
    final iconBg = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.1);
    final decorCircle = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final gradientEnd = isDark
        ? HSLColor.fromColor(bgColor).withLightness(
            (HSLColor.fromColor(bgColor).lightness - 0.14).clamp(0.0, 1.0),
          ).toColor()
        : HSLColor.fromColor(bgColor).withLightness(
            (HSLColor.fromColor(bgColor).lightness - 0.08).clamp(0.0, 1.0),
          ).toColor();

    return Semantics(
      label: '${category.name} category',
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () =>
              context.push(AppRoutes.categoryDetailPath(category.slug)),
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bgColor, gradientEnd],
              ),
              boxShadow: [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Decorative circle — top-right
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: decorCircle,
                      ),
                    ),
                  ),
                  // Decorative circle — bottom-left
                  Positioned(
                    bottom: -30,
                    left: -10,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: decorCircle,
                      ),
                    ),
                  ),
                  // Card content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _resolveIcon(category.icon),
                            color: fgColor,
                            size: 26,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          category.name,
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: fgColor,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Explore',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: fgColor.withValues(alpha: 0.65),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_forward,
                              size: 11,
                              color: fgColor.withValues(alpha: 0.65),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 64,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No categories yet',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back soon \u2014 new content is on the way.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              "Couldn't load categories",
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
