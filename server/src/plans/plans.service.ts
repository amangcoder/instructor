import {
  Injectable,
  Logger,
  HttpException,
  HttpStatus,
  UnprocessableEntityException,
  ServiceUnavailableException,
  BadGatewayException,
} from '@nestjs/common';
import { validatePlan } from './validators/plan.validator';
import { UpstashRateLimitService } from '../ratelimit/upstash-ratelimit.service';

// ── Constants ────────────────────────────────────────────────────────────────

const GEMINI_GENERATE_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

const MAX_RETRIES = 2;
const PLAN_GENERATION_LIMIT = 5;
const PLAN_GENERATION_WINDOW_SEC = 10 * 365 * 24 * 60 * 60; // ~10 years (effective lifetime cap)

// ── Plan JSON schema for Gemini ───────────────────────────────────────────────

const PLAN_SCHEMA = {
  type: 'object',
  required: ['name', 'description', 'category', 'defaultVoice', 'steps'],
  properties: {
    name: { type: 'string' },
    description: { type: 'string' },
    category: {
      type: 'string',
      enum: ['yoga', 'meditation', 'workout', 'cooking', 'routine', 'focus', 'custom'],
    },
    defaultVoice: {
      type: 'string',
      enum: ['af_heart', 'af_bella', 'af_nicole', 'am_adam', 'am_michael', 'am_eric', 'platform'],
    },
    steps: {
      type: 'array',
      minItems: 1,
      items: {
        oneOf: [
          {
            type: 'object',
            required: ['type', 'text'],
            properties: {
              type: { type: 'string', enum: ['say'] },
              text: { type: 'string' },
              voice: {
                type: 'string',
                enum: ['af_heart', 'af_bella', 'af_nicole', 'am_adam', 'am_michael', 'am_eric', 'platform'],
              },
            },
          },
          {
            type: 'object',
            required: ['type', 'durationSeconds'],
            properties: {
              type: { type: 'string', enum: ['wait'] },
              durationSeconds: { type: 'number', minimum: 1 },
            },
          },
          {
            type: 'object',
            required: ['type', 'message'],
            properties: {
              type: { type: 'string', enum: ['notify'] },
              message: { type: 'string' },
            },
          },
          {
            type: 'object',
            required: ['type', 'assetKey'],
            properties: {
              type: { type: 'string', enum: ['play'] },
              assetKey: {
                type: 'string',
                enum: ['rain', 'forest', 'ocean', 'white_noise', 'tibetan_bowls', 'bell', 'chime', 'gong'],
              },
            },
          },
          {
            type: 'object',
            required: ['type'],
            properties: {
              type: { type: 'string', enum: ['stopAudio'] },
            },
          },
          {
            type: 'object',
            required: ['type', 'count', 'steps'],
            properties: {
              type: { type: 'string', enum: ['repeat'] },
              count: { type: 'number', minimum: 1 },
              steps: { type: 'array' },
            },
          },
        ],
      },
    },
  },
};

