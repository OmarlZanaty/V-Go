package com.almobarmg.vgo.vgo_collector

import android.annotation.SuppressLint
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Bridge between the Flutter screens and the native relay. */
class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vgo.collector/native")
            .setMethodCallHandler { call, result ->
                val p = Prefs(this)
                when (call.method) {
                    "status" -> result.success(status())
                    "pair" -> background(result) {
                        Relay.pair(this, call.argument<String>("baseUrl") ?: "", call.argument<String>("code") ?: "",
                            RelayService.appVersion(this))?.also { return@background it }
                        Relay.heartbeat(this, RelayService.appVersion(this))
                        main.post { RelayService.start(this) }
                        null
                    }
                    "unpair" -> {
                        RelayService.stop(this)
                        p.unpair()
                        result.success(null)
                    }
                    "setEnabled" -> {
                        val on = call.argument<Boolean>("enabled") == true
                        p.enabled = on
                        if (on) RelayService.start(this) else RelayService.stop(this)
                        result.success(null)
                    }
                    "syncNow" -> background(result) {
                        val sent = Relay.sweep(this)
                        Relay.heartbeat(this, RelayService.appVersion(this))
                        sent
                    }
                    "startService" -> {
                        if (p.paired && p.enabled) RelayService.start(this)
                        result.success(null)
                    }
                    "requestBatteryExemption" -> result.success(requestBatteryExemption())
                    "openAppSettings" -> {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    "openAutostart" -> result.success(openAutostart())
                    "openNotificationAccess" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            val value = try { work() } catch (e: Exception) { e.message ?: e.javaClass.simpleName }
            main.post { result.success(value) }
        }
    }

    private fun status(): Map<String, Any?> {
        val p = Prefs(this)
        val pm = getSystemService(PowerManager::class.java)
        return mapOf(
            "paired" to p.paired,
            "enabled" to p.enabled,
            "baseUrl" to p.baseUrl,
            "deviceName" to p.deviceName,
            "lastSweepAt" to p.lastSweepAt,
            "lastHeartbeatAt" to p.lastHeartbeatAt,
            "lastHeartbeatOk" to p.lastHeartbeatOk,
            "lastError" to p.lastError,
            "pending" to p.pending,
            "sentTotal" to p.sentTotal,
            "wallets" to p.walletsJson,
            "log" to p.logJson,
            "smsPermission" to Relay.hasSmsPermission(this),
            "notificationAccess" to NotifListener.hasAccess(this),
            "queuedNotifications" to org.json.JSONArray(p.notificationQueue).length(),
            "ignoringBattery" to (pm?.isIgnoringBatteryOptimizations(packageName) == true),
            "manufacturer" to Build.MANUFACTURER,
            "sdk" to Build.VERSION.SDK_INT,
            "appVersion" to RelayService.appVersion(this),
        )
    }

    @SuppressLint("BatteryLife")
    private fun requestBatteryExemption(): Boolean = try {
        startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
        true
    } catch (_: Exception) {
        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        false
    }

    /** Xiaomi / Oppo / Vivo / Huawei keep their own "autostart" list. */
    private fun openAutostart(): Boolean {
        val candidates = listOf(
            ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
            ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
            ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
        )
        for (c in candidates) {
            try {
                startActivity(Intent().setComponent(c).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (_: Exception) { }
        }
        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
        return false
    }
}
