/**
 * Deterministic DSL-to-JSON parser for plan generation.
 *
 * Converts a simple line-by-line DSL produced by Gemini into the structured
 * plan JSON the app expects. Handles all 6 step types:
 *   say, wait, notify, play, stopAudio, repeat
 *
 * Includes auto-repair for common LLM output issues (typos, missing colons,
 * wrong case, close-enough enum values) so we avoid wasting a Gemini retry
 * on fixable formatting problems.
 */

// ── Valid enum values ────────────────────────────────────────────────────────

const VALID_CATEGORIES = [
  'yoga', 'meditation', 'workout', 'cooking', 'routine', 'focus', 'custom',
] as const;

const VALID_VOICES = [
  'af_heart', 'af_bella', 'af_nicole', 'am_adam', 'am_michael', 'am_eric', 'platform',
] as const;

const VALID_ASSETS = [
  'rain', 'forest', 'ocean', 'white_noise', 'tibetan_bowls',
  'bell', 'chime', 'gong',
] as const;

/**
 * Semantic aliases for asset keys LLMs tend to hallucinate.
 * Checked before Levenshtein so semantically-close names always map correctly.
 */
const ASSET_ALIASES: Record<string, string> = {
  // Water / rain
  babbling_brook: 'rain', brook: 'rain', stream: 'rain', river: 'rain',
  waterfall: 'rain', water: 'rain', drizzle: 'rain', rainfall: 'rain',
  // Nature / forest
  birds: 'forest', birdsong: 'forest', nature: 'forest', wind: 'forest',
  breeze: 'forest', leaves: 'forest', jungle: 'forest', trees: 'forest',
  // Ocean / beach
  beach: 'ocean', waves: 'ocean', sea: 'ocean', shore: 'ocean', surf: 'ocean',
  // White noise
  noise: 'white_noise', static: 'white_noise', pink_noise: 'white_noise',
  brown_noise: 'white_noise', fan: 'white_noise',
  // Tibetan bowls
  bowls: 'tibetan_bowls', singing_bowl: 'tibetan_bowls', tibetan: 'tibetan_bowls',
  om: 'tibetan_bowls', drone: 'tibetan_bowls',
  // One-shots
  ding: 'bell', ping: 'bell', bell_sound: 'bell',
  wind_chime: 'chime', windchime: 'chime', chimes: 'chime',
  deep_gong: 'gong', bowl_gong: 'gong', singing_gong: 'gong',
};

// ── Type aliases for fuzzy matching ──────────────────────────────────────────

const TYPE_ALIASES: Record<string, string> = {
  say: 'say', sya: 'say', sai: 'say', speak: 'say', tell: 'say',
  wait: 'wait', wiat: 'wait', pause: 'wait', delay: 'wait', sleep: 'wait',
  notify: 'notify', notification: 'notify', notfy: 'notify', alert: 'notify',
  play: 'play', paly: 'play', sound: 'play',
  stopaudio: 'stopAudio', stop_audio: 'stopAudio', stopsound: 'stopAudio',
  repeat: 'repeat', repat: 'repeat', loop: 'repeat',
  endrepeat: 'endRepeat', end_repeat: 'endRepeat', endloop: 'endRepeat',
};

// ── Public types ─────────────────────────────────────────────────────────────

export interface DslParseResult {
  success: boolean;
  plan?: Record<string, unknown>;
  errors: string[];
  /** Human-readable list of auto-repairs applied (for logging). */
  repaired: string[];
}

// ── Main entry point ─────────────────────────────────────────────────────────

export function parseDslPlan(raw: string): DslParseResult {
  const errors: string[] = [];
  const repaired: string[] = [];

  // Strip markdown fences if Gemini wraps the output
  let text = raw.trim();
  if (text.startsWith('```')) {
    text = text.replace(/^```\w*\n?/, '').replace(/\n?```$/, '').trim();
  }

  // Split header from body at the --- separator
  const sepIdx = text.indexOf('\n---');
  if (sepIdx === -1) {
    errors.push('Missing --- separator between header and steps');
    return { success: false, errors, repaired };
  }

  const headerText = text.substring(0, sepIdx).trim();
  const bodyText = text.substring(sepIdx + 4).trim(); // skip \n---

  // ── Parse header ───────────────────────────────────────────────────────────
  const header = parseHeader(headerText, errors, repaired);
  if (!header) return { success: false, errors, repaired };

  // ── Parse step lines ───────────────────────────────────────────────────────
  const bodyLines = bodyText.split('\n').filter((l) => l.trim() !== '');
  const steps = parseStepLines(bodyLines, errors, repaired);

  if (steps.length === 0 && errors.length === 0) {
    errors.push('No valid steps found');
  }

  if (errors.length > 0) {
    return { success: false, errors, repaired };
  }

  return {
    success: true,
    plan: {
      name: header.name,
      description: header.description,
      category: header.category,
      defaultVoice: header.voice,
      steps,
    },
    errors: [],
    repaired,
  };
}

