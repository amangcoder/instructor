/**
 * DynamoDBRateLimitService — replaces Redis-backed RateLimitService.
 *
 * Uses DynamoDB atomic UpdateItem with ADD operation and ConditionExpression
 * to provide the same fixed-window rate limiting semantics without Redis.
 *
 * Counter item key schema:
 *   pk = RATELIMIT#<namespace>#<identifier>
 *   sk = COUNTER
 *
 * Algorithm for consume():
 *   1. Attempt an atomic UpdateItem: ADD count 1, SET ttl if not exists.
 *      ConditionExpression: attribute_not_exists(count) OR count < :limit
 *   2. If the condition succeeds: return { allowed: true, current: <new count> }.
 *   3. If ConditionalCheckFailedException: read the item to get the TTL,
 *      return { allowed: false, retryAfterSec: ttl - now }.
 *
 * Environment variables:
 *   DYNAMODB_TABLE  — DynamoDB table name
 *   AWS_REGION      — AWS region
 */

import { Injectable, Logger } from '@nestjs/common';
import { DynamoDBClient, ConditionalCheckFailedException } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  GetCommand,
  UpdateCommand,
} from '@aws-sdk/lib-dynamodb';

// ── Rate limit result (matches the RateLimitResult interface from Redis service) ──

export interface RateLimitResult {
  allowed: boolean;
  current: number;
  retryAfterSec: number;
}

// ── Key builders ──────────────────────────────────────────────────────────────

function counterKey(namespace: string, identifier: string): string {
  return `RATELIMIT#${namespace}#${identifier}`;
}

@Injectable()
export class DynamoDBRateLimitService {
  private readonly logger = new Logger(DynamoDBRateLimitService.name);
  private readonly client: DynamoDBDocumentClient;
  private readonly table: string;

  /** True when no DYNAMODB_TABLE is configured — all operations become no-ops. */
  private readonly noop: boolean;

  constructor() {
    const region = process.env.AWS_REGION ?? 'ap-south-1';
    this.table = process.env.DYNAMODB_TABLE ?? process.env.DYNAMODB_TABLE_NAME ?? '';
    this.noop = this.table === '';

    if (this.noop) {
      this.logger.warn(
        'DYNAMODB_TABLE not set — rate limiting is disabled (all requests allowed)',
      );
      this.client = null as unknown as DynamoDBDocumentClient;
      return;
    }

    const rawClient = new DynamoDBClient({ region });
    this.client = DynamoDBDocumentClient.from(rawClient, {
      marshallOptions: { removeUndefinedValues: true },
    });
  }

  /**
   * Atomically increment the rate-limit counter and check whether it is within bounds.
   *
   * Uses a single conditional UpdateItem:
   *   - If no counter exists or count < limit: ADD 1 and allow.
   *   - If count >= limit (condition fails): deny and return retryAfterSec from TTL.
   *
   * @param namespace  Logical group, e.g. "otp", "plan"
   * @param identifier Per-entity key, e.g. email address or userId
   * @param limit      Max requests allowed in the window
   * @param windowSec  Window duration in seconds
   */
  async consume(
    namespace: string,
    identifier: string,
    limit: number,
    windowSec: number,
  ): Promise<RateLimitResult> {
    if (this.noop) {
      return { allowed: true, current: 0, retryAfterSec: 0 };
    }

    const pk = counterKey(namespace, identifier);
    const nowSec = Math.floor(Date.now() / 1000);
    const ttl = nowSec + windowSec;

    try {
      // Atomic ADD: increment count, set TTL on first write.
      // ConditionExpression ensures we never increment past the limit.
      const result = await this.client.send(
        new UpdateCommand({
          TableName: this.table,
          Key: { pk, sk: 'COUNTER' },
          UpdateExpression:
            'ADD #count :one SET #ttl = if_not_exists(#ttl, :ttl)',
          ConditionExpression:
            'attribute_not_exists(#count) OR #count < :limit',
          ExpressionAttributeNames: {
            '#count': 'count',
            '#ttl': 'ttl',
          },
          ExpressionAttributeValues: {
            ':one': 1,
            ':limit': limit,
            ':ttl': ttl,
          },
          ReturnValues: 'ALL_NEW',
        }),
      );

      const newCount = (result.Attributes?.['count'] as number | undefined) ?? 1;
      return { allowed: true, current: newCount, retryAfterSec: 0 };
    } catch (err: unknown) {
      // ConditionalCheckFailedException → counter is at or above the limit.
      if (
        err instanceof ConditionalCheckFailedException ||
        (err as { name?: string })?.name === 'ConditionalCheckFailedException'
      ) {
        // Read the item to compute retryAfterSec from the stored TTL.
        const readResult = await this.client.send(
          new GetCommand({
            TableName: this.table,
            Key: { pk, sk: 'COUNTER' },
          }),
        );

        const item = readResult.Item;
        const currentCount = (item?.['count'] as number | undefined) ?? limit;
        const storedTtl = (item?.['ttl'] as number | undefined) ?? ttl;
        const retryAfterSec = Math.max(0, storedTtl - Math.floor(Date.now() / 1000));

        this.logger.debug(
          `Rate limit exceeded for ${namespace}/${identifier} — current=${currentCount}, retryAfterSec=${retryAfterSec}`,
        );

        return { allowed: false, current: currentCount, retryAfterSec };
      }

      // Any other DynamoDB error propagates to the caller.
      throw err;
    }
  }

  /**
   * Check the current counter value without incrementing.
   * Use before expensive work (e.g. Gemini API call) to avoid burning
   * quota on requests that would be rate-limited.
   *
   * @param namespace  Logical group
   * @param identifier Per-entity key
   * @param limit      Max requests allowed in the window
   */
  async peek(
    namespace: string,
    identifier: string,
    limit: number,
  ): Promise<RateLimitResult> {
    if (this.noop) {
      return { allowed: true, current: 0, retryAfterSec: 0 };
    }

    const pk = counterKey(namespace, identifier);
    const nowSec = Math.floor(Date.now() / 1000);

    const result = await this.client.send(
      new GetCommand({
        TableName: this.table,
        Key: { pk, sk: 'COUNTER' },
      }),
    );

    const item = result.Item;
    if (!item) {
      return { allowed: true, current: 0, retryAfterSec: 0 };
    }

    const currentCount = (item['count'] as number | undefined) ?? 0;
    const storedTtl = (item['ttl'] as number | undefined) ?? 0;
    const allowed = currentCount < limit;
    const retryAfterSec = allowed ? 0 : Math.max(0, storedTtl - nowSec);

    return { allowed, current: currentCount, retryAfterSec };
  }

  /**
   * Increment the counter unconditionally (no limit check).
   * Call after a successful operation to record usage without blocking the response.
   *
   * @param namespace  Logical group
   * @param identifier Per-entity key
   * @param windowSec  Window duration in seconds (used to set TTL on first write)
   */
  async increment(
    namespace: string,
    identifier: string,
    windowSec: number,
  ): Promise<void> {
    if (this.noop) return;

    const pk = counterKey(namespace, identifier);
    const ttl = Math.floor(Date.now() / 1000) + windowSec;

    await this.client.send(
      new UpdateCommand({
        TableName: this.table,
        Key: { pk, sk: 'COUNTER' },
        UpdateExpression:
          'ADD #count :one SET #ttl = if_not_exists(#ttl, :ttl)',
        ExpressionAttributeNames: {
          '#count': 'count',
          '#ttl': 'ttl',
        },
        ExpressionAttributeValues: {
          ':one': 1,
          ':ttl': ttl,
        },
        ReturnValues: 'ALL_NEW',
      }),
    );
  }
}