const SYSTEM_PROMPT = `You are a plan generator for a guided step-by-step scheduler app.
Users can create plans for ANYTHING: yoga, workouts, cooking recipes, morning routines, study sessions, meditation, focus blocks, language practice, skincare, breathing exercises, and more.
Your job is to turn any description into a complete, structured, executable plan.

OUTPUT RULE: Return ONLY a single JSON object. No markdown fences, no comments, no explanation text before or after. Start with { and end with }.

════════════════════════════════════════
PLAN OBJECT — ALL FIELDS ARE REQUIRED
════════════════════════════════════════

{
  "name": "string — short title, max 60 characters",
  "description": "string — 1 to 2 sentences describing what this plan does",
  "category": "string — MUST be exactly one of the 7 values listed below",
  "defaultVoice": "string — MUST be exactly one of the 6 values listed below",
  "steps": [ ...array of step objects, at least 1... ]
}

CATEGORY — choose the closest match:
  "yoga"        → yoga flows, stretching, flexibility
  "meditation"  → guided meditation, breathwork, body scan, sleep wind-down
  "workout"     → exercise, HIIT, strength, cardio, warm-up/cool-down
  "cooking"     → recipes, meal prep, baking
  "routine"     → morning/evening routines, habits, checklists, multi-step rituals
  "focus"       → study sessions, deep work, Pomodoro, productivity blocks
  "custom"      → anything that does not fit the above

DEFAULT VOICE — choose based on the plan's mood:
  "af_bella"   → soft, calm (meditation, yoga, sleep, breathwork)
  "af_heart"   → warm, clear (cooking, morning routines, general guidance)
  "af_nicole"  → light, gentle (focus, study, gentle yoga)
  "am_adam"    → deep, energetic (intense workouts, high-motivation)
  "am_michael" → neutral, steady (timers, productivity, checklists)
  "am_eric"    → expressive, dynamic (coaching, interval training)

════════════════════════════════════════
STEP TYPES — 6 TYPES AVAILABLE
════════════════════════════════════════

Every step object MUST have a "type" field. Use ONLY the types defined below.

──────────────────────────────
TYPE 1: say
Purpose: Speak a text instruction aloud via text-to-speech.
Use for: verbal cues, instructions, countdowns, encouragement, narration.
Required fields: type, text
Optional fields: voice (overrides defaultVoice for this step only)
Schema:
  {
    "type": "say",
    "text": "string — what to speak aloud. Write naturally, as if talking to the user.",
    "voice": "string — optional, same values as defaultVoice"
  }
Examples:
  { "type": "say", "text": "Welcome. Find a comfortable seated position and close your eyes." }
  { "type": "say", "text": "Ten seconds left — push through!", "voice": "am_eric" }
  { "type": "say", "text": "Add the garlic and stir for one minute." }

──────────────────────────────
TYPE 2: wait
Purpose: Pause silently for a fixed number of seconds.
Use for: exercise holds, rest periods, cooking timers, reading time, silent gaps.
Required fields: type, durationSeconds
Rule: durationSeconds must be a whole number >= 1
Schema:
  {
    "type": "wait",
    "durationSeconds": number
  }
Examples:
  { "type": "wait", "durationSeconds": 30 }   ← 30-second rest
  { "type": "wait", "durationSeconds": 300 }  ← 5-minute simmer timer
  { "type": "wait", "durationSeconds": 10 }   ← 10-second hold

──────────────────────────────
TYPE 3: notify
Purpose: Show a short on-screen message at a key moment. Not spoken aloud.
Use for: important checkpoints, status updates, warnings the user must see.
Required fields: type, message
Schema:
  {
    "type": "notify",
    "message": "string — brief, clear message"
  }
Examples:
  { "type": "notify", "message": "Halfway done — great work!" }
  { "type": "notify", "message": "Time to flip the pancakes." }
  { "type": "notify", "message": "Set 1 complete. Rest for 60 seconds." }

──────────────────────────────
TYPE 4: play
Purpose: Start playing a looping ambient sound or a one-shot effect sound.
Use for: background atmosphere, transitions, audio cues.
Required fields: type, assetKey
Rule: assetKey MUST be exactly one of the values listed below — do not invent new keys.
Schema:
  {
    "type": "play",
    "assetKey": "string"
  }
Valid assetKey values:
  Ambient loops (play continuously until stopAudio):
    "rain"          → soft rain on leaves — meditation, focus, reading
    "forest"        → birds and wind — yoga, morning routines
    "ocean"         → ocean waves — breathwork, relaxation
    "white_noise"   → broadband white noise — focus, study, productivity
    "tibetan_bowls" → singing bowls drone — deep meditation, body scan
  One-shot effects (play once, then stop):
    "bell"          → soft bell — step start, transition
    "chime"         → wind chime — light transition, end of section
    "gong"          → deep gong — session end, major milestone
Examples:
  { "type": "play", "assetKey": "ocean" }
  { "type": "play", "assetKey": "gong" }
  { "type": "play", "assetKey": "white_noise" }

──────────────────────────────
TYPE 5: stopAudio
Purpose: Stop all currently playing ambient audio.
Use for: ending a background sound section before a new one, or at plan end.
Required fields: type only — no other fields.
Schema:
  { "type": "stopAudio" }

──────────────────────────────
TYPE 6: repeat
Purpose: Repeat a group of steps a fixed number of times.
Use for: exercise sets/reps, repeated rounds, recipe steps done multiple times.
Required fields: type, count, steps
Rule: count must be a whole number >= 1
Rule: steps is an array of step objects — can be any type, including nested repeat
Schema:
  {
    "type": "repeat",
    "count": number,
    "steps": [ ...array of step objects... ]
  }
Example — 3 sets of push-ups:
  {
    "type": "repeat",
    "count": 3,
    "steps": [
      { "type": "say", "text": "Start your push-ups now." },
      { "type": "wait", "durationSeconds": 30 },
      { "type": "say", "text": "Rest." },
      { "type": "wait", "durationSeconds": 15 }
    ]
  }

════════════════════════════════════════
DECISION GUIDE — WHICH STEP TO USE
════════════════════════════════════════

Need to tell the user something? → say
Need a timed pause (rest, hold, timer)? → wait
Need a pop-up message the user must notice? → notify
Need background music or a sound effect? → play
Need to stop background music? → stopAudio
Need to repeat the same steps N times? → repeat (put the steps inside it)

════════════════════════════════════════
COMPLETE EXAMPLE OUTPUT
════════════════════════════════════════

{
  "name": "5-Minute Desk Stretch",
  "description": "A quick seated stretch routine to relieve tension after long periods at a desk.",
  "category": "routine",
  "defaultVoice": "af_heart",
  "steps": [
    { "type": "say", "text": "Let's begin. Sit up straight and take a deep breath in." },
    { "type": "wait", "durationSeconds": 4 },
    { "type": "say", "text": "Slowly tilt your head to the right, hold for ten seconds." },
    { "type": "wait", "durationSeconds": 10 },
    { "type": "say", "text": "Now tilt to the left. Hold for ten seconds." },
    { "type": "wait", "durationSeconds": 10 },
    {
      "type": "repeat",
      "count": 3,
      "steps": [
        { "type": "say", "text": "Roll your shoulders backward slowly." },
        { "type": "wait", "durationSeconds": 5 }
      ]
    },
    { "type": "notify", "message": "Almost done — one more stretch!" },
    { "type": "say", "text": "Reach both arms overhead and stretch for fifteen seconds." },
    { "type": "wait", "durationSeconds": 15 },
    { "type": "play", "assetKey": "chime" },
    { "type": "say", "text": "Great job. You're done. Take one final deep breath and carry on." }
  ]
}

════════════════════════════════════════
RULES SUMMARY
════════════════════════════════════════

1. Output is a single JSON object — nothing else.
2. All 5 top-level fields (name, description, category, defaultVoice, steps) are required.
3. category must be one of the 7 allowed strings exactly.
4. defaultVoice must be one of the 6 allowed strings exactly.
5. Every step must have a "type" field matching one of the 6 step types exactly.
6. play.assetKey must be one of the 13 allowed strings exactly.
7. wait.durationSeconds and repeat.count must be numbers >= 1.
8. repeat.steps must be a non-empty array.
9. say.text must be non-empty.
10. notify.message must be non-empty.
11. Do not add any fields not listed above.`;

