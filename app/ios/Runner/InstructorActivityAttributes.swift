// InstructorActivityAttributes.swift
// TASK-014: ActivityKit attributes for Live Activity / Dynamic Island.
//
// Defines the static and dynamic state for the Instructor Live Activity.
// Static attributes are set at activity start and don't change.
// ContentState is the mutable portion updated during session execution.

import ActivityKit
import Foundation

/// Attributes for the Instructor plan execution Live Activity.
///
/// These are the immutable properties set when the activity starts.
struct InstructorActivityAttributes: ActivityAttributes {

    /// Plan name shown in the Live Activity header.
    let planName: String

    /// Total number of steps in the plan.
    let totalSteps: Int

    /// The dynamic content state that changes during execution.
    ///
    /// Updated via ActivityKit when:
    /// - Step transitions occur
    /// - User pauses/resumes
    /// - Timer ticks (time remaining)
    /// - Session completes
    struct ContentState: Codable, Hashable {
        /// Name/text of the current step being executed.
        let stepName: String

        /// 0-based index of the current step.
        let stepIndex: Int

        /// Time remaining in the current step (milliseconds).
        let timeRemainingMs: Int

        /// Execution status: "playing", "paused", "completed"
        let status: String

        /// Whether this is the final state (session completed).
        var isCompleted: Bool {
            status == "completed"
        }

        /// Progress fraction (0.0 to 1.0) based on step index.
        var progress: Double {
            guard stepIndex >= 0 else { return 0.0 }
            let total = max(1, stepIndex + 1)  // Avoid division by zero
            return Double(stepIndex + 1) / Double(total)
        }
    }
}
