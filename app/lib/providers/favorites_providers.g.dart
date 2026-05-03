// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorites_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userFavoritesHash() => r'4d290afa01f9355ff82fcaa22f1ee1bb753fdd50';

/// Fetches all plan IDs the current user has favorited.
///
/// Returns a [Set] for O(1) membership tests in [isFavoriteProvider].
/// Call `ref.invalidate(userFavoritesProvider)` after toggling to refresh.
///
/// Copied from [userFavorites].
@ProviderFor(userFavorites)
final userFavoritesProvider = AutoDisposeFutureProvider<Set<String>>.internal(
  userFavorites,
  name: r'userFavoritesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userFavoritesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserFavoritesRef = AutoDisposeFutureProviderRef<Set<String>>;
String _$isFavoriteHash() => r'5b529caff4bf10136d8fe9a0527ca143673439e9';

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

/// Derived bool — true when [planId] is in the user's favorites list.
///
/// Recalculates automatically whenever [userFavoritesProvider] refreshes.
///
/// Copied from [isFavorite].
@ProviderFor(isFavorite)
const isFavoriteProvider = IsFavoriteFamily();

/// Derived bool — true when [planId] is in the user's favorites list.
///
/// Recalculates automatically whenever [userFavoritesProvider] refreshes.
///
/// Copied from [isFavorite].
class IsFavoriteFamily extends Family<AsyncValue<bool>> {
  /// Derived bool — true when [planId] is in the user's favorites list.
  ///
  /// Recalculates automatically whenever [userFavoritesProvider] refreshes.
  ///
  /// Copied from [isFavorite].
  const IsFavoriteFamily();

  /// Derived bool — true when [planId] is in the user's favorites list.
  ///
  /// Recalculates automatically whenever [userFavoritesProvider] refreshes.
  ///
  /// Copied from [isFavorite].
  IsFavoriteProvider call(
    String planId,
  ) {
    return IsFavoriteProvider(
      planId,
    );
  }

  @override
  IsFavoriteProvider getProviderOverride(
    covariant IsFavoriteProvider provider,
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
  String? get name => r'isFavoriteProvider';
}

/// Derived bool — true when [planId] is in the user's favorites list.
///
/// Recalculates automatically whenever [userFavoritesProvider] refreshes.
///
/// Copied from [isFavorite].
class IsFavoriteProvider extends AutoDisposeFutureProvider<bool> {
  /// Derived bool — true when [planId] is in the user's favorites list.
  ///
  /// Recalculates automatically whenever [userFavoritesProvider] refreshes.
  ///
  /// Copied from [isFavorite].
  IsFavoriteProvider(
    String planId,
  ) : this._internal(
          (ref) => isFavorite(
            ref as IsFavoriteRef,
            planId,
          ),
          from: isFavoriteProvider,
          name: r'isFavoriteProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$isFavoriteHash,
          dependencies: IsFavoriteFamily._dependencies,
          allTransitiveDependencies:
              IsFavoriteFamily._allTransitiveDependencies,
          planId: planId,
        );

  IsFavoriteProvider._internal(
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
    FutureOr<bool> Function(IsFavoriteRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: IsFavoriteProvider._internal(
        (ref) => create(ref as IsFavoriteRef),
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
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _IsFavoriteProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IsFavoriteProvider && other.planId == planId;
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
mixin IsFavoriteRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `planId` of this provider.
  String get planId;
}

class _IsFavoriteProviderElement extends AutoDisposeFutureProviderElement<bool>
    with IsFavoriteRef {
  _IsFavoriteProviderElement(super.provider);

  @override
  String get planId => (origin as IsFavoriteProvider).planId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
