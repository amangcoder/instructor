# Flutter App Changes — Backend-First Architecture

## Context

Moving the app from **local-first SQLite** to **server-first API**. Plans come from the server, not local seeds. User explicitly activates a plan to trigger server-side TTS pre-generation. Two playback modes: Platform TTS (always available) and GenAI TTS (enabled only when all audio is cached on S3). Users have no control over TTS provider.

Assumes the backend changes (Phases 1–3 from the main plan) are already done or running in parallel.

---

## Step 1 — Change `Plan.id` from `int` to `String`

This is the most invasive change. Must be done first because it cascades everywhere.

### 1a. Model: `app/lib/models/plan.dart`

```dart
// BEFORE
required int id,

// AFTER
required String id,
```

Also add the new server-side fields:
```dart
@Default(false) bool isActive,
@Default('none') String ttsStatus,   // none|pending|processing|completed|partial|failed
@Default(0) int ttsTotal,
@Default(0) int ttsCompleted,
```

Remove `isUserCreated` — replaced by the server's library vs. user-plan distinction.

### 1b. Database table: `app/lib/database/tables/plans_table.dart`

Change `id` column from `IntColumn` (auto-increment) to `TextColumn`:
```dart
// BEFORE
IntColumn get id => integer().autoIncrement()();

// AFTER
TextColumn get id => text()();
```

Add new columns:
```dart
BoolColumn get isActive => boolean().withDefault(const Constant(false))();
TextColumn get ttsStatus => text().withDefault(const Constant('none'))();
IntColumn get ttsTotal => integer().withDefault(const Constant(0))();
IntColumn get ttsCompleted => integer().withDefault(const Constant(0))();
```

Remove `isUserCreated` column (was used to split My Plans / Starter Plans — replaced by separate API sources).

### 1c. Database migration: `app/lib/database/app_database.dart`

Bump `schemaVersion` from `5` → `6`.

Add migration block for v5→v6:
- Drop the old `plans` table entirely and recreate it with the new `TEXT` id. This is acceptable because plans will now be fetched fresh from the server — local table becomes a cache only.
- Or: use `DROP TABLE plans; CREATE TABLE plans (...)` inside the migration (simpler than ALTER TABLE for a type change).
- Also remove `walCheckpoint()` and `dbFilePath` getter — no longer needed for sync.

Remove `sync_metadata`-related code from `beforeOpen` (the sync indexes on `plans`).

### 1d. Router: `app/lib/router.dart` (lines 161–169)

Change `int.tryParse(raw)` → keep as String directly:
```dart
// BEFORE
final planId = raw != null ? int.tryParse(raw) : null;
if (planId == null) { ... }
return PlanEditorScreen(planId: planId);

// AFTER
final planId = raw ?? '';
if (planId.isEmpty) { ... }
return PlanEditorScreen(planId: planId);
```

Update `PlanEditorScreen(planId: int?)` → `PlanEditorScreen(planId: String?)`.

### 1e. Execution state table: `app/lib/database/tables/execution_state_table.dart`

Change `planId` from `IntColumn` to `TextColumn`:
```dart
// BEFORE
IntColumn get planId => integer().references(PlansTable, #id, onDelete: KeyAction.cascade)();

// AFTER
TextColumn get planId => text()();  // FK cascade not enforced at SQLite level for text PKs — handle in app
```

### 1f. TTS cache table: `app/lib/database/tables/tts_cache_table.dart`

Change `planId` FK column from `IntColumn` to `TextColumn`:
```dart
// BEFORE
IntColumn get planId => integer().nullable()();

// AFTER
TextColumn get planId => text().nullable()();
```

### 1g. Regenerate code
```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

This regenerates: `plan.freezed.dart`, `plan.g.dart`, `app_database.g.dart`, `plan_repository.g.dart`, `plan_providers.g.dart`, and all other `.g.dart` files.

---

## Step 2 — New `PlanApiService` (network layer for plans)

**New file:** `app/lib/services/plan_api_service.dart`

This service handles all HTTP calls for plans and the library. It is a thin wrapper over `ApiClient`.

```dart
class PlanApiService {
  PlanApiService(ApiClient client) : _client = client;
  final ApiClient _client;

  // User plans
  Future<List<Plan>> fetchUserPlans() async { ... }
  // GET /api/plans/list  →  parse each item into Plan

  Future<Plan> getPlanById(String id) async { ... }
  // GET /api/plans/:id

