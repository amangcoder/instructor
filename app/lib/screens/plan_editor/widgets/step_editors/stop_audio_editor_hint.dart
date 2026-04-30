import 'package:flutter/material.dart';

/// A simple hint widget shown when a [StopAudioStep] is expanded.
///
/// The step type requires no configuration, so we just display an informational
/// message explaining that the step stops all ambient audio.
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
