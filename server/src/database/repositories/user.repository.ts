/**
 * UserRepository — domain repository for user account operations.
 *
 * Delegates to the underlying DatabaseService so existing callers are unaffected
 * during the incremental migration from the monolithic DatabaseService god-object
 * to focused, single-responsibility repositories.
 */

import { Injectable } from '@nestjs/common';
import { DatabaseService, UserRecord } from '../database.service';

@Injectable()
export class UserRepository {
  constructor(private readonly database: DatabaseService) {}

  async getUserById(userId: string): Promise<UserRecord | null> {
    return this.database.getUserById(userId);
  }

  async getUserByEmail(email: string): Promise<UserRecord | null> {
    return this.database.getUserByEmail(email);
  }

  async createUser(user: { id: string; email: string; createdAt: Date }): Promise<void> {
    return this.database.createUser(user);
  }

  async updateUserProfile(
    userId: string,
    data: { name?: string | null; username?: string | null; photoUrl?: string | null },
  ): Promise<void> {
    return this.database.updateUserProfile(userId, data);
  }

  async deleteUser(userId: string, email: string): Promise<void> {
    return this.database.deleteUser(userId, email);
  }
}
