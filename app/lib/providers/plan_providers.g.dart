// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$planListHash() => r'7cd0845e7aa7bd1549557d9f41c180cd034d973c';

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

/// Reactive stream of all Plans, with optional search and category filters.
///
/// Backed by [PlanRepository.watchUserPlans] — Plans are sorted by most recently
/// used (nulls last) and filtered in real-time as [searchQuery] or [category]
/// change.
///
/// Usage in a [ConsumerWidget]:
/// ```dart
/// final plans = ref.watch(planListProvider());
/// final filtered = ref.watch(planListProvider(
///   searchQuery: 'yoga',
///   category: 'yoga',
/// ));
/// ```
///
/// Copied from [planList].
@ProviderFor(planList)
const planListProvider = PlanListFamily();

/// Reactive stream of all Plans, with optional search and category filters.
///
/// Backed by [PlanRepository.watchUserPlans] — Plans are sorted by most recently
/// used (nulls last) and filtered in real-time as [searchQuery] or [category]
/// change.
///
/// Usage in a [ConsumerWidget]:
/// ```dart
/// final plans = ref.watch(planListProvider());
/// final filtered = ref.watch(planListProvider(
///   searchQuery: 'yoga',
///   category: 'yoga',
/// ));
/// ```
///
/// Copied from [planList].
class PlanListFamily extends Family<AsyncValue<List<Plan>>> {
  /// Reactive stream of all Plans, with optional search and category filters.
  ///
  /// Backed by [PlanRepository.watchUserPlans] — Plans are sorted by most recently
  /// used (nulls last) and filtered in real-time as [searchQuery] or [category]
  /// change.
  ///
  /// Usage in a [ConsumerWidget]:
  /// ```dart
  /// final plans = ref.watch(planListProvider());
  /// final filtered = ref.watch(planListProvider(
  ///   searchQuery: 'yoga',
  ///   category: 'yoga',
  /// ));
  /// ```
  ///
  /// Copied from [planList].
  const PlanListFamily();

  /// Reactive stream of all Plans, with optional search and category filters.
  ///
  /// Backed by [PlanRepository.watchUserPlans] — Plans are sorted by most recently
  /// used (nulls last) and filtered in real-time as [searchQuery] or [category]
  /// change.
  ///
  /// Usage in a [ConsumerWidget]:
  /// ```dart
  /// final plans = ref.watch(planListProvider());
  /// final filtered = ref.watch(planListProvider(
  ///   searchQuery: 'yoga',
  ///   category: 'yoga',
  /// ));
  /// ```
  ///
  /// Copied from [planList].
  PlanListProvider call({
    String? searchQuery,
    String? category,
  }) {
    return PlanListProvider(
      searchQuery: searchQuery,
      category: category,
    );
  }

  @override
  PlanListProvider getProviderOverride(
    covariant PlanListProvider provider,
  ) {
    return call(
      searchQuery: provider.searchQuery,
      category: provider.category,
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
  String? get name => r'planListProvider';
}

/// Reactive stream of all Plans, with optional search and category filters.
///
/// Backed by [PlanRepository.watchUserPlans] — Plans are sorted by most recently
/// used (nulls last) and filtered in real-time as [searchQuery] or [category]
/// change.
///
/// Usage in a [ConsumerWidget]:
/// ```dart
/// final plans = ref.watch(planListProvider());
/// final filtered = ref.watch(planListProvider(
///   searchQuery: 'yoga',
///   category: 'yoga',
/// ));
/// ```
///
/// Copied from [planList].
class PlanListProvider extends AutoDisposeStreamProvider<List<Plan>> {
  /// Reactive stream of all Plans, with optional search and category filters.
  ///
  /// Backed by [PlanRepository.watchUserPlans] — Plans are sorted by most recently
  /// used (nulls last) and filtered in real-time as [searchQuery] or [category]
  /// change.
  ///
  /// Usage in a [ConsumerWidget]:
  /// ```dart
  /// final plans = ref.watch(planListProvider());
  /// final filtered = ref.watch(planListProvider(
  ///   searchQuery: 'yoga',
  ///   category: 'yoga',
  /// ));
  /// ```
  ///
  /// Copied from [planList].
  PlanListProvider({
    String? searchQuery,
    String? category,
  }) : this._internal(
          (ref) => planList(
            ref as PlanListRef,
            searchQuery: searchQuery,
            category: category,
          ),
          from: planListProvider,
          name: r'planListProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$planListHash,
          dependencies: PlanListFamily._dependencies,
          allTransitiveDependencies: PlanListFamily._allTransitiveDependencies,
          searchQuery: searchQuery,
          category: category,
        );

  PlanListProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.searchQuery,
    required this.category,
  }) : super.internal();

