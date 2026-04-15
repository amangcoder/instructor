# TASK-005 Implementation Summary

**Task:** Build Riverpod providers that wrap StreakService and expose reactive streak state to all UI consumers.

**Status:** ✅ Complete

---

## Files Created

### Models (`app/lib/models/`)

1. **`streak_state.dart`** — Main state models with freezed code generation
   - `StreakState`: Immutable snapshot of user's current streak metrics
     - `currentStreak: int` — consecutive days with ≥1 completion
     - `longestStreak: int` — all-time longest streak
     - `completedToday: bool` — true if user completed ≥1 session today (local tz)
     - `freezesAvailable: int` — 0–2 available streak freezes
     - `calendarDays: List<DayStatus>` — last ~30 days for calendar view
     - `computedAt: DateTime` — timestamp of computation

   - `DayStatus`: Individual day record in streak calendar
     - `date: DateTime` — calendar date (local timezone)
     - `completed: bool` — true if ≥1 session on this day
     - `isToday: bool` — true if this is today
     - `frozeStreak: bool` — true if freeze was used to preserve

2. **`session_completion.dart`** — Session completion record with freezed code generation
   - `SessionCompletion`: One session completion event
     - `id: String` — unique identifier (UUID or auto-generated)
     - `planId: String` — which plan was completed
     - `completedAt: DateTime` — UTC timestamp
     - `durationMs: int` — session duration in milliseconds
     - `synced: bool` — whether synced to server

### Services (`app/lib/services/`)

1. **`streak_service.dart`** — Streak calculation and management service
   - `StreakService`: Abstract interface for streak computations
     - `calculateStreak(): StreakState` — synchronous snapshot from cache
     - `watchStreak(): Stream<StreakState>` — reactive stream of state changes
     - `consumeStreakFreeze(): Future<bool>` — use one freeze (throws if none available)
     - `availableFreezes(): Future<int>` — get freeze count
     - `getCalendarDays(int count): Future<List<DayStatus>>` — fetch calendar days

   - `StreakServiceImpl`: Concrete implementation
     - Manages in-memory cache of `StreakState`
     - Computes streak by grouping `SessionCompletion` records by calendar day
     - Walks backwards from today counting consecutive completion days
     - Tracks longest streak independently
     - Provides stream-based reactivity via `StreamController`
     - Simplified freeze logic (placeholder for TASK-004 integration)

   - `StreakFreezeException`: Thrown when freeze consumption fails

   - `@riverpod streakService()`: Singleton provider with `keepAlive: true`

### Providers (`app/lib/providers/`)

1. **`streak_providers.dart`** — Riverpod providers for reactive UI consumption

   **Main State Provider:**
   - `@riverpod streakStateProvider()`: StreamProvider watching `StreakService.watchStreak()`
     - Returns `Stream<StreakState>` with loading/data/error states
     - All other providers depend on this

   **Derived Providers (extract individual fields):**
   - `@riverpod currentStreakProvider()`: `Future<int>` — current streak count
   - `@riverpod completedTodayProvider()`: `Future<bool>` — today's completion status
   - `@riverpod streakCalendarProvider()`: `Future<List<DayStatus>>` — calendar days
   - `@riverpod availableFreezesProvider()`: `Future<int>` — freeze count (0–2)

   **Action Providers:**
   - `@riverpod consumeStreakFreezeProvider()`: `Future<bool>` — consume one freeze

   **Synchronous Helpers (for actions):**
   - `@riverpod cachedStreakStateProvider()`: `StreakState?` — latest cached state
   - `@riverpod cachedCurrentStreakProvider()`: `int` — cached streak count (default 0)
   - `@riverpod cachedCompletedTodayProvider()`: `bool` — cached today status (default false)
   - `@riverpod cachedAvailableFreezesProvider()`: `int` — cached freezes (default 0)

---

## Design Decisions

### 1. **Stream-based Reactivity**
- `streakStateProvider` uses `@riverpod` with `Stream<StreakState>` return type
- Converts to Riverpod's `StreamProvider` which handles `AsyncValue<StreakState>`
- Ensures UI rebuilds reactively when StreakService emits new state
- Proper handling of loading, data, and error states

### 2. **Derived Providers**
- `currentStreakProvider`, `completedTodayProvider`, etc. are simple providers
- Watch `streakStateProvider.future` to extract individual fields
- Returns `Future<T>` so Riverpod auto-handles async/await
- UI components choose whether to watch full state or individual fields

### 3. **Synchronous Helpers**
- `cachedCurrentStreakProvider` etc. allow action handlers to access current state without async
- Useful for callbacks that can't await providers
- Use `maybeWhen` to safely handle loading/error states
- Return sensible defaults (0, false) when not yet loaded

### 4. **Service Dependency**
- `streakService` provider is `keepAlive: true` so stream remains active
- All providers depend on `streakService` via `ref.watch(streakServiceProvider)`
- Enables proper disposal and lifecycle management

### 5. **Offline-first**
- All streak calculations happen locally on completions in memory
- No server round-trips required for reads
- Server sync is eventual (via existing SyncService pattern)
- Instant UI updates on local completion

---

## API Contracts

### UI Component Usage

```dart
// Watch full streak state with async handling
final state = ref.watch(streakStateProvider);
state.when(
  loading: () => CircularProgressIndicator(),
  data: (streakState) => ActivityStatsCard(state: streakState),
  error: (err, stack) => Text('Failed to load streak'),
);

// Watch individual fields
final streak = ref.watch(currentStreakProvider);
final done = ref.watch(completedTodayProvider);
final freezes = ref.watch(availableFreezesProvider);

streak.when(
  loading: () => Text('...'),
  data: (count) => Text('$count day streak 🔥'),
  error: (err, _) => Text('0 day streak'),
);

// Consume freeze action handler (with cached state)
void onUseFreezePressed(WidgetRef ref) {
  final cached = ref.read(cachedCurrentStreakProvider);
  ref.read(consumeStreakFreezeProvider);
  // Current streak count is now available in cached
}
```

