/// Static bundled fallback TTS provider catalog.
///
/// This catalog is used when:
/// - The app is offline and no cached catalog exists in SQLite.
/// - The server is unreachable on first launch.
///
/// Keep in sync with `provider-registry.service.ts` voice and locale lists.
library static_voice_catalog;

import 'package:instructor/models/tts_provider_config.dart';

// ── Gemini ────────────────────────────────────────────────────────────────────

const _kGeminiVoices = [
  TtsVoiceOption(id: 'aoede', label: 'Aoede'),
  TtsVoiceOption(id: 'charon', label: 'Charon'),
  TtsVoiceOption(id: 'fenrir', label: 'Fenrir'),
  TtsVoiceOption(id: 'kore', label: 'Kore'),
  TtsVoiceOption(id: 'leda', label: 'Leda'),
  TtsVoiceOption(id: 'orus', label: 'Orus'),
  TtsVoiceOption(id: 'puck', label: 'Puck'),
  TtsVoiceOption(id: 'schedar', label: 'Schedar'),
  TtsVoiceOption(id: 'zephyr', label: 'Zephyr'),
];

const _kGeminiLocales = [
  TtsLocaleOption(id: 'enUS', label: 'English (US)'),
  TtsLocaleOption(id: 'enGB', label: 'English (UK)'),
  TtsLocaleOption(id: 'enIN', label: 'English (India)'),
  TtsLocaleOption(id: 'enAU', label: 'English (Australia)'),
  TtsLocaleOption(id: 'enCA', label: 'English (Canada)'),
];

const _kGeminiVoiceMap = <String, String>{
  // Kokoro → Gemini
  'af_heart': 'aoede',
  'af_sky': 'zephyr',
  'af_bella': 'leda',
  'af_sarah': 'leda',
  'af_nicole': 'kore',
  'af_nova': 'aoede',
  'am_adam': 'charon',
  'am_michael': 'puck',
  'am_echo': 'charon',
  'am_eric': 'fenrir',
  'am_liam': 'puck',
  'am_onyx': 'charon',
  'bf_emma': 'leda',
  'bf_isabella': 'kore',
  'bf_alice': 'leda',
  'bf_lily': 'leda',
  'bm_george': 'charon',
  'bm_lewis': 'puck',
  'bm_daniel': 'puck',
  'bm_fable': 'fenrir',
  // ElevenLabs → Gemini
  'EXAVITQu4vr4xnSDxMaL': 'aoede',
  'FGY2WhTYpPnrIDTdsKH5': 'leda',
  'IKne3meq5aSn9XLyUdCD': 'puck',
  'JBFqnCBsd6RMkjVDRZzb': 'charon',
  'TX3LPaxmHKxFdv7VOQHJ': 'orus',
  'XB0fDUnXU5powFXDhCwa': 'kore',
  'Xb7hH8MSUJpSbSDYk0k2': 'leda',
  'bIHbv24MWmeRgasZH58o': 'fenrir',
  'cgSgspJ2msm6clMCkdW9': 'leda',
  'cjVigY5qzO86Huf0OWal': 'fenrir',
  'iP95p4xoKVk53GoZ742B': 'charon',
  'nPczCjzI2devNBz1zQrb': 'schedar',
  'onwK4e9ZLuTAKqWW03F9': 'puck',
  'pFZP5JQG7iQjIQuC4Bku': 'zephyr',
  'pqHfZKP75CvOlQylNhV4': 'charon',
};

// ── Kokoro ────────────────────────────────────────────────────────────────────

