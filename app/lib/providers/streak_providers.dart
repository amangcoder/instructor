/// StreakProviders — Riverpod providers that expose reactive streak state.
///
/// ## Architecture
///
/// These providers are the UI boundary layer for streak data. All UI components
/// that need streak information watch these providers, never the raw StreakService.
///
/// The providers follow these patterns:
/// - [streakStateProvider]: StreamProvider watching StreakService.watchStreak()
///   for reactive state changes
/// - [currentStreakProvider], [completedTodayProvider], etc.: Simple providers
///   that extract individual fields from [streakStateProvider]
/// - All providers rebuild only when StreakService emits new state
///
/// ## Usage in UI
///
/// ```dart
/// // Watch the full state
/// final state = ref.watch(streakStateProvider);
///
/// // Or watch individual fields
/// final count = ref.watch(currentStreakProvider);
/// final done = ref.watch(completedTodayProvider);
/// ```
library streak_providers;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/models/streak_state.dart';
import 'package:instructor/services/streak_service.dart';

part 'streak_providers.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main state provider
// ─────────────────────────────────────────────────────────────────────────────

/// Reactive stream of [StreakState] from [StreakService].
///
/// Rebuilds whenever the streak service emits a new state (session completion,
/// day rollover, freeze consumption, etc.).
///
/// Returns an [AsyncValue<StreakState>] that handles loading/error states:
/// - [AsyncValue.loading]: Service is initializing
/// - [AsyncValue.data]: Current streak state
/// - [AsyncValue.error]: Service failed to provide state
///
/// All other providers depend on this provider.
@riverpod
Stream<StreakState> streakStateProvider(Ref ref) {
  final service = ref.watch(streakServiceProvider);
  return service.watchStreak();
}

// ─────────────────────────────────────────────────────────────────────────────
// Derived providers
// ─────────────────────────────────────────────────────────────────────────────

/// Current streak count as an integer.
///
/// Rebuilds only when [streakStateProvider] emits and the current streak value
/// changes. Safe to use for comparison-based widget rebuilds.
///
/// Returns an [AsyncValue<int>] that extracts the [StreakState.currentStreak]:
/// - [AsyncValue.loading]: Streak is initializing
/// - [AsyncValue.data]: The current streak count (may be 0)
/// - [AsyncValue.error]: Stream failed
@riverpod
Future<int> currentStreakProvider(Ref ref) async {
  final state = await ref.watch(streakStateProvider.future);
  return state.currentStreak;
}

/// Today's completion status as a boolean.
///
/// True if the user has completed at least one session today (in local timezone).
/// False otherwise.
///
/// Used by widgets to show "Done today" / "Start a session" status.
///
/// Returns an [AsyncValue<bool>]:
/// - [AsyncValue.loading]: Status is initializing
/// - [AsyncValue.data]: true/false indicating today's completion
/// - [AsyncValue.error]: Stream failed
@riverpod
Future<bool> completedTodayProvider(Ref ref) async {
  final state = await ref.watch(streakStateProvider.future);
  return state.completedToday;
}

/// Streak calendar as a list of [DayStatus] for the last ~30 days.
///
/// Used by StreakCalendarView to render a visual grid of completed/missed days.
///
/// Returns an [AsyncValue<List<DayStatus>>]:
/// - [AsyncValue.loading]: Calendar is loading
/// - [AsyncValue.data]: List of day statuses (oldest → newest)
/// - [AsyncValue.error]: Stream failed
@riverpod
Future<List<DayStatus>> streakCalendarProvider(Ref ref) async {
  final state = await ref.watch(streakStateProvider.future);
  return state.calendarDays;
}

/// Available streak freezes (0–2).
///
/// A streak freeze preserves the streak for one missed day. The user has a
/// maximum of 2 freezes available at any time, replenished at 1 per 7
/// consecutive days of activity.
///
/// Used by UI to show/enable the "Use Freeze" button.
///
/// Returns an [AsyncValue<int>]:
/// - [AsyncValue.loading]: Freeze count is initializing
/// - [AsyncValue.data]: Number of freezes available (0–2)
/// - [AsyncValue.error]: Stream failed
@riverpod
Future<int> availableFreezesProvider(Ref ref) async {
  final state = await ref.watch(streakStateProvider.future);
  return state.freezesAvailable;
}

// ─────────────────────────────────────────────────────────────────────────────
// Action providers
// ─────────────────────────────────────────────────────────────────────────────

/// Consumes one available streak freeze.
///
/// Throws [StreakFreezeException] if no freezes are available.
/// Otherwise, updates [availableFreezesProvider] reactively.
///
/// Usage:
/// ```dart
/// ref.read(consumeStreakFreezeProvider).call();
/// ```
@riverpod
Future<bool> consumeStreakFreezeProvider(Ref ref) async {
  final service = ref.watch(streakServiceProvider);
  return await service.consumeStreakFreeze();
}

// ─────────────────────────────────────────────────────────────────────────────
// Synchronous helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Synchronous access to the latest [StreakState] from the cache.
///
/// Useful for action handlers that need the current state synchronously
/// without async overhead. Returns the cached state; does not await the stream.
///
/// Returns:
/// - [StreakState] if available
/// - null if stream is still loading or errored
@riverpod
StreakState? cachedStreakStateProvider(Ref ref) {
  final asyncState = ref.watch(streakStateProvider);
  return asyncState.maybeWhen(
    data: (state) => state,
    orElse: () => null,
  );
}

/// Synchronous access to the current streak count.
///
/// Returns the cached current streak; 0 if not yet loaded.
@riverpod
int cachedCurrentStreakProvider(Ref ref) {
  final state = ref.watch(cachedStreakStateProvider);
  return state?.currentStreak ?? 0;
}

/// Synchronous access to today's completion status.
///
/// Returns cached status; false if not yet loaded.
@riverpod
bool cachedCompletedTodayProvider(Ref ref) {
  final state = ref.watch(cachedStreakStateProvider);
  return state?.completedToday ?? false;
}

/// Synchronous access to available freezes.
///
/// Returns cached freeze count; 0 if not yet loaded.
@riverpod
int cachedAvailableFreezesProvider(Ref ref) {
  final state = ref.watch(cachedStreakStateProvider);
  return state?.freezesAvailable ?? 0;
}
