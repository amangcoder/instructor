// LiveActivityManager.swift
// TASK-014: Manages Live Activity lifecycle for plan execution.
//
// Handles MethodChannel calls from Flutter (com.layersiq.instructor/live_activity):
//   'startActivity'  → Start a new Live Activity
//   'updateActivity' → Update the Live Activity content state
//   'endActivity'    → End the Live Activity
//
// ## ActivityKit constraints
//
// - Activities auto-end after 8 hours. At 7h50m, the manager ends the current
//   activity and starts a new one with the current state.
// - Content payload must be under 4KB. Step text is truncated to ~100 chars.
// - Gracefully degrades on iOS < 16.1 (all methods are no-ops).
//
// ## Deep link intents
//
// The expanded Dynamic Island view uses deep-link URLs for pause/resume/skip:
//   instructor://pause
//   instructor://resume
//   instructor://skip

import ActivityKit
import Flutter
import UIKit

/// Manages the Live Activity lifecycle for plan execution.
///
/// Registered as a MethodChannel handler in AppDelegate.setupChannels().
class LiveActivityManager: NSObject {

    /// Reference to the current running activity (iOS 16.1+).
    private var currentActivity: Any? = nil

    /// Timestamp when the current activity was started (for 8h max handling).
    private var activityStartTime: Date? = nil

    /// Timer for 8-hour maximum enforcement.
    private var maxDurationTimer: Timer? = nil

    /// Cached last known state for activity restart after 8h max.
    private var lastKnownState: [String: Any]? = nil

    /// 7 hours 50 minutes in seconds — when to restart the activity.
    private static let maxDurationSeconds: TimeInterval = 7 * 3600 + 50 * 60

    /// Auto-dismiss delay after completion (4 seconds).
    private static let completionDismissDelay: TimeInterval = 4.0

    /// Registers the MethodChannel handler on the given messenger.
    func register(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "com.layersiq.instructor/live_activity",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(FlutterError(code: "DEALLOCATED", message: nil, details: nil))
                return
            }

            switch call.method {
            case "startActivity":
                self.handleStart(arguments: call.arguments, result: result)
            case "updateActivity":
                self.handleUpdate(arguments: call.arguments, result: result)
            case "endActivity":
                self.handleEnd(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Start

    /// Starts a new Live Activity for plan execution.
    ///
    /// Arguments (Map<String, Any>):
    ///   - planName: String
    ///   - totalSteps: Int
    ///   - stepName: String
    ///   - stepIndex: Int
    ///   - timeRemainingMs: Int
    ///   - status: String ("playing" | "paused")
    private func handleStart(arguments: Any?, result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else {
            // AC-023: No Live Activity attempted on iOS 15 or earlier
            result(nil)
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            result(FlutterError(
                code: "ACTIVITIES_DISABLED",
                message: "Live Activities are disabled in Settings",
                details: nil
            ))
            return
        }

        guard let args = arguments as? [String: Any],
              let planName = args["planName"] as? String,
              let totalSteps = args["totalSteps"] as? Int,
              let stepName = args["stepName"] as? String,
              let stepIndex = args["stepIndex"] as? Int,
              let timeRemainingMs = args["timeRemainingMs"] as? Int,
              let status = args["status"] as? String
        else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing required arguments",
                details: nil
            ))
            return
        }

        // End any existing activity first
        endCurrentActivity()

        do {
            let attributes = InstructorActivityAttributes(
                planName: planName,
                totalSteps: totalSteps
            )

            let contentState = InstructorActivityAttributes.ContentState(
                stepName: truncateStepName(stepName),
                stepIndex: stepIndex,
                timeRemainingMs: timeRemainingMs,
                status: status
            )

            let content = ActivityContent(
                state: contentState,
                staleDate: Date().addingTimeInterval(120) // Stale after 2 min without update
            )

            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil // No push updates — using local updates only
            )

            currentActivity = activity
            activityStartTime = Date()
            lastKnownState = args

            // Schedule 8-hour max restart (REQ-024)
            scheduleMaxDurationRestart(args: args)

            result(nil)
        } catch {
            result(FlutterError(
                code: "START_FAILED",
                message: error.localizedDescription,
                details: nil
            ))
        }
    }

    // MARK: - Update

    /// Updates the Live Activity content state.
    ///
    /// Arguments same as startActivity's ContentState fields.
    /// REQ-021: Updates within 1 second of step transition.
    private func handleUpdate(arguments: Any?, result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else {
            result(nil)
            return
        }

        guard let args = arguments as? [String: Any],
              let stepName = args["stepName"] as? String,
              let stepIndex = args["stepIndex"] as? Int,
              let timeRemainingMs = args["timeRemainingMs"] as? Int,
              let status = args["status"] as? String
        else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing required arguments",
                details: nil
            ))
            return
        }

        lastKnownState = args

        guard let activity = currentActivity as? Activity<InstructorActivityAttributes> else {
            result(nil)
            return
        }

        let contentState = InstructorActivityAttributes.ContentState(
            stepName: truncateStepName(stepName),
            stepIndex: stepIndex,
            timeRemainingMs: timeRemainingMs,
            status: status
        )

        let content = ActivityContent(
            state: contentState,
            staleDate: Date().addingTimeInterval(120)
        )

        Task {
            await activity.update(content)
        }

        // If completed, auto-dismiss after 4 seconds (REQ-023)
        if status == "completed" {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.completionDismissDelay) { [weak self] in
                self?.endCurrentActivity()
            }
        }

        result(nil)
    }

    // MARK: - End

    /// Ends the current Live Activity.
    private func handleEnd(result: @escaping FlutterResult) {
        endCurrentActivity()
        result(nil)
    }

    // MARK: - Internal

    /// Ends the current activity if one exists.
    private func endCurrentActivity() {
        guard #available(iOS 16.2, *) else { return }

        maxDurationTimer?.invalidate()
        maxDurationTimer = nil

        guard let activity = currentActivity as? Activity<InstructorActivityAttributes> else {
            currentActivity = nil
            return
        }

        // Create a "completed" final state
        let finalState = InstructorActivityAttributes.ContentState(
            stepName: "Session complete",
            stepIndex: 0,
            timeRemainingMs: 0,
            status: "completed"
        )

        let finalContent = ActivityContent(
            state: finalState,
            staleDate: nil
        )

        Task {
            await activity.end(
                finalContent,
                dismissalPolicy: .after(Date().addingTimeInterval(Self.completionDismissDelay))
            )
        }

        currentActivity = nil
        activityStartTime = nil
    }

    /// Schedules a restart at 7h50m to handle the 8-hour ActivityKit maximum.
    /// REQ-024: Handles 8-hour maximum gracefully by restarting.
    private func scheduleMaxDurationRestart(args: [String: Any]) {
        guard #available(iOS 16.2, *) else { return }

        maxDurationTimer?.invalidate()
        maxDurationTimer = Timer.scheduledTimer(
            withTimeInterval: Self.maxDurationSeconds,
            repeats: false
        ) { [weak self] _ in
            guard let self, let lastState = self.lastKnownState else { return }

            // End current and start fresh
            self.endCurrentActivity()

            // Restart with last known state
            self.handleStart(arguments: lastState) { _ in
                // Ignore result — best-effort restart
            }
        }
    }

    /// Truncates step text to ~100 characters to stay within the 4KB payload limit.
    private func truncateStepName(_ name: String) -> String {
        if name.count <= 100 { return name }
        return String(name.prefix(97)) + "..."
    }
}
