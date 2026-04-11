/// VoiceRemapService — remaps plan voices when the user switches TTS providers.
///
/// Uses the [voiceMap] from the cached provider catalog to find the closest
/// equivalent voice in the new provider for the default voice and all per-step
/// voice overrides (recursively including voices inside RepeatStep children).
library voice_remap_service;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/models/tts_provider_config.dart';
import 'package:instructor/repositories/plan_repository.dart';
import 'package:instructor/services/app_settings.dart';
import 'package:instructor/services/provider_catalog_manager.dart';

part 'voice_remap_service.g.dart';

/// Result of a voice remapping operation.
class VoiceRemapResult {
  const VoiceRemapResult({
    required this.newDefaultVoice,
    required this.newDefaultVoiceLabel,
    required this.newLocale,
    required this.changedStepCount,
    required this.localeChanged,
  });

  /// The new default voice ID after remapping.
  final String newDefaultVoice;

  /// Human-readable label for the new default voice.
  final String newDefaultVoiceLabel;

  /// The new locale after remapping (may be same as before if supported).
  final String newLocale;

  /// Number of plan steps that had voices remapped.
  final int changedStepCount;

  /// Whether the locale changed (used for snackbar message).
  final bool localeChanged;

  /// Human-readable snackbar message.
  String get snackbarMessage {
    if (localeChanged) {
      return 'Voice updated to $newDefaultVoiceLabel ($newLocale). Tap to change.';
    }
    return 'Voice updated to $newDefaultVoiceLabel. Tap to change.';
  }
}

@Riverpod(keepAlive: true)
VoiceRemapService voiceRemapService(Ref ref) {
  return VoiceRemapService(
    catalogManager: ref.read(providerCatalogManagerProvider),
    planRepository: ref.read(planRepositoryProvider),
    settings: ref.read(appSettingsProvider),
  );
}

class VoiceRemapService {
  VoiceRemapService({
    required ProviderCatalogManager catalogManager,
    required PlanRepository planRepository,
    required AppSettings settings,
  })  : _catalogManager = catalogManager,
        _planRepository = planRepository,
        _settings = settings;

  final ProviderCatalogManager _catalogManager;
  final PlanRepository _planRepository;
  final AppSettings _settings;

  /// Remaps all plan voices and settings to the new provider.
  ///
  /// CRITICAL: This persists the new provider setting LAST (after all
  /// remapping completes) to avoid reactive Riverpod race conditions.
  ///
  /// Returns a [VoiceRemapResult] with the new voice info for snackbar display.
  Future<VoiceRemapResult> remapVoicesForProvider({
    required String oldProvider,
    required String newProvider,
  }) async {
    final catalog = await _catalogManager.getCachedCatalog();
    final newProviderConfig = catalog.where((p) => p.id == newProvider).firstOrNull;

    if (newProviderConfig == null) {
      debugPrint('VoiceRemapService: unknown provider "$newProvider" — skipping remap');
      // Return a no-op result using the first voice of the fallback.
      return VoiceRemapResult(
        newDefaultVoice: newProvider == 'kokoro' ? 'af_heart' : 'aoede',
        newDefaultVoiceLabel: newProvider == 'kokoro' ? 'Heart' : 'Aoede',
        newLocale: 'enUS',
        changedStepCount: 0,
        localeChanged: false,
      );
    }

    // Read current default voice and locale from settings.
    final currentVoice = (await _settings.read(AppSettingsKeys.defaultVoice)) ?? 'af_heart';
    final currentLocale = (await _settings.read(AppSettingsKeys.ttsLocale)) ?? 'enIN';

    // Remap the default voice using the voiceMap.
    final voiceMap = newProviderConfig.voiceMap;
    final newDefaultVoice = voiceMap[currentVoice] ??
        (newProviderConfig.voices.isNotEmpty ? newProviderConfig.voices.first.id : currentVoice);

    // Find human-readable label for the new default voice.
    final newDefaultVoiceLabel = newProviderConfig.voices
        .where((v) => v.id == newDefaultVoice)
        .map((v) => v.label)
        .firstOrNull ?? newDefaultVoice;

    // Find closest locale supported by the new provider.
    final newLocale = findClosestLocale(currentLocale, newProviderConfig);
    final localeChanged = newLocale != currentLocale;

    // Update all plan voices via the repository and capture the count.
    final changedCount = await _planRepository.remapPlanVoices(voiceMap);

    // Update locale setting if it changed.
    if (localeChanged) {
      await _settings.write(AppSettingsKeys.ttsLocale, newLocale);
    }

    // Update the default voice setting.
    await _settings.write(AppSettingsKeys.defaultVoice, newDefaultVoice);

    // CRITICAL: Save the new provider LAST to avoid reactive race conditions.
    await _settings.write(AppSettingsKeys.ttsProvider, newProvider);

    debugPrint(
      'VoiceRemapService: remapped $oldProvider → $newProvider: '
      'voice=$currentVoice→$newDefaultVoice, locale=$currentLocale→$newLocale',
    );

    return VoiceRemapResult(
      newDefaultVoice: newDefaultVoice,
      newDefaultVoiceLabel: newDefaultVoiceLabel,
      newLocale: newLocale,
      changedStepCount: changedCount,
      localeChanged: localeChanged,
    );
  }

  /// Finds the closest locale supported by [provider] to [currentLocale].
  ///
  /// Exact match → partial match (same language prefix) → first available locale.
  String findClosestLocale(String currentLocale, TtsProviderConfig provider) {
    if (provider.locales.isEmpty) return currentLocale;

    // Exact match.
    if (provider.locales.any((l) => l.id == currentLocale)) {
      return currentLocale;
    }

    // Normalize: both enIN and en-IN should match enIN.
    final normalizedCurrent = currentLocale.replaceAll('-', '').toLowerCase();

    // Try case-insensitive match.
    final caseInsensitive = provider.locales
        .where((l) => l.id.replaceAll('-', '').toLowerCase() == normalizedCurrent)
        .firstOrNull;
    if (caseInsensitive != null) return caseInsensitive.id;

    // Try language prefix match (e.g., en-IN → en-US if en prefix matches).
    final langPrefix = currentLocale.substring(0, 2).toLowerCase();
    final prefixMatch = provider.locales
        .where((l) => l.id.toLowerCase().startsWith(langPrefix))
        .firstOrNull;
    if (prefixMatch != null) return prefixMatch.id;

    // Fall back to first locale.
    return provider.locales.first.id;
  }

  /// Validates whether [voiceId] is valid for [provider].
  bool validateVoiceForProvider(String voiceId, TtsProviderConfig provider) {
    return provider.voices.any((v) => v.id == voiceId);
  }
}
