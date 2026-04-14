# Backend-First Architecture with Server-Side TTS Pre-Generation

## Context

The Instructor app currently uses a local-first architecture: plans live in Drift/SQLite on-device, 5 starter plans are seeded at first launch, TTS is synthesized on-demand during playback, and the server is mainly a backup/sync target. This plan migrates to a **server-first model** where:

- All plans originate from a **global library** on the server (no local seeding)
- Plan CRUD happens on the server; the app fetches and caches locally for offline playback
- Users explicitly **activate** a plan to trigger server-side TTS pre-generation
- Two playback modes: **Platform TTS** (always available) and **GenAI TTS** (available only after server finishes caching all audio in S3)
- Any user can sign up with a verified email (no invite-only gate)
- User has no control over TTS provider (server decides via env config)

---

## Phase 1: Server — Open Registration & Schema Changes

### 1.1 Remove invite-only gate
**File:** `server/src/auth/auth.service.ts` (lines 67-74)

Delete the `getUserByEmail` check in `requestOtp()`. The existing upsert logic in `verifyOtp()` (creates user on first successful OTP) already handles new user creation.

### 1.2 New table: `library_plans`
**File:** `server/src/database/schema.ts`

```
library_plans:
  id            uuid PK default random
  name          text NOT NULL
  description   text nullable
  category      text NOT NULL default 'custom'
  tags          text NOT NULL default '[]'          -- JSON array
  default_voice text NOT NULL default 'af_heart'
  plan_json     text NOT NULL                       -- full steps JSON
  locale        text NOT NULL default 'enIN'
  is_published  boolean NOT NULL default false
  sort_order    integer NOT NULL default 0
  created_at    timestamptz NOT NULL default now()
  updated_at    timestamptz NOT NULL default now()
```

Index: `(is_published, sort_order)` WHERE `is_published = true`

### 1.3 Add columns to existing `plans` table
**File:** `server/src/database/schema.ts`

New columns on `plans`:
- `source_library_plan_id: uuid nullable` — FK to `library_plans(id)`, null for AI-generated plans
- `is_active: boolean NOT NULL default false` — user explicitly activates to trigger TTS
- `tts_status: text NOT NULL default 'none'` — enum: `none`, `pending`, `processing`, `completed`, `partial`, `failed`
- `tts_total: integer NOT NULL default 0` — total unique TTS pairs to generate
- `tts_completed: integer NOT NULL default 0` — successfully generated count

### 1.4 New table: `tts_jobs`
**File:** `server/src/database/schema.ts`

```
tts_jobs:
  id            uuid PK default random
  plan_id       uuid NOT NULL references plans(id) ON DELETE CASCADE
  cache_key     varchar(64) NOT NULL                -- SHA-256 hash
  text          text NOT NULL
  voice_id      text NOT NULL
  locale        text NOT NULL
  provider      text NOT NULL
  speech_rate   text NOT NULL default '1.0'
  s3_key        text nullable                       -- set on upload completion
  status        text NOT NULL default 'pending'     -- pending, processing, completed, failed
  error         text nullable
  attempts      integer NOT NULL default 0
  created_at    timestamptz NOT NULL default now()
  completed_at  timestamptz nullable
```

Indexes:
- `(plan_id)` for cascade queries
- `(cache_key)` UNIQUE — deduplicates identical text+voice across plans
- `(status)` WHERE `status IN ('pending', 'processing')` — for worker pickup

### 1.5 Drop `sync_metadata` table
No longer needed since SQLite-file sync is removed.

### 1.6 Run Drizzle migration
```bash
cd server && npx drizzle-kit push
```

---

## Phase 2: Server — Library & Plans API

### 2.1 New module: `server/src/library/`
Files to create:
- `library.module.ts`
- `library.controller.ts`
- `library.service.ts`
- `dto/create-library-plan.dto.ts`

