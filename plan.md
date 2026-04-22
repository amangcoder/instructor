# Admin Dashboard with Analytics — Execution Plan

## Context

The `instructor` product is past the stateless-marketing stage: `server/` has real users, study plans, TTS jobs, streak/session data, and a library of curated plans, but there is **no internal visibility** into any of it. Today the only way to answer "how many plans got created this week" or "what's our TTS error rate" is to SSH to logs. An admin dashboard is needed to:

1. Give the team day-to-day visibility into growth, engagement, and reliability.
2. Surface the plan creation funnel — the app's primary user journey — so regressions are caught fast.
3. Provide a single, role-gated surface for operational actions (future: deletion requests, user lookup, plan moderation).

Decisions locked via clarifying questions: **JWT + role field** for admin auth, **dashboard under existing `web/app/admin/`**, **MVP using only existing DB columns** (no TTS schema additions in Phase 1).

---

## Approach

### Server side (auth + analytics endpoints)

1. **Schema change** — add `role` column to `users` in [server/src/database/schema.ts](server/src/database/schema.ts)
   - `role: text('role').notNull().default('user')` — values: `'user' | 'admin'`
   - New drizzle migration in [server/drizzle/](server/drizzle/)
   - Seed script or manual SQL to promote initial admin(s) by email

2. **JWT payload + guard** — extend `JwtPayload` and add `AdminRoleGuard`
   - [server/src/auth/jwt.service.ts] — include `role` in signed payload on login/refresh (currently issues `{ sub, email }` only; ref: jwt-auth.guard.ts:20-36)
   - [server/src/auth/jwt-auth.guard.ts] — keep unchanged; continues to inject `req.user`
   - **New file** `server/src/auth/admin-role.guard.ts` — canActivate checks `req.user.role === 'admin'`, returns 403 otherwise
   - Reuse — **do not create a new decorator**; chain `@UseGuards(JwtAuthGuard, AdminRoleGuard)` in the controller

3. **Analytics module** — new `server/src/admin-analytics/` module
   - `admin-analytics.controller.ts` — routes under `/api/admin/analytics/*`, all gated by `JwtAuthGuard + AdminRoleGuard`
   - `admin-analytics.service.ts` — pure drizzle aggregation; no caching in Phase 1
   - Register in [server/src/app.module.ts](server/src/app.module.ts)

### Endpoints (MVP — all read-only, all drizzle aggregations over existing tables)

| Endpoint | Query source | Returns |
|---|---|---|
| `GET /api/admin/analytics/overview` | users, plans, tts_jobs, session_completions | top-line counts + 7d deltas |
| `GET /api/admin/analytics/users/signups?range=30d` | users.createdAt | daily signup series |
| `GET /api/admin/analytics/users/activation?range=30d` | join users ← plans on userId | % of new users who created a plan within 24h |
| `GET /api/admin/analytics/plans/funnel?range=30d` | plans (generated vs saved vs activated) + tts_jobs.status | counts at each stage, drop-off % |
| `GET /api/admin/analytics/plans/usage?range=30d` | session_completions + plans | plans-per-user distribution, active vs dormant |
| `GET /api/admin/analytics/tts/volume?range=30d` | tts_jobs grouped by day + provider + voiceId | requests/day, voice/provider mix |
| `GET /api/admin/analytics/tts/errors?range=30d` | tts_jobs where status='failed' | error rate, top error messages |
| `GET /api/admin/analytics/engagement/streaks` | session_completions + streak_freezes | active streak distribution |
| `GET /api/admin/analytics/library` | library_plans + plans.sourceLibraryPlanId | which library plans convert to user plans |

All endpoints take `range` query param (`7d|30d|90d`), default `30d`. Response shape: `{ series: [{date, value}], totals: {...} }` — frontend-agnostic.

### Web side (Next.js admin surface)

1. **Dependencies** — add to [web/package.json](web/package.json):
   - `recharts` (charts — lightweight, works with Tailwind)
   - `date-fns` (range math)
   - Optionally `@tanstack/react-query` for fetching/caching; otherwise plain fetch + `use` with Next 15 cache. **Default to plain fetch** for Phase 1 to match current style.

