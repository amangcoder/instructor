import 'package:flutter/material.dart';
import 'package:instructor/services/app_version_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-screen blocker shown when the backend reports that the current
/// build is below the minimum supported version. The user cannot dismiss
/// this screen — the only action is to open the store and update.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({required this.info, super.key});

  final AppVersionCheck info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storeUrl = info.storeUrl;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.system_update,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Update required',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    info.message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  _VersionRow(
                    label: 'Installed',
                    value: info.currentVersion,
                  ),
                  if (info.minVersion != null)
                    _VersionRow(
                      label: 'Required',
                      value: info.minVersion!,
                    ),
                  if (info.latestVersion != null &&
                      info.latestVersion != info.minVersion)
                    _VersionRow(
                      label: 'Latest',
                      value: info.latestVersion!,
                    ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Update now'),
                    onPressed: storeUrl == null
                        ? null
                        : () => _openStore(context, storeUrl),
                  ),
                  if (storeUrl == null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Open the App Store or Play Store and install the '
                      'latest version of Instructor.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openStore(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the store.')),
      );
    }
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label: ', style: theme.textTheme.bodySmall),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
