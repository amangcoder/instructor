import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:instructor/providers/plan_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'favorites_providers.g.dart';

/// Fetches all plan IDs the current user has favorited.
///
/// Returns a [Set] for O(1) membership tests in [isFavoriteProvider].
/// Call `ref.invalidate(userFavoritesProvider)` after toggling to refresh.
@riverpod
Future<Set<String>> userFavorites(Ref ref) async {
  final service = ref.watch(planApiServiceProvider);
  final ids = await service.fetchFavorites();
  return ids.toSet();
}

/// Derived bool — true when [planId] is in the user's favorites list.
///
/// Recalculates automatically whenever [userFavoritesProvider] refreshes.
@riverpod
Future<bool> isFavorite(Ref ref, String planId) async {
  final favorites = await ref.watch(userFavoritesProvider.future);
  return favorites.contains(planId);
}