const _kKokoroVoices = [
  TtsVoiceOption(id: 'af_heart', label: 'Heart (Female, US)'),
  TtsVoiceOption(id: 'af_sky', label: 'Sky (Female, US)'),
  TtsVoiceOption(id: 'af_bella', label: 'Bella (Female, US)'),
  TtsVoiceOption(id: 'af_sarah', label: 'Sarah (Female, US)'),
  TtsVoiceOption(id: 'af_nicole', label: 'Nicole (Female, US)'),
  TtsVoiceOption(id: 'af_nova', label: 'Nova (Female, US)'),
  TtsVoiceOption(id: 'am_adam', label: 'Adam (Male, US)'),
  TtsVoiceOption(id: 'am_michael', label: 'Michael (Male, US)'),
  TtsVoiceOption(id: 'am_echo', label: 'Echo (Male, US)'),
  TtsVoiceOption(id: 'am_eric', label: 'Eric (Male, US)'),
  TtsVoiceOption(id: 'am_liam', label: 'Liam (Male, US)'),
  TtsVoiceOption(id: 'am_onyx', label: 'Onyx (Male, US)'),
  TtsVoiceOption(id: 'bf_emma', label: 'Emma (Female, UK)'),
  TtsVoiceOption(id: 'bf_isabella', label: 'Isabella (Female, UK)'),
  TtsVoiceOption(id: 'bf_alice', label: 'Alice (Female, UK)'),
  TtsVoiceOption(id: 'bf_lily', label: 'Lily (Female, UK)'),
  TtsVoiceOption(id: 'bm_george', label: 'George (Male, UK)'),
  TtsVoiceOption(id: 'bm_lewis', label: 'Lewis (Male, UK)'),
  TtsVoiceOption(id: 'bm_daniel', label: 'Daniel (Male, UK)'),
  TtsVoiceOption(id: 'bm_fable', label: 'Fable (Male, UK)'),
];

const _kKokoroLocales = [
  TtsLocaleOption(id: 'en-us', label: 'English (US)'),
  TtsLocaleOption(id: 'en-gb', label: 'English (UK)'),
];

const _kKokoroVoiceMap = <String, String>{
  // Gemini → Kokoro
  'aoede': 'af_heart',
  'leda': 'af_bella',
  'kore': 'af_nicole',
  'charon': 'am_adam',
  'puck': 'am_michael',
  'fenrir': 'am_eric',
  'orus': 'am_liam',
  'schedar': 'am_echo',
  'zephyr': 'af_sky',
  // ElevenLabs → Kokoro
  'EXAVITQu4vr4xnSDxMaL': 'af_heart',
  'FGY2WhTYpPnrIDTdsKH5': 'af_bella',
  'IKne3meq5aSn9XLyUdCD': 'am_michael',
  'JBFqnCBsd6RMkjVDRZzb': 'bm_george',
  'TX3LPaxmHKxFdv7VOQHJ': 'am_liam',
  'XB0fDUnXU5powFXDhCwa': 'af_nicole',
  'Xb7hH8MSUJpSbSDYk0k2': 'bf_alice',
  'bIHbv24MWmeRgasZH58o': 'am_adam',
  'cgSgspJ2msm6clMCkdW9': 'af_bella',
  'cjVigY5qzO86Huf0OWal': 'am_eric',
  'iP95p4xoKVk53GoZ742B': 'am_adam',
  'nPczCjzI2devNBz1zQrb': 'am_echo',
  'onwK4e9ZLuTAKqWW03F9': 'bm_daniel',
  'pFZP5JQG7iQjIQuC4Bku': 'bf_lily',
  'pqHfZKP75CvOlQylNhV4': 'am_onyx',
};

// ── ElevenLabs ────────────────────────────────────────────────────────────────

const _kElevenLabsVoices = [
  TtsVoiceOption(id: 'EXAVITQu4vr4xnSDxMaL', label: 'Sarah (Female)'),
  TtsVoiceOption(id: 'FGY2WhTYpPnrIDTdsKH5', label: 'Laura (Female)'),
  TtsVoiceOption(id: 'IKne3meq5aSn9XLyUdCD', label: 'Charlie (Male)'),
  TtsVoiceOption(id: 'JBFqnCBsd6RMkjVDRZzb', label: 'George (Male)'),
  TtsVoiceOption(id: 'TX3LPaxmHKxFdv7VOQHJ', label: 'Liam (Male)'),
  TtsVoiceOption(id: 'XB0fDUnXU5powFXDhCwa', label: 'Charlotte (Female)'),
  TtsVoiceOption(id: 'Xb7hH8MSUJpSbSDYk0k2', label: 'Alice (Female)'),
  TtsVoiceOption(id: 'bIHbv24MWmeRgasZH58o', label: 'Will (Male)'),
  TtsVoiceOption(id: 'cgSgspJ2msm6clMCkdW9', label: 'Jessica (Female)'),
  TtsVoiceOption(id: 'cjVigY5qzO86Huf0OWal', label: 'Eric (Male)'),
  TtsVoiceOption(id: 'iP95p4xoKVk53GoZ742B', label: 'Chris (Male)'),
  TtsVoiceOption(id: 'nPczCjzI2devNBz1zQrb', label: 'Brian (Male)'),
  TtsVoiceOption(id: 'onwK4e9ZLuTAKqWW03F9', label: 'Daniel (Male)'),
  TtsVoiceOption(id: 'pFZP5JQG7iQjIQuC4Bku', label: 'Lily (Female)'),
  TtsVoiceOption(id: 'pqHfZKP75CvOlQylNhV4', label: 'Bill (Male)'),
];

