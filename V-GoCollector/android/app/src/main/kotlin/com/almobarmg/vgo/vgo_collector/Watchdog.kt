package com.almobarmg.vgo.vgo_collector

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import android.telephony.SubscriptionManager

/**
 * Brings the relay back when Android has stopped it (ported from VIP Relay).
 *
 * Some phones (realme, Xiaomi) clear the app from recents on their own, and Android
 * 15 stops long-running services; WorkManager's 15-minute worker only relays, it
 * doesn't restart the service. Two alarms, both best-effort: a one-shot a few seconds
 * after the service is removed, and a repeating check every 15 minutes. Every alarm
 * call is guarded: a watchdog must never be the thing that crashes the app.
 */
object Watchdog {
    private const val REQUEST_RESTART = 20
    private const val REQUEST_PERIODIC = 21
    private const val PERIOD_MS = 15L * 60L * 1000L

    fun ensurePeriodic(context: Context) {
        try {
            alarms(context).setInexactRepeating(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime() + PERIOD_MS,
                PERIOD_MS,
                pending(context, REQUEST_PERIODIC)
            )
        } catch (_: Exception) {
            // No periodic check; START_STICKY, WorkManager and the boot receiver still apply.
        }
    }

    fun restartSoon(context: Context, delayMs: Long = 5_000L) {
        val at = SystemClock.elapsedRealtime() + delayMs
        val pi = pending(context, REQUEST_RESTART)
        val am = alarms(context)
        try {
            // An exact alarm is also what lets Android start a foreground service from
            // the background; USE_EXACT_ALARM grants it on 13+.
            if (Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()) {
                am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, at, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, at, pi)
            }
        } catch (_: Exception) {
            try {
                am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, at, pi)
            } catch (_: Exception) {
                // The periodic check will catch it.
            }
        }
    }

    private fun alarms(context: Context): AlarmManager =
        context.getSystemService(AlarmManager::class.java)

    private fun pending(context: Context, request: Int): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            request,
            Intent(context, WatchdogReceiver::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
}

class WatchdogReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val p = Prefs(context)
        if (p.paired && p.enabled) RelayService.start(context)
    }
}

/** Which SIM (1 / 2) a message came in on, for phones with two wallets of one kind. */
object SimSlots {
    fun fromSubscriptionId(context: Context, subId: Int): Int? {
        if (subId < 0) return null
        if (context.checkSelfPermission(Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) return null
        return try {
            val slot = context.getSystemService(SubscriptionManager::class.java)
                ?.getActiveSubscriptionInfo(subId)?.simSlotIndex?.plus(1)
            if (slot == 1 || slot == 2) slot else null
        } catch (_: Exception) {
            null
        }
    }
}