  Future<String> savePlan(Plan plan) async { ... }
  // POST /api/plans/save  →  returns planId

  Future<void> deletePlan(String id) async { ... }
  // DELETE /api/plans/:id

  Future<void> activatePlan(String planId) async { ... }
  // POST /api/plans/activate  { planId }

  // Library
  Future<List<LibraryPlanSummary>> fetchLibraryPlans({
    String? category,
    String? search,
    int page = 1,
  }) async { ... }
  // GET /api/library/plans?category=&search=&page=

  Future<Plan> getLibraryPlanById(String id) async { ... }
  // GET /api/library/plans/:id  (fetches full plan with planJson)

  // TTS status
  Future<TtsStatusInfo> getTtsStatus(String planId) async { ... }
  // GET /api/tts/status/:planId

  Future<List<AudioFileUrl>> getAudioUrls(String planId) async { ... }
  // GET /api/tts/audio-urls/:planId
}

// Models
class LibraryPlanSummary {
  final String id, name, description, category, defaultVoice, locale;
  final int totalDurationSeconds, stepCount;
  final List<String> tags;
}

class TtsStatusInfo {
  final String planId, status;
  final int total, completed, failed;
  bool get ready => status == 'completed';
}

class AudioFileUrl {
  final String cacheKey, url;
}
```

**Riverpod provider** (keep-alive):
```dart
@Riverpod(keepAlive: true)
PlanApiService planApiService(Ref ref) {
  return PlanApiService(ref.watch(apiClientProvider));
}
```

---

## Step 3 — Rewrite `PlanRepository` to API-backed

**File:** `app/lib/repositories/plan_repository.dart`

### 3a. Update abstract interface

```dart
abstract class PlanRepository {
  Future<String> createPlan(Plan plan);         // id: int → String
  Future<void> updatePlan(String id, Plan plan);
  Future<void> deletePlan(String id);
  Future<Plan?> getPlanById(String id);
  Future<void> activatePlan(String planId);     // NEW
  Future<void> updateLastUsed(String id);
  Stream<List<Plan>> watchUserPlans({String? searchQuery, String? category});
  // watchStarterPlans removed — replaced by fetchLibraryPlans on PlanApiService
}
```

### 3b. New `ApiPlanRepository` implementation

Replaces `DriftPlanRepository`. Uses `PlanApiService` for all server calls and `AppDatabase` only for local caching.

```dart
class ApiPlanRepository implements PlanRepository {
  ApiPlanRepository(this._api, this._db);
  final PlanApiService _api;
  final AppDatabase _db;

  // On startup: fetch from server, write to local cache table
  // watchUserPlans: returns stream from local SQLite cache (stays reactive)
  //   + triggers a background refresh on first listen
  // createPlan: POST /api/plans/save → cache locally
  // deletePlan: DELETE /api/plans/:id → remove from local cache
  // activatePlan: POST /api/plans/activate
}
```

Key design: `watchUserPlans()` still returns a `Stream<List<Plan>>` backed by the local SQLite cache. A background fetch populates the cache on app start and on pull-to-refresh. This keeps the reactive UI pattern intact and works offline.

### 3c. Update `planRepositoryProvider`

```dart
@Riverpod(keepAlive: true)
PlanRepository planRepository(Ref ref) {
  return ApiPlanRepository(
    ref.watch(planApiServiceProvider),
    ref.watch(appDatabaseProvider),
  );
}
```

Remove the `syncService` injection.

---

## Step 4 — Update `plan_providers.dart`

**File:** `app/lib/providers/plan_providers.dart`

### 4a. Change `planById` signature

```dart
// BEFORE
Future<Plan?> planById(Ref ref, int id)

// AFTER
Future<Plan?> planById(Ref ref, String id)
```

### 4b. Add `planByIdProvider` for detail view (needed for the "Activate" button)

```dart
@riverpod
Future<Plan?> planById(Ref ref, String id) {
  final repo = ref.watch(planRepositoryProvider);
  return repo.getPlanById(id);
}
```

### 4c. Add `refreshUserPlansProvider`

A simple `StateProvider<int>` that increments to force a re-fetch:
```dart
final refreshCounterProvider = StateProvider<int>((ref) => 0);
```

`planListProvider` watches `refreshCounterProvider` and calls `planApiService.fetchUserPlans()` when it changes.

---

## Step 5 — New `LibraryPlanProviders`

**File:** `app/lib/providers/library_providers.dart` (rewrite — currently only has `searchQueryProvider` and `selectedCategoryProvider`)

```dart
// Search/filter state (keep these, used by both tabs)
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// Library tab — currently selected tab index (0=My Plans, 1=Discover)
final libraryTabIndexProvider = StateProvider<int>((ref) => 0);