// ── Header parsing ───────────────────────────────────────────────────────────

function parseHeader(
  text: string,
  errors: string[],
  repaired: string[],
): { name: string; description: string; category: string; voice: string } | null {
  const map: Record<string, string> = {};

  for (const line of text.split('\n')) {
    const colonIdx = line.indexOf(':');
    if (colonIdx === -1) continue;
    const key = line.substring(0, colonIdx).trim().toLowerCase();
    const value = line.substring(colonIdx + 1).trim();
    map[key] = value;
  }

  const name = map['name'] ?? '';
  const description = map['description'] ?? map['desc'] ?? '';
  const rawCategory = (map['category'] ?? map['cat'] ?? '').toLowerCase();
  const rawVoice = (map['voice'] ?? map['defaultvoice'] ?? map['default_voice'] ?? '').toLowerCase();

  if (!name) errors.push('Missing Name in header');
  if (!description) errors.push('Missing Description in header');

  // Auto-fix category
  let category = rawCategory;
  if (!VALID_CATEGORIES.includes(category as any)) {
    const closest = findClosest(category, VALID_CATEGORIES as unknown as string[]);
    if (closest) {
      repaired.push(`Category "${rawCategory}" -> "${closest}"`);
      category = closest;
    } else {
      category = 'custom';
      repaired.push(`Category "${rawCategory}" -> "custom" (fallback)`);
    }
  }

  // Auto-fix voice
  let voice = rawVoice;
  if (!VALID_VOICES.includes(voice as any)) {
    const closest = findClosest(voice, VALID_VOICES as unknown as string[]);
    if (closest) {
      repaired.push(`Voice "${rawVoice}" -> "${closest}"`);
      voice = closest;
    } else {
      voice = 'af_heart';
      repaired.push(`Voice "${rawVoice}" -> "af_heart" (fallback)`);
    }
  }

  if (errors.length > 0) return null;

  return { name, description, category, voice };
}

// ── Step-line parsing ────────────────────────────────────────────────────────

function parseStepLines(
  lines: string[],
  errors: string[],
  repaired: string[],
): Record<string, unknown>[] {
  const rootSteps: Record<string, unknown>[] = [];
  // Stack tracks nested repeat blocks; each entry is the steps array of the
  // innermost open repeat.
  const repeatStack: Record<string, unknown>[][] = [];
  let target = rootSteps;

  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim();
    if (!trimmed) continue;

    const { type, value } = classifyLine(trimmed, repaired, i);

    if (!type) {
      errors.push(`Line ${i + 1}: Cannot parse "${trimmed}"`);
      continue;
    }

    // Handle EndRepeat
    if (type === 'endRepeat') {
      if (repeatStack.length === 0) {
        repaired.push(`Line ${i + 1}: Orphan EndRepeat ignored`);
        continue;
      }
      repeatStack.pop();
      target = repeatStack.length > 0 ? repeatStack[repeatStack.length - 1] : rootSteps;
      continue;
    }

    const step = buildStep(type, value, i, errors, repaired);
    if (!step) continue;

    target.push(step);

    // If this step opens a repeat block, push its inner steps array
    if (type === 'repeat') {
      const inner = step['steps'] as Record<string, unknown>[];
      repeatStack.push(inner);
      target = inner;
    }
  }

  // Auto-close any unclosed repeat blocks
  if (repeatStack.length > 0) {
    repaired.push(`Auto-closed ${repeatStack.length} unclosed Repeat block(s)`);
  }

  return rootSteps;
}

// ── Line classification ──────────────────────────────────────────────────────

function classifyLine(
  line: string,
  repaired: string[],
  lineIdx: number,
): { type: string; value: string } {
  // Standalone keywords (no colon required)
  const compressed = line.toLowerCase().replace(/[\s_-]/g, '');
  if (compressed === 'stopaudio' || compressed === 'stopsound') {
    return { type: 'stopAudio', value: '' };
  }
  if (compressed === 'endrepeat' || compressed === 'endloop') {
    return { type: 'endRepeat', value: '' };
  }

  // Voice-override syntax: Say [voice_id]: text
  const voiceOverride = line.match(/^(\w+)\s*\[([^\]]+)]\s*:\s*(.*)$/i);
  if (voiceOverride) {
    const rawType = voiceOverride[1].toLowerCase();
    const resolved = TYPE_ALIASES[rawType];
    if (resolved === 'say') {
      return { type: 'say', value: `[${voiceOverride[2].trim()}] ${voiceOverride[3].trim()}` };
    }
  }

  // Standard "Type: value"
  const colonIdx = line.indexOf(':');
  if (colonIdx !== -1) {
    const rawType = line.substring(0, colonIdx).trim().toLowerCase();
    const value = line.substring(colonIdx + 1).trim();
    const resolved = TYPE_ALIASES[rawType];
    if (resolved) {
      if (resolved !== rawType && rawType !== resolved.toLowerCase()) {
        repaired.push(`Line ${lineIdx + 1}: "${rawType}" -> "${resolved}"`);
      }
      return { type: resolved, value };
    }
  }

  // Fallback: "Type value" (missing colon)
  const parts = line.match(/^(\w+)\s+(.+)$/);
  if (parts) {
    const rawType = parts[1].toLowerCase();
    const resolved = TYPE_ALIASES[rawType];
    if (resolved) {
      repaired.push(`Line ${lineIdx + 1}: "${line}" -> added missing colon`);
      return { type: resolved, value: parts[2].trim() };
    }
  }

  return { type: '', value: '' };
}

