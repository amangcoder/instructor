import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/providers/favorites_providers.dart';
import 'package:instructor/providers/plan_providers.dart';

/// Heart icon button that toggles a library plan in/out of the user's
/// Favorites list.
///
/// Reads [isFavoriteProvider] to show the filled/outlined state. On tap it
/// calls the toggle API and invalidates [userFavoritesProvider] so all
/// [isFavoriteProvider] instances refresh automatically.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({required this.planId, super.key});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteAsync = ref.watch(isFavoriteProvider(planId));
    final cs = Theme.of(context).colorScheme;

    final isFav = favoriteAsync.valueOrNull ?? false;
    final isLoading = favoriteAsync.isLoading;

    return Semantics(
      button: true,
      label: isFav ? 'Remove from favorites' : 'Add to favorites',
      child: GestureDetector(
        onTap: isLoading ? null : () => _toggle(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 22,
            color: isFav ? cs.error : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final service = ref.read(planApiServiceProvider);
    try {
      await service.toggleFavorite(planId);
      ref.invalidate(userFavoritesProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update favorites. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
