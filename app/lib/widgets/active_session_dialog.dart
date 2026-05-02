import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/models/plan.dart';
import 'package:instructor/providers/execution_providers.dart';
import 'package:instructor/services/plan_execution_engine.dart';

/// Guards plan start against an already-active session.
///
/// If another session is active, it is gracefully stopped before [onStart]
/// is called for the new plan.
///
/// Returns `true` if the new plan was started, `false` on error.
Future<bool> startPlanWithGuard(
  BuildContext context,
  WidgetRef ref, {
  required Plan newPlan,
  required Future<void> Function() onStart,
}) async {
  final hasActive = ref.read(hasActiveSessionProvider);

  if (hasActive) {
    final engine = ref.read(planExecutionEngineProvider);
    await engine.stop();
  }

  // Reset series-session context on every start. Callers that are launching a
  // series session re-set it after onStart returns; everyone else gets a clean
  // slate so a stale series id can't leak into a later, unrelated completion.
  ref.read(activeSeriesSessionProvider.notifier).state = null;

  if (!context.mounted) return false;
  await onStart();
  return true;
}
