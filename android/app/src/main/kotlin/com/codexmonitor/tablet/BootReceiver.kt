package com.codexmonitor.tablet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Restores only the opt-in foreground collector; it never opens an Activity. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED && intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val preferences = context.getSharedPreferences(MonitoringService.preferencesName, Context.MODE_PRIVATE)
        val enabled = preferences.getBoolean(MonitoringService.enabledKey, false) ||
            preferences.getBoolean(MonitoringService.webServerEnabledKey, false)
        if (enabled) MonitoringService.start(context)
    }
}
