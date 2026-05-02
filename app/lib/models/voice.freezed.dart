// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voice.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Voice _$VoiceFromJson(Map<String, dynamic> json) {
  return _Voice.fromJson(json);
}

/// @nodoc
mixin _$Voice {
  String get id => throw _privateConstructorUsedError;
  String get slug => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String get locale => throw _privateConstructorUsedError;
  String get provider => throw _privateConstructorUsedError;
  String? get sampleUrl => throw _privateConstructorUsedError;
  bool get isPublished => throw _privateConstructorUsedError;

  /// Serializes this Voice to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Voice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VoiceCopyWith<Voice> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VoiceCopyWith<$Res> {
  factory $VoiceCopyWith(Voice value, $Res Function(Voice) then) =
      _$VoiceCopyWithImpl<$Res, Voice>;
  @useResult
  $Res call(
      {String id,
      String slug,
      String displayName,
      String locale,
      String provider,
      String? sampleUrl,
      bool isPublished});
}

/// @nodoc
class _$VoiceCopyWithImpl<$Res, $Val extends Voice>
    implements $VoiceCopyWith<$Res> {
  _$VoiceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Voice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? displayName = null,
    Object? locale = null,
    Object? provider = null,
    Object? sampleUrl = freezed,
    Object? isPublished = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      slug: null == slug
          ? _value.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      locale: null == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _value.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      sampleUrl: freezed == sampleUrl
          ? _value.sampleUrl
          : sampleUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      isPublished: null == isPublished
          ? _value.isPublished
          : isPublished // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VoiceImplCopyWith<$Res> implements $VoiceCopyWith<$Res> {
  factory _$$VoiceImplCopyWith(
          _$VoiceImpl value, $Res Function(_$VoiceImpl) then) =
      __$$VoiceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String slug,
      String displayName,
      String locale,
      String provider,
      String? sampleUrl,
      bool isPublished});
}

/// @nodoc
class __$$VoiceImplCopyWithImpl<$Res>
    extends _$VoiceCopyWithImpl<$Res, _$VoiceImpl>
    implements _$$VoiceImplCopyWith<$Res> {
  __$$VoiceImplCopyWithImpl(
      _$VoiceImpl _value, $Res Function(_$VoiceImpl) _then)
      : super(_value, _then);

  /// Create a copy of Voice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? displayName = null,
    Object? locale = null,
    Object? provider = null,
    Object? sampleUrl = freezed,
    Object? isPublished = null,
  }) {
    return _then(_$VoiceImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      slug: null == slug
          ? _value.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      locale: null == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _value.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      sampleUrl: freezed == sampleUrl
          ? _value.sampleUrl
          : sampleUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      isPublished: null == isPublished
          ? _value.isPublished
          : isPublished // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VoiceImpl extends _Voice {
  const _$VoiceImpl(
      {required this.id,
      required this.slug,
      required this.displayName,
      required this.locale,
      required this.provider,
      this.sampleUrl,
      this.isPublished = false})
      : super._();

  factory _$VoiceImpl.fromJson(Map<String, dynamic> json) =>
      _$$VoiceImplFromJson(json);

  @override
  final String id;
  @override
  final String slug;
  @override
  final String displayName;
  @override
  final String locale;
  @override
  final String provider;
  @override
  final String? sampleUrl;
  @override
  @JsonKey()
  final bool isPublished;

  @override
  String toString() {
    return 'Voice(id: $id, slug: $slug, displayName: $displayName, locale: $locale, provider: $provider, sampleUrl: $sampleUrl, isPublished: $isPublished)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VoiceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.locale, locale) || other.locale == locale) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.sampleUrl, sampleUrl) ||
                other.sampleUrl == sampleUrl) &&
            (identical(other.isPublished, isPublished) ||
                other.isPublished == isPublished));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, slug, displayName, locale,
      provider, sampleUrl, isPublished);

  /// Create a copy of Voice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VoiceImplCopyWith<_$VoiceImpl> get copyWith =>
      __$$VoiceImplCopyWithImpl<_$VoiceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VoiceImplToJson(
      this,
    );
  }
}

abstract class _Voice extends Voice {
  const factory _Voice(
      {required final String id,
      required final String slug,
      required final String displayName,
      required final String locale,
      required final String provider,
      final String? sampleUrl,
      final bool isPublished}) = _$VoiceImpl;
  const _Voice._() : super._();

  factory _Voice.fromJson(Map<String, dynamic> json) = _$VoiceImpl.fromJson;

  @override
  String get id;
  @override
  String get slug;
  @override
  String get displayName;
  @override
  String get locale;
  @override
  String get provider;
  @override
  String? get sampleUrl;
  @override
  bool get isPublished;

  /// Create a copy of Voice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VoiceImplCopyWith<_$VoiceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
