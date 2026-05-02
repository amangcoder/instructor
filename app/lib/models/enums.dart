/// Enumeration of all Plan step types.
enum StepType {
  say,
  notify,
  play,
  wait,
  count,
  repeat,
  stopAudio,
}

/// Available TTS voice identifiers (Kokoro voices + platform fallback).
enum TtsVoiceId {
  af_heart,   // warm, clear — female US (default)
  af_bella,   // soft, calming — female US
  af_nicole,  // light — female US
  am_adam,    // deep, energetic — male US
  am_michael, // neutral — male US
  am_eric,    // expressive — male US
  platform,   // device platform TTS fallback
}

/// Supported TTS locale / accent options.
enum TtsLocale {
  enIN,  // English (India)
  enGB,  // English (UK)
  hi,    // Hindi
}

/// App-wide execution status for the [PlanExecutionEngine].
enum ExecutionStatus {
  idle,
  running,
  paused,
  completed,
  error,
}

/// Sub-phase within the currently executing step.
///
/// Used by the Now Playing UI to show contextual overlays (e.g. a loading
/// spinner while TTS audio is being fetched from the backend).
enum StepPhase {
  /// The step is actively executing (default for all step types).
  active,

  /// TTS audio is being fetched from the backend (cache miss).
  /// The UI should show a loading indicator overlay.
  loadingTts,

  /// An ambient sound just started playing. The UI displays the ambient
  /// track info for a brief period before advancing to the next step.
  ambientDisplay,
}
