/// VoiceValidationDialog — shown when a plan's voice ID is incompatible with
/// the currently selected TTS provider.
///
/// ## Behaviour
///
/// When [showVoiceValidationDialog] is called with a mismatched [voiceId] and
/// [providerId], an [AlertDialog] is presented that:
///
/// 1. Explains the mismatch in plain language.
/// 2. Offers a **Select Voice** button that opens [showVoicePickerSheet]
///    filtered to [providerId].
/// 3. Offers a **Cancel** button that dismisses the dialog without making any
///    changes.
///
/// Returns the [TtsVoiceOption] chosen by the user, or `null` if the user
/// cancels (synthesis should be skipped / plan should not be modified).
///
/// ## Usage
///
/// ```dart
/// final newVoice = await showVoiceValidationDialog(
///   context,
///   voiceId: 'af_heart',
///   providerId: 'gemini',
///   providerLabel: 'Gemini',
/// );
/// if (newVoice != null) {
///   // Retry synthesis with newVoice.id
/// } else {
///   // User cancelled — skip or abort.
/// }
/// ```
library voice_validation_dialog;

import 'package:flutter/material.dart';

import 'package:instructor/models/tts_provider_config.dart';
import 'package:instructor/widgets/voice_picker_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the voice-validation dialog for a single [voiceId]/[providerId]
/// mismatch.
///
/// Returns the [TtsVoiceOption] selected by the user, or `null` if they
/// cancelled.
///
/// [providerLabel] is the human-readable name of the provider shown in the
/// dialog body (e.g. `'Gemini'`, `'Kokoro'`).  Falls back to [providerId]
/// if omitted.
Future<TtsVoiceOption?> showVoiceValidationDialog(
  BuildContext context, {
  required String voiceId,
  required String providerId,
  String? providerLabel,
}) async {
  if (!context.mounted) return null;

  final result = await showDialog<_DialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _VoiceValidationDialog(
      voiceId: voiceId,
      providerId: providerId,
      providerLabel: providerLabel ?? providerId,
    ),
  );

  if (result == null || result.cancelled) return null;

  // User tapped "Select Voice" — open the voice picker filtered to the
  // provider.
  if (!context.mounted) return null;
  return showVoicePickerSheet(
    context,
    providerId: providerId,
  );
}

/// Result type returned by [_VoiceValidationDialog].
class _DialogResult {
  const _DialogResult({required this.cancelled});
  final bool cancelled;
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog widget
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceValidationDialog extends StatelessWidget {
  const _VoiceValidationDialog({
    required this.voiceId,
    required this.providerId,
    required this.providerLabel,
  });

  final String voiceId;
  final String providerId;
  final String providerLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      icon: Icon(
        Icons.mic_off_outlined,
        color: colorScheme.error,
        size: 28,
      ),
      title: const Text('Voice not available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mismatch explanation.
          RichText(
            text: TextSpan(
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
              children: [
                TextSpan(
                  text: "'$voiceId'",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.error,
                  ),
                ),
                const TextSpan(text: ' is not available in '),
                TextSpan(
                  text: providerLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const TextSpan(text: '. Select a compatible voice.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Contextual hint.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The voice picker will show only voices supported by '
                    '$providerLabel.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const _DialogResult(cancelled: true),
          ),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(
            const _DialogResult(cancelled: false),
          ),
          icon: const Icon(Icons.mic, size: 18),
          label: const Text('Select Voice'),
        ),
      ],
    );
  }
}
