// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'series_subscription.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SeriesSubscriptionImpl _$$SeriesSubscriptionImplFromJson(
        Map<String, dynamic> json) =>
    _$SeriesSubscriptionImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      seriesId: json['seriesId'] as String,
      status: $enumDecodeNullable(
              _$SeriesSubscriptionStatusEnumMap, json['status']) ??
          SeriesSubscriptionStatus.active,
      currentSessionIndex: (json['currentSessionIndex'] as num?)?.toInt() ?? 0,
      completedSessions: (json['completedSessions'] as num?)?.toInt() ?? 0,
      subscribedAt: DateTime.parse(json['subscribedAt'] as String),
      lastSessionCompletedAt: json['lastSessionCompletedAt'] == null
          ? null
          : DateTime.parse(json['lastSessionCompletedAt'] as String),
      unsubscribedAt: json['unsubscribedAt'] == null
          ? null
          : DateTime.parse(json['unsubscribedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$SeriesSubscriptionImplToJson(
        _$SeriesSubscriptionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'seriesId': instance.seriesId,
      'status': _$SeriesSubscriptionStatusEnumMap[instance.status]!,
      'currentSessionIndex': instance.currentSessionIndex,
      'completedSessions': instance.completedSessions,
      'subscribedAt': instance.subscribedAt.toIso8601String(),
      'lastSessionCompletedAt':
          instance.lastSessionCompletedAt?.toIso8601String(),
      'unsubscribedAt': instance.unsubscribedAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$SeriesSubscriptionStatusEnumMap = {
  SeriesSubscriptionStatus.active: 'active',
  SeriesSubscriptionStatus.paused: 'paused',
  SeriesSubscriptionStatus.completed: 'completed',
  SeriesSubscriptionStatus.cancelled: 'cancelled',
};
