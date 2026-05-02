-- Seed minimal Discover content for local dev:
--   • 1 system user (acts as owner of curated content)
--   • 4 voices  (one per provider/locale combo we currently use)
--   • 4 categories (Sleep, Focus, Stress, Movement)
--   • 6 series   (2 inside Sleep, 1-2 in each other category)
--   • 2-3 session plans per series (so /series/:id detail isn't empty)
--   • 4 library_plans (one per category) so plan_library has something too
--
-- Re-runnable: every INSERT uses ON CONFLICT DO UPDATE keyed on a unique
-- column so running this script twice leaves the DB in the same final state.
--
-- Run:
--   psql "$DATABASE_URL" -f server/scripts/seed-discover.sql

BEGIN;

-- ── System user (owns curated content; user_id is NOT NULL on plans) ───────
INSERT INTO users (id, email, name, role)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'system@instructor.local',
  'Instructor System',
  'admin'
)
ON CONFLICT (id) DO UPDATE
SET email = EXCLUDED.email,
    name  = EXCLUDED.name,
    role  = EXCLUDED.role;

-- ── Voices ─────────────────────────────────────────────────────────────────
-- Mirrors the catalogs in server/src/tts/providers/provider-registry.service.ts
-- (GEMINI_VOICES + KOKORO_FALLBACK_VOICES). Keep in sync when voices are
-- added/removed there.
INSERT INTO voices (slug, display_name, locale, provider, is_published)
VALUES
  -- Gemini TTS (en-US)
  ('aoede',      'Aoede',      'en-US', 'gemini', true),
  ('charon',     'Charon',     'en-US', 'gemini', true),
  ('fenrir',     'Fenrir',     'en-US', 'gemini', true),
  ('kore',       'Kore',       'en-US', 'gemini', true),
  ('leda',       'Leda',       'en-US', 'gemini', true),
  ('orus',       'Orus',       'en-US', 'gemini', true),
  ('puck',       'Puck',       'en-US', 'gemini', true),
  ('schedar',    'Schedar',    'en-US', 'gemini', true),
  ('zephyr',     'Zephyr',     'en-US', 'gemini', true),
  -- Kokoro — American English (Female)
  ('af_heart',   'Heart (Female, US)',    'en-US', 'kokoro', true),
  ('af_sky',     'Sky (Female, US)',      'en-US', 'kokoro', true),
  ('af_bella',   'Bella (Female, US)',    'en-US', 'kokoro', true),
  ('af_sarah',   'Sarah (Female, US)',    'en-US', 'kokoro', true),
  ('af_nicole',  'Nicole (Female, US)',   'en-US', 'kokoro', true),
  ('af_nova',    'Nova (Female, US)',     'en-US', 'kokoro', true),
  -- Kokoro — American English (Male)
  ('am_adam',    'Adam (Male, US)',       'en-US', 'kokoro', true),
  ('am_michael', 'Michael (Male, US)',    'en-US', 'kokoro', true),
  ('am_echo',    'Echo (Male, US)',       'en-US', 'kokoro', true),
  ('am_eric',    'Eric (Male, US)',       'en-US', 'kokoro', true),
  ('am_liam',    'Liam (Male, US)',       'en-US', 'kokoro', true),
  ('am_onyx',    'Onyx (Male, US)',       'en-US', 'kokoro', true),
  -- Kokoro — British English (Female)
  ('bf_emma',    'Emma (Female, UK)',     'en-GB', 'kokoro', true),
  ('bf_isabella','Isabella (Female, UK)', 'en-GB', 'kokoro', true),
  ('bf_alice',   'Alice (Female, UK)',    'en-GB', 'kokoro', true),
  ('bf_lily',    'Lily (Female, UK)',     'en-GB', 'kokoro', true),
  -- Kokoro — British English (Male)
  ('bm_george',  'George (Male, UK)',     'en-GB', 'kokoro', true),
  ('bm_lewis',   'Lewis (Male, UK)',      'en-GB', 'kokoro', true),
  ('bm_daniel',  'Daniel (Male, UK)',     'en-GB', 'kokoro', true),
  ('bm_fable',   'Fable (Male, UK)',      'en-GB', 'kokoro', true),
  -- Kokoro — Hindi
  ('hf_alpha',   'Alpha (Female, Hindi)', 'hi-IN', 'kokoro', true),
  ('hf_beta',    'Beta (Female, Hindi)',  'hi-IN', 'kokoro', true),
  ('hm_omega',   'Omega (Male, Hindi)',   'hi-IN', 'kokoro', true),
  ('hm_psi',     'Psi (Male, Hindi)',     'hi-IN', 'kokoro', true)
