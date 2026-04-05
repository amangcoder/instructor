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

/// Available TTS voice identifiers (OpenAI voices + platform fallback).
enum PlanVoice {
  nova,      // warm, clear — good for general use
  shimmer,   // soft, calming — good for meditation
  onyx,      // deep, energetic — good for workouts
  alloy,     // neutral, professional
  echo,      // reserved, measured
  fable,     // expressive
  platform,  // device platform TTS fallback
}

/// App-wide execution status for the [PlanExecutionEngine].
enum ExecutionStatus {
  idle,
  running,
  paused,
  completed,
  error,
}
