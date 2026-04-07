import { Global, Module } from '@nestjs/common';
import { DatabaseService } from './database.service';

/**
 * Global DatabaseModule — imported once in AppModule and available
 * everywhere without re-importing.
 */
@Global()
@Module({
  providers: [DatabaseService],
  exports: [DatabaseService],
})
export class DatabaseModule {}
