// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$libraryPlansHash() => r'b95394c173e8893bffba7596c6a035d8e87859a8';

/// Fetches library plans from the API, applying the current
/// [searchQueryProvider] and [selectedCategoryProvider] filters.
///
/// Calls GET /api/library/plans with optional `search` and `category` query
/// parameters derived from the active UI state providers. The provider is
/// auto-disposed when no widgets are listening so stale results are not held
/// in memory.
///
/// Usage in a [ConsumerWidget]:
/// ```dart
/// final plansAsync = ref.watch(libraryPlansProvider);
/// plansAsync.when(
///   data: (plans) => PlanGrid(plans: plans),
///   loading: () => const CircularProgressIndicator(),
///   error: (e, _) => ErrorMessage(e.toString()),
/// );
/// ```
///
/// Copied from [libraryPlans].
@ProviderFor(libraryPlans)
final libraryPlansProvider =
    AutoDisposeFutureProvider<List<LibraryPlanSummary>>.internal(
  libraryPlans,
  name: r'libraryPlansProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$libraryPlansHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LibraryPlansRef
    = AutoDisposeFutureProviderRef<List<LibraryPlanSummary>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
