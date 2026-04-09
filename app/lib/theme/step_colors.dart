import 'package:flutter/material.dart';

import 'package:instructor/models/enums.dart';

/// Color palette for each [StepType] used across the Plan Editor and
/// Now Playing screens to give each step a visually distinct identity.
///
/// ## Design rationale
/// | Type       | Color  | Reasoning                                      |
/// |------------|--------|------------------------------------------------|
/// | wait       | Blue   | Calm, passive — nothing is happening yet       |
/// | say        | Green  | Positive action — voice plays                  |
/// | notify     | Orange | Attention-seeking but non-urgent               |
/// | play       | Purple | Creative / ambient audio mood                  |
/// | repeat     | Red    | Loop / warning that something will repeat      |
/// | stopAudio  | Grey   | Neutral end-of-audio action                    |
abstract final class StepColors {
  /// Returns the primary [Color] associated with [type].
  ///
  /// Use [colorForType] when you only need the colour value.
  /// Use [cardColorForType] for a lighter, on-surface variant suitable
  /// for card backgrounds.
  static Color colorForType(StepType type) => switch (type) {
        StepType.wait => _wait,
        StepType.say => _say,
        StepType.notify => _notify,
        StepType.play => _play,
        StepType.repeat => _repeat,
        StepType.stopAudio => _stopAudio,
      };

  /// Returns a lighter card-background tint for [type].
  ///
  /// The tint is blended from the base color at 12 % opacity over white so
  /// it remains legible in both light and dark themes when overlaid on the
  /// surface colour.
  static Color cardColorForType(StepType type) =>
      colorForType(type).withValues(alpha: 0.12);

  /// Returns an [Icon] widget pre-styled with the correct colour and a
  /// semantically appropriate icon data for [type].
  static Icon iconForType(StepType type, {double size = 20}) => Icon(
        _iconDataForType(type),
        color: colorForType(type),
        size: size,
      );

  // ────────────────────────────────────────────────────────────────────────────
  // Private palette (harmonized for light-theme "Curated Stillness" design)
  // ────────────────────────────────────────────────────────────────────────────

  static const Color _wait = Color(0xFF1565C0); // Deep blue (calm)
  static const Color _say = Color(0xFF2E7D32); // Deep green (positive voice)
  static const Color _notify = Color(0xFFE65100); // Deep orange (attention)
  static const Color _play = Color(0xFF6A1B9A); // Deep purple (ambient)
  static const Color _repeat = Color(0xFFC62828); // Deep red (loop/warning)
  static const Color _stopAudio = Color(0xFF546E7A); // Blue-grey (neutral end)

  static IconData _iconDataForType(StepType type) => switch (type) {
        StepType.wait => Icons.timer_outlined,
        StepType.say => Icons.record_voice_over_outlined,
        StepType.notify => Icons.notifications_outlined,
        StepType.play => Icons.music_note_outlined,
        StepType.repeat => Icons.repeat,
        StepType.stopAudio => Icons.stop_circle_outlined,
      };
}
