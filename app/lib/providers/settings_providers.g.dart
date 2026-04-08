// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$defaultVoiceSettingHash() =>
    r'bf9cfd9b73c31833b0669e5fd2cb7fb89abf53f2';

/// Reactive stream of the user's preferred TTS voice.
///
/// Emits [kDefaultVoice] when the key is absent or unrecognised.
///
/// Copied from [defaultVoiceSetting].
@ProviderFor(defaultVoiceSetting)
final defaultVoiceSettingProvider =
    AutoDisposeStreamProvider<PlanVoice>.internal(
  defaultVoiceSetting,
  name: r'defaultVoiceSettingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$defaultVoiceSettingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DefaultVoiceSettingRef = AutoDisposeStreamProviderRef<PlanVoice>;
String _$ambientVolumeSettingHash() =>
    r'79d037dc991080b1465217823009456e85f7c44e';

/// Reactive stream of the ambient audio master volume (0.0–1.0).
///
/// Emits [kDefaultAmbientVolume] when the key is absent or unparseable.
///
/// Copied from [ambientVolumeSetting].
@ProviderFor(ambientVolumeSetting)
final ambientVolumeSettingProvider = AutoDisposeStreamProvider<double>.internal(
  ambientVolumeSetting,
  name: r'ambientVolumeSettingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ambientVolumeSettingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AmbientVolumeSettingRef = AutoDisposeStreamProviderRef<double>;
String _$voiceVolumeSettingHash() =>
    r'afa1f6889d4350aaceb6a3c2bf74b94abf147655';

/// Reactive stream of the voice/TTS master volume (0.0–1.0).
///
/// Emits [kDefaultVoiceVolume] when the key is absent or unparseable.
///
/// Copied from [voiceVolumeSetting].
@ProviderFor(voiceVolumeSetting)
final voiceVolumeSettingProvider = AutoDisposeStreamProvider<double>.internal(
  voiceVolumeSetting,
  name: r'voiceVolumeSettingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$voiceVolumeSettingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VoiceVolumeSettingRef = AutoDisposeStreamProviderRef<double>;
String _$notificationSoundSettingHash() =>
    r'fbc55646b75589175787536c0e6b82badb1e6c40';

/// Reactive stream of the notification-sound enabled flag.
///
/// Emits [kDefaultNotificationSound] when the key is absent.
///
/// Copied from [notificationSoundSetting].
@ProviderFor(notificationSoundSetting)
final notificationSoundSettingProvider =
    AutoDisposeStreamProvider<bool>.internal(
  notificationSoundSetting,
  name: r'notificationSoundSettingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$notificationSoundSettingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationSoundSettingRef = AutoDisposeStreamProviderRef<bool>;
String _$vibrationSettingHash() => r'edb670f83b5c39ad81119d3c1322279ff566f553';

/// Reactive stream of the vibration enabled flag.
///
/// Emits [kDefaultVibration] when the key is absent.
///
/// Copied from [vibrationSetting].
@ProviderFor(vibrationSetting)
final vibrationSettingProvider = AutoDisposeStreamProvider<bool>.internal(
  vibrationSetting,
  name: r'vibrationSettingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$vibrationSettingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VibrationSettingRef = AutoDisposeStreamProviderRef<bool>;
String _$speechRateSettingHash() => r'66ddfed390c8116083b4ec7bcb9d87f156fbb0b0';

/// Reactive stream of the speech playback speed (0.5–2.0).
///
/// Emits [kDefaultSpeechRate] when the key is absent or unparseable.
///
/// Copied from [speechRateSetting].
@ProviderFor(speechRateSetting)
final speechRateSettingProvider = AutoDisposeStreamProvider<double>.internal(
  speechRateSetting,
  name: r'speechRateSettingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$speechRateSettingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SpeechRateSettingRef = AutoDisposeStreamProviderRef<double>;
String _$ttsLocaleSettingHash() => r'98425cfe840b0a05a80a82b55bfdb4f59b16d7f2';

/// Reactive stream of the selected TTS locale / accent.
///
/// Emits [kDefaultTtsLocale] when the key is absent or unrecognised.
///
/// Copied from [ttsLocaleSetting].
@ProviderFor(ttsLocaleSetting)
final ttsLocaleSettingProvider = AutoDisposeStreamProvider<TtsLocale>.internal(
  ttsLocaleSetting,
  name: r'ttsLocaleSettingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ttsLocaleSettingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TtsLocaleSettingRef = AutoDisposeStreamProviderRef<TtsLocale>;
String _$batteryPromptDismissedSettingHash() =>
    r'd8d7254e92c0e85098602e788c15894ded3b25a9';

/// Reactive stream of the battery-optimisation prompt dismissed flag.
///
/// Emits `false` when the key is absent (prompt not yet dismissed).
///
/// Copied from [batteryPromptDismissedSetting].
@ProviderFor(batteryPromptDismissedSetting)
final batteryPromptDismissedSettingProvider =
    AutoDisposeStreamProvider<bool>.internal(
  batteryPromptDismissedSetting,
  name: r'batteryPromptDismissedSettingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$batteryPromptDismissedSettingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BatteryPromptDismissedSettingRef = AutoDisposeStreamProviderRef<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
