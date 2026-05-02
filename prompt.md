# GOAL
Implement an admin-curated, TTS-gated content hierarchy across backend, admin web,
and mobile. Users only see plans whose voice generation has succeeded; admins fully
control taxonomy, publishing, and voice generation. Users can also request new plans
or author private plans and request TTS.

# REPO LAYOUT (already exists — extend, don't recreate)
- Backend:    server/        NestJS + Drizzle (Postgres) + AWS
              modules: admin, admin-analytics, plans, series, tts, library, sync,
                       plan_requests (already in place from migration 0013)
- Admin web:  web/app/admin/(dashboard)/
              Next.js App Router; existing routes: plans, library, tts, users,
              engagement, app-version, deletion-requests, admins, overview
- Mobile:     app/                Flutter + Riverpod + freezed + go_router
              existing screens: plan_library, plan_editor, plan_generation,
                                plan_request, series, onboarding, settings
- Infra:      infra/              AWS CDK
- Existing:   migrations 0012 (series + series_subscriptions) and
              0013 (plan_requests) are already shipped; series.category is
              currently a free-text column; plans.tts_status enum is the
              current TTS gate.

# DECISIONS (resolved — do not re-litigate)
1. Sub-plan tree: self-FK `plans.parent_plan_id` + `plans.position`, depth
   capped at 3, enforced in service layer.
2. Multi-voice: introduce `plan_voices` table now. One plan can have N
   (voice, locale) renditions; user-visibility requires at least one row
   with status='ready'.
3. User-authored plans live in the same `plans` table with
   `visibility ∈ ('private','pending_review','public')` + `owner_user_id`.
   Private plans are not shareable peer-to-peer (sharing layer is out of scope).
4. tts_status column on plans is deprecated; backfill into plan_voices and
   drop after rollout.

# DATA MODEL CHANGES (Drizzle + migration)
- NEW  categories(id, slug UNIQUE, name, icon, color, sort_order, is_published,
                  created_at, updated_at)
- NEW  voices(id, slug UNIQUE, display_name, locale, provider, sample_url,
              is_published, created_at, updated_at)
- NEW  plan_voices(id, plan_id FK, voice_id FK, locale, status enum,
                   audio_url, duration_ms, error_msg, generated_at,
                   UNIQUE(plan_id, voice_id, locale))
       status: 'pending' | 'processing' | 'ready' | 'failed'
- ALTER series  ADD category_id FK; backfill from existing text column;
                drop old text column after backfill.
- ALTER plans   ADD parent_plan_id FK self, position int NOT NULL DEFAULT 0,
                visibility text DEFAULT 'public',
                owner_user_id FK users (nullable),
                is_published bool DEFAULT false.
- VIEW v_published_plans:
    SELECT p.* FROM plans p
    WHERE p.is_published AND p.visibility = 'public'
      AND EXISTS (SELECT 1 FROM plan_voices pv
                  WHERE pv.plan_id = p.id AND pv.status = 'ready');
- BACKFILL: insert one plan_voices row per existing plan using its
  current default voice + tts_status mapping.
- Keep plans.tts_status for one release behind a feature flag, then drop.

# WORKSTREAMS (parallelizable; spawn one sub-agent per stream)

## Stream A — Database & Schema
- Write migration 0014_add_categories_voices_plan_voices.sql
- Update server/src/database/schema.ts with new tables/columns + types
- Add v_published_plans view
- Add repositories: categories.repository.ts, voices.repository.ts,
  plan-voices.repository.ts; extend plan.repository.ts with tree queries
  (recursive CTE bounded at depth 3)
- Tests: repo tests for tree queries, visibility view, voice status filter

## Stream B — Backend modules (NestJS)
- NEW server/src/categories/   (controller, service, dto)
    Public: GET /categories
    Admin:  POST/PATCH/DELETE /admin/categories,
            PATCH /admin/categories/reorder
- EXTEND server/src/series/
    PATCH /admin/series/:id/publish
    PATCH /admin/series/:id/reorder-plans
    Replace category text → category_id throughout
- EXTEND server/src/plans/
    GET /plans/:id/tree
    POST /plans                        (user-authored, visibility=private)
    POST /plans/:id/request-publish    (private → pending_review)
    PATCH /admin/plans/:id             (parent, position, visibility, is_published)
    All public list/get queries route through v_published_plans view
