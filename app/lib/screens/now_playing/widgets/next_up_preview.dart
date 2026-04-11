import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/theme/step_colors.dart';

/// Stitch "Next Up" card: bg-surface-container-low rounded-2xl p-5, with
/// icon placeholder, "Next Up" label, title, and duration.
///
/// When [nextStepText] is non-null and [onTap] is provided, the card is
/// interactive: tapping it advances the plan to the next step immediately.
/// The "FINAL STEP" variant (nextStepText == null) is never tappable.
class NextUpPreview extends StatelessWidget {
  const NextUpPreview({
    super.key,
    required this.nextStepText,
    this.nextStepType,
    this.onTap,
  });

  final String? nextStepText;
  final StepType? nextStepType;

  /// Called when the user taps the card to skip to the next step.
  /// Only used when [nextStepText] is non-null (i.e. there is a next step).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (nextStepText == null) {
      // ── FINAL STEP variant — not tappable ──────────────────────────────────
      return Semantics(
        label: 'Last step — no next step',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FINAL STEP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: colorScheme.primary.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last step in this session',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final text = nextStepText!;
    final stepType = nextStepType;
    final isTappable = onTap != null;

    // ── Card content ─────────────────────────────────────────────────────────
    final cardContent = Row(
      children: [
        // 56x56 icon placeholder
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: stepType != null
              ? StepColors.iconForType(stepType, size: 24)
              : Icon(Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 16),
        // Title + "Next Up" label
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEXT UP',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // ── Tap affordance arrow shown when interactive ─────────────────────
        if (isTappable) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: colorScheme.primary.withValues(alpha: 0.5),
          ),
        ],
      ],
    );

    // ── NEXT UP variant — tappable when onTap is provided ────────────────────
    if (isTappable) {
      return Semantics(
        label: 'Next up: $text',
        button: true,
        hint: 'Tap to skip to next step',
        child: Material(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: colorScheme.primary.withValues(alpha: 0.12),
            highlightColor: colorScheme.primary.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: cardContent,
            ),
          ),
        ),
      );
    }

    // Non-interactive fallback (onTap not provided).
    return Semantics(
      label: 'Next up: $text',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: cardContent,
      ),
    );
  }
}
