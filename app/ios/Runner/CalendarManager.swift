// CalendarManager.swift
// TASK-012: iOS EventKit integration for calendar event creation.
//
// Handles MethodChannel calls from Flutter (com.layersiq.instructor/calendar):
//   'requestPermission' → Bool   (true = authorized)
//   'createEvent'       → Void   (throws FlutterError on failure)
//   'openAppSettings'   → Void
//
// ## EventKit API versions
//
// iOS 17+:  EKEventStore.requestWriteOnlyAccessToEvents(completion:)
// iOS 16-:  EKEventStore.requestAccess(to: .event) { ... }
//
// ## Recurrence rules
//
// 'daily'    → EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
// 'weekdays' → EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, daysOfTheWeek: Mon-Fri)
// 'weekly'   → EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
// 'none'     → no recurrence

import EventKit
import Flutter
import UIKit

/// Manages calendar event creation via iOS EventKit.
///
/// Registered as a MethodChannel handler in AppDelegate.setupChannels().
class CalendarManager: NSObject {

    private let eventStore = EKEventStore()

    /// Registers the MethodChannel handler on the given messenger.
    func register(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "com.layersiq.instructor/calendar",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(FlutterError(code: "DEALLOCATED", message: nil, details: nil))
                return
            }

            switch call.method {
            case "requestPermission":
                self.handleRequestPermission(result: result)
            case "createEvent":
                self.handleCreateEvent(arguments: call.arguments, result: result)
            case "openAppSettings":
                self.handleOpenAppSettings(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Permission

    /// Requests calendar write access.
    ///
    /// Returns `true` if authorized, `false` if denied/restricted.
    /// Uses iOS 17+ API when available, falls back to legacy API.
    private func handleRequestPermission(result: @escaping FlutterResult) {
        if #available(iOS 17.0, *) {
            eventStore.requestWriteOnlyAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    if let error {
                        result(FlutterError(
                            code: "PERMISSION_ERROR",
                            message: error.localizedDescription,
                            details: nil
                        ))
                        return
                    }
                    result(granted)
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    if let error {
                        result(FlutterError(
                            code: "PERMISSION_ERROR",
                            message: error.localizedDescription,
                            details: nil
                        ))
                        return
                    }
                    result(granted)
                }
            }
        }
    }

    // MARK: - Event Creation

    /// Creates a calendar event from the Flutter arguments map.
    ///
    /// Expected arguments (Map<String, Any>):
    ///   - title: String — event title (plan name)
    ///   - durationMinutes: Int — event duration
    ///   - startDate: String — ISO-8601 UTC timestamp
    ///   - recurrenceRule: String — 'none' | 'daily' | 'weekdays' | 'weekly'
    ///   - deepLink: String — instructor:// deep link URL
    private func handleCreateEvent(arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let title = args["title"] as? String,
              let durationMinutes = args["durationMinutes"] as? Int,
              let startDateString = args["startDate"] as? String
        else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing required arguments: title, durationMinutes, startDate",
                details: nil
            ))
            return
        }

        // Parse the ISO-8601 start date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let startDate = formatter.date(from: startDateString)
                ?? ISO8601DateFormatter().date(from: startDateString)
        else {
            result(FlutterError(
                code: "INVALID_DATE",
                message: "Could not parse startDate: \(startDateString)",
                details: nil
            ))
            return
        }

        let recurrenceString = args["recurrenceRule"] as? String ?? "none"
        let deepLink = args["deepLink"] as? String ?? ""

        // Check authorization status (EKAuthorizationStatus added .fullAccess /
        // .writeOnly in iOS 17; legacy .authorized still used on iOS 16 and for
        // pre-iOS-17 grants that haven't migrated).
        let status = EKEventStore.authorizationStatus(for: .event)
        let authorized: Bool
        if #available(iOS 17.0, *) {
            authorized = status == .fullAccess || status == .writeOnly || status == .authorized
        } else {
            authorized = status == .authorized
        }
        guard authorized else {
            result(FlutterError(
                code: "NOT_AUTHORIZED",
                message: "Calendar access not authorized. Current status: \(status.rawValue)",
                details: nil
            ))
            return
        }

        // Create the event
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(Double(durationMinutes) * 60.0)
        event.calendar = eventStore.defaultCalendarForNewEvents

        // Add deep link as URL and in notes
        if !deepLink.isEmpty, let url = URL(string: deepLink) {
            event.url = url
            event.notes = "Open in Instructor: \(deepLink)"
        }

        // Add recurrence rule
        if let rule = makeRecurrenceRule(from: recurrenceString) {
            event.addRecurrenceRule(rule)
        }

        // Save the event
        do {
            try eventStore.save(event, span: .thisEvent)
            result(nil)
        } catch {
            result(FlutterError(
                code: "SAVE_FAILED",
                message: error.localizedDescription,
                details: nil
            ))
        }
    }

    // MARK: - Settings

    /// Opens the iOS app settings page so the user can grant calendar access.
    private func handleOpenAppSettings(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                result(FlutterError(
                    code: "SETTINGS_ERROR",
                    message: "Could not create settings URL",
                    details: nil
                ))
                return
            }

            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl) { _ in
                    result(nil)
                }
            } else {
                result(FlutterError(
                    code: "SETTINGS_ERROR",
                    message: "Cannot open app settings",
                    details: nil
                ))
            }
        }
    }

    // MARK: - Helpers

    /// Converts a recurrence string from Flutter to an EKRecurrenceRule.
    ///
    /// Returns nil for 'none'.
    private func makeRecurrenceRule(from string: String) -> EKRecurrenceRule? {
        switch string {
        case "daily":
            return EKRecurrenceRule(
                recurrenceWith: .daily,
                interval: 1,
                end: nil
            )
        case "weekdays":
            // Monday through Friday
            let weekdays = [
                EKRecurrenceDayOfWeek(.monday),
                EKRecurrenceDayOfWeek(.tuesday),
                EKRecurrenceDayOfWeek(.wednesday),
                EKRecurrenceDayOfWeek(.thursday),
                EKRecurrenceDayOfWeek(.friday),
            ]
            return EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                daysOfTheWeek: weekdays,
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: nil
            )
        case "weekly":
            return EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                end: nil
            )
        default:
            // 'none' or unrecognized — no recurrence
            return nil
        }
    }
}

