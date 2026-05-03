// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_execution_engine.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$planExecutionEngineHash() =>
    r'b75b01626ffae58ccaa7ed408f4d90a995e949f3';

/// Singleton [PlanExecutionEngine] provider.
///
/// [keepAlive: true] ensures the engine (and its [stateStream]) persists for
/// the entire app session.
///
/// Override in tests with a fake implementation:
/// ```dart
/// ProviderScope(
///   overrides: [
///     planExecutionEngineProvider.overrideWithValue(FakePlanExecutionEngine()),
///   ],
/// )
/// ```
///
/// Copied from [planExecutionEngine].
@ProviderFor(planExecutionEngine)
final planExecutionEngineProvider = Provider<PlanExecutionEngine>.internal(
  planExecutionEngine,
  name: r'planExecutionEngineProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$planExecutionEngineHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlanExecutionEngineRef = ProviderRef<PlanExecutionEngine>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
