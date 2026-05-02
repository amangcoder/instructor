// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_plan_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LibraryPlanSummaryImpl _$$LibraryPlanSummaryImplFromJson(
        Map<String, dynamic> json) =>
    _$LibraryPlanSummaryImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'custom',
      defaultVoice: json['defaultVoice'] as String? ?? 'aoede',
      locale: json['locale'] as String?,
      totalDurationSeconds:
          (json['totalDurationSeconds'] as num?)?.toInt() ?? 0,
      stepCount: (json['stepCount'] as num?)?.toInt() ?? 0,
      tags: json['tags'] == null ? const [] : tagsFromJson(json['tags']),
    );

Map<String, dynamic> _$$LibraryPlanSummaryImplToJson(
        _$LibraryPlanSummaryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'category': instance.category,
      'defaultVoice': instance.defaultVoice,
      'locale': instance.locale,
      'totalDurationSeconds': instance.totalDurationSeconds,
      'stepCount': instance.stepCount,
      'tags': tagsToJson(instance.tags),
    };
