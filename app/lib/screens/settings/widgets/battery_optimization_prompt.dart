import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/providers/settings_providers.dart';
import 'package:instructor/services/app_settings.dart';

/// OEM → user-facing battery optimisation instructions.
const Map<String, String> _oemInstructions = {
  'xiaomi':
      'Go to Settings > Battery & performance > App battery saver > Instructor > No restrictions',
  'samsung':
      'Go to Settings > Battery > App power management > Instructor > Unrestricted',
  'huawei':
      'Go to Settings > Battery > App launch > Instructor > Manage manually',
  'oppo':
      'Go to Settings > Battery > App battery management > Instructor > Allow background activity',
  'vivo':
      'Go to Settings > Battery > High background power consumption > Enable for Instructor',
};

/// A dismissible card that shows device-specific battery optimisation
/// instructions for OEMs (Xiaomi, Samsung, Huawei, Oppo, Vivo) that
/// aggressively kill background apps.
///
/// - Returns [SizedBox.shrink] on iOS, unrecognised OEMs, or after dismissal.
/// - Uses [FutureBuilder] to asynchronously resolve the device manufacturer.
/// - Watches [batteryPromptDismissedSettingProvider] so that once dismissed the
///   widget collapses without requiring a rebuild of the parent.
class BatteryOptimizationPrompt extends ConsumerWidget {
  const BatteryOptimizationPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Not applicable on iOS.
    if (!Platform.isAndroid) return const SizedBox.shrink();

    // If the user already dismissed the prompt, don't show it again.
    final dismissedAsync = ref.watch(batteryPromptDismissedSettingProvider);
    final dismissed = dismissedAsync.valueOrNull ?? false;
    if (dismissed) return const SizedBox.shrink();

    return FutureBuilder<AndroidDeviceInfo>(
      future: DeviceInfoPlugin().androidInfo,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final manufacturer =
            snapshot.data!.manufacturer.toLowerCase().trim();
        final instructions = _oemInstructions[manufacturer];

        if (instructions == null) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.battery_alert, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Battery Optimization',
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        instructions,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            await ref
                                .read(appSettingsProvider)
                                .write(
                                  AppSettingsKeys.batteryPromptDismissed,
                                  'true',
                                );
                          },
                          child: const Text('Dismiss'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
