/// Riverpod providers for TTS voice configuration.
///
/// [availableVoicesProvider] returns voices from the bundled static catalog.
/// [rawVoiceSettingProvider] streams the raw persisted voice setting string.
library tts_providers;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/assets/static_voice_catalog.dart';
import 'package:instructor/models/tts_provider_config.dart';
import 'package:instructor/services/app_settings.dart';

part 'tts_providers.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Available voices (static bundled catalog)
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the list of available voices for the kokoro provider from the
/// bundled [kStaticVoiceCatalog].
@riverpod
Future<List<TtsVoiceOption>> availableVoices(Ref ref) async {
  final provider = kStaticVoiceCatalog.firstWhere(
    (p) => p.id == 'kokoro',
    orElse: () => kStaticVoiceCatalog.first,
  );
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
