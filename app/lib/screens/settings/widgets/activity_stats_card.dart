import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/screens/settings/widgets/shared_settings_widgets.dart';

/// Displays three at-a-glance activity stat tiles: Plans, Sessions, Streak.
///
/// Plans count is live from [planListProvider]; Sessions and Streak are
/// placeholders until session tracking is implemented.
///
/// IMPORTANT: tiles are display-only — no tap feedback, no [InkWell], no
/// [GestureDetector].
class ActivityStatsCard extends ConsumerWidget {
  const ActivityStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(planListProvider());
    final planCount = plansAsync.valueOrNull?.length ?? 0;
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
            _StatTile(
              value: '—',
              label: 'Streak',
              leading: Icon(
                Icons.local_fire_department,
                color: colorScheme.outlineVariant,
                size: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Private display-only stat tile — no tap handling.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    this.leading,
    this.sublabel,
  });

  final String value;
  final String label;

  /// Optional widget rendered to the left of [value] (e.g. a fire icon).
  final Widget? leading;

  /// Optional widget rendered below [label] (e.g. microcopy for Sessions).
  final Widget? sublabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Padding(
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
      ),
    );
  }
}
