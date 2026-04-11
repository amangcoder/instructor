import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/services/plan_execution_engine.dart';

part 'execution_providers.g.dart';

/// Reactive stream of [ExecutionState] from [PlanExecutionEngine.stateStream].
///
/// Consumed by [NowPlayingScreen] to display the current step, countdown timer,
/// and next-up preview.
///
/// Seeds the stream with [PlanExecutionEngine.currentState] when available so
/// that [NowPlayingScreen] (which subscribes after [startPlan] emits the
/// initial state on the broadcast stream) does not get stuck in [AsyncLoading].
///
/// The [keepAlive: false] default means the stream subscription is cancelled
/// when no widgets are listening (e.g. after navigating away from NowPlaying),
/// which is correct — the engine itself ([planExecutionEngineProvider]) keeps
/// alive and continues execution in the background regardless.
@riverpod
Stream<ExecutionState> executionState(Ref ref) async* {
  final engine = ref.watch(planExecutionEngineProvider);
  final seeded = engine.currentState;
  if (seeded != null) yield seeded;
  yield* engine.stateStream;
}

/// True when a plan execution session is active (running or paused).
///
/// Used by [MiniPlayerBar] and [BottomNavShell] to show/hide the mini-player.
@riverpod
bool hasActiveSession(Ref ref) {
  final state = ref.watch(executionStateProvider);
  return state.maybeWhen(
    data: (s) =>
        s.status == ExecutionStatus.running ||
        s.status == ExecutionStatus.paused,
    orElse: () => false,
  );
}

/// Fraction (0.0–1.0) of the current step that has elapsed.
///
/// Computed from [ExecutionState.currentStepDuration] and
/// [ExecutionState.timeRemaining].  Returns 0.0 when no session is active or
/// the step duration is zero.
@riverpod
double stepProgressFraction(Ref ref) {
  final state = ref.watch(executionStateProvider);
  return state.maybeWhen(
    data: (s) {
      final totalMs = s.currentStepDuration.inMilliseconds;
      if (totalMs <= 0) return 0.0;
      final elapsedMs = totalMs - s.timeRemaining.inMilliseconds;
      return (elapsedMs / totalMs).clamp(0.0, 1.0);
    },
    orElse: () => 0.0,
  );
}
