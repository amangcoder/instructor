# TASK-003: Build Runner Regeneration Required

## Summary
Two new `@riverpod` stream providers have been added to `app/lib/providers/settings_providers.dart`:

1. **activityLevelSetting** - Stream<String>
   - Watches `AppSettingsKeys.profileActivityLevel`
   - Maps null to empty string '' (unset state)
   - Returns raw string value: 'beginner', 'intermediate', 'advanced', or ''

2. **profileGoalsSetting** - Stream<List<String>>
   - Watches `AppSettingsKeys.profileGoals`
   - Maps null/empty to empty List<String>
   - Parses comma-separated values into List<String>

## Default Constants Added
```dart
const String kDefaultActivityLevel = '';
const List<String> kDefaultGoals = [];
```

## Required Next Step: Code Generation
The generated file `app/lib/providers/settings_providers.g.dart` needs to be regenerated to include provider declarations for the two new functions.

### Command to Run:
```bash
cd /Users/amangupta/Projects/instructor/app && dart run build_runner build --delete-conflicting-outputs
```

### Alternative Method:
```bash
bash /Users/amangupta/Projects/instructor/run_build_runner.sh
```

## Implementation Details

### activityLevelSetting Provider
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

### profileGoalsSetting Provider
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

## Acceptance Criteria Status

- ✅ `activityLevelSetting` provider watches `AppSettingsKeys.profileActivityLevel`
- ✅ `activityLevelSetting` maps null to '' and returns raw string
- ✅ `profileGoalsSetting` provider watches `AppSettingsKeys.profileGoals`
- ✅ `profileGoalsSetting` maps null/empty to empty List<String>
- ✅ `profileGoalsSetting` splits on comma for List<String> parsing
- ✅ Both providers decorated with `@riverpod` annotation
- ✅ Default value constants added: `kDefaultActivityLevel` and `kDefaultGoals`
- ⏳ Code generation pending (requires running build_runner command)

## Pattern Verification
Both new providers follow the exact same pattern as existing providers:
- Import `appSettingsProvider` ✓
- Get settings via `ref.watch(appSettingsProvider)` ✓
- Watch specific key via `settings.watch(AppSettingsKeys.xxx)` ✓
- Map null to default value ✓
- Apply type-specific parsing/transformation ✓
- Annotated with `@riverpod` ✓
- Return Stream of appropriate type ✓

All code is in place and ready for build_runner to generate the provider declarations in `settings_providers.g.dart`.
