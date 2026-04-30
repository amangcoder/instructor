import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/models/plan_step.dart';
import 'package:instructor/providers/tts_providers.dart';
import 'package:instructor/widgets/voice_picker_sheet.dart';

/// Formats the voice ID as a human-readable display name.
String _formatVoiceId(String voiceId) => switch (voiceId) {
      'af_heart' => 'Heart (warm, clear)',
      'af_bella' => 'Bella (soft, calming)',
      'af_nicole' => 'Nicole (light)',
      'am_adam' => 'Adam (deep, energetic)',
      'am_michael' => 'Michael (neutral)',
      'am_eric' => 'Eric (expressive)',
      'platform' => 'Platform TTS (device)',
      _ => voiceId,
    };

/// A ConsumerStatefulWidget for editing a [SayStep].
class SayStepEditor extends ConsumerStatefulWidget {
  const SayStepEditor({required this.step, required this.onUpdate});

  final SayStep step;
  final void Function(PlanStep) onUpdate;

  @override
  ConsumerState<SayStepEditor> createState() => SayStepEditorState();
}

/// State for [SayStepEditor].
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
    // [_formatVoiceId] if the voice is not yet loaded or provider changed.
    final voicesAsync = ref.watch(availableVoicesProvider);
    final voiceLabel = voicesAsync.valueOrNull
            ?.where((v) => v.id == _voiceId)
            .map((v) => v.label)
            .firstOrNull ??
        _formatVoiceId(_voiceId);

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
