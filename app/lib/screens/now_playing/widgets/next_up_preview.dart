import 'package:flutter/material.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/theme/step_colors.dart';

/// A compact preview row showing the next step's type icon and a summary.
///
/// Displayed below the current step text on [NowPlayingScreen]. Uses a
/// muted / subdued visual treatment so it doesn't compete with the main
/// content area.
///
/// Accepts pre-resolved text from [ExecutionState.nextStepText] so that plans
/// with [RepeatStep] blocks show the correct flattened next step rather than a
/// top-level step object.
class NextUpPreview extends StatelessWidget {
  const NextUpPreview({
    super.key,
    required this.nextStepText,
    this.nextStepType,
  });

  /// The human-readable summary of the next flattened step, or null when the
  /// current step is the last one in the plan.
  final String? nextStepText;

  /// The [StepType] of the next step (for icon/colour), or null when unknown
  /// or when there is no next step.
  final StepType? nextStepType;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (nextStepText == null) {
      return Semantics(
        label: 'Last step — no next step',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 18,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              'Last step',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      );
    }

    final text = nextStepText!;
    final stepType = nextStepType;
    final iconData = stepType != null
        ? StepColors.iconForType(stepType, size: 18).icon
        : Icons.chevron_right;
    final iconColor = stepType != null
        ? StepColors.colorForType(stepType).withValues(alpha: 0.7)
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    return Semantics(
      label: 'Next up: $text',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Next: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
          ),
          Icon(
            iconData,
            size: 18,
            color: iconColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
