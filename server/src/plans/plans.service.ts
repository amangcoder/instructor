import {
  Injectable,
  Logger,
  UnprocessableEntityException,
  ServiceUnavailableException,
  BadGatewayException,
  ForbiddenException,
  NotFoundException,
  Optional,
  Inject,
} from '@nestjs/common';
import type { AppConfig } from '../config/app-config.interface';
import { parseDslPlan } from './parsers/dsl.parser';
import {
  buildPhase1SystemPrompt,
  buildPhase1Schema,
  PROVIDER_DEFAULT_VOICES,
  type Phase1Requirements,
  type PlanPhase,
} from './prompts/phase1.prompt';
import { PHASE2_SYSTEM_PROMPT, buildPhase2PhasePrompt } from './prompts/phase2.prompt';
import {
  TRIAGE_SCHEMA,
  TRIAGE_SYSTEM_PROMPT,
  type TriageResult,
} from './prompts/triage.prompt';
import { DatabaseService, type PlanRecord, type PlanSummaryRecord, type SavePlanResult } from '../database/database.service';
import { PlanRepository } from '../database/repositories/plan.repository';
import { TtsBatchPregenService } from '../tts/tts-batch-pregen.service';
import { SavePlanDto } from './dto/save-plan.dto';
import { plans } from '../database/schema';
import { eq, sql, and, isNull } from 'drizzle-orm';

// ── Constants ────────────────────────────────────────────────────────────────

const GEMINI_GENERATE_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

const MAX_DURATION_MINUTES = 240; // 4-hour hard cap

/**
 * Apply admin step edits in-place. Walks the step tree (descending into
 * `repeat.children`) so deeply-nested say-steps are also addressable by id.
 * Fields are only written when the edit specifies them and the target step's
 * runtime type accepts that field.
 */
function applyStepEdits(
  steps: Array<Record<string, unknown>>,
  editsById: Map<
    string,
    {
      id: string;
      text?: string;
      voiceId?: string | null;
      estimatedDuration?: number | null;
      duration?: number;
    }
  >,
): void {
  for (const step of steps) {
    const stepId = typeof step.id === 'string' ? step.id : null;
    const edit = stepId ? editsById.get(stepId) : undefined;
    if (edit) {
      const runtimeType = step.runtimeType;
      if (runtimeType === 'say') {
        if (edit.text !== undefined) step.text = edit.text;
        if (edit.voiceId !== undefined) step.voiceId = edit.voiceId;
        if (edit.estimatedDuration !== undefined) step.estimatedDuration = edit.estimatedDuration;
      } else if (runtimeType === 'wait') {
        if (edit.duration !== undefined) step.duration = edit.duration;
      }
    }
    if (step.runtimeType === 'repeat' && Array.isArray(step.children)) {
      applyStepEdits(step.children as Array<Record<string, unknown>>, editsById);
    }
  }
}

@Injectable()
export class PlansService {
  private readonly logger = new Logger(PlansService.name);
  private readonly plans: PlanRepository | DatabaseService;

  constructor(
    private readonly db: DatabaseService,
    private readonly ttsBatchPregen: TtsBatchPregenService,
    @Optional() @Inject('APP_CONFIG') private readonly config?: AppConfig,
    @Optional() @Inject(PlanRepository) planRepo?: PlanRepository,
  ) {
    // Prefer PlanRepository when available; fall back to DatabaseService for
    // backward compatibility with tests that only provide DatabaseService.
    this.plans = planRepo ?? db;
  }

  private get llmProvider(): string { return this.config?.llmProvider ?? process.env.LLM_PROVIDER ?? 'ollama'; }
  private get ollamaBaseUrl(): string { return this.config?.ollamaUrl ?? process.env.OLLAMA_URL ?? 'http://localhost:11434'; }
  private get ollamaModel(): string { return this.config?.ollamaModel ?? process.env.OLLAMA_MODEL ?? 'gemma4:e4b'; }
  private get geminiApiKey(): string { return this.config?.geminiApiKey ?? process.env.GEMINI_API_KEY ?? ''; }
  private get defaultTtsProvider(): string { return this.config?.defaultTtsProvider ?? process.env.DEFAULT_TTS_PROVIDER ?? 'kokoro'; }

