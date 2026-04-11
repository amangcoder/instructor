import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/models/plan.dart';
import 'package:instructor/providers/execution_providers.dart';
import 'package:instructor/services/plan_execution_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a confirmation dialog when a plan session is already active.
///
/// Returns `true` when the user taps **Start** (confirming they want to end
/// the current session and begin the new one), or `false` if they cancel.
Future<bool> showActiveSessionDialog(
  BuildContext context, {
  required String currentPlanName,
  required String newPlanName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ActiveSessionDialog(
      currentPlanName: currentPlanName,
      newPlanName: newPlanName,
    ),
  );
  return result ?? false;
}

/// Guards plan start against an already-active session.
///
/// 1. Checks [hasActiveSessionProvider].
/// 2. If active, shows [showActiveSessionDialog].
/// 3. If confirmed (or no active session), stops the current session then
///    calls [onStart].
///
/// Returns `true` if the new plan was started, `false` if the user cancelled.
Future<bool> startPlanWithGuard(
  BuildContext context,
  WidgetRef ref, {
  required Plan newPlan,
  required Future<void> Function() onStart,
}) async {
  final hasActive = ref.read(hasActiveSessionProvider);

  if (hasActive) {
    // Read the current plan name from execution state.
    final stateAsync = ref.read(executionStateProvider);
    final currentPlanName = stateAsync.maybeWhen(
      data: (state) => state.plan.name,
      orElse: () => 'current session',
    );

    if (!context.mounted) return false;

    final confirmed = await showActiveSessionDialog(
      context,
      currentPlanName: currentPlanName,
      newPlanName: newPlan.name,
    );

    if (!confirmed) return false;
    if (!context.mounted) return false;

    // Fully stop the current session before starting the new one.
    final engine = ref.read(planExecutionEngineProvider);
    await engine.stop();
  }

  if (!context.mounted) return false;
  await onStart();
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog widget
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveSessionDialog extends StatelessWidget {
  const _ActiveSessionDialog({
    required this.currentPlanName,
    required this.newPlanName,
  });

  final String currentPlanName;
  final String newPlanName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Session already running'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A session is currently running.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          // Formatted summary of the switch.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SwitchRow(
                  label: 'End',
                  planName: currentPlanName,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 6),
                _SwitchRow(
                  label: 'Start',
                  planName: newPlanName,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Start'),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.planName,
    required this.color,
  });

  final String label;
  final String planName;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label  ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Expanded(
          child: Text(
            planName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}
