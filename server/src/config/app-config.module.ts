import { Module, Global, Logger } from '@nestjs/common';
import type { AppConfig } from './app-config.interface';

const logger = new Logger('AppConfigModule');

/**
 * Valid values for constrained configuration fields.
 */
const VALID_TTS_PROVIDERS = ['kokoro', 'gemini', 'elevenlabs', 'vibevoice'];
const VALID_LLM_PROVIDERS = ['gemini', 'ollama'];
const VALID_NODE_ENVS = ['development', 'production', 'test'];

/**
 * Validates environment variables at startup and maps them to the typed
 * AppConfig shape.  Throws if a constrained field has an invalid value.
 */
function buildConfig(): AppConfig {
  const errors: string[] = [];

  const defaultTtsProvider = process.env.DEFAULT_TTS_PROVIDER ?? 'kokoro';
  if (!VALID_TTS_PROVIDERS.includes(defaultTtsProvider)) {
    errors.push(
      `DEFAULT_TTS_PROVIDER must be one of [${VALID_TTS_PROVIDERS.join(', ')}], got "${defaultTtsProvider}"`,
    );
  }

  const llmProvider = process.env.LLM_PROVIDER ?? 'ollama';
  if (!VALID_LLM_PROVIDERS.includes(llmProvider)) {
    errors.push(
      `LLM_PROVIDER must be one of [${VALID_LLM_PROVIDERS.join(', ')}], got "${llmProvider}"`,
    );
  }

  const nodeEnv = process.env.NODE_ENV ?? 'development';
  if (!VALID_NODE_ENVS.includes(nodeEnv)) {
    errors.push(
      `NODE_ENV must be one of [${VALID_NODE_ENVS.join(', ')}], got "${nodeEnv}"`,
    );
  }

  if (errors.length > 0) {
    const msg = `Configuration validation failed:\n  - ${errors.join('\n  - ')}`;
    logger.error(msg);
    throw new Error(msg);
  }

  return {
    databaseUrl: process.env.DATABASE_URL ?? '',
    awsRegion: process.env.AWS_REGION ?? 'ap-south-1',
    awsS3Bucket: process.env.AWS_S3_BUCKET ?? '',
    defaultTtsProvider,
    kokoroServerUrl: process.env.KOKORO_SERVER_URL ?? 'http://127.0.0.1:3070',
    kokoroApiKey: process.env.KOKORO_API_KEY ?? '',
    vibevoiceServerUrl: process.env.VIBEVOICE_SERVER_URL ?? 'http://127.0.0.1:3073',
    vibevoiceApiKey: process.env.VIBEVOICE_API_KEY ?? '',
    geminiApiKey: process.env.GEMINI_API_KEY ?? '',
    jwtSecret: process.env.JWT_SECRET ?? 'dev-jwt-secret-change-in-production',
    otpSalt: process.env.OTP_SALT ?? '',
    sesFromEmail: process.env.SES_FROM_EMAIL ?? '',
    llmProvider,
    ollamaUrl: process.env.OLLAMA_URL ?? 'http://localhost:11434',
    ollamaModel: process.env.OLLAMA_MODEL ?? 'gemma4:e4b',
    nodeEnv,
    isLocal: process.env.IS_LOCAL === 'true' || process.env.IS_LOCAL === '1',
    lambdaFunctionName: process.env.AWS_LAMBDA_FUNCTION_NAME ?? '',
    usePlanVoicesGate: process.env.USE_PLAN_VOICES_GATE === 'true' || process.env.USE_PLAN_VOICES_GATE === '1',
  };
}

@Global()
@Module({
  providers: [
    {
      provide: 'APP_CONFIG',
      useFactory: (): AppConfig => buildConfig(),
    },
  ],
  exports: ['APP_CONFIG'],
})
export class AppConfigModule {}