  async generatePlan(
    prompt: string,
    userId: string,
    language?: string,
  ): Promise<{ plan: Record<string, unknown> }> {
    // Resolve backend — Gemini requires an API key; Ollama runs locally.
    let resolvedGeminiKey: string | undefined;
    if (this.llmProvider === 'gemini') {
      resolvedGeminiKey = this.geminiApiKey || undefined;
      if (!resolvedGeminiKey) {
        throw new ServiceUnavailableException(
          'GEMINI_API_KEY is not set — set LLM_PROVIDER=ollama to use local Ollama instead',
        );
      }
      this.logger.log(`Backend: Gemini 2.5 Flash`);
    } else {
      this.logger.log(`Backend: Ollama ${this.ollamaModel} @ ${this.ollamaBaseUrl}`);
    }

    const ttsProvider = this.defaultTtsProvider;

    // ── Triage: cheap feasibility gate before any expensive generation ─────
    // Fail-open: if triage itself errors, log and proceed (don't block legit
    // users on a flaky triage call). The 4-hour duration cap below is the
    // structural backstop.
    const triage = await this.triagePrompt(resolvedGeminiKey, prompt);
    if (triage && !triage.feasible) {
      this.logger.warn(
        `Triage rejected prompt for user ${userId} — flags=${triage.flags.join(',')} reason="${triage.reason}"`,
      );
      throw new UnprocessableEntityException(triage.reason);
    }
    if (triage) {
      this.logger.log(
        `Triage passed — complexity=${triage.complexity} flags=${triage.flags.join(',') || 'none'}`,
      );
    }

    // ── Phase 1: Extract requirements + divide into phases ─────────────────
    this.logger.log(`Phase 1: Extracting requirements for user ${userId} (ttsProvider=${ttsProvider})`);
    const requirements = await this.extractRequirements(resolvedGeminiKey, prompt, ttsProvider);

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
        this.generatePhase(resolvedGeminiKey, requirements, phase, i, requirements.phases.length),
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
    return this.plans.savePlan(userId, dto.name, dto.planJson, dto.planId);
  }

  /**
   * Return all plan summaries for the authenticated user (no plan_json body,
   * just metadata for listing). userId from JWT only.
   */
  async listPlans(userId: string): Promise<{ plans: PlanSummaryRecord[] }> {
    this.logger.log(`listPlans — userId=${userId}`);
    const planList = await this.plans.listPlans(userId);
    return { plans: planList };
  }

  /**
   * Fetch a single plan by ID for the authenticated user (IDOR-safe).
   * Returns null if not found or not owned by userId.
   */
  async getPlanById(userId: string, planId: string): Promise<PlanRecord | null> {
    this.logger.log(`getPlanById — userId=${userId}, planId=${planId}`);
    return this.plans.getPlanById(planId, userId);
  }

  /**
   * Delete a plan for the authenticated user (IDOR-safe).
   * Throws NotFoundException if not found or not owned by userId.
   */
  async deletePlan(userId: string, planId: string): Promise<void> {
    this.logger.log(`deletePlan — userId=${userId}, planId=${planId}`);
    return this.plans.deletePlan(planId, userId);
  }

