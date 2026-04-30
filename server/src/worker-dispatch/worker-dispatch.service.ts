/**
 * WorkerDispatchService — Lambda worker invocation for background tasks.
 *
 * Centralizes all Lambda self-invocation logic that was previously duplicated
 * in TtsPregenService and TtsBatchPregenService. This breaks the circular
 * dependency: plans → tts → server(lambda) → tts.
 *
 * Local-dev mode (IS_LOCAL=true): uses setImmediate() callbacks instead of
 * Lambda invocation. The caller provides a fallback function for local execution.
 */
import { Injectable, Logger, Inject } from '@nestjs/common';
import {
  LambdaClient,
  InvokeCommand,
  InvocationType,
} from '@aws-sdk/client-lambda';
import type { AppConfig } from '../config/app-config.interface';
import type {
  TtsPregenWorkerTask,
  TtsBatchPregenWorkerTask,
} from './worker-task.interface';

@Injectable()
export class WorkerDispatchService {
  private readonly logger = new Logger(WorkerDispatchService.name);
  private readonly lambda: LambdaClient | null;
  private readonly functionName: string | null;
  private readonly isLocal: boolean;

  constructor(@Inject('APP_CONFIG') private readonly config: AppConfig) {
    this.functionName = config.lambdaFunctionName || null;
    this.isLocal = config.isLocal;
    this.lambda =
      this.functionName && !this.isLocal
        ? new LambdaClient({ region: config.awsRegion })
        : null;
  }

  /**
   * Dispatch a TTS pre-generation worker task.
   *
   * In production: invokes the Lambda function asynchronously (fire-and-forget).
   * In local dev: executes the provided fallback function via setImmediate().
   *
   * @param task The TtsPregenWorkerTask payload.
   * @param localFallback Callback executed via setImmediate() when Lambda is unavailable.
   */
  async dispatchTtsPregen(
    task: TtsPregenWorkerTask,
    localFallback: () => Promise<void>,
  ): Promise<void> {
    await this.dispatch(task, localFallback, `planId=${task.planId}, jobs=${task.jobIds.length}`);
  }

  /**
   * Dispatch a batch TTS pre-generation worker task.
   *
   * In production: invokes the Lambda function asynchronously (fire-and-forget).
   * In local dev: executes the provided fallback function via setImmediate().
   *
   * @param task The TtsBatchPregenWorkerTask payload.
   * @param localFallback Callback executed via setImmediate() when Lambda is unavailable.
   */
  async dispatchBatchPregen(
    task: TtsBatchPregenWorkerTask,
    localFallback: () => Promise<void>,
  ): Promise<void> {
    await this.dispatch(task, localFallback, `planId=${task.planId}, groups=${task.groups.length}`);
  }

  /**
   * Core dispatch logic shared by all task types.
   */
  private async dispatch(
    task: TtsPregenWorkerTask | TtsBatchPregenWorkerTask,
    localFallback: () => Promise<void>,
    label: string,
  ): Promise<void> {
    if (this.isLocal) {
      this.logger.log(`dispatch (local) — ${label}`);
      setImmediate(() => {
        localFallback().catch((err) =>
          this.logger.error(`dispatch local error: ${err instanceof Error ? err.message : err}`),
        );
      });
      return;
    }

    if (!this.functionName || !this.lambda) {
      this.logger.warn(`dispatch — Lambda not configured, falling back to setImmediate() — ${label}`);
      setImmediate(() => {
        localFallback().catch((err) =>
          this.logger.error(`dispatch fallback error: ${err instanceof Error ? err.message : err}`),
        );
      });
      return;
    }

    await this.lambda.send(
      new InvokeCommand({
        FunctionName: this.functionName,
        InvocationType: InvocationType.Event,
        Payload: Buffer.from(JSON.stringify(task)),
      }),
    );
    this.logger.log(`dispatch — invoked Lambda ${this.functionName} — ${label}`);
  }
}