// Global library fetch
@riverpod
Future<List<LibraryPlanSummary>> libraryPlans(
  Ref ref, {
  String? category,
  String? search,
  int page = 1,
}) {
  final api = ref.watch(planApiServiceProvider);
  return api.fetchLibraryPlans(category: category, search: search, page: page);
}
```

---

## Step 6 — Rewrite `PlanLibraryScreen`

**File:** `app/lib/screens/plan_library/plan_library_screen.dart`

### 6a. Replace single list with `TabBar` (two tabs)

```
Tab 0: "My Plans"    → API-backed user plans (from planListProvider)
Tab 1: "Discover"    → Global library (from libraryPlansProvider)
```

### 6b. "My Plans" tab

- Same `ListView` of `PlanCard` widgets as now
- Each card gets new actions:
  - **Play** — existing flow (guard → countdown → startPlan)
  - **Activate** — new button, only shown when `plan.isActive == false`
  - **Edit** / **Delete** — unchanged
- Show TTS status badge on each card (spinner/checkmark/warning based on `plan.ttsStatus`)

### 6c. "Discover" tab  

New widget: `_LibraryTab`

- Fetches from `libraryPlansProvider`
- Shows `LibraryPlanSummary` cards with:
  - Name, description, category chip, duration
  - "Add to My Plans" button → calls `planApiService.getLibraryPlanById(id)` to get full planJson, then `repo.createPlan(plan)`, then navigates to "My Plans" tab
- Search and category filter shared with "My Plans" tab via `searchQueryProvider` / `selectedCategoryProvider`

### 6d. Empty state update

"No plans yet — browse the Discover tab to find plans"

### 6e. FAB visibility

FAB for creating new plan remains on "My Plans" tab only.

### 6f. Key code changes

- Remove `watchUserPlans` / `watchStarterPlans` separation — now just `planListProvider()` for My Plans
- Remove `_duplicatePlan` using `id: 0` — use empty `String` or generate a temp ID
- Update `context.push('/editor/${plan.id}')` — no change needed (already passes as String via route)

---

## Step 7 — Add TTS Status Badge to `PlanCard`

**File:** `app/lib/screens/plan_library/widgets/plan_card.dart`

Add a `ttsStatusBadge` parameter or read `plan.ttsStatus` directly:

```dart
Widget _buildTtsStatusBadge(String status, int completed, int total) {
  return switch (status) {
    'processing' || 'pending' => Row(children: [
        SizedBox(width:12, height:12, child: CircularProgressIndicator(strokeWidth:1.5)),
        SizedBox(width:4),
        Text('$completed/$total', style: labelSmall),
      ]),
    'completed' => Icon(Icons.auto_awesome, size: 14, color: Colors.green),
    'failed' || 'partial' => Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
    _ => SizedBox.shrink(),  // 'none' — not activated yet
  };
}
```

Add an **Activate** action item in the card's popup menu or as a trailing button when `plan.ttsStatus == 'none'`:
```dart
if (!plan.isActive)
  TextButton.icon(
    onPressed: onActivate,
    icon: Icon(Icons.auto_awesome_outlined, size:16),
    label: Text('Activate AI Voice'),
  ),
```

---

## Step 8 — TTS Status Polling Provider

**New file:** `app/lib/providers/tts_status_providers.dart`

```dart
/// Polls GET /api/tts/status/:planId every 5 seconds.
/// Stops when status is 'completed' or 'failed'.
@riverpod
Stream<TtsStatusInfo> planTtsStatus(Ref ref, String planId) async* {
  final api = ref.watch(planApiServiceProvider);
  while (true) {
    final status = await api.getTtsStatus(planId);
    yield status;
    if (status.ready || status.status == 'failed') break;
    await Future.delayed(const Duration(seconds: 5));
  }
}

