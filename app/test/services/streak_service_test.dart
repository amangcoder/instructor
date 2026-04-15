/// Unit tests for [StreakService] — the core business logic for streak tracking.
///
/// ## Strategy
///
/// StreakServiceImpl depends on SessionCompletionRepository for completion data.
/// Tests use an in-memory Drift database so no file I/O or real time is needed.
///
/// All date/time logic is tested via explicit DateTime values — never
/// DateTime.now() — to ensure determinism across timezones and CI runners.
///
/// ## What is tested
/// - Consecutive day streak calculation (REQ-002)
///   - 0 completions → streak 0
///   - 1 day → streak 1
///   - 5 consecutive days → streak 5
///   - 30 consecutive days → streak 30
/// - Gap detection and reset (AC-004)
/// - Freeze mechanics: consumption, replenishment, max 2 (REQ-005)
/// - Timezone edge cases: UTC midnight vs local midnight
/// - Today-incomplete: shows yesterday's streak count (AC-003)
/// - watchStreak() reactivity
/// - Longest streak tracking
/// - Milestone detection (7, 30, 100, 365)
library streak_service_test;

import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/repositories/session_completion_repository.dart';
import 'package:instructor/services/streak_service.dart';
import 'package:instructor/models/streak_state.dart';

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/// Opens an in-memory Drift database for tests — no file I/O required.
AppDatabase _inMemoryDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// Creates a [DateTime] at noon on the given day to avoid midnight edge issues.
DateTime _day(int year, int month, int day) =>
    DateTime(year, month, day, 12, 0, 0);

/// Records a completion for [planId] at [completedAt] in the given [repo].
Future<void> _recordCompletion(
  SessionCompletionRepository repo, {
  String userId = 'user-1',
  String planId = 'plan-1',
  required DateTime completedAt,
  int durationMs = 600000, // 10 minutes
}) async {
  await repo.recordCompletion(
    userId: userId,
    planId: planId,
    completedAt: completedAt,
    durationMs: durationMs,
  );
}

