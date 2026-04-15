/// StreakService — computes streak metrics from session completion records.
///
/// ## Algorithm
///
/// The service calculates streak by:
/// 1. Grouping [SessionCompletionRecord] records by calendar day (user's local tz).
/// 2. Walking backwards from today, counting consecutive days with >= 1 completion.
/// 3. On a gap, checking if a streak freeze is available to preserve the streak.
/// 4. Replenishing freezes at 1 per 7 consecutive days of activity.
///
/// ## Offline-first design
///
/// All calculations are done locally from the [SessionCompletionRepository].
/// The server sync is eventual (via SyncService) — streak is always live
/// and reactive to local completions without waiting for network.
library streak_service;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/models/streak_state.dart';
import 'package:instructor/repositories/session_completion_repository.dart';

part 'streak_service.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// Maximum number of streak freezes a user can hold.
const int kMaxFreezes = 2;

/// Number of consecutive active days required to earn 1 freeze.
const int kDaysPerFreeze = 7;

/// Milestone thresholds for celebration animations.
const List<int> kMilestones = [7, 30, 100, 365];

// ─────────────────────────────────────────────────────────────────────────────
// Exception types
// ─────────────────────────────────────────────────────────────────────────────

/// Thrown when a streak freeze cannot be consumed (e.g., none available).
final class StreakFreezeException implements Exception {
  const StreakFreezeException(this.message);

  final String message;

  @override
  String toString() => 'StreakFreezeException: $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Main service interface
// ─────────────────────────────────────────────────────────────────────────────

/// Abstract interface for streak service implementations.
abstract interface class StreakService {
  /// Calculates the current streak state from completion data.
  ///
  /// Returns a [StreakState] snapshot with current streak, longest streak,
  /// today's completion status, available freezes, and calendar days.
  ///
  /// [referenceDate] overrides "today" for deterministic testing.
  /// When [referenceDate] is provided, fresh data is loaded from the repository
  /// to avoid stream timing issues.
  Future<StreakState> calculateStreak({DateTime? referenceDate});

  /// Watches streak state changes reactively.
  ///
  /// Emits a new [StreakState] whenever:
  /// - A new session completion is recorded
  /// - The calendar day changes (triggers streak reset check)
  /// - A streak freeze is consumed
  ///
  /// This stream is the source of truth for UI components watching streak data.
  Stream<StreakState> watchStreak();

  /// Consumes one streak freeze to preserve the current streak.
  ///
  /// Returns false if no freezes are available.
  /// Otherwise, decrements [availableFreezes] by 1 and returns true.
  Future<bool> consumeStreakFreeze();

  /// Returns the number of streak freezes currently available (0-2).
  Future<int> availableFreezes();

  /// Grants one streak freeze, up to [kMaxFreezes].
  ///
  /// Used for testing and for awarding freezes from external events.
  Future<void> grantFreeze();

  /// Returns a list of [DayStatus] for the last [count] calendar days.
  ///
  /// Used by StreakCalendarView to render the calendar grid.
  /// Days are sorted oldest -> newest.
  ///
  /// [referenceDate] overrides "today" for deterministic testing.
  Future<List<DayStatus>> getCalendarDays(int count, {DateTime? referenceDate});
}

// ─────────────────────────────────────────────────────────────────────────────
// Concrete implementation
// ─────────────────────────────────────────────────────────────────────────────

/// Production [StreakService] implementation backed by [SessionCompletionRepository].
///
/// Subscribes to the repository's [watchCompletions] stream and recomputes
/// streak state on each update. Also monitors day-boundary crossings to
/// handle streak resets when the calendar day changes.
class StreakServiceImpl implements StreakService {
  StreakServiceImpl({
    required this.repository,
  }) {
    // Subscribe to completion stream for reactive updates
    _completionsSub = repository.watchCompletions().listen(
      (completions) {
        _completions = completions;
        _recompute();
      },
      onError: (e) {
        debugPrint('[StreakService] Error in completions stream: $e');
      },
    );

    // Set up a timer to recompute at midnight (day boundary)
    _scheduleMidnightRecompute();
  }

  final SessionCompletionRepository repository;

