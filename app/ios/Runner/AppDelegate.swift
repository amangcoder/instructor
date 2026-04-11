// AppDelegate.swift
// TASK-017: Extended to support iOS home-screen widget integration.
//
// Added responsibilities:
//   1. MethodChannel 'com.layersiq.instructor/widget' — receives execution
//      state from Flutter and writes it to App Group UserDefaults.  Then calls
//      WidgetCenter.shared.reloadAllTimelines() to refresh all widget sizes.
//
//   2. URL scheme handler for 'instructor://toggle-playback' — the widget's
//      tap-action deep link.  Passes the toggle intent to Flutter via
//      MethodChannel 'com.layersiq.instructor/widget_deeplink'.
//
//   3. openURL / continue userActivity — handles cold-start widget taps (when
//      the app is not in memory) by queuing the intent and delivering it once
//      the Flutter engine is ready.

import Flutter
import UIKit
import WidgetKit

// MARK: - Channel names (must match Dart constants)

private let kWidgetChannel        = "com.layersiq.instructor/widget"
private let kWidgetDeepLinkChannel = "com.layersiq.instructor/widget_deeplink"
private let kAppGroup             = "group.com.layersiq.instructor"

// MARK: - AppDelegate

@main
@objc class AppDelegate: FlutterAppDelegate {

  // Queued deep-link intent while Flutter engine is warming up.
  private var pendingToggle = false

  // Cached reference to the deep-link channel, set after engine is ready.
  private var deepLinkChannel: FlutterMethodChannel?

  // MARK: - Application lifecycle

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      setupChannels(messenger: controller.binaryMessenger)
    }
    return result
  }

  // MARK: - Channel setup

  private func setupChannels(messenger: FlutterBinaryMessenger) {
    // ── Widget State Channel ──────────────────────────────────────────────────
    // Receives state updates from Flutter and writes them to App Group
    // UserDefaults so the widget extension can read them.
    let widgetChannel = FlutterMethodChannel(
      name: kWidgetChannel,
      binaryMessenger: messenger
    )
    widgetChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(FlutterError(code: "DEALLOCATED", message: nil, details: nil)); return }
      if call.method == "updateWidgetState" {
        self.handleWidgetStateUpdate(call.arguments, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // ── Widget Deep-Link Channel ──────────────────────────────────────────────
    // Flutter listens on this channel for toggle-playback intents delivered
    // by widget taps (via URL scheme).
    let deepLink = FlutterMethodChannel(
      name: kWidgetDeepLinkChannel,
      binaryMessenger: messenger
    )
    self.deepLinkChannel = deepLink

    // Deliver any queued toggle intent that arrived before engine was ready.
    if pendingToggle {
      pendingToggle = false
      deepLink.invokeMethod("togglePlayback", arguments: nil)
    }
  }

  // MARK: - Widget state write

  private func handleWidgetStateUpdate(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let payload = arguments as? [String: Any],
          let defaults = UserDefaults(suiteName: kAppGroup) else {
      result(FlutterError(code: "INVALID_ARGS", message: "Expected [String:Any] payload", details: nil))
      return
    }

    // Write each key to the shared App Group UserDefaults.
    if let planName = payload["plan_name"] as? String {
      defaults.set(planName, forKey: "instructor_plan_name")
    }
    if let stepText = payload["step_text"] as? String {
      defaults.set(stepText, forKey: "instructor_step_text")
    }
    if let nextStepText = payload["next_step_text"] as? String {
      defaults.set(nextStepText, forKey: "instructor_next_step_text")
    }
    if let status = payload["status"] as? String {
      defaults.set(status, forKey: "instructor_status")
    }
    if let durationMs = payload["step_duration_ms"] as? Int {
      defaults.set(durationMs, forKey: "instructor_step_duration_ms")
    }
    if let elapsedMs = payload["elapsed_ms"] as? Int {
      defaults.set(elapsedMs, forKey: "instructor_elapsed_ms")
    }
    if let updatedAt = payload["updated_at"] as? Double {
      defaults.set(updatedAt, forKey: "instructor_updated_at")
    }
    defaults.synchronize()

    // Ask WidgetKit to refresh all timelines immediately.
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }

    result(nil)
  }

  // MARK: - URL scheme handling (widget tap deep link)
  //
  // Handles instructor://toggle-playback when the app is already running.

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if handleInstructorURL(url) { return true }
    return super.application(app, open: url, options: options)
  }

  // Handles instructor://toggle-playback when app launches cold from widget tap.
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if let url = userActivity.webpageURL, handleInstructorURL(url) { return true }
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }

  private func handleInstructorURL(_ url: URL) -> Bool {
    guard url.scheme == "instructor", url.host == "toggle-playback" else { return false }

    if let channel = deepLinkChannel {
      channel.invokeMethod("togglePlayback", arguments: nil)
    } else {
      // Engine not ready yet — queue intent.
      pendingToggle = true
    }
    return true
  }
}