**Endpoints:**

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/library/plans` | Optional | List published plans (paginated, filterable by category/search) |
| `GET` | `/api/library/plans/:id` | Optional | Full plan detail with planJson |
| `POST` | `/api/library/plans` | Admin (x-api-key) | Create/update curated plan |

Response shape for list:
```json
{
  "plans": [{ "id", "name", "description", "category", "tags", "defaultVoice", "locale", "totalDurationSeconds", "stepCount" }],
  "total": 20,
  "page": 1
}
```

### 2.2 Modify `PlansController` — new endpoints
**File:** `server/src/plans/plans.controller.ts`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/api/plans/activate` | JWT | Copy library plan to user's plans, or set `is_active=true` on existing plan. Triggers TTS pre-gen. |
| `GET` | `/api/plans/:id` | JWT | Get full plan with planJson, ttsStatus, ttsProgress |
| `DELETE` | `/api/plans/:id` | JWT | Delete user's plan + cascade tts_jobs |
| `GET` | `/api/plans/list` | JWT | **Modify**: add `planJson`, `ttsStatus`, `ttsCompleted`, `ttsTotal`, `isActive` to response |

`POST /api/plans/activate` body:
```json
{ "planId": "uuid" }  // existing user plan ID to activate
```
OR
```json
{ "libraryPlanId": "uuid" }  // library plan to copy + activate
```

### 2.3 Seed library with starter plans
Port the 5 plans from `app/lib/data/starter_plans.dart` into a seed script or admin API calls to populate `library_plans`.

### 2.4 Remove Sync module
- Delete `server/src/sync/` directory
- Remove `SyncModule` from `server/src/app.module.ts` imports
- Add `LibraryModule` to imports

---

## Phase 3: Server — TTS Pre-Generation Pipeline

### 3.1 Step enumeration service
**New file:** `server/src/tts/tts-enumeration.service.ts`

Port the Flutter `_collectSaySteps` logic (from `app/lib/services/tts_service.dart:891-918`) to TypeScript:
- `SayStep` → emit `{text, voice: step.voiceId ?? defaultVoice}`
- `CountStep` → iterate `from` to `to` (respecting direction), emit each number as text
- `RepeatStep` → recurse into children (only once — same audio regardless of repeat count)
- Other step types → skip

Deduplicate by cache key (SHA-256 of `{locale, provider, speechRate, text, voice}` — must match the existing `cacheKey()` in `tts.service.ts`).

### 3.2 TTS pre-generation service
**New file:** `server/src/tts/tts-pregen.service.ts`

**Coordinator flow** (called from `POST /api/plans/activate`):
1. Parse plan JSON, enumerate all unique TTS pairs via enumeration service
2. For each pair, check S3 with `headObject` for existing `tts/{cacheKey}.wav` (batch, concurrency 20)
3. Filter to uncached pairs only
4. If all already cached → set `tts_status='completed'`, return
5. Create `tts_jobs` rows for uncached pairs (skip existing rows with same `cache_key` that are already `completed`)
6. Update `plans.tts_status='pending'`, `plans.tts_total=N`, `plans.tts_completed=0`
7. **Self-invoke Lambda** with chunked worker tasks (10 pairs per chunk, max 5 concurrent workers)
8. Return immediately (non-blocking)

**Worker flow** (runs in self-invoked Lambda):
1. Receive chunk of `{text, voice, cacheKey, locale, provider, speechRate}` pairs
2. For each pair: call existing `TtsService.synthesize()` (handles Kokoro/Gemini routing + S3 upload)
3. On success: update `tts_jobs` row to `completed`, set `s3_key`
4. On failure (after 2 retries): update to `failed` with error message
5. After each item: update `plans.tts_completed` count via SQL `UPDATE plans SET tts_completed = (SELECT COUNT(*) FROM tts_jobs WHERE plan_id = ? AND status = 'completed')`
6. After chunk complete: check if all jobs done → update `plans.tts_status` to `completed`/`partial`/`failed`

### 3.3 Lambda task types
**File:** `server/src/lambda.ts`

Add new task types alongside existing `SendOtpEmailTask`:

```typescript
export interface TtsPregenWorkerTask {
  task: 'ttsPregenWorker';
  planId: string;
  pairs: Array<{ text: string; voice: string; cacheKey: string }>;
  provider: string;
  locale: string;
  speechRate: string;
}
```

Route in the handler's task switch to instantiate `TtsPregenService` and call `processChunk()`.

**Local dev fallback:** When `AWS_LAMBDA_FUNCTION_NAME` is not set, process chunks directly in-process using `setImmediate()` (same pattern as `SESEmailService.dispatchOtpEmail`).

### 3.4 TTS status endpoint
**File:** `server/src/tts/tts.controller.ts`

