import 'package:flutter/material.dart';

// ────────────────────────────────────────────────────────────────────────────
// TtsStatusBadge
// ────────────────────────────────────────────────────────────────────────────

/// A compact badge that visualises the server-side TTS generation status for a
/// plan.
///
/// Renders one of four visual states depending on [status]:
///
/// | status              | visual                                      |
/// |---------------------|---------------------------------------------|
/// | `processing`        | Spinning progress indicator + "N/M" label  |
/// | `pending`           | Spinning progress indicator + "N/M" label  |
/// | `completed`         | Checkmark icon                              |
/// | `partial` / `failed`| Warning icon                                |
/// | `none` (or unknown) | Nothing — zero-size widget                  |
///
/// ## Usage
///
/// ```dart
/// TtsStatusBadge(
///   status: plan.ttsStatus,
///   completed: plan.ttsCompletedSteps,
///   total: plan.ttsTotalSteps,
/// )
/// ```
class TtsStatusBadge extends StatelessWidget {
  const TtsStatusBadge({
    super.key,
    required this.status,
    required this.completed,
    required this.total,
    this.onRetry,
  });

  /// Current TTS generation status string from the server.
  ///
  /// One of: `none` | `pending` | `processing` | `completed` | `partial` |
  /// `failed`.
  final String status;

  /// Number of audio segments that have been generated so far.
  final int completed;

  /// Total number of audio segments to generate for this plan.
  final int total;

  /// Optional callback invoked when the user taps the failed or partial badge.
  ///
  /// When non-null and [status] is `'failed'` or `'partial'`, the badge becomes
  /// tappable and shows a tooltip directing the user to retry TTS generation.
  final VoidCallback? onRetry;

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool get _isInProgress =>
      status == 'processing' || status == 'pending';

  bool get _isCompleted => status == 'completed';

  bool get _isWarning =>
      status == 'partial' || status == 'failed';

  /// Fractional progress in [0, 1] for the spinner value when [total] > 0.
  ///
  /// Returns `null` (indeterminate) if [total] is zero — the server hasn't
  /// yet reported the total segment count.
  double? get _progressValue {
    if (total <= 0) return null;
    return (completed / total).clamp(0.0, 1.0);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isInProgress) return _ProgressBadge(
      completed: completed,
      total: total,
      progressValue: _progressValue,
    );

    if (_isCompleted) return _IconBadge(
      icon: Icons.check_circle_outline,
      semanticLabel: 'TTS generation complete',
      colorSelector: (cs) => cs.primary,
    );

    if (_isWarning) return _IconBadge(
      icon: Icons.warning_amber_rounded,
      semanticLabel: status == 'failed'
          ? 'TTS generation failed'
          : 'TTS generation partially complete',
      colorSelector: (cs) => cs.error,
      tooltipMessage: status == 'failed'
          ? 'Generation failed — tap to retry'
          : 'Some audio failed — tap to retry remaining',
      onTap: onRetry,
    );

    // status == 'none' or any unrecognised value → render nothing.
    return const SizedBox.shrink();
  }
}

// ────────────────────────────────────────────────────────────────────────────
// _ProgressBadge — spinner + optional "N/M" progress label
// ────────────────────────────────────────────────────────────────────────────

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({
    required this.completed,
    required this.total,
    required this.progressValue,
  });

  final int completed;
  final int total;

  /// Fractional value for the progress indicator, or `null` for indeterminate.
  final double? progressValue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        );

    // Build a human-readable description for screen-reader users.
    final String semanticLabel = total > 0
        ? 'Generating TTS audio: $completed of $total complete'
        : 'TTS audio generation in progress';

    return Semantics(
      label: semanticLabel,
      // Treat the whole badge as a single non-interactive status element.
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              value: progressValue,
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          if (total > 0) ...[
            const SizedBox(width: 4),
            Text(
              '$completed/$total',
              style: labelStyle,
            ),
          ],
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// _IconBadge — single icon (checkmark or warning)
// ────────────────────────────────────────────────────────────────────────────

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.semanticLabel,
    required this.colorSelector,
    this.tooltipMessage,
    this.onTap,
  });

  final IconData icon;
  final String semanticLabel;

  /// Selects the icon colour from the current [ColorScheme].
  final Color Function(ColorScheme) colorSelector;

  /// When non-null, wraps the badge in a [Tooltip] with this message.
  final String? tooltipMessage;

  /// When non-null, wraps the badge in a [GestureDetector] with this handler.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget badge = Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: Icon(
        icon,
        size: 16,
        color: colorSelector(colorScheme),
        semanticLabel: null, // parent Semantics node carries the label
      ),
    );

    if (tooltipMessage != null) {
      badge = Tooltip(message: tooltipMessage!, child: badge);
    }

    if (onTap != null) {
      badge = GestureDetector(onTap: onTap, child: badge);
    }

    return badge;
  }
}
