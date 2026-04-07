/// Riverpod providers for sync state.
library sync_providers;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/services/sync_service.dart';

part 'sync_providers.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sync status notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Async notifier tracking the current sync status.
///
/// Initialises from [AppSettings] (persisted last-sync metadata) and updates
/// when [syncToCloud] / [restoreFromCloud] complete.
@Riverpod(keepAlive: true)
class SyncStatusNotifier extends _$SyncStatusNotifier {
  @override
  Future<SyncStatus> build() async {
    final service = ref.watch(syncServiceProvider);
    return service.getSyncStatus();
  }

  /// Triggers an immediate upload to S3 and refreshes the status.
  Future<void> syncNow() async {
    // Mark as syncing.
    state = AsyncData(state.valueOrNull?.copyWith(isSyncing: true) ??
        const SyncStatus(isSyncing: true));

    final service = ref.read(syncServiceProvider);
    try {
      await service.syncToCloud();
      final newStatus = await service.getSyncStatus();
      state = AsyncData(newStatus.copyWith(clearError: true));
    } catch (e) {
      final current = state.valueOrNull ?? const SyncStatus();
      state = AsyncData(current.copyWith(
        isSyncing: false,
        lastError: _friendlyError(e),
      ));
    }
  }

  /// Triggers a restore from S3 and refreshes the status.
  Future<void> restoreNow() async {
    state = AsyncData(state.valueOrNull?.copyWith(isSyncing: true) ??
        const SyncStatus(isSyncing: true));

    final service = ref.read(syncServiceProvider);
    try {
      await service.restoreFromCloud();
      // The old AppDatabase held by the service is now closed.
      // Invalidate the database provider so all dependents (including
      // syncServiceProvider and this notifier) rebuild with a fresh
      // connection to the restored file.
      ref.invalidate(appDatabaseProvider);
    } catch (e) {
      final current = state.valueOrNull ?? const SyncStatus();
      state = AsyncData(current.copyWith(
        isSyncing: false,
        lastError: _friendlyError(e),
      ));
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused') ||
        msg.contains('No address')) {
      return 'Sync failed: No network connection.';
    }
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Sync failed: Please log in and try again.';
    }
    return 'Sync failed: ${msg.length > 80 ? '${msg.substring(0, 80)}…' : msg}';
  }
}
