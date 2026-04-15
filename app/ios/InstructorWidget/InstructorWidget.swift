// InstructorWidget.swift — TASK-017 + TASK-011
// iOS WidgetKit home-screen and lock-screen widgets for Instructor.
//
// ## Overview
//
// The widget reads execution state AND streak data from App Group UserDefaults
// (group.com.layersiq.instructor) which Flutter writes via the
// WidgetStateChannel MethodChannel.
//
// ## Supported Widget Families
//
//   • .systemSmall  — Plan name + status indicator + streak badge (home screen)
//   • .systemMedium — Plan name + step text + progress bar + streak (home screen)
//   • .accessoryRectangular — Step text + play/pause, or streak when idle (lock screen, iOS 16+)
//   • .accessoryCircular    — Status icon or streak flame (lock screen, iOS 16+)
//
// ## StreakOnlySmallWidget
//
//   A separate small widget (added in TASK-011) that shows only streak data:
//   • Current streak count with flame emoji
//   • "Done today ✓" when the user completed today
//   • "Start a session" when they haven't completed today
//   Deep-links to the app root so the user can begin a session.
//
// ## Timeline Refresh
//
// Each timeline entry has a 1-minute expiry.  Flutter also calls
// WidgetCenter.shared.reloadAllTimelines() via the MethodChannel after every
// state write, so in practice the widget refreshes within seconds of a state
// change (subject to WidgetKit budget).

import WidgetKit
import SwiftUI

// MARK: - App Group identifier

let kAppGroup = "group.com.layersiq.instructor"

// MARK: - Deep-link URLs

let kTogglePlaybackURL = URL(string: "instructor://toggle-playback")!
let kOpenAppURL        = URL(string: "instructor://open")!

// MARK: - UserDefaults keys

private enum UDKey {
  // Playback
  static let planName         = "instructor_plan_name"
  static let stepText         = "instructor_step_text"
  static let nextStepText     = "instructor_next_step_text"
  static let status           = "instructor_status"
  static let stepDurationMs   = "instructor_step_duration_ms"
  static let elapsedMs        = "instructor_elapsed_ms"
  static let updatedAt        = "instructor_updated_at"

  // Streak (TASK-011)
  static let streakCount       = "instructor_streak_count"
  static let completedToday    = "instructor_completed_today"
  static let streakFreezeCount = "instructor_streak_freeze_count"
}

// MARK: - Shared state model

struct InstructorWidgetState {
  let planName: String
  let stepText: String
  let nextStepText: String
  let status: PlaybackStatus
  let stepDurationMs: Int
  let elapsedMs: Int
  let updatedAt: Date

  // Streak fields (TASK-011)
  let streakCount: Int
  let completedToday: Bool
  let streakFreezeCount: Int

  enum PlaybackStatus {
    case playing, paused, stopped
  }

  static let placeholder = InstructorWidgetState(
    planName: "Morning Routine",
    stepText: "Breathe in for 4 counts",
    nextStepText: "Hold for 4 counts",
    status: .playing,
    stepDurationMs: 30_000,
    elapsedMs: 8_000,
    updatedAt: Date(),
    streakCount: 7,
    completedToday: false,
    streakFreezeCount: 1
  )

  static let empty = InstructorWidgetState(
    planName: "",
    stepText: "No active plan",
    nextStepText: "",
    status: .stopped,
    stepDurationMs: 0,
    elapsedMs: 0,
    updatedAt: Date(),
    streakCount: 0,
    completedToday: false,
    streakFreezeCount: 0
  )

  /// Read current state from the shared App Group UserDefaults.
  static func fromUserDefaults() -> InstructorWidgetState {
    guard let defaults = UserDefaults(suiteName: kAppGroup) else {
      return .empty
    }

    let statusStr = defaults.string(forKey: UDKey.status) ?? "stopped"
    let playbackStatus: PlaybackStatus
    switch statusStr {
    case "playing": playbackStatus = .playing
    case "paused":  playbackStatus = .paused
    default:        playbackStatus = .stopped
    }

    let updatedAtEpoch = defaults.double(forKey: UDKey.updatedAt)
    let updatedAt = updatedAtEpoch > 0
      ? Date(timeIntervalSince1970: updatedAtEpoch)
      : Date()

    return InstructorWidgetState(
      planName: defaults.string(forKey: UDKey.planName) ?? "",
      stepText: defaults.string(forKey: UDKey.stepText) ?? "No active plan",
      nextStepText: defaults.string(forKey: UDKey.nextStepText) ?? "",
      status: playbackStatus,
      stepDurationMs: defaults.integer(forKey: UDKey.stepDurationMs),
      elapsedMs: defaults.integer(forKey: UDKey.elapsedMs),
      updatedAt: updatedAt,
      streakCount: defaults.integer(forKey: UDKey.streakCount),
      completedToday: defaults.bool(forKey: UDKey.completedToday),
      streakFreezeCount: defaults.integer(forKey: UDKey.streakFreezeCount)
    )
  }