@Injectable()
export class PlansService {
  private readonly logger = new Logger(PlansService.name);

  constructor(private readonly rateLimit: UpstashRateLimitService) {}

  async generatePlan(
    prompt: string,
    userId: string,
    category?: string,
  ): Promise<{ plan: Record<string, unknown> }> {
    // Check rate limit (throws if exceeded) but do NOT record usage yet —
    // usage is only recorded after a successful plan is returned (Issue 12).
    await this.assertRateLimit(userId);

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new ServiceUnavailableException(
        'GEMINI_API_KEY is not set — plan generation is not configured',
      );
    }

    const userPrompt = category
      ? `Generate a ${category} plan: ${prompt}`
      : prompt;

    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
      if (attempt > 0) {
        this.logger.log(`Retrying plan generation (attempt ${attempt + 1}/${MAX_RETRIES + 1})`);
      }

      const plan = await this.callGemini(apiKey, userPrompt);
      const validation = validatePlan(plan);

      if (validation.valid && validation.plan) {
        // Record usage only after a successful response so that transient Gemini
        // errors do not count against the user's hourly quota.
        await this.rateLimit.increment('plan', userId, PLAN_GENERATION_WINDOW_SEC);
        this.logger.log(`Plan generated successfully for user ${userId}`);
        return { plan: validation.plan };
      }

      this.logger.warn(
        `Plan validation failed (attempt ${attempt + 1}): ${validation.errors.join('; ')}`,
      );

      if (attempt === MAX_RETRIES) {
        throw new UnprocessableEntityException({
          message: 'Generated plan does not conform to required schema after retries',
          errors: validation.errors,
        });
      }
    }

    // Should not reach here, but TypeScript requires a return.
    throw new UnprocessableEntityException('Plan generation failed');
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  private async callGemini(
    apiKey: string,
    prompt: string,
  ): Promise<unknown> {
    const requestBody = JSON.stringify({
      contents: [
        {
          role: 'user',
          parts: [{ text: `${SYSTEM_PROMPT}\n\nUser request: ${prompt}` }],
        },
      ],
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: PLAN_SCHEMA,
        temperature: 0.7,
        maxOutputTokens: 4096,
      },
    });

    this.logger.log(`Calling Gemini 2.5 Flash for plan generation`);

    const response = await fetch(GEMINI_GENERATE_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: requestBody,
      signal: AbortSignal.timeout(30_000),
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => '');
      this.logger.error(`Gemini plan generation error ${response.status}: ${errorText}`);
      throw new BadGatewayException(`Gemini API error ${response.status}`);
    }

    const data = (await response.json()) as {
      candidates?: Array<{
        content?: { parts?: Array<{ text?: string }> };
      }>;
    };

    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      this.logger.error('Gemini returned empty content for plan generation');
      throw new BadGatewayException('Gemini returned empty response');
    }

    try {
      return JSON.parse(text);
    } catch {
      this.logger.error(`Failed to parse Gemini JSON response: ${text.slice(0, 200)}`);
      throw new BadGatewayException('Gemini returned invalid JSON');
    }
  }

  /**
   * Throws TooManyRequestsException if the user has exceeded their hourly quota.
   * Does NOT record usage — call rateLimit.increment() after a successful response.
   */
  private async assertRateLimit(userId: string): Promise<void> {
    const result = await this.rateLimit.peek('plan', userId, PLAN_GENERATION_LIMIT);

    if (!result.allowed) {
      throw new HttpException(
        `Plan generation limit reached. You have used all ${PLAN_GENERATION_LIMIT} plan generations.`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }
}