/// Whether GenAI TTS is ready for a given plan.
/// Reads from the local cache plan.ttsStatus first, falls back to polling.
@riverpod
bool isTtsReady(Ref ref, String planId) {
  // First check local cache
  final plans = ref.watch(planListProvider()).valueOrNull ?? [];
  final plan = plans.firstWhereOrNull((p) => p.id == planId);
  if (plan?.ttsStatus == 'completed') return true;

  // Fall back to live polling
  final statusAsync = ref.watch(planTtsStatusProvider(planId));
  return statusAsync.valueOrNull?.ready ?? false;
}
```

---

## Step 9 — Audio Download Service

**New file:** `app/lib/services/audio_download_service.dart`

```dart
class AudioDownloadService {
  AudioDownloadService(this._api, this._db, this._ttsDir);

  final PlanApiService _api;
  final AppDatabase _db;
  final Directory _ttsDir;

  /// Downloads all pre-generated audio for [planId] from S3.
  /// Populates TtsCacheTable rows. Returns number of files downloaded.
  Future<int> downloadPlanAudio(String planId) async {
    final audioFiles = await _api.getAudioUrls(planId);
    int downloaded = 0;
    await Future.wait(
      audioFiles.map((f) => _downloadOne(planId, f)),
      eagerError: false,
    ).then((results) => downloaded = results.whereType<bool>().where((v) => v).length);
    return downloaded;
  }

  Future<bool> _downloadOne(String planId, AudioFileUrl f) async {
    // 1. Check if already in TtsCacheTable
    final existing = await _db.getTtsCacheEntry(f.cacheKey);
    if (existing != null && await File(existing.filePath).exists()) return false;

    // 2. Download from pre-signed S3 URL
    final response = await http.get(Uri.parse(f.url));
    if (response.statusCode != 200) return false;

    // 3. Write to local tts-cache directory
    final file = File('${_ttsDir.path}/${f.cacheKey}.wav');
    await file.writeAsBytes(response.bodyBytes);

    // 4. Upsert into TtsCacheTable
    await _db.upsertTtsCacheEntry(
      cacheKey: f.cacheKey,
      filePath: file.path,
      planId: planId,
    );
    return true;
  }
}
```

Auto-trigger download when `planTtsStatusProvider` emits `ready == true`:
- Watch `planTtsStatusProvider(planId)` in the plan detail/card
- When `ready`, call `audioDownloadService.downloadPlanAudio(planId)`
- Update local plan cache row's `ttsStatus` to `'completed'`

---

## Step 10 — GenAI / Platform TTS Toggle in `NowPlayingScreen`

**File:** `app/lib/screens/now_playing/now_playing_screen.dart`

### 10a. New provider for playback mode (per-session, not persisted)

```dart
// In tts_status_providers.dart or execution_providers.dart
final ttsPlaybackModeProvider = StateProvider<TtsPlaybackMode>((ref) => TtsPlaybackMode.platform);

