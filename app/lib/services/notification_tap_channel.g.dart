// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_tap_channel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationTapStreamHash() =>
    r'985348cc49af51924b131cb02b2faa0b2a1c42c8';

/// A broadcast stream that emits `void` each time the Android foreground
/// notification body is tapped (and the app is brought to the foreground).
///
/// Consume this with `ref.listen` in the root widget to navigate to the Now
/// Playing screen:
///
/// ```dart
/// ref.listen<AsyncValue<void>>(notificationTapStreamProvider, (_, next) {
///   next.whenData((_) => _navigateToNowPlaying(context, ref));
/// });
/// ```
///
/// Copied from [notificationTapStream].
@ProviderFor(notificationTapStream)
final notificationTapStreamProvider = StreamProvider<void>.internal(
  notificationTapStream,
  name: r'notificationTapStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$notificationTapStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationTapStreamRef = StreamProviderRef<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
