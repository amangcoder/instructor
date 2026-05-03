/**
 * Typed application configuration — all environment variables centralised.
 *
 * Services inject AppConfigService instead of reading process.env directly.
 * Missing or invalid variables are caught at startup (fail-fast).
 */
export interface AppConfig {
  // Database
  databaseUrl: string;

  // AWS
  awsRegion: string;
  awsS3Bucket: string;

  // TTS
  defaultTtsProvider: string;
  kokoroServerUrl: string;
  kokoroApiKey: string;
  vibevoiceServerUrl: string;
  vibevoiceApiKey: string;
  geminiApiKey: string;

  // Auth
  jwtSecret: string;
  otpSalt: string;

  // Email
  sesFromEmail: string;

  // LLM
  llmProvider: string;
  ollamaUrl: string;
  ollamaModel: string;

  // Runtime
  nodeEnv: string;
  isLocal: boolean;
  lambdaFunctionName: string;

  // Feature Flags
  usePlanVoicesGate: boolean;
}
