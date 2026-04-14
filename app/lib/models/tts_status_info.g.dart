// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_status_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TtsStatusInfoImpl _$$TtsStatusInfoImplFromJson(Map<String, dynamic> json) =>
    _$TtsStatusInfoImpl(
      planId: json['planId'] as String,
      status: json['status'] as String,
      total: (json['total'] as num).toInt(),
      completed: (json['completed'] as num).toInt(),
    );

Map<String, dynamic> _$$TtsStatusInfoImplToJson(_$TtsStatusInfoImpl instance) =>
    <String, dynamic>{
      'planId': instance.planId,
      'status': instance.status,
      'total': instance.total,
      'completed': instance.completed,
    };
