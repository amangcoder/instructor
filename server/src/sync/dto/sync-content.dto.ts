/**
 * DTOs for content-cache sync endpoints (TASK-018).
 *
 * These endpoints return globally-published content for the mobile app to
 * cache locally in its Drift SQLite database.  They are NOT user-scoped —
 * every authenticated user receives the same published + ready records.
 *
 * Endpoints:
 *   GET /api/sync/categories?since=ISO8601   → GetCategoriesResponseDto
 *   GET /api/sync/voices?since=ISO8601       → GetVoicesResponseDto
 *   GET /api/sync/plan-voices?since=ISO8601  → GetPlanVoicesResponseDto
 *
 * Sync semantics:
 *   Full sync  (no since): all records matching the publish/ready gate.
 *   Delta sync (since set): records updated after `since` that still pass
 *     the gate, PLUS `deletedIds` for records no longer in the visible set
 *     (client must evict those IDs from its local cache).
 */

// ---------------------------------------------------------------------------
// Category DTOs
// ---------------------------------------------------------------------------

/**
 * A single published category row sent to the mobile client.
 *
 * Timestamps are serialised to ISO 8601 strings for JSON transport.
 * Only is_published=true categories ever appear here.
 */
export class CategoryDto {
  /** Server-generated UUID primary key. */
  id!: string;

  /** URL-safe unique slug (e.g. "wellness", "fitness"). */
  slug!: string;

  /** Human-readable display name. */
  name!: string;

  /** Optional icon identifier (null when unset). */
  icon!: string | null;

  /** Optional hex/CSS colour string (null when unset). */
  color!: string | null;

  /** Ascending display order (lower value = higher position). */
  sortOrder!: number;

  /** Always true in sync responses — only published rows are returned. */
  isPublished!: boolean;

  /** ISO 8601 creation timestamp. */
  createdAt!: string;

  /** ISO 8601 last-update timestamp. */
  updatedAt!: string;
}

export class GetCategoriesResponseDto {
  /**
   * Published categories (is_published=true).
   * Delta sync: only rows with updatedAt > since.
   * Full sync: all published rows ordered by sortOrder ASC.
   */
  categories!: CategoryDto[];

  /**
   * IDs of categories that were unpublished (or deleted) after the `since`
   * timestamp.  Client must evict these from its local Drift cache.
   * Always empty for full sync (no since).
   */
  deletedIds!: string[];
}

// ---------------------------------------------------------------------------
// Voice DTOs
// ---------------------------------------------------------------------------

/**
 * A single published voice row sent to the mobile client.
 */
export class VoiceDto {
  /** Server-generated UUID primary key. */
  id!: string;

  /** Unique voice slug (e.g. "google-en-us-wavenet-a"). */
  slug!: string;

  /** Human-readable display name shown in voice-selector UI. */
  displayName!: string;

  /** BCP-47 locale tag (e.g. "en-US", "en-IN"). */
  locale!: string;

  /** TTS provider identifier (e.g. "google", "elevenlabs"). */
  provider!: string;

  /** URL to a short audio sample (null when not set). */
  sampleUrl!: string | null;

  /** Always true in sync responses — only published voices are returned. */
  isPublished!: boolean;

  /** ISO 8601 creation timestamp. */
  createdAt!: string;

  /** ISO 8601 last-update timestamp. */
  updatedAt!: string;
}

export class GetVoicesResponseDto {
  /**
   * Published voices (is_published=true).
   * Delta sync: only rows with updatedAt > since.
   * Full sync: all published rows ordered by locale ASC, displayName ASC.
   */
  voices!: VoiceDto[];

  /**
   * IDs of voices that were unpublished after the `since` timestamp.
   * Always empty for full sync (no since).
   */
  deletedIds!: string[];
}

// ---------------------------------------------------------------------------
// PlanVoice DTOs
// ---------------------------------------------------------------------------

/**
 * A single plan_voice row sent to the mobile client.
 *
 * Only rows where status='ready' AND the parent plan has is_published=true
 * are included — these are the rows that gate audio playback.
 */
export class PlanVoiceDto {
  /** Server-generated UUID primary key. */
  id!: string;

  /** Parent plan UUID. */
  planId!: string;

  /** Associated voice UUID. */
  voiceId!: string;

  /** BCP-47 locale of this rendition. */
  locale!: string;

  /**
   * Synthesis status — always "ready" in sync responses.
   * Non-ready rows (pending / processing / failed) are never sent to clients.
   */
  status!: string;

  /** Pre-signed / CDN audio URL (non-null for status=ready rows). */
  audioUrl!: string | null;

  /** Audio duration in milliseconds (non-null for status=ready rows). */
  durationMs!: number | null;

  /** ISO 8601 timestamp when synthesis completed (null if not yet completed). */
  generatedAt!: string | null;

  /** ISO 8601 creation timestamp. */
  createdAt!: string;

  /** ISO 8601 last-update timestamp. */
  updatedAt!: string;
}

export class GetPlanVoicesResponseDto {
  /**
   * Ready plan-voice renditions for published plans.
   * Delta sync: only rows where plan_voices.updatedAt > since.
   * Full sync: all ready+published rows.
   */
  planVoices!: PlanVoiceDto[];

  /**
   * IDs of plan_voice rows that were recently modified but are no longer in
   * the ready+published set (status changed, or parent plan unpublished).
   * Client must evict these from its local Drift cache.
   * Always empty for full sync (no since).
   */
  deletedIds!: string[];
}
