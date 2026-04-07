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
