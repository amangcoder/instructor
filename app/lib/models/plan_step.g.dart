// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_step.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SayStepImpl _$$SayStepImplFromJson(Map<String, dynamic> json) =>
    _$SayStepImpl(
      id: json['id'] as String,
      text: json['text'] as String,
      voiceId: json['voiceId'] as String?,
      estimatedDuration: json['estimatedDuration'] == null
          ? null
          : Duration(microseconds: (json['estimatedDuration'] as num).toInt()),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$SayStepImplToJson(_$SayStepImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'voiceId': instance.voiceId,
      'estimatedDuration': instance.estimatedDuration?.inMicroseconds,
      'runtimeType': instance.$type,
    };

_$NotifyStepImpl _$$NotifyStepImplFromJson(Map<String, dynamic> json) =>
    _$NotifyStepImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$NotifyStepImplToJson(_$NotifyStepImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'body': instance.body,
      'runtimeType': instance.$type,
    };

_$PlayStepImpl _$$PlayStepImplFromJson(Map<String, dynamic> json) =>
    _$PlayStepImpl(
      id: json['id'] as String,
      audioAssetKey: json['audioAssetKey'] as String,
      loop: json['loop'] as bool? ?? true,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      fadeInMs: (json['fadeInMs'] as num?)?.toInt(),
      fadeOutMs: (json['fadeOutMs'] as num?)?.toInt(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$PlayStepImplToJson(_$PlayStepImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'audioAssetKey': instance.audioAssetKey,
      'loop': instance.loop,
      'volume': instance.volume,
      'fadeInMs': instance.fadeInMs,
      'fadeOutMs': instance.fadeOutMs,
      'runtimeType': instance.$type,
    };

_$WaitStepImpl _$$WaitStepImplFromJson(Map<String, dynamic> json) =>
    _$WaitStepImpl(
      id: json['id'] as String,
      duration: Duration(microseconds: (json['duration'] as num).toInt()),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$WaitStepImplToJson(_$WaitStepImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'duration': instance.duration.inMicroseconds,
      'runtimeType': instance.$type,
    };

_$RepeatStepImpl _$$RepeatStepImplFromJson(Map<String, dynamic> json) =>
    _$RepeatStepImpl(
      id: json['id'] as String,
      count: (json['count'] as num).toInt(),
      children: (json['children'] as List<dynamic>)
          .map((e) => PlanStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$RepeatStepImplToJson(_$RepeatStepImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'count': instance.count,
      'children': instance.children,
      'runtimeType': instance.$type,
    };

_$StopAudioStepImpl _$$StopAudioStepImplFromJson(Map<String, dynamic> json) =>
    _$StopAudioStepImpl(
      id: json['id'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$StopAudioStepImplToJson(_$StopAudioStepImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'runtimeType': instance.$type,
    };
