import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/services/plan_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ratings_providers.g.dart';

/// Fetches aggregate rating stats + the current user's own rating for [planId].
///
/// Auto-disposed when no widgets are watching. Call `ref.invalidate` after
/// submitting or deleting a rating to refresh the displayed stats.
@riverpod
Future<PlanRatingResult> planRating(Ref ref, String planId) {
  final service = ref.watch(planApiServiceProvider);
  return service.getPlanRating(planId);
}