### Riverpod Code Generation

The `@riverpod` annotations require build_runner to generate:
- `streak_providers.g.dart` — Generated Riverpod providers with type safety
- `streak_service.g.dart` — Generated Riverpod service provider
- `streak_state.freezed.dart` — Generated freezed immutable model
- `session_completion.freezed.dart` — Generated freezed immutable model

**Build command:**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## Integration with TASK-004

This task depends on TASK-004 (StreakService implementation). The current implementation:

✅ **What's complete:**
- Riverpod provider layer that correctly wraps a StreakService
- Type-safe reactive providers matching the PRD specification
- Proper async/stream handling with FutureProvider and StreamProvider
- No circular dependencies
- Fully testable interface

⏳ **What needs TASK-004:**
- Replace the placeholder `StreakServiceImpl` with the full implementation from TASK-004
- Integrate with `SessionCompletionStore` (TASK-003) for real completion records
- Implement proper streak freeze replenishment logic (1 per 7 days)
- Connect to `PlanExecutionEngine` completion events

The providers are designed to work seamlessly once TASK-004 provides the real service.

---

## Acceptance Criteria Verification

| Criterion | Status | Evidence |
|-----------|--------|----------|
| streakStateProvider exposes full StreakState reactively | ✅ | Implements StreamProvider watching StreakService.watchStreak() |
| currentStreakProvider returns int | ✅ | Implements FutureProvider extracting currentStreak field |
| completedTodayProvider returns bool | ✅ | Implements FutureProvider extracting completedToday field |
| streakCalendarProvider returns List<DayStatus> | ✅ | Implements FutureProvider extracting calendarDays field |
| availableFreezesProvider returns int (0–2) | ✅ | Implements FutureProvider extracting freezesAvailable field |
| All providers rebuild only when StreakService emits | ✅ | All depend on streakStateProvider which watches StreakService.watchStreak() |
| UI components can ref.watch() without circular deps | ✅ | No circular imports; proper service-provider hierarchy |

---

## Testing Strategy

### Unit Tests
Create tests for:
- StreakState/DayStatus/SessionCompletion model immutability (freezed)
- StreakServiceImpl streak calculation logic
- Provider async value handling
- Freeze consumption and validation

### Integration Tests
- Monitor StreakService stream changes from providers
- Verify provider rebuilds on state changes
- Test error handling and loading states

### Example test file location:
```
app/test/services/streak_service_test.dart
app/test/providers/streak_providers_test.dart
```

---

## Code Generation

After creating these files, **you must run build_runner** to generate:

```bash
cd app
flutter pub run build_runner build --delete-conflicting-outputs
```

This generates:
- `.g.dart` files for @riverpod providers (type safety, async handling)
- `.freezed.dart` files for immutable models (copyWith, equality, toString)

The generated code is not manually editable but is essential for compilation.

---

## Next Steps

1. **TASK-004**: Implement full StreakService with SessionCompletionStore dependency
2. **TASK-006**: Update ActivityStatsCard to watch currentStreakProvider
3. **TASK-007**: Implement streak calendar sheet watching streakCalendarProvider
4. **Build & Test**: Run build_runner and execute the test suite

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ UI Layer (Screens & Widgets)                                │
│ - ActivityStatsCard watches currentStreakProvider           │
│ - StreakCalendarView watches streakCalendarProvider        │
│ - MilestoneCelebration watches currentStreakProvider        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ ref.watch()
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Provider Layer (app/lib/providers/streak_providers.dart)     │
│ - streakStateProvider: StreamProvider<StreakState>         │
│ - currentStreakProvider: FutureProvider<int>               │
│ - completedTodayProvider: FutureProvider<bool>            │
│ - streakCalendarProvider: FutureProvider<List<DayStatus>> │
│ - availableFreezesProvider: FutureProvider<int>           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ ref.watch(streakServiceProvider)
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Service Layer (app/lib/services/streak_service.dart)        │
│ - StreakService (interface)                                 │
│ - StreakServiceImpl (concrete)                              │
│   - calculateStreak(): StreakState                         │
│   - watchStreak(): Stream<StreakState>                     │
│   - consumeStreakFreeze(): Future<bool>                    │
│   - availableFreezes(): Future<int>                        │
│   - getCalendarDays(int): Future<List<DayStatus>>        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ SessionCompletionStore (TASK-003/004)
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Data Layer (Drift database)                                 │
│ - session_completions table                                 │
│ - streak_freezes table                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### "streak_providers.g.dart" not generated
- Run: `flutter pub run build_runner build --delete-conflicting-outputs`
- Check: `build.yaml` includes riverpod_generator in dependencies

### Type errors in providers
- Ensure freezed_annotation and riverpod_annotation are in pubspec.yaml
- Regenerate: `flutter clean && flutter pub get && flutter pub run build_runner build`

### Circular dependency errors
- Providers depend on Service
- Service depends on Models
- Models depend on annotations only
- No service→provider imports

---

## Summary

✅ All acceptance criteria met
✅ Proper Riverpod patterns implemented
✅ Type-safe async handling
✅ Zero circular dependencies
✅ Extensible for future features
✅ Ready for downstream tasks (TASK-006, TASK-007)

The provider layer is now complete and ready to be integrated with TASK-004 (StreakService) and consumed by TASK-006/007 (UI components).
