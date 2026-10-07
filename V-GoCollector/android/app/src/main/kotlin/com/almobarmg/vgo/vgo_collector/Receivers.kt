package com.almobarmg.vgo.vgo_collector

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

/**
 * A new SMS arrived: upload it right away instead of waiting for the next sweep.
 * The default SMS app writes it to the inbox a moment after this broadcast, so wait
 * briefly, then sweep (the same idempotent inbox scan the service runs).
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val p = Prefs(context)
        if (!p.paired || !p.enabled) return
        val pending = goAsync()
        Thread {
            try {
                Thread.sleep(3000)
                Relay.sweep(context, timeoutMs = 7000)
            } catch (e: Exception) {
                Log.w("VGoRelay", "sms-triggered sweep failed", e)
            } finally {
                pending.finish()
            }
        }.start()
    }
}

/** Phone restarted or the app was updated: bring the relay back. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Prefs(context).paired) RelayService.start(context)
    }
}

/** 15-minute safety net in case the service was killed. */
class RelayWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val p = Prefs(applicationContext)
        if (!p.paired || !p.enabled) return Result.success()
        Relay.sweep(applicationContext)
        Relay.heartbeat(applicationContext, RelayService.appVersion(applicationContext))
        return Result.success()
    }
}
