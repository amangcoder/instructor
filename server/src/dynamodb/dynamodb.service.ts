/**
 * DynamoDBService — single-table DynamoDB wrapper replacing DatabaseService.
 *
 * Provides typed CRUD methods for all four entity types:
 *   users, OTP records, refresh tokens, sync metadata.
 *
 * Table design:
 *   pk / sk                — primary key
 *   gsi1pk / gsi1sk        — GSI for secondary lookups (email → user, userId → tokens)
 *   ttl                    — DynamoDB TTL attribute (Unix epoch seconds)
 *
 * Environment variables:
 *   DYNAMODB_TABLE  — DynamoDB table name (required)
 *   AWS_REGION      — AWS region (default: ap-south-1)
 */

import { Injectable, Logger } from '@nestjs/common';
import { ConditionalCheckFailedException, DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  UpdateCommand,
  QueryCommand,
} from '@aws-sdk/lib-dynamodb';
import { v4 as uuidv4 } from 'uuid';
import type {
  UserEntity,
  OtpEntity,
  RefreshTokenEntity,
  SyncMetadataEntity,
} from './entities';

// ── Typed result shapes returned to callers ────────────────────────────────

export interface UserRecord {
  id: string;
  email: string;
  createdAt: Date;
}

export interface OtpRecord {
  sk: string;
  email: string;
  code: string;
  expiresAt: Date;
  attempts: number;
  used: boolean;
}

export interface RefreshTokenRecord {
  userId: string;
  tokenHash: string;
  revoked: boolean;
  expiresAt: Date;
  sk: string;
}

export interface SyncMetadataRecord {
  userId: string;
  lastSyncAt: Date | null;
  sizeBytes: number | null;
}

// ── Key builders ──────────────────────────────────────────────────────────────

const pk = {
  user: (id: string) => `USER#${id}`,
  otp: (email: string) => `OTP#${email}`,
  token: (hash: string) => `TOKEN#${hash}`,
  rateLimit: (ns: string, id: string) => `RATELIMIT#${ns}#${id}`,
};

const sk = {
  profile: 'PROFILE',
  otp: (createdAt: string, uuid: string) => `${createdAt}#${uuid}`,
  token: 'TOKEN',
  sync: 'SYNC',
  counter: 'COUNTER',
};

// ── TTL helper ─────────────────────────────────────────────────────────────

function toTtl(date: Date): number {
  return Math.floor(date.getTime() / 1000);
}

// ── GSI name (must match the CDK table definition) ─────────────────────────

const GSI1_INDEX = 'gsi1';

@Injectable()
export class DynamoDBService {
  private readonly logger = new Logger(DynamoDBService.name);
  private readonly client: DynamoDBDocumentClient;
  private readonly table: string;

  /** True when no DYNAMODB_TABLE is configured — all operations throw descriptive errors. */
  private readonly noop: boolean;

  constructor() {
    const region = process.env.AWS_REGION ?? 'ap-south-1';
    const tableName = process.env.DYNAMODB_TABLE ?? process.env.DYNAMODB_TABLE_NAME ?? '';

    this.table = tableName;
    this.noop = tableName === '';

    if (this.noop) {
      this.logger.warn(
        'DYNAMODB_TABLE not set — DynamoDB operations will fail. ' +
        'Set DYNAMODB_TABLE_NAME in .env for local development.',
      );
      this.client = null as unknown as DynamoDBDocumentClient;
      return;
    }

    const rawClient = new DynamoDBClient({ region });
    this.client = DynamoDBDocumentClient.from(rawClient, {
      marshallOptions: { removeUndefinedValues: true },
    });

    this.logger.log(`DynamoDBService initialised — table=${this.table}, region=${region}`);
  }

  private ensureConfigured(): void {
    if (this.noop) {
      throw new Error(
        'DynamoDB is not configured. Set DYNAMODB_TABLE_NAME in your .env file.',
      );
    }
  }

  // ── Users ──────────────────────────────────────────────────────────────────

  /** Fetch a user by their UUID. Returns null if not found. */
  async getUserById(userId: string): Promise<UserRecord | null> {
    this.ensureConfigured();
    const result = await this.client.send(
      new GetCommand({
        TableName: this.table,
        Key: { pk: pk.user(userId), sk: sk.profile },
      }),
    );

    if (!result.Item) return null;
    const item = result.Item as UserEntity;
    return {
      id: item.id,
      email: item.email,
      createdAt: new Date(item.createdAt),
    };
  }

  /** Fetch a user by email address using the GSI. Returns null if not found. */
  async getUserByEmail(email: string): Promise<UserRecord | null> {
    this.ensureConfigured();
    const result = await this.client.send(
      new QueryCommand({
        TableName: this.table,
        IndexName: GSI1_INDEX,
        KeyConditionExpression: 'gsi1pk = :email AND gsi1sk = :profile',
        ExpressionAttributeValues: {
          ':email': email,
          ':profile': sk.profile,
        },
        Limit: 1,
      }),
    );

    if (!result.Items || result.Items.length === 0) return null;
    const item = result.Items[0] as UserEntity;
    return {
      id: item.id,
      email: item.email,
      createdAt: new Date(item.createdAt),
    };
  }

