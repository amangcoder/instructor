// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$routerHash() => r'41d09e0678527368fe75e68233181c76c84c6404';

/// Global GoRouter provider.
///
/// Defined with [riverpod_annotation] so it can be overridden in tests.
///
/// ## Onboarding redirect guard
/// On every navigation event the `redirect` callback queries the
/// [AppSettings.hasCompletedOnboarding] flag:
/// - If `false` and the user is **not** on `/onboarding`, redirect there.
/// - If `true` and the user **is** on `/onboarding`, redirect to the library.
///
/// Because [OnboardingScreen] awaits [AppSettings.setHasCompletedOnboarding]
/// before calling `context.go(...)`, the flag is guaranteed to be written
/// before the redirect check runs on the subsequent navigation.
///
/// Copied from [router].
@ProviderFor(router)
final routerProvider = Provider<GoRouter>.internal(
  router,
  name: r'routerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$routerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RouterRef = ProviderRef<GoRouter>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
