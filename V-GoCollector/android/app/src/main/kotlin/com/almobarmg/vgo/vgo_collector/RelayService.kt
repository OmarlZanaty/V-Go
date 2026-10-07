package com.almobarmg.vgo.vgo_collector

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

/**
 * Keeps the relay running: sweeps the inbox every 20 seconds and reports to the
 * server every heartbeat interval, with a permanent notification so the system
 * doesn't kill it. WorkManager (every 15 minutes) and the SMS receiver cover the
 * gaps if it is killed anyway.
 */
class RelayService : Service() {
    private var executor: ScheduledExecutorService? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        startInForeground("بيشتغل…")
        if (executor == null) {
            executor = Executors.newSingleThreadScheduledExecutor().also { ex ->
                ex.scheduleWithFixedDelay({ tick() }, 0, SWEEP_SECONDS, TimeUnit.SECONDS)
            }
        }
        return START_STICKY
    }

    private fun tick() {
        try {
            val p = Prefs(this)
            if (!p.paired || !p.enabled) {
                updateNotification(if (!p.paired) "مش مربوط بالسيرفر" else "متوقف")
                return
            }
            Relay.sweep(this)
            if (System.currentTimeMillis() - p.lastHeartbeatAt >= p.heartbeatSeconds * 1000L) {
                Relay.heartbeat(this, appVersion(this))
            }
            val time = SimpleDateFormat("HH:mm", Locale.US).format(Date(p.lastSweepAt))
            updateNotification(p.lastError?.let { "⚠ $it" } ?: "آخر مزامنة $time — اتبعت ${p.sentTotal} رسالة")
        } catch (e: Exception) {
            Log.e("VGoRelay", "tick failed", e)
        }
    }

    private fun notification(text: String): Notification {
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("V-Go تحصيل")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun startInForeground(text: String) {
        ensureChannel(this)
        val type = if (Build.VERSION.SDK_INT >= 34) ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification(text), type)
    }

    private fun updateNotification(text: String) {
        getSystemService(NotificationManager::class.java)?.notify(NOTIFICATION_ID, notification(text))
    }

    override fun onDestroy() {
        executor?.shutdownNow()
        executor = null
        super.onDestroy()
    }

    companion object {
        const val CHANNEL = "relay"
        const val NOTIFICATION_ID = 41
        const val ACTION_STOP = "stop"
        private const val SWEEP_SECONDS = 20L

        fun ensureChannel(context: Context) {
            val nm = context.getSystemService(NotificationManager::class.java) ?: return
            if (nm.getNotificationChannel(CHANNEL) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL, "خدمة التحصيل", NotificationManager.IMPORTANCE_LOW)
                )
            }
        }

        fun appVersion(context: Context): String = try {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "?"
        } catch (_: Exception) { "?" }

        /** Starts the service (when allowed) and makes sure the 15-minute safety net is scheduled. */
        fun start(context: Context) {
            schedulePeriodic(context)
            try {
                ContextCompat.startForegroundService(context, Intent(context, RelayService::class.java))
            } catch (e: Exception) {
                // Android 12+ refuses to start a foreground service from the background;
                // the periodic worker keeps relaying until the app is opened again.
                Log.w("VGoRelay", "service start refused: ${e.javaClass.simpleName}")
            }
        }

        fun stop(context: Context) {
            context.startService(Intent(context, RelayService::class.java).setAction(ACTION_STOP))
        }

        fun schedulePeriodic(context: Context) {
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "relay-periodic",
                ExistingPeriodicWorkPolicy.KEEP,
                PeriodicWorkRequestBuilder<RelayWorker>(15, TimeUnit.MINUTES).build()
            )
        }
    }
}
