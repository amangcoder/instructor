// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'execution_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$executionStateHash() => r'862f3d023d81bfdd73eab78a33fbd4e485d2d571';

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
///
/// Copied from [executionState].
@ProviderFor(executionState)
final executionStateProvider =
    AutoDisposeStreamProvider<ExecutionState>.internal(
  executionState,
  name: r'executionStateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$executionStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ExecutionStateRef = AutoDisposeStreamProviderRef<ExecutionState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
