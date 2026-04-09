import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A large circular countdown timer widget.
///
/// Uses an [AnimationController] to drive a smooth 60 fps arc depletion from
/// 1.0 → 0.0 over [totalDuration]. Engine snapshots ([timeRemaining]) arrive
/// at ~1 Hz and are used for drift correction rather than hard resets, ensuring
/// the arc never visually "jumps" between seconds.
///
/// Displays the remaining time as MM:SS centred inside the arc.
class StepCountdownTimer extends StatefulWidget {
  const StepCountdownTimer({
    super.key,
    required this.timeRemaining,
    required this.totalDuration,
    this.isPaused = false,
    this.color,
    this.size = 220.0,
  });

  /// Time remaining as reported by the engine (updated approximately every
  /// second). Used for drift correction against the animation controller.
  final Duration timeRemaining;

  /// Total duration of the current step (used to compute arc fraction).
  final Duration totalDuration;

  /// Whether the session is currently paused. Stops/starts the animation.
  final bool isPaused;

  /// Colour of the arc indicator. Defaults to [ColorScheme.primary].
  final Color? color;

  /// Diameter of the circular timer in logical pixels.
  final double size;

  @override
  State<StepCountdownTimer> createState() => _StepCountdownTimerState();
}

class _StepCountdownTimerState extends State<StepCountdownTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _initializeAnimation();
  }

  @override
  void didUpdateWidget(StepCountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final stepChanged = widget.totalDuration != oldWidget.totalDuration;
    final pauseChanged = widget.isPaused != oldWidget.isPaused;

    // Detect a skip to a step with the same totalDuration: timeRemaining
    // jumps UP significantly (more than 1 second).
    final jumpedBackward =
        widget.timeRemaining > oldWidget.timeRemaining + const Duration(seconds: 1);

    if (stepChanged || jumpedBackward) {
      _initializeAnimation();
      return;
    }

    if (pauseChanged) {
      if (widget.isPaused) {
        _controller.stop();
      } else {
        _syncAndResume();
      }
      return;
    }

    // Engine snapshot (drift correction) — only when running.
    if (widget.timeRemaining != oldWidget.timeRemaining && !widget.isPaused) {
      _applyDriftCorrection();
    }
  }

  /// Configures the animation controller for the current step's remaining time.
  void _initializeAnimation() {
    final totalMs = widget.totalDuration.inMilliseconds;
    if (totalMs <= 0) {
      // Instant step: show full arc, no animation.
      _controller
        ..duration = const Duration(seconds: 1) // non-zero required
        ..value = 1.0;
      _controller.stop();
      return;
    }

    final remainingMs = widget.timeRemaining.inMilliseconds.clamp(0, totalMs);
    final fraction = remainingMs / totalMs;

    _controller.duration = widget.totalDuration;
    _controller.value = fraction;

    if (!widget.isPaused && fraction > 0.0) {
      // reverse() drives value from current → 0.0. Since duration is the full
      // step duration, it takes (fraction * duration) ms = remainingMs.
      _controller.reverse(from: fraction);
    }
  }

  /// Corrects for drift between the animation and the engine's ground truth.
  /// Only applies a correction when drift exceeds ~150 ms worth of arc fraction
  /// to avoid perceptible jumps.
  void _applyDriftCorrection() {
    final totalMs = widget.totalDuration.inMilliseconds;
    if (totalMs <= 0) return;

    final engineFraction =
        (widget.timeRemaining.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final controllerFraction = _controller.value;
    final drift = (engineFraction - controllerFraction).abs();

    // 150 ms worth of fraction as threshold.
    final threshold = 150 / totalMs;

    if (drift > threshold) {
      _controller.reverse(from: engineFraction);
    }
  }

  /// Re-syncs the controller to the engine's timeRemaining and resumes.
  void _syncAndResume() {
    final totalMs = widget.totalDuration.inMilliseconds;
    if (totalMs <= 0) return;

    final fraction =
        (widget.timeRemaining.inMilliseconds / totalMs).clamp(0.0, 1.0);

    if (fraction <= 0.0) {
      _controller.value = 0.0;
      return;
    }

    _controller.reverse(from: fraction);
  }

  /// Derives the displayed remaining duration from the controller value.
  Duration _displayedDuration() {
    final totalMs = widget.totalDuration.inMilliseconds;
    if (totalMs <= 0) return widget.timeRemaining;
    final remainingMs = (_controller.value * totalMs).round();
    return Duration(milliseconds: remainingMs.clamp(0, totalMs));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Formats [duration] as MM:SS.
  String _formatDuration(Duration d) {
    final total = d.inSeconds.clamp(0, 999 * 60 + 59);
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final arcColor = widget.color ?? colorScheme.primary;
    final totalMs = widget.totalDuration.inMilliseconds;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final fraction = totalMs > 0 ? _controller.value : 1.0;
        final displayed = _displayedDuration();

        return Semantics(
          label: 'Time remaining: ${_formatDuration(displayed)}',
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Center circle background (surface-container-lowest)
                Container(
                  width: widget.size - 16,
                  height: widget.size - 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.surfaceContainerLowest,
                  ),
                ),
                // Background track arc (thin 2px per Stitch spec)
                SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 2,
                    color: arcColor.withValues(alpha: 0.15),
                  ),
                ),
                // Foreground progress arc (thin 2px precision ring)
                SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: 2,
                    color: arcColor,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Time label (Manrope font for editorial authority)
                Text(
                  _formatDuration(displayed),
                  style: GoogleFonts.manrope(
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1,
                    color: colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
