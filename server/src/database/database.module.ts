/**
 * DatabaseModule — global NestJS module providing DatabaseService.
 *
 * Import this module once in AppModule. Because the module is @Global(),
 * all feature modules that inject DatabaseService (AuthModule, SyncModule)
 * resolve it from the global provider registry without needing to import
 * DatabaseModule themselves.
 */

import { Global, Module } from '@nestjs/common';
import { DatabaseService } from './database.service';

@Global()
@Module({
  providers: [DatabaseService],
  exports: [DatabaseService],
})
export class DatabaseModule {}
