// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VoiceImpl _$$VoiceImplFromJson(Map<String, dynamic> json) => _$VoiceImpl(
      id: json['id'] as String,
      slug: json['slug'] as String,
      displayName: json['displayName'] as String,
      locale: json['locale'] as String,
      provider: json['provider'] as String,
      sampleUrl: json['sampleUrl'] as String?,
      isPublished: json['isPublished'] as bool? ?? false,
    );

Map<String, dynamic> _$$VoiceImplToJson(_$VoiceImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'displayName': instance.displayName,
      'locale': instance.locale,
      'provider': instance.provider,
      'sampleUrl': instance.sampleUrl,
      'isPublished': instance.isPublished,
    };
