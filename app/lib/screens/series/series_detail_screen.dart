import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:instructor/models/plan.dart';
import 'package:instructor/models/series.dart';
import 'package:instructor/models/series_subscription.dart';
import 'package:instructor/providers/series_providers.dart';
import 'package:instructor/screens/plan_editor/plan_editor_screen.dart';
import 'package:instructor/services/series_api_service.dart';

// Pushing /editor/:planId via context.push from this screen (a top-level
// route, outside the StatefulShellRoute) triggers the go_router 14
// keyReservation regression — see flutter/flutter#140586. Pushing a
// MaterialPageRoute on the root navigator bypasses go_router's
// outer→shell push path while preserving back-stack UX.
//
// Series sessions are admin-curated plans that live only in the in-memory
// series response — they aren't in the user's local Plans cache. Pass the
// fetched Plan as `initialPlan` so the editor seeds its state directly
// instead of hitting the cache and showing "Plan not found."
void _openPlanEditor(
  BuildContext context,
  Plan plan, {
  required int seriesSessionIndex,
}) {
  Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => PlanEditorScreen(
        planId: plan.id,
        initialPlan: plan,
        seriesSessionIndex: seriesSessionIndex,
      ),
    ),
  );
}

/// Screen for a multi-session "program" (series).
///
/// Shows the series header, a list of ordered sessions with completion state,
/// and a sticky bottom CTA whose label depends on the user's subscription:
///   - not subscribed     -> "Start program"
///   - active subscription -> "Continue Day {N+1} of {total}"
///   - paused              -> "Resume"
///   - completed           -> "Restart"
class SeriesDetailScreen extends ConsumerWidget {
  const SeriesDetailScreen({super.key, required this.seriesId});

  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesAsync = ref.watch(seriesByIdProvider(seriesId));
    final subAsync = ref.watch(mySubscriptionForProvider(seriesId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Program'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: seriesAsync.maybeWhen(
          data: (series) => [
            _BookmarkButton(
              series: series,
              subscription: subAsync.valueOrNull,
            ),
          ],
          orElse: () => null,
        ),
      ),
      body: seriesAsync.when(
        data: (series) => _SeriesBody(
          series: series,
          subscription: subAsync.valueOrNull,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e is SeriesApiException
              ? e.userMessage
              : 'Failed to load this program.',
          onRetry: () {
            ref.invalidate(seriesByIdProvider(seriesId));
            ref.invalidate(mySubscriptionForProvider(seriesId));
          },
        ),
      ),
      bottomNavigationBar: seriesAsync.maybeWhen(
        data: (series) => _CtaBar(
          series: series,
          subscription: subAsync.valueOrNull,
        ),
        orElse: () => null,
      ),
    );
  }
}

class _SeriesBody extends StatelessWidget {
  const _SeriesBody({required this.series, this.subscription});

  final Series series;
  final SeriesSubscription? subscription;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        Text(
          series.name,
          style: GoogleFonts.manrope(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        if (series.description != null && series.description!.isNotEmpty)
          Text(
            series.description!,
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        const SizedBox(height: 16),
        _ProgressMeta(series: series, subscription: subscription),
        const SizedBox(height: 24),
        Text(
          'SESSIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colorScheme.outline,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(series.sessions.length, (i) {
          final plan = series.sessions[i];
          return _SessionTile(
            index: i,
            plan: plan,
            state: _stateForSession(i, subscription),
          );
        }),
      ],
    );
  }
}

enum _SessionState { completed, current, locked }

_SessionState _stateForSession(int i, SeriesSubscription? sub) {
  if (sub == null) return _SessionState.locked;
  if (i < sub.completedSessions) return _SessionState.completed;
  if (i == sub.currentSessionIndex) return _SessionState.current;
  return _SessionState.locked;
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.index,
    required this.plan,
    required this.state,
  });

  final int index;
  final Plan plan;
  final _SessionState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCurrent = state == _SessionState.current;
    final isCompleted = state == _SessionState.completed;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: _SessionStateIcon(state: state, colorScheme: colorScheme),
        title: Text(
          'Day ${index + 1}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isCurrent
                ? colorScheme.onPrimaryContainer
                : isCompleted
                    ? colorScheme.outline
                    : colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          plan.name,
          style: TextStyle(
            color: isCurrent
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
        // Soft-lock: future days are tappable, but we don't yet route to them
        // here — that's the responsibility of the CTA bar's "Continue" flow.
        // Tapping a completed day re-runs it.
        onTap: isCompleted || isCurrent
            ? () => _openPlanEditor(context, plan, seriesSessionIndex: index)
            : null,
      ),
    );
  }
}