  final String? searchQuery;
  final String? category;

  @override
  Override overrideWith(
    Stream<List<Plan>> Function(PlanListRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PlanListProvider._internal(
        (ref) => create(ref as PlanListRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        searchQuery: searchQuery,
        category: category,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<Plan>> createElement() {
    return _PlanListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanListProvider &&
        other.searchQuery == searchQuery &&
        other.category == category;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, searchQuery.hashCode);
    hash = _SystemHash.combine(hash, category.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PlanListRef on AutoDisposeStreamProviderRef<List<Plan>> {
  /// The parameter `searchQuery` of this provider.
  String? get searchQuery;

  /// The parameter `category` of this provider.
  String? get category;
}

class _PlanListProviderElement
    extends AutoDisposeStreamProviderElement<List<Plan>> with PlanListRef {
  _PlanListProviderElement(super.provider);

  @override
  String? get searchQuery => (origin as PlanListProvider).searchQuery;
  @override
  String? get category => (origin as PlanListProvider).category;
}

String _$planByIdHash() => r'4794472ca254454d962cf1779bb8bcafc70eb9b4';

/// Fetches a single Plan by [id].
///
/// Returns null when the Plan does not exist (e.g. after deletion).
///
/// Copied from [planById].
@ProviderFor(planById)
const planByIdProvider = PlanByIdFamily();

/// Fetches a single Plan by [id].
///
/// Returns null when the Plan does not exist (e.g. after deletion).
///
/// Copied from [planById].
class PlanByIdFamily extends Family<AsyncValue<Plan?>> {
  /// Fetches a single Plan by [id].
  ///
  /// Returns null when the Plan does not exist (e.g. after deletion).
  ///
  /// Copied from [planById].
  const PlanByIdFamily();

  /// Fetches a single Plan by [id].
  ///
  /// Returns null when the Plan does not exist (e.g. after deletion).
  ///
  /// Copied from [planById].
  PlanByIdProvider call(
    String id,
  ) {
    return PlanByIdProvider(
      id,
    );
  }

  @override
  PlanByIdProvider getProviderOverride(
    covariant PlanByIdProvider provider,
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
  String? get name => r'planByIdProvider';
}

/// Fetches a single Plan by [id].
///
/// Returns null when the Plan does not exist (e.g. after deletion).
///
/// Copied from [planById].
class PlanByIdProvider extends AutoDisposeFutureProvider<Plan?> {
  /// Fetches a single Plan by [id].
  ///
  /// Returns null when the Plan does not exist (e.g. after deletion).
  ///
  /// Copied from [planById].
  PlanByIdProvider(
    String id,
  ) : this._internal(
          (ref) => planById(
            ref as PlanByIdRef,
            id,
          ),
          from: planByIdProvider,
          name: r'planByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$planByIdHash,
          dependencies: PlanByIdFamily._dependencies,
          allTransitiveDependencies: PlanByIdFamily._allTransitiveDependencies,
          id: id,
        );

  PlanByIdProvider._internal(
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
    FutureOr<Plan?> Function(PlanByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PlanByIdProvider._internal(
        (ref) => create(ref as PlanByIdRef),
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
  AutoDisposeFutureProviderElement<Plan?> createElement() {
    return _PlanByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanByIdProvider && other.id == id;
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
mixin PlanByIdRef on AutoDisposeFutureProviderRef<Plan?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _PlanByIdProviderElement extends AutoDisposeFutureProviderElement<Plan?>
    with PlanByIdRef {
  _PlanByIdProviderElement(super.provider);

  @override
  String get id => (origin as PlanByIdProvider).id;
}

String _$planRepositoryHash() => r'73acda42ef4b77261d34ffc182beead747c91992';

/// Singleton [PlanRepository] provider.
///
/// [keepAlive: true] — the repository must outlive any individual screen so
/// that watch streams remain active and the database is not torn down.
///
/// Backed by [ApiPlanRepository]: all mutations are routed through the backend
/// API first; the local SQLite cache is updated on success so that
/// [watchUserPlans] streams remain reactive.
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
String _$planApiServiceHash() => r'1ec4986c6c05e19f4cb4ded26441db162a978725';

/// Keep-alive [PlanApiService] provider shared across the app.
///
/// Using [keepAlive] ensures a single [PlanApiService] instance is reused for
/// the lifetime of the application, avoiding redundant HTTP client creation.
///
/// Copied from [planApiService].
@ProviderFor(planApiService)
final planApiServiceProvider = Provider<PlanApiService>.internal(
  planApiService,
  name: r'planApiServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$planApiServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlanApiServiceRef = ProviderRef<PlanApiService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
