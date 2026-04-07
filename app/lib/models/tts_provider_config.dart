/// Models for dynamic TTS provider configuration fetched from the backend.
library tts_provider_config;

/// A single voice option returned by the TTS providers API.
class TtsVoiceOption {
  const TtsVoiceOption({
    required this.id,
    required this.label,
    this.gender,
  });

  /// Machine-readable voice identifier (e.g. 'aoede', 'af_bella').
  final String id;

  /// Human-readable display label (e.g. 'Aoede (warm, clear)').
  final String label;

  /// Optional gender tag (e.g. 'female', 'male').
  final String? gender;

  factory TtsVoiceOption.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) {
      throw FormatException(
        'TtsVoiceOption requires a non-empty "id" field',
        json,
      );
    }
    return TtsVoiceOption(
      id: id,
      label: json['label']?.toString() ?? id,
      gender: json['gender']?.toString(),
    );
  }
}

/// A single locale / accent option returned by the TTS providers API.
class TtsLocaleOption {
  const TtsLocaleOption({
    required this.id,
    required this.label,
  });

  /// Machine-readable locale identifier (e.g. 'en-IN', 'en-GB').
  final String id;

  /// Human-readable display label (e.g. 'English (India)').
  final String label;

  factory TtsLocaleOption.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) {
      throw FormatException(
        'TtsLocaleOption requires a non-empty "id" field',
        json,
      );
    }
    return TtsLocaleOption(
      id: id,
      label: json['label']?.toString() ?? id,
    );
  }
}

/// Full configuration for a single TTS provider.
class TtsProviderConfig {
  const TtsProviderConfig({
    required this.id,
    required this.label,
    required this.voices,
    required this.locales,
    this.voiceMap = const {},
  });

  /// Machine-readable provider identifier (e.g. 'gemini', 'kokoro').
  final String id;

  /// Human-readable display label (e.g. 'Gemini', 'Kokoro (local)').
  final String label;

  final List<TtsVoiceOption> voices;
  final List<TtsLocaleOption> locales;

  /// Maps foreign voice IDs → this provider's native voice IDs.
  /// Used by the frontend to remap plan voices when the user switches providers.
  final Map<String, String> voiceMap;

  factory TtsProviderConfig.fromJson(Map<String, dynamic> json) {
    return TtsProviderConfig(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? json['id']?.toString() ?? '',
      voices: (json['voices'] as List<dynamic>? ?? [])
          .map((v) => TtsVoiceOption.fromJson(v as Map<String, dynamic>))
          .toList(),
      locales: (json['locales'] as List<dynamic>? ?? [])
          .map((l) => TtsLocaleOption.fromJson(l as Map<String, dynamic>))
          .toList(),
      voiceMap: (json['voiceMap'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v.toString())),
    );
  }
}

/// Response envelope from GET /api/tts/providers.
class TtsProvidersResponse {
  const TtsProvidersResponse({required this.providers});

  final List<TtsProviderConfig> providers;

  factory TtsProvidersResponse.fromJson(Map<String, dynamic> json) {
    return TtsProvidersResponse(
      providers: (json['providers'] as List<dynamic>? ?? [])
          .map((p) => TtsProviderConfig.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Type aliases for test compatibility
// ─────────────────────────────────────────────────────────────────────────────

/// Alias for [TtsProvidersResponse] — used in test fakes.
typedef TtsProviderList = TtsProvidersResponse;

/// Alias for [TtsProviderConfig] — used in test fakes.
typedef TtsProvider = TtsProviderConfig;

/// Alias for [TtsVoiceOption] — used in test fakes.
typedef TtsVoice = TtsVoiceOption;
