// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationServiceHash() =>
    r'aead8fb05f3d3e0c009fa6d2604d2fd06e032d84';

/// Provides a long-lived singleton [NotificationService].
///
/// `keepAlive: true` ensures the service persists for the app lifetime and
/// is not disposed between navigations.
///
/// Copied from [notificationService].
@ProviderFor(notificationService)
final notificationServiceProvider = Provider<NotificationService>.internal(
  notificationService,
  name: r'notificationServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$notificationServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationServiceRef = ProviderRef<NotificationService>;
String _$notificationRouteStreamHash() =>
    r'd2222e36d064bf13b737ba547fbc6d484aed9d75';

/// A stream of GoRouter paths emitted when the user taps a notification.
///
/// Connect to this provider with `ref.listen` in a widget or shell route
/// to handle notification-driven navigation:
///
/// ```dart
/// @override
/// Widget build(BuildContext context, WidgetRef ref) {
///   ref.listen<AsyncValue<String>>(
///     notificationRouteStreamProvider,
///     (_, next) => next.whenData((route) => context.go(route)),
///   );
///   ...
/// }
/// ```
///
/// Copied from [notificationRouteStream].
@ProviderFor(notificationRouteStream)
final notificationRouteStreamProvider = StreamProvider<String>.internal(
  notificationRouteStream,
  name: r'notificationRouteStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$notificationRouteStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationRouteStreamRef = StreamProviderRef<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
