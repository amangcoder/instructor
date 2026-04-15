// Scheduled triggers card — lists every active plan-start trigger for the
// current user with a per-row cancel button.
//
// Empty state hides the card so the Settings screen stays uncluttered when
// the user has no triggers (the "Add to Calendar" sheet is the entry point).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/repositories/plan_trigger_repository.dart';
import 'package:instructor/screens/settings/widgets/shared_settings_widgets.dart';
import 'package:instructor/services/auth_service.dart';
import 'package:instructor/services/plan_trigger_service.dart';
import 'package:instructor/services/plan_trigger_sync_service.dart';

class ScheduledTriggersCard extends ConsumerWidget {
  const ScheduledTriggersCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).getUser();
    if (user == null) return const SizedBox.shrink();

    final repo = ref.watch(planTriggerRepositoryProvider);

    return StreamBuilder<List<PlanTriggersTableData>>(
      stream: repo.watchActive(user.id),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <PlanTriggersTableData>[];
        if (rows.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Scheduled Sessions'),
            SettingsCard(
              children: [
                for (final r in rows)
                  _TriggerRow(
                    row: r,
                    userId: user.id,
                    isLast: r == rows.last,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TriggerRow extends ConsumerWidget {
  const _TriggerRow({
    required this.row,
    required this.userId,
    required this.isLast,
  });

  final PlanTriggersTableData row;
  final String userId;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(Icons.alarm_outlined, color: colorScheme.primary),
          title: Text(
            row.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(_formatSubtitle(context, row)),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel scheduled session',
            onPressed: () => _confirmCancel(context, ref),
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Scheduled Session?'),
        content: Text('"${row.title}" will no longer start automatically.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(planTriggerServiceProvider).cancel(row.clientId);
    unawaited(
      ref.read(planTriggerSyncServiceProvider).push(userId).catchError(
        (Object e) => 0,
      ),
    );
  }

  String _formatSubtitle(BuildContext context, PlanTriggersTableData r) {
    final start = r.startUtc.toLocal();
    final time = TimeOfDay.fromDateTime(start).format(context);
    final date = '${start.day} ${_monthName(start.month)} ${start.year}';
    final recurrence = _recurrenceLabel(r.recurrence);
    return recurrence.isEmpty
        ? '$date • $time'
        : '$date • $time • $recurrence';
  }

  String _recurrenceLabel(String value) => switch (value) {
        'daily' => 'Daily',
        'weekly' => 'Weekly',
        'weekdays' => 'Mon–Fri',
        _ => '',
      };

  String _monthName(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m - 1];
}
