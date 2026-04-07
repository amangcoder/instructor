import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
