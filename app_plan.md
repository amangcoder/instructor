# Plan: Sidebar & Profile Screen

## Context

The 4th bottom-nav tab ("Profile") currently renders `SettingsScreen` — a settings dump with no real user profile content. The `account_circle` icon button in the AppBar has an empty `onPressed: () {}`. Neither gives users a sense of identity or personalization.

The PRD explicitly calls for:
- **User profile fields** (fitness level, goals) injected into the LLM prompt for AI plan generation (§10 AI Integration)
- **Subscription tier display** (§11 Monetization — Free vs Premium badge)
- **Streak tracking** (§7 P1 features)
- **Design philosophy**: "The Invisible App" — profile should be clean and purposeful

**Sidebar** = an `EndDrawer` that slides in from the right when the `account_circle` AppBar icon is tapped. Quick account actions + app info.

**Profile** = the full `/settings` screen, restructured from a generic settings dump into a proper profile-first page with personalization, stats, and settings below.

---

## What Changes

### 1. `app/lib/services/app_settings.dart`

Add two new keys to `AppSettingsKeys`:

```dart
// Profile personalization (fed to LLM for AI plan generation)
static const String profileActivityLevel = 'profile_activity_level';
// Values: 'beginner' | 'intermediate' | 'advanced'

static const String profileGoals = 'profile_goals';
// Comma-separated: 'yoga,meditation,workout,cooking,routine,focus'
```

### 2. `app/lib/providers/settings_providers.dart`

Add two stream providers (same pattern as `themeModeSettingProvider`):

```dart
@riverpod
Stream<String> activityLevelSettingProvider(Ref ref) {
  return ref.watch(appSettingsProvider).watch(AppSettingsKeys.profileActivityLevel)
      .map((v) => v ?? 'beginner');
}

@riverpod
Stream<List<String>> profileGoalsSettingProvider(Ref ref) {
  return ref.watch(appSettingsProvider).watch(AppSettingsKeys.profileGoals)
      .map((v) => v == null || v.isEmpty ? [] : v.split(','));
}
```

### 3. New: `app/lib/screens/settings/widgets/profile_header.dart`

A self-contained widget: large avatar (initials from email), email, subscription badge.

```
┌─────────────────────────────────┐
│         [AM]  ← colored avatar  │
│   user@email.com                │
│   [● Free]   [Upgrade →]        │
└─────────────────────────────────┘
```

- Avatar: `CircleAvatar` with initials derived from email (first char, uppercase)
- Color: `colorScheme.primaryContainer`, 72px radius
- If unauthenticated: shows a person_off icon + "Not signed in" + Login button
- Subscription badge: `Chip` with `● Free` in `colorScheme.outline` color. "Upgrade" is a `TextButton` that does nothing (stub — no subscription system yet)
- Reads `currentUserProvider` and `isAuthenticatedProvider`

### 4. New: `app/lib/screens/settings/widgets/personalization_card.dart`

Activity level + goals chip selectors for LLM personalization:

```
FOR YOU
┌─────────────────────────────────┐
│ Activity Level                  │
│ [Beginner ✓] [Intermediate] [Advanced] │
│                                 │
│ Your Goals                      │
│ [Yoga ✓] [Meditation ✓] [Workout] │
│ [Cooking] [Routine] [Focus]     │
└─────────────────────────────────┘
```

- Uses `FilterChip` for multi-select goals, `ChoiceChip` for single-select activity level
- On tap: writes to `AppSettings` via the providers above
- "These help AI generate better plans for you" subtitle text

### 5. New: `app/lib/screens/settings/widgets/activity_stats_card.dart`

Three stat tiles in a row:

```
MY ACTIVITY
┌──────────┬──────────┬──────────┐
│    12    │    —     │   🔥 0   │
│  Plans   │  Played  │  Streak  │
└──────────┴──────────┴──────────┘
```

- **Plans created**: live count from `planListProvider()` (already available)
- **Played**: `—` for now (no history table yet) — label "Sessions"
- **Streak**: `0` (placeholder, shown with `🔥` prefix using `Icons.local_fire_department`)
- Uses `Consumer` + `ref.watch(planListProvider())` for plans count

### 6. New: `app/lib/screens/settings/widgets/profile_sidebar.dart`

