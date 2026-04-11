package com.layersiq.instructor

import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

/**
 * MainActivity for Instructor.
 *
 * Extends [AudioServiceActivity] (from the audio_service plugin) which
 * handles MediaSession lifecycle, foreground-service binding, and the
 * Flutter engine setup.
 *
 * ## Notification body-tap navigation (REQ-004)
 *
 * The audio_service plugin creates a PendingIntent that brings this
 * Activity to the foreground when the user taps the body of the Android
 * foreground notification (the non-button area). Because the Activity is
 * declared with `android:launchMode="singleTop"` in the manifest, Android
 * calls [onNewIntent] instead of [onCreate] when the activity is already
 * running (foreground or back-stack).
 *
 * [onNewIntent] invokes the Flutter MethodChannel
 * `"com.instructor.app/notification"` with method `"notificationTapped"`.
 * The Flutter side listens on this channel and calls
 * `GoRouter.go('/now-playing')` with deduplication (skips the push if the
 * current route is already `/now-playing`).
 */
class MainActivity : AudioServiceActivity() {

    companion object {
        /** MethodChannel name agreed between Kotlin and Flutter. */
        private const val NOTIFICATION_CHANNEL = "com.instructor.app/notification"
    }

    private var notificationChannel: MethodChannel? = null

    // ── Flutter engine setup ──────────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_CHANNEL,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        notificationChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // ── Notification body-tap ─────────────────────────────────────────────────

    /**
     * Called when the activity receives a new Intent while it is already
     * running at the top of the task stack (`launchMode="singleTop"`).
     *
     * The audio_service PendingIntent already brings the Activity to the
     * foreground; this override notifies Flutter so the router can navigate
     * to the Now Playing screen.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        notificationChannel?.invokeMethod("notificationTapped", null)
    }
}
