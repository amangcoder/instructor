import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/models/tts_provider_config.dart';
import 'package:instructor/providers/settings_providers.dart';
import 'package:instructor/providers/tts_providers.dart';
import 'package:instructor/repositories/plan_repository.dart';
import 'package:instructor/services/app_settings.dart';
import 'widgets/auth_section.dart';
import 'widgets/battery_optimization_prompt.dart';
import 'widgets/sync_section.dart';

/// App settings screen.
///
/// Sections:
/// - **Voice** — default TTS voice selector (aoede / charon / etc.).
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
          // ── Account ───────────────────────────────────────────────────────
          _SectionHeader(title: 'Account'),
          const AuthSection(),

          // ── Sync ──────────────────────────────────────────────────────────
          _SectionHeader(title: 'Sync'),
          const SyncSection(),

          // ── TTS Provider ─────────────────────────────────────────────────
          _SectionHeader(title: 'TTS Provider'),
          const _ProviderSelector(),

          // ── Locale ────────────────────────────────────────────────────────
          _SectionHeader(title: 'Language'),
          const _LocaleSelector(),

          // ── Voice ───────────────────────────────────────────────────────
          _SectionHeader(title: 'Voice'),
          const _VoiceSelector(),

          // ── Speed ──────────────────────────────────────────────────────
          _SectionHeader(title: 'Speed'),
          const _SpeechRateSlider(),

          // ── Volume ──────────────────────────────────────────────────────
          _SectionHeader(title: 'Volume'),
          const _AmbientVolumeSlider(),
          const _VoiceVolumeSlider(),

          // ── Notifications ───────────────────────────────────────────────
          _SectionHeader(title: 'Notifications'),
          const _NotificationSoundSwitch(),
          const _VibrationSwitch(),

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
// TTS Provider selector (dynamic — fetched from API)
// ─────────────────────────────────────────────────────────────────────────────

class _ProviderSelector extends ConsumerWidget {
  const _ProviderSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(ttsProvidersProvider);
    final selectedAsync = ref.watch(selectedTtsProviderProvider);

    final currentId = selectedAsync.valueOrNull ?? 'gemini';

