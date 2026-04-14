import {
  Injectable,
  Logger,
  UnprocessableEntityException,
  ServiceUnavailableException,
  BadGatewayException,
} from '@nestjs/common';
import { parseDslPlan } from './parsers/dsl.parser';
import {
  buildPhase1SystemPrompt,
  buildPhase1Schema,
  PROVIDER_DEFAULT_VOICES,
  type Phase1Requirements,
  type PlanPhase,
} from './prompts/phase1.prompt';
import { PHASE2_SYSTEM_PROMPT, buildPhase2PhasePrompt } from './prompts/phase2.prompt';
import { DatabaseService, type PlanRecord, type PlanSummaryRecord, type SavePlanResult } from '../database/database.service';
import { TtsPregenService } from '../tts/tts-pregen.service';
import { SavePlanDto } from './dto/save-plan.dto';

// ── Constants ────────────────────────────────────────────────────────────────

const GEMINI_GENERATE_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

const MAX_DURATION_MINUTES = 240; // 4-hour hard cap

// ── Backend selection ─────────────────────────────────────────────────────────
// llmProvider()=gemini → use Gemini API (requires GEMINI_API_KEY).
// Default → Ollama local server.
// OLLAMA_URL overrides the Ollama base URL (default: http://localhost:11434).
// ollamaModel() overrides the model (default: gemma4:e4b).
// Read at runtime (not module load) so tests can override process.env.
function llmProvider(): string { return process.env.LLM_PROVIDER ?? 'ollama'; }
function ollamaBaseUrl(): string { return process.env.OLLAMA_URL ?? 'http://localhost:11434'; }
function ollamaModel(): string { return process.env.OLLAMA_MODEL ?? 'gemma4:e4b'; }

@Injectable()
export class PlansService {
  private readonly logger = new Logger(PlansService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly ttsPregen: TtsPregenService,
  ) {}

  async generatePlan(
    prompt: string,
    userId: string,
    language?: string,
  ): Promise<{ plan: Record<string, unknown> }> {
    // Resolve backend — Gemini requires an API key; Ollama runs locally.
    let geminiApiKey: string | undefined;
    if (llmProvider() === 'gemini') {
      geminiApiKey = process.env.GEMINI_API_KEY;
      if (!geminiApiKey) {
        throw new ServiceUnavailableException(
          'GEMINI_API_KEY is not set — set llmProvider()=ollama to use local Ollama instead',
        );
      }
      this.logger.log(`Backend: Gemini 2.5 Flash`);
    } else {
      this.logger.log(`Backend: Ollama ${ollamaModel()} @ ${ollamaBaseUrl()}`);
    }

    const ttsProvider = process.env.DEFAULT_TTS_PROVIDER ?? 'kokoro';

    // ── Phase 1: Extract requirements + divide into phases ─────────────────
    this.logger.log(`Phase 1: Extracting requirements for user ${userId} (ttsProvider=${ttsProvider})`);
    const requirements = await this.extractRequirements(geminiApiKey, prompt, ttsProvider);

    // Override language if the user explicitly selected one in the UI.
    if (language) {
      this.logger.log(`Language override: "${requirements.language}" → "${language}"`);
      requirements.language = language;
    }

    // Collapse Hinglish → Hindi (Kokoro can't handle mixed-script, Gemini TTS can handle Hindi)
    if (/hinglish/i.test(requirements.language)) {
      this.logger.log(`Language "${requirements.language}" collapsed to Hindi`);
      requirements.language = 'Hindi';
    }

    if (requirements.durationMinutes > MAX_DURATION_MINUTES) {
      this.logger.log(`Capping duration from ${requirements.durationMinutes}min to ${MAX_DURATION_MINUTES}min`);
      requirements.durationMinutes = MAX_DURATION_MINUTES;
      // Re-scale phases proportionally
      requirements.phases = scalePhaseDurations(requirements.phases, MAX_DURATION_MINUTES);
    }

    this.logger.debug(`Phase 1 output:\n${JSON.stringify(requirements, null, 2)}`);
    this.logger.log(
      `Phase 1 complete: "${requirements.title}" — ${requirements.phases.length} phases, ${requirements.durationMinutes}min total`,
    );

    // ── Phase 2: Generate DSL for each phase in parallel ───────────────────
    this.logger.log(`Phase 2: Generating ${requirements.phases.length} phases in parallel`);

    const phaseResults = await Promise.all(
      requirements.phases.map((phase, i) =>
        this.generatePhase(geminiApiKey, requirements, phase, i, requirements.phases.length),
      ),
    );

    // ── Phase 3: Combine all phases into one plan ──────────────────────────
    const plan = combinePhasePlans(requirements, phaseResults);

    this.logger.debug(`Combined plan:\n${JSON.stringify(plan, null, 2)}`);
    this.logger.log(
      `Plan generated: ${plan.steps.length} steps across ${requirements.phases.length} phases`,
    );

    return { plan };
  }

