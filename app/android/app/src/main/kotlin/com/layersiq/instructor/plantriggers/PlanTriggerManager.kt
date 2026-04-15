package com.layersiq.instructor.plantriggers

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter ↔ Kotlin bridge for plan triggers.
 *
 * Channel: com.layersiq.instructor/plan_trigger
 *
 * Methods:
 *   canScheduleExactAlarms() → Bool
 *   openExactAlarmSettings()  → Void
 *   scheduleTrigger(args)     → Bool  (false = exact-alarm permission missing)
 *   cancelTrigger(id)         → Void
 *   listTriggers()            → List<Map> (for diagnostics / UI listing)
 *
 * scheduleTrigger args (Map<String, Any>):
 *   id            — String (client UUID, stable across devices)
 *   planId        — String
 *   title         — String
 *   startEpochMs  — Long
 *   recurrence    — String ('none'|'daily'|'weekdays'|'weekly')
 */
class PlanTriggerManager(private val appContext: Context) {

    private var channel: MethodChannel? = null

    fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL).apply {
            setMethodCallHandler { call, result -> handle(call, result) }
        }
    }

    fun unregister() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canScheduleExactAlarms" ->
                result.success(PlanTriggerScheduler.canScheduleExactAlarms(appContext))

            "openExactAlarmSettings" -> {
                PlanTriggerScheduler.openExactAlarmSettings(appContext)
                result.success(null)
            }

            "scheduleTrigger" -> {
                val args = call.arguments as? Map<*, *>
                if (args == null) {
                    result.error("INVALID_ARGS", "Expected Map", null); return
                }
                try {
                    val t = PlanTriggerStore.Trigger(
                        id = args["id"] as String,
                        planId = args["planId"] as String,
                        title = (args["title"] as? String) ?: "Plan",
                        startEpochMs = (args["startEpochMs"] as Number).toLong(),
                        recurrence = (args["recurrence"] as? String) ?: "none",
                    )
                    val ok = PlanTriggerScheduler.schedule(appContext, t)
                    result.success(ok)
                } catch (e: Exception) {
                    result.error("SCHEDULE_FAILED", e.message, null)
                }
            }

            "cancelTrigger" -> {
                val id = call.argument<String>("id")
                if (id.isNullOrEmpty()) {
                    result.error("INVALID_ARGS", "Missing id", null); return
                }
                PlanTriggerScheduler.cancel(appContext, id)
                result.success(null)
            }

            "listTriggers" -> {
                val triggers = PlanTriggerStore.load(appContext).map {
                    mapOf(
                        "id" to it.id,
                        "planId" to it.planId,
                        "title" to it.title,
                        "startEpochMs" to it.startEpochMs,
                        "recurrence" to it.recurrence,
                    )
                }
                result.success(triggers)
            }

            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL = "com.layersiq.instructor/plan_trigger"
    }
}
