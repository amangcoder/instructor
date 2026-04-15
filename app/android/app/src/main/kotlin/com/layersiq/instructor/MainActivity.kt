package com.layersiq.instructor

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity
import com.layersiq.instructor.plantriggers.PlanTriggerManager
import com.layersiq.instructor.plantriggers.PlanTriggerScheduler

/**
 * MainActivity for Instructor.
 *
 * Extends [AudioServiceActivity] (from the audio_service plugin) which
 * handles MediaSession lifecycle, foreground-service binding, and the
 * Flutter engine setup.
 *
 * Channels registered here:
 *   - com.instructor.app/notification        — notification body-tap (REQ-004)
 *   - com.layersiq.instructor/calendar        — iOS-style calendar API
 *                                              (only "openAppSettings" on Android)
 *   - com.layersiq.instructor/plan_trigger    — Android exact-alarm scheduling
 *
 * Deep links:
 *   instructor://plan-start?planId=…&triggerId=…
 *     Fired by [PlanAlarmReceiver] when an exact alarm reaches its start
 *     time. onNewIntent forwards the URI to Flutter via the notification
 *     channel so the router can auto-start the plan session.
 */
class MainActivity : AudioServiceActivity() {

    companion object {
        private const val NOTIFICATION_CHANNEL = "com.instructor.app/notification"
        private const val CALENDAR_CHANNEL = "com.layersiq.instructor/calendar"
    }

    private var notificationChannel: MethodChannel? = null
    private var calendarChannel: MethodChannel? = null
    private var planTriggerManager: PlanTriggerManager? = null

    // ── Flutter engine setup ──────────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        notificationChannel = MethodChannel(messenger, NOTIFICATION_CHANNEL)

        calendarChannel = MethodChannel(messenger, CALENDAR_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAppSettings" -> {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        planTriggerManager = PlanTriggerManager(applicationContext).apply {
            register(messenger)
        }

        // Safety net: re-arm alarms on every app start in case the boot
        // receiver missed (e.g. direct-boot device not yet unlocked).
        PlanTriggerScheduler.rescheduleAll(applicationContext)

        // Handle cold-start deep link (app launched by tapping the notification).
        intent?.let { forwardPlanTriggerDeepLink(it) }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        notificationChannel = null
        calendarChannel?.setMethodCallHandler(null)
        calendarChannel = null
        planTriggerManager?.unregister()
        planTriggerManager = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // ── Intent handling ───────────────────────────────────────────────────────

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Existing contract: notify Flutter for in-app notification taps.
        notificationChannel?.invokeMethod("notificationTapped", null)
        // Plan-trigger deep link: forward as a structured payload so the
        // router can auto-start the session.
        forwardPlanTriggerDeepLink(intent)
    }

    private fun forwardPlanTriggerDeepLink(intent: Intent) {
        val uri = intent.data ?: return
        if (uri.scheme != "instructor" || uri.host != "plan-start") return
        val payload = mapOf(
            "planId" to (uri.getQueryParameter("planId") ?: ""),
            "triggerId" to (uri.getQueryParameter("triggerId") ?: ""),
        )
        notificationChannel?.invokeMethod("planTriggerFired", payload)
    }
}
