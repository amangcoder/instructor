/**
 * DatabaseModule — global NestJS module providing DatabaseService and all
 * domain repositories.
 *
 * Import this module once in AppModule. Because the module is @Global(),
 * all feature modules that inject DatabaseService (AuthModule, SyncModule)
 * or any domain repository resolve them from the global provider registry
 * without needing to import DatabaseModule themselves.
 *
 * Domain repositories (AuthRepository, UserRepository, PlanRepository,
 * TtsRepository, LibraryRepository, SyncRepository, AdminRepository)
 * wrap DatabaseService to provide focused, single-responsibility
 * interfaces for each domain. They delegate to DatabaseService so all existing
 * callers continue to work during the incremental migration.
 */

import { Global, Module } from '@nestjs/common';
import { DatabaseService } from './database.service';
import {
  AuthRepository,
  UserRepository,
  PlanRepository,
  TtsRepository,
  AdminAnalyticsRepository,
  LibraryRepository,
  SyncRepository,
  AdminRepository,
} from './repositories';

@Global()
@Module({
  providers: [
    DatabaseService,
    AuthRepository,
    UserRepository,
    PlanRepository,
    TtsRepository,
    AdminAnalyticsRepository,
    LibraryRepository,
    SyncRepository,
    AdminRepository,
  ],
  exports: [
    DatabaseService,
    AuthRepository,
    UserRepository,
    PlanRepository,
    TtsRepository,
    AdminAnalyticsRepository,
    LibraryRepository,
    SyncRepository,
    AdminRepository,
  ],
})
export class DatabaseModule {}
