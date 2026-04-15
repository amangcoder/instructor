// InstructorWidgetBundle.swift — TASK-017 + TASK-011
// WidgetBundle entry point for the InstructorWidget app extension.
//
// Lists all Widget types defined in this extension so WidgetKit registers them.
// Conditionally includes lock-screen widgets on iOS 16+.
//
// Widgets:
//   • InstructorWidget         — small + medium, playback + streak indicator
//   • InstructorLockScreenWidget — lock screen rectangular + circular (iOS 16+)
//   • StreakOnlySmallWidget    — small, streak count + today completion (TASK-011)

import WidgetKit
import SwiftUI

@main
struct InstructorWidgetBundle: WidgetBundle {
  var body: some Widget {
    InstructorWidget()
    StreakOnlySmallWidget()
    if #available(iOSApplicationExtension 16.1, *) {
      InstructorLiveActivity()
      InstructorLockScreenWidget()
    }
  }
}
