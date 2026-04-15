// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'streak_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$totalSessionCountHash() => r'e7f3ded688ad4116156b1b05d05e52ed82edbcd7';

/// Live total count of recorded session completions.
///
/// Watches the repository stream so the UI updates as new completions land.
///
/// Copied from [totalSessionCount].
@ProviderFor(totalSessionCount)
final totalSessionCountProvider = AutoDisposeStreamProvider<int>.internal(
  totalSessionCount,
  name: r'totalSessionCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$totalSessionCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TotalSessionCountRef = AutoDisposeStreamProviderRef<int>;
String _$streakStateHash() => r'c5f55f2f954edb0af35a9a0beb5a7bc85a69df47';

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
///
/// Copied from [streakState].
@ProviderFor(streakState)
final streakStateProvider = AutoDisposeStreamProvider<StreakState>.internal(
  streakState,
  name: r'streakStateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$streakStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StreakStateRef = AutoDisposeStreamProviderRef<StreakState>;
String _$currentStreakHash() => r'6fcc9b08a16b84b9906f8c529c0ded0f7ae41bd1';

/// Current streak count as an integer.
///
/// Rebuilds only when [streakStateProvider] emits and the current streak value
/// changes. Safe to use for comparison-based widget rebuilds.
///
/// Returns an [AsyncValue<int>] that extracts the [StreakState.currentStreak]:
/// - [AsyncValue.loading]: Streak is initializing
/// - [AsyncValue.data]: The current streak count (may be 0)
/// - [AsyncValue.error]: Stream failed
///
/// Copied from [currentStreak].
@ProviderFor(currentStreak)
final currentStreakProvider = AutoDisposeFutureProvider<int>.internal(
  currentStreak,
  name: r'currentStreakProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentStreakHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentStreakRef = AutoDisposeFutureProviderRef<int>;
String _$completedTodayHash() => r'bc87daa3915ddf12257b77a2c199011489ff12a0';

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
///
/// Copied from [completedToday].
@ProviderFor(completedToday)
final completedTodayProvider = AutoDisposeFutureProvider<bool>.internal(
  completedToday,
  name: r'completedTodayProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$completedTodayHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CompletedTodayRef = AutoDisposeFutureProviderRef<bool>;
String _$streakCalendarHash() => r'8964d15e0a6b09dfea1c3e1c60c378f2261a0449';

/// Streak calendar as a list of [DayStatus] for the last ~30 days.
///
/// Used by StreakCalendarView to render a visual grid of completed/missed days.
///
/// Returns an [AsyncValue<List<DayStatus>>]:
/// - [AsyncValue.loading]: Calendar is loading
/// - [AsyncValue.data]: List of day statuses (oldest → newest)
/// - [AsyncValue.error]: Stream failed
///
/// Copied from [streakCalendar].
@ProviderFor(streakCalendar)
final streakCalendarProvider =
    AutoDisposeFutureProvider<List<DayStatus>>.internal(
  streakCalendar,
  name: r'streakCalendarProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$streakCalendarHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StreakCalendarRef = AutoDisposeFutureProviderRef<List<DayStatus>>;
String _$availableFreezesHash() => r'fdceed20b6ae536f430346c997f98a5856b6bb8f';

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
///
/// Copied from [availableFreezes].
@ProviderFor(availableFreezes)
final availableFreezesProvider = AutoDisposeFutureProvider<int>.internal(
  availableFreezes,
  name: r'availableFreezesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$availableFreezesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AvailableFreezesRef = AutoDisposeFutureProviderRef<int>;
String _$consumeStreakFreezeHash() =>
    r'e3ef0518492082d230f0ca837e1071f6bd0b2ec8';

/// Consumes one available streak freeze.
///
/// Throws [StreakFreezeException] if no freezes are available.
/// Otherwise, updates [availableFreezesProvider] reactively.
///
/// Usage:
/// ```dart
/// ref.read(consumeStreakFreezeProvider).call();
/// ```
///
/// Copied from [consumeStreakFreeze].
@ProviderFor(consumeStreakFreeze)
final consumeStreakFreezeProvider = AutoDisposeFutureProvider<bool>.internal(
  consumeStreakFreeze,
  name: r'consumeStreakFreezeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$consumeStreakFreezeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConsumeStreakFreezeRef = AutoDisposeFutureProviderRef<bool>;
String _$cachedStreakStateHash() => r'7620574dc4d78eb633f457630c0cde38d4b23c3f';

/// Synchronous access to the latest [StreakState] from the cache.
///
/// Useful for action handlers that need the current state synchronously
/// without async overhead. Returns the cached state; does not await the stream.
///
/// Returns:
/// - [StreakState] if available
/// - null if stream is still loading or errored
///
/// Copied from [cachedStreakState].
@ProviderFor(cachedStreakState)
final cachedStreakStateProvider = AutoDisposeProvider<StreakState?>.internal(
  cachedStreakState,
  name: r'cachedStreakStateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cachedStreakStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CachedStreakStateRef = AutoDisposeProviderRef<StreakState?>;
String _$cachedCurrentStreakHash() =>
    r'b35eefd2ec27eabc4d48281aa987538533c94b44';

/// Synchronous access to the current streak count.
///
/// Returns the cached current streak; 0 if not yet loaded.
///
/// Copied from [cachedCurrentStreak].
@ProviderFor(cachedCurrentStreak)
final cachedCurrentStreakProvider = AutoDisposeProvider<int>.internal(
  cachedCurrentStreak,
  name: r'cachedCurrentStreakProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cachedCurrentStreakHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CachedCurrentStreakRef = AutoDisposeProviderRef<int>;
String _$cachedCompletedTodayHash() =>
    r'1adc57584cc34483180acc850cc0cafb87af7ff6';

/// Synchronous access to today's completion status.
///
/// Returns cached status; false if not yet loaded.
///
/// Copied from [cachedCompletedToday].
@ProviderFor(cachedCompletedToday)
final cachedCompletedTodayProvider = AutoDisposeProvider<bool>.internal(
  cachedCompletedToday,
  name: r'cachedCompletedTodayProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cachedCompletedTodayHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CachedCompletedTodayRef = AutoDisposeProviderRef<bool>;
String _$cachedAvailableFreezesHash() =>
    r'6e36fcaef31802ab1e2ac9dd836f4b02293069ff';

/// Synchronous access to available freezes.
///
/// Returns cached freeze count; 0 if not yet loaded.
///
/// Copied from [cachedAvailableFreezes].
@ProviderFor(cachedAvailableFreezes)
final cachedAvailableFreezesProvider = AutoDisposeProvider<int>.internal(
  cachedAvailableFreezes,
  name: r'cachedAvailableFreezesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cachedAvailableFreezesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CachedAvailableFreezesRef = AutoDisposeProviderRef<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