  /**
   * Activate a plan for the authenticated user.
   * For studio voice quality, triggers TTS pre-generation after activation.
   *
   * @param speechRate Speech rate from API (string, e.g. '1.0').
   *                   Forwarded to TtsBatchPregenService which accepts string | number.
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
    await this.plans.activatePlan(planId, userId, voiceQuality);

    if (voiceQuality === 'studio') {
      try {
        const plan = await this.plans.getPlanById(planId, userId);
        if (!plan) return;

        const effectiveProvider = this.defaultTtsProvider;
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

        await this.ttsBatchPregen.startBatchPregen(
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
        await this.plans.setTtsStatus(planId, 'failed', 0, 0);
      }
    }
  }

  // ── Sub-plan tree retrieval (recursive CTE, depth 3) ─────────────────────

  /**
   * Fetch a plan with its recursive sub-plan tree to depth 3.
   * Includes IDOR check: private plans can only be accessed by their owner.
   *
   * @throws NotFoundException if plan not found
   * @throws ForbiddenException if private plan accessed by non-owner
   */
  async getPlanTree(userId: string, planId: string): Promise<PlanTreeNode> {
    const db = this.db.getDb();

    // 1. Fetch the root plan first to check ownership / visibility
    const rootRows = await this.db.withRetry(() =>
      db
        .select()
        .from(plans)
        .where(eq(plans.id, planId))
        .limit(1),
    );

    if (rootRows.length === 0) {
      throw new NotFoundException(`Plan ${planId} not found`);
    }

    const root = rootRows[0];

    // IDOR check: private plans are only accessible to their owner
    if (root.visibility === 'private' && root.ownerUserId !== userId) {
      throw new ForbiddenException('You do not have access to this plan');
    }

    // 2. Recursive CTE bounded at depth 3
    const treeRows = await this.db.withRetry(() =>
      db.execute(sql`
        WITH RECURSIVE plan_tree AS (
          SELECT id, name, parent_plan_id, position, visibility, is_published, owner_user_id, 1 AS depth
          FROM plans
          WHERE id = ${planId}
          UNION ALL
          SELECT p.id, p.name, p.parent_plan_id, p.position, p.visibility, p.is_published, p.owner_user_id, pt.depth + 1
          FROM plans p
          INNER JOIN plan_tree pt ON p.parent_plan_id = pt.id
          WHERE pt.depth < 3
        )
        SELECT id, name, parent_plan_id, position, visibility, is_published, owner_user_id, depth
        FROM plan_tree
        ORDER BY depth ASC, position ASC
      `),
    );

    // 3. Build nested tree structure
    const rows = treeRows.rows as Array<{
      id: string;
      name: string;
      parent_plan_id: string | null;
      position: number;
      visibility: string;
      is_published: boolean;
      owner_user_id: string | null;
      depth: number;
    }>;

    return this.buildTree(rows, planId);
  }

  /** Build a nested tree structure from flat CTE rows. */
  private buildTree(
    rows: Array<{
      id: string;
      name: string;
      parent_plan_id: string | null;
      position: number;
      visibility: string;
      is_published: boolean;
      owner_user_id: string | null;
      depth: number;
    }>,
    rootId: string,
  ): PlanTreeNode {
    const nodeMap = new Map<string, PlanTreeNode>();

    for (const row of rows) {
      nodeMap.set(row.id, {
        id: row.id,
        name: row.name,
        parentPlanId: row.parent_plan_id,
        position: row.position,
        visibility: row.visibility,
        isPublished: row.is_published,
        depth: row.depth,
        children: [],
      });
    }

    for (const row of rows) {
      if (row.parent_plan_id && nodeMap.has(row.parent_plan_id)) {
        nodeMap.get(row.parent_plan_id)!.children.push(nodeMap.get(row.id)!);
      }
    }

    return nodeMap.get(rootId)!;
  }

  // ── User-authored plan creation ───────────────────────────────────────────

  /**
   * Create a new user-authored plan with visibility='private'.
   * owner_user_id is always derived from the JWT (req.user.sub).
   */
  async createUserPlan(
    userId: string,
    title: string,
    steps: string,
    description?: string,
    seriesId?: string,
  ): Promise<{ planId: string }> {
    const db = this.db.getDb();
    const now = new Date();

    const rows = await this.db.withRetry(() =>
      db
        .insert(plans)
        .values({
          userId,
          name: title,
          planJson: steps,
          visibility: 'private',
          ownerUserId: userId,
          seriesId: seriesId ?? null,
          isActive: false,
          ttsStatus: 'none',
          ttsTotal: 0,
          ttsCompleted: 0,
          voiceQuality: 'standard',
          createdAt: now,
          updatedAt: now,
        })
        .returning({ id: plans.id }),
    );

    const planId = rows[0].id;
    this.logger.log(`User plan created: planId=${planId}, userId=${userId}, visibility=private`);
    return { planId };
  }

  // ── Request-publish transition ────────────────────────────────────────────

