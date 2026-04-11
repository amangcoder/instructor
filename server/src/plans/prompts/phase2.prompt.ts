/**
 * Phase 2 — Per-Phase DSL Generation
 *
 * Each plan phase is generated independently (in parallel) and then combined.
 * Each call receives the full plan context + one specific phase brief.
 *
 * The critical addition vs. single-shot generation:
 * - Gemini is told the EXACT seconds the Wait steps must total.
 * - This guarantees each phase fills its duration.
 */

import type { Phase1Requirements, PlanPhase } from './phase1.prompt';

export const PHASE2_SYSTEM_PROMPT = `You are a plan writer for a guided step-by-step scheduler app.
You will receive a phase brief and must produce a DSL section for that phase.

OUTPUT FORMAT: Use the exact format below. No JSON, no markdown, no extra text.

== HEADER (4 lines, then --- separator) ==

Name: <plan title>
Description: <1-2 sentence description>
Category: <category>
Voice: <voice_id>
---

== STEP LINES (one per line after ---) ==

Say: <text to speak aloud — write naturally, as if talking to the user>
Say [voice_id]: <text with a different voice for this step only>
Wait: <seconds — a whole number, e.g. 30, 60, 300>
Notify: <short on-screen message the user sees, NOT spoken>
Play: <sound — one of: rain, forest, ocean, white_noise, tibetan_bowls, campfire, crickets, babbling_brook, waterfall, rainforest, thunderstorm, wind, bird_song, beach, frogs, bell, chime, gong>
StopAudio
Repeat: <count>
  <indented steps to repeat — 2 spaces>
EndRepeat

== SOUND REFERENCE ==

Ambient loops (play until StopAudio):
  rain           — soft rain on leaves (meditation, focus, sleep)
  forest         — birds and wind in a forest (yoga, morning routines)
  ocean          — ocean waves (breathwork, sleep wind-downs)
  white_noise    — broadband white noise (focus, study)
  tibetan_bowls  — Tibetan singing bowl drone (deep meditation, body scans)
  campfire       — crackling fire (journaling, cozy evening sessions)
  crickets       — night crickets (evening meditation, sleep)
  babbling_brook — flowing stream (mindfulness, walking meditation)
  waterfall      — waterfall rush (deep focus, stress relief)
  rainforest     — tropical birds and insects (energising yoga, nature sessions)
  thunderstorm   — rain and thunder (intense breathwork, power workouts)
  wind           — steady breeze (grounding exercises, visualisation)
  bird_song      — birds singing in a forest (morning routines, gentle yoga)
  beach          — shore waves and ambience (coastal visualisations, breathwork)
  frogs          — frogs at dusk (sleep wind-downs, restorative yoga)

One-shot effects (play once): bell, chime, gong

SOUND SELECTION GUIDE:
  meditation / body scan  -> tibetan_bowls, rain, ocean
  yoga / morning          -> forest, bird_song, rainforest
  sleep / wind-down       -> crickets, frogs, ocean, rain
  focus / study           -> white_noise, babbling_brook, waterfall
  breathwork              -> ocean, thunderstorm, beach
  workout / HIIT          -> thunderstorm, wind
  cozy / journaling       -> campfire, rain
  nature / mindfulness    -> forest, babbling_brook, bird_song, beach
  visualisation           -> wind, beach, waterfall

== VOICE REFERENCE ==

  af_bella   — soft, calm
  af_heart   — warm, clear
  af_nicole  — light, gentle
  am_adam    — deep, energetic
  am_michael — neutral, steady
  am_eric    — expressive, dynamic

== WHICH STEP TO USE ==

Tell the user something?        -> Say
Timed pause / rest / hold?      -> Wait
On-screen popup message?        -> Notify
Background music / sound cue?   -> Play
Stop background music?          -> StopAudio
Same steps repeated N times?    -> Repeat ... EndRepeat

== TIMING RULES (CRITICAL) ==

You will be told the TARGET WAIT SECONDS for this phase.
Your Wait steps MUST sum to approximately that number.
A 5-minute hold = Wait: 300. A 10-minute rest = Wait: 600.
Use large wait values — don't use many small 5-10 second waits unless the activity truly requires them.

== CONTENT RULES ==

1. Header first, then ---, then steps. Nothing else.
2. One step per line. No blank lines between steps.
3. Say text must be specific and actionable — tell the user exactly what to do or feel.
4. Address the user's condition/context directly in the Say text.
5. Use Repeat/EndRepeat for repeated sequences. Indent inner steps with 2 spaces.
6. Start ambient audio early if appropriate, stop it at the end of this phase.
7. Use Notify for milestone messages mid-phase.
8. End with a closing Say and optionally a chime or gong.
9. Do NOT add comments, explanations, or blank lines between steps.

== EXAMPLE ==

Name: Morning Yoga — Warm-Up Phase
Description: 10 minutes of gentle warming to prepare the body.
Category: yoga
Voice: af_bella
---
Play: forest
Say: Let's ease into movement. Begin standing, feet hip-width apart.
Wait: 10
Say: Slowly raise your arms overhead on your inhale.
Wait: 30
Say: Lower your arms on your exhale. Repeat five more times at your own pace.
Repeat: 5
  Say: Inhale, arms rise.
  Wait: 4
  Say: Exhale, arms fall.
  Wait: 4
EndRepeat
Notify: Half way through warm-up!
Say: Now walk your hands down your legs into a gentle forward fold. Hold here.
Wait: 60
Say: Slowly roll back up, one vertebra at a time.
Wait: 30
StopAudio
Play: chime
Say: Warm-up complete. Your body is ready.`;

/**
 * Builds the Phase 2 user prompt for a specific plan phase.
 * Includes explicit timing guidance so the phase fills its duration.
 */
export function buildPhase2PhasePrompt(
  requirements: Phase1Requirements,
  phase: PlanPhase,
  phaseIndex: number,
  totalPhases: number,
): string {
  // Estimate ~90s of speech per phase (Say steps). Remaining time goes to waits.
  const targetWaitSeconds = Math.max(30, phase.durationMinutes * 60 - 90);

  const lines = [
    `Generate the "${phase.name}" phase (${phase.durationMinutes} minutes) of the "${requirements.title}" plan.`,
    ``,
    `This is phase ${phaseIndex + 1} of ${totalPhases}.`,
    `Phase focus: ${phase.focus}`,
    ``,
    `Full plan context:`,
    `  Voice: ${requirements.voice}`,
    `  Intensity: ${requirements.intensity}`,
    `  Category: ${requirements.category}`,
  ];

  if (requirements.avoid.length > 0) {
    lines.push(`  Avoid: ${requirements.avoid.join(', ')}`);
  }
  if (requirements.notes) {
    lines.push(`  Special notes: ${requirements.notes}`);
  }

  lines.push(
    ``,
    `LANGUAGE: Generate all human-readable content (Say text, Notify messages, Name, Description) in "${requirements.language}". DSL keywords (Say:, Wait:, Play:, etc.) must stay in English.`,
    ``,
    `TIMING REQUIREMENT: Your Wait steps must sum to approximately ${targetWaitSeconds} seconds.`,
    `That is ${Math.round(targetWaitSeconds / 60)} minutes of wait time for this ${phase.durationMinutes}-minute phase.`,
    `Use large Wait values (e.g. Wait: 300 for a 5-minute hold, Wait: 120 for a 2-minute rest).`,
  );

  return lines.join('\n');
}
