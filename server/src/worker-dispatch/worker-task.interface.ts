/**
 * Worker task interfaces for Lambda background task dispatch.
 *
 * These interfaces define the contracts for asynchronous Lambda self-invocation
 * payloads. They are the single source of truth — both the dispatch side
 * (WorkerDispatchService) and the handler side (lambda.ts) import from here.
 *
 * This module has ZERO upstream dependencies, breaking the former circular
 * dependency: plans → tts → server(lambda) → tts.
 */

/** Task payload for individual TTS pre-generation jobs. */
export interface TtsPregenWorkerTask {
  task: 'ttsPregen';
  planId: string;
  jobIds: string[];
}

/** Task payload for batch TTS pre-generation (grouped by voice/locale). */
export interface TtsBatchPregenWorkerTask {
  task: 'ttsBatchPregen';
  planId: string;
  groups: Array<{
    voiceId: string;
    locale: string;
    provider: string;
    jobIds: string[];  // ordered — matches concatenation order
  }>;
}

/** Union of all worker task types (used by the Lambda handler router). */
export type WorkerTask = TtsPregenWorkerTask | TtsBatchPregenWorkerTask;
