// Riverpod providers backing the Home screen.
//
// Local UI state for the personal-plan list (search query + category
// filter) and a [featuredLibraryPlansProvider] that surfaces a curated
// "For You" rail without sharing state with the Discover screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/models/library_plan_summary.dart';
import 'package:instructor/providers/plan_providers.dart';

/// Search query for the user's own plans on the Home screen.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Active category filter slug for the user's own plans on the Home screen,
/// or `null` when "All" is selected.
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// Fetches the unfiltered library catalogue so the Home "For You" rail can
/// render fresh recommendations independent of the Discover screen's
/// search/category filters.
final featuredLibraryPlansProvider =
    FutureProvider.autoDispose<List<LibraryPlanSummary>>((ref) {
  final service = ref.watch(planApiServiceProvider);
  return service.fetchLibraryPlans();
});