  /// Fractional progress through the current step (0.0–1.0).
  var progress: Double {
    guard stepDurationMs > 0 else { return 0 }
    return Double(elapsedMs) / Double(stepDurationMs)
  }

  /// Formatted elapsed time string, e.g. "1:32".
  var elapsedFormatted: String {
    let seconds = elapsedMs / 1000
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
  }

  /// True when a plan is actively running or paused.
  var hasActivePlan: Bool {
    !planName.isEmpty && status != .stopped
  }

  /// Streak label: "🔥 7" or "🔥 0" when no streak.
  var streakLabel: String {
    streakCount > 0 ? "🔥 \(streakCount)" : "🔥 0"
  }
}

// MARK: - Timeline Entry

struct InstructorEntry: TimelineEntry {
  let date: Date
  let state: InstructorWidgetState
}

// MARK: - Timeline Provider

struct InstructorTimelineProvider: TimelineProvider {
  typealias Entry = InstructorEntry

  func placeholder(in context: Context) -> InstructorEntry {
    InstructorEntry(date: Date(), state: .placeholder)
  }

  func getSnapshot(in context: Context, completion: @escaping (InstructorEntry) -> Void) {
    let state = context.isPreview ? .placeholder : InstructorWidgetState.fromUserDefaults()
    completion(InstructorEntry(date: Date(), state: state))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<InstructorEntry>) -> Void) {
    let state = InstructorWidgetState.fromUserDefaults()
    let now = Date()
    let entry = InstructorEntry(date: now, state: state)

    // Refresh every 60 seconds. Flutter will also call
    // WidgetCenter.reloadAllTimelines() on every state write.
    let nextRefresh = Calendar.current.date(byAdding: .minute, value: 1, to: now)!
    let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
    completion(timeline)
  }
}

// MARK: - Colour palette

private extension Color {
  static let instructorBackground = Color("WidgetBackground", bundle: nil)
  static let instructorAccent     = Color(red: 0.35, green: 0.68, blue: 1.0)  // #59ADFF
  static let instructorText       = Color.white
  static let instructorSubtext    = Color.white.opacity(0.7)
  static let instructorProgress   = Color(red: 0.35, green: 0.68, blue: 1.0)
  static let streakOrange         = Color(red: 1.0,  green: 0.55, blue: 0.0)  // #FF8C00
}

// MARK: - Shared icon helper

private func statusIcon(for status: InstructorWidgetState.PlaybackStatus) -> String {
  switch status {
  case .playing: return "play.fill"
  case .paused:  return "pause.fill"
  case .stopped: return "stop.fill"
  }
}

// MARK: - Streak badge view (shared between small and medium)

/// Compact streak indicator: "🔥 7" in orange, shown in a corner of the widget.
private struct StreakBadge: View {
  let streakCount: Int
  let completedToday: Bool

  var body: some View {
    HStack(spacing: 2) {
      Text("🔥")
        .font(.system(size: 10))
      Text("\(streakCount)")
        .font(.system(size: 10, weight: .bold).monospacedDigit())
        .foregroundColor(.streakOrange)
      if completedToday {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 9))
          .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.2))
      }
    }
    .padding(.horizontal, 5)
    .padding(.vertical, 2)
    .background(
      Capsule()
        .fill(Color.white.opacity(0.10))
    )
  }
}

// MARK: - Small widget view

struct SmallWidgetView: View {
  let entry: InstructorEntry

