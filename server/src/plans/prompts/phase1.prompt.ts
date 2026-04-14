/**
 * Phase 1 — Requirements Extraction + Phase Division
 *
 * A small, focused Gemini call that:
 * 1. Understands the user's request
 * 2. Determines category, voice, intensity, etc.
 * 3. Divides the plan into logical phases with exact durations
 *
 * The phases are then handed to Phase 2 which generates each one independently
 * (in parallel) and combines them into a single plan.
 */

// ── Per-provider voice guides ─────────────────────────────────────────────────

/** Voice IDs available per provider (for the AI voice field). */
export const PROVIDER_VOICE_IDS: Record<string, string[]> = {
  kokoro: ['af_bella', 'af_heart', 'af_nicole', 'am_adam', 'am_michael', 'am_eric'],
  gemini: ['leda', 'aoede', 'kore', 'charon', 'puck', 'fenrir'],
  elevenlabs: [
    'FGY2WhTYpPnrIDTdsKH5', // Laura — soft, calm
    'EXAVITQu4vr4xnSDxMaL', // Sarah — warm, clear
    'XB0fDUnXU5powFXDhCwa', // Charlotte — light, gentle
    'JBFqnCBsd6RMkjVDRZzb', // George — deep, energetic
    'IKne3meq5aSn9XLyUdCD', // Charlie — neutral, steady
    'cjVigY5qzO86Huf0OWal', // Eric — expressive, dynamic
  ],
};

/** Human-readable voice guide section per provider. */
const PROVIDER_VOICE_GUIDES: Record<string, string> = {
  kokoro: `VOICE GUIDE (pick based on plan mood):
  af_bella   -> soft, calm (meditation, yoga, sleep, breathwork)
  af_heart   -> warm, clear (cooking, routines, general guidance)
  af_nicole  -> light, gentle (focus, study, gentle yoga)
  am_adam    -> deep, energetic (intense workouts, high-motivation)
  am_michael -> neutral, steady (timers, productivity, checklists)
  am_eric    -> expressive, dynamic (coaching, interval training)`,

  gemini: `VOICE GUIDE (pick based on plan mood):
  leda   -> soft, calm (meditation, yoga, sleep, breathwork)
  aoede  -> warm, clear (cooking, routines, general guidance)
  kore   -> light, gentle (focus, study, gentle yoga)
  charon -> deep, energetic (intense workouts, high-motivation)
  puck   -> neutral, steady (timers, productivity, checklists)
  fenrir -> expressive, dynamic (coaching, interval training)`,

  elevenlabs: `VOICE GUIDE (pick based on plan mood):
  FGY2WhTYpPnrIDTdsKH5 -> soft, calm (meditation, yoga, sleep, breathwork)
  EXAVITQu4vr4xnSDxMaL -> warm, clear (cooking, routines, general guidance)
  XB0fDUnXU5powFXDhCwa -> light, gentle (focus, study, gentle yoga)
  JBFqnCBsd6RMkjVDRZzb -> deep, energetic (intense workouts, high-motivation)
  IKne3meq5aSn9XLyUdCD -> neutral, steady (timers, productivity, checklists)
  cjVigY5qzO86Huf0OWal -> expressive, dynamic (coaching, interval training)`,
};

/** Default voice per provider — used as the plan's defaultVoice when no voice is specified. */
export const PROVIDER_DEFAULT_VOICES: Record<string, string> = {
  kokoro: 'af_heart',
  gemini: 'aoede',
  elevenlabs: 'EXAVITQu4vr4xnSDxMaL',
};

// ── Dynamic prompt builder ────────────────────────────────────────────────────

/**
 * Builds the Phase 1 system prompt with voice IDs and guide appropriate for
 * the active TTS provider.
 */
