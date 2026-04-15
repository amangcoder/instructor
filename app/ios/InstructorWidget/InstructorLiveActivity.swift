// InstructorLiveActivity.swift
// TASK-014: SwiftUI views for Live Activity / Dynamic Island presentations.
//
// ## Presentations
//
//   Compact (Leading + Trailing):
//     Leading  — Plan name (truncated)
//     Trailing — Step progress "2/5" + status icon
//
//   Expanded (Dynamic Island):
//     Top row    — Plan name + step progress
//     Center     — Current step name
//     Bottom row — Time remaining + pause/resume/skip deep-link buttons
//
//   Lock Screen banner:
//     Plan name, current step, progress bar, time remaining
//
// ## Deep link intents
//
//   instructor://pause  — Pause the current session
//   instructor://resume — Resume the current session
//   instructor://skip   — Skip the current step

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Deep link URLs

private let kPauseURL  = URL(string: "instructor://pause")!
private let kResumeURL = URL(string: "instructor://resume")!
private let kSkipURL   = URL(string: "instructor://skip")!
private let kOpenURL   = URL(string: "instructor://open")!

// MARK: - Colour constants

private extension Color {
    static let liveAccent    = Color(red: 0.35, green: 0.68, blue: 1.0)  // #59ADFF
    static let liveSubtext   = Color.white.opacity(0.7)
    static let liveProgress  = Color(red: 0.35, green: 0.68, blue: 1.0)
    static let livePaused    = Color(red: 1.0, green: 0.75, blue: 0.0)   // amber
    static let liveCompleted = Color(red: 0.2, green: 0.8, blue: 0.2)    // green
}

// MARK: - Helper functions

/// Formats milliseconds into "M:SS" display string.
private func formatTime(_ ms: Int) -> String {
    let totalSeconds = max(0, ms / 1000)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%d:%02d", minutes, seconds)
}

/// Computes step progress as a fraction (0.0–1.0).
private func stepProgress(stepIndex: Int, totalSteps: Int) -> Double {
    guard totalSteps > 0 else { return 0.0 }
    return Double(stepIndex + 1) / Double(totalSteps)
}

/// Returns the appropriate SF Symbol name for a status string.
private func statusIcon(for status: String) -> String {
    switch status {
    case "playing":   return "play.fill"
    case "paused":    return "pause.fill"
    case "completed": return "checkmark.circle.fill"
    default:          return "play.fill"
    }
}

/// Returns the tint colour for a status string.
private func statusColor(for status: String) -> Color {
    switch status {
    case "playing":   return .liveAccent
    case "paused":    return .livePaused
    case "completed": return .liveCompleted
    default:          return .liveAccent
    }
}

// MARK: - Live Activity Configuration

@available(iOSApplicationExtension 16.1, *)
struct InstructorLiveActivity: Widget {
    let kind: String = "InstructorLiveActivity"

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: InstructorActivityAttributes.self) { context in
            // Lock Screen / banner presentation
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Compact views (Dynamic Island pill)

@available(iOSApplicationExtension 16.1, *)
private struct CompactLeadingView: View {
    let context: ActivityViewContext<InstructorActivityAttributes>

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon(for: context.state.status))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(statusColor(for: context.state.status))
            Text(context.attributes.planName)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct CompactTrailingView: View {
    let context: ActivityViewContext<InstructorActivityAttributes>

    var body: some View {
        Text("\(context.state.stepIndex + 1)/\(context.attributes.totalSteps)")
            .font(.system(size: 12, weight: .bold).monospacedDigit())
            .foregroundColor(.liveAccent)
    }
}

// MARK: - Minimal view (when multiple Live Activities are active)

@available(iOSApplicationExtension 16.1, *)
private struct MinimalView: View {
    let context: ActivityViewContext<InstructorActivityAttributes>

    var body: some View {
        Image(systemName: statusIcon(for: context.state.status))
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(statusColor(for: context.state.status))
    }
}

// MARK: - Expanded Dynamic Island views

@available(iOSApplicationExtension 16.1, *)
private struct ExpandedLeadingView: View {
    let context: ActivityViewContext<InstructorActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(context.attributes.planName)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Text("Step \(context.state.stepIndex + 1) of \(context.attributes.totalSteps)")
                .font(.system(size: 11))
                .foregroundColor(.liveSubtext)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<InstructorActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Image(systemName: statusIcon(for: context.state.status))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(statusColor(for: context.state.status))
            Text(formatTime(context.state.timeRemainingMs))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundColor(.liveSubtext)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct ExpandedCenterView: View {
    let context: ActivityViewContext<InstructorActivityAttributes>

    var body: some View {
        VStack(spacing: 6) {
            // Current step name
            Text(context.state.stepName)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.liveProgress)
                        .frame(
                            width: geo.size.width * stepProgress(
                                stepIndex: context.state.stepIndex,
                                totalSteps: context.attributes.totalSteps
                            ),
                            height: 3
                        )
                }
            }
            .frame(height: 3)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct ExpandedBottomView: View {
    let context: ActivityViewContext<InstructorActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            if context.state.status == "completed" {
                // Completed state — show done message
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.liveCompleted)
                    Text("Session complete")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.liveCompleted)
                }
            } else {
                // Active state — show control buttons as deep links
                if context.state.status == "playing" {
                    // Pause button
                    Link(destination: kPauseURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Pause")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.livePaused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.livePaused.opacity(0.15))
                        )
                    }
                } else if context.state.status == "paused" {
                    // Resume button
                    Link(destination: kResumeURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Resume")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.liveAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.liveAccent.opacity(0.15))
                        )
                    }
                }

                // Skip button (always visible when not completed)
                Link(destination: kSkipURL) {
                    HStack(spacing: 4) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Skip")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                    )
                }
            }
        }
    }
}

// MARK: - Lock Screen / banner Live Activity view

@available(iOSApplicationExtension 16.1, *)
private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<InstructorActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row: plan name + status
            HStack {
                Image(systemName: "figure.mind.and.body")
                    .font(.system(size: 12))
                    .foregroundColor(.liveAccent)
                Text(context.attributes.planName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                // Status badge
                HStack(spacing: 4) {
                    Image(systemName: statusIcon(for: context.state.status))
                        .font(.system(size: 10, weight: .bold))
                    Text(context.state.status.capitalized)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(statusColor(for: context.state.status))
            }

            // Current step
            Text(context.state.stepName)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.liveProgress)
                        .frame(
                            width: geo.size.width * stepProgress(
                                stepIndex: context.state.stepIndex,
                                totalSteps: context.attributes.totalSteps
                            ),
                            height: 4
                        )
                }
            }
            .frame(height: 4)

            // Bottom row: step count + time remaining + controls
            HStack {
                Text("Step \(context.state.stepIndex + 1)/\(context.attributes.totalSteps)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundColor(.liveSubtext)

                Spacer()

                if context.state.status != "completed" {
                    Text(formatTime(context.state.timeRemainingMs))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundColor(.liveSubtext)
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(Color(red: 0.08, green: 0.10, blue: 0.18))
    }
}