  var body: some View {
    let state = entry.state
    Link(destination: kTogglePlaybackURL) {
      ZStack {
        // Background gradient
        LinearGradient(
          colors: [Color(red: 0.08, green: 0.10, blue: 0.18),
                   Color(red: 0.05, green: 0.07, blue: 0.13)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )

        VStack(alignment: .leading, spacing: 6) {
          // Header row: status icon + streak badge
          HStack(spacing: 4) {
            Image(systemName: statusIcon(for: state.status))
              .font(.system(size: 10, weight: .bold))
              .foregroundColor(.instructorAccent)
            Text("Instructor")
              .font(.system(size: 9, weight: .semibold))
              .foregroundColor(.instructorSubtext)
              .lineLimit(1)

            Spacer()

            // Streak badge — always visible
            StreakBadge(
              streakCount: state.streakCount,
              completedToday: state.completedToday
            )
          }

          Spacer()

          // Step text or plan name
          Text(state.hasActivePlan ? state.stepText : state.planName.isEmpty ? "Start a session" : state.stepText)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.instructorText)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)

          Spacer()

          // Progress bar
          if state.hasActivePlan {
            GeometryReader { geo in
              ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                  .fill(Color.white.opacity(0.15))
                  .frame(height: 3)
                RoundedRectangle(cornerRadius: 2)
                  .fill(Color.instructorProgress)
                  .frame(width: geo.size.width * state.progress, height: 3)
              }
            }
            .frame(height: 3)
          }
        }
        .padding(12)
      }
    }
    .widgetURL(kTogglePlaybackURL)
  }
}

// MARK: - Medium widget view

struct MediumWidgetView: View {
  let entry: InstructorEntry

  var body: some View {
    let state = entry.state
    Link(destination: kTogglePlaybackURL) {
      ZStack {
        // Background gradient
        LinearGradient(
          colors: [Color(red: 0.08, green: 0.10, blue: 0.18),
                   Color(red: 0.05, green: 0.07, blue: 0.13)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )

        HStack(spacing: 12) {
          // Left column — plan info
          VStack(alignment: .leading, spacing: 6) {
            // Header row
            HStack(spacing: 6) {
              Image(systemName: "figure.mind.and.body")
                .font(.system(size: 12))
                .foregroundColor(.instructorAccent)
              Text("INSTRUCTOR")
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundColor(.instructorSubtext)

              Spacer()

              // Streak badge in the header
              StreakBadge(
                streakCount: state.streakCount,
                completedToday: state.completedToday
              )
            }

            // Plan name
            if !state.planName.isEmpty {
              Text(state.planName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.instructorSubtext)
                .lineLimit(1)
            }

            Spacer()

            // Current step text
            Text(state.stepText)
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.instructorText)
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)

            // Next step text (if available)
            if !state.nextStepText.isEmpty {
              HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                  .font(.system(size: 9))
                  .foregroundColor(.instructorSubtext)
                Text(state.nextStepText)
                  .font(.system(size: 11))
                  .foregroundColor(.instructorSubtext)
                  .lineLimit(1)
              }
            }

            Spacer()

            // Progress bar
            if state.hasActivePlan {
              GeometryReader { geo in
                ZStack(alignment: .leading) {
                  RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 3)
                  RoundedRectangle(cornerRadius: 2)
                    .fill(Color.instructorProgress)
                    .frame(width: geo.size.width * state.progress, height: 3)
                }
              }
              .frame(height: 3)
            }
          }

          Spacer()

          // Right column — status + elapsed
          VStack(spacing: 8) {
            // Play/Pause button visual
            ZStack {
              Circle()
                .fill(Color.instructorAccent.opacity(0.15))
                .frame(width: 44, height: 44)
              Image(systemName: statusIcon(for: state.status))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.instructorAccent)
            }

            // Elapsed time
            if state.hasActivePlan {
              Text(state.elapsedFormatted)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundColor(.instructorSubtext)
            }
          }
        }
        .padding(14)
      }
    }
    .widgetURL(kTogglePlaybackURL)
  }
}

// MARK: - Lock screen rectangular widget (iOS 16+)

@available(iOSApplicationExtension 16.0, *)
struct AccessoryRectangularView: View {
  let entry: InstructorEntry

