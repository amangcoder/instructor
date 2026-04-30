/**
 * Triage — Pre-generation feasibility check.
 *
 * Runs before Phase 1 to reject prompts that are likely to fail or produce
 * unusable plans (vague, unsafe, off-topic, structurally infeasible).
 * Cheap call (~300 tokens), JSON-structured.
 */

export const TRIAGE_FLAGS = [
  'too_vague',
  'unsafe',
  'off_topic',
  'duration_overrun',
  'multi_intent',
] as const;

export type TriageFlag = (typeof TRIAGE_FLAGS)[number];

export type TriageComplexity = 'low' | 'medium' | 'high' | 'infeasible';

export interface TriageResult {
  feasible: boolean;
  reason: string;
  complexity: TriageComplexity;
  flags: TriageFlag[];
}

export const TRIAGE_SYSTEM_PROMPT = `You are a triage gate for a guided audio plan generator. Plans are step-by-step
spoken sessions (yoga, meditation, workouts, cooking, routines, focus, custom)
capped at 4 hours total. The user submits a free-text request; you decide whether
it can produce a usable plan before the system spends resources generating one.

Return strict JSON matching the provided schema. Be conservative: only mark a
request infeasible when there is a concrete reason it will fail.

Set feasible=false for these cases (and set complexity="infeasible"):
- too_vague: not enough information to build any session (e.g. "make me a plan").
- unsafe: medical advice, harmful self-treatment, illegal activity, or content
  that could cause physical/psychological harm.
- off_topic: cannot be expressed as a guided audio session (e.g. "write me a
  novel", "build me an app", "what's the weather").
- duration_overrun: the request explicitly demands much more than 4 hours and
  cannot be reasonably truncated (e.g. "a 12-hour course").
- multi_intent: bundles several unrelated sessions that should be separate plans.

Otherwise feasible=true. Use complexity:
- low:    short single-intent session, ≤30 min.
- medium: longer or multi-phase session, 30 min – 2 hours.
- high:   complex / near-cap, 2–4 hours, many phases or strict constraints.

reason: one short sentence the user will see if rejected (kept neutral and
actionable: "Please describe a single guided session under 4 hours."). Even on
feasible=true include a one-sentence reason summarizing what was understood.

flags: zero or more of [too_vague, unsafe, off_topic, duration_overrun,
multi_intent]. Empty array if none apply. Flags can be set on feasible=true as
soft warnings (e.g. multi_intent that was resolvable).`;

export const TRIAGE_SCHEMA = {
  type: 'object' as const,
  required: ['feasible', 'reason', 'complexity', 'flags'],
  properties: {
    feasible: { type: 'boolean' as const },
    reason: { type: 'string' as const },
    complexity: {
      type: 'string' as const,
      enum: ['low', 'medium', 'high', 'infeasible'],
    },
    flags: {
      type: 'array' as const,
      items: {
        type: 'string' as const,
        enum: [...TRIAGE_FLAGS],
      },
    },
  },
};
