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
import { DynamoDBRateLimitService } from '../ratelimit/dynamodb-ratelimit.service';

// ── Constants ────────────────────────────────────────────────────────────────

const GEMINI_GENERATE_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

const MAX_RETRIES = 2;
const RATE_LIMIT_PER_HOUR = 10;
const RATE_WINDOW_SEC = 60 * 60; // 1 hour

// ── Plan JSON schema for Gemini ───────────────────────────────────────────────

const PLAN_SCHEMA = {
  type: 'object',
  required: ['name', 'description', 'category', 'defaultVoice', 'steps'],
  properties: {
    name: { type: 'string' },
    description: { type: 'string' },
    category: { type: 'string' },
    defaultVoice: { type: 'string' },
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
              voice: { type: 'string' },
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
              assetKey: { type: 'string' },
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

const SYSTEM_PROMPT = `You are an expert fitness/wellness coach who creates structured plans.
Generate a structured workout/routine plan based on the user's description.
Return ONLY valid JSON matching the schema — no markdown, no comments, no extra text.

The plan must include:
- name: a short, descriptive title (max 60 chars)
- description: 1-2 sentences describing the plan
- category: one of "fitness", "meditation", "study", "routine", "custom"
- defaultVoice: a voice ID (use "aoede" as default)
- steps: array of step objects where each step has a "type" field

Step types:
- say: { type: "say", text: "...", voice?: "..." } — spoken instruction
- wait: { type: "wait", durationSeconds: 30 } — silent pause
- notify: { type: "notify", message: "..." } — on-screen notification
- repeat: { type: "repeat", count: 3, steps: [...] } — loop steps

Keep plans practical, well-structured, and achievable.`;

@Injectable()
export class PlansService {
  private readonly logger = new Logger(PlansService.name);

  constructor(private readonly rateLimit: DynamoDBRateLimitService) {}

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
        await this.rateLimit.increment('plan', userId, RATE_WINDOW_SEC);
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

    this.logger.log(`Calling Gemini 2.0 Flash for plan generation`);

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
    const result = await this.rateLimit.peek('plan', userId, RATE_LIMIT_PER_HOUR);

    if (!result.allowed) {
      const retryAfterMin = Math.ceil(result.retryAfterSec / 60);
      throw new HttpException(
        `Plan generation rate limit exceeded. Try again in ${retryAfterMin} minutes.`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }
}