// ── Step builders ────────────────────────────────────────────────────────────

function buildStep(
  type: string,
  value: string,
  lineIdx: number,
  errors: string[],
  repaired: string[],
): Record<string, unknown> | null {
  switch (type) {
    case 'say': {
      // Check for inline voice override: [voice_id] text
      const vm = value.match(/^\[([^\]]+)]\s*(.+)$/);
      if (vm) {
        const text = vm[2].trim();
        if (!text) { errors.push(`Line ${lineIdx + 1}: Say step has no text`); return null; }
        let voice = vm[1].trim().toLowerCase();
        if (!VALID_VOICES.includes(voice as any)) {
          const fix = findClosest(voice, VALID_VOICES as unknown as string[]);
          if (fix) { repaired.push(`Line ${lineIdx + 1}: voice "${voice}" -> "${fix}"`); voice = fix; }
        }
        return { type: 'say', text, voice };
      }
      if (!value) { errors.push(`Line ${lineIdx + 1}: Say step has no text`); return null; }
      return { type: 'say', text: value };
    }

    case 'wait': {
      const seconds = parseDuration(value);
      if (seconds === null || seconds < 1) {
        errors.push(`Line ${lineIdx + 1}: Invalid wait duration "${value}"`);
        return null;
      }
      return { type: 'wait', durationSeconds: seconds };
    }

    case 'notify': {
      if (!value) { errors.push(`Line ${lineIdx + 1}: Notify step has no message`); return null; }
      return { type: 'notify', message: value };
    }

    case 'play': {
      const key = value.toLowerCase().replace(/[\s-]+/g, '_').trim();
      if (VALID_ASSETS.includes(key as any)) {
        return { type: 'play', assetKey: key };
      }
      // Semantic alias lookup (handles babbling_brook → rain, waves → ocean, etc.)
      const aliased = ASSET_ALIASES[key];
      if (aliased) {
        repaired.push(`Line ${lineIdx + 1}: asset "${value}" -> "${aliased}" (semantic match)`);
        return { type: 'play', assetKey: aliased };
      }
      // Fuzzy Levenshtein match as last resort
      const closest = findClosest(key, VALID_ASSETS as unknown as string[]);
      if (closest) {
        repaired.push(`Line ${lineIdx + 1}: asset "${value}" -> "${closest}" (fuzzy match)`);
        return { type: 'play', assetKey: closest };
      }
      // Unknown asset — drop the step rather than failing the whole phase
      repaired.push(`Line ${lineIdx + 1}: asset "${value}" unknown — step dropped`);
      return null;
    }

    case 'stopAudio':
      return { type: 'stopAudio' };

    case 'repeat': {
      const count = parseInt(value, 10);
      if (isNaN(count) || count < 1) {
        errors.push(`Line ${lineIdx + 1}: Invalid repeat count "${value}"`);
        return null;
      }
      return { type: 'repeat', count, steps: [] };
    }

    default:
      return null;
  }
}

// ── Duration parsing (supports 30, 30s, 2m, 1m30s) ──────────────────────────

function parseDuration(raw: string): number | null {
  const s = raw.trim().toLowerCase();
  const ms = s.match(/^(\d+)\s*m\s*(\d+)\s*s?$/);
  if (ms) return parseInt(ms[1]) * 60 + parseInt(ms[2]);
  const m = s.match(/^(\d+)\s*m$/);
  if (m) return parseInt(m[1]) * 60;
  const sec = s.match(/^(\d+)\s*s?$/);
  if (sec) return parseInt(sec[1]);
  return null;
}

// ── Fuzzy enum matching (Levenshtein) ────────────────────────────────────────

function findClosest(input: string, options: string[]): string | null {
  if (!input) return null;
  if (options.includes(input)) return input;

  let best = '';
  let bestDist = Infinity;
  for (const opt of options) {
    const d = levenshtein(input, opt);
    if (d < bestDist) { bestDist = d; best = opt; }
  }
  return bestDist <= 3 ? best : null;
}

function levenshtein(a: string, b: string): number {
  const m = a.length, n = b.length;
  const dp: number[][] = Array.from({ length: m + 1 }, () => Array(n + 1).fill(0));
  for (let i = 0; i <= m; i++) dp[i][0] = i;
  for (let j = 0; j <= n; j++) dp[0][j] = j;
  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      dp[i][j] = a[i - 1] === b[j - 1]
        ? dp[i - 1][j - 1]
        : 1 + Math.min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]);
    }
  }
  return dp[m][n];
}
