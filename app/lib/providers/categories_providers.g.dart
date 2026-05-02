// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'categories_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$categoriesHash() => r'c5ae4f6cd7f24ec69ad2807c32bd414be1ce6423';

/// Fetches all published categories from the server.
///
/// Calls `GET /api/categories` which returns only `is_published=true`
/// categories ordered by their `sort_order`.  Returns an empty list when no
/// categories have been published yet.
///
/// ### Error handling
/// Any non-2xx HTTP response or network failure is wrapped in [ApiException]
/// and surfaced as `AsyncError` — the UI should handle both the loading and
/// error states via `.when()`.
///
/// Usage:
/// ```dart
/// final cats = ref.watch(categoriesProvider);
/// cats.when(
///   data:    (list) => ...,
///   loading: () => const CircularProgressIndicator(),
///   error:   (e, _) => Text('Error: $e'),
/// );
/// ```
///
/// Copied from [categories].
@ProviderFor(categories)
final categoriesProvider = AutoDisposeFutureProvider<List<Category>>.internal(
  categories,
  name: r'categoriesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$categoriesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CategoriesRef = AutoDisposeFutureProviderRef<List<Category>>;
String _$seriesByCategoryHash() => r'41d974a7bbe358b28a53adbc301a867216fc0eb4';

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

/// Fetches all published series that belong to a given category [slug].
///
/// Calls `GET /api/series?categorySlug=<slug>`.  Returns an ordered list of
/// [Series] in the server-defined sort order.  An empty list is returned when
/// the category exists but has no published series.
///
/// ### Error handling
/// Non-2xx responses are surfaced as `AsyncError`.
/// The category [slug] is URL-encoded automatically by [Uri.replace].
///
/// Usage:
/// ```dart
/// final series = ref.watch(seriesByCategoryProvider('meditation'));
/// series.when(
///   data:    (list) => ...,
///   loading: () => const CircularProgressIndicator(),
///   error:   (e, _) => Text('Error: $e'),
/// );
/// ```
///
/// Copied from [seriesByCategory].
@ProviderFor(seriesByCategory)
const seriesByCategoryProvider = SeriesByCategoryFamily();

/// Fetches all published series that belong to a given category [slug].
///
/// Calls `GET /api/series?categorySlug=<slug>`.  Returns an ordered list of
/// [Series] in the server-defined sort order.  An empty list is returned when
/// the category exists but has no published series.
///
/// ### Error handling
/// Non-2xx responses are surfaced as `AsyncError`.
/// The category [slug] is URL-encoded automatically by [Uri.replace].
///
/// Usage:
/// ```dart
/// final series = ref.watch(seriesByCategoryProvider('meditation'));
/// series.when(
///   data:    (list) => ...,
///   loading: () => const CircularProgressIndicator(),
///   error:   (e, _) => Text('Error: $e'),
/// );
/// ```
///
/// Copied from [seriesByCategory].
class SeriesByCategoryFamily extends Family<AsyncValue<List<Series>>> {
  /// Fetches all published series that belong to a given category [slug].
  ///
  /// Calls `GET /api/series?categorySlug=<slug>`.  Returns an ordered list of
  /// [Series] in the server-defined sort order.  An empty list is returned when
  /// the category exists but has no published series.
  ///
  /// ### Error handling
  /// Non-2xx responses are surfaced as `AsyncError`.
  /// The category [slug] is URL-encoded automatically by [Uri.replace].
  ///
  /// Usage:
  /// ```dart
  /// final series = ref.watch(seriesByCategoryProvider('meditation'));
  /// series.when(
  ///   data:    (list) => ...,
  ///   loading: () => const CircularProgressIndicator(),
  ///   error:   (e, _) => Text('Error: $e'),
  /// );
  /// ```
  ///
  /// Copied from [seriesByCategory].
  const SeriesByCategoryFamily();

  /// Fetches all published series that belong to a given category [slug].
  ///
  /// Calls `GET /api/series?categorySlug=<slug>`.  Returns an ordered list of
  /// [Series] in the server-defined sort order.  An empty list is returned when
  /// the category exists but has no published series.
  ///
  /// ### Error handling
  /// Non-2xx responses are surfaced as `AsyncError`.
  /// The category [slug] is URL-encoded automatically by [Uri.replace].
  ///
  /// Usage:
  /// ```dart
  /// final series = ref.watch(seriesByCategoryProvider('meditation'));
  /// series.when(
  ///   data:    (list) => ...,
  ///   loading: () => const CircularProgressIndicator(),
  ///   error:   (e, _) => Text('Error: $e'),
  /// );
  /// ```
  ///
  /// Copied from [seriesByCategory].
  SeriesByCategoryProvider call(
    String slug,
  ) {
    return SeriesByCategoryProvider(
      slug,
    );
  }

  @override
  SeriesByCategoryProvider getProviderOverride(
    covariant SeriesByCategoryProvider provider,
  ) {
    return call(
      provider.slug,
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
  String? get name => r'seriesByCategoryProvider';
}

/// Fetches all published series that belong to a given category [slug].
///
/// Calls `GET /api/series?categorySlug=<slug>`.  Returns an ordered list of
/// [Series] in the server-defined sort order.  An empty list is returned when
/// the category exists but has no published series.
///
/// ### Error handling
/// Non-2xx responses are surfaced as `AsyncError`.
/// The category [slug] is URL-encoded automatically by [Uri.replace].
///
/// Usage:
/// ```dart
/// final series = ref.watch(seriesByCategoryProvider('meditation'));
/// series.when(
///   data:    (list) => ...,
///   loading: () => const CircularProgressIndicator(),
///   error:   (e, _) => Text('Error: $e'),
/// );
/// ```
///
/// Copied from [seriesByCategory].
class SeriesByCategoryProvider extends AutoDisposeFutureProvider<List<Series>> {
  /// Fetches all published series that belong to a given category [slug].
  ///
  /// Calls `GET /api/series?categorySlug=<slug>`.  Returns an ordered list of
  /// [Series] in the server-defined sort order.  An empty list is returned when
  /// the category exists but has no published series.
  ///
  /// ### Error handling
  /// Non-2xx responses are surfaced as `AsyncError`.
  /// The category [slug] is URL-encoded automatically by [Uri.replace].
  ///
  /// Usage:
  /// ```dart
  /// final series = ref.watch(seriesByCategoryProvider('meditation'));
  /// series.when(
  ///   data:    (list) => ...,
  ///   loading: () => const CircularProgressIndicator(),
  ///   error:   (e, _) => Text('Error: $e'),
  /// );
  /// ```
  ///
  /// Copied from [seriesByCategory].
  SeriesByCategoryProvider(
    String slug,
  ) : this._internal(
          (ref) => seriesByCategory(
            ref as SeriesByCategoryRef,
            slug,
          ),
          from: seriesByCategoryProvider,
          name: r'seriesByCategoryProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$seriesByCategoryHash,
          dependencies: SeriesByCategoryFamily._dependencies,
          allTransitiveDependencies:
              SeriesByCategoryFamily._allTransitiveDependencies,
          slug: slug,
        );

  SeriesByCategoryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.slug,
  }) : super.internal();

  final String slug;

  @override
  Override overrideWith(
    FutureOr<List<Series>> Function(SeriesByCategoryRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SeriesByCategoryProvider._internal(
        (ref) => create(ref as SeriesByCategoryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        slug: slug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Series>> createElement() {
    return _SeriesByCategoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SeriesByCategoryProvider && other.slug == slug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, slug.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SeriesByCategoryRef on AutoDisposeFutureProviderRef<List<Series>> {
  /// The parameter `slug` of this provider.
  String get slug;
}

class _SeriesByCategoryProviderElement
    extends AutoDisposeFutureProviderElement<List<Series>>
    with SeriesByCategoryRef {
  _SeriesByCategoryProviderElement(super.provider);

  @override
  String get slug => (origin as SeriesByCategoryProvider).slug;
}

String _$planTreeHash() => r'72fb529f4db0b32f9b8ef46ccdd5de14c0b8fda0';

/// Fetches a [Plan] with its complete sub-plan tree up to depth 3.
///
/// Calls `GET /api/plans/:planId/tree`.  The root [Plan] is returned with its
/// [Plan.children] list populated to at most 3 levels deep:
///
/// ```
/// Root Plan                 (depth 0)
///   └─ Sub-plan A           (depth 1)
///        └─ Sub-plan A.1    (depth 2)
///             └─ Sub-plan A.1.a  (depth 3, leaf)
/// ```
///
/// Each child plan also carries its [Plan.voices] list so callers can check
/// TTS readiness without additional fetches.
///
/// ### Error handling
/// - `404` → plan not found; surfaced as `AsyncError`.
/// - `422` → depth constraint violated; surfaced as `AsyncError`.
/// - Network failures → surfaced as `AsyncError`.
///
/// Usage:
/// ```dart
/// final tree = ref.watch(planTreeProvider('plan-uuid-1234'));
/// tree.when(
///   data:    (plan) => PlanTreeWidget(plan: plan),
///   loading: () => const CircularProgressIndicator(),
///   error:   (e, _) => Text('Error: $e'),
/// );
/// ```
///
/// Copied from [planTree].
@ProviderFor(planTree)
const planTreeProvider = PlanTreeFamily();

/// Fetches a [Plan] with its complete sub-plan tree up to depth 3.
///
/// Calls `GET /api/plans/:planId/tree`.  The root [Plan] is returned with its
/// [Plan.children] list populated to at most 3 levels deep:
///
/// ```
/// Root Plan                 (depth 0)
///   └─ Sub-plan A           (depth 1)
///        └─ Sub-plan A.1    (depth 2)
///             └─ Sub-plan A.1.a  (depth 3, leaf)
/// ```
///
/// Each child plan also carries its [Plan.voices] list so callers can check
/// TTS readiness without additional fetches.
///
/// ### Error handling
/// - `404` → plan not found; surfaced as `AsyncError`.
/// - `422` → depth constraint violated; surfaced as `AsyncError`.
/// - Network failures → surfaced as `AsyncError`.
///
/// Usage:
/// ```dart
/// final tree = ref.watch(planTreeProvider('plan-uuid-1234'));
/// tree.when(
///   data:    (plan) => PlanTreeWidget(plan: plan),
///   loading: () => const CircularProgressIndicator(),
///   error:   (e, _) => Text('Error: $e'),
/// );
/// ```
///
/// Copied from [planTree].
class PlanTreeFamily extends Family<AsyncValue<Plan>> {
  /// Fetches a [Plan] with its complete sub-plan tree up to depth 3.
  ///
  /// Calls `GET /api/plans/:planId/tree`.  The root [Plan] is returned with its
  /// [Plan.children] list populated to at most 3 levels deep:
  ///
  /// ```
  /// Root Plan                 (depth 0)
  ///   └─ Sub-plan A           (depth 1)
  ///        └─ Sub-plan A.1    (depth 2)
  ///             └─ Sub-plan A.1.a  (depth 3, leaf)
  /// ```
  ///
  /// Each child plan also carries its [Plan.voices] list so callers can check
  /// TTS readiness without additional fetches.
  ///
  /// ### Error handling
  /// - `404` → plan not found; surfaced as `AsyncError`.
  /// - `422` → depth constraint violated; surfaced as `AsyncError`.
  /// - Network failures → surfaced as `AsyncError`.
  ///
  /// Usage:
  /// ```dart
  /// final tree = ref.watch(planTreeProvider('plan-uuid-1234'));
  /// tree.when(
  ///   data:    (plan) => PlanTreeWidget(plan: plan),
  ///   loading: () => const CircularProgressIndicator(),
  ///   error:   (e, _) => Text('Error: $e'),
  /// );
  /// ```
  ///
  /// Copied from [planTree].
  const PlanTreeFamily();

  /// Fetches a [Plan] with its complete sub-plan tree up to depth 3.
  ///
  /// Calls `GET /api/plans/:planId/tree`.  The root [Plan] is returned with its
  /// [Plan.children] list populated to at most 3 levels deep:
  ///
  /// ```
  /// Root Plan                 (depth 0)
  ///   └─ Sub-plan A           (depth 1)
  ///        └─ Sub-plan A.1    (depth 2)
  ///             └─ Sub-plan A.1.a  (depth 3, leaf)
  /// ```
  ///
  /// Each child plan also carries its [Plan.voices] list so callers can check
  /// TTS readiness without additional fetches.
  ///
  /// ### Error handling
  /// - `404` → plan not found; surfaced as `AsyncError`.
  /// - `422` → depth constraint violated; surfaced as `AsyncError`.
  /// - Network failures → surfaced as `AsyncError`.
  ///
  /// Usage:
  /// ```dart
  /// final tree = ref.watch(planTreeProvider('plan-uuid-1234'));
  /// tree.when(
  ///   data:    (plan) => PlanTreeWidget(plan: plan),
  ///   loading: () => const CircularProgressIndicator(),
  ///   error:   (e, _) => Text('Error: $e'),
  /// );
  /// ```
  ///
  /// Copied from [planTree].
  PlanTreeProvider call(
    String planId,
  ) {
    return PlanTreeProvider(
      planId,
    );
  }

  @override
  PlanTreeProvider getProviderOverride(
    covariant PlanTreeProvider provider,
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
  String? get name => r'planTreeProvider';
}

/// Fetches a [Plan] with its complete sub-plan tree up to depth 3.
///
/// Calls `GET /api/plans/:planId/tree`.  The root [Plan] is returned with its
/// [Plan.children] list populated to at most 3 levels deep:
///
/// ```
/// Root Plan                 (depth 0)
///   └─ Sub-plan A           (depth 1)
///        └─ Sub-plan A.1    (depth 2)
///             └─ Sub-plan A.1.a  (depth 3, leaf)
/// ```
///
/// Each child plan also carries its [Plan.voices] list so callers can check
/// TTS readiness without additional fetches.
///
/// ### Error handling
/// - `404` → plan not found; surfaced as `AsyncError`.
/// - `422` → depth constraint violated; surfaced as `AsyncError`.
/// - Network failures → surfaced as `AsyncError`.
///
/// Usage:
/// ```dart
/// final tree = ref.watch(planTreeProvider('plan-uuid-1234'));
/// tree.when(
///   data:    (plan) => PlanTreeWidget(plan: plan),
///   loading: () => const CircularProgressIndicator(),
///   error:   (e, _) => Text('Error: $e'),
/// );
/// ```
///
/// Copied from [planTree].
class PlanTreeProvider extends AutoDisposeFutureProvider<Plan> {
  /// Fetches a [Plan] with its complete sub-plan tree up to depth 3.
  ///
  /// Calls `GET /api/plans/:planId/tree`.  The root [Plan] is returned with its
  /// [Plan.children] list populated to at most 3 levels deep:
  ///
  /// ```
  /// Root Plan                 (depth 0)
  ///   └─ Sub-plan A           (depth 1)
  ///        └─ Sub-plan A.1    (depth 2)
  ///             └─ Sub-plan A.1.a  (depth 3, leaf)
  /// ```
  ///
  /// Each child plan also carries its [Plan.voices] list so callers can check
  /// TTS readiness without additional fetches.
  ///
  /// ### Error handling
  /// - `404` → plan not found; surfaced as `AsyncError`.
  /// - `422` → depth constraint violated; surfaced as `AsyncError`.
  /// - Network failures → surfaced as `AsyncError`.
  ///
  /// Usage:
  /// ```dart
  /// final tree = ref.watch(planTreeProvider('plan-uuid-1234'));
  /// tree.when(
  ///   data:    (plan) => PlanTreeWidget(plan: plan),
  ///   loading: () => const CircularProgressIndicator(),
  ///   error:   (e, _) => Text('Error: $e'),
  /// );
  /// ```
  ///
  /// Copied from [planTree].
  PlanTreeProvider(
    String planId,
  ) : this._internal(
          (ref) => planTree(
            ref as PlanTreeRef,
            planId,
          ),
          from: planTreeProvider,
          name: r'planTreeProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$planTreeHash,
          dependencies: PlanTreeFamily._dependencies,
          allTransitiveDependencies: PlanTreeFamily._allTransitiveDependencies,
          planId: planId,
        );

  PlanTreeProvider._internal(
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
    FutureOr<Plan> Function(PlanTreeRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PlanTreeProvider._internal(
        (ref) => create(ref as PlanTreeRef),
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
  AutoDisposeFutureProviderElement<Plan> createElement() {
    return _PlanTreeProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanTreeProvider && other.planId == planId;
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
mixin PlanTreeRef on AutoDisposeFutureProviderRef<Plan> {
  /// The parameter `planId` of this provider.
  String get planId;
}

class _PlanTreeProviderElement extends AutoDisposeFutureProviderElement<Plan>
    with PlanTreeRef {
  _PlanTreeProviderElement(super.provider);

  @override
  String get planId => (origin as PlanTreeProvider).planId;
}

String _$selectedVoiceHash() => r'75994ab6793e6ca1a96d7b94e2262ef51501dcd3';

abstract class _$SelectedVoice extends BuildlessAutoDisposeNotifier<Voice?> {
  late final String planId;

  Voice? build(
    String planId,
  );
}

/// Per-plan in-memory voice preference.
///
/// Tracks which [Voice] the user has selected for a specific [planId].
/// Defaults to `null`, which signals callers to fall back to the platform
/// TTS voice (see `FlutterTtsFallback` in the architecture).
///
/// This state is **session-scoped** — it is never persisted to disk or the
/// backend, and resets to `null` every app launch.
///
/// ### Selecting a voice
/// ```dart
/// // Read the current selection (null = no preference):
/// final voice = ref.watch(selectedVoiceProvider('plan-uuid'));
///
/// // Update the selection:
/// ref.read(selectedVoiceProvider('plan-uuid').notifier).select(myVoice);
///
/// // Clear the selection (fall back to platform TTS):
/// ref.read(selectedVoiceProvider('plan-uuid').notifier).select(null);
/// ```
///
/// Copied from [SelectedVoice].
@ProviderFor(SelectedVoice)
const selectedVoiceProvider = SelectedVoiceFamily();

/// Per-plan in-memory voice preference.
///
/// Tracks which [Voice] the user has selected for a specific [planId].
/// Defaults to `null`, which signals callers to fall back to the platform
/// TTS voice (see `FlutterTtsFallback` in the architecture).
///
/// This state is **session-scoped** — it is never persisted to disk or the
/// backend, and resets to `null` every app launch.
///
/// ### Selecting a voice
/// ```dart
/// // Read the current selection (null = no preference):
/// final voice = ref.watch(selectedVoiceProvider('plan-uuid'));
///
/// // Update the selection:
/// ref.read(selectedVoiceProvider('plan-uuid').notifier).select(myVoice);
///
/// // Clear the selection (fall back to platform TTS):
/// ref.read(selectedVoiceProvider('plan-uuid').notifier).select(null);
/// ```
///
/// Copied from [SelectedVoice].
class SelectedVoiceFamily extends Family<Voice?> {
  /// Per-plan in-memory voice preference.
  ///
  /// Tracks which [Voice] the user has selected for a specific [planId].
  /// Defaults to `null`, which signals callers to fall back to the platform
  /// TTS voice (see `FlutterTtsFallback` in the architecture).
  ///
  /// This state is **session-scoped** — it is never persisted to disk or the
  /// backend, and resets to `null` every app launch.
  ///
  /// ### Selecting a voice
  /// ```dart
  /// // Read the current selection (null = no preference):
  /// final voice = ref.watch(selectedVoiceProvider('plan-uuid'));
  ///
  /// // Update the selection:
  /// ref.read(selectedVoiceProvider('plan-uuid').notifier).select(myVoice);
  ///
  /// // Clear the selection (fall back to platform TTS):
  /// ref.read(selectedVoiceProvider('plan-uuid').notifier).select(null);
  /// ```
  ///
  /// Copied from [SelectedVoice].
  const SelectedVoiceFamily();

  /// Per-plan in-memory voice preference.
  ///
  /// Tracks which [Voice] the user has selected for a specific [planId].
  /// Defaults to `null`, which signals callers to fall back to the platform
  /// TTS voice (see `FlutterTtsFallback` in the architecture).
  ///
  /// This state is **session-scoped** — it is never persisted to disk or the
  /// backend, and resets to `null` every app launch.
  ///
  /// ### Selecting a voice
  /// ```dart
  /// // Read the current selection (null = no preference):
  /// final voice = ref.watch(selectedVoiceProvider('plan-uuid'));
  ///
  /// // Update the selection:
  /// ref.read(selectedVoiceProvider('plan-uuid').notifier).select(myVoice);
  ///
  /// // Clear the selection (fall back to platform TTS):
  /// ref.read(selectedVoiceProvider('plan-uuid').notifier).select(null);
  /// ```
  ///
  /// Copied from [SelectedVoice].
  SelectedVoiceProvider call(
    String planId,
  ) {
    return SelectedVoiceProvider(
      planId,
    );
  }

  @override
  SelectedVoiceProvider getProviderOverride(
    covariant SelectedVoiceProvider provider,
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
  String? get name => r'selectedVoiceProvider';
}

/// Per-plan in-memory voice preference.
///
/// Tracks which [Voice] the user has selected for a specific [planId].
/// Defaults to `null`, which signals callers to fall back to the platform
/// TTS voice (see `FlutterTtsFallback` in the architecture).
///
/// This state is **session-scoped** — it is never persisted to disk or the
/// backend, and resets to `null` every app launch.
///
/// ### Selecting a voice
/// ```dart
/// // Read the current selection (null = no preference):
/// final voice = ref.watch(selectedVoiceProvider('plan-uuid'));
///
/// // Update the selection:
/// ref.read(selectedVoiceProvider('plan-uuid').notifier).select(myVoice);
///
/// // Clear the selection (fall back to platform TTS):
/// ref.read(selectedVoiceProvider('plan-uuid').notifier).select(null);
/// ```
///
/// Copied from [SelectedVoice].
class SelectedVoiceProvider
    extends AutoDisposeNotifierProviderImpl<SelectedVoice, Voice?> {
  /// Per-plan in-memory voice preference.
  ///
  /// Tracks which [Voice] the user has selected for a specific [planId].
  /// Defaults to `null`, which signals callers to fall back to the platform
  /// TTS voice (see `FlutterTtsFallback` in the architecture).
  ///
  /// This state is **session-scoped** — it is never persisted to disk or the
  /// backend, and resets to `null` every app launch.
  ///
  /// ### Selecting a voice
  /// ```dart
  /// // Read the current selection (null = no preference):
  /// final voice = ref.watch(selectedVoiceProvider('plan-uuid'));
  ///
  /// // Update the selection:
  /// ref.read(selectedVoiceProvider('plan-uuid').notifier).select(myVoice);
  ///
  /// // Clear the selection (fall back to platform TTS):
  /// ref.read(selectedVoiceProvider('plan-uuid').notifier).select(null);
  /// ```
  ///
  /// Copied from [SelectedVoice].
  SelectedVoiceProvider(
    String planId,
  ) : this._internal(
          () => SelectedVoice()..planId = planId,
          from: selectedVoiceProvider,
          name: r'selectedVoiceProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$selectedVoiceHash,
          dependencies: SelectedVoiceFamily._dependencies,
          allTransitiveDependencies:
              SelectedVoiceFamily._allTransitiveDependencies,
          planId: planId,
        );

  SelectedVoiceProvider._internal(
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
  Voice? runNotifierBuild(
    covariant SelectedVoice notifier,
  ) {
    return notifier.build(
      planId,
    );
  }

  @override
  Override overrideWith(SelectedVoice Function() create) {
    return ProviderOverride(
      origin: this,
      override: SelectedVoiceProvider._internal(
        () => create()..planId = planId,
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
  AutoDisposeNotifierProviderElement<SelectedVoice, Voice?> createElement() {
    return _SelectedVoiceProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SelectedVoiceProvider && other.planId == planId;
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
mixin SelectedVoiceRef on AutoDisposeNotifierProviderRef<Voice?> {
  /// The parameter `planId` of this provider.
  String get planId;
}

class _SelectedVoiceProviderElement
    extends AutoDisposeNotifierProviderElement<SelectedVoice, Voice?>
    with SelectedVoiceRef {
  _SelectedVoiceProviderElement(super.provider);

  @override
  String get planId => (origin as SelectedVoiceProvider).planId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
