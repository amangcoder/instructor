// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'streak_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DayStatus _$DayStatusFromJson(Map<String, dynamic> json) {
  return _DayStatus.fromJson(json);
}

/// @nodoc
mixin _$DayStatus {
  /// The calendar date (in user's local timezone).
  DateTime get date => throw _privateConstructorUsedError;

  /// True if the user completed at least one session on this day.
  bool get completed => throw _privateConstructorUsedError;

  /// True if this is today (used for highlighting the current day).
  bool get isToday => throw _privateConstructorUsedError;

  /// True if a streak freeze was used to preserve the streak on this day.
  bool get frozeStreak => throw _privateConstructorUsedError;

  /// Serializes this DayStatus to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DayStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DayStatusCopyWith<DayStatus> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DayStatusCopyWith<$Res> {
  factory $DayStatusCopyWith(DayStatus value, $Res Function(DayStatus) then) =
      _$DayStatusCopyWithImpl<$Res, DayStatus>;
  @useResult
  $Res call({DateTime date, bool completed, bool isToday, bool frozeStreak});
}

/// @nodoc
class _$DayStatusCopyWithImpl<$Res, $Val extends DayStatus>
    implements $DayStatusCopyWith<$Res> {
  _$DayStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DayStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? completed = null,
    Object? isToday = null,
    Object? frozeStreak = null,
  }) {
    return _then(_value.copyWith(
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      completed: null == completed
          ? _value.completed
          : completed // ignore: cast_nullable_to_non_nullable
              as bool,
      isToday: null == isToday
          ? _value.isToday
          : isToday // ignore: cast_nullable_to_non_nullable
              as bool,
      frozeStreak: null == frozeStreak
          ? _value.frozeStreak
          : frozeStreak // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DayStatusImplCopyWith<$Res>
    implements $DayStatusCopyWith<$Res> {
  factory _$$DayStatusImplCopyWith(
          _$DayStatusImpl value, $Res Function(_$DayStatusImpl) then) =
      __$$DayStatusImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime date, bool completed, bool isToday, bool frozeStreak});
}

/// @nodoc
class __$$DayStatusImplCopyWithImpl<$Res>
    extends _$DayStatusCopyWithImpl<$Res, _$DayStatusImpl>
    implements _$$DayStatusImplCopyWith<$Res> {
  __$$DayStatusImplCopyWithImpl(
      _$DayStatusImpl _value, $Res Function(_$DayStatusImpl) _then)
      : super(_value, _then);

  /// Create a copy of DayStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? completed = null,
    Object? isToday = null,
    Object? frozeStreak = null,
  }) {
    return _then(_$DayStatusImpl(
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      completed: null == completed
          ? _value.completed
          : completed // ignore: cast_nullable_to_non_nullable
              as bool,
      isToday: null == isToday
          ? _value.isToday
          : isToday // ignore: cast_nullable_to_non_nullable
              as bool,
      frozeStreak: null == frozeStreak
          ? _value.frozeStreak
          : frozeStreak // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DayStatusImpl extends _DayStatus {
  const _$DayStatusImpl(
      {required this.date,
      required this.completed,
      required this.isToday,
      required this.frozeStreak})
      : super._();

  factory _$DayStatusImpl.fromJson(Map<String, dynamic> json) =>
      _$$DayStatusImplFromJson(json);

  /// The calendar date (in user's local timezone).
  @override
  final DateTime date;

  /// True if the user completed at least one session on this day.
  @override
  final bool completed;

  /// True if this is today (used for highlighting the current day).
  @override
  final bool isToday;

  /// True if a streak freeze was used to preserve the streak on this day.
  @override
  final bool frozeStreak;

  @override
  String toString() {
    return 'DayStatus(date: $date, completed: $completed, isToday: $isToday, frozeStreak: $frozeStreak)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DayStatusImpl &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.completed, completed) ||
                other.completed == completed) &&
            (identical(other.isToday, isToday) || other.isToday == isToday) &&
            (identical(other.frozeStreak, frozeStreak) ||
                other.frozeStreak == frozeStreak));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, date, completed, isToday, frozeStreak);

  /// Create a copy of DayStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DayStatusImplCopyWith<_$DayStatusImpl> get copyWith =>
      __$$DayStatusImplCopyWithImpl<_$DayStatusImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DayStatusImplToJson(
      this,
    );
  }
}

abstract class _DayStatus extends DayStatus {
  const factory _DayStatus(
      {required final DateTime date,
      required final bool completed,
      required final bool isToday,
      required final bool frozeStreak}) = _$DayStatusImpl;
  const _DayStatus._() : super._();

  factory _DayStatus.fromJson(Map<String, dynamic> json) =
      _$DayStatusImpl.fromJson;

