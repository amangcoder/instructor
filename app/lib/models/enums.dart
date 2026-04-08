/// Enumeration of all Plan step types.
enum StepType {
  say,
  notify,
  play,
  wait,
  repeat,
  stopAudio,
}

/// Enumeration of Plan categories used for filtering in the library.
enum PlanCategory {
  yoga,
  meditation,
  workout,
  cooking,
  routine,
  focus,
  custom,
}

/// Available TTS voice identifiers (Google Gemini voices + platform fallback).
enum PlanVoice {
  aoede,    // warm, clear — female (default)
  leda,     // soft, calming — female
  charon,   // deep, energetic — male
  puck,     // neutral — male
  kore,     // reserved — female
  fenrir,   // expressive — male
  platform, // device platform TTS fallback
}

/// Supported TTS locale / accent options.
enum TtsLocale {
  enIN,  // English (India)
  enGB,  // English (UK)
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