  // ── Plan persistence ───────────────────────────────────────────────────────

  /**
   * Persist a plan to the database.
   * userId is ALWAYS derived from the JWT by the controller — never from the
   * request body — to prevent IDOR attacks.
   */
  async savePlan(userId: string, dto: SavePlanDto): Promise<SavePlanResult> {
    this.logger.log(
      `savePlan — userId=${userId}, planId=${dto.planId ?? 'NEW'}, name="${dto.name}"`,
    );
    return this.db.savePlan(userId, dto.name, dto.planJson, dto.planId);
  }

  /**
   * Return all plan summaries for the authenticated user (no plan_json body,
   * just metadata for listing). userId from JWT only.
   */
  async listPlans(userId: string): Promise<{ plans: PlanSummaryRecord[] }> {
    this.logger.log(`listPlans — userId=${userId}`);
    const planList = await this.db.listPlans(userId);
    return { plans: planList };
  }

  /**
   * Fetch a single plan by ID for the authenticated user (IDOR-safe).
   * Returns null if not found or not owned by userId.
   */
  async getPlanById(userId: string, planId: string): Promise<PlanRecord | null> {
    this.logger.log(`getPlanById — userId=${userId}, planId=${planId}`);
    return this.db.getPlanById(planId, userId);
  }

  /**
   * Delete a plan for the authenticated user (IDOR-safe).
   * Throws NotFoundException if not found or not owned by userId.
   */
  async deletePlan(userId: string, planId: string): Promise<void> {
    this.logger.log(`deletePlan — userId=${userId}, planId=${planId}`);
    return this.db.deletePlan(planId, userId);
  }

  /**
   * Activate a plan for the authenticated user.
   * For studio voice quality, triggers TTS pre-generation after activation.
   */
  async activatePlan(
    userId: string,
    planId: string,
    voiceQuality: string,
    voice?: string,
    locale?: string,
    speechRate?: string,
  ): Promise<void> {
    this.logger.log(`activatePlan — userId=${userId}, planId=${planId}, voiceQuality=${voiceQuality}, voice=${voice}, locale=${locale}, speechRate=${speechRate}`);
    await this.db.activatePlan(planId, userId, voiceQuality);

    if (voiceQuality === 'studio') {
      try {
        const plan = await this.db.getPlanById(planId, userId);
        if (!plan) return;

        const effectiveProvider = process.env.DEFAULT_TTS_PROVIDER ?? 'kokoro';
        const providerDefaultVoice = PROVIDER_DEFAULT_VOICES[effectiveProvider] ?? PROVIDER_DEFAULT_VOICES.kokoro;

        // Use client-provided voice, falling back to plan default, then provider default.
        let effectiveVoice = voice ?? providerDefaultVoice;
        if (!voice) {
          try {
            const parsed = JSON.parse(plan.planJson);
            if (parsed.defaultVoice) effectiveVoice = parsed.defaultVoice;
          } catch { /* use provider default voice */ }
        }

        const effectiveLocale = locale ?? 'enIN';
        const effectiveSpeechRate = speechRate ?? '1.0';

        await this.ttsPregen.startPregen(
          planId,
          plan.planJson,
          effectiveVoice,
          effectiveLocale,
          effectiveProvider,
          effectiveSpeechRate,
        );
      } catch (err) {
        this.logger.error(
          `TTS pre-generation failed for planId=${planId}: ${err instanceof Error ? err.message : err}`,
        );
        // Reset status so the UI doesn't show a spinner forever.
        await this.db.setTtsStatus(planId, 'failed', 0, 0);
      }
    }
  }

