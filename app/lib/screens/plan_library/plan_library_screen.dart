import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart' show debugPrint;
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
import 'package:instructor/providers/library_providers.dart' as libProviders;
import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/providers/series_providers.dart';
import 'package:instructor/providers/categories_providers.dart';
import 'package:instructor/providers/settings_providers.dart';
import 'package:instructor/providers/tts_status_providers.dart';
import 'package:instructor/repositories/plan_repository.dart';
import 'package:instructor/router.dart';
import 'package:instructor/screens/plan_editor/plan_editor_screen.dart';
import 'package:instructor/services/audio_download_service.dart';
import 'package:instructor/services/plan_api_service.dart' show PlanApiException;
import 'package:instructor/services/plan_execution_engine.dart';
import 'package:instructor/theme/app_branding.dart';
import 'package:instructor/widgets/active_session_dialog.dart';
import 'package:instructor/widgets/offline_banner.dart';
import 'package:instructor/widgets/profile_avatar_button.dart';
import 'package:instructor/widgets/series_card.dart';

import 'widgets/category_filter.dart';
import 'widgets/countdown_overlay.dart';
import 'widgets/plan_card.dart';

// Pushing /editor/:planId via context.push from this screen (which lives
// inside StatefulShellRoute branch 0) into branch 1 triggers the go_router 14
// keyReservation regression — see flutter/flutter#140586. Pushing a
// MaterialPageRoute on the root navigator bypasses go_router's cross-branch
// push path while preserving back-stack UX.
void _openPlanEditor(BuildContext context, {String? planId}) {
  Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      builder: (_) =>
          planId == null ? const PlanEditorScreen() : PlanEditorScreen(planId: planId),
    ),
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Local Riverpod state providers
// ────────────────────────────────────────────────────────────────────────────

/// Holds the current search query string entered in the library search bar.
///
/// Updated on every keystroke; passed to [planListProvider] for SQLite-side
/// filtering.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Holds the active [PlanCategory] filter, or null when "All" is selected.
///
/// Passed to [planListProvider] for SQLite-side filtering.
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// ────────────────────────────────────────────────────────────────────────────
// Network-error detection helper
// ────────────────────────────────────────────────────────────────────────────

/// Returns `true` if [error] represents a network connectivity failure that
/// should be communicated to the user as "No internet connection".
///
/// Covers:
/// - Raw [SocketException] from `dart:io` (direct socket failures).
/// - [PlanApiException] whose [PlanApiException.message] contains a
///   [SocketException] string (the API layer wraps socket errors this way).
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

// ────────────────────────────────────────────────────────────────────────────
// PlanLibraryScreen
// ────────────────────────────────────────────────────────────────────────────

/// Home screen — displays the user's Plan library with search, category
/// filtering, and one-tap-to-start.
///
/// ## Layout (top → bottom)
/// 1. [AppBar] with gradient "Instructor" title, settings icon, and a
///    [TabBar] with two tabs: "My Plans" (index 0) and "Discover" (index 1).
/// 2. [TabBarView] with two tab bodies:
///    - Tab 0 (My Plans): Search bar, [CategoryFilter], list of [PlanCard]s,
///      and a gradient FAB for creating new plans.
///    - Tab 1 (Discover): Empty placeholder — content added by a later task.
///
/// Tab selection state is persisted via [libraryTabIndexProvider] so other
/// widgets can read or change the active tab programmatically.
class PlanLibraryScreen extends ConsumerStatefulWidget {
  const PlanLibraryScreen({super.key});

  @override
  ConsumerState<PlanLibraryScreen> createState() => _PlanLibraryScreenState();
}

