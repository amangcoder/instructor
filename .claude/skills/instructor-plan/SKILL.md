---
name: instructor-plan
description: Generate a runtime-valid Instructor Plan JSON from a description. Use when the user describes a guided plan (yoga, meditation, workout, cooking, study/focus, routine) and asks for "plan JSON", "a plan", "generate the plan", "instructor plan", or to seed/save a plan in this app. Outputs a single JSON object in the runtime/storage format (Freezed-serialized PlanStep tree) that is ready to paste into `planJson` on POST /api/plans/save.
---

# Instructor Plan (JSON)

Instructor runs guided, narrated plans (yoga, meditation, workouts, cooking, focus blocks, routines) with TTS speech, timed waits, audio cues, and notifications. The runtime consumes a flat, typed step list serialized from a Flutter Freezed sealed class.

This skill turns a plan description into a paste-ready, runtime-valid JSON object **in the storage format** that gets saved as `planJson` and consumed by the Flutter app.

## Two formats — do not confuse them

There are two plan formats in this codebase. **Always emit the runtime format below.**

| | LLM intermediate format | **Runtime / storage format (use this)** |
|---|---|---|
| Discriminator | `type` | `runtimeType` |
| Per-step `id` | not required | **required** (unique string) |
| Wait duration | `durationSeconds: 30` (number, seconds) | `duration: 30000000` (number, **microseconds**) |
| Say voice | `voice` (string) | `voiceId` (string\|null) |
| Say est. duration | n/a | `estimatedDuration` (microseconds\|null) |
| Notify body | `message` | `title` + `body` |
| Play asset | `assetKey` | `audioAssetKey` |
| Repeat children | `steps` | `children` |
| Validator | `server/src/plans/validators/plan.validator.ts` | `app/lib/models/plan_step.dart` (sealed class), `web/src/types/plan-detail.ts` (TS mirror), `server/scripts/seed-library-plans.ts` (canonical reference example) |

The LLM intermediate format is only used inside `POST /api/plans/generate` before being transformed. **For `POST /api/plans/save` and direct DB seeding, use the runtime format.**

## How to run this skill

