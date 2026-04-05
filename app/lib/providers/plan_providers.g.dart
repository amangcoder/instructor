// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$planListHash() => r'dd4fdbf48e0968a0b4c6d78b470698aec11e9700';

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
/// Backed by [PlanRepository.watchAllPlans] — Plans are sorted by most recently
/// used (nulls last) and filtered in real-time as [searchQuery] or [category]
/// change.
///
/// Usage in a [ConsumerWidget]:
/// ```dart
/// final plans = ref.watch(planListProvider());
/// final filtered = ref.watch(planListProvider(
///   searchQuery: 'yoga',
///   category: PlanCategory.yoga,
/// ));
/// ```
///
/// Copied from [planList].
@ProviderFor(planList)
const planListProvider = PlanListFamily();

/// Reactive stream of all Plans, with optional search and category filters.
///
/// Backed by [PlanRepository.watchAllPlans] — Plans are sorted by most recently
/// used (nulls last) and filtered in real-time as [searchQuery] or [category]
/// change.
///
/// Usage in a [ConsumerWidget]:
/// ```dart
/// final plans = ref.watch(planListProvider());
/// final filtered = ref.watch(planListProvider(
///   searchQuery: 'yoga',
///   category: PlanCategory.yoga,
/// ));
/// ```
///
/// Copied from [planList].
class PlanListFamily extends Family<AsyncValue<List<Plan>>> {
  /// Reactive stream of all Plans, with optional search and category filters.
  ///
  /// Backed by [PlanRepository.watchAllPlans] — Plans are sorted by most recently
  /// used (nulls last) and filtered in real-time as [searchQuery] or [category]
  /// change.
  ///
  /// Usage in a [ConsumerWidget]:
  /// ```dart
  /// final plans = ref.watch(planListProvider());
  /// final filtered = ref.watch(planListProvider(
  ///   searchQuery: 'yoga',
  ///   category: PlanCategory.yoga,
  /// ));
  /// ```
  ///
  /// Copied from [planList].
  const PlanListFamily();

  /// Reactive stream of all Plans, with optional search and category filters.
  ///
  /// Backed by [PlanRepository.watchAllPlans] — Plans are sorted by most recently
  /// used (nulls last) and filtered in real-time as [searchQuery] or [category]
  /// change.
  ///
  /// Usage in a [ConsumerWidget]:
  /// ```dart
  /// final plans = ref.watch(planListProvider());
  /// final filtered = ref.watch(planListProvider(
  ///   searchQuery: 'yoga',
  ///   category: PlanCategory.yoga,
  /// ));
  /// ```
  ///
  /// Copied from [planList].
  PlanListProvider call({
    String? searchQuery,
    PlanCategory? category,
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
/// Backed by [PlanRepository.watchAllPlans] — Plans are sorted by most recently
/// used (nulls last) and filtered in real-time as [searchQuery] or [category]
/// change.
///
/// Usage in a [ConsumerWidget]:
/// ```dart
/// final plans = ref.watch(planListProvider());
/// final filtered = ref.watch(planListProvider(
///   searchQuery: 'yoga',
///   category: PlanCategory.yoga,
/// ));
/// ```
///
/// Copied from [planList].
class PlanListProvider extends AutoDisposeStreamProvider<List<Plan>> {
  /// Reactive stream of all Plans, with optional search and category filters.
  ///
  /// Backed by [PlanRepository.watchAllPlans] — Plans are sorted by most recently
  /// used (nulls last) and filtered in real-time as [searchQuery] or [category]
  /// change.
  ///
  /// Usage in a [ConsumerWidget]:
  /// ```dart
  /// final plans = ref.watch(planListProvider());
  /// final filtered = ref.watch(planListProvider(
  ///   searchQuery: 'yoga',
  ///   category: PlanCategory.yoga,
  /// ));
  /// ```
  ///
  /// Copied from [planList].
  PlanListProvider({
    String? searchQuery,
    PlanCategory? category,
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
  final PlanCategory? category;

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
  PlanCategory? get category;
}

class _PlanListProviderElement
    extends AutoDisposeStreamProviderElement<List<Plan>> with PlanListRef {
  _PlanListProviderElement(super.provider);

  @override
  String? get searchQuery => (origin as PlanListProvider).searchQuery;
  @override
  PlanCategory? get category => (origin as PlanListProvider).category;
}

String _$planByIdHash() => r'c104d497974af3818bee4cf7df8ae26ed5edecf0';

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
    int id,
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
    int id,
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

  final int id;

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
  int get id;
}

class _PlanByIdProviderElement extends AutoDisposeFutureProviderElement<Plan?>
    with PlanByIdRef {
  _PlanByIdProviderElement(super.provider);

  @override
  int get id => (origin as PlanByIdProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