const _kElevenLabsLocales = [
  TtsLocaleOption(id: 'en', label: 'English'),
];

const _kElevenLabsVoiceMap = <String, String>{
  // Gemini → ElevenLabs
  'aoede': 'EXAVITQu4vr4xnSDxMaL',
  'leda': 'cgSgspJ2msm6clMCkdW9',
  'kore': 'XB0fDUnXU5powFXDhCwa',
  'charon': 'JBFqnCBsd6RMkjVDRZzb',
  'puck': 'IKne3meq5aSn9XLyUdCD',
  'fenrir': 'cjVigY5qzO86Huf0OWal',
  'orus': 'TX3LPaxmHKxFdv7VOQHJ',
  'schedar': 'nPczCjzI2devNBz1zQrb',
  'zephyr': 'pFZP5JQG7iQjIQuC4Bku',
  // Kokoro → ElevenLabs
  'af_heart': 'EXAVITQu4vr4xnSDxMaL',
  'af_sky': 'pFZP5JQG7iQjIQuC4Bku',
  'af_bella': 'cgSgspJ2msm6clMCkdW9',
  'af_sarah': 'EXAVITQu4vr4xnSDxMaL',
  'af_nicole': 'XB0fDUnXU5powFXDhCwa',
  'af_nova': 'FGY2WhTYpPnrIDTdsKH5',
  'am_adam': 'JBFqnCBsd6RMkjVDRZzb',
  'am_michael': 'IKne3meq5aSn9XLyUdCD',
  'am_echo': 'nPczCjzI2devNBz1zQrb',
  'am_eric': 'cjVigY5qzO86Huf0OWal',
  'am_liam': 'TX3LPaxmHKxFdv7VOQHJ',
  'am_onyx': 'pqHfZKP75CvOlQylNhV4',
  'bf_emma': 'Xb7hH8MSUJpSbSDYk0k2',
  'bf_isabella': 'XB0fDUnXU5powFXDhCwa',
  'bf_alice': 'Xb7hH8MSUJpSbSDYk0k2',
  'bf_lily': 'pFZP5JQG7iQjIQuC4Bku',
  'bm_george': 'JBFqnCBsd6RMkjVDRZzb',
  'bm_lewis': 'IKne3meq5aSn9XLyUdCD',
  'bm_daniel': 'onwK4e9ZLuTAKqWW03F9',
  'bm_fable': 'bIHbv24MWmeRgasZH58o',
};

// ── Public bundled catalog ────────────────────────────────────────────────────

/// The static fallback catalog used when no network or SQLite cache is available.
///
/// Matches the server's provider-registry.service.ts definitions exactly.
const List<TtsProviderConfig> kStaticVoiceCatalog = [
  TtsProviderConfig(
    id: 'gemini',
    label: 'Google Gemini TTS',
    voices: _kGeminiVoices,
    locales: _kGeminiLocales,
    voiceMap: _kGeminiVoiceMap,
  ),
  TtsProviderConfig(
    id: 'kokoro',
    label: 'Kokoro TTS (Self-Hosted)',
    voices: _kKokoroVoices,
    locales: _kKokoroLocales,
    voiceMap: _kKokoroVoiceMap,
  ),
  TtsProviderConfig(
    id: 'elevenlabs',
    label: 'ElevenLabs',
    voices: _kElevenLabsVoices,
    locales: _kElevenLabsLocales,
    voiceMap: _kElevenLabsVoiceMap,
  ),
];
