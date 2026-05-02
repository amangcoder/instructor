import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/repositories/plan_repository.dart';
import 'package:instructor/services/api_client.dart';
import 'package:instructor/services/plan_api_service.dart';

part 'plan_providers.g.dart';

/// Reactive stream of all Plans, with optional search and category filters.
///
/// Backed by [PlanRepository.watchUserPlans] — Plans are sorted by most recently
/// used (nulls last) and filtered in real-time as [searchQuery] or [category]
/// change.
///
/// Usage in a [ConsumerWidget]:
/// ```dart
/// final plans = ref.watch(planListProvider());
/// final filtered = ref.watch(planListProvider(
///   searchQuery: 'yoga',
///   category: 'yoga',
/// ));
/// ```
@riverpod
Stream<List<Plan>> planList(
  Ref ref, {
  String? searchQuery,
  String? category,
}) {
  final repo = ref.watch(planRepositoryProvider);
  return repo.watchUserPlans(searchQuery: searchQuery, category: category);
}

/// Fetches a single Plan by [id].
///
/// Returns null when the Plan does not exist (e.g. after deletion).
@riverpod
Future<Plan?> planById(Ref ref, String id) {
  final repo = ref.watch(planRepositoryProvider);
  return repo.getPlanById(id);
}

/// Singleton [PlanRepository] provider.
///
/// [keepAlive: true] — the repository must outlive any individual screen so
/// that watch streams remain active and the database is not torn down.
///
/// Backed by [ApiPlanRepository]: all mutations are routed through the backend
/// API first; the local SQLite cache is updated on success so that
/// [watchUserPlans] streams remain reactive.
///
/// Override in tests with a mock or an [AppDatabase.forTesting] instance:
/// ```dart
/// final container = ProviderContainer(overrides: [
///   planRepositoryProvider.overrideWithValue(FakePlanRepository()),
/// ]);
/// ```
@Riverpod(keepAlive: true)
PlanRepository planRepository(Ref ref) {
  final api = ref.watch(planApiServiceProvider);
  final db = ref.watch(appDatabaseProvider);
  return ApiPlanRepository(planApiService: api, db: db);
}

/// Keep-alive [PlanApiService] provider shared across the app.
///
/// Using [keepAlive] ensures a single [PlanApiService] instance is reused for
/// the lifetime of the application, avoiding redundant HTTP client creation.
@Riverpod(keepAlive: true)
PlanApiService planApiService(Ref ref) {
  final client = ref.watch(apiClientProvider);
  return PlanApiServiceImpl(apiClient: client);
}
