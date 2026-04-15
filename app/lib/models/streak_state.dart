/// StreakState — immutable data class representing the user's streak metrics.
///
/// All fields are computed from the local session_completions table and
/// represent the current state of the user's streak at the time of calculation.
library streak_state;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'streak_state.freezed.dart';
part 'streak_state.g.dart';

/// Represents the status of a single day in the streak calendar.
///
/// Used by StreakCalendarView to render a visual calendar of completed days.
@freezed
class DayStatus with _$DayStatus {
  const DayStatus._();

  const factory DayStatus({
    /// The calendar date (in user's local timezone).
    required DateTime date,

    /// True if the user completed at least one session on this day.
    required bool completed,

    /// True if this is today (used for highlighting the current day).
    required bool isToday,

    /// True if a streak freeze was used to preserve the streak on this day.
    required bool frozeStreak,
  }) = _DayStatus;

  factory DayStatus.fromJson(Map<String, dynamic> json) =>
      _$DayStatusFromJson(json);
}

/// Immutable snapshot of the user's current streak metrics.
///
/// Computed by [StreakService] from [SessionCompletion] records in the local
/// database. All dates are in the user's local timezone.
@freezed
class StreakState with _$StreakState {
  const StreakState._();

  const factory StreakState({
    /// The number of consecutive calendar days on which the user completed
    /// at least one session. Resets to 0 if a full day passes with no completion
    /// and no streak freeze is available.
    required int currentStreak,

    /// The longest consecutive-day streak the user has ever achieved.
    /// Never decreases, only increases when [currentStreak] exceeds it.
    required int longestStreak,

    /// True if the user has completed at least one session today (in local timezone).
    required bool completedToday,

    /// Number of streak freezes currently available to the user (0–2).
    /// Replenished at a rate of 1 per 7 consecutive active days.
    required int freezesAvailable,

    /// List of days in the calendar view, typically the last 30 days.
    /// Provided for UI rendering of streak calendars.
    required List<DayStatus> calendarDays,

    /// Timestamp when this snapshot was computed (for debugging/caching).
    required DateTime computedAt,
  }) = _StreakState;

  factory StreakState.fromJson(Map<String, dynamic> json) =>
      _$StreakStateFromJson(json);

  /// Whether the current streak count is a milestone (7, 30, 100, 365).
  ///
  /// Used by MilestoneCelebration to trigger celebration animations (REQ-006).
  bool get isMilestone => const [7, 30, 100, 365].contains(currentStreak);
}
