/**
 * DynamoDBModule — global module providing DynamoDBService.
 *
 * Import this module once in AppModule. All feature modules that inject
 * DynamoDBService will resolve it from the global provider registry
 * without needing to import DynamoDBModule themselves.
 */

import { Global, Module } from '@nestjs/common';
import { DynamoDBService } from './dynamodb.service';

@Global()
@Module({
  providers: [DynamoDBService],
  exports: [DynamoDBService],
})
export class DynamoDBModule {}