  /// The calendar date (in user's local timezone).
  @override
  DateTime get date;

  /// True if the user completed at least one session on this day.
  @override
  bool get completed;

  /// True if this is today (used for highlighting the current day).
  @override
  bool get isToday;

  /// True if a streak freeze was used to preserve the streak on this day.
  @override
  bool get frozeStreak;

  /// Create a copy of DayStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DayStatusImplCopyWith<_$DayStatusImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StreakState _$StreakStateFromJson(Map<String, dynamic> json) {
  return _StreakState.fromJson(json);
}

/// @nodoc
mixin _$StreakState {
  /// The number of consecutive calendar days on which the user completed
  /// at least one session. Resets to 0 if a full day passes with no completion
  /// and no streak freeze is available.
  int get currentStreak => throw _privateConstructorUsedError;

  /// The longest consecutive-day streak the user has ever achieved.
  /// Never decreases, only increases when [currentStreak] exceeds it.
  int get longestStreak => throw _privateConstructorUsedError;

  /// True if the user has completed at least one session today (in local timezone).
  bool get completedToday => throw _privateConstructorUsedError;

  /// Number of streak freezes currently available to the user (0–2).
  /// Replenished at a rate of 1 per 7 consecutive active days.
  int get freezesAvailable => throw _privateConstructorUsedError;

  /// List of days in the calendar view, typically the last 30 days.
  /// Provided for UI rendering of streak calendars.
  List<DayStatus> get calendarDays => throw _privateConstructorUsedError;

  /// Timestamp when this snapshot was computed (for debugging/caching).
  DateTime get computedAt => throw _privateConstructorUsedError;

  /// Serializes this StreakState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StreakState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StreakStateCopyWith<StreakState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StreakStateCopyWith<$Res> {
  factory $StreakStateCopyWith(
          StreakState value, $Res Function(StreakState) then) =
      _$StreakStateCopyWithImpl<$Res, StreakState>;
  @useResult
  $Res call(
      {int currentStreak,
      int longestStreak,
      bool completedToday,
      int freezesAvailable,
      List<DayStatus> calendarDays,
      DateTime computedAt});
}

