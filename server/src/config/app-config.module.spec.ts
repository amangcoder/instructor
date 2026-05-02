import { Test } from '@nestjs/testing';
import { AppConfigModule } from './app-config.module';
import type { AppConfig } from './app-config.interface';

describe('AppConfigModule', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  it('should provide APP_CONFIG with default values', async () => {
    const module = await Test.createTestingModule({
      imports: [AppConfigModule],
    }).compile();

    const config = module.get<AppConfig>('APP_CONFIG');
    expect(config).toBeDefined();
    expect(config.awsRegion).toBe('ap-south-1');
    expect(config.defaultTtsProvider).toBe('kokoro');
    expect(config.llmProvider).toBe('ollama');
    expect(config.nodeEnv).toBe('test');
    expect(config.isLocal).toBe(false);
    expect(config.ollamaUrl).toBe('http://localhost:11434');
    expect(config.ollamaModel).toBe('gemma4:e4b');
    expect(config.kokoroServerUrl).toBe('http://127.0.0.1:3070');
  });

  it('should read values from process.env', async () => {
    process.env.AWS_REGION = 'us-east-1';
    process.env.DATABASE_URL = 'postgres://test:test@localhost/db';
    process.env.AWS_S3_BUCKET = 'my-bucket';
    process.env.IS_LOCAL = 'true';

    const module = await Test.createTestingModule({
      imports: [AppConfigModule],
    }).compile();

    const config = module.get<AppConfig>('APP_CONFIG');
    expect(config.awsRegion).toBe('us-east-1');
    expect(config.databaseUrl).toBe('postgres://test:test@localhost/db');
    expect(config.awsS3Bucket).toBe('my-bucket');
    expect(config.isLocal).toBe(true);
  });

  it('should treat IS_LOCAL=1 as true', async () => {
    process.env.IS_LOCAL = '1';

    const module = await Test.createTestingModule({
      imports: [AppConfigModule],
    }).compile();

    const config = module.get<AppConfig>('APP_CONFIG');
    expect(config.isLocal).toBe(true);
  });

  it('should throw for invalid DEFAULT_TTS_PROVIDER', async () => {
    process.env.DEFAULT_TTS_PROVIDER = 'invalid-provider';

    await expect(
      Test.createTestingModule({
        imports: [AppConfigModule],
      }).compile(),
    ).rejects.toThrow('Configuration validation failed');
  });

  it('should throw for invalid LLM_PROVIDER', async () => {
    process.env.LLM_PROVIDER = 'openai';

    await expect(
      Test.createTestingModule({
        imports: [AppConfigModule],
      }).compile(),
    ).rejects.toThrow('Configuration validation failed');
  });

  it('should throw for invalid NODE_ENV', async () => {
    process.env.NODE_ENV = 'staging';

    await expect(
      Test.createTestingModule({
        imports: [AppConfigModule],
      }).compile(),
    ).rejects.toThrow('Configuration validation failed');
  });

  it('should accept all valid TTS providers', async () => {
    for (const provider of ['kokoro', 'gemini', 'elevenlabs']) {
      process.env.DEFAULT_TTS_PROVIDER = provider;

      const module = await Test.createTestingModule({
        imports: [AppConfigModule],
      }).compile();

      const config = module.get<AppConfig>('APP_CONFIG');
      expect(config.defaultTtsProvider).toBe(provider);
    }
  });

  it('should parse usePlanVoicesGate with default value false', async () => {
    delete process.env.USE_PLAN_VOICES_GATE;

    const module = await Test.createTestingModule({
      imports: [AppConfigModule],
    }).compile();

    const config = module.get<AppConfig>('APP_CONFIG');
    expect(config.usePlanVoicesGate).toBe(false);
  });

  it('should parse usePlanVoicesGate=true from environment', async () => {
    process.env.USE_PLAN_VOICES_GATE = 'true';

    const module = await Test.createTestingModule({
      imports: [AppConfigModule],
    }).compile();

    const config = module.get<AppConfig>('APP_CONFIG');
    expect(config.usePlanVoicesGate).toBe(true);
  });

  it('should treat USE_PLAN_VOICES_GATE=1 as true', async () => {
    process.env.USE_PLAN_VOICES_GATE = '1';

    const module = await Test.createTestingModule({
      imports: [AppConfigModule],
    }).compile();

    const config = module.get<AppConfig>('APP_CONFIG');
    expect(config.usePlanVoicesGate).toBe(true);
  });

  it('should treat USE_PLAN_VOICES_GATE=false as false', async () => {
    process.env.USE_PLAN_VOICES_GATE = 'false';

    const module = await Test.createTestingModule({
      imports: [AppConfigModule],
    }).compile();

    const config = module.get<AppConfig>('APP_CONFIG');
    expect(config.usePlanVoicesGate).toBe(false);
  });
});
