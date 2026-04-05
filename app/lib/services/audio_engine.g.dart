// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_engine.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioEngineHash() => r'3142090d213b8b042bedf7119660f0ad71ee84cc';

/// Singleton [AudioEngine] provider.
///
/// Kept alive for the lifetime of the [ProviderScope] (typically the entire
/// app session). Disposing the [ProviderScope] (e.g. in tests) will call
/// [AudioEngine.dispose], releasing all [AudioPlayer] resources.
///
/// Copied from [audioEngine].
@ProviderFor(audioEngine)
final audioEngineProvider = Provider<AudioEngine>.internal(
  audioEngine,
  name: r'audioEngineProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$audioEngineHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AudioEngineRef = ProviderRef<AudioEngine>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
