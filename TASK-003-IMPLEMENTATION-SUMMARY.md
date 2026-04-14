# TASK-003: Implementation Summary

**Task:** Add two new @riverpod stream providers to settings_providers.dart
**Status:** ✅ Source code implementation complete
**Dependencies:** TASK-002 (AppSettingsKeys) - ✅ Verified as complete

## Changes Made

### File: `app/lib/providers/settings_providers.dart`

#### 1. Added Default Value Constants (Lines 35-39)
```dart
/// Default activity level (empty = unset).
const String kDefaultActivityLevel = '';

/// Default goals list (empty = unset).
const List<String> kDefaultGoals = [];
```

**Location:** After `kDefaultTtsLocale` constant definition
**Pattern Match:** Follows existing constant naming convention (kDefault*)

#### 2. Added activityLevelSetting Provider (Lines 166-177)
```dart
/// Reactive stream of the user's activity level preference.
///
/// Emits [kDefaultActivityLevel] (empty string) when the key is absent.
/// Valid values: 'beginner', 'intermediate', 'advanced', or '' (unset).
@riverpod
Stream<String> activityLevelSetting(Ref ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.watch(AppSettingsKeys.profileActivityLevel).map((raw) {
    if (raw == null) return kDefaultActivityLevel;
    return raw;
  });
}
```

**Behavior:**
- Watches `AppSettingsKeys.profileActivityLevel` (added in TASK-002)
- Returns `kDefaultActivityLevel` ('')  when key is null
- Returns raw string value ('beginner', 'intermediate', 'advanced', or '')
- Emits stream updates whenever the setting changes in SQLite

#### 3. Added profileGoalsSetting Provider (Lines 179-190)
```dart
/// Reactive stream of the user's goal preferences.
///
/// Emits [kDefaultGoals] (empty list) when the key is absent or empty.
/// When present, parses comma-separated goal tags into a List<String>.
@riverpod
Stream<List<String>> profileGoalsSetting(Ref ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.watch(AppSettingsKeys.profileGoals).map((raw) {
    if (raw == null || raw.isEmpty) return kDefaultGoals;
    return raw.split(',').map((s) => s.trim()).toList();
  });
}
```

**Behavior:**
- Watches `AppSettingsKeys.profileGoals` (added in TASK-002)
- Returns `kDefaultGoals` (empty List<String>) when key is null or empty
- Splits comma-separated string into List<String> with trimmed values
- Example: "yoga,meditation,workout" → ["yoga", "meditation", "workout"]
- Emits stream updates whenever the setting changes in SQLite

## Acceptance Criteria Verification

| Criterion | Status | Notes |
|-----------|--------|-------|
| activityLevelSetting emits '' when key absent | ✅ | Maps null to `kDefaultActivityLevel` |
| activityLevelSetting returns 'beginner'\|'intermediate'\|'advanced' when set | ✅ | Returns raw string value |
| profileGoalsSetting emits [] when key absent | ✅ | Maps null/empty to `kDefaultGoals` |
| profileGoalsSetting emits List<String> of tags when set | ✅ | Splits on comma |
| Both providers have @riverpod annotation | ✅ | Line 170 and 183 |
| Settings_providers.g.dart regenerated via build_runner | ⏳ | See "Next Steps" below |
| Default constants added (kDefaultActivityLevel, kDefaultGoals) | ✅ | Lines 36 and 39 |

## Pattern Verification

Both providers follow the exact same pattern as existing providers (e.g., `themeModeSetting`):

✅ Import existing `appSettingsProvider`
✅ Use `ref.watch(appSettingsProvider)` to get settings object
✅ Call `settings.watch(AppSettingsKeys.xxx)` with the specific key
✅ Use `.map()` to transform raw string value
✅ Handle null case by returning appropriate default
✅ Apply type-specific parsing (no parsing for activity level, comma-split for goals)
✅ Return `Stream<T>` where T is the appropriate type
✅ Decorated with `@riverpod` annotation
✅ Documented with JSDoc comments

## Next Steps: Code Generation

The Riverpod code generator (`build_runner`) needs to be run to generate the provider declarations in `settings_providers.g.dart`. This will create:

- `activityLevelSettingProvider` - AutoDisposeStreamProvider<String>
- `profileGoalsSettingProvider` - AutoDisposeStreamProvider<List<String>>
- Hash functions for code change detection
- Typedef references for backward compatibility

### Run Command:
```bash
cd /Users/amangupta/Projects/instructor/app && dart run build_runner build --delete-conflicting-outputs
```

This command should be run from the project root or app directory to regenerate the .g.dart files.

## Verification Checklist

- [x] Source code added to settings_providers.dart
- [x] File line count increased (159 → 190 lines)
- [x] Both providers follow existing pattern
- [x] Default constants defined
- [x] @riverpod annotations present
- [x] Null handling implemented correctly
- [x] Type signatures correct (Stream<String> and Stream<List<String>>)
- [x] AppSettingsKeys dependency verified (TASK-002)
- [ ] build_runner executed (requires shell access)
- [ ] settings_providers.g.dart updated
- [ ] Tests written (if applicable)
- [ ] Code review passed

## Dependencies

- ✅ **TASK-002**: App Settings Keys (profileActivityLevel, profileGoals)
  - Verified present in `app/lib/services/app_settings.dart` lines 87 and 93

## Files Modified

1. `app/lib/providers/settings_providers.dart` - Source code ✅ Updated
2. `app/lib/providers/settings_providers.g.dart` - Generated code ⏳ Pending build_runner

## Related Components (Downstream Dependencies)

These providers will be consumed by:
- **TASK-007**: PersonalizationCard widget (will use both providers via `ref.watch()`)
- Architecture: PersonalizationProviders component