  /**
   * Transition a plan from private → pending_review.
   * Only the owner of a private plan can request publication.
   *
   * @throws NotFoundException if plan not found
   * @throws ForbiddenException if requester is not the owner
   * @throws UnprocessableEntityException if plan is not private
   */
  async requestPublish(userId: string, planId: string): Promise<{ visibility: string }> {
    const db = this.db.getDb();

    const rows = await this.db.withRetry(() =>
      db
        .select({
          id: plans.id,
          visibility: plans.visibility,
          ownerUserId: plans.ownerUserId,
        })
        .from(plans)
        .where(eq(plans.id, planId))
        .limit(1),
    );

    if (rows.length === 0) {
      throw new NotFoundException(`Plan ${planId} not found`);
    }

    const plan = rows[0];

    if (plan.ownerUserId !== userId) {
      throw new ForbiddenException('Only the plan owner can request publication');
    }

    if (plan.visibility !== 'private') {
      throw new UnprocessableEntityException(
        `Plan visibility is '${plan.visibility}', only 'private' plans can request publish`,
      );
    }

    const now = new Date();
    await this.db.withRetry(() =>
      db
        .update(plans)
        .set({ visibility: 'pending_review', updatedAt: now })
        .where(eq(plans.id, planId)),
    );

    this.logger.log(`Plan publish requested: planId=${planId}, userId=${userId}`);
    return { visibility: 'pending_review' };
  }

  // ── Admin plan detail ─────────────────────────────────────────────────────

  /**
   * Admin-only: fetch a plan's hierarchy/publish fields by id.
   * Used by the admin plan detail page to seed PublishToggle / VisibilitySelector.
   *
   * @throws NotFoundException if plan not found
   */
  async getAdminPlanDetail(planId: string): Promise<{
    id: string;
    name: string;
    description: string | null;
    parentPlanId: string | null;
    position: number;
    visibility: string;
    isPublished: boolean;
    ownerUserId: string | null;
    ttsStatus: string | null;
    ttsTotal: number;
    ttsCompleted: number;
    planJson: string;
    createdAt: string;
    updatedAt: string;
  }> {
    const db = this.db.getDb();

    const rows = await this.db.withRetry(() =>
      db
        .select({
          id: plans.id,
          name: plans.name,
          parentPlanId: plans.parentPlanId,
          position: plans.position,
          visibility: plans.visibility,
          isPublished: plans.isPublished,
          ownerUserId: plans.ownerUserId,
          ttsStatus: plans.ttsStatus,
          ttsTotal: plans.ttsTotal,
          ttsCompleted: plans.ttsCompleted,
          planJson: plans.planJson,
          createdAt: plans.createdAt,
          updatedAt: plans.updatedAt,
        })
        .from(plans)
        .where(eq(plans.id, planId))
        .limit(1),
    );

    const row = rows[0];
    if (!row) {
      throw new NotFoundException(`Plan ${planId} not found`);
    }

    // Description is stored inside planJson — surface it on the response so
    // the admin detail page can display it without a second parse.
    let description: string | null = null;
    try {
      const parsed = JSON.parse(row.planJson) as { description?: string | null };
      if (typeof parsed.description === 'string') description = parsed.description;
    } catch {
      // malformed planJson — leave description as null
    }

    return {
      id: row.id,
      name: row.name,
      description,
      parentPlanId: row.parentPlanId ?? null,
      position: row.position,
      visibility: row.visibility,
      isPublished: row.isPublished,
      ownerUserId: row.ownerUserId ?? null,
      ttsStatus: row.ttsStatus ?? null,
      ttsTotal: row.ttsTotal,
      ttsCompleted: row.ttsCompleted,
      planJson: row.planJson,
      createdAt: row.createdAt.toISOString(),
      updatedAt: row.updatedAt.toISOString(),
    };
  }

  // ── Admin plan update ─────────────────────────────────────────────────────

