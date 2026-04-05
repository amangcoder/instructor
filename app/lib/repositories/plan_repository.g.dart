// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$planRepositoryHash() => r'428dbd5ff92c2a5074a866ff44eefa3ee3bbd696';

/// Singleton [PlanRepository] provider.
///
/// [keepAlive: true] — the repository must outlive any individual screen so
/// that watch streams remain active and the database is not torn down.
///
/// Override in tests with a mock or an [AppDatabase.forTesting] instance:
/// ```dart
/// final container = ProviderContainer(overrides: [
///   planRepositoryProvider.overrideWithValue(FakePlanRepository()),
/// ]);
/// ```
///
/// Copied from [planRepository].
@ProviderFor(planRepository)
final planRepositoryProvider = Provider<PlanRepository>.internal(
  planRepository,
  name: r'planRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$planRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlanRepositoryRef = ProviderRef<PlanRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
