package com.codexmonitor.tablet

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Bundle
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Debug
import android.os.SystemClock
import java.io.File
import java.net.Inet4Address
import java.net.NetworkInterface
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
    }

    override fun onStart() {
        super.onStart()
        // The foreground UI already owns polling. Do not retain a second
        // FlutterEngine in the monitoring service while the dashboard is open.
        MonitoringService.setAppVisible(this, true)
    }

    override fun onStop() {
        MonitoringService.setAppVisible(this, false)
        super.onStop()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "codex_monitor/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> {
                        val battery = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                        val memoryInfo = Debug.MemoryInfo()
                        Debug.getMemoryInfo(memoryInfo)
                        val connectivity = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                        val wifiIp = wifiIpv4Address(connectivity)
                        val status = battery?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
                        val plugged = battery?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
                        val temp = battery?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1) ?: -1
                        result.success(mapOf(
                            "uptimeSeconds" to SystemClock.elapsedRealtime() / 1000,
                            "charging" to (status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL || plugged != 0),
                            "full" to (status == BatteryManager.BATTERY_STATUS_FULL),
                            "temperatureC" to if (temp >= 0) temp / 10.0 else null,
                            // totalPss is reported in KiB and includes the app's
                            // native and managed memory with shared pages apportioned.
                            "memoryMb" to memoryInfo.totalPss / 1024.0,
                            "wifiIp" to wifiIp
                        ))
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "codex_monitor/network_proxy")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "activeProxy" -> {
                        val connectivity = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                        val proxy = connectivity.getLinkProperties(connectivity.activeNetwork)?.httpProxy
                        if (proxy == null || proxy.host.isNullOrBlank() || proxy.port <= 0) {
                            result.success(null)
                        } else {
                            result.success(mapOf(
                                "host" to proxy.host,
                                "port" to proxy.port,
                                // MethodChannel supports List but not String[].
                                "exclusionList" to proxy.exclusionList.toList()
                            ))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "codex_monitor/foreground_monitor")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setModes" -> {
                        val bootMonitoring = call.argument<Boolean>("bootMonitoring") ?: false
                        val webServerEnabled = call.argument<Boolean>("webServerEnabled") ?: false
                        val enabled = bootMonitoring || webServerEnabled
                        getSharedPreferences(MonitoringService.preferencesName, Context.MODE_PRIVATE)
                            .edit()
                            .putBoolean(MonitoringService.enabledKey, bootMonitoring)
                            .putBoolean(MonitoringService.webServerEnabledKey, webServerEnabled)
                            .apply()
                        if (enabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4101)
                        }
                        if (enabled && !MonitoringService.appVisible) {
                            MonitoringService.start(this)
                        } else {
                            MonitoringService.stop(this)
                        }
                        result.success(null)
                    }
                    "updateNotification" -> {
                        MonitoringService.updateNotification(this, call.argument<String>("remaining") ?: "--")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "codex_monitor/adb_credential_import")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeStagedCredentials" -> {
                        val debuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
                        if (!debuggable) {
                            result.error("debug_only", "ADB credential import is disabled in release builds", null)
                            return@setMethodCallHandler
                        }
                        val staged = File(filesDir, ".adb-auth-import.json")
                        if (!staged.exists()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(staged.readText(Charsets.UTF_8))
                        } catch (_: Exception) {
                            result.error("staged_read_failed", "Unable to read staged credentials", null)
                        } finally {
                            // Do not leave a duplicate of auth.json in the app sandbox.
                            staged.delete()
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Resolve the physical Wi-Fi address even while a VPN owns activeNetwork.
     * VPN capabilities can inherit TRANSPORT_WIFI from their underlying
     * network, so reading LinkProperties from activeNetwork may return tun0.
     */
    private fun wifiIpv4Address(connectivity: ConnectivityManager): String? {
        val fromConnectivity = connectivity.allNetworks
            .asSequence()
            .filter { network ->
                val capabilities = connectivity.getNetworkCapabilities(network)
                capabilities != null &&
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) &&
                    !capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
            }
            .mapNotNull(connectivity::getLinkProperties)
            .flatMap { it.linkAddresses.asSequence() }
            .map { it.address }
            .filterIsInstance<Inet4Address>()
            .firstOrNull { !it.isLoopbackAddress }
            ?.hostAddress
        if (fromConnectivity != null) return fromConnectivity

        return try {
            NetworkInterface.getNetworkInterfaces()
                ?.toList()
                ?.asSequence()
                ?.filter { it.isUp && !it.isLoopback && it.name.startsWith("wlan") }
                ?.flatMap { it.inetAddresses.toList().asSequence() }
                ?.filterIsInstance<Inet4Address>()
                ?.firstOrNull { !it.isLoopbackAddress }
                ?.hostAddress
        } catch (_: Exception) {
            null
        }
    }
}