export function buildPhase1SystemPrompt(provider: string): string {
  const voiceIds = PROVIDER_VOICE_IDS[provider] ?? PROVIDER_VOICE_IDS.kokoro;
  const voiceGuide = PROVIDER_VOICE_GUIDES[provider] ?? PROVIDER_VOICE_GUIDES.kokoro;
  const voiceEnum = voiceIds.join(', ');

  return `You are a requirements extractor and plan architect for a guided step-by-step scheduler app.
Given a user's natural-language request, extract structured requirements AND divide the plan into logical phases.

OUTPUT: Return ONLY a JSON object with these fields. No markdown, no explanation.

{
  "title": "string — short plan title, max 60 chars",
  "description": "string — 1-2 sentence description of the full plan",
  "category": "string — one of: yoga, meditation, workout, cooking, routine, focus, custom",
  "voice": "string — one of: ${voiceEnum}",
  "durationMinutes": number — total plan duration,
  "intensity": "string — one of: low, moderate, high",
  "avoid": ["string array — things to avoid given the context, empty if none"],
  "notes": "string — any special considerations from the user's context",
  "language": "string — the language or communication style to use for all human-readable content. Detect from the prompt. Use natural descriptions like 'English', 'Hindi', 'Spanish', 'Hinglish (casual Hindi-English mix)', 'formal French', etc. Mirror the user's own style.",
  "phases": [
    {
      "name": "string — short phase title",
      "durationMinutes": number — exact duration for this phase,
      "focus": "string — what this phase covers and why"
    }
  ]
}

PHASE DESIGN RULES:
- Phases must sum to exactly durationMinutes.
- Aim for 3-6 phases. Avoid phases shorter than 5 minutes.
- Each phase should have a clear, distinct purpose (e.g. "warm-up", "main set", "cool-down").
- Phase names should be short and clear (max 40 chars).
- Order phases logically: preparation → main content → wind-down.

CATEGORY GUIDE:
  yoga       -> yoga, stretching, flexibility, poses
  meditation -> guided meditation, breathwork, body scan, sleep
  workout    -> exercise, HIIT, strength, cardio
  cooking    -> recipes, meal prep, baking
  routine    -> morning/evening routines, habits, checklists
  focus      -> study sessions, deep work, Pomodoro
  custom     -> anything else

${voiceGuide}

RULES:
1. If the user doesn't specify duration, infer a reasonable one (5-30 min for most plans).
2. If the user mentions a physical condition (pain, injury, tiredness), set intensity to "low" and add relevant items to "avoid".
3. Always fill all fields — use empty arrays for avoid if nothing applies.`;
}

export function buildPhase1Schema(provider: string) {
  const voiceIds = PROVIDER_VOICE_IDS[provider] ?? PROVIDER_VOICE_IDS.kokoro;
  return buildPhase1SchemaWithVoices(voiceIds);
}

function buildPhase1SchemaWithVoices(voiceIds: string[]) {
  return {
  type: 'object' as const,
  required: ['title', 'description', 'category', 'voice', 'durationMinutes', 'intensity', 'avoid', 'notes', 'language', 'phases'],
  properties: {
    title: { type: 'string' as const },
    description: { type: 'string' as const },
    category: {
      type: 'string' as const,
      enum: ['yoga', 'meditation', 'workout', 'cooking', 'routine', 'focus', 'custom'],
    },
    voice: {
      type: 'string' as const,
      enum: voiceIds,
    },
    durationMinutes: { type: 'number' as const, minimum: 1 },
    intensity: { type: 'string' as const, enum: ['low', 'moderate', 'high'] },
    avoid: { type: 'array' as const, items: { type: 'string' as const } },
    notes: { type: 'string' as const },
    language: { type: 'string' as const },
    phases: {
      type: 'array' as const,
      minItems: 1,
      items: {
        type: 'object' as const,
        required: ['name', 'durationMinutes', 'focus'],
        properties: {
          name: { type: 'string' as const },
          durationMinutes: { type: 'number' as const, minimum: 1 },
          focus: { type: 'string' as const },
        },
      },
    },
  },
  };
}

export interface PlanPhase {
  name: string;
  durationMinutes: number;
  focus: string;
}

export interface Phase1Requirements {
  title: string;
  description: string;
  category: string;
  voice: string;
  durationMinutes: number;
  intensity: string;
  avoid: string[];
  notes: string;
  language: string;
  phases: PlanPhase[];
}
