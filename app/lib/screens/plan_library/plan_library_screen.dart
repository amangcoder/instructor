import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/repositories/plan_repository.dart';
import 'package:instructor/router.dart';
import 'package:instructor/services/plan_execution_engine.dart';
import 'package:instructor/theme/app_branding.dart';
import 'package:instructor/widgets/active_session_dialog.dart';

import 'widgets/category_filter.dart';
import 'widgets/countdown_overlay.dart';
import 'widgets/plan_card.dart';

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
final selectedCategoryProvider = StateProvider<PlanCategory?>((ref) => null);

// ────────────────────────────────────────────────────────────────────────────
// PlanLibraryScreen
// ────────────────────────────────────────────────────────────────────────────

/// Home screen — displays the user's Plan library with search, category
/// filtering, and one-tap-to-start.
///
/// ## Layout (top → bottom)
/// 1. [AppBar] with title and settings icon
/// 2. Search bar — filters plans by name in real-time via SQLite LIKE
/// 3. [CategoryFilter] — horizontal chip row for category filtering
/// 4. [ListView.builder] of [PlanCard] widgets
/// 5. [FloatingActionButton] → create new Plan
class PlanLibraryScreen extends ConsumerWidget {
  const PlanLibraryScreen({super.key});

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

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBranding.brandedAppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.surfaceContainer,
              child: Icon(Icons.person, size: 18, color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── "Plan Library" heading ─────────────────────────────────────────
          Padding(
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

          // ── Search bar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: _SearchBar(),
          ),

          // ── Category filter chips ──────────────────────────────────────────
          const CategoryFilter(),

          // ── Plan list ─────────────────────────────────────────────────────
          Expanded(
            child: plansAsync.when(
              data: (plans) => _PlanList(
                plans: plans,
                isAuthenticated: isLoggedIn,
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(planListProvider),
              ),
            ),
          ),
        ],
      ),

      // ── FAB: gradient (Stitch design) ─────────────────────────────────────
      floatingActionButton: isLoggedIn
          ? _GradientFab(
              onPressed: () => context.push(AppRoutes.editorNew),
            )
          : null,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// _PlanList
// ────────────────────────────────────────────────────────────────────────────

class _PlanList extends ConsumerWidget {
  const _PlanList({required this.plans, required this.isAuthenticated});

  final List<Plan> plans;
  final bool isAuthenticated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (plans.isEmpty) {
      return const _EmptyState();
    }

    final userPlans = plans.where((p) => p.isUserCreated).toList();
    final starterPlans = plans.where((p) => !p.isUserCreated).toList();

    // If all plans are the same type, fall through to a flat list with one
    // section header. If both types are present, show two labelled sections.
    Widget buildPlanCard(Plan plan) {
      return Padding(
        key: ValueKey(plan.id),
        padding: const EdgeInsets.only(bottom: 8),
        child: PlanCard(
          plan: plan,
          onTap: () => context.push('/editor/${plan.id}'),
          onPlay: () => _onPlanTap(context, ref, plan),
          onEdit: isAuthenticated
              ? () => context.push('/editor/${plan.id}')
              : null,
          onDuplicate: isAuthenticated
              ? () => _duplicatePlan(context, ref, plan)
              : null,
          onDelete: isAuthenticated
              ? () => _confirmDelete(context, ref, plan)
              : null,
        ),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (userPlans.isNotEmpty) ...[
          buildSectionHeader('My Plans'),
          ...userPlans.map(buildPlanCard),
        ],
        if (starterPlans.isNotEmpty) ...[
          if (userPlans.isNotEmpty) const SizedBox(height: 8),
          buildSectionHeader('Starter Plans'),
          ...starterPlans.map(buildPlanCard),
        ],
      ],
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

    // Build a copy: id=0 is ignored by createPlan (auto-increment).
    final copy = plan.copyWith(
      id: 0,
      name: '${plan.name} (copy)',
      createdAt: now,
      updatedAt: now,
      lastUsedAt: null,
    );
    await repo.createPlan(copy);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${plan.name}" duplicated')),
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
      SnackBar(content: Text('"${plan.name}" deleted')),
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
  const _EmptyState();

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
              Icons.playlist_play_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No plans yet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to create your first plan,\n'
              'or try clearing your search filter.',
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
