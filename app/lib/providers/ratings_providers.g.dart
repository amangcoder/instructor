// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ratings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$planRatingHash() => r'fc1e868dc1376f321eee187f09efd2348a4abafa';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Fetches aggregate rating stats + the current user's own rating for [planId].
///
/// Auto-disposed when no widgets are watching. Call `ref.invalidate` after
/// submitting or deleting a rating to refresh the displayed stats.
///
/// Copied from [planRating].
@ProviderFor(planRating)
const planRatingProvider = PlanRatingFamily();

/// Fetches aggregate rating stats + the current user's own rating for [planId].
///
/// Auto-disposed when no widgets are watching. Call `ref.invalidate` after
/// submitting or deleting a rating to refresh the displayed stats.
///
/// Copied from [planRating].
class PlanRatingFamily extends Family<AsyncValue<PlanRatingResult>> {
  /// Fetches aggregate rating stats + the current user's own rating for [planId].
  ///
  /// Auto-disposed when no widgets are watching. Call `ref.invalidate` after
  /// submitting or deleting a rating to refresh the displayed stats.
  ///
  /// Copied from [planRating].
  const PlanRatingFamily();

  /// Fetches aggregate rating stats + the current user's own rating for [planId].
  ///
  /// Auto-disposed when no widgets are watching. Call `ref.invalidate` after
  /// submitting or deleting a rating to refresh the displayed stats.
  ///
  /// Copied from [planRating].
  PlanRatingProvider call(
    String planId,
  ) {
    return PlanRatingProvider(
      planId,
    );
  }

  @override
  PlanRatingProvider getProviderOverride(
    covariant PlanRatingProvider provider,
  ) {
    return call(
      provider.planId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'planRatingProvider';
}

/// Fetches aggregate rating stats + the current user's own rating for [planId].
///
/// Auto-disposed when no widgets are watching. Call `ref.invalidate` after
/// submitting or deleting a rating to refresh the displayed stats.
///
/// Copied from [planRating].
class PlanRatingProvider extends AutoDisposeFutureProvider<PlanRatingResult> {
  /// Fetches aggregate rating stats + the current user's own rating for [planId].
  ///
  /// Auto-disposed when no widgets are watching. Call `ref.invalidate` after
  /// submitting or deleting a rating to refresh the displayed stats.
  ///
  /// Copied from [planRating].
  PlanRatingProvider(
    String planId,
  ) : this._internal(
          (ref) => planRating(
            ref as PlanRatingRef,
            planId,
          ),
          from: planRatingProvider,
          name: r'planRatingProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$planRatingHash,
          dependencies: PlanRatingFamily._dependencies,
          allTransitiveDependencies:
              PlanRatingFamily._allTransitiveDependencies,
          planId: planId,
        );

  PlanRatingProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.planId,
  }) : super.internal();

  final String planId;

  @override
  Override overrideWith(
    FutureOr<PlanRatingResult> Function(PlanRatingRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PlanRatingProvider._internal(
        (ref) => create(ref as PlanRatingRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        planId: planId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<PlanRatingResult> createElement() {
    return _PlanRatingProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanRatingProvider && other.planId == planId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, planId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PlanRatingRef on AutoDisposeFutureProviderRef<PlanRatingResult> {
  /// The parameter `planId` of this provider.
  String get planId;
}

class _PlanRatingProviderElement
    extends AutoDisposeFutureProviderElement<PlanRatingResult>
    with PlanRatingRef {
  _PlanRatingProviderElement(super.provider);

  @override
  String get planId => (origin as PlanRatingProvider).planId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