enum TtsPlaybackMode { platform, genai }
```

### 10b. Add toggle to `NowPlayingScreen`

Near the top of the screen (or in the AppBar actions):

```dart
Consumer(builder: (context, ref, _) {
  final plan = ref.watch(activePlanProvider);  // current plan being played
  final isReady = plan != null ? ref.watch(isTtsReadyProvider(plan.id)) : false;
  final mode = ref.watch(ttsPlaybackModeProvider);

  return SegmentedButton<TtsPlaybackMode>(
    segments: [
      ButtonSegment(value: TtsPlaybackMode.platform, label: Text('Device'), icon: Icon(Icons.phone_android)),
      ButtonSegment(
        value: TtsPlaybackMode.genai,
        label: Text(isReady ? 'AI Voice' : 'Downloading…'),
        icon: isReady ? Icon(Icons.auto_awesome) : SizedBox(width:14, height:14, child: CircularProgressIndicator(strokeWidth:1.5)),
        enabled: isReady,
      ),
    ],
    selected: {mode},
    onSelectionChanged: (s) => ref.read(ttsPlaybackModeProvider.notifier).state = s.first,
  );
})
```

---

## Step 11 — Simplify `TtsService`

**File:** `app/lib/services/tts_service.dart`

### Remove:
- `preRenderPlan()` method (server handles pre-generation now)
- `_readTtsProvider()` method (provider is server-side config)
- The provider-selection logic in `synthesize()` / `renderTTS()`

### Modify `renderTTS()` flow:

```dart
Future<String?> renderTTS(String text, String voiceId) async {
  // 1. Check local TTS cache (covers both pre-downloaded GenAI and past on-demand)
  final cached = await _checkLocalCache(text, voiceId);
  if (cached != null) return cached;

  // 2. If in GenAI mode and plan has completed TTS — file should be local, but
  //    if missing (evicted), fall back to on-demand via API
  //    The server will return the S3-cached WAV immediately (~100ms cache hit)
  if (_currentPlaybackMode == TtsPlaybackMode.genai) {
    return await _synthesizeViaApi(text, voiceId);
  }

  // 3. Platform TTS mode — use flutter_tts directly
  return null;  // null → caller uses flutter_tts
}
```

### Keep:
- `_collectSaySteps()` (still used for pre-render in platform mode)
- `_checkLocalCache()` logic unchanged
- `_synthesizeViaApi()` unchanged

---

## Step 12 — Remove Sync Infrastructure

### 12a. Delete files
- `app/lib/services/sync_service.dart`
- `app/lib/providers/sync_providers.dart`
- `app/lib/screens/settings/widgets/sync_section.dart`

### 12b. Modify `app/lib/database/app_database.dart`
- Remove `dbFilePath` getter
- Remove `walCheckpoint()` method
- Remove the sync-related SQLite indexes from `beforeOpen`

### 12c. Modify `app/lib/main.dart` (lines 93 and 8)
- Remove `import 'package:instructor/data/starter_plans.dart'`
- Remove `import 'package:instructor/repositories/plan_repository.dart'` (if only used for seed)
- Remove line 93: `await seedStarterPlans(container.read(planRepositoryProvider));`

### 12d. Delete `app/lib/data/starter_plans.dart`

---

## Step 13 — Remove TTS Provider/Locale Selectors from Settings

**File:** `app/lib/screens/settings/settings_screen.dart`

Remove from the `_SettingsCard` children list (lines 54–55):
```dart
// REMOVE:
const _TtsProviderSelector(),
const _LocaleSelector(),
```

Remove the full class definitions:
- `_TtsProviderSelector` (lines ~233–370) — entire class
- `_LocaleSelector` (lines ~370–420) — entire class

Keep:
- `_ThemeModeSelector`
- `_VoiceSelector` (voice choice still relevant)
- `_SpeechRateSlider`
- `_AmbientVolumeSlider`
- `_VoiceVolumeSlider`
- `_NotificationSoundSwitch`
- `_VibrationSwitch`
- `AuthSection`

Remove from imports:
```dart
// REMOVE:
import 'package:instructor/services/voice_remap_service.dart';
```

---

## Step 14 — Remove Dead Code

### Delete files:
- `app/lib/services/voice_remap_service.dart`
- `app/lib/services/provider_catalog_manager.dart`
- `app/lib/database/tables/provider_catalog_table.dart`

### Simplify `tts_providers.dart`:
Remove:
- `ttsProvidersProvider` (no longer fetched — server manages provider)
- `selectedTtsProviderProvider`
- `selectedProviderConfigProvider`
- `availableLocalesProvider`
- `voicesForProviderProvider`
- `rawTtsLocaleSetting`

Keep:
- `availableVoicesProvider` (simplified — reads from `staticVoiceCatalog` only)
- `rawVoiceSetting`

### Remove from `app_database.dart`:
- `ProviderCatalogTable` from `@DriftDatabase(tables: [...])`
- Its import

---

## Step 15 — Data Migration on First Launch After Update

**File:** `app/lib/main.dart`

After db init, add migration step (runs once per device):

```dart
// Step 4 (replacement for seedStarterPlans):
await _migrateLocalPlansToServer(container);
```

```dart
Future<void> _migrateLocalPlansToServer(ProviderContainer container) async {
  final settings = container.read(appSettingsProvider);
  final alreadyMigrated = await settings.read('plans_migrated_v2') == 'true';
  if (alreadyMigrated) return;

  // Try to upload any existing local plans to the server
  final db = container.read(appDatabaseProvider);
  final api = container.read(planApiServiceProvider);
  final auth = container.read(authServiceProvider);

  if (!auth.isAuthenticated) {
    // Can't migrate without auth — do it on next login
    return;
  }

  try {
    final localPlans = await db.select(db.plansTable).get();
    for (final row in localPlans) {
      final plan = _rowToPlan(row);
      await api.savePlan(plan);
    }
    await settings.write('plans_migrated_v2', 'true');
  } catch (_) {
    // Non-fatal — user will see their plans from server on next sync
  }
}
```

---

## Step 16 — Final Code Generation & Verification

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

Verify generated files:
- `plan.freezed.dart` — new `String id`, new `isActive/ttsStatus/ttsTotal/ttsCompleted` fields
- `app_database.g.dart` — `PlansTable` with `TextColumn id`, no `isUserCreated`
- `plan_providers.g.dart` — `planById(Ref, String)` signature
- `router.g.dart` — no `int.tryParse` remnants

---

## Critical Files Summary

| File | Action |
|------|--------|
| `app/lib/models/plan.dart` | `id: int` → `id: String`; add `isActive`, `ttsStatus`, `ttsTotal`, `ttsCompleted`; remove `isUserCreated` |
| `app/lib/database/tables/plans_table.dart` | `id`: IntColumn→TextColumn; add 4 new columns; remove `isUserCreated` |
| `app/lib/database/tables/execution_state_table.dart` | `planId`: IntColumn→TextColumn |
| `app/lib/database/tables/tts_cache_table.dart` | `planId`: IntColumn→TextColumn |
| `app/lib/database/app_database.dart` | Bump schema to v6; migration to drop/recreate plans table; remove `walCheckpoint`, `dbFilePath`; remove `ProviderCatalogTable` |
| `app/lib/router.dart:161–169` | `int.tryParse` → pass raw String planId |
| `app/lib/services/plan_api_service.dart` | **NEW** — all HTTP calls for plans + library + TTS status |
| `app/lib/repositories/plan_repository.dart` | Rewrite: `int` → `String`, new `ApiPlanRepository`, remove sync dependency |
| `app/lib/providers/plan_providers.dart` | `planById` signature `int` → `String` |
| `app/lib/providers/library_providers.dart` | Add `libraryTabIndexProvider`, `libraryPlansProvider` |
| `app/lib/providers/tts_status_providers.dart` | **NEW** — polling provider + `isTtsReadyProvider` + `ttsPlaybackModeProvider` |
| `app/lib/services/audio_download_service.dart` | **NEW** — download pre-signed S3 audio |
| `app/lib/screens/plan_library/plan_library_screen.dart` | Two-tab layout (My Plans / Discover); TTS badge on cards; Activate button |
| `app/lib/screens/plan_library/widgets/plan_card.dart` | Add `ttsStatus` badge; add Activate action |
| `app/lib/screens/now_playing/now_playing_screen.dart` | Add Platform/GenAI TTS `SegmentedButton` toggle |
| `app/lib/screens/settings/settings_screen.dart` | Remove `_TtsProviderSelector` + `_LocaleSelector` |
| `app/lib/screens/settings/widgets/sync_section.dart` | **DELETE** |
| `app/lib/services/tts_service.dart` | Remove `preRenderPlan`, `_readTtsProvider`; simplify `renderTTS` for two-mode dispatch |
| `app/lib/services/sync_service.dart` | **DELETE** |
| `app/lib/services/voice_remap_service.dart` | **DELETE** |
| `app/lib/services/provider_catalog_manager.dart` | **DELETE** |
| `app/lib/providers/sync_providers.dart` | **DELETE** |
| `app/lib/providers/tts_providers.dart` | Remove provider-selection providers; keep voice/rate streams |
| `app/lib/data/starter_plans.dart` | **DELETE** |
| `app/lib/database/tables/provider_catalog_table.dart` | **DELETE** |
| `app/lib/main.dart` | Remove `seedStarterPlans`; add migration; remove sync-related imports |

---

## Verification Checklist

1. `dart run build_runner build` — zero errors
2. `flutter analyze` — zero errors
3. App launches → no crash on cold start
4. **Auth**: login with new email via OTP → tokens stored → library shows
5. **Discover tab**: lists global library plans from server
6. **Add to My Plans**: tap "Add" on a library plan → appears in My Plans tab
7. **Activate**: tap "Activate" on My Plans card → spinner appears → badge turns to checkmark when complete
8. **Platform TTS playback**: play a plan → TTS toggle shows "Device" → voice plays from flutter_tts
9. **GenAI TTS**: once activated, toggle shows "AI Voice" enabled → WAV files downloaded → plays pre-generated audio
10. **Offline**: airplane mode → My Plans loads from local cache → Platform TTS works
11. **Settings**: no provider/locale selector shown
12. **Delete plan**: removes from list, server confirms deletion