`GET /api/tts/status/:planId` (JWT required):
```json
{
  "planId": "uuid",
  "status": "processing",
  "total": 47,
  "completed": 23,
  "failed": 0,
  "ready": false
}
```

### 3.5 Audio URLs endpoint
**File:** `server/src/tts/tts.controller.ts`

`GET /api/tts/audio-urls/:planId` (JWT required):
```json
{
  "planId": "uuid",
  "audioFiles": [
    { "cacheKey": "abc123...", "url": "https://s3...presigned-url" }
  ]
}
```

Returns pre-signed S3 GET URLs (1hr TTL) for all completed `tts_jobs` of the plan.

---

## Phase 4: Flutter App — API-First Plans

### 4.1 Change `Plan.id` type: `int` → `String`
**File:** `app/lib/models/plan.dart`

Change `required int id` to `required String id`. This cascades through:
- All widgets referencing `plan.id` (plan cards, editor, now playing)
- Router path parameters (already string in go_router)
- Repository method signatures
- Execution state table FK (change `planId` from `IntColumn` to `TextColumn`)
- TTS cache table FK

### 4.2 Rewrite `PlanRepository` to API-backed
**File:** `app/lib/repositories/plan_repository.dart`

New `ApiPlanRepository` implementation:
- `fetchAllPlans()` → `GET /api/plans/list` (returns full plan data including planJson)
- `getPlanById(String id)` → `GET /api/plans/:id`
- `savePlan(Plan plan)` → `POST /api/plans/save`
- `deletePlan(String id)` → `DELETE /api/plans/:id`
- `activatePlan(String planId)` → `POST /api/plans/activate`
- `activateLibraryPlan(String libraryPlanId)` → `POST /api/plans/activate`
- `fetchLibraryPlans({category, search, page})` → `GET /api/library/plans`

Use an in-memory cache (`StateNotifier` / `AsyncNotifier`) that holds the fetched plans list. Pull-to-refresh re-fetches from server.

### 4.3 Local plan cache for offline
**File:** `app/lib/database/app_database.dart`

Keep a lightweight `cached_plans` table (or reuse the existing `PlansTable` as a pure cache):
- After fetching from server, write plans to local DB
- On app start with no network, load from local cache
- This is read-only locally — all writes go through the API
- Show "last synced X ago" indicator when offline

### 4.4 Remove local-only plan infrastructure
- **Delete:** `app/lib/data/starter_plans.dart` (replaced by server library)
- **Delete:** `app/lib/services/sync_service.dart` and sync providers
- **Remove** from `main.dart`: `seedStarterPlans()` call
- **Remove** sync-related settings UI

### 4.5 Add library browsing
**File:** `app/lib/screens/plan_library/plan_library_screen.dart`

