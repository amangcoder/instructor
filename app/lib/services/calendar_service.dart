// TASK-013: Calendar integration service
//
// Bridges Flutter to iOS EventKit via a MethodChannel so the user can schedule
// plan sessions as native calendar events.
//
// ## Channel contract
//
// Flutter → Native (invokeMethod):
//   'requestPermission' → bool  (true = authorized, false = denied/restricted)
//   'createEvent'       → void  (throws PlatformException on failure)
//   'openAppSettings'   → void
//
// createEvent payload (Map<String, dynamic>):
//   title          — String   — plan name shown as the calendar event title
//   durationMinutes — int    — estimated plan duration in minutes
//   startDate       — String — ISO-8601 start date+time (UTC)
//   recurrenceRule  — String — 'none' | 'daily' | 'weekdays' | 'weekly'
//   deepLink        — String — instructor:// deep-link URL for the plan
//
// ## Platform behaviour
//
// On iOS:  forwards to the native CalendarManager via EventKit.
// On other platforms: all methods are no-ops / return false so the feature
// degrades gracefully (Android calendar integration can be wired later).

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'calendar_service.g.dart';

// ── Channel identifier ────────────────────────────────────────────────────────

/// MethodChannel name that must match the native CalendarManager handler.
const String kCalendarChannel = 'com.layersiq.instructor/calendar';

// ── Recurrence rule ───────────────────────────────────────────────────────────

/// Recurrence options for a scheduled plan session.
enum CalendarRecurrence {
  none,
  daily,
  weekdays,
  weekly;

  /// String value sent over the MethodChannel to native code.
  String get channelValue => switch (this) {
        CalendarRecurrence.none => 'none',
        CalendarRecurrence.daily => 'daily',
        CalendarRecurrence.weekdays => 'weekdays',
        CalendarRecurrence.weekly => 'weekly',
      };

  /// Human-readable label shown in the UI dropdown.
  String get label => switch (this) {
        CalendarRecurrence.none => 'None',
        CalendarRecurrence.daily => 'Daily',
        CalendarRecurrence.weekdays => 'Weekdays (Mon–Fri)',
        CalendarRecurrence.weekly => 'Weekly',
      };
}

// ── CalendarService ───────────────────────────────────────────────────────────

/// Manages iOS EventKit calendar integration.
///
/// All public methods are safe to call on any platform — they return early or
/// return `false` on non-iOS targets so the UI can be rendered without
/// platform guards everywhere.
class CalendarService {
  CalendarService._();

  static const _channel = MethodChannel(kCalendarChannel);

  // ── Permission ──────────────────────────────────────────────────────────────

  /// Requests calendar access permission.
  ///
  /// Returns `true` when the user grants (or has already granted) access.
  /// Returns `false` when the user denies, or when running on a non-iOS
  /// platform.
  Future<bool> requestPermission() async {
    if (!defaultTargetPlatform.isIOS) return false;
    try {
      final result =
          await _channel.invokeMethod<bool>('requestPermission') ?? false;
      return result;
    } on PlatformException catch (e) {
      debugPrint('[CalendarService] requestPermission failed: $e');
      return false;
    }
  }

  // ── Event creation ──────────────────────────────────────────────────────────

  /// Creates a calendar event for a plan session.
  ///
  /// [title]           — Plan name used as the event title.
  /// [durationMinutes] — Estimated session length; sets the event end time.
  /// [startDateTime]   — Desired session start date/time.
  /// [recurrence]      — Optional recurrence rule (default: none).
  /// [deepLink]        — Optional URL attached to the event; opens the plan
  ///                     when tapped from the calendar.
  ///
  /// Throws [PlatformException] when the native call fails (e.g. the calendar
  /// is read-only, or the user revoked permission between the permission check
  /// and this call).
  ///
  /// No-op on non-iOS platforms.
  Future<void> createEvent({
    required String title,
    required int durationMinutes,
    required DateTime startDateTime,
    CalendarRecurrence recurrence = CalendarRecurrence.none,
    String? deepLink,
  }) async {
    if (!defaultTargetPlatform.isIOS) return;
    await _channel.invokeMethod<void>('createEvent', {
      'title': title,
      'durationMinutes': durationMinutes,
      'startDate': startDateTime.toUtc().toIso8601String(),
      'recurrenceRule': recurrence.channelValue,
      'deepLink': deepLink ?? '',
    });
  }

  // ── Settings ────────────────────────────────────────────────────────────────

  /// Opens the native app-settings page so the user can grant calendar access.
  ///
  /// No-op on platforms without a registered MethodChannel handler (e.g.
  /// desktop/web).
  Future<void> openAppSettings() async {
    if (!defaultTargetPlatform.isIOS && !defaultTargetPlatform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('openAppSettings');
    } on PlatformException catch (e) {
      debugPrint('[CalendarService] openAppSettings failed: $e');
    }
  }
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
CalendarService calendarService(Ref ref) => CalendarService._();

// ── Extension helper ──────────────────────────────────────────────────────────

extension on TargetPlatform {
  bool get isIOS => this == TargetPlatform.iOS;
  bool get isAndroid => this == TargetPlatform.android;
}
