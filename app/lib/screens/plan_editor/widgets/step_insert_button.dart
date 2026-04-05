import 'package:flutter/material.dart';

import 'package:instructor/models/enums.dart';

import 'step_type_picker.dart';

/// A thin "+\u200a" divider row shown between step cards and at the bottom of
/// the editor list. Tapping it opens [showStepTypePicker] and calls [onInsert]
/// with the chosen [StepType].
class StepInsertButton extends StatelessWidget {
  const StepInsertButton({
    super.key,
    required this.onInsert,
    this.afterStepIndex,
  });

  final void Function(StepType type) onInsert;

  /// When null or negative, the button represents insertion before the first
  /// step. When ≥ 0, it represents insertion after step [afterStepIndex + 1]
  /// (1-based for display).
  final int? afterStepIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;

    final semanticLabel =
        (afterStepIndex == null || afterStepIndex! < 0)
            ? 'Insert step at beginning'
            : 'Insert step after step ${afterStepIndex! + 1}';

    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: () async {
          final type = await showStepTypePicker(context);
          if (type != null) onInsert(type);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, size: 15, color: primary),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Divider(
                  color: primary.withValues(alpha: 0.2),
                  thickness: 1,
                  height: 1,
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
