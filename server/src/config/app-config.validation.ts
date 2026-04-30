/**
 * Valid values for constrained configuration fields.
 *
 * These are exported for use in tests or other validation contexts.
 * Runtime validation happens inside AppConfigModule's buildConfig().
 */
export const VALID_TTS_PROVIDERS = ['kokoro', 'gemini', 'elevenlabs'] as const;
export const VALID_LLM_PROVIDERS = ['gemini', 'ollama'] as const;
export const VALID_NODE_ENVS = ['development', 'production', 'test'] as const;
