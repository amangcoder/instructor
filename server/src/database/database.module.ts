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
 * TtsRepository, LibraryRepository, SyncRepository, AdminRepository,
 * CategoryRepository, VoiceRepository, PlanVoicesRepository)
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
  SeriesRepository,
  SyncRepository,
  AdminRepository,
  CategoryRepository,
  VoiceRepository,
  PlanVoicesRepository,
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
    SeriesRepository,
    SyncRepository,
    AdminRepository,
    CategoryRepository,
    VoiceRepository,
    PlanVoicesRepository,
  ],
  exports: [
    DatabaseService,
    AuthRepository,
    UserRepository,
    PlanRepository,
    TtsRepository,
    AdminAnalyticsRepository,
    LibraryRepository,
    SeriesRepository,
    SyncRepository,
    AdminRepository,
    CategoryRepository,
    VoiceRepository,
    PlanVoicesRepository,
  ],
})
export class DatabaseModule {}
