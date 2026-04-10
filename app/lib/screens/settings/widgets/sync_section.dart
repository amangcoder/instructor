/// SyncSection — cloud sync status display and manual sync controls.
library sync_section;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/providers/sync_providers.dart';
import 'package:instructor/services/sync_service.dart';

/// Displays the last sync timestamp, database size, and Sync Now / Restore
/// buttons. Integrates with [SyncStatusNotifier] for live status.
class SyncSection extends ConsumerWidget {
  const SyncSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncAsync = ref.watch(syncStatusNotifierProvider);

    return syncAsync.when(
      data: (status) => _SyncTile(status: status),
      loading: () => const ListTile(
        leading: Icon(Icons.cloud_sync_outlined),
        title: Text('Cloud Sync'),
        subtitle: LinearProgressIndicator(),
      ),
      error: (_, __) => const ListTile(
        leading: Icon(Icons.cloud_off_outlined),
        title: Text('Cloud Sync'),
        subtitle: Text('Unable to load sync status'),
      ),
    );
  }
}

class _SyncTile extends ConsumerWidget {
  const _SyncTile({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final lastSync = status.lastSyncDateTime;
    final subtitleText = status.isSyncing
        ? 'Syncing…'
        : status.lastError != null
            ? status.lastError!
            : lastSync != null
                ? 'Last synced: ${_formatDateTime(lastSync)}'
                : 'Never synced';

    final sizeText = status.sizeBytes != null
        ? ' · ${_formatSize(status.sizeBytes!)}'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(
            status.isSyncing
                ? Icons.cloud_sync_outlined
                : lastSync != null
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_outlined,
            color: status.lastError != null
                ? colorScheme.error
                : colorScheme.primary,
          ),
          title: const Text('Cloud Sync'),
          subtitle: Text('$subtitleText$sizeText'),
          trailing: status.isSyncing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: status.isSyncing
                    ? null
                    : () => ref
                        .read(syncStatusNotifierProvider.notifier)
                        .syncNow(),
                icon: const Icon(Icons.upload_outlined, size: 16),
                label: const Text('Sync Now'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: status.isSyncing
                    ? null
                    : () => _confirmRestore(context, ref),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Restore'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  Future<void> _confirmRestore(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Restore from Cloud'),
        content: const Text(
          'This will replace your current data with the cloud backup. '
          'The app will need to restart afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(syncStatusNotifierProvider.notifier).restoreNow();
  }
}
