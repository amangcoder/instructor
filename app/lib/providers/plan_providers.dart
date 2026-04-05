import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/repositories/plan_repository.dart';

part 'plan_providers.g.dart';

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
@riverpod
Stream<List<Plan>> planList(
  Ref ref, {
  String? searchQuery,
  PlanCategory? category,
}) {
  final repo = ref.watch(planRepositoryProvider);
  return repo.watchAllPlans(searchQuery: searchQuery, category: category);
}

/// Fetches a single Plan by [id].
///
/// Returns null when the Plan does not exist (e.g. after deletion).
@riverpod
Future<Plan?> planById(Ref ref, int id) {
  final repo = ref.watch(planRepositoryProvider);
  return repo.getPlanById(id);
}
