// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$ttsProvidersHash() => r'31e9c6b6ed14eb020b3a239640527ad978e91a84';

/// Fetches the list of TTS providers + their voices/locales from the backend.
///
/// Re-fetches whenever the backend server URL changes.
/// Returns an [AsyncValue<TtsProvidersResponse>] for error/loading handling.
///
/// Copied from [ttsProviders].
@ProviderFor(ttsProviders)
final ttsProvidersProvider =
    AutoDisposeFutureProvider<TtsProvidersResponse>.internal(
  ttsProviders,
  name: r'ttsProvidersProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$ttsProvidersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TtsProvidersRef = AutoDisposeFutureProviderRef<TtsProvidersResponse>;
String _$selectedTtsProviderHash() =>
    r'c948f6cfc26e5735e80be237cbf1bd6ea444a406';

/// Reactive stream of the currently selected TTS provider ID.
///
/// Defaults to 'gemini' when no preference is stored.
///
/// Copied from [selectedTtsProvider].
@ProviderFor(selectedTtsProvider)
final selectedTtsProviderProvider = AutoDisposeStreamProvider<String>.internal(
  selectedTtsProvider,
  name: r'selectedTtsProviderProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$selectedTtsProviderHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SelectedTtsProviderRef = AutoDisposeStreamProviderRef<String>;
String _$selectedProviderConfigHash() =>
    r'5bd6231a3e0f6e64a3ccd9a800958c964269db0a';

/// Returns the [TtsProviderConfig] for the currently selected provider,
/// or `null` if the providers haven't loaded yet.
///
/// Copied from [selectedProviderConfig].
@ProviderFor(selectedProviderConfig)
final selectedProviderConfigProvider =
    AutoDisposeFutureProvider<TtsProviderConfig?>.internal(
  selectedProviderConfig,
  name: r'selectedProviderConfigProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$selectedProviderConfigHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SelectedProviderConfigRef
    = AutoDisposeFutureProviderRef<TtsProviderConfig?>;
String _$availableVoicesHash() => r'86640cff2897f3c118ef4421a03cba19b4bbf9da';

/// Returns the list of available voices for the currently selected provider.
///
/// Copied from [availableVoices].
@ProviderFor(availableVoices)
final availableVoicesProvider =
    AutoDisposeFutureProvider<List<TtsVoiceOption>>.internal(
  availableVoices,
  name: r'availableVoicesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$availableVoicesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AvailableVoicesRef = AutoDisposeFutureProviderRef<List<TtsVoiceOption>>;
String _$availableLocalesHash() => r'd1aa58ddd5ea397fae03f2ba5be37c0aa8c93d58';

/// Returns the list of available locales for the currently selected provider.
///
/// Copied from [availableLocales].
@ProviderFor(availableLocales)
final availableLocalesProvider =
    AutoDisposeFutureProvider<List<TtsLocaleOption>>.internal(
  availableLocales,
  name: r'availableLocalesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$availableLocalesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AvailableLocalesRef
    = AutoDisposeFutureProviderRef<List<TtsLocaleOption>>;
String _$rawTtsLocaleSettingHash() =>
    r'7fd7650b571dc74c47ba7b3704dff7e0bb2a293e';

/// Reactive stream of the raw locale setting string (e.g. 'en-IN', 'enIN').
///
/// Used by the settings screen to display the currently selected locale
/// without going through the [TtsLocale] enum (which does not handle
/// API-format locale IDs like 'en-IN').
///
/// Copied from [rawTtsLocaleSetting].
@ProviderFor(rawTtsLocaleSetting)
final rawTtsLocaleSettingProvider = AutoDisposeStreamProvider<String>.internal(
  rawTtsLocaleSetting,
  name: r'rawTtsLocaleSettingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$rawTtsLocaleSettingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RawTtsLocaleSettingRef = AutoDisposeStreamProviderRef<String>;
String _$rawVoiceSettingHash() => r'2a20206d0690de680e34a7a4753173c94979c6c6';

/// Reactive stream of the raw voice setting string (e.g. 'aoede', 'af_bella').
///
/// Used by the settings screen to display the currently selected voice
/// without going through the [PlanVoice] enum.
///
/// Copied from [rawVoiceSetting].
@ProviderFor(rawVoiceSetting)
final rawVoiceSettingProvider = AutoDisposeStreamProvider<String>.internal(
  rawVoiceSetting,
  name: r'rawVoiceSettingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$rawVoiceSettingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RawVoiceSettingRef = AutoDisposeStreamProviderRef<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
