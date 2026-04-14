// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$ttsProviderCatalogHash() =>
    r'c8d2bfd28c4391f143e4f310430edc6574f472ae';

/// Fetches the full TTS provider catalog from the backend.
/// Falls back to [kStaticVoiceCatalog] on any error so the app always has
/// voice data available offline.
///
/// Copied from [ttsProviderCatalog].
@ProviderFor(ttsProviderCatalog)
final ttsProviderCatalogProvider =
    AutoDisposeFutureProvider<List<TtsProviderConfig>>.internal(
  ttsProviderCatalog,
  name: r'ttsProviderCatalogProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ttsProviderCatalogHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TtsProviderCatalogRef
    = AutoDisposeFutureProviderRef<List<TtsProviderConfig>>;
String _$activeProviderHash() => r'9383dccc866c6d64851bbabcd0edb0ae76fd3974';

/// Returns the [TtsProviderConfig] flagged [isActive] == true by the backend.
/// Falls back to the kokoro entry from [kStaticVoiceCatalog] when the catalog
/// hasn't loaded yet or no provider is flagged active.
///
/// Copied from [activeProvider].
@ProviderFor(activeProvider)
final activeProviderProvider =
    AutoDisposeFutureProvider<TtsProviderConfig>.internal(
  activeProvider,
  name: r'activeProviderProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeProviderHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActiveProviderRef = AutoDisposeFutureProviderRef<TtsProviderConfig>;
String _$availableVoicesHash() => r'a3ed5b1a359c2afc35cead611733e85ed7e88545';

/// Returns the list of available voices for the currently active TTS provider.
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
String _$rawVoiceSettingHash() => r'3a8f03c4037ea30f92ff60ad9459a49661404e87';

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