  /// In-memory list of completion records, kept in sync by the stream subscription.
  List<SessionCompletionRecord> _completions = [];

  /// Number of consumed freezes (tracked locally).
  int _consumedFreezeCount = 0;

  /// Number of explicitly granted freezes (via [grantFreeze]).
  int _grantedFreezeCount = 0;

  /// Internal streak state cache.
  late StreakState _cachedState = _computeStreak();

  /// Controller for [watchStreak] stream.
  final _stateController = StreamController<StreakState>.broadcast();

  /// Subscription to the repository's completion stream.
  StreamSubscription<List<SessionCompletionRecord>>? _completionsSub;

  /// Timer for day-boundary recompute.
  Timer? _midnightTimer;

  @override
  Future<StreakState> calculateStreak({DateTime? referenceDate}) async {
    if (referenceDate != null) {
      // Load fresh data from repository to avoid stream timing issues
      _completions = await repository.getAllCompletions();
      return _computeStreak(referenceDate: referenceDate);
    }
    return _cachedState;
  }

  @override
  Stream<StreakState> watchStreak() => Stream.multi((controller) {
        controller.add(_cachedState);
        final sub = _stateController.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = sub.cancel;
      });

  @override
  Future<bool> consumeStreakFreeze() async {
    if (_cachedState.freezesAvailable <= 0) {
      return false;
    }

    _consumedFreezeCount++;
    _recompute();
    return true;
  }

  @override
  Future<int> availableFreezes() async => _cachedState.freezesAvailable;

  @override
  Future<void> grantFreeze() async {
    // Decrease consumed count (which increases available freezes)
    if (_consumedFreezeCount > 0) {
      _consumedFreezeCount--;
    } else {
      // Track granted freezes by using negative consumed count
      _grantedFreezeCount++;
    }
    _recompute();
  }

  @override
  Future<List<DayStatus>> getCalendarDays(int count, {DateTime? referenceDate}) async {
    if (referenceDate != null) {
      // Load fresh data from repository to avoid stream timing issues
      _completions = await repository.getAllCompletions();
      final state = _computeStreak(referenceDate: referenceDate);
      return state.calendarDays.take(count).toList();
    }
    return _cachedState.calendarDays.take(count).toList();
  }

  /// Recomputes streak state and notifies listeners.
  void _recompute() {
    _cachedState = _computeStreak();
    _stateController.add(_cachedState);
  }

  /// Core streak computation algorithm.
  ///
  /// Groups completions by calendar day (user's local timezone), walks
  /// backwards from today counting consecutive days. Gap days consume
  /// freezes if available; otherwise reset the streak.
  ///
  /// [referenceDate] overrides "today" for deterministic testing.
  StreakState _computeStreak({DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_completions.isEmpty) {
      return StreakState(
        currentStreak: 0,
        longestStreak: 0,
        completedToday: false,
        freezesAvailable: (_grantedFreezeCount - _consumedFreezeCount).clamp(0, kMaxFreezes),
        calendarDays: _buildCalendarDays(today, {}, {}),
        computedAt: now,
      );
    }

    // ── Group completions by calendar day ──────────────────────────────
    final completionDays = <DateTime>{};
    for (final completion in _completions) {
      final local = completion.completedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      completionDays.add(day);
    }

    final completedToday = completionDays.contains(today);

    // ── Calculate earned freezes ───────────────────────────────────────
    // 1 freeze per 7 consecutive active days, max kMaxFreezes
    final earnedFreezes = _calculateEarnedFreezes(completionDays, today);
    final totalFreezes =
        (earnedFreezes + _grantedFreezeCount - _consumedFreezeCount).clamp(0, kMaxFreezes);

    // ── Walk backwards to calculate current streak ────────────────────
    // AC-003: If completed yesterday but not today, show yesterday's count
    var currentStreak = 0;
    var freezesUsed = 0;
    final frozenDays = <DateTime>{};

    // Determine start day:
    //   - If completed today, start from today
    //   - If not completed today, start from yesterday (streak is "pending")
    final startDay = completedToday
        ? today
        : today.subtract(const Duration(days: 1));

    var checkDay = startDay;
    const maxDaysToCheck = 400; // Look back > 1 year

    for (var i = 0; i < maxDaysToCheck; i++) {
      if (completionDays.contains(checkDay)) {
        currentStreak++;
      } else {
        // Gap day — try to use a freeze (AC-005)
        if (freezesUsed < totalFreezes) {
          freezesUsed++;
          frozenDays.add(checkDay);
          // Streak continues (frozen day doesn't count towards streak count)
        } else {
          // AC-004: No freeze available — streak is broken
          break;
        }
      }
      checkDay = checkDay.subtract(const Duration(days: 1));
    }

    // ── Calculate longest streak historically ──────────────────────────
    var longestStreak = _calculateLongestStreak(completionDays);
    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }

