/// Riverpod providers for TTS voice configuration.
///
/// [ttsProviderCatalogProvider] fetches the live catalog from the backend and
/// falls back to [kStaticVoiceCatalog] on error.
/// [activeProviderProvider] returns the provider flagged [isActive] == true.
/// [availableVoicesProvider] returns voices for the active provider.
/// [rawVoiceSettingProvider] streams the raw persisted voice setting string.
library tts_providers;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/assets/static_voice_catalog.dart';
import 'package:instructor/models/tts_provider_config.dart';
import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/services/app_settings.dart';

part 'tts_providers.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Live provider catalog (fetched from backend, fallback to static)
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches the full TTS provider catalog from the backend.
/// Falls back to [kStaticVoiceCatalog] on any error so the app always has
/// voice data available offline.
@riverpod
Future<List<TtsProviderConfig>> ttsProviderCatalog(Ref ref) async {
  try {
    final api = ref.read(planApiServiceProvider);
    final response = await api.fetchProviderCatalog();
    if (response.providers.isNotEmpty) return response.providers;
  } catch (_) {
    // Network or parse error — fall through to static catalog.
  }
  return kStaticVoiceCatalog;
}

// ─────────────────────────────────────────────────────────────────────────────
// Active provider + default voice
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the [TtsProviderConfig] flagged [isActive] == true by the backend.
/// Falls back to the kokoro entry from [kStaticVoiceCatalog] when the catalog
/// hasn't loaded yet or no provider is flagged active.
@riverpod
Future<TtsProviderConfig> activeProvider(Ref ref) async {
  final catalog = await ref.watch(ttsProviderCatalogProvider.future);
  return catalog.firstWhere(
    (p) => p.isActive,
    orElse: () => catalog.firstWhere(
      (p) => p.id == 'kokoro',
      orElse: () => catalog.first,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Available voices (active provider)
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the list of available voices for the currently active TTS provider.
@riverpod
Future<List<TtsVoiceOption>> availableVoices(Ref ref) async {
  final provider = await ref.watch(activeProviderProvider.future);
  return provider.voices;
}

// ─────────────────────────────────────────────────────────────────────────────
// Raw string stream for settings screen dropdown
// ─────────────────────────────────────────────────────────────────────────────

/// Reactive stream of the raw voice setting string (e.g. 'aoede', 'af_bella').
///
/// Used by the settings screen to display the currently selected voice
/// without going through the [PlanVoice] enum.
@riverpod
Stream<String> rawVoiceSetting(Ref ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.watch(AppSettingsKeys.defaultVoice).map((raw) {
    return raw?.isNotEmpty == true ? raw! : 'af_heart';
  });
}
