/**
 * AdminRepository — domain repository for admin-level operations
 * such as deletion requests.
 *
 * Delegates to the underlying DatabaseService so existing callers are unaffected
 * during the incremental migration from the monolithic DatabaseService god-object
 * to focused, single-responsibility repositories.
 */

import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database.service';

@Injectable()
export class AdminRepository {
  constructor(private readonly database: DatabaseService) {}

  /** Whether the database is running in noop mode (DATABASE_URL unset). */
  get noop(): boolean {
    return this.database.noop;
  }

  async insertDeletionRequest(data: {
    id: string;
    email: string;
    scope: string;
    reason: string | null;
    requestedAt: Date;
    createdAt: Date;
  }): Promise<void> {
    return this.database.insertDeletionRequest(data);
  }
}
