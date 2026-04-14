// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$availableVoicesHash() => r'e31de50c65077730bc6c0add938990e703589039';

/// Returns the list of available voices for the kokoro provider from the
/// bundled [kStaticVoiceCatalog].
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