Content for the `EndDrawer`. A `Drawer` widget containing:

```
┌────────────────────────────┐
│ [←]              Account   │
│                            │
│ [AM avatar - 56px]         │
│ user@email.com             │
│ ● Free Plan  [Upgrade →]   │
│                            │
│ ─── QUICK LINKS ───        │
│ ☁️  Cloud Sync (coming soon)│
│ ❓ Help & Feedback          │
│ ★ Rate Instructor           │
│ 📄 Privacy Policy           │
│                            │
│ ─── ACCOUNT ────           │
│ [Sign Out]                  │
│                            │
│ v1.0.0 · Instructor        │
└────────────────────────────┘
```

- `Sign Out` calls `_logout()` (same logic as in `AuthSection`)
- Cloud Sync, Help, Rate: `ListTile` with `enabled: false` or stubs (no crash — just show a coming-soon snack)
- Rate: will use `url_launcher` IF already a dependency; otherwise stub
- If unauthenticated: shows Login button instead of Sign Out

### 7. `app/lib/screens/settings/settings_screen.dart` — Full restructure

**AppBar changes:**
- Same `AppBranding.brandedAppBar`
- `account_circle` icon `onPressed` → `Scaffold.of(context).openEndDrawer()`
- Add `endDrawer: const ProfileSidebar()` to the `Scaffold`

**Body changes** — new section order:

```
Profile Header         ← NEW _ProfileHeader()
MY ACTIVITY            ← NEW _ActivityStatsCard section header + card
FOR YOU                ← NEW _PersonalizationCard section header + card
ACCOUNT                ← existing AuthSection (keep as-is, it still handles login/logout inline)
PREFERENCES            ← Theme + Voice (rename from "Core Settings", remove AuthSection from here)
AUDIO & SPEECH         ← unchanged
NOTIFICATIONS          ← unchanged
BATTERY (Android)      ← unchanged
Footer                 ← unchanged
```

The `AuthSection` moves out of the "Core Settings" card and becomes its own `ACCOUNT` section card (same card style, just repositioned below personalization).

---

## Files to Create / Modify

| File | Action |
|------|--------|
| `app/lib/services/app_settings.dart` | Add 2 new keys: `profileActivityLevel`, `profileGoals` |
| `app/lib/providers/settings_providers.dart` | Add `activityLevelSettingProvider`, `profileGoalsSettingProvider` |
| `app/lib/screens/settings/settings_screen.dart` | Add `endDrawer`, reorder sections, add profile header + stats + personalization |
| `app/lib/screens/settings/widgets/profile_header.dart` | **NEW** — avatar, email, subscription badge |
| `app/lib/screens/settings/widgets/personalization_card.dart` | **NEW** — activity level + goals chip selectors |
| `app/lib/screens/settings/widgets/activity_stats_card.dart` | **NEW** — plans count, sessions, streak row |
| `app/lib/screens/settings/widgets/profile_sidebar.dart` | **NEW** — EndDrawer with quick links + sign out |

No router changes needed — `/settings` route stays the same.  
No new routes needed — the sidebar is an `EndDrawer`, not a navigable screen.  
No `build_runner` needed — no new Riverpod `@riverpod` annotations, just `StateProvider` / `StreamProvider` patterns.

---

## Existing Patterns to Reuse

- `_SectionHeader` and `_SettingsCard` from `settings_screen.dart` — reuse for all new sections
- `AuthSection._logout()` logic — copy into `profile_sidebar.dart` for the Sign Out tile
- `themeModeSettingProvider` in `settings_providers.dart` — exact same pattern for new providers
- `currentUserProvider`, `isAuthenticatedProvider` from `auth_providers.dart` — already used in `AuthSection`
- `planListProvider()` from `plan_providers.dart` — for plans count stat

---

## Verification

1. Tap "Profile" tab → profile header shows avatar with email initials and "Free" badge
2. Tap `account_circle` icon → EndDrawer slides in from right with sidebar content
3. Sidebar → tap "Sign Out" → logout dialog appears → confirms → navigates to login
4. Profile → tap an activity level chip → selection updates visually and persists on restart
5. Profile → toggle a goal chip → persists on restart
6. Not signed in: profile header shows "Not signed in", sidebar shows Login button
7. Plans count in stats reflects actual number of plans in local DB