    return ListTile(
      title: const Text('TTS Provider'),
      subtitle: const Text('Service used to generate voice audio'),
      trailing: providersAsync.when(
        data: (response) {
          final providers = response.providers;
          if (providers.isEmpty) return const Text('—');
          // Ensure current value exists in list (fallback to first).
          final validId = providers.any((p) => p.id == currentId)
              ? currentId
              : providers.first.id;
          return DropdownButton<String>(
            value: validId,
            underline: const SizedBox.shrink(),
            items: providers
                .map(
                  (p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(p.label),
                  ),
                )
                .toList(),
            onChanged: (newId) async {
              if (newId == null) return;
              final settings = ref.read(appSettingsProvider);
              await settings.write(
                  TtsProviderSettingsKeys.ttsProvider, newId);

              final newProvider = response.providers
                  .cast<TtsProviderConfig?>()
                  .firstWhere((p) => p!.id == newId,
                      orElse: () => null);
              if (newProvider != null) {
                // Remap all plan voices to the new provider's equivalents.
                if (newProvider.voiceMap.isNotEmpty) {
                  final repo = ref.read(planRepositoryProvider);
                  await repo.remapPlanVoices(newProvider.voiceMap);
                }
                // Update the default voice setting to the mapped equivalent,
                // or fall back to the first voice of the new provider.
                final currentVoice = await settings.read(
                    AppSettingsKeys.defaultVoice);
                final mappedVoice = currentVoice != null
                    ? newProvider.voiceMap[currentVoice]
                    : null;
                await settings.write(
                    AppSettingsKeys.defaultVoice,
                    mappedVoice ?? newProvider.voices.firstOrNull?.id ?? '');
              }
              ref.invalidate(selectedTtsProviderProvider);
            },
          );
        },
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
// Locale section (dynamic — fetched from API based on selected provider)
// ─────────────────────────────────────────────────────────────────────────────

class _LocaleSelector extends ConsumerWidget {
  const _LocaleSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localesAsync = ref.watch(availableLocalesProvider);
    final currentLocaleStr =
        ref.watch(rawTtsLocaleSettingProvider).valueOrNull ?? 'en-IN';

    return ListTile(
      title: const Text('TTS Accent'),
      subtitle: const Text('Language/accent used for voice instructions'),
      trailing: localesAsync.when(
        data: (locales) {
          if (locales.isEmpty) return const Text('—');
          // Ensure current value is in list.
          final validId = locales.any((l) => l.id == currentLocaleStr)
              ? currentLocaleStr
              : locales.first.id;
          return DropdownButton<String>(
            value: validId,
            underline: const SizedBox.shrink(),
            items: locales
                .map(
                  (l) => DropdownMenuItem(
                    value: l.id,
                    child: Text(l.label),
                  ),
                )
                .toList(),
            onChanged: (newLocale) {
              if (newLocale == null) return;
              ref
                  .read(appSettingsProvider)
                  .write(AppSettingsKeys.ttsLocale, newLocale);
            },
          );
        },
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
// Voice section (dynamic — fetched from API based on selected provider)
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceSelector extends ConsumerWidget {
  const _VoiceSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voicesAsync = ref.watch(availableVoicesProvider);
    final currentVoiceStr =
        ref.watch(rawVoiceSettingProvider).valueOrNull ?? 'aoede';

    return ListTile(
      title: const Text('Default TTS Voice'),
      subtitle: const Text('Voice used for all Say steps'),
      trailing: voicesAsync.when(
        data: (voices) {
          if (voices.isEmpty) return const Text('—');
          // Ensure current value is in list — if the stored voice
          // doesn't exist for this provider, persist the fallback so
          // synthesis never sends an invalid voice ID.
          final validId = voices.any((v) => v.id == currentVoiceStr)
              ? currentVoiceStr
              : voices.first.id;
          if (validId != currentVoiceStr) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref
                  .read(appSettingsProvider)
                  .write(AppSettingsKeys.defaultVoice, validId);
            });
          }
          return DropdownButton<String>(
            value: validId,
            underline: const SizedBox.shrink(),
            items: voices
                .map(
                  (v) => DropdownMenuItem(
                    value: v.id,
                    child: Text(v.label),
                  ),
                )
                .toList(),
            onChanged: (newVoice) {
              if (newVoice == null) return;
              ref
                  .read(appSettingsProvider)
                  .write(AppSettingsKeys.defaultVoice, newVoice);
            },
          );
        },
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
// Speed section
// ─────────────────────────────────────────────────────────────────────────────

class _SpeechRateSlider extends ConsumerStatefulWidget {
  const _SpeechRateSlider();

  @override
  ConsumerState<_SpeechRateSlider> createState() => _SpeechRateSliderState();
}

class _SpeechRateSliderState extends ConsumerState<_SpeechRateSlider> {
  /// Non-null while the user is actively dragging.
  double? _activeValue;

  String _label(double rate) {
    if (rate == 1.0) return '1.0x (Normal)';
    return '${rate.toStringAsFixed(1)}x';
  }

  @override
  Widget build(BuildContext context) {
    final rateAsync = ref.watch(speechRateSettingProvider);

    return rateAsync.when(
      data: (rate) {
        final display = _activeValue ?? rate;
        return ListTile(
          title: const Text('Instruction Speed'),
          subtitle: Semantics(
            label: 'Speech rate: ${_label(display)}',
            child: Slider(
              value: display,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: _label(display),
              onChanged: (v) => setState(() => _activeValue = v),
              onChangeEnd: (v) {
                setState(() => _activeValue = null);
                ref
                    .read(appSettingsProvider)
                    .write(
                      AppSettingsKeys.speechRate,
                      v.toStringAsFixed(1),
                    );
              },
            ),
          ),
        );
      },
      loading: () => const ListTile(
        title: Text('Instruction Speed'),
        subtitle: LinearProgressIndicator(),
      ),
      error: (_, __) => const ListTile(title: Text('Instruction Speed')),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Volume section
// ─────────────────────────────────────────────────────────────────────────────

class _AmbientVolumeSlider extends ConsumerWidget {
  const _AmbientVolumeSlider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class _VoiceVolumeSlider extends ConsumerWidget {
  const _VoiceVolumeSlider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class _NotificationSoundSwitch extends ConsumerWidget {
  const _NotificationSoundSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class _VibrationSwitch extends ConsumerWidget {
  const _VibrationSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