  // ── Phase generation (with 1 retry per phase) ──────────────────────────────

  private async generatePhase(
    geminiApiKey: string | undefined,
    requirements: Phase1Requirements,
    phase: PlanPhase,
    index: number,
    total: number,
  ): Promise<{ phaseName: string; steps: Record<string, unknown>[] }> {
    const label = `Phase 2.${index + 1} "${phase.name}"`;

    for (let attempt = 0; attempt <= 1; attempt++) {
      if (attempt > 0) this.logger.log(`Retrying ${label}`);

      const userPrompt = buildPhase2PhasePrompt(requirements, phase, index, total);
      const dslText = geminiApiKey
        ? await this.geminiText(geminiApiKey, PHASE2_SYSTEM_PROMPT, userPrompt, `Phase 2 "${phase.name}"`, 90_000)
        : await this.ollamaText(PHASE2_SYSTEM_PROMPT, userPrompt, `Phase 2 "${phase.name}"`);

      this.logger.debug(`${label} raw DSL:\n${dslText}`);

      const result = parseDslPlan(dslText);

      if (result.repaired.length > 0) {
        this.logger.log(`${label} auto-repairs: ${result.repaired.join('; ')}`);
      }

      if (result.success && result.plan) {
        const steps = result.plan.steps as Record<string, unknown>[];
        this.logger.log(`${label} parsed: ${steps.length} steps`);
        return { phaseName: phase.name, steps };
      }

      this.logger.warn(`${label} parse failed: ${result.errors.join('; ')}`);
    }

    throw new UnprocessableEntityException(
      `Failed to generate phase "${phase.name}" after retries`,
    );
  }

  // ── Phase 1: Requirements extraction ───────────────────────────────────────

