// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tts_status_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TtsStatusInfo _$TtsStatusInfoFromJson(Map<String, dynamic> json) {
  return _TtsStatusInfo.fromJson(json);
}

/// @nodoc
mixin _$TtsStatusInfo {
  /// The plan ID this status belongs to.
  String get planId => throw _privateConstructorUsedError;

  /// Current generation status.
  ///
  /// One of: none | pending | processing | completed | partial | failed.
  String get status => throw _privateConstructorUsedError;

  /// Total number of TTS audio segments to generate.
  int get total => throw _privateConstructorUsedError;

  /// Number of TTS audio segments generated so far.
  int get completed => throw _privateConstructorUsedError;

  /// Serializes this TtsStatusInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TtsStatusInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TtsStatusInfoCopyWith<TtsStatusInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TtsStatusInfoCopyWith<$Res> {
  factory $TtsStatusInfoCopyWith(
          TtsStatusInfo value, $Res Function(TtsStatusInfo) then) =
      _$TtsStatusInfoCopyWithImpl<$Res, TtsStatusInfo>;
  @useResult
  $Res call({String planId, String status, int total, int completed});
}

/// @nodoc
class _$TtsStatusInfoCopyWithImpl<$Res, $Val extends TtsStatusInfo>
    implements $TtsStatusInfoCopyWith<$Res> {
  _$TtsStatusInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TtsStatusInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? planId = null,
    Object? status = null,
    Object? total = null,
    Object? completed = null,
  }) {
    return _then(_value.copyWith(
      planId: null == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      completed: null == completed
          ? _value.completed
          : completed // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TtsStatusInfoImplCopyWith<$Res>
    implements $TtsStatusInfoCopyWith<$Res> {
  factory _$$TtsStatusInfoImplCopyWith(
          _$TtsStatusInfoImpl value, $Res Function(_$TtsStatusInfoImpl) then) =
      __$$TtsStatusInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String planId, String status, int total, int completed});
}

/// @nodoc
class __$$TtsStatusInfoImplCopyWithImpl<$Res>
    extends _$TtsStatusInfoCopyWithImpl<$Res, _$TtsStatusInfoImpl>
    implements _$$TtsStatusInfoImplCopyWith<$Res> {
  __$$TtsStatusInfoImplCopyWithImpl(
      _$TtsStatusInfoImpl _value, $Res Function(_$TtsStatusInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of TtsStatusInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? planId = null,
    Object? status = null,
    Object? total = null,
    Object? completed = null,
  }) {
    return _then(_$TtsStatusInfoImpl(
      planId: null == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      completed: null == completed
          ? _value.completed
          : completed // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TtsStatusInfoImpl extends _TtsStatusInfo {
  const _$TtsStatusInfoImpl(
      {required this.planId,
      required this.status,
      required this.total,
      required this.completed})
      : super._();

  factory _$TtsStatusInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$TtsStatusInfoImplFromJson(json);

  /// The plan ID this status belongs to.
  @override
  final String planId;

  /// Current generation status.
  ///
  /// One of: none | pending | processing | completed | partial | failed.
  @override
  final String status;

  /// Total number of TTS audio segments to generate.
  @override
  final int total;

  /// Number of TTS audio segments generated so far.
  @override
  final int completed;

  @override
  String toString() {
    return 'TtsStatusInfo(planId: $planId, status: $status, total: $total, completed: $completed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TtsStatusInfoImpl &&
            (identical(other.planId, planId) || other.planId == planId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.completed, completed) ||
                other.completed == completed));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, planId, status, total, completed);

  /// Create a copy of TtsStatusInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TtsStatusInfoImplCopyWith<_$TtsStatusInfoImpl> get copyWith =>
      __$$TtsStatusInfoImplCopyWithImpl<_$TtsStatusInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TtsStatusInfoImplToJson(
      this,
    );
  }
}

abstract class _TtsStatusInfo extends TtsStatusInfo {
  const factory _TtsStatusInfo(
      {required final String planId,
      required final String status,
      required final int total,
      required final int completed}) = _$TtsStatusInfoImpl;
  const _TtsStatusInfo._() : super._();

  factory _TtsStatusInfo.fromJson(Map<String, dynamic> json) =
      _$TtsStatusInfoImpl.fromJson;

  /// The plan ID this status belongs to.
  @override
  String get planId;

  /// Current generation status.
  ///
  /// One of: none | pending | processing | completed | partial | failed.
  @override
  String get status;

  /// Total number of TTS audio segments to generate.
  @override
  int get total;

  /// Number of TTS audio segments generated so far.
  @override
  int get completed;

  /// Create a copy of TtsStatusInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TtsStatusInfoImplCopyWith<_$TtsStatusInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