  var body: some View {
    let state = entry.state
    Link(destination: kTogglePlaybackURL) {
      HStack(spacing: 6) {
        if state.hasActivePlan {
          // Active plan: show status icon + step info
          Image(systemName: statusIcon(for: state.status))
            .font(.system(size: 12, weight: .bold))
          VStack(alignment: .leading, spacing: 1) {
            Text(state.stepText)
              .font(.system(size: 12, weight: .semibold))
              .lineLimit(2)
            if !state.planName.isEmpty {
              Text(state.planName)
                .font(.system(size: 10))
                .opacity(0.7)
                .lineLimit(1)
            }
          }
        } else {
          // Idle: show streak instead
          Text("🔥")
            .font(.system(size: 14))
          VStack(alignment: .leading, spacing: 1) {
            Text("\(state.streakCount) day streak")
              .font(.system(size: 12, weight: .semibold))
              .lineLimit(1)
            Text(state.completedToday ? "Done today ✓" : "Start a session")
              .font(.system(size: 10))
              .opacity(0.7)
              .lineLimit(1)
          }
        }
        Spacer()
      }
    }
  }
}

// MARK: - Lock screen circular widget (iOS 16+)

@available(iOSApplicationExtension 16.0, *)
struct AccessoryCircularView: View {
  let entry: InstructorEntry

  var body: some View {
    Link(destination: kTogglePlaybackURL) {
      ZStack {
        AccessoryWidgetBackground()
        if entry.state.hasActivePlan {
          Image(systemName: statusIcon(for: entry.state.status))
            .font(.system(size: 16, weight: .bold))
        } else {
          // Show streak count in circular widget when idle
          VStack(spacing: 0) {
            Text("🔥")
              .font(.system(size: 10))
            Text("\(entry.state.streakCount)")
              .font(.system(size: 12, weight: .bold).monospacedDigit())
          }
        }
      }
    }
  }
}

// MARK: - Widget view dispatcher

struct InstructorWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  let entry: InstructorEntry

  var body: some View {
    switch family {
    case .systemSmall:
      SmallWidgetView(entry: entry)
    case .systemMedium:
      MediumWidgetView(entry: entry)
    default:
      // Fallback for unexpected families
      MediumWidgetView(entry: entry)
    }
  }
}

// MARK: - Main Widget definition

struct InstructorWidget: Widget {
  let kind: String = "InstructorWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: InstructorTimelineProvider()) { entry in
      if #available(iOSApplicationExtension 17.0, *) {
        InstructorWidgetEntryView(entry: entry)
          .containerBackground(.fill.tertiary, for: .widget)
      } else {
        InstructorWidgetEntryView(entry: entry)
      }
    }
    .configurationDisplayName("Instructor")
    .description("See your active plan step, control playback, and track your streak.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// MARK: - Lock screen widget definition (iOS 16+)

@available(iOSApplicationExtension 16.0, *)
struct InstructorLockScreenWidget: Widget {
  let kind: String = "InstructorLockScreenWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: InstructorTimelineProvider()) { entry in
      InstructorLockScreenEntryView(entry: entry)
    }
    .configurationDisplayName("Instructor Status")
    .description("Shows current step on your lock screen. Shows streak when idle.")
    .supportedFamilies([.accessoryRectangular, .accessoryCircular])
  }
}

@available(iOSApplicationExtension 16.0, *)
struct InstructorLockScreenEntryView: View {
  @Environment(\.widgetFamily) var family
  let entry: InstructorEntry

  var body: some View {
    switch family {
    case .accessoryRectangular:
      AccessoryRectangularView(entry: entry)
    case .accessoryCircular:
      AccessoryCircularView(entry: entry)
    default:
      AccessoryRectangularView(entry: entry)
    }
  }
}

// ============================================================================
// MARK: - StreakOnlySmallWidget (TASK-011)
// ============================================================================
//
// A dedicated small widget that shows only streak data — useful for users
// who want habit-tracking on their home screen without the playback controls.
//
//   • Current streak count with flame emoji (large, centred)
//   • "Done today ✓" badge when completedToday == true
//   • "Start a session" prompt when completedToday == false
//   • Deep-links to the app root (kOpenAppURL)
//
// Data source: same App Group UserDefaults as InstructorWidget; reads only the
// three streak keys (instructor_streak_count, instructor_completed_today,
// instructor_streak_freeze_count).
//
// Timeline refresh: same policy as InstructorWidget (1-minute expiry +
// WidgetCenter.reloadAllTimelines() triggered by Flutter on every write).