    // ── Build calendar days ────────────────────────────────────────────
    final calendarDays = _buildCalendarDays(today, completionDays, frozenDays);

    final freezesRemaining = totalFreezes - freezesUsed;

    return StreakState(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      completedToday: completedToday,
      freezesAvailable: freezesRemaining.clamp(0, kMaxFreezes),
      calendarDays: calendarDays,
      computedAt: now,
    );
  }

  /// Calculate earned freezes based on consecutive active days.
  /// 1 freeze per 7 consecutive active days, max [kMaxFreezes].
  /// REQ-005: Replenished at 1 per 7 active days.
  int _calculateEarnedFreezes(Set<DateTime> completionDays, DateTime today) {
    if (completionDays.isEmpty) return 0;

    // Count total consecutive active days from the most recent activity backwards
    var consecutiveDays = 0;
    var checkDay = today;

    for (var i = 0; i < 400; i++) {
      if (completionDays.contains(checkDay)) {
        consecutiveDays++;
        checkDay = checkDay.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    // 1 freeze per 7 consecutive days, capped at kMaxFreezes
    return (consecutiveDays ~/ kDaysPerFreeze).clamp(0, kMaxFreezes);
  }

  /// Calculate the longest streak in the full completion history.
  int _calculateLongestStreak(Set<DateTime> completionDays) {
    if (completionDays.isEmpty) return 0;

    final sortedDays = completionDays.toList()..sort();
    var longest = 1;
    var current = 1;

    for (var i = 1; i < sortedDays.length; i++) {
      final diff = sortedDays[i].difference(sortedDays[i - 1]).inDays;
      if (diff == 1) {
        current++;
        if (current > longest) longest = current;
      } else if (diff > 1) {
        current = 1;
      }
      // diff == 0: same day, skip (multiple completions per day)
    }

    return longest;
  }

  /// Build a list of [DayStatus] for the last 30 days.
  List<DayStatus> _buildCalendarDays(
    DateTime today,
    Set<DateTime> completionDays,
    Set<DateTime> frozenDays,
  ) {
    final days = <DayStatus>[];
    for (var i = 29; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      days.add(
        DayStatus(
          date: day,
          completed: completionDays.contains(day),
          isToday: day == today,
          frozeStreak: frozenDays.contains(day),
        ),
      );
    }
    return days;
  }

  /// Schedule a recompute at midnight to handle day-boundary crossings.
  void _scheduleMidnightRecompute() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = tomorrow.difference(now);

    _midnightTimer?.cancel();
    _midnightTimer = Timer(durationUntilMidnight, () {
      debugPrint('[StreakService] Day boundary crossed — recomputing streak');
      _recompute();
      // Reschedule for next midnight
      _scheduleMidnightRecompute();
    });
  }

  /// Cleanup for the stream controller and subscriptions.
  void dispose() {
    _completionsSub?.cancel();
    _midnightTimer?.cancel();
    _stateController.close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ─────────────────────────────────────────────────────────────────────────────

/// Singleton [StreakService] provider.
///
/// [keepAlive: true] — the service must outlive individual screens so that
/// [watchStreak] streams remain active and reactive.
@Riverpod(keepAlive: true)
StreakService streakService(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final repository = SessionCompletionRepository(database);
  final service = StreakServiceImpl(repository: repository);
  ref.onDispose(service.dispose);
  return service;
}
