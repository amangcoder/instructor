// Plan trigger service — schedules exact alarms on Android (and local
// notifications on iOS) so the app can auto-start a plan session at a
// user-chosen date/time with optional recurrence.
//
// ## Data flow
//
//   UI → schedule()
//        ├─ persist to Drift (PlanTriggersTable) — source of truth
//        ├─ invoke native PlanTriggerManager channel → AlarmManager (Android)
//        │  OR flutter_local_notifications.zonedSchedule(...) (iOS)
//        └─ caller later triggers sync to push the new row to the backend
//
//   App startup → reschedule()
//        ├─ read all non-deleted, future triggers from Drift
//        └─ re-arm each on the native layer (safety net against
//           reinstalls and iOS where there is no BootReceiver equivalent)
//
//   Cancel → cancel()
//        ├─ soft-delete in Drift (tombstone for sync)
//        ├─ cancel native alarm / notification
//        └─ caller later pushes the tombstone to the backend
//
// ## Platform behaviour
//
// * Android (API 24+): native PlanTriggerManager over MethodChannel
//   `com.layersiq.instructor/plan_trigger`. Uses
//   AlarmManager.setExactAndAllowWhileIdle; requires SCHEDULE_EXACT_ALARM on
//   Android 12+ (user redirected to Settings on first denial).
//
// * iOS: schedules a time-sensitive UNNotification via
//   flutter_local_notifications with an `instructor://plan-start?...`
//   payload. One-tap auto-start — iOS disallows silent foreground launch.
//   Recurring triggers are expanded into the next occurrence only; the
//   follow-up is re-armed after each fire (mirrors Android's re-arm model).
//
// * Other platforms: all calls are no-ops.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:instructor/database/app_database.dart';
import 'package:instructor/repositories/plan_trigger_repository.dart';
import 'package:instructor/services/calendar_service.dart' show CalendarRecurrence;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

part 'plan_trigger_service.g.dart';

const String kPlanTriggerChannel = 'com.layersiq.instructor/plan_trigger';

/// iOS notification channel / Android fallback channel for plan-start alerts.
/// Must match [FlutterNotificationService] Android-channel init.
const String kPlanTriggerNotificationChannelId = 'plan_triggers';

/// Reserved notification ID range for plan-trigger notifications on iOS.
/// Offset added to the hash of the client id so we never collide with the
/// step / resume / foreground notifications used elsewhere.
const int _planTriggerIosIdOffset = 0x10000000;

/// Outcome of [PlanTriggerService.schedule].
enum PlanTriggerScheduleResult {
  scheduled,
  permissionRequired,
  unsupportedPlatform,
  failed,
}

class PlanTriggerService {
  PlanTriggerService(this._repo, this._notifications);

  final PlanTriggerRepository _repo;
  final FlutterLocalNotificationsPlugin _notifications;

  static const MethodChannel _channel = MethodChannel(kPlanTriggerChannel);
  static const Uuid _uuid = Uuid();

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  // ── Permissions ──────────────────────────────────────────────────────────

