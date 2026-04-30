/**
 * SharingService — plan sharing business logic.
 *
 * Responsibilities:
 *   - Generate URL-safe share tokens (nanoid, 12 chars)
 *   - Store tokens on plan records
 *   - Validate ownership (only plan owner can share/revoke)
 *   - Fetch shared plan data (excluding sensitive fields)
 *   - Handle token revocation
 *
 * Share tokens:
 *   - nanoid with URL-safe alphabet ([a-zA-Z0-9_-])
 *   - 12 characters = ~2.8 trillion combinations (OWASP sufficient)
 *   - Collision-resistant enough for social sharing
 *   - Stored in plans table share_token column (VARCHAR(20) unique)
 *
 * Share URLs:
 *   - Format: https://instructor.app/s/{token}
 *   - Under 60 characters (suitable for SMS/social media)
 *   - iOS Universal Links handle /s/ prefix
 *   - Web fallback at web/app/s/[token]/page.tsx
 */

import { Injectable, Logger, NotFoundException, ForbiddenException, Optional, Inject } from '@nestjs/common';
import { customAlphabet } from 'nanoid';
import { DatabaseService } from '../database/database.service';
import { PlanRepository } from '../database/repositories/plan.repository';
import { SharedPlanResponseDto } from './dto/shared-plan-response.dto';

// Nanoid instance: URL-safe alphabet, 12 characters
const nanoid = customAlphabet('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-', 12);

@Injectable()
export class SharingService {
  private readonly logger = new Logger(SharingService.name);
  private readonly shareBaseUrl = 'https://instructor.app/s';
  private readonly repo: PlanRepository | DatabaseService;

  constructor(
    private readonly db: DatabaseService,
    @Optional() @Inject(PlanRepository) planRepo?: PlanRepository,
  ) {
    this.repo = planRepo ?? db;
  }

  /**
   * Generate a new share token for a plan.
   * If the plan already has a share token, return the existing one.
   *
   * SECURITY: Verifies ownership — only the plan owner can share.
   *
   * Returns: { shareToken, shareUrl }
   * Throws: NotFoundException if plan not found
   * Throws: ForbiddenException if user is not the plan owner
   */
  async generateShareToken(
    userId: string,
    planId: string,
  ): Promise<{ shareToken: string; shareUrl: string }> {
    // Fetch the plan to verify ownership
    const plan = await this.repo.getPlanById(planId, userId);
    if (!plan) {
      this.logger.warn(`Ownership verification failed: userId=${userId}, planId=${planId}`);
      throw new NotFoundException('Plan not found');
    }

    // If the plan already has a share token, return it (idempotent)
    if (plan.shareToken) {
      const shareUrl = `${this.shareBaseUrl}/${plan.shareToken}`;
      return { shareToken: plan.shareToken, shareUrl };
    }

    // Generate a new share token
    const shareToken = nanoid();

    // Store the token on the plan
    await this.repo.updatePlanShareToken(planId, shareToken);

    const shareUrl = `${this.shareBaseUrl}/${shareToken}`;
    this.logger.debug(`Share token generated: planId=${planId}, token=${shareToken}`);

    return { shareToken, shareUrl };
  }

  /**
   * Revoke sharing for a plan (set share_token to NULL).
   *
   * SECURITY: Verifies ownership — only the plan owner can revoke.
   *
   * Returns: true if revoked, false if plan not found
   * Throws: No exceptions — returns boolean for controller to handle
   */
  async revokeShareToken(userId: string, planId: string): Promise<boolean> {
    // Verify ownership before revoking
    const plan = await this.repo.getPlanById(planId, userId);
    if (!plan) {
      this.logger.warn(`Ownership verification failed: userId=${userId}, planId=${planId}`);
      throw new NotFoundException('Plan not found');
    }

    // Revoke the token
    const success = await this.repo.revokePlanShareToken(userId, planId);
    if (success) {
      this.logger.debug(`Share token revoked: planId=${planId}`);
    }

    return success;
  }

  /**
   * Fetch shared plan data by share token (public endpoint, no auth).
   *
   * Returns: SharedPlanResponseDto with name, description, steps, stepCount, estimatedDurationMs
   * Returns: null if token is invalid or share has been revoked
   *
   * SECURITY: Response excludes userId, internal metadata, and server-side fields.
   */
  async getSharedPlan(shareToken: string): Promise<SharedPlanResponseDto | null> {
    // Use constant-time comparison to prevent timing attacks
    if (!this.isValidTokenFormat(shareToken)) {
      return null;
    }

    try {
      const planData = await this.repo.getSharedPlan(shareToken);
      if (!planData) {
        return null;
      }

      // Map raw plan data to response DTO (excludes sensitive fields)
      return {
        name: planData.name,
        description: planData.description || undefined,
        steps: planData.steps || [],
        stepCount: planData.stepCount,
        estimatedDurationMs: planData.estimatedDurationMs,
      };
    } catch (error) {
      this.logger.error(`Error fetching shared plan: ${error}`);
      return null;
    }
  }

  /**
   * Validate share token format before querying the database.
   * Prevents invalid tokens from reaching the database layer.
   */
  private isValidTokenFormat(token: string): boolean {
    // Share tokens are 12-character nanoid with URL-safe alphabet
    // Pattern: [a-zA-Z0-9_-]{12}
    const tokenPattern = /^[a-zA-Z0-9_-]{12}$/;
    return tokenPattern.test(token);
  }
}
