// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_voice.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PlanVoiceImpl _$$PlanVoiceImplFromJson(Map<String, dynamic> json) =>
    _$PlanVoiceImpl(
      id: json['id'] as String,
      planId: json['planId'] as String,
      voiceId: json['voiceId'] as String,
      locale: json['locale'] as String,
      status: json['status'] as String,
      audioUrl: json['audioUrl'] as String?,
      durationMs: (json['durationMs'] as num?)?.toInt(),
      generatedAt: json['generatedAt'] == null
          ? null
          : DateTime.parse(json['generatedAt'] as String),
    );

Map<String, dynamic> _$$PlanVoiceImplToJson(_$PlanVoiceImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'planId': instance.planId,
      'voiceId': instance.voiceId,
      'locale': instance.locale,
      'status': instance.status,
      'audioUrl': instance.audioUrl,
      'durationMs': instance.durationMs,
      'generatedAt': instance.generatedAt?.toIso8601String(),
    };
