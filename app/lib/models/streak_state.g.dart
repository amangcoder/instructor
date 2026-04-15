// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'streak_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DayStatusImpl _$$DayStatusImplFromJson(Map<String, dynamic> json) =>
    _$DayStatusImpl(
      date: DateTime.parse(json['date'] as String),
      completed: json['completed'] as bool,
      isToday: json['isToday'] as bool,
      frozeStreak: json['frozeStreak'] as bool,
    );

Map<String, dynamic> _$$DayStatusImplToJson(_$DayStatusImpl instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'completed': instance.completed,
      'isToday': instance.isToday,
      'frozeStreak': instance.frozeStreak,
    };

_$StreakStateImpl _$$StreakStateImplFromJson(Map<String, dynamic> json) =>
    _$StreakStateImpl(
      currentStreak: (json['currentStreak'] as num).toInt(),
      longestStreak: (json['longestStreak'] as num).toInt(),
      completedToday: json['completedToday'] as bool,
      freezesAvailable: (json['freezesAvailable'] as num).toInt(),
      calendarDays: (json['calendarDays'] as List<dynamic>)
          .map((e) => DayStatus.fromJson(e as Map<String, dynamic>))
          .toList(),
      computedAt: DateTime.parse(json['computedAt'] as String),
    );

Map<String, dynamic> _$$StreakStateImplToJson(_$StreakStateImpl instance) =>
    <String, dynamic>{
      'currentStreak': instance.currentStreak,
      'longestStreak': instance.longestStreak,
      'completedToday': instance.completedToday,
      'freezesAvailable': instance.freezesAvailable,
      'calendarDays': instance.calendarDays,
      'computedAt': instance.computedAt.toIso8601String(),
    };
