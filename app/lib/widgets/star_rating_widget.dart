import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/providers/ratings_providers.dart';
import 'package:instructor/services/plan_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StarRatingWidget
// ─────────────────────────────────────────────────────────────────────────────

/// Displays aggregate star rating for a library plan and lets the user submit
/// or update their own 1–5 star rating by tapping a star.
///
/// Shows average rating (one decimal place) and total count when the plan has
/// been rated at least once. The user's own rated star is highlighted in
/// [ColorScheme.primary]; unrated stars use [ColorScheme.outlineVariant].
class StarRatingWidget extends ConsumerWidget {
  const StarRatingWidget({required this.planId, super.key});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingAsync = ref.watch(planRatingProvider(planId));

    return ratingAsync.when(
      loading: () => const _StarRow(userRating: null, averageRating: null, ratingsCount: 0, onRate: null),
      error: (_, __) => const SizedBox.shrink(),
      data: (result) => _StarRow(
        userRating: result.userRating,
        averageRating: result.averageRating,
        ratingsCount: result.ratingsCount,
        onRate: (rating) => _submitRating(context, ref, rating, result),
      ),
    );
  }

  Future<void> _submitRating(
    BuildContext context,
    WidgetRef ref,
    int tappedStar,
    PlanRatingResult current,
  ) async {
    // Tapping the current rating removes it (toggle off); otherwise upsert.
    final service = ref.read(planApiServiceProvider);
    try {
      if (current.userRating == tappedStar) {
        await service.deleteRating(planId);
      } else {
        await service.ratePlan(planId, tappedStar);
      }
      ref.invalidate(planRatingProvider(planId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save rating. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.userRating,
    required this.averageRating,
    required this.ratingsCount,
    required this.onRate,
  });

  final int? userRating;
  final double? averageRating;
  final int ratingsCount;
  final void Function(int star)? onRate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onRate != null ? () => onRate!(i) : null,
            child: Icon(
              i <= (userRating ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 18,
              color: i <= (userRating ?? 0) ? cs.primary : cs.outlineVariant,
            ),
          ),
        if (ratingsCount > 0) ...[
          const SizedBox(width: 4),
          Text(
            '${averageRating?.toStringAsFixed(1) ?? '–'} ($ratingsCount)',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