  private async extractRequirements(
    geminiApiKey: string | undefined,
    userPrompt: string,
    ttsProvider: string,
  ): Promise<Phase1Requirements> {
    const systemPrompt = buildPhase1SystemPrompt(ttsProvider);
    const schema = buildPhase1Schema(ttsProvider);
    let text: string;

    if (geminiApiKey) {
      const body = JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: `${systemPrompt}\n\nUser request: ${userPrompt}` }] }],
        generationConfig: {
          responseMimeType: 'application/json',
          responseSchema: schema,
          temperature: 0.3,
          maxOutputTokens: 2048,
        },
      });
      const response = await this.callGeminiRaw(geminiApiKey, body, 'Phase 1 (requirements)');
      text = this.extractGeminiText(response, 'Phase 1');
    } else {
      text = await this.ollamaJson(systemPrompt, userPrompt, schema, 'Phase 1 (requirements)');
    }

    try {
      const parsed = JSON.parse(text) as Phase1Requirements;
      if (!parsed.title || !parsed.category || !parsed.durationMinutes || !parsed.phases?.length || !parsed.language) {
        throw new Error('Missing required fields in Phase 1 output');
      }
      return parsed;
    } catch (err) {
      this.logger.error(
        `Phase 1 failed — ${(err as Error).message}. Response (first 400 chars): ${text.slice(0, 400)}`,
      );
      throw new BadGatewayException('Failed to extract plan requirements');
    }
  }

  // ── Gemini helpers ─────────────────────────────────────────────────────────

  private async geminiText(
    apiKey: string,
    systemPrompt: string,
    userPrompt: string,
    label: string,
    timeoutMs = 30_000,
  ): Promise<string> {
    const body = JSON.stringify({
      contents: [{ role: 'user', parts: [{ text: `${systemPrompt}\n\n${userPrompt}` }] }],
      generationConfig: { temperature: 0.7, maxOutputTokens: 8192 },
    });
    const response = await this.callGeminiRaw(apiKey, body, label, timeoutMs);
    return this.extractGeminiText(response, label);
  }

  private async callGeminiRaw(
    apiKey: string,
    requestBody: string,
    label: string,
    timeoutMs = 30_000,
  ): Promise<unknown> {
    this.logger.log(`Calling Gemini 2.5 Flash — ${label}`);
    const response = await fetch(GEMINI_GENERATE_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
      body: requestBody,
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (!response.ok) {
      const errorText = await response.text().catch(() => '');
      this.logger.error(`Gemini ${label} error ${response.status}: ${errorText}`);
      throw new BadGatewayException(`Gemini API error ${response.status}`);
    }
    return response.json();
  }

  private extractGeminiText(data: unknown, label: string): string {
    const resp = data as { candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }> };
    const text = resp?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      this.logger.error(`Gemini ${label} returned empty content`);
      throw new BadGatewayException(`Gemini returned empty response (${label})`);
    }
    return text;
  }

  // ── Ollama helpers ─────────────────────────────────────────────────────────

  /** Phase 1: structured JSON via Ollama's `format` parameter. */
  private async ollamaJson(
    systemPrompt: string,
    userPrompt: string,
    schema: object,
    label: string,
  ): Promise<string> {
    return this.callOllama(systemPrompt, userPrompt, label, schema, 60_000);
  }

  /** Phase 2: plain text (DSL) via Ollama. */
  private async ollamaText(
    systemPrompt: string,
    userPrompt: string,
    label: string,
  ): Promise<string> {
    return this.callOllama(systemPrompt, userPrompt, label, undefined, 120_000);
  }

  private async callOllama(
    systemPrompt: string,
    userPrompt: string,
    label: string,
    format?: object,
    timeoutMs = 60_000,
  ): Promise<string> {
    this.logger.log(`Calling Ollama ${ollamaModel()} — ${label}`);

    const body: Record<string, unknown> = {
      model: ollamaModel(),
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      stream: false,
      options: { temperature: llmProvider() === 'ollama' ? 0.7 : 0.3 },
    };
    if (format) body.format = format;

    const response = await fetch(`${ollamaBaseUrl()}/api/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(timeoutMs),
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => '');
      this.logger.error(`Ollama ${label} error ${response.status}: ${errorText}`);
      throw new BadGatewayException(`Ollama API error ${response.status}`);
    }

    const data = (await response.json()) as { message?: { content?: string }; error?: string };

    if (data.error) {
      this.logger.error(`Ollama ${label} returned error: ${data.error}`);
      throw new BadGatewayException(`Ollama error: ${data.error}`);
    }

    const text = data?.message?.content;
    if (!text) {
      this.logger.error(`Ollama ${label} returned empty content`);
      throw new BadGatewayException(`Ollama returned empty response (${label})`);
    }

    return text;
  }

}

// ── Pure helpers (no logger needed) ──────────────────────────────────────────

/**
 * Scales phase durations proportionally to fit a new total.
 * Ensures the sum always equals targetTotal by adjusting the last phase.
 */
function scalePhaseDurations(phases: PlanPhase[], targetTotal: number): PlanPhase[] {
  const currentTotal = phases.reduce((sum, p) => sum + p.durationMinutes, 0);
  if (currentTotal === 0) return phases;

  const ratio = targetTotal / currentTotal;
  let remaining = targetTotal;

  return phases.map((phase, i) => {
    if (i === phases.length - 1) {
      return { ...phase, durationMinutes: Math.max(1, remaining) };
    }
    const scaled = Math.max(1, Math.round(phase.durationMinutes * ratio));
    remaining -= scaled;
    return { ...phase, durationMinutes: scaled };
  });
}

/**
 * Combines parsed phase steps into a single plan object.
 * Inserts a Notify separator between phases.
 */
function combinePhasePlans(
  requirements: Phase1Requirements,
  phases: Array<{ phaseName: string; steps: Record<string, unknown>[] }>,
): { name: string; description: string; category: string; defaultVoice: string; steps: Record<string, unknown>[] } {
  const allSteps: Record<string, unknown>[] = [];

  for (let i = 0; i < phases.length; i++) {
    if (i > 0) {
      allSteps.push({ type: 'notify', message: phases[i].phaseName });
    }
    allSteps.push(...phases[i].steps);
  }

  return {
    name: requirements.title,
    description: requirements.description,
    category: requirements.category,
    defaultVoice: requirements.voice,
    steps: allSteps,
  };
}
