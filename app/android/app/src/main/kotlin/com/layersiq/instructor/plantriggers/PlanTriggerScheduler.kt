package com.layersiq.instructor.plantriggers

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import java.util.Calendar
import java.util.TimeZone

/**
 * Schedules / cancels exact alarms for plan triggers.
 *
 * Uses [AlarmManager.setExactAndAllowWhileIdle] with RTC_WAKEUP so alarms
 * fire at the exact wall-clock time even during Doze.
 *
 * Recurrence is implemented by re-arming the next occurrence inside
 * [PlanAlarmReceiver] after each fire — one-shot setExact is the only API
 * that survives Doze, so setRepeating is avoided.
 */
object PlanTriggerScheduler {

    private const val TAG = "PlanTriggerScheduler"

    /**
     * Compute the next fire time for a trigger. If [t.startEpochMs] is in the
     * future, returns it unchanged. Otherwise advances by the recurrence step
     * until it is in the future. Returns null when non-recurring and expired.
     */
    fun nextFire(t: PlanTriggerStore.Trigger, now: Long = System.currentTimeMillis()): Long? {
        if (t.startEpochMs > now) return t.startEpochMs
        return when (t.recurrence) {
            "daily" -> advanceDaily(t.startEpochMs, now)
            "weekly" -> advanceWeekly(t.startEpochMs, now)
            "weekdays" -> advanceWeekdays(t.startEpochMs, now)
            else -> null
        }
    }

    fun schedule(ctx: Context, t: PlanTriggerStore.Trigger): Boolean {
        val fireAt = nextFire(t) ?: run {
            Log.w(TAG, "schedule: trigger ${t.id} has no future occurrence; removing")
            PlanTriggerStore.remove(ctx, t.id)
            return false
        }

        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
            Log.w(TAG, "schedule: SCHEDULE_EXACT_ALARM not granted")
            return false
        }

        val pi = buildPendingIntent(ctx, t)
        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pi)
        PlanTriggerStore.put(ctx, t)
        Log.i(TAG, "schedule: ${t.id} planId=${t.planId} fireAt=$fireAt recurrence=${t.recurrence}")
        return true
    }

    fun cancel(ctx: Context, id: String) {
        val stored = PlanTriggerStore.get(ctx, id)
        if (stored != null) {
            val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(buildPendingIntent(ctx, stored, flagsForCancel = true))
        }
        PlanTriggerStore.remove(ctx, id)
        Log.i(TAG, "cancel: $id")
    }

    /**
     * Re-arm every stored trigger. Called by [PlanTriggerBootReceiver] after
     * device boot and by app startup as a safety net.
     */
    fun rescheduleAll(ctx: Context) {
        val all = PlanTriggerStore.load(ctx)
        Log.i(TAG, "rescheduleAll: ${all.size} triggers")
        for (t in all) schedule(ctx, t)
    }

    fun canScheduleExactAlarms(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return am.canScheduleExactAlarms()
    }

    fun openExactAlarmSettings(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            data = android.net.Uri.fromParts("package", ctx.packageName, null)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        ctx.startActivity(intent)
    }

    /**
     * Whether a notification with `setFullScreenIntent` will actually elevate
     * to a full-screen take-over on this device. On Android 14+ this requires
     * the [Manifest.permission.USE_FULL_SCREEN_INTENT] permission to be granted
     * to the app — Google grants it by default only to apps in the default
     * Phone/Alarm/Calendar role; other apps must request it via Settings.
     * Returns true on Android 13 and below (no runtime gate).
     */
    fun canUseFullScreenIntent(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.canUseFullScreenIntent()
    }

    /**
     * Opens the per-app "Allow full screen intent" settings page on Android
     * 14+. No-op below 14. Falls back to the app-details page if the specific
     * action is unavailable on this device.
     */
    fun openFullScreenIntentSettings(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
            data = android.net.Uri.fromParts("package", ctx.packageName, null)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            ctx.startActivity(intent)
        } catch (e: Exception) {
            Log.w(TAG, "openFullScreenIntentSettings: falling back to app details", e)
            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.fromParts("package", ctx.packageName, null)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            ctx.startActivity(fallback)
        }
    }

    // ── Internal ─────────────────────────────────────────────────────────────

    private fun buildPendingIntent(
        ctx: Context,
        t: PlanTriggerStore.Trigger,
        flagsForCancel: Boolean = false,
    ): PendingIntent {
        val intent = Intent(ctx, PlanAlarmReceiver::class.java).apply {
            action = PlanAlarmReceiver.ACTION_FIRE
            putExtra(PlanAlarmReceiver.EXTRA_TRIGGER_ID, t.id)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(ctx, PlanTriggerStore.requestCodeFor(t.id), intent, flags)
    }

    // ── Recurrence math ───────────────────────────────────────────────────────
    //
    // All math is done in the device's default time zone so "daily at 08:00"
    // survives DST changes correctly.

    private fun calendarAt(epochMs: Long): Calendar =
        Calendar.getInstance(TimeZone.getDefault()).apply { timeInMillis = epochMs }

    private fun advanceDaily(startEpochMs: Long, now: Long): Long {
        val c = calendarAt(startEpochMs)
        while (c.timeInMillis <= now) c.add(Calendar.DAY_OF_YEAR, 1)
        return c.timeInMillis
    }

    private fun advanceWeekly(startEpochMs: Long, now: Long): Long {
        val c = calendarAt(startEpochMs)
        while (c.timeInMillis <= now) c.add(Calendar.WEEK_OF_YEAR, 1)
        return c.timeInMillis
    }

    private fun advanceWeekdays(startEpochMs: Long, now: Long): Long {
        val c = calendarAt(startEpochMs)
        do {
            c.add(Calendar.DAY_OF_YEAR, 1)
        } while (c.timeInMillis <= now || isWeekend(c))
        return c.timeInMillis
    }

    private fun isWeekend(c: Calendar): Boolean {
        val d = c.get(Calendar.DAY_OF_WEEK)
        return d == Calendar.SATURDAY || d == Calendar.SUNDAY
    }
}