  /**
   * Admin-only: update plan hierarchy fields.
   * Enforces max depth of 3 when setting parent_plan_id.
   *
   * @throws NotFoundException if plan not found
   * @throws UnprocessableEntityException if depth exceeds 3
   */
  async adminUpdatePlan(
    planId: string,
    data: {
      parentPlanId?: string | null;
      position?: number;
      visibility?: string;
      isPublished?: boolean;
      name?: string;
      description?: string | null;
      category?: string;
      tags?: string[];
      defaultVoice?: string;
      stepEdits?: Array<{
        id: string;
        text?: string;
        voiceId?: string | null;
        estimatedDuration?: number | null;
        duration?: number;
      }>;
      planJson?: string;
    },
  ): Promise<void> {
    const db = this.db.getDb();

    // When a full planJson replace is requested, surgical fields would conflict.
    if (data.planJson !== undefined) {
      const conflicting: string[] = [];
      if (data.description !== undefined) conflicting.push('description');
      if (data.category !== undefined) conflicting.push('category');
      if (data.tags !== undefined) conflicting.push('tags');
      if (data.defaultVoice !== undefined) conflicting.push('defaultVoice');
      if (data.stepEdits !== undefined) conflicting.push('stepEdits');
      if (conflicting.length > 0) {
        throw new UnprocessableEntityException(
          `planJson cannot be combined with: ${conflicting.join(', ')}`,
        );
      }
    }

    // Verify plan exists and fetch current planJson if any planJson-touching
    // field is in the patch — keeps reads to a minimum for hierarchy-only edits.
    const touchesJson =
      data.description !== undefined ||
      data.category !== undefined ||
      data.tags !== undefined ||
      data.defaultVoice !== undefined ||
      (data.stepEdits !== undefined && data.stepEdits.length > 0) ||
      data.name !== undefined; // mirror name into planJson too
    const existing = await this.db.withRetry(() =>
      db
        .select({ id: plans.id, planJson: plans.planJson })
        .from(plans)
        .where(eq(plans.id, planId))
        .limit(1),
    );
    if (existing.length === 0) {
      throw new NotFoundException(`Plan ${planId} not found`);
    }

    // Depth validation when setting parent_plan_id
    if (data.parentPlanId !== undefined && data.parentPlanId !== null) {
      await this.validateDepth(planId, data.parentPlanId);
    }

    const updates: Partial<typeof plans.$inferInsert> = { updatedAt: new Date() };
    if (data.parentPlanId !== undefined) updates.parentPlanId = data.parentPlanId;
    if (data.position !== undefined) updates.position = data.position;
    if (data.visibility !== undefined) updates.visibility = data.visibility;
    if (data.isPublished !== undefined) updates.isPublished = data.isPublished;
    if (data.name !== undefined) updates.name = data.name;

    if (data.planJson !== undefined) {
      let parsed: Record<string, unknown>;
      try {
        parsed = JSON.parse(data.planJson) as Record<string, unknown>;
      } catch {
        throw new UnprocessableEntityException('planJson is not valid JSON');
      }
      if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
        throw new UnprocessableEntityException('planJson must be a JSON object');
      }
      if (!Array.isArray(parsed.steps)) {
        throw new UnprocessableEntityException('planJson.steps must be an array');
      }
      if (typeof parsed.name === 'string' && parsed.name.length > 0) {
        updates.name = parsed.name;
      }
      updates.planJson = JSON.stringify(parsed);
    } else if (touchesJson) {
      let parsed: Record<string, unknown> = {};
      try {
        parsed = JSON.parse(existing[0].planJson) as Record<string, unknown>;
      } catch {
        throw new UnprocessableEntityException(
          `Plan ${planId} has malformed plan_json and cannot be edited`,
        );
      }

      if (data.name !== undefined) parsed.name = data.name;
      if (data.description !== undefined) parsed.description = data.description;
      if (data.category !== undefined) parsed.category = data.category;
      if (data.tags !== undefined) parsed.tags = data.tags;
      if (data.defaultVoice !== undefined) parsed.defaultVoice = data.defaultVoice;

      if (data.stepEdits && data.stepEdits.length > 0) {
        const steps = Array.isArray(parsed.steps) ? (parsed.steps as Array<Record<string, unknown>>) : [];
        const editById = new Map(data.stepEdits.map((e) => [e.id, e]));
        applyStepEdits(steps, editById);
        parsed.steps = steps;
      }

      updates.planJson = JSON.stringify(parsed);
    }

    await this.db.withRetry(() =>
      db.update(plans).set(updates).where(eq(plans.id, planId)),
    );

