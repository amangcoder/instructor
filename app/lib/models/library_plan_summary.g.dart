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
      category: $enumDecodeNullable(_$PlanCategoryEnumMap, json['category']) ??
          PlanCategory.custom,
      defaultVoice: json['defaultVoice'] as String? ?? 'aoede',
      locale: json['locale'] as String?,
      totalDurationSeconds:
          (json['totalDurationSeconds'] as num?)?.toInt() ?? 0,
      stepCount: (json['stepCount'] as num?)?.toInt() ?? 0,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
    );

Map<String, dynamic> _$$LibraryPlanSummaryImplToJson(
        _$LibraryPlanSummaryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'category': _$PlanCategoryEnumMap[instance.category]!,
      'defaultVoice': instance.defaultVoice,
      'locale': instance.locale,
      'totalDurationSeconds': instance.totalDurationSeconds,
      'stepCount': instance.stepCount,
      'tags': instance.tags,
    };

const _$PlanCategoryEnumMap = {
  PlanCategory.yoga: 'yoga',
  PlanCategory.meditation: 'meditation',
  PlanCategory.workout: 'workout',
  PlanCategory.cooking: 'cooking',
  PlanCategory.routine: 'routine',
  PlanCategory.focus: 'focus',
  PlanCategory.custom: 'custom',
};
