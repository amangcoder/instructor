import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/models/plan_voice.dart';
import 'package:instructor/models/voice.dart';
import 'package:instructor/providers/categories_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VoicePickerWidget
// ─────────────────────────────────────────────────────────────────────────────

/// Inline widget that displays available voice renditions for a plan and lets
/// the user choose which voice to use for playback.
///
/// The widget is driven by:
/// - [planId] — to read/write [selectedVoiceProvider].
/// - [planVoices] — the plan's synthesised voice list from the plan tree.
///
/// ### Behaviour
/// - Only voices with `status = 'ready'` are shown as selectable options.
/// - If no voices are ready, a "Platform TTS" fallback notice is shown instead.
/// - Tapping a voice chip calls `selectedVoiceProvider(planId).notifier.select()`
///   which persists the choice in memory for the session (REQ-020).
/// - Tapping the "Clear" / already-selected chip de-selects the voice and falls
///   back to platform TTS.
class VoicePickerWidget extends ConsumerWidget {
  const VoicePickerWidget({
    super.key,
    required this.planId,
    required this.planVoices,
  });

  final String planId;

  /// The plan's synthesised voice entries — a subset of [PlanVoice] whose
  /// `status` may be `pending | processing | ready | failed`.
  final List<PlanVoice> planVoices;

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns only the plan voices that are ready for playback.
  List<PlanVoice> get _readyVoices =>
      planVoices.where((v) => v.status == 'ready').toList();

  /// Converts a [PlanVoice] to a minimal [Voice] suitable for display and
  /// storage inside [selectedVoiceProvider].
  ///
  /// The `displayName` is derived by splitting the voice slug on underscores
  /// and capitalising each segment, e.g. `af_bella` → `Af Bella`.
  static Voice voiceFromPlanVoice(PlanVoice pv) {
    final parts = pv.voiceId.split('_').map((s) {
      if (s.isEmpty) return s;
      return s[0].toUpperCase() + s.substring(1);
    }).toList();

    return Voice(
      id: pv.voiceId,
      slug: pv.voiceId,
      displayName: parts.join(' '),
      locale: pv.locale,
      provider: 'kokoro',
      isPublished: true,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedVoice = ref.watch(selectedVoiceProvider(planId));
    final ready = _readyVoices;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section label ──────────────────────────────────────────────────
        Text(
          'VOICE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colorScheme.outline,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),

        if (ready.isEmpty) ...[
          // ── No voices ready — platform TTS notice ─────────────────────
          _PlatformTtsNotice(colorScheme: colorScheme),
        ] else ...[
          // ── Voice option chips ─────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Platform TTS option is always available.
              _VoiceChip(
                label: 'Platform TTS',
                icon: Icons.phone_android_outlined,
                isSelected: selectedVoice == null,
                onTap: () => ref
                    .read(selectedVoiceProvider(planId).notifier)
                    .select(null),
              ),

              // One chip per ready voice.
              for (final pv in ready)
                _VoiceChip(
                  label: voiceFromPlanVoice(pv).displayName,
                  icon: Icons.auto_awesome_outlined,
                  subtitle: pv.locale,
                  isSelected: selectedVoice?.id == pv.voiceId,
                  onTap: () {
                    final voice = voiceFromPlanVoice(pv);
                    ref
                        .read(selectedVoiceProvider(planId).notifier)
                        .select(voice);
                  },
                ),
            ],
          ),

          // ── Selected voice info ──────────────────────────────────────
          const SizedBox(height: 8),
          _SelectedVoiceInfo(
            selectedVoice: selectedVoice,
            colorScheme: colorScheme,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _VoiceChip
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceChip extends StatelessWidget {
  const _VoiceChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final IconData icon;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '$label voice option',
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.7,
                              )
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PlatformTtsNotice
// ─────────────────────────────────────────────────────────────────────────────

class _PlatformTtsNotice extends StatelessWidget {
  const _PlatformTtsNotice({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.phone_android_outlined,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Platform TTS — no AI voice available for this plan.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SelectedVoiceInfo
// ─────────────────────────────────────────────────────────────────────────────

class _SelectedVoiceInfo extends StatelessWidget {
  const _SelectedVoiceInfo({
    required this.selectedVoice,
    required this.colorScheme,
  });

  final Voice? selectedVoice;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final label = selectedVoice == null
        ? 'Using device voice'
        : 'Using AI voice: ${selectedVoice!.displayName}';

    return Text(
      label,
      style: TextStyle(fontSize: 12, color: colorScheme.outline),
    );
  }
}
