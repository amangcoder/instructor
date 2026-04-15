package com.layersiq.instructor.plantriggers

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Notification
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.layersiq.instructor.MainActivity
import com.layersiq.instructor.R

/**
 * Fired by [AlarmManager] when a scheduled plan trigger reaches its start
 * time. Responsibilities, in order:
 *
 *   1. Acquire a short wake lock so the device stays awake long enough to
 *      build and post the notification.
 *   2. Post a high-priority full-screen notification with an
 *      `instructor://plan-start?planId=<id>&triggerId=<id>` deep link that
 *      launches [MainActivity]. Flutter parses this URI and auto-starts the
 *      plan via `PlanExecutionEngine`.
 *   3. If the trigger has a recurrence, compute the next occurrence and
 *      re-arm via [PlanTriggerScheduler]. Non-recurring triggers are removed
 *      from the store.
 */
class PlanAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_FIRE = "com.layersiq.instructor.PLAN_TRIGGER_FIRE"
        const val EXTRA_TRIGGER_ID = "triggerId"

        private const val TAG = "PlanAlarmReceiver"
        private const val CHANNEL_ID = "plan_triggers"
        private const val CHANNEL_NAME = "Plan start reminders"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val triggerId = intent.getStringExtra(EXTRA_TRIGGER_ID) ?: run {
            Log.w(TAG, "onReceive: missing triggerId")
            return
        }
        val trigger = PlanTriggerStore.get(context, triggerId) ?: run {
            Log.w(TAG, "onReceive: trigger $triggerId not in store (already cancelled?)")
            return
        }

        acquireWakeLock(context, 10_000).use {
            postStartNotification(context, trigger)
            rearmOrRemove(context, trigger)
        }
    }

    // ── Notification ─────────────────────────────────────────────────────────

    private fun postStartNotification(ctx: Context, t: PlanTriggerStore.Trigger) {
        ensureChannel(ctx)

        val deepLink = "instructor://plan-start?planId=${Uri.encode(t.planId)}" +
            "&triggerId=${Uri.encode(t.id)}"
        val openIntent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLink), ctx, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)

        val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val contentPi = PendingIntent.getActivity(ctx, t.id.hashCode(), openIntent, piFlags)

        val builder = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_instructor)
            .setContentTitle("Time to start: ${t.title}")
            .setContentText("Tap to begin your session")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(contentPi)
            .setFullScreenIntent(contentPi, true)

        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(t.id.hashCode(), builder.build())
    }

    private fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Alerts when a scheduled plan session is starting"
            setShowBadge(true)
        }
        nm.createNotificationChannel(channel)
    }

    // ── Recurrence ───────────────────────────────────────────────────────────

    private fun rearmOrRemove(ctx: Context, t: PlanTriggerStore.Trigger) {
        if (t.recurrence == "none") {
            PlanTriggerStore.remove(ctx, t.id)
            return
        }
        // Advance startEpochMs to the next occurrence and reschedule.
        val next = PlanTriggerScheduler.nextFire(
            t.copy(startEpochMs = t.startEpochMs + 1_000), // force advance past current fire
        )
        if (next == null) {
            PlanTriggerStore.remove(ctx, t.id)
            return
        }
        PlanTriggerScheduler.schedule(ctx, t.copy(startEpochMs = next))
    }

    // ── Wake lock ────────────────────────────────────────────────────────────

    private fun acquireWakeLock(ctx: Context, timeoutMs: Long): AutoCloseable {
        val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wl = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "instructor:plan-trigger",
        )
        wl.setReferenceCounted(false)
        wl.acquire(timeoutMs)
        return AutoCloseable { if (wl.isHeld) wl.release() }
    }
}