ON CONFLICT (slug) DO UPDATE
SET display_name = EXCLUDED.display_name,
    locale       = EXCLUDED.locale,
    provider     = EXCLUDED.provider,
    is_published = EXCLUDED.is_published,
    updated_at   = now();

-- Retire the bogus 'kokoro-en' placeholder slug from earlier seed runs.
-- Hide rather than delete to avoid breaking any plan_voices rows that may
-- still reference its UUID.
UPDATE voices SET is_published = false, updated_at = now()
WHERE slug = 'kokoro-en';

-- ── Categories ─────────────────────────────────────────────────────────────
INSERT INTO categories (slug, name, icon, color, sort_order, is_published)
VALUES
  ('sleep',     'Sleep',     'bedtime',          '#5B5FE9', 0, true),
  ('focus',     'Focus',     'center_focus_strong', '#22C55E', 1, true),
  ('stress',    'Stress',    'spa',              '#F59E0B', 2, true),
  ('movement',  'Movement',  'directions_run',   '#EF4444', 3, true)
ON CONFLICT (slug) DO UPDATE
SET name         = EXCLUDED.name,
    icon         = EXCLUDED.icon,
    color        = EXCLUDED.color,
    sort_order   = EXCLUDED.sort_order,
    is_published = EXCLUDED.is_published,
    updated_at   = now();

-- ── Series (categorised by FK to categories.id) ────────────────────────────
-- We can't ON CONFLICT on series.name (no unique index), so we DELETE-then-
-- INSERT inside the same transaction. Safe for seed data; do not use in prod.
DELETE FROM series WHERE name IN (
  'Yoga Nidra Foundations',
  'Sleep Stories',
  'Deep Work Primer',
  'Stress First Aid',
  'Morning Mobility',
  'Evening Wind-Down'
);

INSERT INTO series (name, description, category, category_id, tags, default_voice, locale, is_published, sort_order)
SELECT v.name, v.description, v.category, c.id, v.tags, v.default_voice, v.locale, true, v.sort_order
FROM (VALUES
  ('Yoga Nidra Foundations', 'A 4-session intro to yogic sleep — Sankalpa, body rotation, breath awareness, and visualisation.', 'sleep',    'yoga,nidra,sleep',           'leda',      'en-US', 0),
  ('Sleep Stories',          'Calming long-form narration designed to help you drift off.',                                        'sleep',    'stories,sleep',              'charon',    'en-US', 1),
  ('Deep Work Primer',       '5 short focus rituals before deep-work blocks.',                                                     'focus',    'focus,productivity',         'puck',      'en-US', 0),
  ('Stress First Aid',       'Quick guided resets for acute stress moments.',                                                      'stress',   'stress,anxiety,relief',      'leda',      'en-US', 0),
  ('Morning Mobility',       'Gentle movement and breath sequences to start the day.',                                             'movement', 'movement,morning',           'af_heart', 'en-US', 0),
  ('Evening Wind-Down',      'Slow stretches and breath work to transition into evening.',                                         'movement', 'movement,evening,wind-down', 'am_adam',  'en-US', 1)
) AS v(name, description, category, tags, default_voice, locale, sort_order)
JOIN categories c ON c.slug = v.category;

-- ── Sessions inside each series ────────────────────────────────────────────
-- Sessions are rows in `plans` with series_id set + visibility='public'.
-- Owned by the system user. Wiped-and-reinserted to keep seed idempotent.
DELETE FROM plans
WHERE user_id = '00000000-0000-0000-0000-000000000001'
  AND series_id IS NOT NULL;

INSERT INTO plans (
  user_id, name, plan_json, series_id, position, visibility, is_published, voice_quality
)
SELECT
  '00000000-0000-0000-0000-000000000001'::uuid,
  v.name, v.plan_json, s.id, v.position, 'public', true, 'standard'
