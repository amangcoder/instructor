import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:instructor/providers/settings_providers.dart';
import 'package:instructor/screens/settings/widgets/activity_stats_card.dart';
import 'package:instructor/screens/settings/widgets/auth_section.dart';
import 'package:instructor/screens/settings/widgets/battery_optimization_prompt.dart';
import 'package:instructor/screens/settings/widgets/profile_header.dart';
import 'package:instructor/screens/settings/widgets/profile_sidebar.dart';
import 'package:instructor/screens/settings/widgets/scheduled_triggers_card.dart';
import 'package:instructor/screens/settings/widgets/shared_settings_widgets.dart';
import 'package:instructor/services/app_settings.dart';
import 'package:instructor/theme/app_branding.dart';

/// App settings screen — Profile-first layout.
///
/// Structure (top to bottom):
/// - **Profile Header** — user avatar, email, plan badge, upgrade button.
/// - **My Activity** — live plan count, session and streak placeholders.
/// - **Account** — sign-in / sign-out (AuthSection).
/// - **Preferences** — theme mode selector.
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
    // Parent BottomNavShell uses extendBody: true, so trailing list items scroll
    // under the glassmorphic nav. Reserve enough bottom padding to clear it.
    final bottomInset = MediaQuery.of(context).padding.bottom + 96;
    return Scaffold(
      endDrawer: const ProfileSidebar(),
      appBar: AppBranding.brandedAppBar(
        actions: [
          Builder(
            builder: (builderContext) => IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More',
              onPressed: () => Scaffold.of(builderContext).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24, 8, 24, bottomInset),
        children: [
          // ── Profile Header ────────────────────────────────────────────
          const ProfileHeader(),

          // ── My Activity ───────────────────────────────────────────────
          const SectionHeader(title: 'My Activity'),
          const ActivityStatsCard(),

          // ── Scheduled Sessions (renders only when the user has any) ─────
          const ScheduledTriggersCard(),

          // ── Account ───────────────────────────────────────────────────
          const SectionHeader(title: 'Account'),
          const SettingsCard(children: [AuthSection()]),

          // ── Preferences ───────────────────────────────────────────────
          const SectionHeader(title: 'Preferences'),
          const SettingsCard(
            children: [_ThemeModeSelector()],
          ),

          // ── Audio & Speech ────────────────────────────────────────────
          const SectionHeader(title: 'Audio & Speech'),
          const SettingsCard(
            children: [
              _SpeechRateSlider(),
              _SliderDivider(),
              _AmbientVolumeSlider(),
              _SliderDivider(),
              _VoiceVolumeSlider(),
            ],
          ),

          // ── Notifications ─────────────────────────────────────────────
          const SectionHeader(title: 'Notifications'),
          const SettingsCard(
            children: [
              _NotificationSoundSwitch(),
              _VibrationSwitch(),
            ],
          ),

          // ── Battery (Android only) ────────────────────────────────────
          if (Platform.isAndroid) ...[
            const SectionHeader(title: 'Battery'),
            const SettingsCard(
              children: [BatteryOptimizationPrompt()],
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appearance', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 10),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto_rounded, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_rounded, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_rounded, size: 16),
              ),
            ],
            selected: {current},
            onSelectionChanged: (selection) {
              final mode = selection.first;
              final raw = switch (mode) {
                ThemeMode.light => 'light',
                ThemeMode.dark => 'dark',
                ThemeMode.system => 'system',
              };
              unawaited(
                ref
                    .read(appSettingsProvider)
                    .write(AppSettingsKeys.themeMode, raw),
              );
            },
          ),
        ],
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
  double? _activeValue;

  String _label(double rate) {
    if (rate == 1.0) return '1.0x';
    return '${rate.toStringAsFixed(1)}x';
  }

  @override
  Widget build(BuildContext context) {
    final rateAsync = ref.watch(speechRateSettingProvider);
    final theme = Theme.of(context);

    return rateAsync.when(
      data: (rate) {
        final display = _activeValue ?? rate;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Instruction Speed', style: theme.textTheme.bodyLarge),
                  Text(
                    _label(display),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Semantics(
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
                    unawaited(
                      ref
                          .read(appSettingsProvider)
                          .write(AppSettingsKeys.speechRate, v.toStringAsFixed(1)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
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
    final theme = Theme.of(context);

    return volumeAsync.when(
      data: (volume) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ambient Volume', style: theme.textTheme.bodyLarge),
                Text(
                  '${(volume * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Semantics(
              label: 'Ambient volume: ${(volume * 100).round()} percent',
              child: Slider(
                value: volume,
                divisions: 10,
                label: '${(volume * 100).round()}%',
                onChanged: (v) => unawaited(
                  ref
                      .read(appSettingsProvider)
                      .write(AppSettingsKeys.ambientVolume, v.toStringAsFixed(2)),
                ),
              ),
            ),
          ],
        ),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _VoiceVolumeSlider extends ConsumerWidget {
  const _VoiceVolumeSlider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumeAsync = ref.watch(voiceVolumeSettingProvider);
    final theme = Theme.of(context);

    return volumeAsync.when(
      data: (volume) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Voice Volume', style: theme.textTheme.bodyLarge),
                Text(
                  '${(volume * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Semantics(
              label: 'Voice volume: ${(volume * 100).round()} percent',
              child: Slider(
                value: volume,
                divisions: 10,
                label: '${(volume * 100).round()}%',
                onChanged: (v) => unawaited(
                  ref
                      .read(appSettingsProvider)
                      .write(AppSettingsKeys.voiceVolume, v.toStringAsFixed(2)),
                ),
              ),
            ),
          ],
        ),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
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
        onChanged: (newValue) => unawaited(
          ref.read(appSettingsProvider).write(
                AppSettingsKeys.notificationSound,
                newValue ? 'true' : 'false',
              ),
        ),
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
        onChanged: (newValue) => unawaited(
          ref.read(appSettingsProvider).write(
                AppSettingsKeys.vibration,
                newValue ? 'true' : 'false',
              ),
        ),
      ),
      loading: () => const ListTile(title: Text('Vibration')),
      error: (_, __) => const ListTile(title: Text('Vibration')),
    );
  }
}

class _SliderDivider extends StatelessWidget {
  const _SliderDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
  }
}
