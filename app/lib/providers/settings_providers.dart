import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/services/app_settings.dart';

part 'settings_providers.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Default values
// ─────────────────────────────────────────────────────────────────────────────

/// Default TTS voice used when no preference has been saved.
const PlanVoice kDefaultVoice = PlanVoice.aoede;

/// Default ambient audio master volume (70%).
const double kDefaultAmbientVolume = 0.7;

/// Default voice/TTS master volume (100%).
const double kDefaultVoiceVolume = 1.0;

/// Default notification sound enabled state.
const bool kDefaultNotificationSound = true;

/// Default vibration enabled state.
const bool kDefaultVibration = true;

/// Default speech playback speed (1.0 = normal).
const double kDefaultSpeechRate = 1.0;

/// Default TTS locale / accent.
const TtsLocale kDefaultTtsLocale = TtsLocale.enIN;

/// Default backend server URL.
const String kDefaultBackendServerUrl = 'http://localhost:3071';

// ─────────────────────────────────────────────────────────────────────────────
// Stream providers — one per user-facing setting
// ─────────────────────────────────────────────────────────────────────────────

/// Reactive stream of the user's preferred TTS voice.
///
/// Emits [kDefaultVoice] when the key is absent or unrecognised.
@riverpod
Stream<PlanVoice> defaultVoiceSetting(Ref ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.watch(AppSettingsKeys.defaultVoice).map((raw) {
    if (raw == null) return kDefaultVoice;
    return PlanVoice.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => kDefaultVoice,
    );
  });
}

/// Reactive stream of the ambient audio master volume (0.0–1.0).
///
/// Emits [kDefaultAmbientVolume] when the key is absent or unparseable.
@riverpod
Stream<double> ambientVolumeSetting(Ref ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.watch(AppSettingsKeys.ambientVolume).map((raw) {
    if (raw == null) return kDefaultAmbientVolume;
    return double.tryParse(raw)?.clamp(0.0, 1.0) ?? kDefaultAmbientVolume;
  });
}

/// Reactive stream of the voice/TTS master volume (0.0–1.0).
///
/// Emits [kDefaultVoiceVolume] when the key is absent or unparseable.
@riverpod
Stream<double> voiceVolumeSetting(Ref ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.watch(AppSettingsKeys.voiceVolume).map((raw) {
    if (raw == null) return kDefaultVoiceVolume;
    return double.tryParse(raw)?.clamp(0.0, 1.0) ?? kDefaultVoiceVolume;
  });
}

/// Reactive stream of the notification-sound enabled flag.
///
/// Emits [kDefaultNotificationSound] when the key is absent.
@riverpod
Stream<bool> notificationSoundSetting(Ref ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.watch(AppSettingsKeys.notificationSound).map((raw) {
    if (raw == null) return kDefaultNotificationSound;
    return raw == 'true';
  });
}

/// Reactive stream of the vibration enabled flag.
///
/// Emits [kDefaultVibration] when the key is absent.
@riverpod
Stream<bool> vibrationSetting(Ref ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.watch(AppSettingsKeys.vibration).map((raw) {
    if (raw == null) return kDefaultVibration;
    return raw == 'true';
  });
}

/// Reactive stream of the speech playback speed (0.5–2.0).
///
/// Emits [kDefaultSpeechRate] when the key is absent or unparseable.
@riverpod
Stream<double> speechRateSetting(Ref ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.watch(AppSettingsKeys.speechRate).map((raw) {
    if (raw == null) return kDefaultSpeechRate;
    return double.tryParse(raw)?.clamp(0.5, 2.0) ?? kDefaultSpeechRate;
  });
}

/// Reactive stream of the selected TTS locale / accent.
///
/// Emits [kDefaultTtsLocale] when the key is absent or unrecognised.
@riverpod
Stream<TtsLocale> ttsLocaleSetting(Ref ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.watch(AppSettingsKeys.ttsLocale).map((raw) {
    if (raw == null) return kDefaultTtsLocale;
    return TtsLocale.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => kDefaultTtsLocale,
    );
  });
}

/// Reactive stream of the backend server URL.
///
/// Emits [kDefaultBackendServerUrl] when the key is absent.
@riverpod
Stream<String> backendServerUrlSetting(Ref ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.watch(AppSettingsKeys.backendServerUrl).map((raw) {
    if (raw == null || raw.isEmpty) return kDefaultBackendServerUrl;
    return raw;
  });
}

/// Reactive stream of the battery-optimisation prompt dismissed flag.
///
/// Emits `false` when the key is absent (prompt not yet dismissed).
@riverpod
Stream<bool> batteryPromptDismissedSetting(Ref ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.watch(AppSettingsKeys.batteryPromptDismissed).map((raw) {
    if (raw == null) return false;
    return raw == 'true';
  });
}