1. **Get the seed description.** If the user gave one in the invocation, use it. Otherwise ask one short question: *"What's the plan? Describe the goal, total duration, and any constraints (injury, mood, language)."*
2. **Pick the category and voice.** See category and voice guides below. Default `defaultVoice` is `af_heart` unless the brief signals a different mood.
3. **Plan the duration budget.** Add up the wait durations (in seconds) in your head. Total should match the user's requested duration ±10%.
4. **Emit the steps array** using only the seven valid step types: `say`, `wait`, `notify`, `play`, `repeat`, `stopAudio`, `count`. Every step is an object with `runtimeType` and `id`. **Assume the user knows nothing.** The first time you introduce *any* named thing — pose, position, posture, stance, grip, transition, movement, exercise, breath pattern, technique, skill, equipment use, cooking action, study method, or protocol — write a verbose, detailed teaching `say` (starting position, step-by-step entry, where to feel/notice it, breath, common mistakes). Every later mention of the same thing in the same plan is a short cue. See Composition rules for details.
5. **Convert seconds to microseconds** for `duration` and `estimatedDuration`. Multiply by `1_000_000`. (e.g., 30 seconds = `30000000`.)
6. **Validate.** Mentally walk the JSON against the rules below. Common mistakes: forgetting `id`, using `type` instead of `runtimeType`, using seconds instead of microseconds, using `voice` instead of `voiceId`, using `message` on `notify`, using `steps` on `repeat`.
7. **Output exactly one fenced ```json block** containing the plan object. Above the block, one short line summarizing structure. Below it, ask whether to save it via the API or write it to a file (do not save/write without confirmation).
8. **Do not call the API and do not write a file unprompted.** Wait for the user to say "save it" / "post it" / "write it to X".

## JSON schema (runtime / storage format — authoritative)

Source of truth: [app/lib/models/plan_step.dart](app/lib/models/plan_step.dart) (Flutter sealed class), mirrored in [web/src/types/plan-detail.ts](web/src/types/plan-detail.ts). Canonical worked example: [server/scripts/seed-library-plans.ts](server/scripts/seed-library-plans.ts).

```json
{
  "name": "string — non-empty, plan title",
  "description": "string — 1–2 sentence summary",
  "category": "string — see category guide",
  "tags": ["array", "of", "string", "tags"],
  "defaultVoice": "string — voice id, see voice guide",
  "steps": [
    { "runtimeType": "say",       "id": "s1",  "text": "string", "voiceId": null, "estimatedDuration": null },
    { "runtimeType": "wait",      "id": "w1",  "duration": 30000000 },
    { "runtimeType": "notify",    "id": "n1",  "title": "string", "body": "string" },
    { "runtimeType": "play",      "id": "p1",  "audioAssetKey": "forest", "loop": true, "volume": 1.0, "fadeInMs": 0, "fadeOutMs": 0 },
    { "runtimeType": "stopAudio", "id": "sa1" },
    { "runtimeType": "count",     "id": "c1",  "from": 1, "to": 10, "intervalSeconds": 1 },
    { "runtimeType": "repeat",    "id": "r1",  "count": 3, "children": [ /* nested step objects */ ] }
  ]
}
```

### Top-level fields

- **`name`** — Non-empty string, ≤ 200 chars. Title case ("Morning Yoga Flow").
- **`description`** — String, may be empty. 1–2 sentences.
- **`category`** — Free string (no enum constraint in the DB). Common values seen in seeds: `yoga`, `workout`, `meditation`, `routine`, `focus`. The LLM-intermediate validator collapses to `fitness | meditation | study | routine | custom` — for `planJson` use whichever describes the plan best (descriptive strings are fine).
- **`tags`** — Array of short string tags (e.g., `["yoga", "morning", "beginner"]`). Optional but recommended.
- **`defaultVoice`** — Non-empty string. Use a known voice id (see voice guide).

### Step rules

Every step object **must** include `runtimeType` (discriminator) and `id` (unique non-empty string). Suggested id convention: short prefix + ordinal (`s1`, `w1`, `r1_s1`). IDs scope globally within the plan; keep them unique across all nested levels.

- **`say`** — `text` required, non-empty. `voiceId` is `string | null` (use `null` to inherit `defaultVoice`). `estimatedDuration` is `number | null` (microseconds; the runtime fills this in after TTS synthesis — emit `null` unless you have an authoritative value).
- **`wait`** — `duration` required, **microseconds**, positive integer. Convert seconds → microseconds by multiplying by `1_000_000`.
- **`notify`** — `title` and `body` both required, non-empty.
- **`play`** — `audioAssetKey` required, must be one of the valid asset keys (see asset guide). `loop` (bool, default `true`), `volume` (number 0.0–1.0, default `1.0`), `fadeInMs` and `fadeOutMs` (integer ms, optional, default `0`).
- **`stopAudio`** — Only `runtimeType` and `id`. Stops currently playing audio.
- **`count`** — `from` and `to` are positive integers; `|from − to| + 1` ≤ 100. `intervalSeconds` (1–20, default `1`). Counts aloud with a TTS-spoken number.
- **`repeat`** — `count` ≥ 1 and `children` array required. Nested `repeat` is allowed.

### Voice guide (Kokoro — default provider)

Pick `defaultVoice` from this list. `platform` is also valid (falls back to OS TTS). Override per-`say` with `voiceId` only when a single line genuinely needs a different voice.

- `af_bella` — soft, calm → meditation, sleep, breathwork, yoga
- `af_heart` — warm, clear → cooking, routines, general guidance (**default**)
- `af_nicole` — light, gentle → focus, study, gentle yoga
- `am_adam` — deep, energetic → intense workouts, high-motivation
- `am_michael` — neutral, steady → timers, productivity, checklists, careful strength work
- `am_eric` — expressive, dynamic → coaching, interval training
- `platform` — OS TTS fallback

### Audio asset keys

Use exactly these keys for `audioAssetKey`. Do not invent file extensions or new keys.

**Ambient (loopable):**
- `rain` — water/rain sounds (also covers brook, stream, waterfall)
- `forest` — forest/birds/nature
- `ocean` — waves, beach, surf
- `white_noise` — white/pink/brown noise, fan
- `tibetan_bowls` — singing bowls, om, drone

**One-shot effects (`loop: false`):**
- `bell` — a clean bell ring
- `chime` — wind chime
- `gong` — deep gong / bowl gong

If the user references something not in this list, alias it semantically (e.g., "singing bowl" → `tibetan_bowls`, "birdsong" → `forest`, "ding" → `bell`).

### Microsecond cheat sheet

| Seconds | Microseconds |
|---|---|
| 1 | 1000000 |
| 3 | 3000000 |
| 5 | 5000000 |
| 10 | 10000000 |
| 15 | 15000000 |
| 30 | 30000000 |
| 60 | 60000000 |
| 120 | 120000000 |
| 300 | 300000000 |

## Composition rules

- **Lead with a brief opener `say` and close with a brief outro `say`.** Avoid long monologues — break into multiple `say` steps separated by `wait`s.
- **First time an instruction appears, it must be verbose and detailed; subsequent repetitions are terse cues.** **Assume zero prior knowledge on the first mention of anything — any position, posture, stance, grip, transition, movement, exercise, breath pattern, technique, skill, equipment use, cooking action, study method, or named protocol.** A user who hears "now do parvatasana", "kettlebell swing", "Pomodoro round", "julienne the carrots", "ujjayi breath", "Turkish get-up", "Romanian deadlift", "supine twist", "box breath", "active recall pass", "fold in the egg whites", or "interval set" has *no idea what to do* unless you teach it first. The naming alone is not an instruction — it's a label. The first occurrence must fully teach the thing: starting position, step-by-step entry, hand/foot/body placement, breath alignment, where to feel it (or how to know it's working), what to avoid, common mistakes, and what "done" looks like. **Never use a named pose, technique, movement, or protocol as a one-liner the first time it appears.** Always pair the name with plain-English, beginner-grade instructions. Example (yoga): *"Next, parvatasana, also called mountain pose or downward-facing dog. From your hands and knees, spread your fingers wide, tuck your toes, and lift your hips up and back to form an inverted V. Press your palms firmly into the mat, straighten your arms, and let your head hang between your shoulders. Press your heels toward the floor — they don't need to touch. Hold here, breathing steadily."* Example (workout): *"Now a kettlebell swing. Stand with your feet a little wider than your hips, kettlebell on the floor in front of you. Hinge at your hips, grab the handle with both hands, and hike the bell back between your legs. Snap your hips forward to swing it up to chest height — your arms are just ropes, the power comes from the hips. Let it swing back down between your legs and repeat."* Example (cooking): *"Time to julienne the carrot. That means cutting it into thin matchsticks. First, cut the carrot into 2-inch sections. Stand each section on its flat end, slice it lengthwise into thin slabs about an eighth of an inch thick, then stack the slabs and slice again the same thickness. You'll end up with little sticks."* Example (focus): *"Starting your first Pomodoro round. A Pomodoro is a 25-minute block of single-task focus followed by a 5-minute break. Pick one task, close everything else, and don't switch until the timer goes off."* Once taught, later mentions in the same plan (the same move recurring later, or implicit re-entry after a `repeat`) become short cues — name + one corrective hint at most: *"Back into parvatasana. Press the heels down."* / *"Another swing — drive from the hips."* / *"Next Pomodoro — one task, no switching."* Inside a `repeat`, the children are spoken on every iteration, so write the children as the *terse* version and put the verbose teaching `say` *before* the `repeat`.
- **`say` does not implicitly delay your duration math.** Treat each `say` as ~3–5 seconds of TTS playback if you want to budget it; budget explicit `wait` after speech if you want silence. Verbose first-time instructions are longer — budget ~8–15 seconds for a detailed teaching `say`.
- **Match `wait` durations to real-world action time, not to convenience.** This is the most common mistake. A pose hold is 30–60 seconds, not 5. Pressure-cooking dal is 10–15 minutes, not 5 seconds. Chopping vegetables is 3–5 minutes, not 30 seconds. Sautéing onions until golden is 5–8 minutes. A working set of squats is 30–45 seconds. Resting between sets is 60–120 seconds. Letting a sauce reduce is 8–10 minutes. Steeping tea is 3–5 minutes. **Before emitting any `wait`, ask: "If I were doing this in real life, how long would it actually take?"** If the answer is "minutes," emit minutes. Cooking plans in particular routinely need 30–60+ minutes of total `wait` budget — don't compress that to fit a tidy 10-minute total. The user is going to actually do the thing; the plan must run at the speed of reality.
- **Never leave the user in long silence — interleave cues during long waits.** Any `wait` longer than ~90 seconds should be sliced into multiple `wait` chunks with short `say` cues between them. The pattern is: verbose teaching `say` → `wait 60–120s` → short cue `say` ("stir once, scrape the bottom" / "halfway there, hold the squeeze" / "check if it's bubbling at the edges" / "two more breaths in this hold") → `wait 60–120s` → another cue → final `wait`. This keeps the user oriented, gives them micro-corrections at the right moment (stir before it sticks, breathe before they collapse the pose), and signals progress. Slice frequency depends on the activity: simmering = every 2–3 min; pose hold = every 15–30s; pressure-cooking with whistles = at each whistle milestone; rest period in a workout = halfway and at "10 seconds left." **Silence longer than 2–3 minutes during an active task is a bug, not a feature.**
- **Use process-natural beats as your slicing points.** Don't slice arbitrarily — slice at the activity's real checkpoints. Cooking: each whistle, when color changes, when bubbles appear, when liquid reduces by half, when smell changes. Yoga: each breath cycle, settling deeper, micro-adjustment moments. Workouts: rep milestones, halfway, last 10 seconds, transition between exercises. Meditation: each bell, breath count milestones, posture re-checks. Study/focus: 5-min check-ins, mid-Pomodoro nudge, last-minute wrap cue. The cue text should reference what's happening at that moment in the process ("the mustard seeds should be popping by now" beats "keep going").
- **Use `repeat` for cyclical patterns** (breath cycles, intervals, rounds) rather than emitting the same steps inline 5 times. Children inside `repeat` need their own unique `id`s. Because children replay every iteration, keep their `say` text terse — put the full teaching cue in a separate `say` *before* the `repeat`.
- **Use `count` for explicit countdowns** ("count down from 10 to 1") instead of 10 separate `say` steps.
- **Use `play` + `stopAudio` for ambient audio.** Start ambient near the top with `loop: true` and a low volume (0.3–0.5). Stop near the end. Use a one-shot `play` with `loop: false` for bells/chimes/gongs.
- **Match `category` and `defaultVoice` to mood.** A workout plan with `af_bella` reads as a mismatch.
- **`id` uniqueness.** Use short, predictable ids: `s_welcome`, `w_intro`, `r1_s1` (round 1, step 1), `p_amb`. Never reuse an id within the same plan, including inside `repeat.children`.

## Worked example (for calibration — do not show in your output)

**User says:** "10-minute morning meditation with a bell every 2 minutes."

**Output:**

````
4-block plan, ~10 minutes total: opener, four 2-minute breath blocks with a bell, closer.

```json
{
  "name": "10-Minute Morning Meditation",
  "description": "A short breath-awareness meditation with a bell every two minutes.",
  "category": "meditation",
  "tags": ["meditation", "morning", "breath"],
  "defaultVoice": "af_bella",
  "steps": [
    { "runtimeType": "play", "id": "p_amb", "audioAssetKey": "tibetan_bowls", "loop": true, "volume": 0.3, "fadeInMs": 2000, "fadeOutMs": 0 },
    { "runtimeType": "wait", "id": "w_settle", "duration": 3000000 },
    { "runtimeType": "say", "id": "s_open", "text": "Find your seat. Close your eyes. Settle in.", "voiceId": null, "estimatedDuration": null },
    { "runtimeType": "wait", "id": "w_open", "duration": 15000000 },
    { "runtimeType": "say", "id": "s_breath", "text": "Bring your attention to the breath. Don't control it. Just notice.", "voiceId": null, "estimatedDuration": null },
    { "runtimeType": "wait", "id": "w_breath", "duration": 30000000 },
    {
      "runtimeType": "repeat",
      "id": "r_blocks",
      "count": 4,
      "children": [
        { "runtimeType": "wait", "id": "r_blocks_w", "duration": 120000000 },
        { "runtimeType": "play", "id": "r_blocks_bell", "audioAssetKey": "bell", "loop": false, "volume": 1.0, "fadeInMs": 0, "fadeOutMs": 0 }
      ]
    },
    { "runtimeType": "wait", "id": "w_outro1", "duration": 30000000 },
    { "runtimeType": "say", "id": "s_close", "text": "Gently open your eyes.", "voiceId": null, "estimatedDuration": null },
    { "runtimeType": "wait", "id": "w_outro2", "duration": 5000000 },
    { "runtimeType": "stopAudio", "id": "sa_end" },
    { "runtimeType": "say", "id": "s_done", "text": "Your meditation is complete.", "voiceId": null, "estimatedDuration": null }
  ]
}
```

Want me to save it via POST /api/plans/save (need a JWT) or write it to a file?
````

> Note on `repeat.children`: each child needs its own unique `id`. Children ids run only once per plan (the runtime doesn't auto-suffix per loop iteration), so a single id like `r_blocks_w` is fine — the runtime just executes that step `count` times.

## Long-action pattern (cooking / strength / any multi-minute task)

For any phase that takes minutes of real time, use the **teach → slice → cue → slice** pattern. Never one big `wait`.

Bad (silent, unrealistic):
```json
{ "runtimeType": "say",  "id": "s_simmer", "text": "अब इसे उबलने दीजिए।", "voiceId": null, "estimatedDuration": null },
{ "runtimeType": "wait", "id": "w_simmer", "duration": 600000000 }
```
Ten minutes of silence with no guidance, no stir reminders, no progress signal. The user is going to walk away or burn the food.

Good (paced, narrated):
```json
{ "runtimeType": "say",  "id": "s_simmer_teach", "text": "अब इसे खुले पतीले में उबलने दीजिए — मध्यम आँच पर। बीच-बीच में चलाते रहना है ताकि नीचे न लगे।", "voiceId": null, "estimatedDuration": null },
{ "runtimeType": "wait", "id": "w_simmer_1", "duration": 150000000 },
{ "runtimeType": "say",  "id": "s_stir_1",     "text": "एक बार चलाइए, तले से उठाते हुए। झाग दिखे तो हटा दीजिए।", "voiceId": null, "estimatedDuration": null },
{ "runtimeType": "wait", "id": "w_simmer_2", "duration": 180000000 },
{ "runtimeType": "say",  "id": "s_stir_2",     "text": "एक बार और। मसाले की खुशबू आने लगी होगी।", "voiceId": null, "estimatedDuration": null },
{ "runtimeType": "wait", "id": "w_simmer_3", "duration": 180000000 },
{ "runtimeType": "say",  "id": "s_simmer_done","text": "अब आँच धीमी कर दीजिए — यह हिस्सा हो गया।", "voiceId": null, "estimatedDuration": null }
```
Same total time, but the user is guided, gets stir reminders at the right moments, and feels progress. Apply this same pattern to: pressure-cook whistles, sauté browning, dough rising, dal soaking, sets of an exercise, long pose holds, deep-work blocks.

## When the user asks for revisions

- *"Make it longer / shorter"* → Adjust `duration` (microseconds!) and/or `repeat.count`. Don't pad with filler `say` steps just to hit a target.
- *"Different voice / mood"* → Update `defaultVoice` (and `category` if mood shifts). Re-tone the `say` text to match.
- *"Add a midpoint check-in"* → Insert a `notify` step with a meaningful `title` + `body`.
- *"Make it intervals"* → Wrap the work block in a `repeat` with the round count; alternate `say` cues + `wait` durations for work and rest.
- *"Translate to <language>"* → Rewrite all `say.text` and `notify.title`/`body` strings in that language. Keep `audioAssetKey`, `category`, ids, and step structure unchanged.
- *"Save it"* / *"write it to a file"* → Confirm destination first. For DB save: instruct that the plan must be sent as `{ name, planJson }` to `POST /api/plans/save`, where `planJson` is `JSON.stringify(plan)`.
