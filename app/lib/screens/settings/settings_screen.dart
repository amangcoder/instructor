import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/providers/settings_providers.dart';
import 'package:instructor/services/app_settings.dart';
import 'widgets/battery_optimization_prompt.dart';

/// App settings screen.
///
/// Sections:
/// - **Voice** — default TTS voice selector (alloy / nova).
/// - **Volume** — ambient and voice volume sliders (0.0–1.0).
/// - **Notifications** — sound and vibration toggles.
/// - **Battery** (Android only) — OEM battery optimisation prompt.
///
/// All values are read from [AppSettings] via stream providers and written back
/// via [AppSettings.write] on every user interaction.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Voice ───────────────────────────────────────────────────────
          _SectionHeader(title: 'Voice'),
          _VoiceSelector(ref: ref),

          // ── Volume ──────────────────────────────────────────────────────
          _SectionHeader(title: 'Volume'),
          _AmbientVolumeSlider(ref: ref),
          _VoiceVolumeSlider(ref: ref),

          // ── Notifications ───────────────────────────────────────────────
          _SectionHeader(title: 'Notifications'),
          _NotificationSoundSwitch(ref: ref),
          _VibrationSwitch(ref: ref),

          // ── Battery (Android only) ───────────────────────────────────────
          if (Platform.isAndroid) ...[
            _SectionHeader(title: 'Battery'),
            const BatteryOptimizationPrompt(),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Voice section
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceSelector extends StatelessWidget {
  const _VoiceSelector({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final voiceAsync = ref.watch(defaultVoiceSettingProvider);

    return ListTile(
      title: const Text('Default TTS Voice'),
      subtitle: const Text('Voice used for all "Say" steps'),
      trailing: voiceAsync.when(
        data: (currentVoice) => DropdownButton<PlanVoice>(
          value: currentVoice,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(
              value: PlanVoice.alloy,
              child: Text('Alloy'),
            ),
            DropdownMenuItem(
              value: PlanVoice.nova,
              child: Text('Nova'),
            ),
          ],
          onChanged: (newVoice) {
            if (newVoice == null) return;
            ref
                .read(appSettingsProvider)
                .write(AppSettingsKeys.defaultVoice, newVoice.name);
          },
        ),
        loading: () => const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (_, __) => const Text('—'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Volume section
// ─────────────────────────────────────────────────────────────────────────────

class _AmbientVolumeSlider extends StatelessWidget {
  const _AmbientVolumeSlider({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final volumeAsync = ref.watch(ambientVolumeSettingProvider);

    return volumeAsync.when(
      data: (volume) => ListTile(
        title: const Text('Ambient Volume'),
        subtitle: Semantics(
          label: 'Ambient volume: ${(volume * 100).round()} percent',
          child: Slider(
            value: volume,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            label: '${(volume * 100).round()}%',
            onChanged: (newValue) {
              ref
                  .read(appSettingsProvider)
                  .write(
                    AppSettingsKeys.ambientVolume,
                    newValue.toStringAsFixed(2),
                  );
            },
          ),
        ),
      ),
      loading: () => const ListTile(
        title: Text('Ambient Volume'),
        subtitle: LinearProgressIndicator(),
      ),
      error: (_, __) => const ListTile(title: Text('Ambient Volume')),
    );
  }
}

class _VoiceVolumeSlider extends StatelessWidget {
  const _VoiceVolumeSlider({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final volumeAsync = ref.watch(voiceVolumeSettingProvider);

    return volumeAsync.when(
      data: (volume) => ListTile(
        title: const Text('Voice Volume'),
        subtitle: Semantics(
          label: 'Voice volume: ${(volume * 100).round()} percent',
          child: Slider(
            value: volume,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            label: '${(volume * 100).round()}%',
            onChanged: (newValue) {
              ref
                  .read(appSettingsProvider)
                  .write(
                    AppSettingsKeys.voiceVolume,
                    newValue.toStringAsFixed(2),
                  );
            },
          ),
        ),
      ),
      loading: () => const ListTile(
        title: Text('Voice Volume'),
        subtitle: LinearProgressIndicator(),
      ),
      error: (_, __) => const ListTile(title: Text('Voice Volume')),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifications section
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationSoundSwitch extends StatelessWidget {
  const _NotificationSoundSwitch({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final soundAsync = ref.watch(notificationSoundSettingProvider);

    return soundAsync.when(
      data: (enabled) => SwitchListTile(
        title: const Text('Notification Sound'),
        subtitle: const Text('Play a sound on notify steps'),
        value: enabled,
        onChanged: (newValue) {
          ref
              .read(appSettingsProvider)
              .write(
                AppSettingsKeys.notificationSound,
                newValue ? 'true' : 'false',
              );
        },
      ),
      loading: () => const ListTile(title: Text('Notification Sound')),
      error: (_, __) => const ListTile(title: Text('Notification Sound')),
    );
  }
}

class _VibrationSwitch extends StatelessWidget {
  const _VibrationSwitch({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final vibrationAsync = ref.watch(vibrationSettingProvider);

    return vibrationAsync.when(
      data: (enabled) => SwitchListTile(
        title: const Text('Vibration'),
        subtitle: const Text('Vibrate on notify steps'),
        value: enabled,
        onChanged: (newValue) {
          ref
              .read(appSettingsProvider)
              .write(
                AppSettingsKeys.vibration,
                newValue ? 'true' : 'false',
              );
        },
      ),
      loading: () => const ListTile(title: Text('Vibration')),
      error: (_, __) => const ListTile(title: Text('Vibration')),
    );
  }
}
