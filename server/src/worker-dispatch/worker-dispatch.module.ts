/**
 * WorkerDispatchModule — encapsulates Lambda worker dispatch.
 *
 * This module has ZERO upstream dependencies (no DatabaseModule, TtsModule, etc.),
 * breaking the circular dependency cycle: plans → tts → server → tts.
 *
 * @Global() so any feature module can inject WorkerDispatchService without
 * importing this module individually.
 */
import { Global, Module } from '@nestjs/common';
import { WorkerDispatchService } from './worker-dispatch.service';

@Global()
@Module({
  providers: [WorkerDispatchService],
  exports: [WorkerDispatchService],
})
export class WorkerDispatchModule {}
