package com.codexmonitor.tablet

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * A deliberately quiet, opt-in service. Its Dart isolate performs the same
 * Keystore-backed usage collection as the UI and sends only a remaining
 * percentage to this notification channel.
 */
class MonitoringService : Service() {
    private var engine: FlutterEngine? = null

    override fun onCreate() {
        super.onCreate()
        createChannel(this)
        startForeground(notificationId, notification(this, "监控运行中 · 等待同步"))
        engine = FlutterEngine(applicationContext).also { flutterEngine ->
            GeneratedPluginRegistrant.registerWith(flutterEngine)
            val entrypoint = DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "bootMonitorEntrypoint"
            )
            flutterEngine.dartExecutor.executeDartEntrypoint(entrypoint)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onDestroy() { engine?.destroy(); engine = null; super.onDestroy() }

    companion object {
        const val preferencesName = "codex_monitor_native"
        const val enabledKey = "boot_monitoring_enabled"
        private const val channelId = "codex_monitor_background"
        private const val notificationId = 4101

        fun start(context: Context) {
            val intent = Intent(context, MonitoringService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent) else context.startService(intent)
        }
        fun stop(context: Context) { context.stopService(Intent(context, MonitoringService::class.java)) }
        fun updateNotification(context: Context, remaining: String) {
            createChannel(context)
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .notify(notificationId, notification(context, "监控运行中 · 剩余 $remaining"))
        }
        private fun createChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(channelId, "Codex 额度监控", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "后台额度监控状态"
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                }
                (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
            }
        }
        private fun notification(context: Context, content: String): Notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(com.codexmonitor.tablet.R.mipmap.ic_launcher)
            .setContentTitle("Codex 额度监控")
            .setContentText(content)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setOngoing(true)
            .build()
    }
}
