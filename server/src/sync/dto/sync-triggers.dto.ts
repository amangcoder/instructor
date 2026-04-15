/**
 * DTOs for plan-trigger sync endpoints.
 *
 * Mirrors the sync-completions contract: client uploads a batch of triggers
 * and pulls the server-authoritative view by `since` timestamp.
 *
 * ## Idempotency
 *   `clientId` is the cross-device UUID generated on the device. Server
 *   upserts by (userId, clientId): re-uploading the same row is a no-op
 *   that updates mutable columns only.
 *
 * ## Tombstones
 *   Cancellation is represented by a non-null `deletedAt`. The row is
 *   retained server-side so other devices observe the delete on pull.
 *
 * ## Recurrence
 *   Transported as a string — one of:
 *     'none' | 'daily' | 'weekdays' | 'weekly'
 *   The server validates membership in this set.
 */

import {
  IsArray,
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export const TRIGGER_RECURRENCE_VALUES = [
  'none',
  'daily',
  'weekdays',
  'weekly',
] as const;

export type TriggerRecurrence = (typeof TRIGGER_RECURRENCE_VALUES)[number];

export class TriggerDto {
  /** Client-generated UUID; idempotency key across devices. */
  @IsUUID()
  clientId!: string;

  /** Plan this trigger starts when it fires. */
  @IsUUID()
  planId!: string;

  /** Display title captured at schedule time. */
  @IsString()
  title!: string;

  /** Scheduled start time (ISO-8601 UTC). */
  @IsISO8601()
  startUtc!: string;

  /** Plan session duration in minutes. */
  @IsInt()
  @Min(1)
  @Max(1440)
  durationMinutes!: number;

  /** Recurrence: 'none' | 'daily' | 'weekdays' | 'weekly'. */
  @IsIn(TRIGGER_RECURRENCE_VALUES)
  recurrence!: TriggerRecurrence;

  /** Non-null if the client soft-deleted this trigger (tombstone). */
  @IsOptional()
  @IsISO8601()
  deletedAt?: string | null;

  /** Last local mutation time (client clock) — used for LWW reconciliation. */
  @IsISO8601()
  updatedAt!: string;
}

export class UploadTriggersDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => TriggerDto)
  triggers!: TriggerDto[];
}

export class TriggerResponseDto {
  id!: string;
  clientId!: string;
  planId!: string;
  title!: string;
  startUtc!: string;
  durationMinutes!: number;
  recurrence!: TriggerRecurrence;
  deletedAt!: string | null;
  updatedAt!: string;
}

export class UploadTriggersResponseDto {
  /** Server-authoritative view of each accepted row (after LWW reconciliation). */
  triggers!: TriggerResponseDto[];
}

export class GetTriggersResponseDto {
  triggers!: TriggerResponseDto[];
}
