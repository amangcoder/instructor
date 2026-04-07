// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$syncStatusNotifierHash() =>
    r'772dce77ae0458b8ac77117d281b39c5d7a4e67b';

/// Async notifier tracking the current sync status.
///
/// Initialises from [AppSettings] (persisted last-sync metadata) and updates
/// when [syncToCloud] / [restoreFromCloud] complete.
///
/// Copied from [SyncStatusNotifier].
@ProviderFor(SyncStatusNotifier)
final syncStatusNotifierProvider =
    AsyncNotifierProvider<SyncStatusNotifier, SyncStatus>.internal(
  SyncStatusNotifier.new,
  name: r'syncStatusNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$syncStatusNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SyncStatusNotifier = AsyncNotifier<SyncStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
