/**
 * SeriesRepository — domain repository for series + subscription operations.
 *
 * Thin wrapper over DatabaseService, mirroring the LibraryRepository pattern
 * so callers can be unit-tested with a mock repository while the service
 * delegates to Drizzle.
 */

import { Injectable } from '@nestjs/common';
import {
  DatabaseService,
  type SeriesRecord,
  type SeriesSubscriptionRecord,
  type PlanRecord,
} from '../database.service';

@Injectable()
export class SeriesRepository {
  constructor(private readonly database: DatabaseService) {}

  // Series CRUD
  listPublishedSeries(categorySlug?: string): Promise<SeriesRecord[]> {
    return this.database.listPublishedSeries(categorySlug);
  }

  listAllSeries(): Promise<SeriesRecord[]> {
    return this.database.listAllSeries();
  }

  getSeriesById(id: string): Promise<SeriesRecord | null> {
    return this.database.getSeriesById(id);
  }

  createSeries(data: Parameters<DatabaseService['createSeries']>[0]) {
    return this.database.createSeries(data);
  }

  updateSeries(id: string, data: Parameters<DatabaseService['updateSeries']>[1]) {
    return this.database.updateSeries(id, data);
  }

  deleteSeries(id: string): Promise<boolean> {
    return this.database.deleteSeries(id);
  }

  /**
   * Convenience wrapper for the publish toggle.
   * Delegates to updateSeries with only the isPublished field.
   */
  publish(id: string, isPublished: boolean): Promise<SeriesRecord | null> {
    return this.database.updateSeries(id, { isPublished });
  }

  listPlansInSeries(seriesId: string): Promise<PlanRecord[]> {
    return this.database.listPlansInSeries(seriesId);
  }

  /**
   * Bulk-update plan positions for plans that belong to this series.
   * Plans not in the list keep their current position.
   */
  reorderPlans(
    seriesId: string,
    items: Array<{ planId: string; position: number }>,
  ): Promise<void> {
    return this.database.reorderSeriesPlans(seriesId, items);
  }

  // Subscriptions
  getSubscription(userId: string, seriesId: string): Promise<SeriesSubscriptionRecord | null> {
    return this.database.getSubscription(userId, seriesId);
  }

  listUserSubscriptions(
    userId: string,
    activeOnly = false,
  ): Promise<SeriesSubscriptionRecord[]> {
    return this.database.listUserSubscriptions(userId, activeOnly);
  }

  subscribe(userId: string, seriesId: string): Promise<SeriesSubscriptionRecord> {
    return this.database.subscribeToSeries(userId, seriesId);
  }

  setStatus(
    userId: string,
    seriesId: string,
    status: 'active' | 'paused' | 'completed' | 'cancelled',
  ): Promise<SeriesSubscriptionRecord | null> {
    return this.database.setSubscriptionStatus(userId, seriesId, status);
  }

  recordProgress(
    userId: string,
    seriesId: string,
    sessionIndex: number,
  ): Promise<SeriesSubscriptionRecord | null> {
    return this.database.recordSessionProgress(userId, seriesId, sessionIndex);
  }
}
