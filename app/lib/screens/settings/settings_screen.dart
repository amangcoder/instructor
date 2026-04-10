import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/providers/settings_providers.dart';
import 'package:instructor/providers/tts_providers.dart';
import 'package:instructor/services/app_settings.dart';
import 'package:instructor/theme/app_branding.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBranding.brandedAppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          // ── Core Settings ──────────────────────────────────────────────
          const _SectionHeader(title: 'Core Settings'),
          _SettingsCard(
            children: [
              const AuthSection(),
              const SyncSection(),
              const _ThemeModeSelector(),
              const _TtsProviderSelector(),
              const _LocaleSelector(),
              const _VoiceSelector(),
            ],
          ),

          // ── Audio & Speech ────────────────────────────────────────────
          const _SectionHeader(title: 'Audio & Speech'),
          _SettingsCard(
            children: [
              const _SpeechRateSlider(),
              const _AmbientVolumeSlider(),
              const _VoiceVolumeSlider(),
            ],
          ),

          // ── Notifications ─────────────────────────────────────────────
          const _SectionHeader(title: 'Notifications'),
          _SettingsCard(
            children: [
              const _NotificationSoundSwitch(),
              const _VibrationSwitch(),
            ],
          ),

          // ── Battery (Android only) ────────────────────────────────────
          if (Platform.isAndroid) ...[
            const _SectionHeader(title: 'Battery'),
            _SettingsCard(
              children: [const BatteryOptimizationPrompt()],
            ),
          ],

          // ── Logout button ─────────────────────────────────────────────
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerLow,
                foregroundColor: colorScheme.error,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              child: const Text('Logout'),
            ),
          ),

          // ── Footer ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Instructor for iOS & Android\nCrafted for The Curated Stillness',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.outlineVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Stitch section header: xs font-bold uppercase tracking-[2px] text-primary.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Stitch settings group card: bg-surface-container-lowest rounded-2xl p-2.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: children,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme mode section
// ─────────────────────────────────────────────────────────────────────────────

class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(themeModeSettingProvider).valueOrNull ?? ThemeMode.system;

    const options = [
      (value: ThemeMode.system, label: 'System'),
      (value: ThemeMode.light, label: 'Light'),
      (value: ThemeMode.dark, label: 'Dark'),
    ];

    return ListTile(
      title: const Text('Appearance'),
      subtitle: const Text('App colour scheme'),
      trailing: DropdownButton<ThemeMode>(
        value: current,
        underline: const SizedBox.shrink(),
        items: options
            .map(
              (o) => DropdownMenuItem(
                value: o.value,
                child: Text(o.label),
              ),
            )
            .toList(),
        onChanged: (mode) {
          if (mode == null) return;
          final raw = switch (mode) {
            ThemeMode.light => 'light',
            ThemeMode.dark => 'dark',
            ThemeMode.system => 'system',
          };
          unawaited(
            ref.read(appSettingsProvider).write(AppSettingsKeys.themeMode, raw),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TTS Provider section
// ─────────────────────────────────────────────────────────────────────────────

class _TtsProviderSelector extends ConsumerWidget {
  const _TtsProviderSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(ttsProvidersProvider);
    final currentProvider =
        ref.watch(selectedTtsProviderProvider).valueOrNull ?? 'kokoro';

    return ListTile(
      title: const Text('TTS Provider'),
      subtitle: const Text('Service used to generate voice audio'),
      trailing: providersAsync.when(
        data: (response) {
          final providers = response.providers;
          if (providers.isEmpty) return const Text('—');
          final validId = providers.any((p) => p.id == currentProvider)
              ? currentProvider
              : providers.first.id;
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: DropdownButton<String>(
              value: validId,
              underline: const SizedBox.shrink(),
              isExpanded: true,
              items: providers
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (newProvider) {
                if (newProvider == null) return;
                ref
                    .read(appSettingsProvider)
                    .write(AppSettingsKeys.ttsProvider, newProvider);
              },
            ),
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

