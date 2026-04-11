// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PlanImpl _$$PlanImplFromJson(Map<String, dynamic> json) => _$PlanImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      description: json['description'] as String?,
      category: $enumDecodeNullable(_$PlanCategoryEnumMap, json['category']) ??
          PlanCategory.custom,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      defaultVoice: json['defaultVoice'] as String? ?? 'aoede',
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => PlanStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastUsedAt: json['lastUsedAt'] == null
          ? null
          : DateTime.parse(json['lastUsedAt'] as String),
      isUserCreated: json['isUserCreated'] as bool? ?? true,
    );

Map<String, dynamic> _$$PlanImplToJson(_$PlanImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'category': _$PlanCategoryEnumMap[instance.category]!,
      'tags': instance.tags,
      'defaultVoice': instance.defaultVoice,
      'steps': instance.steps,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'lastUsedAt': instance.lastUsedAt?.toIso8601String(),
      'isUserCreated': instance.isUserCreated,
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
