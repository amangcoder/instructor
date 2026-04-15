// InstructorLiveActivity.swift
// TASK-014: SwiftUI views for Dynamic Island and Lock Screen Live Activity.
//
// Provides:
//   • Compact leading/trailing views for the Dynamic Island pill
//   • Expanded view with step name, progress, and deep-link controls
//   • Lock Screen banner with step info and time remaining
//
// ## Deep-link intents (expanded Dynamic Island)
//
//   instructor://pause   — pause the current session
//   instructor://resume  — resume the paused session
//   instructor://skip    — skip to the next step
//
// ## Layout
//
// Compact (collapsed pill):
//   Leading: ▶️ icon or ⏸ icon depending on status
//   Trailing: "Step 2/5" text
//
// Expanded:
//   Center: step name (truncated to ~100 chars by LiveActivityManager)
//   Bottom: progress bar + pause/resume/skip buttons as deep links
//
// Lock Screen:
//   Plan name, current step, progress indicator, time remaining

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity Configuration

/// Registers the Live Activity with WidgetKit.
///
/// This struct uses the `@available` check to ensure it only compiles
/// on iOS 16.1+ where ActivityKit Live Activities are supported.
@available(iOS 16.1, *)
struct InstructorLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: InstructorActivityAttributes.self) { context in
            // Lock Screen / StandBy banner
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island regions
                DynamicIslandExpandedRegion(.leading) {
                    statusIcon(for: context.state.status)
                        .font(.title2)
                        .foregroundColor(statusColor(for: context.state.status))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.stepIndex + 1)/\(context.attributes.totalSteps)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.attributes.planName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Text(context.state.stepName)
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        // Progress bar
                        ProgressView(
                            value: Double(context.state.stepIndex + 1),
                            total: Double(max(context.attributes.totalSteps, 1))
                        )
                        .tint(statusColor(for: context.state.status))

                        // Control buttons (deep links)
                        if !context.state.isCompleted {
                            HStack(spacing: 24) {
                                // Pause / Resume toggle
                                if context.state.status == "paused" {
                                    Link(destination: URL(string: "instructor://resume")!) {
                                        Image(systemName: "play.fill")
                                            .font(.title3)
                                    }
                                } else {
                                    Link(destination: URL(string: "instructor://pause")!) {
                                        Image(systemName: "pause.fill")
                                            .font(.title3)
                                    }
                                }

                                // Skip forward
                                Link(destination: URL(string: "instructor://skip")!) {
                                    Image(systemName: "forward.fill")
                                        .font(.title3)
                                }
                            }
                            .foregroundColor(.white)
                        }
                    }
                }
            } compactLeading: {
                // Compact pill: leading icon
                statusIcon(for: context.state.status)
                    .foregroundColor(statusColor(for: context.state.status))
            } compactTrailing: {
                // Compact pill: trailing step counter
                Text("\(context.state.stepIndex + 1)/\(context.attributes.totalSteps)")
                    .font(.caption2)
                    .monospacedDigit()
            } minimal: {
                // Minimal (when competing with another Live Activity)
                statusIcon(for: context.state.status)
                    .foregroundColor(statusColor(for: context.state.status))
            }
            // AC-020: Tapping Dynamic Island opens now-playing screen
            .widgetURL(URL(string: "instructor://toggle-playback"))
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<InstructorActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: plan name + status icon
            HStack {
                statusIcon(for: context.state.status)
                    .foregroundColor(statusColor(for: context.state.status))

                Text(context.attributes.planName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Spacer()

                Text("\(context.state.stepIndex + 1)/\(context.attributes.totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            // Current step name
            Text(context.state.stepName)
                .font(.headline)
                .lineLimit(2)

            // Progress bar
            ProgressView(
                value: Double(context.state.stepIndex + 1),
                total: Double(max(context.attributes.totalSteps, 1))
            )
            .tint(statusColor(for: context.state.status))

            // Time remaining (if available)
            if context.state.timeRemainingMs > 0 && !context.state.isCompleted {
                Text(formatTimeRemaining(ms: context.state.timeRemainingMs))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.75))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statusIcon(for status: String) -> some View {
        switch status {
        case "playing":
            Image(systemName: "play.fill")
        case "paused":
            Image(systemName: "pause.fill")
        case "completed":
            Image(systemName: "checkmark.circle.fill")
        default:
            Image(systemName: "play.fill")
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "playing":
            return .green
        case "paused":
            return .orange
        case "completed":
            return .blue
        default:
            return .green
        }
    }

    private func formatTimeRemaining(ms: Int) -> String {
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s remaining"
        }
        return "\(seconds)s remaining"
    }
}