Restructure with two tabs:
1. **My Plans** — from `GET /api/plans/list` (user's saved/activated plans)
2. **Discover** — from `GET /api/library/plans` (global curated library)

Each library plan card has an "Add to My Plans" button → `POST /api/plans/save` (copies plan). Separate "Activate" button on user's plan cards to trigger TTS generation.

### 4.6 Add `Plan.isActive` and `Plan.ttsStatus` fields
**File:** `app/lib/models/plan.dart`

```dart
@Default(false) bool isActive,
@Default('none') String ttsStatus,  // none, pending, processing, completed, partial, failed
@Default(0) int ttsTotal,
@Default(0) int ttsCompleted,
```

---

## Phase 5: Flutter App — TTS Mode & Pre-Gen Status

### 5.1 TTS status polling provider
**New file:** `app/lib/providers/tts_status_providers.dart`

```dart
@riverpod
Stream<TtsStatusInfo> planTtsStatus(Ref ref, String planId)
```

Polls `GET /api/tts/status/:planId` every 5 seconds while plan detail screen is open. Stops when `status == 'completed'` or `status == 'failed'`.

### 5.2 Two-mode playback toggle
**Modify:** `app/lib/screens/now_playing/now_playing_screen.dart`

Add a toggle/segmented button:
- **Platform TTS** — always enabled, uses `flutter_tts` (device engine)
- **GenAI TTS** — only enabled when `ttsStatus == 'completed'`; greyed out with "Generating AI voices... X%" otherwise

### 5.3 Audio download service
**New file:** `app/lib/services/audio_download_service.dart`

When `ttsStatus == 'completed'`:
1. Call `GET /api/tts/audio-urls/:planId` to get pre-signed S3 URLs
2. Download all WAV files in parallel (max 5 concurrent) to local TTS cache directory
3. Populate `TtsCacheTable` rows with local file paths
4. Mark plan as "GenAI TTS ready" locally

The existing `PlanExecutionEngine` already reads from `TtsCacheTable` — no change to playback logic needed.

### 5.4 Remove TTS provider selection from settings
**File:** `app/lib/screens/settings/settings_screen.dart`

Remove:
- TTS provider selector widget (Kokoro/Gemini/ElevenLabs dropdown)
- Locale selector widget

Keep: voice selector (simplified), speech rate slider, volume controls.

### 5.5 Simplify TTS service
**File:** `app/lib/services/tts_service.dart`

- Remove `preRenderPlan()` — server handles pre-generation
- `renderTTS()` flow: check local cache → if GenAI mode and file downloaded, play it → else fall back to Platform TTS
- Remove provider selection logic
- Remove `_readTtsProvider()` — provider is server-side only

---

## Phase 6: Cleanup & Migration

### 6.1 On-device migration
On first launch after update:
- If user has local plans in SQLite that aren't on the server, upload them via `POST /api/plans/save`
- After successful upload, clear local plans table
- Show a one-time "Your plans have been moved to the cloud" message

### 6.2 Remove dead code
- `app/lib/services/voice_remap_service.dart` — no provider switching
- `app/lib/services/provider_catalog_manager.dart` — simplify or remove
- `server/src/sync/` — entire module
- `server/src/auth/auth.controller.ts` — `POST /auth/invite` becomes optional (keep for admin use)

### 6.3 Regenerate Drift & Freezed code
After model changes, run:
```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

---

## Critical Files Summary

| File | Action |
|------|--------|
| `server/src/database/schema.ts` | Add `library_plans`, `tts_jobs` tables; modify `plans` table |
| `server/src/auth/auth.service.ts:67-74` | Remove invite-only check |
| `server/src/lambda.ts` | Add `TtsPregenWorkerTask` routing |
| `server/src/tts/tts-enumeration.service.ts` | **NEW** — step enumeration |
| `server/src/tts/tts-pregen.service.ts` | **NEW** — pre-generation coordinator + worker |
| `server/src/tts/tts.controller.ts` | Add status + audio-urls endpoints |
| `server/src/library/` | **NEW** — entire library module |
| `server/src/plans/plans.controller.ts` | Add activate, get-by-id, delete endpoints |
| `server/src/sync/` | **DELETE** entire module |
| `app/lib/models/plan.dart` | `id: int` → `id: String`, add ttsStatus fields |
| `app/lib/repositories/plan_repository.dart` | Rewrite to API-backed |
| `app/lib/data/starter_plans.dart` | **DELETE** |
| `app/lib/services/sync_service.dart` | **DELETE** |
| `app/lib/services/tts_service.dart` | Simplify (remove provider logic, preRender) |
| `app/lib/services/audio_download_service.dart` | **NEW** — S3 audio downloader |
| `app/lib/screens/plan_library/plan_library_screen.dart` | Two-tab layout (My Plans / Discover) |
| `app/lib/screens/now_playing/now_playing_screen.dart` | Add Platform/GenAI TTS toggle |
| `app/lib/screens/settings/settings_screen.dart` | Remove provider/locale selectors |

---

## Verification Plan

1. **Auth**: Create a new account with a fresh email → OTP received → login succeeds
2. **Library**: `GET /api/library/plans` returns the 5 seeded plans
3. **Add plan**: Tap "Add" on a library plan → appears in My Plans
4. **Activate**: Tap "Activate" on My Plans card → `tts_status` transitions: `pending` → `processing` → `completed`
5. **TTS status**: Poll status endpoint, verify progress increments
6. **GenAI playback**: After completion, GenAI TTS toggle becomes enabled; play plan → pre-generated audio plays from local cache
7. **Platform TTS**: Toggle to Platform TTS → plan plays with device voice (no server dependency)
8. **Offline**: Enable airplane mode → cached plans load, Platform TTS playback works
9. **Custom plan**: Generate a plan via AI → save → activate → TTS generates
10. **Delete plan**: Delete a plan → tts_jobs cascade deleted, plan removed from list
