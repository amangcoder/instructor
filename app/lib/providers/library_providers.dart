import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/models/enums.dart';

/// Holds the current search query string entered in the library search bar.
///
/// Updated on every keystroke; passed to [planListProvider] for SQLite-side
/// filtering.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Holds the active [PlanCategory] filter, or null when "All" is selected.
///
/// Passed to [planListProvider] for SQLite-side filtering.
final selectedCategoryProvider = StateProvider<PlanCategory?>((ref) => null);
