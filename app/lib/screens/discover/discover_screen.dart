// DiscoverScreen — the catalog: curated categories + searchable plan library.
//
// Route: /discover  (Branch 3 of StatefulShellRoute in router.dart)
//
// Feature gate:
//   Controlled by [discoverEnabledProvider] — a runtime remote-config flag
//   fetched from GET /api/app-config.  Defaults to false (disabled) on error.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:instructor/models/category.dart';
import 'package:instructor/models/library_plan_summary.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/series.dart';
import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/providers/categories_providers.dart';
import 'package:instructor/providers/library_providers.dart' as libProviders;
import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/providers/remote_config_providers.dart';
import 'package:instructor/providers/series_providers.dart';
import 'package:instructor/router.dart';
import 'package:instructor/screens/plan_library/widgets/countdown_overlay.dart';
import 'package:instructor/screens/plan_library/widgets/plan_card.dart';
import 'package:instructor/services/plan_api_service.dart' show PlanApiException;
import 'package:instructor/services/plan_execution_engine.dart';
import 'package:instructor/widgets/active_session_dialog.dart';
import 'package:instructor/widgets/favorite_button.dart';
import 'package:instructor/widgets/offline_banner.dart';
import 'package:instructor/widgets/star_rating_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Discover screen
// ─────────────────────────────────────────────────────────────────────────────

