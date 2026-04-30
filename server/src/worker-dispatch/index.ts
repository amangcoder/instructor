/**
 * Worker dispatch barrel file.
 *
 * Re-exports all public APIs from the worker-dispatch module.
 */
export { WorkerDispatchModule } from './worker-dispatch.module';
export { WorkerDispatchService } from './worker-dispatch.service';
export type {
  TtsPregenWorkerTask,
  TtsBatchPregenWorkerTask,
  WorkerTask,
} from './worker-task.interface';
