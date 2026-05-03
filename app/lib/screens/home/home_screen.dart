import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:instructor/models/library_plan_summary.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/series.dart';
import 'package:instructor/models/series_subscription.dart';
import 'package:instructor/models/tts_status_info.dart';
import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/providers/home_providers.dart';
import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/providers/series_providers.dart';
import 'package:instructor/providers/tts_status_providers.dart';
import 'package:instructor/router.dart';
import 'package:instructor/screens/plan_editor/plan_editor_screen.dart';
import 'package:instructor/screens/plan_library/widgets/category_filter.dart';
import 'package:instructor/screens/plan_library/widgets/countdown_overlay.dart';
import 'package:instructor/screens/plan_library/widgets/plan_card.dart';
import 'package:instructor/services/audio_download_service.dart';
import 'package:instructor/services/plan_api_service.dart' show PlanApiException;
import 'package:instructor/services/series_api_service.dart' show SeriesApiException;
import 'package:instructor/services/plan_execution_engine.dart';
import 'package:instructor/theme/app_branding.dart';
import 'package:instructor/widgets/active_session_dialog.dart';
import 'package:instructor/widgets/offline_banner.dart';
import 'package:instructor/widgets/profile_avatar_button.dart';
import 'package:instructor/widgets/series_card.dart';

// Pushing /editor/:planId via context.push from inside StatefulShellRoute
// branch 0 into branch 1 trips the go_router 14 keyReservation regression
// (flutter/flutter#140586). Going through the root navigator preserves
// back-stack UX without crossing branches.
void _openPlanEditor(BuildContext context, {String? planId}) {
  Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      builder: (_) =>
          planId == null ? const PlanEditorScreen() : PlanEditorScreen(planId: planId),
    ),
  );
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

bool _isNetworkError(Object error) {
  if (error is SocketException) return true;
  if (error is PlanApiException) {
    final msg = error.message;
    return msg.contains('SocketException') ||
        msg.contains('ClientException') ||
        msg.contains('No address associated with hostname') ||
        msg.contains('Connection refused') ||
        msg.contains('Network is unreachable');
  }
  return false;
}

