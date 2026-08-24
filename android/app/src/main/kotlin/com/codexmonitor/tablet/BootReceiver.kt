package com.codexmonitor.tablet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Restores only the opt-in foreground collector; it never opens an Activity. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED && intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val enabled = context.getSharedPreferences(MonitoringService.preferencesName, Context.MODE_PRIVATE)
            .getBoolean(MonitoringService.enabledKey, false)
        if (enabled) MonitoringService.start(context)
    }
}
