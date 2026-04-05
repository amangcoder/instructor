/// Utility for formatting [Duration] values into human-readable strings.
///
/// Used by the Plan Editor (total plan duration header) and the Now Playing
/// screen (time-remaining counter).
abstract final class DurationFormatter {
  /// Formats [duration] as `Xh Ym Zs`.
  ///
  /// Components with a zero value are **omitted** unless [duration] is zero
  /// itself (in which case `'0s'` is returned):
  ///
  /// ```dart
  /// formatHms(Duration(hours: 1, minutes: 30, seconds: 0)) // → '1h 30m'
  /// formatHms(Duration(minutes: 2, seconds: 45))           // → '2m 45s'
  /// formatHms(Duration(seconds: 10))                       // → '10s'
  /// formatHms(Duration.zero)                               // → '0s'
  /// ```
  ///
  /// Negative durations are treated as zero.
  static String formatHms(Duration duration) {
    if (duration.isNegative || duration == Duration.zero) return '0s';

    // Round down to whole seconds.
    final totalSeconds = duration.inSeconds;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;

    final buffer = StringBuffer();
    if (h > 0) buffer.write('${h}h ');
    if (m > 0) buffer.write('${m}m ');
    if (s > 0) buffer.write('${s}s');

    // If only hours and/or minutes are present with zero seconds, trim the
    // trailing space left by the last non-zero component.
    return buffer.toString().trimRight();
  }

  /// Formats [duration] as a compact `MM:SS` clock string.
  ///
  /// Hours are prepended as `H:MM:SS` when `duration >= 1 hour`.
  /// Useful for countdowns in the Now Playing screen.
  ///
  /// ```dart
  /// formatClock(Duration(minutes: 5, seconds: 7))           // → '05:07'
  /// formatClock(Duration(hours: 1, minutes: 0, seconds: 3)) // → '1:00:03'
  /// ```
  ///
  /// Negative durations are treated as zero.
  static String formatClock(Duration duration) {
    if (duration.isNegative) duration = Duration.zero;

    final totalSeconds = duration.inSeconds;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;

    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');

    if (h > 0) return '$h:$mm:$ss';
    return '$mm:$ss';
  }
}
