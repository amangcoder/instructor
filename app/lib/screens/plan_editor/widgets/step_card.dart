import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/data/audio_assets.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/providers/tts_providers.dart';
import 'package:instructor/theme/step_colors.dart';
import 'package:instructor/widgets/voice_picker_sheet.dart';

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

// ─────────────────────────────────────────────────────────────────────────────
// Step-type editors
// ─────────────────────────────────────────────────────────────────────────────

// ── Say ───────────────────────────────────────────────────────────────────

class SayStepEditor extends ConsumerStatefulWidget {
  const SayStepEditor({required this.step, required this.onUpdate});

  final SayStep step;
  final void Function(PlanStep) onUpdate;

  @override
  ConsumerState<SayStepEditor> createState() => SayStepEditorState();
}

class SayStepEditorState extends ConsumerState<SayStepEditor> {
  late final TextEditingController _textController;

  /// The currently selected voice ID for this step.
  ///
  /// Accepts any voice ID string — not limited to the [PlanVoice] enum — so
  /// Gemini, ElevenLabs, and Kokoro voices all work correctly.
  late String _voiceId;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.step.text);
    // Accept any non-null voice ID; fall back to af_heart (Kokoro default).
    _voiceId = widget.step.voiceId ?? 'af_heart';
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    widget.onUpdate(widget.step.copyWith(text: value));
  }

  /// Opens [showVoicePickerSheet] filtered to the currently selected TTS
  /// provider and updates [_voiceId] when a new voice is confirmed.
  Future<void> _onPickVoice() async {
    const providerId = 'kokoro';
    final picked = await showVoicePickerSheet(
      context,
      providerId: providerId,
      currentVoiceId: _voiceId,
    );
    if (picked != null) {
      setState(() => _voiceId = picked.id);
      widget.onUpdate(widget.step.copyWith(voiceId: picked.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Resolve a human-readable label for the current voice ID.
    // Uses the catalog for the currently selected provider; falls back to
    // [formatVoiceId] if the voice is not yet loaded or provider changed.
    final voicesAsync = ref.watch(availableVoicesProvider);
    final voiceLabel = voicesAsync.valueOrNull
            ?.where((v) => v.id == _voiceId)
            .map((v) => v.label)
            .firstOrNull ??
        formatVoiceId(_voiceId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Semantics(
          label: 'Text to say',
          textField: true,
          child: TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'Text to say',
              hintText: 'Enter the text to be spoken aloud…',
            ),
            maxLines: null,
            minLines: 2,
            textInputAction: TextInputAction.newline,
            onChanged: _onTextChanged,
          ),
        ),
        const SizedBox(height: 8),
        // ── Per-step voice selector (opens voice picker sheet) ──────────
        Semantics(
          button: true,
          label: 'Change voice. Current voice: $voiceLabel',
          child: OutlinedButton.icon(
            onPressed: _onPickVoice,
            icon: const Icon(Icons.record_voice_over_outlined, size: 18),
            label: Text(
              voiceLabel,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              foregroundColor: colorScheme.onSurface,
              side: BorderSide(color: colorScheme.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Notify ────────────────────────────────────────────────────────────────

class NotifyStepEditor extends StatefulWidget {
  const NotifyStepEditor({required this.step, required this.onUpdate});

  final NotifyStep step;
  final void Function(PlanStep) onUpdate;

  @override
  State<NotifyStepEditor> createState() => NotifyStepEditorState();
}

class NotifyStepEditorState extends State<NotifyStepEditor> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.step.title);
    _bodyController = TextEditingController(text: widget.step.body);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _onChanged() {
    widget.onUpdate(
      widget.step.copyWith(
        title: _titleController.text,
        body: _bodyController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Semantics(
          label: 'Notification title',
          textField: true,
          child: TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. Time check',
            ),
            textInputAction: TextInputAction.next,
            onChanged: (_) => _onChanged(),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Notification body',
          textField: true,
          child: TextField(
            controller: _bodyController,
            decoration: const InputDecoration(
              labelText: 'Body',
              hintText: 'e.g. You are halfway there!',
            ),
            maxLines: null,
            minLines: 2,
            textInputAction: TextInputAction.newline,
            onChanged: (_) => _onChanged(),
          ),
        ),
      ],
    );
  }
}

// ── Play ──────────────────────────────────────────────────────────────────

/// All playable asset keys (excludes internal silence track).
const _kPlayableAssets = [
  kAmbientRain,
  kAmbientForest,
  kAmbientOcean,
  kAmbientWhiteNoise,
  kAmbientTibetanBowls,
  kEffectBell,
  kEffectChime,
  kEffectGong,
];

class PlayStepEditor extends StatefulWidget {
  const PlayStepEditor({required this.step, required this.onUpdate});

  final PlayStep step;
  final void Function(PlanStep) onUpdate;

  @override
  State<PlayStepEditor> createState() => PlayStepEditorState();
}

class PlayStepEditorState extends State<PlayStepEditor> {
  late String _audioKey;
  late bool _loop;
  late double _volume;

  @override
  void initState() {
    super.initState();
    // Ensure the asset key is a valid playable key.
    _audioKey = _kPlayableAssets.contains(widget.step.audioAssetKey)
        ? widget.step.audioAssetKey
        : kAmbientRain;
    _loop = widget.step.loop;
    _volume = widget.step.volume.clamp(0.0, 1.0);
  }

  void _push() {
    widget.onUpdate(
      widget.step.copyWith(
        audioAssetKey: _audioKey,
        loop: _loop,
        volume: _volume,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 8),

        // Audio asset dropdown
        DropdownButtonFormField<String>(
          value: _audioKey,
          decoration: const InputDecoration(labelText: 'Audio Track'),
          items: _kPlayableAssets
              .map(
                (k) => DropdownMenuItem(
                  value: k,
                  child: Text(formatAudioAssetKey(k)),
                ),
              )
              .toList(),
          onChanged: (k) {
            if (k == null) return;
            setState(() => _audioKey = k);
            _push();
          },
        ),
        const SizedBox(height: 8),

        // Loop toggle
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Loop'),
          subtitle: const Text('Repeat continuously'),
          value: _loop,
          onChanged: (v) {
            setState(() => _loop = v);
            _push();
          },
        ),

        // Volume slider
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Volume: ${(_volume * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            Semantics(
              label: 'Volume',
              slider: true,
              child: Slider.adaptive(
                value: _volume,
                min: 0,
                max: 1,
                divisions: 20,
                label: '${(_volume * 100).round()}%',
                onChanged: (v) => setState(() => _volume = v),
                onChangeEnd: (v) {
                  setState(() => _volume = v);
                  _push();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Wait ──────────────────────────────────────────────────────────────────

class WaitStepEditor extends StatefulWidget {
  const WaitStepEditor({required this.step, required this.onUpdate});

  final WaitStep step;
  final void Function(PlanStep) onUpdate;

  @override
  State<WaitStepEditor> createState() => WaitStepEditorState();
}

class WaitStepEditorState extends State<WaitStepEditor> {
  late final TextEditingController _minutesCtrl;
  late final TextEditingController _secondsCtrl;

  @override
  void initState() {
    super.initState();
    final d = widget.step.duration;
    _minutesCtrl =
        TextEditingController(text: d.inMinutes.remainder(60).toString());
    _secondsCtrl =
        TextEditingController(text: d.inSeconds.remainder(60).toString());
  }

  @override
  void dispose() {
    _minutesCtrl.dispose();
    _secondsCtrl.dispose();
    super.dispose();
  }

  void _push() {
    final minutes = int.tryParse(_minutesCtrl.text) ?? 0;
    final seconds = int.tryParse(_secondsCtrl.text) ?? 0;
    final clamped = seconds.clamp(0, 59);
    if (clamped != seconds) {
      _secondsCtrl.text = clamped.toString();
    }
    widget.onUpdate(
      widget.step.copyWith(
        duration: Duration(
          minutes: minutes.clamp(0, 9999),
          seconds: clamped,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            // Minutes
            Expanded(
              child: Semantics(
                label: 'Minutes',
                textField: true,
                child: TextField(
                  controller: _minutesCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Minutes',
                    suffixText: 'm',
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _push(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Seconds
            Expanded(
              child: Semantics(
                label: 'Seconds',
                textField: true,
                child: TextField(
                  controller: _secondsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Seconds',
                    suffixText: 's',
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => _push(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Count ────────────────────────────────────────────────────────────────

class CountStepEditor extends StatefulWidget {
  const CountStepEditor({required this.step, required this.onUpdate});

  final CountStep step;
  final void Function(PlanStep) onUpdate;

  @override
  State<CountStepEditor> createState() => _CountStepEditorState();
}

class _CountStepEditorState extends State<CountStepEditor> {
  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;
  late final TextEditingController _intervalCtrl;

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController(text: widget.step.from.toString());
    _toCtrl = TextEditingController(text: widget.step.to.toString());
    _intervalCtrl =
        TextEditingController(text: widget.step.intervalSeconds.toString());
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  void _push() {
    final from = (int.tryParse(_fromCtrl.text) ?? 1).clamp(1, 999);
    final to = (int.tryParse(_toCtrl.text) ?? 10).clamp(1, 999);
    final interval = (int.tryParse(_intervalCtrl.text) ?? 1).clamp(1, 20);
    widget.onUpdate(
      widget.step.copyWith(
        from: from,
        to: to,
        intervalSeconds: interval,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _fromCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'From',
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) => _push(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _toCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'To',
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) => _push(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _intervalCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Interval',
                  suffixText: 's',
                ),
                textInputAction: TextInputAction.done,
                onChanged: (_) => _push(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── StopAudio hint ────────────────────────────────────────────────────────

class StopAudioEditorHint extends StatelessWidget {
  const StopAudioEditorHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'This step stops all ambient audio. No configuration needed.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