  /// Whether exact alarms can be scheduled without user intervention.
  /// Returns `true` below Android 12; on 12+ reflects the user's grant state.
  /// Always `true` on iOS (uses local notifications, not exact alarms).
  Future<bool> canScheduleExactAlarms() async {
    if (_isIOS) return true;
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('canScheduleExactAlarms') ?? false;
    } on PlatformException catch (e) {
      debugPrint('[PlanTriggerService] canScheduleExactAlarms failed: $e');
      return false;
    }
  }

  /// Opens the Android "Alarms & reminders" settings screen for this app
  /// (Android 12+). No-op elsewhere.
  Future<void> openExactAlarmSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openExactAlarmSettings');
    } on PlatformException catch (e) {
      debugPrint('[PlanTriggerService] openExactAlarmSettings failed: $e');
    }
  }

  /// Whether full-screen-intent notifications can take over the lockscreen on
  /// this device. Android 14+ requires the user to grant USE_FULL_SCREEN_INTENT
  /// in Settings; this method reflects that state. Returns `true` on Android
  /// 13 and below, and on iOS (no equivalent gate — iOS uses notifications).
  Future<bool> canUseFullScreenIntent() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('canUseFullScreenIntent') ?? false;
    } on PlatformException catch (e) {
      debugPrint('[PlanTriggerService] canUseFullScreenIntent failed: $e');
      return false;
    }
  }

  /// Opens the system "Allow full screen intent" settings page on Android 14+.
  /// No-op on older Android and on iOS.
  Future<void> openFullScreenIntentSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openFullScreenIntentSettings');
    } on PlatformException catch (e) {
      debugPrint('[PlanTriggerService] openFullScreenIntentSettings failed: $e');
    }
  }

  // ── Schedule ─────────────────────────────────────────────────────────────

  /// Schedules a plan-start trigger.
  ///
  /// Persists the trigger to Drift first (so it survives reinstall + can be
  /// synced to the backend), then arms the native layer. Returns a result
  /// describing the outcome — the row remains in Drift even on native
  /// failure so a retry via [rescheduleAll] can pick it up later.
  ///
  /// [id] is optional — a client UUID is generated when omitted.
  Future<PlanTriggerScheduleResult> schedule({
    required String userId,
    required String planId,
    required String title,
    required DateTime start,
    required int durationMinutes,
    CalendarRecurrence recurrence = CalendarRecurrence.none,
    String? id,
  }) async {
    if (!_isAndroid && !_isIOS) {
      return PlanTriggerScheduleResult.unsupportedPlatform;
    }

    final clientId = id ?? _uuid.v4();
    final startUtc = start.toUtc();

    // Persist first — local source of truth for sync + rearm.
    await _repo.upsert(
      clientId: clientId,
      userId: userId,
      planId: planId,
      title: title,
      startUtc: startUtc,
      durationMinutes: durationMinutes,
      recurrence: recurrence.channelValue,
    );

    if (!await canScheduleExactAlarms()) {
      return PlanTriggerScheduleResult.permissionRequired;
    }

    final ok = await _armNative(
      clientId: clientId,
      planId: planId,
      title: title,
      startUtc: startUtc,
      recurrence: recurrence,
    );
    return ok
        ? PlanTriggerScheduleResult.scheduled
        : PlanTriggerScheduleResult.failed;
  }

  /// Cancels a trigger by [clientId]: soft-deletes in Drift (tombstone for
  /// sync) and removes the native alarm / pending notification.
  Future<void> cancel(String clientId) async {
    await _repo.softDelete(clientId);
    await _cancelNative(clientId);
  }

  /// Returns all active (non-deleted) triggers for [userId] from Drift.
  Future<List<PlanTriggersTableData>> listForUser(String userId) async {
    final rows = await _repo.watchActive(userId).first;
    return rows;
  }

  /// Re-arms every active, future-dated trigger in Drift on the native layer.
  ///
  /// Called on app startup so that reinstall (which wipes the native
  /// AlarmManager queue and local notifications) does not silently stop
  /// scheduled sessions.
  Future<void> rescheduleAll(String userId) async {
    if (!_isAndroid && !_isIOS) return;
    if (!await canScheduleExactAlarms()) return;

    final upcoming = await _repo.getUpcoming(userId, DateTime.now().toUtc());
    for (final row in upcoming) {
      final recurrence = _parseRecurrence(row.recurrence);
      await _armNative(
        clientId: row.clientId,
        planId: row.planId,
        title: row.title,
        startUtc: row.startUtc,
        recurrence: recurrence,
      );
    }
  }

  // ── Native integration ───────────────────────────────────────────────────

  Future<bool> _armNative({
    required String clientId,
    required String planId,
    required String title,
    required DateTime startUtc,
    required CalendarRecurrence recurrence,
  }) async {
    if (_isAndroid) {
      try {
        final ok = await _channel.invokeMethod<bool>('scheduleTrigger', {
          'id': clientId,
          'planId': planId,
          'title': title,
          'startEpochMs': startUtc.millisecondsSinceEpoch,
          'recurrence': recurrence.channelValue,
        });
        return ok ?? false;
      } on PlatformException catch (e) {
        debugPrint('[PlanTriggerService] scheduleTrigger failed: $e');
        return false;
      }
    }
    if (_isIOS) {
      return _scheduleIosNotification(
        clientId: clientId,
        planId: planId,
        title: title,
        startUtc: startUtc,
      );
    }
    return false;
  }

  Future<void> _cancelNative(String clientId) async {
    if (_isAndroid) {
      try {
        await _channel.invokeMethod<void>('cancelTrigger', {'id': clientId});
      } on PlatformException catch (e) {
        debugPrint('[PlanTriggerService] cancelTrigger failed: $e');
      }
      return;
    }
    if (_isIOS) {
      await _notifications.cancel(_iosNotificationId(clientId));
    }
  }

  // ── iOS notification scheduling ──────────────────────────────────────────
  //
  // Limitation: iOS forbids launching the app into the foreground without
  // user interaction, so the "trigger" here is a notification the user taps.
  // The payload carries an `instructor://plan-start` deep link that the
  // existing notification-tap handler routes into PlanExecutionEngine.
  //
  // Recurring iOS triggers schedule only the next occurrence; the client
  // re-arms after each fire (matching the Android PlanAlarmReceiver loop).

  Future<bool> _scheduleIosNotification({
    required String clientId,
    required String planId,
    required String title,
    required DateTime startUtc,
  }) async {
    try {
      final when = tz.TZDateTime.from(startUtc, tz.local);
      final deepLink =
          'instructor://plan-start?planId=${Uri.encodeComponent(planId)}'
          '&triggerId=${Uri.encodeComponent(clientId)}';

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBanner: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      await _notifications.zonedSchedule(
        _iosNotificationId(clientId),
        'Time to start: $title',
        'Tap to begin your session',
        when,
        const NotificationDetails(iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: deepLink,
      );
      return true;
    } catch (e) {
      debugPrint('[PlanTriggerService] iOS schedule failed: $e');
      return false;
    }
  }

  int _iosNotificationId(String clientId) =>
      _planTriggerIosIdOffset + (clientId.hashCode & 0x0FFFFFFF);

  CalendarRecurrence _parseRecurrence(String value) {
    return CalendarRecurrence.values.firstWhere(
      (r) => r.channelValue == value,
      orElse: () => CalendarRecurrence.none,
    );
  }
}

@Riverpod(keepAlive: true)
PlanTriggerService planTriggerService(Ref ref) {
  return PlanTriggerService(
    ref.watch(planTriggerRepositoryProvider),
    FlutterLocalNotificationsPlugin(),
  );
}