class _SessionStateIcon extends StatelessWidget {
  const _SessionStateIcon({required this.state, required this.colorScheme});

  final _SessionState state;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _SessionState.completed:
        return Icon(Icons.check_circle, color: colorScheme.primary);
      case _SessionState.current:
        return Icon(Icons.play_circle_fill, color: colorScheme.primary);
      case _SessionState.locked:
        return Icon(Icons.lock_outline, color: colorScheme.outline);
    }
  }
}

class _ProgressMeta extends StatelessWidget {
  const _ProgressMeta({required this.series, this.subscription});

  final Series series;
  final SeriesSubscription? subscription;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final completed = subscription?.completedSessions ?? 0;
    final total = series.totalSessions;

    return Row(
      children: [
        Icon(Icons.calendar_today, size: 14, color: colorScheme.outline),
        const SizedBox(width: 6),
        Text(
          '$total session${total == 1 ? '' : 's'}',
          style: TextStyle(color: colorScheme.outline, fontSize: 13),
        ),
        if (subscription != null) ...[
          const SizedBox(width: 16),
          Icon(Icons.check, size: 14, color: colorScheme.outline),
          const SizedBox(width: 6),
          Text(
            '$completed completed',
            style: TextStyle(color: colorScheme.outline, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class _CtaBar extends ConsumerWidget {
  const _CtaBar({required this.series, this.subscription});

  final Series series;
  final SeriesSubscription? subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSessions = series.sessions.isNotEmpty;
    final label = _ctaLabel();
    final disabled = !hasSessions;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant, width: 1),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: disabled ? null : () => _handleCta(context, ref),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  String _ctaLabel() {
    if (subscription == null) return 'Start program';
    switch (subscription!.status) {
      case SeriesSubscriptionStatus.active:
        final next = (subscription!.currentSessionIndex + 1)
            .clamp(1, series.totalSessions == 0 ? 1 : series.totalSessions);
        return 'Continue Day $next of ${series.totalSessions}';
      case SeriesSubscriptionStatus.paused:
        return 'Resume program';
      case SeriesSubscriptionStatus.completed:
        return 'Restart program';
      case SeriesSubscriptionStatus.cancelled:
        return 'Re-subscribe';
    }
  }

  Future<void> _handleCta(BuildContext context, WidgetRef ref) async {
    final api = ref.read(seriesApiServiceProvider);
    try {
      // For non-active states, flip the subscription state first so the user
      // sees an immediate response. The actual session opens after.
      if (subscription == null) {
        await api.subscribe(series.id);
      } else if (subscription!.status == SeriesSubscriptionStatus.paused) {
        await api.resume(series.id);
      } else if (subscription!.status == SeriesSubscriptionStatus.cancelled) {
        await api.subscribe(series.id);
      }
      ref.invalidate(mySubscriptionsProvider);
      ref.invalidate(mySubscriptionForProvider(series.id));

      // Open the session the user is currently on (or Day 1 if just starting).
      final idx = subscription?.currentSessionIndex ?? 0;
      final clamped = idx.clamp(0, series.sessions.length - 1);
      if (!context.mounted) return;
      final plan = series.sessions[clamped];
      _openPlanEditor(context, plan, seriesSessionIndex: clamped);
    } on SeriesApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.userMessage)),
      );
    }
  }
}

class _BookmarkButton extends ConsumerStatefulWidget {
  const _BookmarkButton({required this.series, this.subscription});

  final Series series;
  final SeriesSubscription? subscription;

  @override
  ConsumerState<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends ConsumerState<_BookmarkButton> {
  bool _loading = false;

  bool get _isSubscribed =>
      widget.subscription != null &&
      widget.subscription!.status != SeriesSubscriptionStatus.cancelled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _isSubscribed ? 'Saved to My Programs' : 'Save to My Programs',
      onPressed: _isSubscribed || _loading ? null : _subscribe,
      icon: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_isSubscribed ? Icons.bookmark : Icons.bookmark_border),
    );
  }

  Future<void> _subscribe() async {
    setState(() => _loading = true);
    try {
      await ref.read(seriesApiServiceProvider).subscribe(widget.series.id);
      ref.invalidate(mySubscriptionsProvider);
      ref.invalidate(mySubscriptionForProvider(widget.series.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${widget.series.name}" saved to My Programs'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on SeriesApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.userMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