  /**
   * Create a new user record. Throws ConditionalCheckFailedException if a
   * record with the same pk already exists, preventing silent overwrites.
   */
  async createUser(user: { id: string; email: string; createdAt: Date }): Promise<void> {
    this.ensureConfigured();
    const item: UserEntity = {
      pk: pk.user(user.id),
      sk: sk.profile,
      // NOTE: gsi1sk is stored as 'PROFILE' (not 'USER') to match the query in
      // getUserByEmail.  The architecture doc says 'USER' but the code predates
      // that spec revision — intentional deviation, documented here.
      gsi1pk: user.email,
      gsi1sk: sk.profile,
      id: user.id,
      email: user.email,
      createdAt: user.createdAt.toISOString(),
    };

    try {
      await this.client.send(
        new PutCommand({
          TableName: this.table,
          Item: item,
          // Prevent silent overwrites: fail if an item with this pk already exists.
          ConditionExpression: 'attribute_not_exists(pk)',
        }),
      );
    } catch (err) {
      if (err instanceof ConditionalCheckFailedException) {
        // A user record with this UUID already exists — re-throw as a recognisable error.
        throw Object.assign(new Error('User already exists'), { code: 'USER_ALREADY_EXISTS' });
      }
      throw err;
    }
  }

  // ── OTP records ────────────────────────────────────────────────────────────

  /**
   * Store a new OTP record.
   * The sort key includes a timestamp prefix for chronological ordering
   * and a UUID suffix for uniqueness.
   */
  async createOtp(email: string, codeHash: string, expiresAt: Date): Promise<void> {
    this.ensureConfigured();
    const now = new Date().toISOString();
    const sortKey = sk.otp(now, uuidv4());

    const item: OtpEntity = {
      pk: pk.otp(email),
      sk: sortKey,
      email,
      code: codeHash,
      expiresAt: expiresAt.toISOString(),
      attempts: 0,
      used: false,
      ttl: toTtl(expiresAt),
    };

    await this.client.send(
      new PutCommand({
        TableName: this.table,
        Item: item,
      }),
    );
  }

  /**
   * Return all active (unused, non-expired) OTPs for the email address.
   * Caller filters by expiresAt > now to handle DynamoDB TTL eventual deletion lag.
   */
  async getActiveOtps(email: string): Promise<OtpRecord[]> {
    this.ensureConfigured();
    const now = new Date().toISOString();

    const result = await this.client.send(
      new QueryCommand({
        TableName: this.table,
        KeyConditionExpression: 'pk = :pk',
        FilterExpression: '#used = :false AND expiresAt > :now',
        ExpressionAttributeNames: { '#used': 'used' },
        ExpressionAttributeValues: {
          ':pk': pk.otp(email),
          ':false': false,
          ':now': now,
        },
      }),
    );

    return (result.Items ?? []).map((item) => {
      const otp = item as unknown as OtpEntity;
      return {
        sk: otp.sk,
        email: otp.email,
        code: otp.code,
        expiresAt: new Date(otp.expiresAt),
        attempts: otp.attempts,
        used: otp.used,
      };
    });
  }

  /** Mark a specific OTP record as used (single-use enforcement). */
  async markOtpUsed(email: string, sortKey: string): Promise<void> {
    this.ensureConfigured();
    await this.client.send(
      new UpdateCommand({
        TableName: this.table,
        Key: { pk: pk.otp(email), sk: sortKey },
        UpdateExpression: 'SET #used = :true',
        ExpressionAttributeNames: { '#used': 'used' },
        ExpressionAttributeValues: { ':true': true },
      }),
    );
  }

  /**
   * Atomically increment the failed attempt counter for an OTP record.
   * Uses DynamoDB ADD (not client-side SET) to prevent race conditions where
   * concurrent failed requests both read the same count and write the same value.
   */
  async incrementOtpAttempts(email: string, sortKey: string): Promise<void> {
    this.ensureConfigured();
    await this.client.send(
      new UpdateCommand({
        TableName: this.table,
        Key: { pk: pk.otp(email), sk: sortKey },
        UpdateExpression: 'ADD attempts :one',
        ExpressionAttributeValues: { ':one': 1 },
      }),
    );
  }

