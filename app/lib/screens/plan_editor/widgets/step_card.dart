import 'package:flutter/material.dart';

import 'package:instructor/data/audio_assets.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/theme/step_colors.dart';

import 'step_editors/step_editors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Formats [d] as a human-readable duration string (e.g. "5m 30s", "1h 10m").
String formatStepDuration(Duration d) {
  if (d == Duration.zero) return '0s';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return m > 0 ? '${h}h ${m}m' : '${h}h';
  if (m > 0) return s > 0 ? '${m}m ${s}s' : '${m}m';
  return '${s}s';
}

/// Returns a human-readable display name for the given audio asset [key].
String formatAudioAssetKey(String key) => switch (key) {
      kAmbientRain => 'Rain',
      kAmbientForest => 'Forest',
      kAmbientOcean => 'Ocean Waves',
      kAmbientWhiteNoise => 'White Noise',
      kAmbientTibetanBowls => 'Tibetan Bowls',
      kEffectBell => 'Bell',
      kEffectChime => 'Wind Chime',
      kEffectGong => 'Gong',
      _ => key,
    };

/// Returns a human-readable display name for [voiceId].
String formatVoiceId(String voiceId) => switch (voiceId) {
      'af_heart' => 'Heart (warm, clear)',
      'af_bella' => 'Bella (soft, calming)',
      'af_nicole' => 'Nicole (light)',
      'am_adam' => 'Adam (deep, energetic)',
      'am_michael' => 'Michael (neutral)',
      'am_eric' => 'Eric (expressive)',
      'platform' => 'Platform TTS (device)',
      _ => voiceId,
    };

// ─────────────────────────────────────────────────────────────────────────────
// StepCard
// ─────────────────────────────────────────────────────────────────────────────

/// A collapsible card for a single [PlanStep].
///
/// In the collapsed state it shows the step type icon, a one-line summary of
/// the step content, and the computed duration.  Tapping the card header
/// expands it in-place to reveal inline editing fields for the specific step
/// type (via [AnimatedSize]).
///
/// Drag-to-reorder is enabled via a [ReorderableDragStartListener] attached to
/// the drag-handle icon on the right side.  Long-pressing anywhere on the card
/// header triggers the [onLongPress] callback, which the parent uses to show a
/// Duplicate / Delete context menu.
class StepCard extends StatelessWidget {
  const StepCard({
    super.key,
    required this.step,
    required this.isExpanded,
    required this.dragIndex,
    required this.onToggle,
    required this.onUpdate,
    required this.onLongPress,
  });

  /// The step to display.
  final PlanStep step;

  /// Whether the card is currently expanded for inline editing.
  final bool isExpanded;

  /// The item index in the parent [ReorderableListView] used by the drag
  /// handle's [ReorderableDragStartListener].
  final int dragIndex;

  /// Called when the user taps the header to toggle expand/collapse.
  final VoidCallback onToggle;

  /// Called whenever the step data changes during inline editing.
  final void Function(PlanStep updated) onUpdate;

  /// Called on long-press of the card header (parent shows context menu).
  final VoidCallback onLongPress;

  // ── Type label helper ──────────────────────────────────────────────────────

  String get _stepTypeLabel => switch (step.type) {
        StepType.say => 'Say',
        StepType.notify => 'Notify',
        StepType.play => 'Play',
        StepType.wait => 'Wait',
        StepType.count => 'Count',
        StepType.repeat => 'Repeat',
        StepType.stopAudio => 'Stop Audio',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stepColor = StepColors.colorForType(step.type);

    return Semantics(
      label: 'Step ${dragIndex + 1}: $_stepTypeLabel — $_summaryText',
      container: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Colour accent bar (decorative — excluded from semantics) ───
            ExcludeSemantics(
              child: Container(height: 3, color: stepColor),
            ),

            // ── Collapsed header ─────────────────────────────────────────────
            GestureDetector(
              onLongPress: onLongPress,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Row(
                    children: [
                      // Step icon (decorative — label already in outer Semantics)
                      ExcludeSemantics(
                        child: StepColors.iconForType(step.type, size: 20),
                      ),
                      const SizedBox(width: 10),

                      // Summary text + duration
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _summaryText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_durationText != null)
                              Text(
                                _durationText!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Expand/collapse chevron (decorative)
                      ExcludeSemantics(
                        child: Icon(
                          isExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ),

                      // Drag handle — explicit semantic label for screen readers
                      Semantics(
                        label: 'Reorder step',
                        child: ReorderableDragStartListener(
                          index: dragIndex,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Icon(
                                Icons.drag_handle,
                                size: 20,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Inline editor (expanded only) ─────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: _buildEditor(),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Editor switcher ───────────────────────────────────────────────────────

  Widget _buildEditor() => switch (step) {
        SayStep s => SayStepEditor(step: s, onUpdate: onUpdate),
        NotifyStep n => NotifyStepEditor(step: n, onUpdate: onUpdate),
        PlayStep p => PlayStepEditor(step: p, onUpdate: onUpdate),
        WaitStep w => WaitStepEditor(step: w, onUpdate: onUpdate),
        CountStep c => CountStepEditor(step: c, onUpdate: onUpdate),
        // RepeatStep editing is handled by RepeatBlockCard; nothing here.
        RepeatStep _ => const SizedBox.shrink(),
        StopAudioStep _ => const StopAudioEditorHint(),
      };

  // ── Summary helpers ───────────────────────────────────────────────────────

  String get _summaryText => switch (step) {
        SayStep s => s.text.isEmpty ? '(empty)' : s.text,
        NotifyStep n => n.title.isEmpty ? '(untitled notification)' : n.title,
        PlayStep p => formatAudioAssetKey(p.audioAssetKey),
        WaitStep w => formatStepDuration(w.duration),
        CountStep c => '${c.from <= c.to ? 'Count' : 'Countdown'} '
            '${c.from} \u2192 ${c.to}'
            '${c.intervalSeconds > 1 ? ' (every ${c.intervalSeconds}s)' : ''}',
        RepeatStep r =>
          '×${r.count} · ${r.children.length} step${r.children.length == 1 ? '' : 's'}',
        StopAudioStep _ => 'Stop all audio',
      };

  String? get _durationText {
    final d = step.estimatedStepDuration;
    return switch (step) {
      PlayStep _ => null, // looping — no fixed duration
      _ => d == Duration.zero ? null : formatStepDuration(d),
    };
  }
}