FROM (VALUES
  -- Yoga Nidra Foundations (4 sessions)
  ('Yoga Nidra Foundations', 0, 'Session 1: Settle & Sankalpa',
    '{"steps":[{"id":"yn1-1","text":"Lie comfortably on your back.","runtimeType":"say"},{"id":"yn1-2","text":"Set a Sankalpa — a short, positive intention.","runtimeType":"say"},{"id":"yn1-3","text":"Repeat it silently three times.","runtimeType":"say"}]}'),
  ('Yoga Nidra Foundations', 1, 'Session 2: Body Rotation',
    '{"steps":[{"id":"yn2-1","text":"Bring awareness to the right thumb.","runtimeType":"say"},{"id":"yn2-2","text":"Move attention through each finger, the palm, the forearm.","runtimeType":"say"},{"id":"yn2-3","text":"Continue up to the shoulder, then switch sides.","runtimeType":"say"}]}'),
  ('Yoga Nidra Foundations', 2, 'Session 3: Breath Awareness',
    '{"steps":[{"id":"yn3-1","text":"Notice the natural breath without changing it.","runtimeType":"say"},{"id":"yn3-2","text":"Count down from 27 with each exhale.","runtimeType":"say"},{"id":"yn3-3","text":"If you lose count, simply start again.","runtimeType":"say"}]}'),
  ('Yoga Nidra Foundations', 3, 'Session 4: Visualisation',
    '{"steps":[{"id":"yn4-1","text":"Picture a calm, golden light at the heart centre.","runtimeType":"say"},{"id":"yn4-2","text":"Let it expand to fill the whole body.","runtimeType":"say"},{"id":"yn4-3","text":"Rest in that warmth for a few breaths.","runtimeType":"say"}]}'),

  -- Sleep Stories (2 sessions)
  ('Sleep Stories', 0, 'A Walk Through the Pine Forest',
    '{"steps":[{"id":"ss1-1","text":"You arrive at the edge of a quiet pine forest.","runtimeType":"say"},{"id":"ss1-2","text":"The path is soft with fallen needles.","runtimeType":"say"},{"id":"ss1-3","text":"With each step you feel a little more at ease.","runtimeType":"say"}]}'),
  ('Sleep Stories', 1, 'The Cabin by the Lake',
    '{"steps":[{"id":"ss2-1","text":"A small wooden cabin sits at the edge of a still lake.","runtimeType":"say"},{"id":"ss2-2","text":"You step inside and a fire is already burning low.","runtimeType":"say"},{"id":"ss2-3","text":"Outside, the water reflects the stars.","runtimeType":"say"}]}'),

  -- Deep Work Primer (3 sessions)
  ('Deep Work Primer', 0, 'Pre-Block Reset',
    '{"steps":[{"id":"dw1-1","text":"Close any tab not relevant to the next 90 minutes.","runtimeType":"say"},{"id":"dw1-2","text":"Take three slow breaths through the nose.","runtimeType":"say"},{"id":"dw1-3","text":"Name the single outcome for this block.","runtimeType":"say"}]}'),
  ('Deep Work Primer', 1, 'Mid-Block Refocus',
    '{"steps":[{"id":"dw2-1","text":"Notice where attention has drifted.","runtimeType":"say"},{"id":"dw2-2","text":"Return to the named outcome.","runtimeType":"say"}]}'),
  ('Deep Work Primer', 2, 'End-of-Block Review',
    '{"steps":[{"id":"dw3-1","text":"Note one thing you finished.","runtimeType":"say"},{"id":"dw3-2","text":"Note one obstacle for next block.","runtimeType":"say"}]}'),

  -- Stress First Aid (2 sessions)
  ('Stress First Aid', 0, '60-Second Reset',
    '{"steps":[{"id":"sf1-1","text":"Place a hand on your chest.","runtimeType":"say"},{"id":"sf1-2","text":"Inhale four counts, exhale six counts.","runtimeType":"say"},{"id":"sf1-3","text":"Repeat three times.","runtimeType":"say"}]}'),
  ('Stress First Aid', 1, 'Grounding 5-4-3-2-1',
    '{"steps":[{"id":"sf2-1","text":"Name five things you can see.","runtimeType":"say"},{"id":"sf2-2","text":"Four you can touch, three you can hear.","runtimeType":"say"},{"id":"sf2-3","text":"Two you can smell, one you can taste.","runtimeType":"say"}]}'),

  -- Morning Mobility (2 sessions)
  ('Morning Mobility', 0, 'Wake-Up Flow',
    '{"steps":[{"id":"mm1-1","text":"Stand tall and reach both arms overhead.","runtimeType":"say"},{"id":"mm1-2","text":"Roll the shoulders backward five times.","runtimeType":"say"},{"id":"mm1-3","text":"Gentle forward fold, let the head hang.","runtimeType":"say"}]}'),
  ('Morning Mobility', 1, 'Spine Openers',
    '{"steps":[{"id":"mm2-1","text":"Cat-cow on hands and knees, five rounds.","runtimeType":"say"},{"id":"mm2-2","text":"Thread the needle on each side.","runtimeType":"say"},{"id":"mm2-3","text":"Childs pose for five breaths.","runtimeType":"say"}]}'),

  -- Evening Wind-Down (2 sessions)
  ('Evening Wind-Down', 0, 'Hip Release',
    '{"steps":[{"id":"ew1-1","text":"Lie on your back, knees bent.","runtimeType":"say"},{"id":"ew1-2","text":"Cross right ankle over left knee, hold for five breaths.","runtimeType":"say"},{"id":"ew1-3","text":"Switch sides.","runtimeType":"say"}]}'),
  ('Evening Wind-Down', 1, 'Lying Twist',
    '{"steps":[{"id":"ew2-1","text":"Knees to chest, then drop them to one side.","runtimeType":"say"},{"id":"ew2-2","text":"Open the opposite arm, gaze that way.","runtimeType":"say"},{"id":"ew2-3","text":"Five breaths each side.","runtimeType":"say"}]}')
) AS v(series_name, position, name, plan_json)
JOIN series s ON s.name = v.series_name;

