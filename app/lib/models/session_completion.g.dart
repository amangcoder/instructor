// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_completion.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SessionCompletionImpl _$$SessionCompletionImplFromJson(
        Map<String, dynamic> json) =>
    _$SessionCompletionImpl(
      id: json['id'] as String,
      planId: json['planId'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      durationMs: (json['durationMs'] as num).toInt(),
      synced: json['synced'] as bool,
    );

Map<String, dynamic> _$$SessionCompletionImplToJson(
        _$SessionCompletionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'planId': instance.planId,
      'completedAt': instance.completedAt.toIso8601String(),
      'durationMs': instance.durationMs,
      'synced': instance.synced,
    };
