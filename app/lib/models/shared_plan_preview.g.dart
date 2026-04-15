// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shared_plan_preview.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SharedPlanPreviewImpl _$$SharedPlanPreviewImplFromJson(
        Map<String, dynamic> json) =>
    _$SharedPlanPreviewImpl(
      name: json['name'] as String,
      description: json['description'] as String?,
      steps: json['steps'] as List<dynamic>? ?? const [],
      stepCount: (json['stepCount'] as num).toInt(),
      estimatedDurationMs: (json['estimatedDurationMs'] as num).toInt(),
    );

Map<String, dynamic> _$$SharedPlanPreviewImplToJson(
        _$SharedPlanPreviewImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'steps': instance.steps,
      'stepCount': instance.stepCount,
      'estimatedDurationMs': instance.estimatedDurationMs,
    };