-- ── Library plans (one published plan per category) ────────────────────────
DELETE FROM library_plans WHERE name IN (
  '10-Minute Body Scan',
  '5-Minute Focus Reset',
  'Box Breathing',
  '3-Minute Morning Stretch'
);

INSERT INTO library_plans (name, description, category, tags, default_voice, plan_json, locale, is_published, sort_order)
VALUES
  ('10-Minute Body Scan',
   'A guided body scan to release tension before sleep.',
   'sleep', 'sleep,body-scan', 'leda',
   '{"steps":[{"id":"s1","text":"Close your eyes and take three slow breaths.","runtimeType":"say"},{"id":"s2","text":"Bring your attention to the crown of your head.","runtimeType":"say"},{"id":"s3","text":"Slowly move your awareness down through your body.","runtimeType":"say"}]}',
   'en-US', true, 0),

  ('5-Minute Focus Reset',
   'Reset your attention between work blocks.',
   'focus', 'focus,reset', 'puck',
   '{"steps":[{"id":"s1","text":"Sit upright and close your eyes.","runtimeType":"say"},{"id":"s2","text":"Take five long breaths through the nose.","runtimeType":"say"},{"id":"s3","text":"Open your eyes and choose one task.","runtimeType":"say"}]}',
   'en-US', true, 0),

  ('Box Breathing',
   '4-4-4-4 breathing pattern to calm the nervous system.',
   'stress', 'stress,breathing', 'leda',
   '{"steps":[{"id":"s1","text":"Inhale for four counts.","runtimeType":"say"},{"id":"s2","text":"Hold for four counts.","runtimeType":"say"},{"id":"s3","text":"Exhale for four counts.","runtimeType":"say"},{"id":"s4","text":"Hold for four counts.","runtimeType":"say"}]}',
   'en-US', true, 0),

  ('3-Minute Morning Stretch',
   'A short mobility flow to wake the body.',
   'movement', 'movement,morning', 'af_heart',
   '{"steps":[{"id":"s1","text":"Reach both arms overhead and stretch tall.","runtimeType":"say"},{"id":"s2","text":"Roll your shoulders backward five times.","runtimeType":"say"},{"id":"s3","text":"Gentle forward fold, let your head hang.","runtimeType":"say"}]}',
   'en-US', true, 0);

COMMIT;

-- Sanity check after running:
--   SELECT slug, name FROM categories ORDER BY sort_order;
--   SELECT s.name, c.slug FROM series s JOIN categories c ON c.id = s.category_id ORDER BY c.sort_order, s.sort_order;
--   SELECT name, category FROM library_plans ORDER BY category, sort_order;
