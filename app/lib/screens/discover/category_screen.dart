// CategoryScreen — displays series and plans belonging to a single category.
//
// Route: /discover/:categorySlug
// The [categorySlug] path parameter is passed directly from GoRouter.
//
// Data sources:
//   • [seriesByCategoryProvider](categorySlug) — fetches published series via
//     GET /api/series?categorySlug=<slug>.
//   • Series.sessions — inline Plan list within each Series; filtered by the
//     published+ready rule (AC-012) before display.
//   • [planTreeProvider](planId) — used when the user taps a plan row to
//     navigate to the full plan detail screen which renders the sub-plan tree.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_voice.dart';
import 'package:instructor/models/series.dart';
import 'package:instructor/providers/categories_providers.dart';
import 'package:instructor/router.dart';
import 'package:instructor/screens/plan_library/widgets/plan_card.dart';
import 'package:instructor/widgets/series_card.dart';

/// Detail screen for a single content category.
///
/// Displays all published [Series] (with their TTS-ready sessions) that belong
/// to [categorySlug].  Series are fetched via [seriesByCategoryProvider].
///
/// ### Filtering (AC-012)
/// A [Plan] session is shown only when **both** of the following are true:
///   1. `plan.isPublished == true` **or** `plan.visibility == 'public'`
///   2. `plan.voices` contains at least one [PlanVoice] with `status == 'ready'`
///
/// Plans that don't satisfy this rule are silently hidden (the server-side API
/// should already filter them, but the client re-validates as a safety net).
///
/// ### Navigation
/// - Tapping a [SeriesCard] → [AppRoutes.seriesDetailPath]
/// - Tapping a plan row → [AppRoutes.planDetailPath]  (renders plan tree via
///   [planTreeProvider] on the destination screen)
///
/// ## States
/// - **Loading** — [CircularProgressIndicator]
/// - **Error** — [_ErrorState] with retry
/// - **Empty** — [_EmptyState] when no series are published for the category
/// - **Data** — scrollable list of [_SeriesSection] widgets
class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.categorySlug});

  /// URL slug that uniquely identifies the category (e.g. `strength-training`).
  final String categorySlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesAsync = ref.watch(seriesByCategoryProvider(categorySlug));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _formatSlug(categorySlug),
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
      ),
      body: seriesAsync.when(
        data: (seriesList) {
          if (seriesList.isEmpty) return const _EmptyState();
          return _SeriesAndPlanList(seriesList: seriesList);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(seriesByCategoryProvider(categorySlug)),
        ),
      ),
    );
  }

  /// Converts a slug like `strength-training` into `Strength Training`.
  static String _formatSlug(String slug) => slug
      .split('-')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

// ─────────────────────────────────────────────────────────────────────────────
// Series + plan list
// ─────────────────────────────────────────────────────────────────────────────

class _SeriesAndPlanList extends StatelessWidget {
  const _SeriesAndPlanList({required this.seriesList});

  final List<Series> seriesList;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: seriesList.length,
      itemBuilder: (context, index) =>
          _SeriesSection(series: seriesList[index]),
    );
  }
}

/// One section per [Series]: a header [SeriesCard] followed by its filtered
/// plan session rows.
class _SeriesSection extends StatelessWidget {
  const _SeriesSection({required this.series});

  final Series series;

  /// AC-012: a plan session is visible if it is published **and** has at least
  /// one voice synthesis that completed successfully (`status == 'ready'`).
  static bool _isPlanReady(Plan plan) {
    final isPublished = plan.isPublished || plan.visibility == 'public';
    if (!isPublished) return false;
    return plan.voices.any((PlanVoice v) => v.status == 'ready');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final readySessions = series.sessions.where(_isPlanReady).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Series header card ─────────────────────────────────────────────
        Semantics(
          label: '${series.name}, ${series.totalSessions} sessions',
          button: true,
          child: SeriesCard(
            series: series,
            onTap: () =>
                context.push(AppRoutes.seriesDetailPath(series.id)),
          ),
        ),

        // ── Plan session rows (published + ready only) ─────────────────────
        if (readySessions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
            child: Text(
              'SESSIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colorScheme.outline,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...readySessions.map((plan) => _PlanRow(plan: plan)),
        ],

        const SizedBox(height: 24),
      ],
    );
  }
}

/// Single tappable row for a plan session inside a [_SeriesSection].
class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: plan.name,
      button: true,
      child: InkWell(
        onTap: () => context.push(AppRoutes.planDetailPath(plan.id)),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                planCategoryIcon(plan.category),
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (plan.description != null &&
                        plan.description!.isNotEmpty)
                      Text(
                        plan.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.outline,
                size: 20,
              ),
            ],
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
              Icons.library_books_outlined,
              size: 64,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing here yet',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Content for this category is coming soon.',
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
              "Couldn't load content",
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
