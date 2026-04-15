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
    final colorScheme = Theme.of(context).colorScheme;

    return SettingsCard(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatTile(value: '$planCount', label: 'Plans'),
            _StatTile(
              value: '—',
              label: 'Sessions',
              sublabel: Text(
                'Start a session to track',
                style: TextStyle(fontSize: 11, color: colorScheme.outline),
              ),
            ),
            // Streak tile is interactive — tap to open calendar
            _StreakStatTile(
              streakAsync: streakAsync,
              completedTodayAsync: completedTodayAsync,
              colorScheme: colorScheme,
              onTap: () => _openStreakCalendarSheet(context),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 4),
              ],
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 2),
            sublabel!,
          ],
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

/// Streak stat tile that handles AsyncValue<int> for current streak.
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
      loading: () => _StatTile(
        value: '—',
        label: 'Streak',
        leading: const SizedBox(
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
          leading: Text(
            '🔥',
            style: TextStyle(fontSize: 16),
          ),
          semanticLabel: streakSemanticLabel,
          sublabel: completedTodayAsync.when(
            loading: () => Text(
              'Checking...',
              style: TextStyle(fontSize: 11, color: colorScheme.outline),
            ),
            error: (_, __) => Text(
              'Error',
              style: TextStyle(fontSize: 11, color: colorScheme.error),
            ),
            data: (completedToday) => Text(
              completedToday ? 'Completed today ✓' : 'No session yet today',
              style: TextStyle(fontSize: 11, color: colorScheme.outline),
            ),
          ),
          onTap: onTap,
        );
      },
    );
  }
}
