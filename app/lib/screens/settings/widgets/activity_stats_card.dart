import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/providers/streak_providers.dart';
import 'package:instructor/screens/settings/widgets/shared_settings_widgets.dart';
import 'package:instructor/screens/settings/widgets/streak_calendar_sheet.dart';

/// Displays three at-a-glance activity stat tiles: Plans, Sessions, Streak.
///
/// - Plans count is live from [planListProvider]
/// - Sessions shows a placeholder (—) for future implementation
/// - Streak shows current streak count with flame icon, fetched reactively from
///   [currentStreakProvider] and [completedTodayProvider]
///
/// The Streak tile is tappable and opens the StreakCalendarSheet to show
/// the full 30-day calendar view.
class ActivityStatsCard extends ConsumerWidget {
  const ActivityStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(planListProvider());
    final planCount = plansAsync.valueOrNull?.length ?? 0;
    final streakAsync = ref.watch(currentStreakProvider);
    final completedTodayAsync = ref.watch(completedTodayProvider);
    final sessionCountAsync = ref.watch(totalSessionCountProvider);
    final sessionCount = sessionCountAsync.valueOrNull;
    final colorScheme = Theme.of(context).colorScheme;

    return SettingsCard(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  value: '$planCount',
                  label: 'Plans',
                  leading: Icon(
                    Icons.library_books_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _StatTile(
                  value: sessionCount == null ? '—' : '$sessionCount',
                  label: 'Sessions',
                  leading: Icon(
                    Icons.timer_rounded,
                    size: 16,
                    color: colorScheme.tertiary,
                  ),
                  sublabel: sessionCount == null || sessionCount == 0
                      ? Text(
                          'No sessions yet',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.outline,
                          ),
                        )
                      : null,
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              // Streak tile is interactive — tap to open calendar
              Expanded(
                child: _StreakStatTile(
                  streakAsync: streakAsync,
                  completedTodayAsync: completedTodayAsync,
                  colorScheme: colorScheme,
                  onTap: () => _openStreakCalendarSheet(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Opens the StreakCalendarSheet modal bottom sheet.
  static Future<void> _openStreakCalendarSheet(BuildContext context) {
    return showStreakCalendarSheet(context);
  }
}

/// Private display-only stat tile — no tap handling.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    this.leading,
    this.sublabel,
    this.onTap,
    this.semanticLabel,
  });

  final String value;
  final String label;

  /// Optional widget rendered to the left of [value] (e.g. a fire icon).
  final Widget? leading;

  /// Optional widget rendered below [label] (e.g. microcopy for Sessions).
  final Widget? sublabel;

  /// Optional tap callback. If provided, the tile becomes interactive.
  final VoidCallback? onTap;

  /// Full semantic label for the tile, including any sublabel information.
  /// When provided, this replaces the default '$value $label' semantic label
  /// so that screen readers can announce sublabel content suppressed by
  /// [excludeSemantics].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Reserved leading slot — keeps numbers centered and aligned
          // across tiles regardless of whether this tile has an icon.
          SizedBox(
            height: 18,
            child: leading == null ? null : Center(child: leading),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          // Reserved sublabel slot — fixed height keeps tile heights equal.
          SizedBox(
            height: 20,
            child: sublabel == null ? null : Center(child: sublabel),
          ),
        ],
      ),
    );

    content = Semantics(
      label: semanticLabel ?? '$value $label',
      excludeSemantics: true,
      child: content,
    );

    if (onTap != null) {
      content = Semantics(
        button: true,
        label: semanticLabel ?? '$value $label',
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// Streak stat tile that handles `AsyncValue<int>` for current streak.
///
/// Shows:
/// - Flame emoji + streak count (e.g., "🔥 10")
/// - Today's completion status below the "Streak" label
/// - Tappable to open the StreakCalendarSheet
class _StreakStatTile extends StatelessWidget {
  const _StreakStatTile({
    required this.streakAsync,
    required this.completedTodayAsync,
    required this.colorScheme,
    required this.onTap,
  });

  final AsyncValue<int> streakAsync;
  final AsyncValue<bool> completedTodayAsync;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return streakAsync.when(
      loading: () => const _StatTile(
        value: '—',
        label: 'Streak',
        leading: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => _StatTile(
        value: '—',
        label: 'Streak',
        sublabel: Text(
          'Error loading',
          style: TextStyle(fontSize: 11, color: colorScheme.error),
        ),
      ),
      data: (streak) {
        // Build the full semantic label before excludeSemantics suppresses
        // the sublabel widget, so screen readers can announce the completion
        // status (REQ: accessibility, streak tile).
        final completionStatus = completedTodayAsync.when(
          loading: () => null,
          error: (_, __) => null,
          data: (completedToday) =>
              completedToday ? 'Completed today' : 'No session yet today',
        );
        final streakSemanticLabel = completionStatus != null
            ? '$streak Streak, $completionStatus'
            : '$streak Streak';

        return _StatTile(
          value: '$streak',
          label: 'Streak',
          leading: const Text('🔥', style: TextStyle(fontSize: 16)),
          semanticLabel: streakSemanticLabel,
          sublabel: completedTodayAsync.when(
            loading: () => const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            error: (_, __) => Text(
              'Error',
              style: TextStyle(fontSize: 11, color: colorScheme.error),
            ),
            data: (completedToday) => completedToday
                ? _CompletionPill(colorScheme: colorScheme)
                : Text(
                    'No session yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.outline,
                    ),
                  ),
          ),
          onTap: onTap,
        );
      },
    );
  }
}

/// Compact "Today ✓" pill rendered in the streak sublabel slot when the user
/// has completed a session today. Uses primary container colors so the
/// indicator reads as a positive status without dominating the card.
class _CompletionPill extends StatelessWidget {
  const _CompletionPill({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_rounded,
            size: 12,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 2),
          Text(
            'Today',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
