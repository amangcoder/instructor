package com.layersiq.instructor.plantriggers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Re-arms all stored plan triggers after the device reboots or the app is
 * reinstalled. AlarmManager state is wiped on reboot, so without this the
 * user would silently stop receiving scheduled session reminders.
 */
class PlanTriggerBootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED
        ) return
        Log.i("PlanTriggerBoot", "Re-arming plan triggers after: $action")
        PlanTriggerScheduler.rescheduleAll(context)
    }
}