String _greetingForHour(int hour) {
  if (hour < 5) return 'Good evening';
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

String _greetingPunch(int hour) {
  if (hour < 5) return 'Late-night focus is yours.';
  if (hour < 12) return 'A fresh start awaits.';
  if (hour < 17) return 'Pick up where you left off.';
  if (hour < 21) return 'Wind down with intention.';
  return 'Time to recharge.';
}

/// Home screen — the user's personalised entry point.
///
/// Replaces the old tabbed Library + Discover surfaces with a single
/// vertical feed: greeting, resume-in-progress, programs, recently
/// played, recommendations, and the user's own plans.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isAuthenticatedProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final hasActiveFilter =
        searchQuery.isNotEmpty || selectedCategory != null;

    final plansAsync = ref.watch(
      planListProvider(
        searchQuery: searchQuery.isEmpty ? null : searchQuery,
        category: selectedCategory,
      ),
    );

    Future<void> handleRefresh() async {
      try {
        await ref.read(planRepositoryProvider).refreshFromServer();
        ref.invalidate(featuredLibraryPlansProvider);
      } catch (e) {
        if (!context.mounted) return;
        final message = _isNetworkError(e)
            ? 'No internet connection — showing cached plans'
            : 'Could not refresh';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBranding.brandedAppBar(
        actions: [
          ProfileAvatarButton(
            onTap: () => context.go(AppRoutes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _GreetingHeader()),
            const SliverToBoxAdapter(
              child: OfflineBanner(),
            ),
            if (isLoggedIn && !hasActiveFilter)
              const SliverToBoxAdapter(child: _ContinueProgramCard()),
            if (!hasActiveFilter)
              const SliverToBoxAdapter(child: _QuickActionsRow()),
            if (isLoggedIn && !hasActiveFilter)
              const SliverToBoxAdapter(child: _MyProgramsRail()),
            if (!hasActiveFilter)
              const SliverToBoxAdapter(child: _ProgramsRail()),
            if (!hasActiveFilter)
              const SliverToBoxAdapter(child: _ForYouRail()),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: _MyPlansSectionHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: _SearchBar(),
              ),
            ),
            const SliverToBoxAdapter(child: CategoryFilter()),
            plansAsync.when(
              data: (plans) => _PlanList(
                plans: plans,
                isAuthenticated: isLoggedIn,
                hasActiveFilter: hasActiveFilter,
              ),
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(planListProvider),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isLoggedIn
          ? _GradientFab(onPressed: () => _openPlanEditor(context))
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Greeting header
// ─────────────────────────────────────────────────────────────────────────────

class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final hour = DateTime.now().hour;
    final greeting = _greetingForHour(hour);
    final punch = _greetingPunch(hour);

    final firstName = () {
      final name = user?.name?.trim();
      if (name != null && name.isNotEmpty) {
        return name.split(' ').first;
      }
      final username = user?.username;
      if (username != null && username.isNotEmpty) return username;
      return null;
    }();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstName == null ? '$greeting!' : '$greeting, $firstName',
            style: GoogleFonts.manrope(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            punch,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyPlansSectionHeader extends StatelessWidget {
  const _MyPlansSectionHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          'My Plans',
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick actions strip — Discover, Request, Create
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionsRow extends ConsumerWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _QuickAction(
              icon: Icons.explore_outlined,
              label: 'Discover',
              colorScheme: colorScheme,
              onTap: () => context.go(AppRoutes.discover),
            ),
            const SizedBox(width: 10),
            _QuickAction(
              icon: Icons.lightbulb_outline,
              label: 'Request',
              colorScheme: colorScheme,
              onTap: () => context.push(AppRoutes.planRequest),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.colorScheme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onPrimaryContainer,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Continue your program card — most-recent active subscription.
// ─────────────────────────────────────────────────────────────────────────────

class _ContinueProgramCard extends ConsumerWidget {
  const _ContinueProgramCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSubsAsync =
        ref.watch(mySubscriptionsProvider(activeOnly: true));
    final colorScheme = Theme.of(context).colorScheme;

    return activeSubsAsync.maybeWhen(
      data: (subs) {
        if (subs.isEmpty) return const SizedBox.shrink();
        final sub = subs.first;
        final seriesAsync = ref.watch(seriesByIdProvider(sub.seriesId));
        return seriesAsync.maybeWhen(
          data: (series) {
            final next = (sub.currentSessionIndex + 1).clamp(
              1,
              series.totalSessions == 0 ? 1 : series.totalSessions,
            );
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Material(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/series/${series.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CONTINUE',
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                series.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Day $next of ${series.totalSessions}',
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.85),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: colorScheme.onPrimaryContainer),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MY PROGRAMS rail — series the user has subscribed to.
// ─────────────────────────────────────────────────────────────────────────────

class _MyProgramsRail extends ConsumerWidget {
  const _MyProgramsRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = ref.watch(mySubscriptionsProvider()).valueOrNull ??
        const <SeriesSubscription>[];
    final allSeries =
        ref.watch(publishedSeriesProvider).valueOrNull ?? const <Series>[];

    final activeSubs = subs
        .where((s) => s.status != SeriesSubscriptionStatus.cancelled)
        .toList();

    if (activeSubs.isEmpty) return const SizedBox.shrink();

    final seriesById = {for (final s in allSeries) s.id: s};
    final pairs = <({Series series, SeriesSubscription sub})>[];
    for (final sub in activeSubs) {
      final s = seriesById[sub.seriesId];
      if (s != null) pairs.add((series: s, sub: sub));
    }

    if (pairs.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final railHeight = 200 + (textScaler.scale(60) - 60).clamp(0.0, 60.0);
    final cardWidth = MediaQuery.sizeOf(context).width - 60;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'MY PROGRAMS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colorScheme.outline,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            height: railHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: pairs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final item = pairs[i];
                return SeriesCard(
                  series: item.series,
                  subscription: item.sub,
                  width: cardWidth,
                  onTap: () => context.push('/series/${item.series.id}'),
                  onRemove: () => _confirmRemove(context, ref, item.series.id, item.series.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    String seriesId,
    String seriesName,
  ) async {
    if (!context.mounted) return;
    try {
      await ref.read(seriesApiServiceProvider).unsubscribe(seriesId);
      ref.invalidate(mySubscriptionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$seriesName" removed from My Programs'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on SeriesApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.userMessage), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRAMS rail — curated catalog series.
// ─────────────────────────────────────────────────────────────────────────────

class _ProgramsRail extends ConsumerWidget {
  const _ProgramsRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesAsync = ref.watch(publishedSeriesProvider);
    final subsAsync = ref.watch(mySubscriptionsProvider());
    final colorScheme = Theme.of(context).colorScheme;

    final textScaler = MediaQuery.textScalerOf(context);
    final railHeight = 200 + (textScaler.scale(60) - 60).clamp(0.0, 60.0);
    final cardWidth = MediaQuery.sizeOf(context).width - 60;

    return seriesAsync.maybeWhen(
      data: (seriesList) {
        if (seriesList.isEmpty) return const SizedBox.shrink();
        final subs = subsAsync.valueOrNull ?? const <SeriesSubscription>[];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
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
                height: railHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: seriesList.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final s = seriesList[i];
                    final sub = _findSubscription(subs, s);
                    return SeriesCard(
                      series: s,
                      subscription: sub,
                      width: cardWidth,
                      onTap: () => context.push('/series/${s.id}'),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  SeriesSubscription? _findSubscription(
      List<SeriesSubscription> subs, Series series) {
    for (final s in subs) {
      if (s.seriesId == series.id) return s;
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOR YOU rail — curated library plans.
// ─────────────────────────────────────────────────────────────────────────────

class _ForYouRail extends ConsumerWidget {
  const _ForYouRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredAsync = ref.watch(featuredLibraryPlansProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final cardWidth = MediaQuery.sizeOf(context).width * 0.66;

    return featuredAsync.maybeWhen(
      data: (plans) {
        if (plans.isEmpty) return const SizedBox.shrink();
        // Cap at 6 to keep the rail tight; tapping "See all" goes to Discover.
        final featured = plans.take(6).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'FOR YOU',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.outline,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.discover),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: featured.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _FeaturedLibraryCard(
                    plan: featured[i],
                    width: cardWidth,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _FeaturedLibraryCard extends ConsumerStatefulWidget {
  const _FeaturedLibraryCard({required this.plan, required this.width});

  final LibraryPlanSummary plan;
  final double width;

  @override
  ConsumerState<_FeaturedLibraryCard> createState() =>
      _FeaturedLibraryCardState();
}

class _FeaturedLibraryCardState extends ConsumerState<_FeaturedLibraryCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final plan = widget.plan;
    final badgeColor = categoryBadgeColor(plan.category, colorScheme);
    final badgeFg = categoryBadgeForeground(plan.category, colorScheme);

    return Semantics(
      label: '${plan.name}, ${planCategoryLabel(plan.category)}, '
          '${plan.stepCount} steps',
      button: true,
      child: SizedBox(
        width: widget.width,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    badgeColor.withValues(alpha: 0.32),
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
              onTap: _loading ? null : _play,
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
                            planCategoryIcon(plan.category),
                            color: badgeFg,
                            size: 22,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          planCategoryLabel(plan.category).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.outline,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      plan.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 12, color: colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          formatPlanDuration(
                              Duration(seconds: plan.totalDurationSeconds)),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.outline,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: colorScheme.outline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${plan.stepCount} step${plan.stepCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.outline,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: _loading
                              ? Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                )
                              : Icon(
                                  Icons.play_arrow,
                                  color: colorScheme.onPrimaryContainer,
                                  size: 18,
                                ),
                        ),
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

  Future<void> _play() async {
    final summary = widget.plan;
    if (!ref.read(isAuthenticatedProvider)) {
      context.go(AppRoutes.login);
      return;
    }

    setState(() => _loading = true);
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
      setState(() => _loading = false);

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
      setState(() => _loading = false);
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
// TTS auto-download — kicks off a download when generation completes.
// ─────────────────────────────────────────────────────────────────────────────

class _TtsAutoDownloadEffect extends ConsumerStatefulWidget {
  const _TtsAutoDownloadEffect({required this.planId, super.key});

  final String planId;

  @override
  ConsumerState<_TtsAutoDownloadEffect> createState() =>
      _TtsAutoDownloadEffectState();
}

class _TtsAutoDownloadEffectState
    extends ConsumerState<_TtsAutoDownloadEffect> {
  bool _downloadTriggered = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<TtsStatusInfo>>(
      planTtsStatusProvider(widget.planId),
      (_, next) {
        if (_downloadTriggered) return;
        next.whenData((status) {
          if (status.status == 'completed' || status.status == 'partial') {
            _downloadTriggered = true;
            _triggerDownload();
          }
        });
      },
    );
    return const SizedBox.shrink();
  }

  Future<void> _triggerDownload() async {
    final planId = widget.planId;
    debugPrint('_TtsAutoDownloadEffect[$planId]: starting audio download');
    try {
      final service = ref.read(audioDownloadServiceProvider);
      await service.downloadPlanAudio(planId);
      if (mounted) {
        ref.invalidate(isFullyDownloadedProvider(planId));
      }
      debugPrint(
          '_TtsAutoDownloadEffect[$planId]: audio download complete');
    } catch (e) {
      debugPrint(
          '_TtsAutoDownloadEffect[$planId]: audio download failed — $e');
      if (mounted) {
        setState(() => _downloadTriggered = false);
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan list — the user's personal plans.
// ─────────────────────────────────────────────────────────────────────────────

class _PlanList extends ConsumerWidget {
  const _PlanList({
    required this.plans,
    required this.isAuthenticated,
    required this.hasActiveFilter,
  });

  final List<Plan> plans;
  final bool isAuthenticated;
  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomNavInset = MediaQuery.of(context).padding.bottom + 96;

    if (plans.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    Widget buildPlanCard(Plan plan) {
      final isLibraryClone = plan.libraryId != null;
      return Column(
        key: ValueKey(plan.id),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (plan.isActive ||
              (plan.ttsStatus == 'completed' || plan.ttsStatus == 'partial'))
            _TtsAutoDownloadEffect(
              key: ValueKey('tts-effect-${plan.id}'),
              planId: plan.id,
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PlanCard(
              plan: plan,
              onTap: isLibraryClone
                  ? () => _onPlanTap(context, ref, plan)
                  : () => _openPlanEditor(context, planId: plan.id),
              onPlay: () => _onPlanTap(context, ref, plan),
              onPlayWithAiVoice: () {
                ref.read(ttsPlaybackModeProvider.notifier).state =
                    TtsPlaybackMode.genai;
                _onPlanTap(context, ref, plan);
              },
              onEdit: isAuthenticated && !isLibraryClone
                  ? () => _openPlanEditor(context, planId: plan.id)
                  : null,
              onDuplicate: isAuthenticated
                  ? () => _duplicatePlan(context, ref, plan)
                  : null,
              onDelete: isAuthenticated
                  ? () => _confirmDelete(context, ref, plan)
                  : null,
            ),
          ),
        ],
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomNavInset),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => buildPlanCard(plans[index]),
          childCount: plans.length,
        ),
      ),
    );
  }

  Future<void> _onPlanTap(
    BuildContext context,
    WidgetRef ref,
    Plan plan,
  ) =>
      _startPlanFlow(context, ref, plan);

  Future<void> _duplicatePlan(
    BuildContext context,
    WidgetRef ref,
    Plan plan,
  ) async {
    final repo = ref.read(planRepositoryProvider);
    final now = DateTime.now();
    final copy = plan.copyWith(
      id: '',
      name: '${plan.name} (copy)',
      createdAt: now,
      updatedAt: now,
      lastUsedAt: null,
      isActive: false,
      ttsStatus: 'none',
      ttsTotal: 0,
      ttsCompleted: 0,
      libraryId: null,
    );
    await repo.createPlan(copy);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${plan.name}" duplicated'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Plan plan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Plan'),
        content:
            Text('Delete "${plan.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    await ref.read(planRepositoryProvider).deletePlan(plan.id);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${plan.name}" deleted'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(searchQueryProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    if (_controller.text != query) {
      _controller.value = _controller.value.copyWith(text: query);
    }

    return TextField(
      controller: _controller,
      onChanged: (value) =>
          ref.read(searchQueryProvider.notifier).state = value,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search your routines...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: query.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear search',
                onPressed: () {
                  _controller.clear();
                  ref.read(searchQueryProvider.notifier).state = '';
                },
              )
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / error states
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text('Could not load plans', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient FAB
// ─────────────────────────────────────────────────────────────────────────────

class _GradientFab extends StatelessWidget {
  const _GradientFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'New Plan',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          splashColor: colorScheme.primary.withValues(alpha: 0.2),
          child: Ink(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorScheme.primary, colorScheme.primaryContainer],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