    this.logger.log(`Admin updated plan: planId=${planId}, fields=${Object.keys(data).join(',')}`);
  }

  /**
   * Validate that assigning parentPlanId to planId won't exceed depth 3.
   *
   * Depth calculation:
   *   - Walk UP from the proposed parent to find the ancestor depth (how deep the parent is).
   *   - Walk DOWN from the plan to find descendant depth (how deep the plan's subtree goes).
   *   - Total depth = ancestor depth + 1 (this plan) + descendant depth must not exceed 3.
   *
   * @throws UnprocessableEntityException if depth exceeds 3
   */
  async validateDepth(planId: string, parentPlanId: string): Promise<void> {
    const db = this.db.getDb();

    // Calculate ancestor depth (how deep the parent is from the root)
    const ancestorResult = await this.db.withRetry(() =>
      db.execute(sql`
        WITH RECURSIVE ancestors AS (
          SELECT id, parent_plan_id, 1 AS depth
          FROM plans
          WHERE id = ${parentPlanId}
          UNION ALL
          SELECT p.id, p.parent_plan_id, a.depth + 1
          FROM plans p
          INNER JOIN ancestors a ON p.id = a.parent_plan_id
        )
        SELECT MAX(depth) AS max_depth FROM ancestors
      `),
    );

    const ancestorDepth = Number((ancestorResult.rows[0] as any)?.max_depth ?? 0);

    // If the parent doesn't exist, that's an error
    if (ancestorDepth === 0) {
      throw new NotFoundException(`Parent plan ${parentPlanId} not found`);
    }

    // Calculate descendant depth (how deep the plan's subtree goes below it)
    const descendantResult = await this.db.withRetry(() =>
      db.execute(sql`
        WITH RECURSIVE descendants AS (
          SELECT id, 0 AS depth
          FROM plans
          WHERE id = ${planId}
          UNION ALL
          SELECT p.id, d.depth + 1
          FROM plans p
          INNER JOIN descendants d ON p.parent_plan_id = d.id
          WHERE d.depth < 3
        )
        SELECT MAX(depth) AS max_depth FROM descendants
      `),
    );

    const descendantDepth = Number((descendantResult.rows[0] as any)?.max_depth ?? 0);

    // Total depth in the tree: ancestor chain + this plan level + descendant chain
    // ancestor depth is how many levels the parent is from root (1 = root level)
    // So the plan would be at level ancestorDepth + 1
    // Its deepest descendant would be at level ancestorDepth + 1 + descendantDepth
    const totalDepth = ancestorDepth + 1 + descendantDepth;

    if (totalDepth > 3) {
      throw new UnprocessableEntityException(
        `Assigning parent would result in depth ${totalDepth}, which exceeds the maximum depth of 3`,
      );
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

  // ── Triage: pre-generation feasibility gate ────────────────────────────────

  /**
   * Returns a TriageResult on success, or null if triage failed (fail-open).
   * Caller must treat null as "proceed" — the existing duration cap and
   * Phase 1 schema validation are the structural backstops.
   */
  private async triagePrompt(
    geminiApiKey: string | undefined,
    userPrompt: string,
  ): Promise<TriageResult | null> {
    let text: string;
    try {
      if (geminiApiKey) {
        const body = JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: `${TRIAGE_SYSTEM_PROMPT}\n\nUser request: ${userPrompt}` }] }],
          generationConfig: {
            responseMimeType: 'application/json',
            responseSchema: TRIAGE_SCHEMA,
            temperature: 0.0,
            maxOutputTokens: 256,
          },
        });
        const response = await this.callGeminiRaw(geminiApiKey, body, 'Triage', 15_000);
        text = this.extractGeminiText(response, 'Triage');
      } else {
        text = await this.callOllama(TRIAGE_SYSTEM_PROMPT, userPrompt, 'Triage', TRIAGE_SCHEMA, 15_000);
      }
    } catch (err) {
      this.logger.warn(
        `Triage call failed — proceeding without gate: ${(err as Error).message}`,
      );
      return null;
    }

    try {
      const parsed = JSON.parse(text) as TriageResult;
      if (typeof parsed.feasible !== 'boolean' || !parsed.complexity || !Array.isArray(parsed.flags)) {
        throw new Error('Missing required fields in triage output');
      }
      return parsed;
    } catch (err) {
      this.logger.warn(
        `Triage parse failed — proceeding without gate: ${(err as Error).message}. Response (first 200 chars): ${text.slice(0, 200)}`,
      );
      return null;
    }
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
    this.logger.log(`Calling Ollama ${this.ollamaModel} — ${label}`);

    const body: Record<string, unknown> = {
      model: this.ollamaModel,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      stream: false,
      options: { temperature: this.llmProvider === 'ollama' ? 0.7 : 0.3 },
    };
    if (format) body.format = format;

    const response = await fetch(`${this.ollamaBaseUrl}/api/chat`, {
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

// ── Exported types ───────────────────────────────────────────────────────────

export interface PlanTreeNode {
  id: string;
  name: string;
  parentPlanId: string | null;
  position: number;
  visibility: string;
  isPublished: boolean;
  depth: number;
  children: PlanTreeNode[];
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
