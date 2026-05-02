import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/models/series.dart';
import 'package:instructor/models/series_subscription.dart';
import 'package:instructor/services/api_client.dart';
import 'package:instructor/services/series_api_service.dart';

part 'series_providers.g.dart';

/// Singleton SeriesApiService — same lifetime as the rest of the app's HTTP
/// services so we don't churn http.Client instances.
@Riverpod(keepAlive: true)
SeriesApiService seriesApiService(Ref ref) {
  final client = ref.watch(apiClientProvider);
  return SeriesApiServiceImpl(apiClient: client);
}

/// Published series for the Library "Programs" rail.
@riverpod
Future<List<Series>> publishedSeries(Ref ref) {
  return ref.watch(seriesApiServiceProvider).listPublished();
}

/// Single series detail (with ordered sessions).
@riverpod
Future<Series> seriesById(Ref ref, String id) {
  return ref.watch(seriesApiServiceProvider).getById(id);
}

/// Current user's subscriptions.
///
/// [activeOnly] = true is what the "Continue your program" card on the Library
/// tab and the mini-player series-context lookup use, since they only care
/// about programs the user is currently progressing through.
@riverpod
Future<List<SeriesSubscription>> mySubscriptions(
  Ref ref, {
  bool activeOnly = false,
}) {
  return ref
      .watch(seriesApiServiceProvider)
      .mySubscriptions(activeOnly: activeOnly);
}

/// Subscription for a single series, or null if the user hasn't opted in.
/// Convenience derived from [mySubscriptions] so a single fetch covers
/// both "is subscribed?" and "list my programs."
@riverpod
Future<SeriesSubscription?> mySubscriptionFor(Ref ref, String seriesId) async {
  final subs = await ref.watch(mySubscriptionsProvider().future);
  for (final sub in subs) {
    if (sub.seriesId == seriesId) return sub;
  }
  return null;
}
