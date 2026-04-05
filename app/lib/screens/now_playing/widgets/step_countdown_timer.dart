import 'dart:async';

import 'package:flutter/material.dart';

/// A large circular countdown timer widget.
///
/// Accepts the [timeRemaining] from the engine state stream (updated ~1 Hz)
/// and smooths the display using a local 100 ms [Timer] that interpolates
/// between received values. The circular arc depletes proportionally based
/// on [totalDuration].
///
/// Displays the remaining time as MM:SS centred inside the arc.
class StepCountdownTimer extends StatefulWidget {
  const StepCountdownTimer({
    super.key,
    required this.timeRemaining,
    required this.totalDuration,
    this.color,
    this.size = 220.0,
  });

  /// Time remaining as reported by the engine (updated approximately every
  /// second). The widget interpolates locally between these snapshots.
  final Duration timeRemaining;

  /// Total duration of the current step (used to compute arc fraction).
  final Duration totalDuration;

  /// Colour of the arc indicator. Defaults to [ColorScheme.primary].
  final Color? color;

  /// Diameter of the circular timer in logical pixels.
  final double size;

  @override
  State<StepCountdownTimer> createState() => _StepCountdownTimerState();
}

class _StepCountdownTimerState extends State<StepCountdownTimer> {
  static const _tickInterval = Duration(milliseconds: 100);

  /// The displayed remaining duration — updated every tick.
  late Duration _displayed;

  /// The remaining duration at the moment of the last engine snapshot.
  late Duration _snapshotRemaining;

  /// Wall-clock time of the last snapshot reception.
  late DateTime _snapshotTime;

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _displayed = widget.timeRemaining;
    _snapshotRemaining = widget.timeRemaining;
    _snapshotTime = DateTime.now();
    _startTicker();
  }

  @override
  void didUpdateWidget(StepCountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeRemaining != widget.timeRemaining) {
      // Fresh snapshot from the engine — re-anchor the interpolation.
      _snapshotRemaining = widget.timeRemaining;
      _snapshotTime = DateTime.now();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickInterval, (_) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(_snapshotTime);
      final interpolated = _snapshotRemaining - elapsed;
      setState(() {
        _displayed = interpolated.isNegative ? Duration.zero : interpolated;
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
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
    final remainingMs = _displayed.inMilliseconds;
    final fraction = totalMs > 0
        ? (remainingMs / totalMs).clamp(0.0, 1.0)
        : 0.0;

    return Semantics(
      label: 'Time remaining: ${_formatDuration(_displayed)}',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background track arc
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 10,
                color: arcColor.withValues(alpha: 0.15),
              ),
            ),
            // Foreground progress arc
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                value: fraction,
                strokeWidth: 10,
                color: arcColor,
                strokeCap: StrokeCap.round,
              ),
            ),
            // Time label
            Text(
              _formatDuration(_displayed),
              style: TextStyle(
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
  }
}
