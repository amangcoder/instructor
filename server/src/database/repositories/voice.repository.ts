/**
 * VoiceRepository — domain repository for TTS voice operations.
 *
 * Manages voice registry (provider / locale / slug) and enables admin
 * voice-selector dropdowns and mobile voice selection for plan audio synthesis.
 *
 * Uses direct Drizzle queries via DatabaseService.getDb() to leverage
 * published/locale indexes for efficient list operations.
 */

import { Injectable } from '@nestjs/common';
import { and, eq, asc, count } from 'drizzle-orm';
import { DatabaseService } from '../database.service';
import { voices, type Voice, type NewVoice } from '../schema';

export interface ListVoicesResponse {
  rows: Voice[];
  total: number;
}

@Injectable()
export class VoiceRepository {
  constructor(private readonly database: DatabaseService) {}

  /** Whether the database is running in noop mode (DATABASE_URL unset). */
  get noop(): boolean {
    return this.database.noop;
  }

  /**
   * List published voices, optionally filtered by locale.
   * Used by admin voice-selectors and mobile app discovery.
   *
   * @param locale - Optional locale filter (e.g. 'en-US', 'en-IN')
   * @returns All published voices matching the filter, ordered by locale then displayName
   */
  async listPublished(locale?: string): Promise<Voice[]> {
    if (this.noop) return [];

    const drizzle = this.database.getDb();
    const conditions: Parameters<typeof and>[0][] = [eq(voices.isPublished, true)];

    if (locale) {
      conditions.push(eq(voices.locale, locale));
    }

    return drizzle
      .select()
      .from(voices)
      .where(and(...conditions))
      .orderBy(asc(voices.locale), asc(voices.displayName));
  }

  /**
   * List all voices with pagination.
   * Used by admin dashboard voice management grid.
   *
   * @param page - Page number (1-indexed)
   * @param pageSize - Number of records per page
   * @returns Paginated list of voices and total count, ordered by createdAt descending
   */
  async listAll(page: number, pageSize: number): Promise<ListVoicesResponse> {
    if (this.noop) return { rows: [], total: 0 };

    const drizzle = this.database.getDb();
    const pageOffset = (page - 1) * pageSize;

    const [totalResult, rows] = await Promise.all([
      drizzle.select({ value: count() }).from(voices),
      drizzle
        .select()
        .from(voices)
        .orderBy(asc(voices.createdAt))
        .limit(pageSize)
        .offset(pageOffset),
    ]);

    return {
      rows,
      total: totalResult[0]?.value ?? 0,
    };
  }

  /**
   * Find a voice by ID.
   * Used when retrieving details for edit forms or voice assignments.
   *
   * @param id - Voice UUID
   * @returns Voice record or null if not found
   */
  async findById(id: string): Promise<Voice | null> {
    if (this.noop) return null;

    const drizzle = this.database.getDb();
    const rows = await drizzle.select().from(voices).where(eq(voices.id, id));

    return rows[0] ?? null;
  }

  /**
   * Find a voice by slug.
   * Used to resolve provider-style slugs (e.g. 'leda', 'aoede') to the voice
   * UUID required by FK columns such as plan_voices.voice_id.
   *
   * @param slug - Voice slug (unique)
   * @returns Voice record or null if not found
   */
  async findBySlug(slug: string): Promise<Voice | null> {
    if (this.noop) return null;

    const drizzle = this.database.getDb();
    const rows = await drizzle.select().from(voices).where(eq(voices.slug, slug)).limit(1);

    return rows[0] ?? null;
  }

  /**
   * Create a new voice.
   * Used by admin to register a new TTS provider/locale/voice combination.
   *
   * @param data - Voice creation data (id, slug, displayName, locale, provider are required)
   * @returns Created voice record with generated ID and timestamps
   */
  async create(data: NewVoice): Promise<Voice> {
    if (this.noop) throw new Error('Database not configured');

    const drizzle = this.database.getDb();
    const rows = await drizzle.insert(voices).values(data).returning();

    if (!rows[0]) {
      throw new Error('Failed to create voice');
    }

    return rows[0];
  }

  /**
   * Update an existing voice.
   * Used by admin to modify voice metadata (displayName, sampleUrl, isPublished, etc).
   *
   * @param id - Voice UUID
   * @param data - Partial voice update data (all fields optional)
   * @returns Updated voice record or null if not found
   */
  async update(id: string, data: Partial<NewVoice>): Promise<Voice | null> {
    if (this.noop) return null;

    const drizzle = this.database.getDb();
    const rows = await drizzle
      .update(voices)
      .set({
        ...data,
        updatedAt: new Date(),
      })
      .where(eq(voices.id, id))
      .returning();

    return rows[0] ?? null;
  }
}