// MARK: StreakOnlyWidgetState

struct StreakOnlyWidgetState {
  let streakCount: Int
  let completedToday: Bool
  let streakFreezeCount: Int

  static let placeholder = StreakOnlyWidgetState(
    streakCount: 7,
    completedToday: false,
    streakFreezeCount: 1
  )

  static let empty = StreakOnlyWidgetState(
    streakCount: 0,
    completedToday: false,
    streakFreezeCount: 0
  )

  /// Read streak state from the shared App Group UserDefaults.
  static func fromUserDefaults() -> StreakOnlyWidgetState {
    guard let defaults = UserDefaults(suiteName: kAppGroup) else {
      return .empty
    }
    return StreakOnlyWidgetState(
      streakCount: defaults.integer(forKey: UDKey.streakCount),
      completedToday: defaults.bool(forKey: UDKey.completedToday),
      streakFreezeCount: defaults.integer(forKey: UDKey.streakFreezeCount)
    )
  }
}

// MARK: StreakOnlyEntry

struct StreakOnlyEntry: TimelineEntry {
  let date: Date
  let state: StreakOnlyWidgetState
}

// MARK: StreakOnlyTimelineProvider

struct StreakOnlyTimelineProvider: TimelineProvider {
  typealias Entry = StreakOnlyEntry

  func placeholder(in context: Context) -> StreakOnlyEntry {
    StreakOnlyEntry(date: Date(), state: .placeholder)
  }

  func getSnapshot(in context: Context, completion: @escaping (StreakOnlyEntry) -> Void) {
    let state = context.isPreview ? .placeholder : StreakOnlyWidgetState.fromUserDefaults()
    completion(StreakOnlyEntry(date: Date(), state: state))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<StreakOnlyEntry>) -> Void) {
    let state = StreakOnlyWidgetState.fromUserDefaults()
    let now = Date()
    let entry = StreakOnlyEntry(date: now, state: state)
    let nextRefresh = Calendar.current.date(byAdding: .minute, value: 1, to: now)!
    let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
    completion(timeline)
  }
}

// MARK: StreakOnlySmallWidgetView

struct StreakOnlySmallWidgetView: View {
  let entry: StreakOnlyEntry

  var body: some View {
    let state = entry.state
    Link(destination: kOpenAppURL) {
      ZStack {
        // Dark blue-black gradient background
        LinearGradient(
          colors: [Color(red: 0.08, green: 0.10, blue: 0.18),
                   Color(red: 0.05, green: 0.07, blue: 0.13)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )

        VStack(spacing: 8) {
          // App label
          Text("INSTRUCTOR")
            .font(.system(size: 8, weight: .bold))
            .tracking(1.2)
            .foregroundColor(.white.opacity(0.5))

          Spacer()

          // Flame + streak count (prominent)
          VStack(spacing: 2) {
            Text("🔥")
              .font(.system(size: 28))
            Text("\(state.streakCount)")
              .font(.system(size: 32, weight: .black).monospacedDigit())
              .foregroundColor(.streakOrange)
          }

          // Streak sub-label
          Text(state.streakCount == 1 ? "day streak" : "day streak")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.6))

          Spacer()

          // Today status badge
          if state.completedToday {
            HStack(spacing: 4) {
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.2))
              Text("Done today")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
              Capsule()
                .fill(Color.white.opacity(0.10))
            )
          } else {
            Text("Start a session")
              .font(.system(size: 10, weight: .medium))
              .foregroundColor(.instructorAccent)
              .multilineTextAlignment(.center)
          }
        }
        .padding(12)
      }
    }
    .widgetURL(kOpenAppURL)
  }
}

// MARK: StreakOnlySmallWidget

struct StreakOnlySmallWidget: Widget {
  let kind: String = "StreakOnlySmallWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: StreakOnlyTimelineProvider()) { entry in
      if #available(iOSApplicationExtension 17.0, *) {
        StreakOnlySmallWidgetView(entry: entry)
          .containerBackground(.fill.tertiary, for: .widget)
      } else {
        StreakOnlySmallWidgetView(entry: entry)
      }
    }
    .configurationDisplayName("Streak")
    .description("Track your daily practice streak. Tap to start a session.")
    .supportedFamilies([.systemSmall])
  }
}
