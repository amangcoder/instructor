package com.layersiq.instructor.plantriggers

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Persists scheduled plan triggers to SharedPreferences so [PlanTriggerBootReceiver]
 * can re-arm them after reboot (AlarmManager state is wiped on boot).
 *
 * Stored as a JSON array under the single key [KEY_TRIGGERS]. Row identity is
 * [Trigger.id] — the client UUID from Flutter, also used as the PendingIntent
 * requestCode (reduced to an int via String.hashCode()).
 */
object PlanTriggerStore {

    private const val PREFS = "plan_triggers"
    private const val KEY_TRIGGERS = "triggers"

    data class Trigger(
        val id: String,
        val planId: String,
        val title: String,
        val startEpochMs: Long,
        val recurrence: String, // none | daily | weekdays | weekly
    ) {
        fun toJson(): JSONObject = JSONObject()
            .put("id", id)
            .put("planId", planId)
            .put("title", title)
            .put("startEpochMs", startEpochMs)
            .put("recurrence", recurrence)

        companion object {
            fun fromJson(obj: JSONObject) = Trigger(
                id = obj.getString("id"),
                planId = obj.getString("planId"),
                title = obj.optString("title", "Plan"),
                startEpochMs = obj.getLong("startEpochMs"),
                recurrence = obj.optString("recurrence", "none"),
            )
        }
    }

    fun put(ctx: Context, t: Trigger) {
        val all = load(ctx).filterNot { it.id == t.id }.toMutableList()
        all += t
        save(ctx, all)
    }

    fun remove(ctx: Context, id: String) {
        val all = load(ctx).filterNot { it.id == id }
        save(ctx, all)
    }

    fun get(ctx: Context, id: String): Trigger? = load(ctx).firstOrNull { it.id == id }

    fun load(ctx: Context): List<Trigger> {
        val raw = prefs(ctx).getString(KEY_TRIGGERS, null) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { Trigger.fromJson(arr.getJSONObject(it)) }
        }.getOrElse { emptyList() }
    }

    private fun save(ctx: Context, triggers: List<Trigger>) {
        val arr = JSONArray().apply { triggers.forEach { put(it.toJson()) } }
        prefs(ctx).edit().putString(KEY_TRIGGERS, arr.toString()).apply()
    }

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Compute PendingIntent requestCode deterministically from the trigger id. */
    fun requestCodeFor(id: String): Int = id.hashCode()
}