  /**
   * Invalidate all active OTPs for an email address (set used=true).
   * Called before issuing a new OTP to enforce single-active-OTP invariant.
   */
  async invalidateOtpsForEmail(email: string): Promise<void> {
    this.ensureConfigured();
    // Query all OTPs for this email (active or not — we want to catch any residuals).
    const result = await this.client.send(
      new QueryCommand({
        TableName: this.table,
        KeyConditionExpression: 'pk = :pk',
        FilterExpression: '#used = :false',
        ExpressionAttributeNames: { '#used': 'used' },
        ExpressionAttributeValues: {
          ':pk': pk.otp(email),
          ':false': false,
        },
      }),
    );

    const items = result.Items ?? [];
    await Promise.all(
      items.map((item: Record<string, unknown>) =>
        this.client.send(
          new UpdateCommand({
            TableName: this.table,
            Key: { pk: item['pk'], sk: item['sk'] },
            UpdateExpression: 'SET #used = :true',
            ExpressionAttributeNames: { '#used': 'used' },
            ExpressionAttributeValues: { ':true': true },
          }),
        ),
      ),
    );
  }

  // ── Refresh tokens ─────────────────────────────────────────────────────────

  /** Store a new refresh token (stored as a SHA-256 hash, never plaintext). */
  async createRefreshToken(
    userId: string,
    tokenHash: string,
    expiresAt: Date,
  ): Promise<void> {
    this.ensureConfigured();
    const item: RefreshTokenEntity = {
      pk: pk.token(tokenHash),
      sk: sk.token,
      gsi1pk: pk.user(userId),
      gsi1sk: sk.token,
      userId,
      tokenHash,
      revoked: false,
      expiresAt: expiresAt.toISOString(),
      ttl: toTtl(expiresAt),
    };

    await this.client.send(
      new PutCommand({
        TableName: this.table,
        Item: item,
      }),
    );
  }

  /** Retrieve a refresh token by its hash. Returns null if not found. */
  async getRefreshToken(tokenHash: string): Promise<RefreshTokenRecord | null> {
    const result = await this.client.send(
      new GetCommand({
        TableName: this.table,
        Key: { pk: pk.token(tokenHash), sk: sk.token },
      }),
    );

    if (!result.Item) return null;
    const item = result.Item as RefreshTokenEntity;
    return {
      userId: item.userId,
      tokenHash: item.tokenHash,
      revoked: item.revoked,
      expiresAt: new Date(item.expiresAt),
      sk: item.sk,
    };
  }

  /** Mark a specific refresh token as revoked. */
  async revokeRefreshToken(userId: string, tokenHash: string): Promise<void> {
    await this.client.send(
      new UpdateCommand({
        TableName: this.table,
        Key: { pk: pk.token(tokenHash), sk: sk.token },
        UpdateExpression: 'SET revoked = :true',
        ExpressionAttributeValues: { ':true': true },
      }),
    );

    this.logger.log(`Refresh token revoked for userId=${userId}`);
  }

  /** Revoke all refresh tokens for a user (logout-all / security reset). */
  async revokeAllRefreshTokens(userId: string): Promise<void> {
    // Scan GSI for all tokens belonging to this user.
    const result = await this.client.send(
      new QueryCommand({
        TableName: this.table,
        IndexName: GSI1_INDEX,
        KeyConditionExpression: 'gsi1pk = :userPk AND gsi1sk = :token',
        FilterExpression: 'revoked = :false',
        ExpressionAttributeValues: {
          ':userPk': pk.user(userId),
          ':token': sk.token,
          ':false': false,
        },
      }),
    );

    const items = result.Items ?? [];
    await Promise.all(
      items.map((item: Record<string, unknown>) =>
        this.client.send(
          new UpdateCommand({
            TableName: this.table,
            Key: { pk: item['pk'], sk: item['sk'] },
            UpdateExpression: 'SET revoked = :true',
            ExpressionAttributeValues: { ':true': true },
          }),
        ),
      ),
    );

    this.logger.log(`All ${items.length} refresh tokens revoked for userId=${userId}`);
  }

  // ── Sync metadata ──────────────────────────────────────────────────────────

  /** Retrieve sync metadata for a user. Returns null if never synced. */
  async getSyncMetadata(userId: string): Promise<SyncMetadataRecord | null> {
    const result = await this.client.send(
      new GetCommand({
        TableName: this.table,
        Key: { pk: pk.user(userId), sk: sk.sync },
      }),
    );

    if (!result.Item) return null;
    const item = result.Item as SyncMetadataEntity;
    return {
      userId: item.userId,
      lastSyncAt: item.lastSyncAt ? new Date(item.lastSyncAt) : null,
      sizeBytes: item.sizeBytes ?? null,
    };
  }

  /** Upsert sync metadata after a confirmed upload. */
  async upsertSyncMetadata(
    userId: string,
    lastSyncAt: Date,
    sizeBytes?: number,
  ): Promise<void> {
    const item: SyncMetadataEntity = {
      pk: pk.user(userId),
      sk: sk.sync,
      userId,
      lastSyncAt: lastSyncAt.toISOString(),
      sizeBytes: sizeBytes ?? null,
    };

    await this.client.send(
      new PutCommand({
        TableName: this.table,
        Item: item,
      }),
    );
  }
}
