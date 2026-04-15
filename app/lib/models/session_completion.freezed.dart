// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_completion.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SessionCompletion _$SessionCompletionFromJson(Map<String, dynamic> json) {
  return _SessionCompletion.fromJson(json);
}

/// @nodoc
mixin _$SessionCompletion {
  /// Unique identifier for this completion record (e.g., UUID or auto-generated).
  String get id => throw _privateConstructorUsedError;

  /// ID of the plan that was completed.
  String get planId => throw _privateConstructorUsedError;

  /// UTC timestamp when the session was completed.
  DateTime get completedAt => throw _privateConstructorUsedError;

  /// Duration of the session in milliseconds.
  int get durationMs => throw _privateConstructorUsedError;

  /// True if this completion has been synced to the server.
  /// Used to identify unsynced records for the sync service.
  bool get synced => throw _privateConstructorUsedError;

  /// Serializes this SessionCompletion to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SessionCompletion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionCompletionCopyWith<SessionCompletion> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionCompletionCopyWith<$Res> {
  factory $SessionCompletionCopyWith(
          SessionCompletion value, $Res Function(SessionCompletion) then) =
      _$SessionCompletionCopyWithImpl<$Res, SessionCompletion>;
  @useResult
  $Res call(
      {String id,
      String planId,
      DateTime completedAt,
      int durationMs,
      bool synced});
}

/// @nodoc
class _$SessionCompletionCopyWithImpl<$Res, $Val extends SessionCompletion>
    implements $SessionCompletionCopyWith<$Res> {
  _$SessionCompletionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionCompletion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? planId = null,
    Object? completedAt = null,
    Object? durationMs = null,
    Object? synced = null,
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
      completedAt: null == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      durationMs: null == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int,
      synced: null == synced
          ? _value.synced
          : synced // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SessionCompletionImplCopyWith<$Res>
    implements $SessionCompletionCopyWith<$Res> {
  factory _$$SessionCompletionImplCopyWith(_$SessionCompletionImpl value,
          $Res Function(_$SessionCompletionImpl) then) =
      __$$SessionCompletionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String planId,
      DateTime completedAt,
      int durationMs,
      bool synced});
}

/// @nodoc
class __$$SessionCompletionImplCopyWithImpl<$Res>
    extends _$SessionCompletionCopyWithImpl<$Res, _$SessionCompletionImpl>
    implements _$$SessionCompletionImplCopyWith<$Res> {
  __$$SessionCompletionImplCopyWithImpl(_$SessionCompletionImpl _value,
      $Res Function(_$SessionCompletionImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionCompletion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? planId = null,
    Object? completedAt = null,
    Object? durationMs = null,
    Object? synced = null,
  }) {
    return _then(_$SessionCompletionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      planId: null == planId
          ? _value.planId
          : planId // ignore: cast_nullable_to_non_nullable
              as String,
      completedAt: null == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      durationMs: null == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int,
      synced: null == synced
          ? _value.synced
          : synced // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SessionCompletionImpl extends _SessionCompletion {
  const _$SessionCompletionImpl(
      {required this.id,
      required this.planId,
      required this.completedAt,
      required this.durationMs,
      required this.synced})
      : super._();

  factory _$SessionCompletionImpl.fromJson(Map<String, dynamic> json) =>
      _$$SessionCompletionImplFromJson(json);

  /// Unique identifier for this completion record (e.g., UUID or auto-generated).
  @override
  final String id;

  /// ID of the plan that was completed.
  @override
  final String planId;

  /// UTC timestamp when the session was completed.
  @override
  final DateTime completedAt;

  /// Duration of the session in milliseconds.
  @override
  final int durationMs;

  /// True if this completion has been synced to the server.
  /// Used to identify unsynced records for the sync service.
  @override
  final bool synced;

  @override
  String toString() {
    return 'SessionCompletion(id: $id, planId: $planId, completedAt: $completedAt, durationMs: $durationMs, synced: $synced)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionCompletionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.planId, planId) || other.planId == planId) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.synced, synced) || other.synced == synced));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, planId, completedAt, durationMs, synced);

  /// Create a copy of SessionCompletion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionCompletionImplCopyWith<_$SessionCompletionImpl> get copyWith =>
      __$$SessionCompletionImplCopyWithImpl<_$SessionCompletionImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SessionCompletionImplToJson(
      this,
    );
  }
}

abstract class _SessionCompletion extends SessionCompletion {
  const factory _SessionCompletion(
      {required final String id,
      required final String planId,
      required final DateTime completedAt,
      required final int durationMs,
      required final bool synced}) = _$SessionCompletionImpl;
  const _SessionCompletion._() : super._();

  factory _SessionCompletion.fromJson(Map<String, dynamic> json) =
      _$SessionCompletionImpl.fromJson;

  /// Unique identifier for this completion record (e.g., UUID or auto-generated).
  @override
  String get id;

  /// ID of the plan that was completed.
  @override
  String get planId;

  /// UTC timestamp when the session was completed.
  @override
  DateTime get completedAt;

  /// Duration of the session in milliseconds.
  @override
  int get durationMs;

  /// True if this completion has been synced to the server.
  /// Used to identify unsynced records for the sync service.
  @override
  bool get synced;

  /// Create a copy of SessionCompletion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionCompletionImplCopyWith<_$SessionCompletionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