/// Top-level Discover screen — curated category grid plus a searchable
/// view of the entire plan library.
///
/// When the search/filter is empty, the screen displays a 2-column "bento"
/// grid of admin-curated categories. As soon as the user types or selects a
/// category chip, the grid is replaced by a vertical list of matching
/// [LibraryPlanSummary] cards. Tapping a card silently adds the plan to "My
/// Plans" (if not already added) and starts playback.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoverEnabledAsync = ref.watch(discoverEnabledProvider);
    final isEnabled = discoverEnabledAsync.valueOrNull ?? false;
    final isLoading = discoverEnabledAsync.isLoading;

    if (!isLoading && !isEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.library);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final search = ref.watch(libProviders.searchQueryProvider);
    final selectedCategory = ref.watch(libProviders.selectedCategoryProvider);
    final isFiltering = search.isNotEmpty || selectedCategory != null;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          ref.invalidate(libProviders.libraryPlansProvider);
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
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
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
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _DiscoverSearchBar(),
              ),
            ),
            const SliverToBoxAdapter(child: _DiscoverCategoryFilter()),
            SliverToBoxAdapter(
              child: OfflineBanner(
                message: isFiltering
                    ? 'You are offline — Discover requires internet'
                    : null,
                icon: isFiltering
                    ? Icons.wifi_off_outlined
                    : Icons.cloud_off_outlined,
              ),
            ),
            if (isFiltering)
              const _FilteredResults()
            else
              const _BentoSection(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bento section — categories grid + request CTA, shown when no filter is set.
// ─────────────────────────────────────────────────────────────────────────────

class _BentoSection extends ConsumerWidget {
  const _BentoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return const SliverFillRemaining(child: _EmptyState());
        }
        return SliverToBoxAdapter(
          child: Column(
            children: [
              _BentoCategoryGrid(
                key: ValueKey(categories.map((c) => c.slug).join(',')),
                categories: categories,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: _RequestPlanCard(),
              ),
              SizedBox(height: 80 + MediaQuery.paddingOf(context).bottom),
            ],
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filtered results — shown when search or category filter is active.
// Renders matching series (Programs) then matching library plans (Plans).
// ─────────────────────────────────────────────────────────────────────────────

class _FilteredResults extends ConsumerStatefulWidget {
  const _FilteredResults();

  @override
  ConsumerState<_FilteredResults> createState() => _FilteredResultsState();
}

class _FilteredResultsState extends ConsumerState<_FilteredResults> {
  final Set<String> _loadingPlanIds = {};

  List<Series> _filterSeries(
    List<Series> all,
    String search,
    String? categorySlug,
  ) {
    final q = search.toLowerCase();
    return all.where((s) {
      if (categorySlug != null && s.category != categorySlug) return false;
      if (q.isEmpty) return true;
      if (s.name.toLowerCase().contains(q)) return true;
      if (s.description?.toLowerCase().contains(q) == true) return true;
      if (s.tags.any((t) => t.toLowerCase().contains(q))) return true;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(libProviders.libraryPlansProvider);
    final allSeries = ref.watch(publishedSeriesProvider).valueOrNull ?? [];
    final search = ref.watch(libProviders.searchQueryProvider);
    final selectedCategory = ref.watch(libProviders.selectedCategoryProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 96;

    final matchingSeries = _filterSeries(allSeries, search, selectedCategory);
    final cardWidth = MediaQuery.sizeOf(context).width * 0.72;

    return plansAsync.when(
      data: (plans) {
        final hasPlans = plans.isNotEmpty;
        final hasSeries = matchingSeries.isNotEmpty;

        if (!hasPlans && !hasSeries) {
          return const SliverFillRemaining(child: _NoMatchesState());
        }

        return SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Programs section ───────────────────────────────────────
                if (hasSeries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      'PROGRAMS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.outline,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: matchingSeries.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        final s = matchingSeries[i];
                        return _SeriesResultCard(
                          series: s,
                          width: cardWidth,
                          onTap: () => context.push('/series/${s.id}'),
                        );
                      },
                    ),
                  ),
                ],

                // ── Plans section ──────────────────────────────────────────
                if (hasPlans) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, hasSeries ? 24 : 16, 20, 8),
                    child: Text(
                      'PLANS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.outline,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (final plan in plans)
                          Padding(
                            key: ValueKey(plan.id),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _LibraryPlanCard(
                              plan: plan,
                              isLoading: _loadingPlanIds.contains(plan.id),
                              onPlay: () => _playLibraryPlan(plan),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SliverFillRemaining(
        child: _ErrorState(
          message: error is PlanApiException
              ? error.userMessage
              : error.toString(),
          onRetry: () => ref.invalidate(libProviders.libraryPlansProvider),
        ),
      ),
    );
  }

  Future<void> _playLibraryPlan(LibraryPlanSummary summary) async {
    if (!ref.read(isAuthenticatedProvider)) {
      context.go(AppRoutes.login);
      return;
    }
    if (_loadingPlanIds.contains(summary.id)) return;

    setState(() => _loadingPlanIds.add(summary.id));

    try {
      final repo = ref.read(planRepositoryProvider);
      Plan? plan;
      try {
        final userPlans = await ref.read(planListProvider().future);
        for (final p in userPlans) {
          if (p.libraryId == summary.id) {
            plan = p;
            break;
          }
        }
      } catch (_) {}

      if (plan == null) {
        final apiService = ref.read(planApiServiceProvider);
        final fullPlan = await apiService.getLibraryPlanById(summary.id);
        final now = DateTime.now();
        final planToSave = fullPlan.copyWith(
          id: '',
          createdAt: now,
          updatedAt: now,
          lastUsedAt: null,
          isActive: false,
          ttsStatus: 'none',
          ttsTotal: 0,
          ttsCompleted: 0,
          libraryId: summary.id,
        );
        final newId = await repo.createPlan(planToSave);
        plan = await repo.getPlanById(newId);
      }

      if (!mounted) return;
      setState(() => _loadingPlanIds.remove(summary.id));

      if (plan == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load plan. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await _startPlanFlow(context, ref, plan);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPlanIds.remove(summary.id));
      final message = e is PlanApiException
          ? e.userMessage
          : 'Failed to play plan. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Series result card — horizontal-rail card shown in the Programs section.
// ─────────────────────────────────────────────────────────────────────────────

class _SeriesResultCard extends StatelessWidget {
  const _SeriesResultCard({
    required this.series,
    required this.width,
    required this.onTap,
  });

  final Series series;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final badgeColor = categoryBadgeColor(series.category, colorScheme);
    final badgeFg = categoryBadgeForeground(series.category, colorScheme);

    return Semantics(
      label: '${series.name}, ${planCategoryLabel(series.category)}, '
          '${series.totalSessions} sessions',
      button: true,
      child: SizedBox(
        width: width,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    badgeColor.withValues(alpha: 0.28),
                    colorScheme.surfaceContainerLow,
                  ),
                  colorScheme.surfaceContainerLow,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.08),
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            planCategoryIcon(series.category),
                            color: badgeFg,
                            size: 20,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            planCategoryLabel(series.category).toUpperCase(),
                            style: TextStyle(
                              color: badgeFg,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      series.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                    if (series.description != null &&
                        series.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        series.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 12, color: colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          '${series.totalSessions} day${series.totalSessions == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.outline,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right,
                            size: 16, color: colorScheme.outline),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _startPlanFlow(
  BuildContext context,
  WidgetRef ref,
  Plan plan,
) async {
  await startPlanWithGuard(
    context,
    ref,
    newPlan: plan,
    onStart: () async {
      final engine = ref.read(planExecutionEngineProvider);
      final recoverableStepIndex =
          await engine.getRecoverableStepIndexForPlan(plan.id);

      bool resumeSession = false;
      if (recoverableStepIndex != null) {
        if (!context.mounted) return;
        final choice = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            title: const Text('Continue where you left off?'),
            content: Text(
              'You paused at step ${recoverableStepIndex + 1}. '
              'Would you like to continue from there, or start over?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Start Over'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (choice == null) return;
        resumeSession = choice;
      }

      if (!context.mounted) return;

      final shouldStart = await showCountdownOverlay(context);
      if (shouldStart != true) return;
      if (!context.mounted) return;

      final repo = ref.read(planRepositoryProvider);
      await repo.updateLastUsed(plan.id);

      if (resumeSession) {
        final resumed = await engine.resumeFromPersistedState(plan.id);
        if (!resumed) {
          await engine.startPlan(plan);
        }
      } else {
        await engine.startPlan(plan);
      }

      if (!context.mounted) return;
      context.go(AppRoutes.nowPlaying);
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar + category chip filter
// ─────────────────────────────────────────────────────────────────────────────

class _DiscoverSearchBar extends ConsumerStatefulWidget {
  const _DiscoverSearchBar();

  @override
  ConsumerState<_DiscoverSearchBar> createState() => _DiscoverSearchBarState();
}

class _DiscoverSearchBarState extends ConsumerState<_DiscoverSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(libProviders.searchQueryProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(libProviders.searchQueryProvider);
    if (_controller.text != query) {
      _controller.value = _controller.value.copyWith(text: query);
    }

    return TextField(
      controller: _controller,
      onChanged: (value) =>
          ref.read(libProviders.searchQueryProvider.notifier).state = value,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search the library…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: query.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear search',
                onPressed: () {
                  _controller.clear();
                  ref
                      .read(libProviders.searchQueryProvider.notifier)
                      .state = '';
                },
              )
            : null,
      ),
    );
  }
}

class _DiscoverCategoryFilter extends ConsumerWidget {
  const _DiscoverCategoryFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStr = ref.watch(libProviders.selectedCategoryProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    return SizedBox(
      height: 56,
      child: Semantics(
        label: 'Category filter',
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _DiscoverChip(
                label: 'All',
                isSelected: selectedStr == null,
                colorScheme: colorScheme,
                onTap: () => ref
                    .read(libProviders.selectedCategoryProvider.notifier)
                    .state = null,
              ),
            ),
            ...categories.map((cat) {
              final isSelected = selectedStr == cat.slug;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _DiscoverChip(
                  label: cat.name,
                  isSelected: isSelected,
                  colorScheme: colorScheme,
                  onTap: () {
                    final notifier = ref
                        .read(libProviders.selectedCategoryProvider.notifier);
                    notifier.state = isSelected ? null : cat.slug;
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _DiscoverChip extends StatelessWidget {
  const _DiscoverChip({
    required this.label,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(9999),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Library plan card (shown in the search-results list)
// ─────────────────────────────────────────────────────────────────────────────

class _LibraryPlanCard extends ConsumerWidget {
  const _LibraryPlanCard({
    required this.plan,
    required this.isLoading,
    required this.onPlay,
  });

  final LibraryPlanSummary plan;
  final bool isLoading;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final badgeColor = categoryBadgeColor(plan.category, colorScheme);
    final badgeFg = categoryBadgeForeground(plan.category, colorScheme);

    return Semantics(
      label: '${plan.name}, ${planCategoryLabel(plan.category)}, '
          '${plan.stepCount} steps',
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: icon badge + favorite button + category tag ───────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    planCategoryIcon(plan.category),
                    color: badgeFg,
                    size: 22,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FavoriteButton(planId: plan.id),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        planCategoryLabel(plan.category).toUpperCase(),
                        style: TextStyle(
                          color: badgeFg,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              plan.name,
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            StarRatingWidget(planId: plan.id),
            if (plan.description != null && plan.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                plan.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: _PlayButton(
                isLoading: isLoading,
                planName: plan.name,
                onPlay: onPlay,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${formatPlanDuration(Duration(seconds: plan.totalDurationSeconds))} · ${plan.stepCount} STEP${plan.stepCount == 1 ? '' : 'S'}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colorScheme.outline,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.isLoading,
    required this.planName,
    required this.onPlay,
  });

  final bool isLoading;
  final String planName;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (isLoading) {
      return Semantics(
        label: 'Preparing $planName, please wait',
        child: FilledButton(
          onPressed: null,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Preparing…'),
            ],
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: 'Play $planName',
      child: FilledButton.icon(
        onPressed: onPlay,
        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
        icon: const Icon(Icons.play_arrow, size: 18),
        label: const Text('Play'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category bento grid (unchanged from prior implementation)
// ─────────────────────────────────────────────────────────────────────────────

class _BentoCategoryGrid extends StatefulWidget {
  const _BentoCategoryGrid({required this.categories, super.key});

  final List<Category> categories;

  @override
  State<_BentoCategoryGrid> createState() => _BentoCategoryGridState();
}

class _BentoCategoryGridState extends State<_BentoCategoryGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
        ? HSLColor.fromColor(bgColor)
            .withLightness(
              (HSLColor.fromColor(bgColor).lightness - 0.14).clamp(0.0, 1.0),
            )
            .toColor()
        : HSLColor.fromColor(bgColor)
            .withLightness(
              (HSLColor.fromColor(bgColor).lightness - 0.08).clamp(0.0, 1.0),
            )
            .toColor();

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
// Empty / error states
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
              'Check back soon — new content is on the way.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () => context.push(AppRoutes.planRequest),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Request a plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatchesState extends StatelessWidget {
  const _NoMatchesState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 56,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text('No plans found', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or clearing the category filter.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            Icon(Icons.cloud_off_outlined, size: 56, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              "Couldn't load",
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

// ─────────────────────────────────────────────────────────────────────────────
// Request-a-plan CTA
// ─────────────────────────────────────────────────────────────────────────────

class _RequestPlanCard extends StatelessWidget {
  const _RequestPlanCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.planRequest),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Can’t find what you need?',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Request a plan and we’ll build it for you.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
