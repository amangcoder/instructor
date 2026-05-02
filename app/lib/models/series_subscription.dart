import 'package:freezed_annotation/freezed_annotation.dart';

part 'series_subscription.freezed.dart';
part 'series_subscription.g.dart';

/// Lifecycle of a user's subscription to a series.
enum SeriesSubscriptionStatus {
  @JsonValue('active')
  active,
  @JsonValue('paused')
  paused,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled,
}

/// A user's opt-in to a [Series], with progress tracking.
///
/// Source: `GET /api/series/me/subscriptions`. One row per (user, series);
/// re-subscribing reactivates the existing row instead of creating a new one,
/// so [completedSessions] / [currentSessionIndex] survive a cancel + resub.
@freezed
class SeriesSubscription with _$SeriesSubscription {
  const SeriesSubscription._();

  const factory SeriesSubscription({
    required String id,
    required String userId,
    required String seriesId,
    @Default(SeriesSubscriptionStatus.active) SeriesSubscriptionStatus status,

    /// 0-indexed position in the series — points at the next session to play.
    @Default(0) int currentSessionIndex,

    /// Number of sessions the user has completed. Bumped server-side when
    /// `POST /api/series/:id/progress` is called.
    @Default(0) int completedSessions,

    required DateTime subscribedAt,
    DateTime? lastSessionCompletedAt,
    DateTime? unsubscribedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _SeriesSubscription;

  factory SeriesSubscription.fromJson(Map<String, dynamic> json) =>
      _$SeriesSubscriptionFromJson(json);

  bool get isActive => status == SeriesSubscriptionStatus.active;
  bool get isComplete => status == SeriesSubscriptionStatus.completed;
}
