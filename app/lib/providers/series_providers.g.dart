// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'series_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$seriesApiServiceHash() => r'c5a75fc0ec635cc4b43641103bd3b0b87adecb44';

/// Singleton SeriesApiService — same lifetime as the rest of the app's HTTP
/// services so we don't churn http.Client instances.
///
/// Copied from [seriesApiService].
@ProviderFor(seriesApiService)
final seriesApiServiceProvider = Provider<SeriesApiService>.internal(
  seriesApiService,
  name: r'seriesApiServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$seriesApiServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SeriesApiServiceRef = ProviderRef<SeriesApiService>;
String _$publishedSeriesHash() => r'594b48954478699988d5275c49d8a33f51f37914';

/// Published series for the Library "Programs" rail.
///
/// Copied from [publishedSeries].
@ProviderFor(publishedSeries)
final publishedSeriesProvider =
    AutoDisposeFutureProvider<List<Series>>.internal(
  publishedSeries,
  name: r'publishedSeriesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$publishedSeriesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PublishedSeriesRef = AutoDisposeFutureProviderRef<List<Series>>;
String _$seriesByIdHash() => r'cd189a15f09087b149bbe6204d31c86d2bf95ef6';

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

/// Single series detail (with ordered sessions).
///
/// Copied from [seriesById].
@ProviderFor(seriesById)
const seriesByIdProvider = SeriesByIdFamily();

/// Single series detail (with ordered sessions).
///
/// Copied from [seriesById].
class SeriesByIdFamily extends Family<AsyncValue<Series>> {
  /// Single series detail (with ordered sessions).
  ///
  /// Copied from [seriesById].
  const SeriesByIdFamily();

  /// Single series detail (with ordered sessions).
  ///
  /// Copied from [seriesById].
  SeriesByIdProvider call(
    String id,
  ) {
    return SeriesByIdProvider(
      id,
    );
  }

  @override
  SeriesByIdProvider getProviderOverride(
    covariant SeriesByIdProvider provider,
  ) {
    return call(
      provider.id,
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
  String? get name => r'seriesByIdProvider';
}

/// Single series detail (with ordered sessions).
///
/// Copied from [seriesById].
class SeriesByIdProvider extends AutoDisposeFutureProvider<Series> {
  /// Single series detail (with ordered sessions).
  ///
  /// Copied from [seriesById].
  SeriesByIdProvider(
    String id,
  ) : this._internal(
          (ref) => seriesById(
            ref as SeriesByIdRef,
            id,
          ),
          from: seriesByIdProvider,
          name: r'seriesByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$seriesByIdHash,
          dependencies: SeriesByIdFamily._dependencies,
          allTransitiveDependencies:
              SeriesByIdFamily._allTransitiveDependencies,
          id: id,
        );

  SeriesByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<Series> Function(SeriesByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SeriesByIdProvider._internal(
        (ref) => create(ref as SeriesByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Series> createElement() {
    return _SeriesByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SeriesByIdProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SeriesByIdRef on AutoDisposeFutureProviderRef<Series> {
  /// The parameter `id` of this provider.
  String get id;
}

class _SeriesByIdProviderElement
    extends AutoDisposeFutureProviderElement<Series> with SeriesByIdRef {
  _SeriesByIdProviderElement(super.provider);

  @override
  String get id => (origin as SeriesByIdProvider).id;
}

String _$mySubscriptionsHash() => r'071e22f0cd542cc70ccba38dc79e394059ad9a72';

/// Current user's subscriptions.
///
/// [activeOnly] = true is what the "Continue your program" card on the Library
/// tab and the mini-player series-context lookup use, since they only care
/// about programs the user is currently progressing through.
///
/// Copied from [mySubscriptions].
@ProviderFor(mySubscriptions)
const mySubscriptionsProvider = MySubscriptionsFamily();

/// Current user's subscriptions.
///
/// [activeOnly] = true is what the "Continue your program" card on the Library
/// tab and the mini-player series-context lookup use, since they only care
/// about programs the user is currently progressing through.
///
/// Copied from [mySubscriptions].
class MySubscriptionsFamily
    extends Family<AsyncValue<List<SeriesSubscription>>> {
  /// Current user's subscriptions.
  ///
  /// [activeOnly] = true is what the "Continue your program" card on the Library
  /// tab and the mini-player series-context lookup use, since they only care
  /// about programs the user is currently progressing through.
  ///
  /// Copied from [mySubscriptions].
  const MySubscriptionsFamily();

  /// Current user's subscriptions.
  ///
  /// [activeOnly] = true is what the "Continue your program" card on the Library
  /// tab and the mini-player series-context lookup use, since they only care
  /// about programs the user is currently progressing through.
  ///
  /// Copied from [mySubscriptions].
  MySubscriptionsProvider call({
    bool activeOnly = false,
  }) {
    return MySubscriptionsProvider(
      activeOnly: activeOnly,
    );
  }

  @override
  MySubscriptionsProvider getProviderOverride(
    covariant MySubscriptionsProvider provider,
  ) {
    return call(
      activeOnly: provider.activeOnly,
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
  String? get name => r'mySubscriptionsProvider';
}

/// Current user's subscriptions.
///
/// [activeOnly] = true is what the "Continue your program" card on the Library
/// tab and the mini-player series-context lookup use, since they only care
/// about programs the user is currently progressing through.
///
/// Copied from [mySubscriptions].
class MySubscriptionsProvider
    extends AutoDisposeFutureProvider<List<SeriesSubscription>> {
  /// Current user's subscriptions.
  ///
  /// [activeOnly] = true is what the "Continue your program" card on the Library
  /// tab and the mini-player series-context lookup use, since they only care
  /// about programs the user is currently progressing through.
  ///
  /// Copied from [mySubscriptions].
  MySubscriptionsProvider({
    bool activeOnly = false,
  }) : this._internal(
          (ref) => mySubscriptions(
            ref as MySubscriptionsRef,
            activeOnly: activeOnly,
          ),
          from: mySubscriptionsProvider,
          name: r'mySubscriptionsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$mySubscriptionsHash,
          dependencies: MySubscriptionsFamily._dependencies,
          allTransitiveDependencies:
              MySubscriptionsFamily._allTransitiveDependencies,
          activeOnly: activeOnly,
        );

  MySubscriptionsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.activeOnly,
  }) : super.internal();

  final bool activeOnly;

  @override
  Override overrideWith(
    FutureOr<List<SeriesSubscription>> Function(MySubscriptionsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MySubscriptionsProvider._internal(
        (ref) => create(ref as MySubscriptionsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        activeOnly: activeOnly,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<SeriesSubscription>> createElement() {
    return _MySubscriptionsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MySubscriptionsProvider && other.activeOnly == activeOnly;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, activeOnly.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MySubscriptionsRef
    on AutoDisposeFutureProviderRef<List<SeriesSubscription>> {
  /// The parameter `activeOnly` of this provider.
  bool get activeOnly;
}

class _MySubscriptionsProviderElement
    extends AutoDisposeFutureProviderElement<List<SeriesSubscription>>
    with MySubscriptionsRef {
  _MySubscriptionsProviderElement(super.provider);

  @override
  bool get activeOnly => (origin as MySubscriptionsProvider).activeOnly;
}

String _$mySubscriptionForHash() => r'7cca4c12137694e839507fd9c1a5007bf26a9f83';

/// Subscription for a single series, or null if the user hasn't opted in.
/// Convenience derived from [mySubscriptions] so a single fetch covers
/// both "is subscribed?" and "list my programs."
///
/// Copied from [mySubscriptionFor].
@ProviderFor(mySubscriptionFor)
const mySubscriptionForProvider = MySubscriptionForFamily();

/// Subscription for a single series, or null if the user hasn't opted in.
/// Convenience derived from [mySubscriptions] so a single fetch covers
/// both "is subscribed?" and "list my programs."
///
/// Copied from [mySubscriptionFor].
class MySubscriptionForFamily extends Family<AsyncValue<SeriesSubscription?>> {
  /// Subscription for a single series, or null if the user hasn't opted in.
  /// Convenience derived from [mySubscriptions] so a single fetch covers
  /// both "is subscribed?" and "list my programs."
  ///
  /// Copied from [mySubscriptionFor].
  const MySubscriptionForFamily();

  /// Subscription for a single series, or null if the user hasn't opted in.
  /// Convenience derived from [mySubscriptions] so a single fetch covers
  /// both "is subscribed?" and "list my programs."
  ///
  /// Copied from [mySubscriptionFor].
  MySubscriptionForProvider call(
    String seriesId,
  ) {
    return MySubscriptionForProvider(
      seriesId,
    );
  }

  @override
  MySubscriptionForProvider getProviderOverride(
    covariant MySubscriptionForProvider provider,
  ) {
    return call(
      provider.seriesId,
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
  String? get name => r'mySubscriptionForProvider';
}

/// Subscription for a single series, or null if the user hasn't opted in.
/// Convenience derived from [mySubscriptions] so a single fetch covers
/// both "is subscribed?" and "list my programs."
///
/// Copied from [mySubscriptionFor].
class MySubscriptionForProvider
    extends AutoDisposeFutureProvider<SeriesSubscription?> {
  /// Subscription for a single series, or null if the user hasn't opted in.
  /// Convenience derived from [mySubscriptions] so a single fetch covers
  /// both "is subscribed?" and "list my programs."
  ///
  /// Copied from [mySubscriptionFor].
  MySubscriptionForProvider(
    String seriesId,
  ) : this._internal(
          (ref) => mySubscriptionFor(
            ref as MySubscriptionForRef,
            seriesId,
          ),
          from: mySubscriptionForProvider,
          name: r'mySubscriptionForProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$mySubscriptionForHash,
          dependencies: MySubscriptionForFamily._dependencies,
          allTransitiveDependencies:
              MySubscriptionForFamily._allTransitiveDependencies,
          seriesId: seriesId,
        );

  MySubscriptionForProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.seriesId,
  }) : super.internal();

  final String seriesId;

  @override
  Override overrideWith(
    FutureOr<SeriesSubscription?> Function(MySubscriptionForRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MySubscriptionForProvider._internal(
        (ref) => create(ref as MySubscriptionForRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        seriesId: seriesId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<SeriesSubscription?> createElement() {
    return _MySubscriptionForProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MySubscriptionForProvider && other.seriesId == seriesId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, seriesId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MySubscriptionForRef
    on AutoDisposeFutureProviderRef<SeriesSubscription?> {
  /// The parameter `seriesId` of this provider.
  String get seriesId;
}

class _MySubscriptionForProviderElement
    extends AutoDisposeFutureProviderElement<SeriesSubscription?>
    with MySubscriptionForRef {
  _MySubscriptionForProviderElement(super.provider);

  @override
  String get seriesId => (origin as MySubscriptionForProvider).seriesId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