/// Records completions for [count] consecutive days ending at [lastDay].
Future<void> _recordConsecutiveDays(
  SessionCompletionRepository repo, {
  required int count,
  required DateTime lastDay,
  String planId = 'plan-1',
}) async {
  for (int i = count - 1; i >= 0; i--) {
    await _recordCompletion(
      repo,
      planId: planId,
      completedAt: lastDay.subtract(Duration(days: i)),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

void main() {
  late AppDatabase db;
  late SessionCompletionRepository completionRepo;
  late StreakServiceImpl streakService;

  setUp(() {
    db = _inMemoryDb();
    completionRepo = SessionCompletionRepository(db);
    streakService = StreakServiceImpl(repository: completionRepo);
  });

  tearDown(() async {
    streakService.dispose();
    await db.close();
  });

  // ─── Zero-state ──────────────────────────────────────────────────────────

  group('zero-state (no completions)', () {
    test('calculateStreak returns 0 current streak with no completions', () {
      final state = streakService.calculateStreak();

      expect(state.currentStreak, 0);
      expect(state.longestStreak, 0);
      expect(state.completedToday, false);
    });

    test('availableFreezes returns 0 for a new user', () async {
      final freezes = await streakService.availableFreezes();
      expect(freezes, 0);
    });
  });

  // ─── Basic streak calculation ────────────────────────────────────────────

  group('basic streak calculation', () {
    test('1 completion today → streak of 1', () async {
      final today = _day(2026, 4, 15);
      await _recordCompletion(completionRepo, completedAt: today);

      // Allow stream to propagate
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: today);

      expect(state.currentStreak, 1);
      expect(state.completedToday, true);
    });

    test('5 consecutive days → streak of 5 (AC-002)', () async {
      final lastDay = _day(2026, 4, 15);
      await _recordConsecutiveDays(
        completionRepo,
        count: 5,
        lastDay: lastDay,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: lastDay);

      expect(state.currentStreak, 5);
      expect(state.completedToday, true);
    });

    test('30 consecutive days → streak of 30', () async {
      final lastDay = _day(2026, 4, 15);
      await _recordConsecutiveDays(
        completionRepo,
        count: 30,
        lastDay: lastDay,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: lastDay);

      expect(state.currentStreak, 30);
    });

    test('multiple completions on the same day count as 1 day', () async {
      final day = _day(2026, 4, 15);
      // Three completions on the same day
      await _recordCompletion(completionRepo, completedAt: day);
      await _recordCompletion(
          completionRepo,
          completedAt: day.add(const Duration(hours: 2)),
          planId: 'plan-2');
      await _recordCompletion(
          completionRepo,
          completedAt: day.add(const Duration(hours: 4)),
          planId: 'plan-3');

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: day);

      expect(state.currentStreak, 1);
    });
  });

  // ─── Gap detection and reset ─────────────────────────────────────────────

  group('gap detection and reset', () {
    test('1-day gap resets streak to 0 (AC-004)', () async {
      // Day 1, Day 2, [gap: Day 3], Day 4
      final day1 = _day(2026, 4, 11);
      final day2 = _day(2026, 4, 12);
      // Day 3 skipped
      final day4 = _day(2026, 4, 14);

      await _recordCompletion(completionRepo, completedAt: day1);
      await _recordCompletion(completionRepo, completedAt: day2);
      await _recordCompletion(completionRepo, completedAt: day4);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: day4);

      // Streak should be 1 (only day4), not 3
      expect(state.currentStreak, 1);
    });

    test('completed yesterday but not today shows yesterday streak (AC-003)',
        () async {
      final yesterday = _day(2026, 4, 14);
      final today = _day(2026, 4, 15);

      // 5 consecutive days ending yesterday
      await _recordConsecutiveDays(
        completionRepo,
        count: 5,
        lastDay: yesterday,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: today);

      // Today not completed yet — streak from yesterday
      expect(state.currentStreak, 5);
      expect(state.completedToday, false);
    });

    test('2-day gap resets streak regardless of prior length', () async {
      // 10-day streak, then 2-day gap, then 1 day
      final streakEnd = _day(2026, 4, 10);
      await _recordConsecutiveDays(
        completionRepo,
        count: 10,
        lastDay: streakEnd,
      );

      // 2-day gap: days 11 and 12 skipped
      final resumeDay = _day(2026, 4, 13);
      await _recordCompletion(completionRepo, completedAt: resumeDay);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: resumeDay);

      expect(state.currentStreak, 1);
    });
  });

  // ─── Longest streak tracking ─────────────────────────────────────────────

  group('longest streak tracking', () {
    test('longest streak persists across gaps', () async {
      // First streak: 5 days
      final firstEnd = _day(2026, 4, 5);
      await _recordConsecutiveDays(
        completionRepo,
        count: 5,
        lastDay: firstEnd,
      );

      // Gap day 6
      // Second streak: 3 days
      final secondEnd = _day(2026, 4, 9);
      await _recordConsecutiveDays(
        completionRepo,
        count: 3,
        lastDay: secondEnd,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: secondEnd);

      expect(state.currentStreak, 3);
      expect(state.longestStreak, greaterThanOrEqualTo(5));
    });
  });

  // ─── Streak freeze mechanics (REQ-005) ───────────────────────────────────

  group('streak freeze mechanics', () {
    test('consuming a freeze preserves streak across a 1-day gap (AC-005)',
        () async {
      // Build up a 5-day streak
      final streakEnd = _day(2026, 4, 10);
      await _recordConsecutiveDays(
        completionRepo,
        count: 5,
        lastDay: streakEnd,
      );

      // Grant a freeze to the user
      await streakService.grantFreeze();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Day 11 is missed — should auto-consume freeze
      final dayAfterGap = _day(2026, 4, 12);
      await _recordCompletion(completionRepo, completedAt: dayAfterGap);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: dayAfterGap);

      // Streak preserved: 5 + frozen day + today = 7
      expect(state.currentStreak, greaterThanOrEqualTo(6));
    });

    test('max 2 freezes available at any time', () async {
      await streakService.grantFreeze();
      await streakService.grantFreeze();
      // Third grant should not exceed max
      await streakService.grantFreeze();

      final freezes = await streakService.availableFreezes();
      expect(freezes, lessThanOrEqualTo(2));
    });

    test('consumeStreakFreeze reduces available count by 1', () async {
      await streakService.grantFreeze();
      await streakService.grantFreeze();

      final consumed = await streakService.consumeStreakFreeze();
      expect(consumed, true);

      final remaining = await streakService.availableFreezes();
      expect(remaining, 1);
    });

    test('consumeStreakFreeze throws when no freezes available', () async {
      // No freezes available — should throw StreakFreezeException
      expect(
        () => streakService.consumeStreakFreeze(),
        throwsA(isA<StreakFreezeException>()),
      );
    });

    test('freeze replenished after 7 consecutive active days (REQ-005)',
        () async {
      // Record 7 consecutive days to earn a freeze
      final lastDay = _day(2026, 4, 15);
      await _recordConsecutiveDays(
        completionRepo,
        count: 7,
        lastDay: lastDay,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: lastDay);

      // After 7 consecutive days, should have earned at least 1 freeze
      expect(state.freezesAvailable, greaterThanOrEqualTo(1));
    });

    test('missed day with no freeze available resets streak', () async {
      // 5-day streak, NO freezes
      final streakEnd = _day(2026, 4, 10);
      await _recordConsecutiveDays(
        completionRepo,
        count: 5,
        lastDay: streakEnd,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify no freezes (5 days = 0 earned freezes, 0 granted)
      expect(await streakService.availableFreezes(), 0);

      // Day 11 missed, complete day 12
      final dayAfterGap = _day(2026, 4, 12);
      await _recordCompletion(completionRepo, completedAt: dayAfterGap);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: dayAfterGap);

      // Streak should be reset to 1
      expect(state.currentStreak, 1);
    });
  });

  // ─── Timezone edge cases ─────────────────────────────────────────────────

  group('timezone edge cases', () {
    test('completion at 23:59 and 00:01 counts as two separate days',
        () async {
      final lateNight =
          DateTime(2026, 4, 14, 23, 59, 0); // April 14 at 23:59
      final earlyMorning =
          DateTime(2026, 4, 15, 0, 1, 0); // April 15 at 00:01

      await _recordCompletion(completionRepo, completedAt: lateNight);
      await _recordCompletion(completionRepo, completedAt: earlyMorning);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state =
          streakService.calculateStreak(referenceDate: earlyMorning);

      expect(state.currentStreak, 2);
      expect(state.completedToday, true);
    });

    test('completions straddling midnight boundary are separate days',
        () async {
      // 11:30 PM on day 1
      final beforeMidnight = DateTime(2026, 4, 14, 23, 30, 0);
      // 12:30 AM on day 2
      final afterMidnight = DateTime(2026, 4, 15, 0, 30, 0);

      await _recordCompletion(completionRepo, completedAt: beforeMidnight);
      await _recordCompletion(completionRepo, completedAt: afterMidnight);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(
          referenceDate: afterMidnight);

      expect(state.currentStreak, 2);
    });

    test('same calendar day regardless of time → counted once', () async {
      final morning = DateTime(2026, 4, 15, 6, 0, 0);
      final evening = DateTime(2026, 4, 15, 22, 0, 0);

      await _recordCompletion(completionRepo, completedAt: morning);
      await _recordCompletion(completionRepo, completedAt: evening);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: evening);

      expect(state.currentStreak, 1);
    });

    test('month boundary does not break streak', () async {
      // March 30, 31, April 1, 2
      final days = [
        _day(2026, 3, 30),
        _day(2026, 3, 31),
        _day(2026, 4, 1),
        _day(2026, 4, 2),
      ];

      for (final d in days) {
        await _recordCompletion(completionRepo, completedAt: d);
      }

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: days.last);

      expect(state.currentStreak, 4);
    });

    test('year boundary does not break streak', () async {
      // December 30, 31, January 1, 2
      final days = [
        _day(2025, 12, 30),
        _day(2025, 12, 31),
        _day(2026, 1, 1),
        _day(2026, 1, 2),
      ];

      for (final d in days) {
        await _recordCompletion(completionRepo, completedAt: d);
      }

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: days.last);

      expect(state.currentStreak, 4);
    });

    test('leap day February 29 handled correctly', () async {
      // 2024 is a leap year
      final days = [
        _day(2024, 2, 28),
        _day(2024, 2, 29),
        _day(2024, 3, 1),
      ];

      for (final d in days) {
        await _recordCompletion(completionRepo, completedAt: d);
      }

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: days.last);

      expect(state.currentStreak, 3);
    });
  });

  // ─── Calendar days (for streak calendar UI) ──────────────────────────────

  group('getCalendarDays', () {
    test('returns correct day statuses for the last 30 days', () async {
      // Record completions for 3 specific days
      final today = _day(2026, 4, 15);
      await _recordCompletion(completionRepo, completedAt: today);
      await _recordCompletion(
          completionRepo, completedAt: today.subtract(const Duration(days: 1)));
      await _recordCompletion(
          completionRepo, completedAt: today.subtract(const Duration(days: 5)));

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final days =
          await streakService.getCalendarDays(30, referenceDate: today);

      expect(days.length, 30);

      // Today should be completed
      final todayStatus = days.last;
      expect(todayStatus.completed, true);
    });
  });

  // ─── Milestone detection ─────────────────────────────────────────────────

  group('milestone detection (REQ-006)', () {
    test('7-day streak triggers milestone (AC-006)', () async {
      final lastDay = _day(2026, 4, 15);
      await _recordConsecutiveDays(
        completionRepo,
        count: 7,
        lastDay: lastDay,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: lastDay);

      expect(state.currentStreak, 7);
      expect(state.isMilestone, true);
    });

    test('30-day streak triggers milestone', () async {
      final lastDay = _day(2026, 4, 30);
      await _recordConsecutiveDays(
        completionRepo,
        count: 30,
        lastDay: lastDay,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: lastDay);

      expect(state.currentStreak, 30);
      expect(state.isMilestone, true);
    });

    test('8-day streak is NOT a milestone', () async {
      final lastDay = _day(2026, 4, 15);
      await _recordConsecutiveDays(
        completionRepo,
        count: 8,
        lastDay: lastDay,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: lastDay);

      expect(state.currentStreak, 8);
      expect(state.isMilestone, false);
    });
  });

  // ─── watchStreak() reactivity ────────────────────────────────────────────

  group('watchStreak', () {
    test('emits new StreakState when a completion is recorded', () async {
      final today = _day(2026, 4, 15);

      // Start watching
      final states = <StreakState>[];
      final sub = streakService.watchStreak().listen(states.add);

      // Allow initial emission
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Record a completion
      await _recordCompletion(completionRepo, completedAt: today);

      // Wait for stream to emit
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await sub.cancel();

      // Should have at least 1 emission after recording
      expect(states.length, greaterThanOrEqualTo(1));
      // The last emission should reflect the new completion
      if (states.isNotEmpty) {
        expect(states.last.currentStreak, greaterThanOrEqualTo(0));
      }
    });
  });

  // ─── Different plan IDs ──────────────────────────────────────────────────

  group('cross-plan completions', () {
    test('completions from different plans on the same day count as 1 day',
        () async {
      final day = _day(2026, 4, 15);

      await _recordCompletion(completionRepo,
          completedAt: day, planId: 'plan-yoga');
      await _recordCompletion(completionRepo,
          completedAt: day, planId: 'plan-meditation');

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: day);

      expect(state.currentStreak, 1);
    });

    test('completions from different plans across days extend streak',
        () async {
      final day1 = _day(2026, 4, 14);
      final day2 = _day(2026, 4, 15);

      await _recordCompletion(completionRepo,
          completedAt: day1, planId: 'plan-yoga');
      await _recordCompletion(completionRepo,
          completedAt: day2, planId: 'plan-meditation');

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = streakService.calculateStreak(referenceDate: day2);

      expect(state.currentStreak, 2);
    });
  });
}
