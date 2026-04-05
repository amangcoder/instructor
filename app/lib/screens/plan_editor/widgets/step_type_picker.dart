import 'package:flutter/material.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/theme/step_colors.dart';

/// Shows a modal bottom sheet listing all addable [StepType]s.
///
/// Returns the chosen [StepType] or null when the sheet is dismissed.
Future<StepType?> showStepTypePicker(BuildContext context) {
  return showModalBottomSheet<StepType>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _StepTypePickerSheet(),
  );
}

class _StepTypePickerSheet extends StatelessWidget {
  const _StepTypePickerSheet();

  static const _types = [
    StepType.say,
    StepType.notify,
    StepType.play,
    StepType.wait,
    StepType.repeat,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Add Step',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          ..._types.map(
            (type) => Semantics(
              button: true,
              label: '${_labelForType(type)}: ${_descForType(type)}',
              child: ListTile(
                leading: StepColors.iconForType(type, size: 24),
                title: Text(_labelForType(type)),
                subtitle: Text(
                  _descForType(type),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(type),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _labelForType(StepType type) => switch (type) {
        StepType.say => 'Say',
        StepType.notify => 'Notify',
        StepType.play => 'Play Audio',
        StepType.wait => 'Wait',
        StepType.repeat => 'Repeat Block',
        StepType.stopAudio => 'Stop Audio',
      };

  String _descForType(StepType type) => switch (type) {
        StepType.say => 'Speak text aloud using TTS',
        StepType.notify => 'Send a push notification',
        StepType.play => 'Start or change ambient audio',
        StepType.wait => 'Pause silently for a duration',
        StepType.repeat => 'Repeat a group of steps N times',
        StepType.stopAudio => 'Stop all ambient audio',
      };
}
