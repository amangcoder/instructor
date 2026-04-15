/// SessionCompletion — immutable record of a completed plan session.
///
/// Persisted to the local Drift database and synced to the server for
/// cross-device streak consistency.
library session_completion;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_completion.freezed.dart';
part 'session_completion.g.dart';

/// A session completion record.
///
/// This record is created when [PlanExecutionEngine] transitions to completed
/// status, and is persisted to the [SessionCompletionStore] for later
/// streak calculation and server sync.
@freezed
class SessionCompletion with _$SessionCompletion {
  const SessionCompletion._();

  const factory SessionCompletion({
    /// Unique identifier for this completion record (e.g., UUID or auto-generated).
    required String id,

    /// ID of the plan that was completed.
    required String planId,

    /// UTC timestamp when the session was completed.
    required DateTime completedAt,

    /// Duration of the session in milliseconds.
    required int durationMs,

    /// True if this completion has been synced to the server.
    /// Used to identify unsynced records for the sync service.
    required bool synced,
  }) = _SessionCompletion;

  factory SessionCompletion.fromJson(Map<String, dynamic> json) =>
      _$SessionCompletionFromJson(json);
}
