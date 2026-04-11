// InstructorWidgetBundle.swift — TASK-017
// WidgetBundle entry point for the InstructorWidget app extension.
//
// Lists all Widget types defined in this extension so WidgetKit registers them.
// Conditionally includes lock-screen widgets on iOS 16+.

import WidgetKit
import SwiftUI

@main
struct InstructorWidgetBundle: WidgetBundle {
  var body: some Widget {
    InstructorWidget()
    if #available(iOSApplicationExtension 16.0, *) {
      InstructorLockScreenWidget()
    }
  }
}
