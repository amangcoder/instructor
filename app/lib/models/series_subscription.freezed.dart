// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'series_subscription.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SeriesSubscription _$SeriesSubscriptionFromJson(Map<String, dynamic> json) {
  return _SeriesSubscription.fromJson(json);
}

/// @nodoc
mixin _$SeriesSubscription {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get seriesId => throw _privateConstructorUsedError;
  SeriesSubscriptionStatus get status => throw _privateConstructorUsedError;

  /// 0-indexed position in the series — points at the next session to play.
  int get currentSessionIndex => throw _privateConstructorUsedError;

  /// Number of sessions the user has completed. Bumped server-side when
  /// `POST /api/series/:id/progress` is called.
  int get completedSessions => throw _privateConstructorUsedError;
  DateTime get subscribedAt => throw _privateConstructorUsedError;
  DateTime? get lastSessionCompletedAt => throw _privateConstructorUsedError;
  DateTime? get unsubscribedAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this SeriesSubscription to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SeriesSubscription
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SeriesSubscriptionCopyWith<SeriesSubscription> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SeriesSubscriptionCopyWith<$Res> {
  factory $SeriesSubscriptionCopyWith(
          SeriesSubscription value, $Res Function(SeriesSubscription) then) =
      _$SeriesSubscriptionCopyWithImpl<$Res, SeriesSubscription>;
  @useResult
  $Res call(
      {String id,
      String userId,
      String seriesId,
      SeriesSubscriptionStatus status,
      int currentSessionIndex,
      int completedSessions,
      DateTime subscribedAt,
      DateTime? lastSessionCompletedAt,
      DateTime? unsubscribedAt,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class _$SeriesSubscriptionCopyWithImpl<$Res, $Val extends SeriesSubscription>
    implements $SeriesSubscriptionCopyWith<$Res> {
  _$SeriesSubscriptionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SeriesSubscription
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? seriesId = null,
    Object? status = null,
    Object? currentSessionIndex = null,
    Object? completedSessions = null,
    Object? subscribedAt = null,
    Object? lastSessionCompletedAt = freezed,
    Object? unsubscribedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      seriesId: null == seriesId
          ? _value.seriesId
          : seriesId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SeriesSubscriptionStatus,
      currentSessionIndex: null == currentSessionIndex
          ? _value.currentSessionIndex
          : currentSessionIndex // ignore: cast_nullable_to_non_nullable
              as int,
      completedSessions: null == completedSessions
          ? _value.completedSessions
          : completedSessions // ignore: cast_nullable_to_non_nullable
              as int,
      subscribedAt: null == subscribedAt
          ? _value.subscribedAt
          : subscribedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastSessionCompletedAt: freezed == lastSessionCompletedAt
          ? _value.lastSessionCompletedAt
          : lastSessionCompletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      unsubscribedAt: freezed == unsubscribedAt
          ? _value.unsubscribedAt
          : unsubscribedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SeriesSubscriptionImplCopyWith<$Res>
    implements $SeriesSubscriptionCopyWith<$Res> {
  factory _$$SeriesSubscriptionImplCopyWith(_$SeriesSubscriptionImpl value,
          $Res Function(_$SeriesSubscriptionImpl) then) =
      __$$SeriesSubscriptionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String seriesId,
      SeriesSubscriptionStatus status,
      int currentSessionIndex,
      int completedSessions,
      DateTime subscribedAt,
      DateTime? lastSessionCompletedAt,
      DateTime? unsubscribedAt,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class __$$SeriesSubscriptionImplCopyWithImpl<$Res>
    extends _$SeriesSubscriptionCopyWithImpl<$Res, _$SeriesSubscriptionImpl>
    implements _$$SeriesSubscriptionImplCopyWith<$Res> {
  __$$SeriesSubscriptionImplCopyWithImpl(_$SeriesSubscriptionImpl _value,
      $Res Function(_$SeriesSubscriptionImpl) _then)
      : super(_value, _then);

  /// Create a copy of SeriesSubscription
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? seriesId = null,
    Object? status = null,
    Object? currentSessionIndex = null,
    Object? completedSessions = null,
    Object? subscribedAt = null,
    Object? lastSessionCompletedAt = freezed,
    Object? unsubscribedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$SeriesSubscriptionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      seriesId: null == seriesId
          ? _value.seriesId
          : seriesId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SeriesSubscriptionStatus,
      currentSessionIndex: null == currentSessionIndex
          ? _value.currentSessionIndex
          : currentSessionIndex // ignore: cast_nullable_to_non_nullable
              as int,
      completedSessions: null == completedSessions
          ? _value.completedSessions
          : completedSessions // ignore: cast_nullable_to_non_nullable
              as int,
      subscribedAt: null == subscribedAt
          ? _value.subscribedAt
          : subscribedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastSessionCompletedAt: freezed == lastSessionCompletedAt
          ? _value.lastSessionCompletedAt
          : lastSessionCompletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      unsubscribedAt: freezed == unsubscribedAt
          ? _value.unsubscribedAt
          : unsubscribedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SeriesSubscriptionImpl extends _SeriesSubscription {
  const _$SeriesSubscriptionImpl(
      {required this.id,
      required this.userId,
      required this.seriesId,
      this.status = SeriesSubscriptionStatus.active,
      this.currentSessionIndex = 0,
      this.completedSessions = 0,
      required this.subscribedAt,
      this.lastSessionCompletedAt,
      this.unsubscribedAt,
      required this.createdAt,
      required this.updatedAt})
      : super._();

  factory _$SeriesSubscriptionImpl.fromJson(Map<String, dynamic> json) =>
      _$$SeriesSubscriptionImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String seriesId;
  @override
  @JsonKey()
  final SeriesSubscriptionStatus status;

  /// 0-indexed position in the series — points at the next session to play.
  @override
  @JsonKey()
  final int currentSessionIndex;

  /// Number of sessions the user has completed. Bumped server-side when
  /// `POST /api/series/:id/progress` is called.
  @override
  @JsonKey()
  final int completedSessions;
  @override
  final DateTime subscribedAt;
  @override
  final DateTime? lastSessionCompletedAt;
  @override
  final DateTime? unsubscribedAt;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'SeriesSubscription(id: $id, userId: $userId, seriesId: $seriesId, status: $status, currentSessionIndex: $currentSessionIndex, completedSessions: $completedSessions, subscribedAt: $subscribedAt, lastSessionCompletedAt: $lastSessionCompletedAt, unsubscribedAt: $unsubscribedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SeriesSubscriptionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.seriesId, seriesId) ||
                other.seriesId == seriesId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.currentSessionIndex, currentSessionIndex) ||
                other.currentSessionIndex == currentSessionIndex) &&
            (identical(other.completedSessions, completedSessions) ||
                other.completedSessions == completedSessions) &&
            (identical(other.subscribedAt, subscribedAt) ||
                other.subscribedAt == subscribedAt) &&
            (identical(other.lastSessionCompletedAt, lastSessionCompletedAt) ||
                other.lastSessionCompletedAt == lastSessionCompletedAt) &&
            (identical(other.unsubscribedAt, unsubscribedAt) ||
                other.unsubscribedAt == unsubscribedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      seriesId,
      status,
      currentSessionIndex,
      completedSessions,
      subscribedAt,
      lastSessionCompletedAt,
      unsubscribedAt,
      createdAt,
      updatedAt);

  /// Create a copy of SeriesSubscription
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SeriesSubscriptionImplCopyWith<_$SeriesSubscriptionImpl> get copyWith =>
      __$$SeriesSubscriptionImplCopyWithImpl<_$SeriesSubscriptionImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SeriesSubscriptionImplToJson(
      this,
    );
  }
}

abstract class _SeriesSubscription extends SeriesSubscription {
  const factory _SeriesSubscription(
      {required final String id,
      required final String userId,
      required final String seriesId,
      final SeriesSubscriptionStatus status,
      final int currentSessionIndex,
      final int completedSessions,
      required final DateTime subscribedAt,
      final DateTime? lastSessionCompletedAt,
      final DateTime? unsubscribedAt,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$SeriesSubscriptionImpl;
  const _SeriesSubscription._() : super._();

  factory _SeriesSubscription.fromJson(Map<String, dynamic> json) =
      _$SeriesSubscriptionImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get seriesId;
  @override
  SeriesSubscriptionStatus get status;

  /// 0-indexed position in the series — points at the next session to play.
  @override
  int get currentSessionIndex;

  /// Number of sessions the user has completed. Bumped server-side when
  /// `POST /api/series/:id/progress` is called.
  @override
  int get completedSessions;
  @override
  DateTime get subscribedAt;
  @override
  DateTime? get lastSessionCompletedAt;
  @override
  DateTime? get unsubscribedAt;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of SeriesSubscription
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SeriesSubscriptionImplCopyWith<_$SeriesSubscriptionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
