import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/providers/settings_providers.dart';
import 'package:instructor/providers/tts_providers.dart';
import 'package:instructor/services/app_settings.dart';
import 'package:instructor/theme/app_branding.dart';

import 'package:instructor/widgets/profile_avatar_button.dart';

import 'widgets/activity_stats_card.dart';
import 'widgets/auth_section.dart';
import 'widgets/battery_optimization_prompt.dart';
import 'widgets/personalization_card.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_sidebar.dart';
import 'widgets/shared_settings_widgets.dart';

/// App settings screen — Profile-first layout.
///
/// Structure (top to bottom):
/// - **Profile Header** — user avatar, email, plan badge, upgrade button.
/// - **My Activity** — live plan count, session and streak placeholders.
/// - **For You** — activity level and goal personalisation chips.
/// - **Account** — sign-in / sign-out (AuthSection).
/// - **Preferences** — theme mode and default TTS voice selectors.
/// - **Audio & Speech** — speech rate, ambient volume, voice volume sliders.
/// - **Notifications** — notification sound and vibration toggles.
/// - **Battery** (Android only) — OEM battery optimisation prompt.
///
/// The account_circle AppBar icon opens the [ProfileSidebar] EndDrawer from
/// the right. A [Builder] widget is used so that [Scaffold.of(context)] resolves
/// to the correct Scaffold ancestor inside [AppBranding.brandedAppBar].
///
/// All values are read from [AppSettings] via stream providers and written back
/// via [AppSettings.write] on every user interaction.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      endDrawer: const ProfileSidebar(),
      appBar: AppBranding.brandedAppBar(
        actions: [
          Builder(
            builder: (builderContext) => ProfileAvatarButton(
              onTap: () => Scaffold.of(builderContext).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          // ── Profile Header ────────────────────────────────────────────
          const ProfileHeader(),

          // ── My Activity ───────────────────────────────────────────────
          const SectionHeader(title: 'My Activity'),
          const ActivityStatsCard(),

          // ── For You ───────────────────────────────────────────────────
          const SectionHeader(title: 'For You'),
          const PersonalizationCard(),

          // ── Account ───────────────────────────────────────────────────
          const SectionHeader(title: 'Account'),
          SettingsCard(children: [const AuthSection()]),

          // ── Preferences ───────────────────────────────────────────────
          const SectionHeader(title: 'Preferences'),
          SettingsCard(
            children: [const _ThemeModeSelector(), const _VoiceSelector()],
          ),

          // ── Audio & Speech ────────────────────────────────────────────
          const SectionHeader(title: 'Audio & Speech'),
          SettingsCard(
            children: [
              const _SpeechRateSlider(),
              const _AmbientVolumeSlider(),
              const _VoiceVolumeSlider(),
            ],
          ),

          // ── Notifications ─────────────────────────────────────────────
          const SectionHeader(title: 'Notifications'),
          SettingsCard(
            children: [
              const _NotificationSoundSwitch(),
              const _VibrationSwitch(),
            ],
          ),

          // ── Battery (Android only) ────────────────────────────────────
          if (Platform.isAndroid) ...[
            const SectionHeader(title: 'Battery'),
            SettingsCard(
              children: [const BatteryOptimizationPrompt()],
            ),
          ],

          // ── Footer ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Instructor for iOS & Android\nCrafted for The Curated Stillness',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outlineVariant,
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