- NEW server/src/plan-voices/
    POST /admin/plans/:id/voices/:voiceId/regenerate
    GET /admin/plan-voices?status=failed
- EXTEND server/src/tts/
    Update tts-batch-pregen.service.ts to read from / write to plan_voices
    rows instead of plans.tts_status
- EXTEND server/src/plan_requests (existing controller)
    POST /admin/plan-requests/:id/promote
        → creates plan + N plan_voices rows + queues TTS
- Tests for each controller + service; e2e for the promote flow

## Stream C — Admin web (Next.js)
Under web/app/admin/(dashboard)/:
- NEW /categories                     CRUD + dnd-kit reorder
- NEW /series                          List by category, publish toggle,
                                       drag-reorder plans inside each series
- EXTEND /plans/[id]                   Plan editor: sub-plan tree drag/drop,
                                       voice grid (per voice: status pill +
                                       Regenerate), publish toggle, visibility
- EXTEND /plan-requests                "Promote to Plan" action → prefilled form
- EXTEND /tts                          Per-plan-voice job table, retry queue
- Use existing API patterns under web/app/api/admin/*; add tts-health-proxy-style
  proxies where needed for new admin endpoints
- Tests with the existing __tests__ pattern

## Stream D — Mobile (Flutter)
Models (app/lib/models/, freezed + json_serializable + build_runner):
  - Category (NEW), Voice (NEW), PlanVoice (NEW)
  - extend Plan: parentPlanId, position, children, voices, visibility
  - extend Series: categoryId
Providers (app/lib/providers/):
  - categoriesProvider, seriesByCategoryProvider(slug),
    planTreeProvider(planId), selectedVoiceProvider(planId, userPref)
Routes (app/lib/router.dart, regenerate router.g.dart):
  /discover, /discover/:categorySlug, /series/:id, /plans/:id,
  /plans/:id/play/:voiceId, /library, /create-plan
Screens:
  - app/lib/screens/discover/                         (NEW, categories grid)
  - app/lib/screens/discover/category_screen.dart     (NEW)
  - extend app/lib/screens/series/                    (use category_id)
  - app/lib/screens/plan_detail/                      (sub-plan tree + voice picker)
  - app/lib/screens/create_plan/                      (NEW, user-authored)
Player:
  - On TTS request failure / no ready voice, fall back to platform TTS
    (per existing project memory).
Sync:
  - Extend existing /sync endpoint deltas to include categories, voices,
    plan_voices.
  - Local cache mirrors only published+ready content.
Run build_runner after model changes; do not hand-edit *.g.dart / *.freezed.dart.

## Stream E — Rollout / feature flag
- Add a backend feature flag `use_plan_voices_gate` (default off).
- Phase 1: dual-read — old endpoints still use plans.tts_status, new
  endpoints use v_published_plans.
- Phase 2: flip flag, monitor for one release.
- Phase 3: drop plans.tts_status column in migration 0015.
- Mobile: gate the new Discover navigation behind remote config so old
  plan_library stays alive during cutover.

# ACCEPTANCE CRITERIA
- DB: migration applies cleanly forward and rolls back; v_published_plans
  returns zero rows for plans without any ready plan_voices.
- Backend: all new endpoints have tests; tts worker updates plan_voices and
  not plans.tts_status; promote-from-request creates plan + voices in one tx.
- Admin web: an admin can create category → series → plan → sub-plan, queue
  TTS, see status flip to ready, and toggle publish — all without DB access.
- Mobile: user sees only published plans with at least one ready voice; user
  can request a plan and author a private plan and request TTS for it; on
  TTS failure during playback, platform TTS fallback engages.
- No mobile screen still uses plans.tts_status after Stream E phase 2.

# CONSTRAINTS
- Keep changes incremental; each migration must be individually deployable.
- No new files outside the directories listed above.
- Follow existing repo conventions (NestJS module structure, Drizzle repo
  pattern, freezed models, Riverpod providers, dnd-kit on admin).
- Use the .knowledge/ MCP tools (get_project_overview, get_module_context,
  get_implementation_context) before reading or modifying any file —
  per CLAUDE.md.
- Do NOT skip pre-commit hooks. Do NOT amend existing commits. Each stream
  ships as its own PR against `dev`.

# DELIVERABLES
- One PR per workstream (A–E), each green on CI, each independently
  deployable behind the feature flag.
- A short README under server/src/plan-voices/ describing the visibility
  rule and the v_published_plans contract.
