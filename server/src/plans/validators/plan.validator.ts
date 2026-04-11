/**
 * Validates a generated Plan object from the LLM against the Flutter Plan model schema.
 */

const VALID_STEP_TYPES = ['say', 'wait', 'play', 'notify', 'repeat', 'stopAudio', 'count'] as const;
const VALID_CATEGORIES = ['fitness', 'meditation', 'study', 'routine', 'custom'] as const;
// NOTE: Voice IDs are NOT validated here — any non-empty string is accepted.
// Voices are validated downstream by the TTS provider at synthesis time.
// A hardcoded allowlist would break silently whenever a provider adds new voices.

export interface PlanValidationResult {
  valid: boolean;
  errors: string[];
  plan?: Record<string, unknown>;
}

/**
 * Validates a raw LLM-generated plan object.
 * Returns { valid, errors, plan } where plan is the sanitized plan on success.
 */
export function validatePlan(raw: unknown): PlanValidationResult {
  const errors: string[] = [];

  if (!raw || typeof raw !== 'object') {
    return { valid: false, errors: ['Response is not an object'] };
  }

  const plan = raw as Record<string, unknown>;

  // ── Required top-level fields ─────────────────────────────────────────────
  if (typeof plan.name !== 'string' || !plan.name.trim()) {
    errors.push('plan.name must be a non-empty string');
  }
  if (typeof plan.description !== 'string') {
    errors.push('plan.description must be a string');
  }
  if (typeof plan.category !== 'string') {
    errors.push('plan.category must be a string');
  }
  if (typeof plan.defaultVoice !== 'string' || !plan.defaultVoice.trim()) {
    errors.push('plan.defaultVoice must be a non-empty string');
  }
  if (!Array.isArray(plan.steps)) {
    errors.push('plan.steps must be an array');
    return { valid: false, errors };
  }
  if ((plan.steps as unknown[]).length === 0) {
    errors.push('plan.steps must have at least one step');
  }

  // ── Validate each step ────────────────────────────────────────────────────
  (plan.steps as unknown[]).forEach((step, i) => {
    if (!step || typeof step !== 'object') {
      errors.push(`steps[${i}] is not an object`);
      return;
    }
    const s = step as Record<string, unknown>;

    if (!s.type || !VALID_STEP_TYPES.includes(s.type as any)) {
      errors.push(
        `steps[${i}].type must be one of: ${VALID_STEP_TYPES.join(', ')}`,
      );
    }

    switch (s.type) {
      case 'say':
        if (typeof s.text !== 'string' || !s.text.trim()) {
          errors.push(`steps[${i}] (say): text must be a non-empty string`);
        }
        // voice is optional on say steps; if provided it must be a non-empty string.
        if (s.voice !== undefined && (typeof s.voice !== 'string' || !(s.voice as string).trim())) {
          errors.push(`steps[${i}] (say): voice must be a non-empty string when provided`);
        }
        break;
      case 'wait':
        if (typeof s.durationSeconds !== 'number' || s.durationSeconds <= 0) {
          errors.push(`steps[${i}] (wait): durationSeconds must be a positive number`);
        }
        break;
      case 'notify':
        if (typeof s.message !== 'string' || !s.message.trim()) {
          errors.push(`steps[${i}] (notify): message must be a non-empty string`);
        }
        break;
      case 'play':
        if (typeof s.assetKey !== 'string' || !s.assetKey.trim()) {
          errors.push(`steps[${i}] (play): assetKey must be a non-empty string`);
        }
        break;
      case 'repeat':
        if (typeof s.count !== 'number' || s.count < 1) {
          errors.push(`steps[${i}] (repeat): count must be a positive number`);
        }
        if (!Array.isArray(s.steps)) {
          errors.push(`steps[${i}] (repeat): steps must be an array`);
        }
        break;
      case 'stopAudio':
        // No additional fields required
        break;
      case 'count':
        if (typeof s.from !== 'number' || s.from < 1) {
          errors.push(`steps[${i}] (count): from must be a positive number`);
        }
        if (typeof s.to !== 'number' || s.to < 1) {
          errors.push(`steps[${i}] (count): to must be a positive number`);
        }
        if (typeof s.from === 'number' && typeof s.to === 'number') {
          const span = Math.abs(s.from - s.to) + 1;
          if (span > 100) {
            errors.push(`steps[${i}] (count): span must not exceed 100 (got ${span})`);
          }
        }
        if (s.intervalSeconds !== undefined) {
          if (typeof s.intervalSeconds !== 'number' || s.intervalSeconds < 1 || s.intervalSeconds > 20) {
            errors.push(`steps[${i}] (count): intervalSeconds must be 1–20`);
          }
        }
        break;
    }
  });

  return {
    valid: errors.length === 0,
    errors,
    plan: errors.length === 0 ? plan : undefined,
  };
}