class _PlanLibraryScreenState extends ConsumerState<PlanLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Initialise at the provider's current value (default 0 = My Plans).
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: ref.read(libProviders.libraryTabIndexProvider),
    );
    _tabController.addListener(_onTabChanged);
    // Fetch fresh data for the initially-visible tab.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCurrentTab());
  }

  /// Propagates controller changes → provider so all widgets stay in sync.
  /// Also triggers a background refresh whenever the user switches tabs.
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      ref.read(libProviders.libraryTabIndexProvider.notifier).state =
          _tabController.index;
      _refreshCurrentTab();
    }
  }

  /// Refreshes data for the currently visible tab.
  ///
  /// - My Plans (0): calls [PlanRepository.refreshFromServer] silently so the
  ///   Drift stream picks up any server-side changes without a pull-to-refresh.
  /// - Discover (1): invalidates [libraryPlansProvider] to re-fetch the list.
  ///
  /// Errors are swallowed — the user can still pull-to-refresh manually.
  Future<void> _refreshCurrentTab() async {
    if (!mounted) return;
    switch (_tabController.index) {
      case 0:
        try {
          await ref.read(planRepositoryProvider).refreshFromServer();
        } catch (_) {
          // Silent — pull-to-refresh remains available.
        }
      case 1:
        ref.invalidate(libProviders.libraryPlansProvider);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = ref.watch(libProviders.libraryTabIndexProvider);
    final isLoggedIn = ref.watch(isAuthenticatedProvider);

    // Propagates provider changes → controller (e.g. "View" snackbar action or
    // external deep-link). Uses ref.listen so animateTo runs post-build and
    // never triggers a "setState during build" assertion.
    ref.listen<int>(libProviders.libraryTabIndexProvider, (_, newIndex) {
      if (_tabController.index != newIndex && !_tabController.indexIsChanging) {
        _tabController.animateTo(newIndex);
      }
    });

    return Scaffold(
      appBar: AppBranding.brandedAppBar(
        actions: [
          ProfileAvatarButton(
            onTap: () => context.go(AppRoutes.settings),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Plans'),
            Tab(text: 'Discover'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MyPlansTab(),
          _DiscoverTab(),
        ],
      ),

      // FAB only shown on the My Plans tab for authenticated users.
      floatingActionButton: tabIndex == 0 && isLoggedIn
          ? _GradientFab(
              onPressed: () => _openPlanEditor(context),
            )
          : null,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// _MyPlansTab  (index 0)
// ────────────────────────────────────────────────────────────────────────────

/// The "My Plans" tab body.
///
/// Contains:
/// - A "Plan Library" heading
/// - A real-time search bar ([_SearchBar])
/// - A horizontal category filter row ([CategoryFilter])
/// - A scrollable list of [PlanCard] widgets driven by [planListProvider]
class _MyPlansTab extends ConsumerWidget {
  const _MyPlansTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isLoggedIn = ref.watch(isAuthenticatedProvider);

    final plansAsync = ref.watch(
      planListProvider(
        searchQuery: searchQuery.isEmpty ? null : searchQuery,
        category: selectedCategory,
      ),
    );

    // Programs rail renders only when published series exist; mirror that
    // condition here so the empty state below can adapt its layout.
    final hasProgramsRail = ref
            .watch(publishedSeriesProvider)
            .valueOrNull
            ?.isNotEmpty ??
        false;

    final colorScheme = Theme.of(context).colorScheme;

    Future<void> handleRefresh() async {
      final repo = ref.read(planRepositoryProvider);
      try {
        await repo.refreshFromServer();
      } catch (e) {
        if (!context.mounted) return;
        final message = _isNetworkError(e)
            ? 'No internet connection — showing cached plans'
            : 'Could not refresh plans';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    return RefreshIndicator(
      onRefresh: handleRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
        // ── "Plan Library" heading ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Text(
              'Plan Library',
              style: GoogleFonts.manrope(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),

        // ── Search bar ─────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: _SearchBar(),
          ),
        ),

        // ── Category filter chips ──────────────────────────────────────────
        const SliverToBoxAdapter(child: CategoryFilter()),

        // ── Offline banner (auto-hides when connectivity is restored) ──────
        const SliverToBoxAdapter(
          child: OfflineBanner(tab: LibraryTab.myPlans),
        ),

        // ── Continue your program (only when an active subscription exists) ─
        if (isLoggedIn)
          const SliverToBoxAdapter(child: _ContinueProgramCard()),

        // ── My Programs — subscribed series (active, paused, completed) ────
        if (isLoggedIn)
          const SliverToBoxAdapter(child: _MyProgramsRail()),

        // ── Programs rail — horizontal carousel of curated series ──────────
        const SliverToBoxAdapter(child: _ProgramsRail()),

        // ── Plan list ─────────────────────────────────────────────────────
        plansAsync.when(
          data: (plans) => _PlanList(
            plans: plans,
            isAuthenticated: isLoggedIn,
            hasActiveFilter:
                searchQuery.isNotEmpty || selectedCategory != null,
            hasContentAbove: hasProgramsRail,
            onGoToDiscover: () => ref
                .read(libProviders.libraryTabIndexProvider.notifier)
                .state = 1,
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
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// _DiscoverTab  (index 1)
// ────────────────────────────────────────────────────────────────────────────

/// The "Discover" tab body.
///
/// Displays a paginated list of [LibraryPlanSummary] items fetched from
/// [libProviders.libraryPlansProvider], with:
/// - A search bar that updates [libProviders.searchQueryProvider]
/// - A category chip row that updates [libProviders.selectedCategoryProvider]
/// - An "Add to My Plans" button on each card with loading and already-added
///   states
/// - An offline banner when the device has no connectivity
/// - Navigation back to My Plans tab on successful add
class _DiscoverTab extends ConsumerStatefulWidget {
  const _DiscoverTab();

  @override
  ConsumerState<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<_DiscoverTab> {
  /// IDs of library plans currently being fetched+saved (shows spinner).
  final Set<String> _loadingPlanIds = {};

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(libProviders.libraryPlansProvider);
    // Derive which library plans have already been added from the reactive
    // user plan stream. This persists across navigation and app restarts.
    final userPlansAsync = ref.watch(planListProvider());
    final addedLibraryIds = userPlansAsync.valueOrNull
            ?.where((p) => p.libraryId != null)
            .map((p) => p.libraryId!)
            .toSet() ??
        {};
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── "Discover" heading ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Text(
            'Discover',
            style: GoogleFonts.manrope(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: colorScheme.onSurface,
            ),
          ),
        ),

        // ── Search bar ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
          child: _DiscoverSearchBar(),
        ),

        // ── Category filter chips ─────────────────────────────────────────
        const _DiscoverCategoryFilter(),

        // ── Offline banner (auto-hides when connectivity is restored) ─────
        const OfflineBanner(tab: LibraryTab.discover),

        // ── Library plan list ─────────────────────────────────────────────
        Expanded(
          child: plansAsync.when(
            data: (plans) => _buildPlanList(context, plans, addedLibraryIds),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(
              message: error is PlanApiException
                  ? error.userMessage
                  : error.toString(),
              onRetry: () =>
                  ref.invalidate(libProviders.libraryPlansProvider),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanList(
    BuildContext context,
    List<LibraryPlanSummary> plans,
    Set<String> addedLibraryIds,
  ) {
    if (plans.isEmpty) {
      return const _DiscoverEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        return Padding(
          key: ValueKey(plan.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: _LibraryPlanCard(
            plan: plan,
            isAdded: addedLibraryIds.contains(plan.id),
            isLoading: _loadingPlanIds.contains(plan.id),
            onAdd: () => _addToMyPlans(context, plan),
          ),
        );
      },
    );
  }

  // ── "Add to My Plans" handler ─────────────────────────────────────────────

  Future<void> _addToMyPlans(
    BuildContext context,
    LibraryPlanSummary summary,
  ) async {
    // Guard: redirect to login if not authenticated.
    if (!ref.read(isAuthenticatedProvider)) {
      context.go(AppRoutes.login);
      return;
    }

    // Guard: no-op if already in-flight (isAdded is handled by the button state).
    if (_loadingPlanIds.contains(summary.id)) {
      return;
    }

    setState(() => _loadingPlanIds.add(summary.id));

    try {
      final apiService = ref.read(planApiServiceProvider);
      final repo = ref.read(planRepositoryProvider);

      // Fetch the full plan (with steps) from the library.
      final fullPlan = await apiService.getLibraryPlanById(summary.id);

      // Strip server-managed fields so createPlan assigns a fresh server UUID.
      // Set libraryId so the plan is recognised as a Discover clone, preventing
      // duplicate additions across sessions.
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
      await repo.createPlan(planToSave);

      if (!mounted) return;

      setState(() => _loadingPlanIds.remove(summary.id));
      // addedLibraryIds is derived from planListProvider, which will update
      // automatically via the Drift stream — no manual setState needed.

      // Show a success snackbar with a "View" action.
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('"${summary.name}" added to My Plans'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              messenger.hideCurrentSnackBar();
              ref
                  .read(libProviders.libraryTabIndexProvider.notifier)
                  .state = 0;
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPlanIds.remove(summary.id));

      final message = e is PlanApiException
          ? e.userMessage
          : 'Failed to add plan. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// _DiscoverSearchBar
// ────────────────────────────────────────────────────────────────────────────

/// Search field for the Discover tab.
///
/// Writes to [libProviders.searchQueryProvider] on every keystroke, which
/// causes [libProviders.libraryPlansProvider] to re-fetch with the new query.
class _DiscoverSearchBar extends ConsumerStatefulWidget {
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

    // Sync controller text if the provider was reset externally.
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
                  ref.read(libProviders.searchQueryProvider.notifier).state =
                      '';
                },
              )
            : null,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// _DiscoverCategoryFilter
// ────────────────────────────────────────────────────────────────────────────

/// Horizontal scrollable row of category chips for the Discover tab.
///
/// Reads and writes [libProviders.selectedCategoryProvider] (a `String?` whose
/// value is the [PlanCategory.name] string, e.g. `'yoga'`). The chips use the
/// same visual design as [CategoryFilter] in the My Plans tab.
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // "All" chip — clears the category filter.
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _DiscoverChip(
                label: 'All',
                isSelected: selectedStr == null,
                colorScheme: colorScheme,
                onTap: () =>
                    ref.read(libProviders.selectedCategoryProvider.notifier)
                        .state = null,
              ),
            ),
            // One chip per category from categoriesProvider.
            ...categories.map((cat) {
              final isSelected = selectedStr == cat.slug;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _DiscoverChip(
                  label: cat.name,
                  isSelected: isSelected,
                  colorScheme: colorScheme,
                  onTap: () {
                    final notifier = ref.read(
                      libProviders.selectedCategoryProvider.notifier,
                    );
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

/// A single filter chip for [_DiscoverCategoryFilter].
///
/// Visually identical to [_StitchChip] in [CategoryFilter].
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
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// _LibraryPlanCard
// ────────────────────────────────────────────────────────────────────────────

/// Displays a [LibraryPlanSummary] in the Discover tab list.
///
/// Shows category icon, name, description, step count, and an "Add to My Plans"
/// button whose state transitions through default → loading → added.
class _LibraryPlanCard extends StatelessWidget {
  const _LibraryPlanCard({
    super.key,
    required this.plan,
    required this.isAdded,
    required this.isLoading,
    required this.onAdd,
  });

  final LibraryPlanSummary plan;
  final bool isAdded;
  final bool isLoading;

  /// Called when the "Add to My Plans" button is tapped in the default state.
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: icon badge + category tag ────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 48×48 icon badge.
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    planCategoryIcon(plan.category),
                    color: badgeFg,
                    size: 24,
                  ),
                ),
                // Category tag pill.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
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

            const SizedBox(height: 16),

            // ── Title ──────────────────────────────────────────────────────
            Text(
              plan.name,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Description ───────────────────────────────────────────────
            if (plan.description != null &&
                plan.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                plan.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 16),

            // ── "Add to My Plans" button ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: _AddToMyPlansButton(
                isAdded: isAdded,
                isLoading: isLoading,
                planName: plan.name,
                onAdd: onAdd,
              ),
            ),

            const SizedBox(height: 16),

            // ── Bottom row: duration · step count ─────────────────────────
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

// ────────────────────────────────────────────────────────────────────────────
// _AddToMyPlansButton
// ────────────────────────────────────────────────────────────────────────────

/// The "Add to My Plans" button rendered inside [_LibraryPlanCard].
///
/// Transitions between three visual states:
/// - **Default**: tappable "Add to My Plans" button.
/// - **Loading**: disabled button with a [CircularProgressIndicator].
/// - **Added**: disabled button with a check icon and "Added to My Plans" label.
class _AddToMyPlansButton extends StatelessWidget {
  const _AddToMyPlansButton({
    required this.isAdded,
    required this.isLoading,
    required this.planName,
    required this.onAdd,
  });

  final bool isAdded;
  final bool isLoading;
  final String planName;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // ── Already-added state ──────────────────────────────────────────────
    if (isAdded) {
      return Semantics(
        label: '$planName already added to My Plans',
        child: FilledButton.tonal(
          onPressed: null, // disabled — already added
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            backgroundColor:
                colorScheme.secondaryContainer.withValues(alpha: 0.7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 16,
                color: colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                'Added to My Plans',
                style:
                    TextStyle(color: colorScheme.onSecondaryContainer),
              ),
            ],
          ),
        ),
      );
    }

    // ── Loading state ────────────────────────────────────────────────────
    if (isLoading) {
      return Semantics(
        label: 'Adding $planName to My Plans, please wait',
        child: FilledButton.tonal(
          onPressed: null, // disabled while loading
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Adding…'),
            ],
          ),
        ),
      );
    }

    // ── Default (tappable) state ─────────────────────────────────────────
    return Semantics(
      button: true,
      label: 'Add $planName to My Plans',
      child: FilledButton.tonal(
        onPressed: onAdd,
        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16),
            SizedBox(width: 6),
            Text('Add to My Plans'),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// _DiscoverEmptyState
// ────────────────────────────────────────────────────────────────────────────

/// Shown when [libraryPlansProvider] returns an empty list (no matching plans).
class _DiscoverEmptyState extends StatelessWidget {
  const _DiscoverEmptyState();

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
              Icons.explore_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No plans found',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or\nclear the category filter.',
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

// ────────────────────────────────────────────────────────────────────────────
// _TtsAutoDownloadEffect
// ────────────────────────────────────────────────────────────────────────────

/// A zero-size side-effect widget that auto-triggers audio download when TTS
/// generation for [planId] reaches a terminal state.
///
/// ## Lifecycle
/// 1. Rendered in [_PlanList] for every plan where `plan.isActive == true`.
/// 2. Subscribes to [planTtsStatusProvider] (an adaptive-backoff polling
///    StreamProvider) via [ref.listen].
/// 3. When the stream emits a status of `'completed'` or `'partial'`,
///    calls [AudioDownloadService.downloadPlanAudio] once.
/// 4. On success, [invalidate]s [isFullyDownloadedProvider] so any listening
///    UI (e.g. a "Ready" indicator) is immediately refreshed.
///
/// ## Idempotency
/// - A `_downloadTriggered` flag prevents re-triggering during the current
///   widget's lifetime. If the widget is disposed and recreated (e.g. on
///   navigation or list refresh), a fresh attempt is made — but
///   [AudioDownloadService.downloadPlanAudio] skips already-cached files, so
///   repeated calls are always safe.
/// - On download failure the flag is reset so the next terminal-status event
///   can retry (relevant if the widget re-subscribes after a rebuild).
///
/// ## Rendering
/// Returns [SizedBox.shrink] — this widget occupies no visible space.
class _TtsAutoDownloadEffect extends ConsumerStatefulWidget {
  const _TtsAutoDownloadEffect({required this.planId, super.key});

  /// The plan ID whose TTS status is being watched.
  final String planId;

  @override
  ConsumerState<_TtsAutoDownloadEffect> createState() =>
      _TtsAutoDownloadEffectState();
}

class _TtsAutoDownloadEffectState
    extends ConsumerState<_TtsAutoDownloadEffect> {
  /// Set to `true` once [_triggerDownload] has been called to prevent
  /// duplicate concurrent downloads within the same widget instance.
  bool _downloadTriggered = false;

  @override
  Widget build(BuildContext context) {
    // Listen for terminal TTS status events.
    // ref.listen is idempotent across rebuilds — Riverpod replaces the
    // previous listener with this one on every build call.
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

    // Zero-size widget — all work is done in the listener above.
    return const SizedBox.shrink();
  }

  /// Calls [AudioDownloadService.downloadPlanAudio] and invalidates
  /// [isFullyDownloadedProvider] on success.
  ///
  /// On failure, resets [_downloadTriggered] so the next terminal-status
  /// event (if any) can retry.
  Future<void> _triggerDownload() async {
    final planId = widget.planId;
    debugPrint('_TtsAutoDownloadEffect[$planId]: starting audio download');
    try {
      final service = ref.read(audioDownloadServiceProvider);
      await service.downloadPlanAudio(planId);

      // Refresh the isFullyDownloaded cache so UI reflects new download state.
      if (mounted) {
        ref.invalidate(isFullyDownloadedProvider(planId));
      }
      debugPrint(
          '_TtsAutoDownloadEffect[$planId]: audio download complete');
    } catch (e) {
      debugPrint(
          '_TtsAutoDownloadEffect[$planId]: audio download failed — $e');
      // Reset so the effect can retry if the widget is still mounted.
      if (mounted) {
        setState(() => _downloadTriggered = false);
      }
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// _PlanList
// ────────────────────────────────────────────────────────────────────────────

class _PlanList extends ConsumerWidget {
  const _PlanList({
    required this.plans,
    required this.isAuthenticated,
    required this.hasActiveFilter,
    required this.hasContentAbove,
    required this.onGoToDiscover,
  });

  final List<Plan> plans;
  final bool isAuthenticated;
  final bool hasActiveFilter;

  /// True when the programs rail (or other section) renders above the plan
  /// list. Used by the empty state to switch from a full-screen centered
  /// layout to a compact inline layout that sits flush below the rail.
  final bool hasContentAbove;

  /// Switches to the Discover tab. Passed to [_EmptyState] when there are no
  /// plans and no active filter so the user can browse public plans.
  final VoidCallback onGoToDiscover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (plans.isEmpty) {
      final emptyState = _EmptyState(
        isFiltered: hasActiveFilter,
        onGoToDiscover: hasActiveFilter ? null : onGoToDiscover,
        compact: hasContentAbove,
      );
      if (hasContentAbove) {
        return SliverToBoxAdapter(child: emptyState);
      }
      return SliverFillRemaining(
        hasScrollBody: false,
        child: emptyState,
      );
    }

    // All plans come from the server; render them as a flat list.
    final userPlans = plans;

    Widget buildPlanCard(Plan plan) {
      // For active plans, attach a [_TtsAutoDownloadEffect] that watches the
      // TTS status stream and auto-triggers audio download when generation
      // completes. The effect renders nothing and is safe to keep mounted
      // across rebuilds — [downloadPlanAudio] skips already-cached files.
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
              onTap: () => _openPlanEditor(context, planId: plan.id),
              onPlay: () => _onPlanTap(context, ref, plan),
              onPlayWithAiVoice: () {
                ref.read(ttsPlaybackModeProvider.notifier).state =
                    TtsPlaybackMode.genai;
                _onPlanTap(context, ref, plan);
              },
              onEdit: isAuthenticated
                  ? () => _openPlanEditor(context, planId: plan.id)
                  : null,
              onDuplicate: isAuthenticated
                  ? () => _duplicatePlan(context, ref, plan)
                  : null,
              onDelete: isAuthenticated
                  ? () => _confirmDelete(context, ref, plan)
                  : null,
              onActivate: isAuthenticated
                  ? () async {
                      final locale = ref.read(ttsLocaleSettingProvider).valueOrNull ?? kDefaultTtsLocale;
                      final speechRate = ref.read(speechRateSettingProvider).valueOrNull ?? kDefaultSpeechRate;
                      await ref.read(planRepositoryProvider).activatePlan(
                            plan.id,
                            voice: plan.defaultVoice,
                            locale: locale.name,
                            speechRate: speechRate.toString(),
                          );
                    }
                  : null,
            ),
          ),
        ],
      );
    }

    Widget buildSectionHeader(String title) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
        child: Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    final children = <Widget>[
      if (userPlans.isNotEmpty) ...[
        buildSectionHeader('My Plans'),
        ...userPlans.map(buildPlanCard),
      ],
    ];

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => children[index],
          childCount: children.length,
        ),
      ),
    );
  }

  // ── Tap → (guard) → (optional recover dialog) → countdown → start ────────

  Future<void> _onPlanTap(
    BuildContext context,
    WidgetRef ref,
    Plan plan,
  ) async {
    // Guard: if another plan is already running/paused, show confirmation
    // dialog before proceeding. startPlanWithGuard calls engine.stop() when
    // the user confirms, then runs the onStart callback.
    await startPlanWithGuard(
      context,
      ref,
      newPlan: plan,
      onStart: () async {
        final engine = ref.read(planExecutionEngineProvider);

        // Check if this specific plan has a recoverable session in the DB.
        // getRecoverableStepIndexForPlan is read-only and does NOT alter engine
        // state.
        final recoverableStepIndex =
            await engine.getRecoverableStepIndexForPlan(plan.id);

        bool resumeSession = false;

        if (recoverableStepIndex != null) {
          if (!context.mounted) return;

          // Show "Continue where you left off?" dialog.
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

          // Dialog dismissed (back button / barrier tap) → abort.
          if (choice == null) return;
          resumeSession = choice;
        }

        if (!context.mounted) return;

        // Show 3-2-1 countdown overlay; returns true only when it completes.
        final shouldStart = await showCountdownOverlay(context);
        if (shouldStart != true) return;
        if (!context.mounted) return;

        // Mark plan as used.
        final repo = ref.read(planRepositoryProvider);
        await repo.updateLastUsed(plan.id);

        if (resumeSession) {
          // resumeFromPersistedState loads the persisted session for this plan
          // into the engine and calls resume() to restore ambient audio and
          // restart the execution loop from the saved step index.
          final resumed = await engine.resumeFromPersistedState(plan.id);
          if (!resumed) {
            // Session was cleared between the dialog and the countdown (race
            // condition) — fall back to a fresh start.
            await engine.startPlan(plan);
          }
        } else {
          // Fresh start — startPlan resets all execution state.
          await engine.startPlan(plan);
        }

        if (!context.mounted) return;
        context.go(AppRoutes.nowPlaying);
      },
    );
  }

  // ── Duplicate ────────────────────────────────────────────────────────────

  Future<void> _duplicatePlan(
    BuildContext context,
    WidgetRef ref,
    Plan plan,
  ) async {
    final repo = ref.read(planRepositoryProvider);
    final now = DateTime.now();

    // Build a copy: empty id signals createPlan to assign a new server ID.
    // Reset TTS/activation fields so the duplicate starts in a clean state —
    // it has never been activated, has no TTS jobs, and is not the active plan.
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

  // ── Delete with confirmation ─────────────────────────────────────────────

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

// ────────────────────────────────────────────────────────────────────────────
// _SearchBar
// ────────────────────────────────────────────────────────────────────────────

/// Search TextField that writes to [searchQueryProvider] on every keystroke.
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
    // Watch only to rebuild when the query is cleared externally.
    final query = ref.watch(searchQueryProvider);

    // Sync controller text if the provider was reset externally.
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

// ────────────────────────────────────────────────────────────────────────────
// Empty / Error states
// ────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isFiltered,
    this.onGoToDiscover,
    this.compact = false,
  });

  /// True when a search query or category chip is active.
  final bool isFiltered;

  /// Called when the user taps "Discover" in the no-plans state.
  /// Null when [isFiltered] is true (filter hint is shown instead).
  final VoidCallback? onGoToDiscover;

  /// When true, render a top-aligned, lighter-weight layout suitable for
  /// sitting flush below another section (e.g. the programs rail). When
  /// false, the empty state is centered in the available viewport.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isFiltered
              ? Icons.search_off_outlined
              : Icons.playlist_play_outlined,
          size: compact ? 40 : 64,
          color: colorScheme.primary.withValues(alpha: 0.5),
        ),
        SizedBox(height: compact ? 12 : 16),
        Text(
          isFiltered ? 'No plans found' : 'No plans yet',
          style:
              compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (isFiltered)
          Text(
            'Try adjusting your search or clearing the category filter.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          Text(
            'Made no plans yet? No problem — head over to the ',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          GestureDetector(
            onTap: onGoToDiscover,
            child: Text(
              'Discover tab',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: colorScheme.primary,
              ),
            ),
          ),
          Text(
            'to browse publicly available plans.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
        child: content,
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: content,
      ),
    );
  }
}

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
            Text(
              'Could not load plans',
              style: theme.textTheme.titleMedium,
            ),
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

// ────────────────────────────────────────────────────────────────────────────
// Gradient FAB (Stitch: bg-gradient-to-br from-primary to-primary-container)
// ────────────────────────────────────────────────────────────────────────────

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

// ────────────────────────────────────────────────────────────────────────────
// _ContinueProgramCard — surfaces an active series subscription so the user
// has a one-tap path back into the program they're mid-way through. Hidden
// when the user has no active subscriptions; this is the single highest-
// leverage retention surface for the series feature.
// ────────────────────────────────────────────────────────────────────────────

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
        // Pick the most-recently-updated active sub.
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
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/series/${series.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Continue ${series.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
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

// ────────────────────────────────────────────────────────────────────────────
// _MyProgramsRail — horizontal carousel of series the user has subscribed to
// (active, paused, or completed — excludes cancelled). Hidden when the user
// has no subscriptions. Placed above the catalog Programs rail so the user's
// own programs are always the first thing they see.
// ────────────────────────────────────────────────────────────────────────────

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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// _ProgramsRail — horizontal carousel of curated series. Tapping a card opens
// the SeriesDetailScreen. Subscribed series get a "Day N of M" pill; new
// users see the category label.
// ────────────────────────────────────────────────────────────────────────────

class _ProgramsRail extends ConsumerWidget {
  const _ProgramsRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesAsync = ref.watch(publishedSeriesProvider);
    final subsAsync = ref.watch(mySubscriptionsProvider());
    final colorScheme = Theme.of(context).colorScheme;

    // Card height grows with the user's text scale factor so the rail
    // accommodates the title + 2-line description + footer label at
    // accessibility text sizes instead of clipping.
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
