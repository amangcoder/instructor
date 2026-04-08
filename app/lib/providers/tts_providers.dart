/// Riverpod providers for dynamic TTS provider configuration.
///
/// [ttsProvidersProvider] fetches available providers from the backend API.
/// [selectedTtsProviderProvider] tracks the currently selected provider.
/// [availableVoicesProvider] returns voices for the selected provider.
/// [availableLocalesProvider] returns locales for the selected provider.
library tts_providers;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/models/tts_provider_config.dart';
import 'package:instructor/services/app_settings.dart';
import 'package:instructor/services/tts_service.dart';

part 'tts_providers.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppSettings keys for new TTS provider settings
// ─────────────────────────────────────────────────────────────────────────────

extension TtsProviderSettingsKeys on AppSettingsKeys {
  /// The selected TTS provider identifier (e.g. 'gemini', 'kokoro').
  static const String ttsProvider = 'tts_provider';
}

// ─────────────────────────────────────────────────────────────────────────────
// Remote providers response
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches the list of TTS providers + their voices/locales from the backend.
///
/// Returns an [AsyncValue<TtsProvidersResponse>] for error/loading handling.
@riverpod
Future<TtsProvidersResponse> ttsProviders(Ref ref) async {
  final uri = Uri.parse('$kBackendUrl/api/tts/providers');
  final response = await http.get(uri).timeout(const Duration(seconds: 15));

  if (response.statusCode != 200) {
    throw Exception(
        'Failed to load TTS providers (HTTP ${response.statusCode})');
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return TtsProvidersResponse.fromJson(json);
}

// ─────────────────────────────────────────────────────────────────────────────
// Selected provider (persisted in AppSettings)
// ─────────────────────────────────────────────────────────────────────────────

/// Reactive stream of the currently selected TTS provider ID.
///
/// Defaults to 'gemini' when no preference is stored.
@riverpod
Stream<String> selectedTtsProvider(Ref ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.watch(TtsProviderSettingsKeys.ttsProvider).map((raw) {
    return raw?.isNotEmpty == true ? raw! : 'gemini';
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Derived lists (depend on selectedTtsProvider)
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the [TtsProviderConfig] for the currently selected provider,
/// or `null` if the providers haven't loaded yet.
@riverpod
Future<TtsProviderConfig?> selectedProviderConfig(Ref ref) async {
  final providerIdAsync = ref.watch(selectedTtsProviderProvider);
  final providerId = providerIdAsync.valueOrNull ?? 'gemini';

  final response = await ref.watch(ttsProvidersProvider.future);
  try {
    return response.providers.firstWhere((p) => p.id == providerId);
  } catch (_) {
    return response.providers.isNotEmpty ? response.providers.first : null;
  }
}

/// Returns the list of available voices for the currently selected provider.
@riverpod
Future<List<TtsVoiceOption>> availableVoices(Ref ref) async {
  final config = await ref.watch(selectedProviderConfigProvider.future);
  return config?.voices ?? [];
}

/// Returns the list of available locales for the currently selected provider.
@riverpod
Future<List<TtsLocaleOption>> availableLocales(Ref ref) async {
  final config = await ref.watch(selectedProviderConfigProvider.future);
  return config?.locales ?? [];
}

// ─────────────────────────────────────────────────────────────────────────────
// Raw string streams for settings screen dropdowns
// ─────────────────────────────────────────────────────────────────────────────

/// Reactive stream of the raw locale setting string (e.g. 'en-IN', 'enIN').
///
/// Used by the settings screen to display the currently selected locale
/// without going through the [TtsLocale] enum (which does not handle
/// API-format locale IDs like 'en-IN').
@riverpod
Stream<String> rawTtsLocaleSetting(Ref ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.watch(AppSettingsKeys.ttsLocale).map((raw) {
    return raw?.isNotEmpty == true ? raw! : 'en-IN';
  });
}

/// Reactive stream of the raw voice setting string (e.g. 'aoede', 'af_bella').
///
/// Used by the settings screen to display the currently selected voice
/// without going through the [PlanVoice] enum.
@riverpod
Stream<String> rawVoiceSetting(Ref ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.watch(AppSettingsKeys.defaultVoice).map((raw) {
    return raw?.isNotEmpty == true ? raw! : 'aoede';
  });
}