/// @nodoc
class _$StreakStateCopyWithImpl<$Res, $Val extends StreakState>
    implements $StreakStateCopyWith<$Res> {
  _$StreakStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StreakState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentStreak = null,
    Object? longestStreak = null,
    Object? completedToday = null,
    Object? freezesAvailable = null,
    Object? calendarDays = null,
    Object? computedAt = null,
  }) {
    return _then(_value.copyWith(
      currentStreak: null == currentStreak
          ? _value.currentStreak
          : currentStreak // ignore: cast_nullable_to_non_nullable
              as int,
      longestStreak: null == longestStreak
          ? _value.longestStreak
          : longestStreak // ignore: cast_nullable_to_non_nullable
              as int,
      completedToday: null == completedToday
          ? _value.completedToday
          : completedToday // ignore: cast_nullable_to_non_nullable
              as bool,
      freezesAvailable: null == freezesAvailable
          ? _value.freezesAvailable
          : freezesAvailable // ignore: cast_nullable_to_non_nullable
              as int,
      calendarDays: null == calendarDays
          ? _value.calendarDays
          : calendarDays // ignore: cast_nullable_to_non_nullable
              as List<DayStatus>,
      computedAt: null == computedAt
          ? _value.computedAt
          : computedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StreakStateImplCopyWith<$Res>
    implements $StreakStateCopyWith<$Res> {
  factory _$$StreakStateImplCopyWith(
          _$StreakStateImpl value, $Res Function(_$StreakStateImpl) then) =
      __$$StreakStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int currentStreak,
      int longestStreak,
      bool completedToday,
      int freezesAvailable,
      List<DayStatus> calendarDays,
      DateTime computedAt});
}

/// @nodoc
class __$$StreakStateImplCopyWithImpl<$Res>
    extends _$StreakStateCopyWithImpl<$Res, _$StreakStateImpl>
    implements _$$StreakStateImplCopyWith<$Res> {
  __$$StreakStateImplCopyWithImpl(
      _$StreakStateImpl _value, $Res Function(_$StreakStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of StreakState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentStreak = null,
    Object? longestStreak = null,
    Object? completedToday = null,
    Object? freezesAvailable = null,
    Object? calendarDays = null,
    Object? computedAt = null,
  }) {
    return _then(_$StreakStateImpl(
      currentStreak: null == currentStreak
          ? _value.currentStreak
          : currentStreak // ignore: cast_nullable_to_non_nullable
              as int,
      longestStreak: null == longestStreak
          ? _value.longestStreak
          : longestStreak // ignore: cast_nullable_to_non_nullable
              as int,
      completedToday: null == completedToday
          ? _value.completedToday
          : completedToday // ignore: cast_nullable_to_non_nullable
              as bool,
      freezesAvailable: null == freezesAvailable
          ? _value.freezesAvailable
          : freezesAvailable // ignore: cast_nullable_to_non_nullable
              as int,
      calendarDays: null == calendarDays
          ? _value._calendarDays
          : calendarDays // ignore: cast_nullable_to_non_nullable
              as List<DayStatus>,
      computedAt: null == computedAt
          ? _value.computedAt
          : computedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StreakStateImpl extends _StreakState {
  const _$StreakStateImpl(
      {required this.currentStreak,
      required this.longestStreak,
      required this.completedToday,
      required this.freezesAvailable,
      required final List<DayStatus> calendarDays,
      required this.computedAt})
      : _calendarDays = calendarDays,
        super._();

  factory _$StreakStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$StreakStateImplFromJson(json);

  /// The number of consecutive calendar days on which the user completed
  /// at least one session. Resets to 0 if a full day passes with no completion
  /// and no streak freeze is available.
  @override
  final int currentStreak;

  /// The longest consecutive-day streak the user has ever achieved.
  /// Never decreases, only increases when [currentStreak] exceeds it.
  @override
  final int longestStreak;

  /// True if the user has completed at least one session today (in local timezone).
  @override
  final bool completedToday;

  /// Number of streak freezes currently available to the user (0–2).
  /// Replenished at a rate of 1 per 7 consecutive active days.
  @override
  final int freezesAvailable;

  /// List of days in the calendar view, typically the last 30 days.
  /// Provided for UI rendering of streak calendars.
  final List<DayStatus> _calendarDays;

  /// List of days in the calendar view, typically the last 30 days.
  /// Provided for UI rendering of streak calendars.
  @override
  List<DayStatus> get calendarDays {
    if (_calendarDays is EqualUnmodifiableListView) return _calendarDays;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_calendarDays);
  }

  /// Timestamp when this snapshot was computed (for debugging/caching).
  @override
  final DateTime computedAt;

  @override
  String toString() {
    return 'StreakState(currentStreak: $currentStreak, longestStreak: $longestStreak, completedToday: $completedToday, freezesAvailable: $freezesAvailable, calendarDays: $calendarDays, computedAt: $computedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StreakStateImpl &&
            (identical(other.currentStreak, currentStreak) ||
                other.currentStreak == currentStreak) &&
            (identical(other.longestStreak, longestStreak) ||
                other.longestStreak == longestStreak) &&
            (identical(other.completedToday, completedToday) ||
                other.completedToday == completedToday) &&
            (identical(other.freezesAvailable, freezesAvailable) ||
                other.freezesAvailable == freezesAvailable) &&
            const DeepCollectionEquality()
                .equals(other._calendarDays, _calendarDays) &&
            (identical(other.computedAt, computedAt) ||
                other.computedAt == computedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      currentStreak,
      longestStreak,
      completedToday,
      freezesAvailable,
      const DeepCollectionEquality().hash(_calendarDays),
      computedAt);

  /// Create a copy of StreakState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StreakStateImplCopyWith<_$StreakStateImpl> get copyWith =>
      __$$StreakStateImplCopyWithImpl<_$StreakStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StreakStateImplToJson(
      this,
    );
  }
}

abstract class _StreakState extends StreakState {
  const factory _StreakState(
      {required final int currentStreak,
      required final int longestStreak,
      required final bool completedToday,
      required final int freezesAvailable,
      required final List<DayStatus> calendarDays,
      required final DateTime computedAt}) = _$StreakStateImpl;
  const _StreakState._() : super._();

  factory _StreakState.fromJson(Map<String, dynamic> json) =
      _$StreakStateImpl.fromJson;

  /// The number of consecutive calendar days on which the user completed
  /// at least one session. Resets to 0 if a full day passes with no completion
  /// and no streak freeze is available.
  @override
  int get currentStreak;

  /// The longest consecutive-day streak the user has ever achieved.
  /// Never decreases, only increases when [currentStreak] exceeds it.
  @override
  int get longestStreak;

  /// True if the user has completed at least one session today (in local timezone).
  @override
  bool get completedToday;

  /// Number of streak freezes currently available to the user (0–2).
  /// Replenished at a rate of 1 per 7 consecutive active days.
  @override
  int get freezesAvailable;

  /// List of days in the calendar view, typically the last 30 days.
  /// Provided for UI rendering of streak calendars.
  @override
  List<DayStatus> get calendarDays;

  /// Timestamp when this snapshot was computed (for debugging/caching).
  @override
  DateTime get computedAt;

  /// Create a copy of StreakState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StreakStateImplCopyWith<_$StreakStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