2. **Route group** `web/app/admin/`
   - `layout.tsx` — server component; reads session, calls `/auth/me` (or decodes JWT), redirects non-admins to `/`. Shared nav shell (sidebar with: Overview, Users, Plans, TTS, Library, Engagement).
   - `page.tsx` — redirect to `/admin/overview`.
   - `overview/page.tsx` — top cards (DAU, new signups, synths today, p95-or-placeholder, plans activated) + recent activity.
   - `users/page.tsx` — signup trend chart, activation rate chart.
   - `plans/page.tsx` — funnel chart (the headline one), usage distribution, dormancy.
   - `tts/page.tsx` — volume by day, voice/provider mix, error rate.
   - `engagement/page.tsx` — streaks, session completions.
   - `library/page.tsx` — library-plan conversion table.
   - `login/page.tsx` — simple email+OTP form that calls existing auth endpoints and stores the token (see below).

3. **Auth flow on web**
   - Web has **no current login UI** (confirmed by exploration). Reuse server's existing OTP flow (`/auth/otp/request`, `/auth/otp/verify`, `/auth/refresh`).
   - Store access token in httpOnly cookie set by a new `web/app/api/auth/session/route.ts` handler that proxies to server; refresh token also cookie-bound.
   - `layout.tsx` reads the cookie, validates via `/auth/me` (exists per auth module), pulls `role`, gates render.

4. **API client** — new `web/src/lib/admin-api.ts`
   - Thin wrapper around fetch: `adminFetch(path, range?)` that attaches auth cookie, handles 401 → redirect to `/admin/login`, 403 → `/`.

5. **Chart primitives** — `web/src/components/admin/`
   - `StatCard.tsx`, `TimeSeriesChart.tsx` (recharts LineChart), `FunnelChart.tsx` (recharts BarChart horizontal), `RangePicker.tsx`.
   - Styled with existing Tailwind setup ([web/app/layout.tsx](web/app/layout.tsx)).

### Critical files to modify

- [server/src/database/schema.ts](server/src/database/schema.ts) — add `role` column
- [server/src/auth/jwt.service.ts](server/src/auth/jwt.service.ts) — include `role` in token
- [server/src/auth/admin-role.guard.ts](server/src/auth/admin-role.guard.ts) — **new**
- [server/src/admin-analytics/](server/src/admin-analytics/) — **new** (module, controller, service)
- [server/src/app.module.ts](server/src/app.module.ts) — wire new module
- [server/drizzle/](server/drizzle/) — **new** migration
- [web/package.json](web/package.json) — `recharts`, `date-fns`
- [web/app/admin/](web/app/admin/) — **new** route group + pages
- [web/src/lib/admin-api.ts](web/src/lib/admin-api.ts) — **new**
- [web/src/components/admin/](web/src/components/admin/) — **new** chart primitives

### Things explicitly out of scope for Phase 1

- TTS cache-hit %, synth latency percentiles, audio-bytes (requires `tts_jobs` schema additions — call it Phase 2)
- Rate-limit analytics (Upstash counters are ephemeral; needs new table — Phase 2)
- Kokoro GPU/Modal cost attribution (needs instrumentation in [kokoro-server/main.py](kokoro-server/main.py) — Phase 2)
- MRR/subscription metrics (no billing tables exist — Phase 3, if/when plans monetize)
- Admin mutations (user edit, plan moderation) — read-only dashboard for v1

---

## Verification

**Server**
1. `cd server && pnpm drizzle-kit generate` → confirm migration diff adds only `role` column.
2. `pnpm run start:dev`; promote a user via SQL (`UPDATE users SET role='admin' WHERE email='aman26121999@gmail.com'`).
3. Log in via OTP, decode JWT (jwt.io), confirm `role: 'admin'` claim.
4. `curl -H "Authorization: Bearer <non-admin-token>" localhost:3071/api/admin/analytics/overview` → expect 403.
5. Same curl with admin token → expect 200 with sane numbers; cross-check one number against a direct SQL count.
6. Run existing `pnpm test` in `server/` — confirm no regressions in auth suite.

**Web**
7. `cd web && pnpm dev` (port 3072 per memory).
8. Hit `localhost:3072/admin` unauthenticated → redirects to `/admin/login`.
9. Log in as admin → `/admin/overview` renders; StatCards show non-zero values; charts render without runtime errors.
10. Log in as non-admin → `/admin` redirects to `/` (no leak of admin layout).
11. Change range picker `7d → 90d` → all charts refetch; network tab shows correct query param.
12. Walk each page (users, plans, tts, engagement, library) — confirm no empty states masking real errors (403s, 500s should surface, not silently show 0).

**End-to-end sanity**
13. Create a new user + plan via the Flutter app, wait a minute, refresh `/admin/plans` → the new plan appears in the funnel.
14. Trigger a TTS failure (set a bogus voiceId) → appears in `/admin/tts` error breakdown.
