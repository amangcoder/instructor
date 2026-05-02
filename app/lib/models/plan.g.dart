// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PlanImpl _$$PlanImplFromJson(Map<String, dynamic> json) => _$PlanImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'custom',
      tags: json['tags'] == null ? const [] : tagsFromJson(json['tags']),
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
      isActive: json['isActive'] as bool? ?? false,
      ttsStatus: json['ttsStatus'] as String? ?? 'none',
      ttsTotal: (json['ttsTotal'] as num?)?.toInt() ?? 0,
      ttsCompleted: (json['ttsCompleted'] as num?)?.toInt() ?? 0,
      libraryId: json['libraryId'] as String?,
      seriesId: json['seriesId'] as String?,
      parentPlanId: json['parentPlanId'] as String?,
      position: (json['position'] as num?)?.toInt() ?? 0,
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => Plan.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      voices: (json['voices'] as List<dynamic>?)
              ?.map((e) => PlanVoice.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      visibility: json['visibility'] as String? ?? 'public',
      isPublished: json['isPublished'] as bool? ?? false,
      ownerId: json['ownerId'] as String?,
    );

Map<String, dynamic> _$$PlanImplToJson(_$PlanImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'category': instance.category,
      'tags': tagsToJson(instance.tags),
      'defaultVoice': instance.defaultVoice,
      'steps': instance.steps,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'lastUsedAt': instance.lastUsedAt?.toIso8601String(),
      'isActive': instance.isActive,
      'ttsStatus': instance.ttsStatus,
      'ttsTotal': instance.ttsTotal,
      'ttsCompleted': instance.ttsCompleted,
      'libraryId': instance.libraryId,
      'seriesId': instance.seriesId,
      'parentPlanId': instance.parentPlanId,
      'position': instance.position,
      'children': instance.children,
      'voices': instance.voices,
      'visibility': instance.visibility,
      'isPublished': instance.isPublished,
      'ownerId': instance.ownerId,
    };
