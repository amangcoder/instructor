// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plan_voice.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PlanVoice _$PlanVoiceFromJson(Map<String, dynamic> json) {
  return _PlanVoice.fromJson(json);
}

/// @nodoc
mixin _$PlanVoice {
  String get id => throw _privateConstructorUsedError;
  String get planId => throw _privateConstructorUsedError;
  String get voiceId => throw _privateConstructorUsedError;
  String get locale => throw _privateConstructorUsedError;

  /// TTS synthesis status: 'pending' | 'processing' | 'ready' | 'failed'
  String get status => throw _privateConstructorUsedError;

  /// URL to the synthesized audio file (present when status='ready').
  String? get audioUrl => throw _privateConstructorUsedError;

  /// Duration of the synthesized audio in milliseconds.
  int? get durationMs => throw _privateConstructorUsedError;

  /// Timestamp when the audio was generated (present when status='ready').
  DateTime? get generatedAt => throw _privateConstructorUsedError;

  /// Serializes this PlanVoice to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlanVoice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanVoiceCopyWith<PlanVoice> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanVoiceCopyWith<$Res> {
  factory $PlanVoiceCopyWith(PlanVoice value, $Res Function(PlanVoice) then) =
      _$PlanVoiceCopyWithImpl<$Res, PlanVoice>;
  @useResult
  $Res call(
      {String id,
      String planId,
      String voiceId,
      String locale,
      String status,
      String? audioUrl,
      int? durationMs,
      DateTime? generatedAt});
}

/// @nodoc
class _$PlanVoiceCopyWithImpl<$Res, $Val extends PlanVoice>
    implements $PlanVoiceCopyWith<$Res> {
  _$PlanVoiceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlanVoice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? planId = null,
    Object? voiceId = null,
    Object? locale = null,
    Object? status = null,
    Object? audioUrl = freezed,
    Object? durationMs = freezed,
    Object? generatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      planId: null == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as String,
      voiceId: null == voiceId
          ? _value.voiceId
          : voiceId // ignore: cast_nullable_to_non_nullable
              as String,
      locale: null == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      audioUrl: freezed == audioUrl
          ? _value.audioUrl
          : audioUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      durationMs: freezed == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      generatedAt: freezed == generatedAt
          ? _value.generatedAt
          : generatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlanVoiceImplCopyWith<$Res>
    implements $PlanVoiceCopyWith<$Res> {
  factory _$$PlanVoiceImplCopyWith(
          _$PlanVoiceImpl value, $Res Function(_$PlanVoiceImpl) then) =
      __$$PlanVoiceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String planId,
      String voiceId,
      String locale,
      String status,
      String? audioUrl,
      int? durationMs,
      DateTime? generatedAt});
}

/// @nodoc
class __$$PlanVoiceImplCopyWithImpl<$Res>
    extends _$PlanVoiceCopyWithImpl<$Res, _$PlanVoiceImpl>
    implements _$$PlanVoiceImplCopyWith<$Res> {
  __$$PlanVoiceImplCopyWithImpl(
      _$PlanVoiceImpl _value, $Res Function(_$PlanVoiceImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlanVoice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? planId = null,
    Object? voiceId = null,
    Object? locale = null,
    Object? status = null,
    Object? audioUrl = freezed,
    Object? durationMs = freezed,
    Object? generatedAt = freezed,
  }) {
    return _then(_$PlanVoiceImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      planId: null == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as String,
      voiceId: null == voiceId
          ? _value.voiceId
          : voiceId // ignore: cast_nullable_to_non_nullable
              as String,
      locale: null == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      audioUrl: freezed == audioUrl
          ? _value.audioUrl
          : audioUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      durationMs: freezed == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      generatedAt: freezed == generatedAt
          ? _value.generatedAt
          : generatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlanVoiceImpl extends _PlanVoice {
  const _$PlanVoiceImpl(
      {required this.id,
      required this.planId,
      required this.voiceId,
      required this.locale,
      required this.status,
      this.audioUrl,
      this.durationMs,
      this.generatedAt})
      : super._();

  factory _$PlanVoiceImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanVoiceImplFromJson(json);

  @override
  final String id;
  @override
  final String planId;
  @override
  final String voiceId;
  @override
  final String locale;

  /// TTS synthesis status: 'pending' | 'processing' | 'ready' | 'failed'
  @override
  final String status;

  /// URL to the synthesized audio file (present when status='ready').
  @override
  final String? audioUrl;

  /// Duration of the synthesized audio in milliseconds.
  @override
  final int? durationMs;

  /// Timestamp when the audio was generated (present when status='ready').
  @override
  final DateTime? generatedAt;

  @override
  String toString() {
    return 'PlanVoice(id: $id, planId: $planId, voiceId: $voiceId, locale: $locale, status: $status, audioUrl: $audioUrl, durationMs: $durationMs, generatedAt: $generatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlanVoiceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.planId, planId) || other.planId == planId) &&
            (identical(other.voiceId, voiceId) || other.voiceId == voiceId) &&
            (identical(other.locale, locale) || other.locale == locale) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.audioUrl, audioUrl) ||
                other.audioUrl == audioUrl) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.generatedAt, generatedAt) ||
                other.generatedAt == generatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, planId, voiceId, locale,
      status, audioUrl, durationMs, generatedAt);

  /// Create a copy of PlanVoice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlanVoiceImplCopyWith<_$PlanVoiceImpl> get copyWith =>
      __$$PlanVoiceImplCopyWithImpl<_$PlanVoiceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlanVoiceImplToJson(
      this,
    );
  }
}

abstract class _PlanVoice extends PlanVoice {
  const factory _PlanVoice(
      {required final String id,
      required final String planId,
      required final String voiceId,
      required final String locale,
      required final String status,
      final String? audioUrl,
      final int? durationMs,
      final DateTime? generatedAt}) = _$PlanVoiceImpl;
  const _PlanVoice._() : super._();

  factory _PlanVoice.fromJson(Map<String, dynamic> json) =
      _$PlanVoiceImpl.fromJson;

  @override
  String get id;
  @override
  String get planId;
  @override
  String get voiceId;
  @override
  String get locale;

  /// TTS synthesis status: 'pending' | 'processing' | 'ready' | 'failed'
  @override
  String get status;

  /// URL to the synthesized audio file (present when status='ready').
  @override
  String? get audioUrl;

  /// Duration of the synthesized audio in milliseconds.
  @override
  int? get durationMs;

  /// Timestamp when the audio was generated (present when status='ready').
  @override
  DateTime? get generatedAt;

  /// Create a copy of PlanVoice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanVoiceImplCopyWith<_$PlanVoiceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
