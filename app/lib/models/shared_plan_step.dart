/// A lightweight representation of a single step in a shared plan preview.
///
/// Used by [SharedPlanPreviewScreen] to display step type and duration.
/// Constructed from raw JSON maps returned by the backend, or instantiated
/// directly in tests.
library shared_plan_step;

/// A single step within a [SharedPlanPreview].
///
/// Fields mirror the minimal step data returned by the public shared-plan
/// endpoint — full step details (e.g. nested repeat blocks) are not included.
class SharedPlanStep {
  const SharedPlanStep({
    required this.type,
    this.text,
    this.estimatedDurationMs,
  });

  /// Step type string (e.g. `'say'`, `'wait'`, `'repeat'`).
  final String type;

  /// Optional step label / TTS text.
  final String? text;

  /// Estimated duration for this step in milliseconds, if provided.
  final int? estimatedDurationMs;

  /// Parses a [SharedPlanStep] from a raw JSON map.
  ///
  /// Gracefully handles missing or unexpected keys, falling back to safe
  /// defaults so preview rendering never crashes on malformed data.
  factory SharedPlanStep.fromMap(Map<String, dynamic> map) {
    return SharedPlanStep(
      type: map['type'] as String? ?? map['stepType'] as String? ?? 'say',
      text: map['text'] as String? ?? map['name'] as String?,
      estimatedDurationMs:
          (map['estimatedDurationMs'] as num?)?.toInt() ??
          (map['durationMs'] as num?)?.toInt(),
    );
  }

  /// Returns a human-readable label for this step's type.
  String get typeLabel {
    return switch (type.toLowerCase()) {
      'say' => 'Audio',
      'wait' => 'Rest',
      'repeat' => 'Repeat',
      'timer' => 'Timer',
      _ => type[0].toUpperCase() + type.substring(1),
    };
  }

  @override
  String toString() => 'SharedPlanStep(type: $type, text: $text, '
      'estimatedDurationMs: $estimatedDurationMs)';
}
