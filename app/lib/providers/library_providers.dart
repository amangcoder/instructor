/// Riverpod providers for the Plan Library screen.
///
/// Provides simple [StateProvider]s for UI state (tab index, search query,
/// category filter) and a [libraryPlansProvider] that fetches from the server
/// API with the active filters applied.
library library_providers;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/models/library_plan_summary.dart';
import 'package:instructor/providers/plan_providers.dart';

part 'library_providers.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UI state providers
// ─────────────────────────────────────────────────────────────────────────────

/// Tracks the currently selected tab index in the Plan Library screen.
///
/// 0 = My Plans tab, 1 = Browse Library tab.
final libraryTabIndexProvider = StateProvider<int>((ref) => 0);

/// Holds the current search query string entered in the library search bar.
///
/// Updated on every keystroke; passed to [libraryPlansProvider] for API-side
/// filtering.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Holds the active category filter string, or null when "All" is selected.
///
/// The raw category name string (e.g. `'yoga'`, `'meditation'`) is passed
/// directly to the API as a query parameter via [libraryPlansProvider].
/// Null means no category filter is applied.
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// ─────────────────────────────────────────────────────────────────────────────
// Library plans provider
// ─────────────────────────────────────────────────────────────────────────────

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
@riverpod
Future<List<LibraryPlanSummary>> libraryPlans(Ref ref) {
  final service = ref.watch(planApiServiceProvider);
  final search = ref.watch(searchQueryProvider);
  final category = ref.watch(selectedCategoryProvider);

  return service.fetchLibraryPlans(
    search: search.isEmpty ? null : search,
    category: category,
  );
}
