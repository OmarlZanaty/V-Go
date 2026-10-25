package com.almobarmg.vgo.collector

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import android.telephony.SmsManager
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

/** Runs only on the OTP worker. SMS bodies/codes are never written to logs or preferences. */
object OtpSender {
    private val requestCodes = AtomicInteger(1000)

    fun hasPermission(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED

    @Synchronized
    fun poll(context: Context) {
        val app = context.applicationContext
        val p = Prefs(app)
        val key = p.deviceKey ?: return
        if (!p.enabled || !p.otpEnabled || !hasPermission(app)) return
        try {
            // Retry acknowledgements before fetching more work, without sending the SMS again.
            if (!reportPending(p, key)) return
            val http = Relay.request(p.baseUrl, "outbox?max=5", "GET", null, key, 5000)
            if (http.code != 200) {
                p.otpLastError = "تعذر تحميل أكواد التحقق (HTTP ${http.code})"
                return
            }
            val messages = JSONObject(http.body).getJSONArray("data")
            val sends = mutableListOf<Pair<String, Sending>>()
            try {
                // Start the whole batch first: five sequential 30-second waits would exceed the lease.
                for (i in 0 until messages.length()) {
                    val message = messages.getJSONObject(i)
                    val id = message.getString("id")
                    val sending = if (p.deviceKey == key && p.enabled && p.otpEnabled && hasPermission(app)) {
                        startSend(app, p.otpSubscriptionId, message.getString("to"), message.getString("body"))
                    } else Sending.completed("SENDING_DISABLED")
                    sends += id to sending
                }
                val results = JSONArray(p.otpPendingResults)
                for ((id, sending) in sends) {
                    val error = sending.awaitResult()
                    val sent = error == null
                    if (sent) p.otpSentTotal = p.otpSentTotal + 1
                    p.otpLastError = error
                    results.put(JSONObject().put("id", id).put("sent", sent)
                        .put("error", error ?: JSONObject.NULL)
                        .put("device", key.substringBefore('.')).put("server", p.baseUrl))
                    // Persist each outcome before any HTTP request; a lost response must not resend it.
                    p.otpPendingResults = results.toString()
                }
            } finally {
                sends.forEach { it.second.close(app) }
            }
            reportPending(p, key)
        } catch (_: Exception) {
            // Exceptions from telephony/HTTP can contain message text, so never log them.
            p.otpLastError = "تعذر الاتصال بخدمة أكواد التحقق"
        }
    }

    private fun reportPending(p: Prefs, key: String): Boolean {
        val queue = JSONArray(p.otpPendingResults)
        val remaining = JSONArray()
        var unavailable = false
        for (i in 0 until queue.length()) {
            val item = queue.getJSONObject(i)
            if (item.optString("device") != key.substringBefore('.') || item.optString("server") != p.baseUrl) continue
            if (unavailable) {
                remaining.put(item)
                continue
            }
            val code = try {
                Relay.request(p.baseUrl, "outbox/${item.getString("id")}/result", "POST",
                    JSONObject().put("sent", item.getBoolean("sent")).put("error", item.opt("error") ?: JSONObject.NULL),
                    key, 2000).code
            } catch (_: Exception) { 0 }
            // 409 means this lease is no longer ours; it must never be reported for another device.
            if (code != 200 && code != 409) {
                remaining.put(item)
                unavailable = true
                p.otpLastError = "تعذر تأكيد إرسال الأكواد للسيرفر"
            }
        }
        p.otpPendingResults = remaining.toString()
        return !unavailable
    }

    @Suppress("DEPRECATION")
    private fun manager(context: Context, subscriptionId: Int): SmsManager {
        if (subscriptionId == -1) return SmsManager.getDefault()
        return if (Build.VERSION.SDK_INT >= 31) {
            val base = context.getSystemService(SmsManager::class.java)
                ?: throw UnsupportedOperationException()
            base.createForSubscriptionId(subscriptionId)
        } else SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
    }

    @SuppressLint("MissingPermission", "UnspecifiedRegisterReceiverFlag")
    private fun startSend(context: Context, subscriptionId: Int, to: String, body: String): Sending {
        var sending: Sending? = null
        return try {
            val sms = manager(context, subscriptionId)
            val parts = sms.divideMessage(body)
            if (parts.isEmpty()) return Sending.completed("RESULT_ERROR_NULL_PDU")
            val state = Sending(parts.size)
            sending = state
            val action = "${context.packageName}.OTP_SENT.${UUID.randomUUID()}"
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    val part = intent.getIntExtra("part", -1)
                    if (part !in state.received.indices || state.received[part]) return
                    state.received[part] = true
                    if (resultCode != Activity.RESULT_OK) state.error.compareAndSet(null, resultName(resultCode))
                    state.latch.countDown()
                }
            }
            if (Build.VERSION.SDK_INT >= 33) {
                context.registerReceiver(receiver, IntentFilter(action), Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.registerReceiver(receiver, IntentFilter(action))
            }
            state.receiver = receiver
            for (i in parts.indices) {
                state.intents += PendingIntent.getBroadcast(context, requestCodes.getAndIncrement(),
                    Intent(action).setPackage(context.packageName).putExtra("part", i),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_ONE_SHOT)
            }
            sms.sendMultipartTextMessage(to, null, parts, state.intents, null)
            state
        } catch (_: SecurityException) {
            sending?.close(context)
            Sending.completed("SEND_SMS_PERMISSION_DENIED")
        } catch (_: IllegalArgumentException) {
            sending?.close(context)
            Sending.completed("RESULT_INVALID_ARGUMENTS")
        } catch (_: Exception) {
            sending?.close(context)
            Sending.completed("RESULT_ERROR_GENERIC_FAILURE")
        }
    }

    private fun resultName(code: Int): String =
        SmsManager::class.java.fields.firstOrNull {
            it.name.startsWith("RESULT_") && it.type == Int::class.javaPrimitiveType &&
                runCatching { it.getInt(null) == code }.getOrDefault(false)
        }?.name ?: "RESULT_UNKNOWN_$code"

    private class Sending(parts: Int) {
        val latch = CountDownLatch(parts)
        val error = AtomicReference<String?>(null)
        val received = BooleanArray(parts)
        val intents = arrayListOf<PendingIntent>()
        var receiver: BroadcastReceiver? = null
        private val deadline = SystemClock.elapsedRealtime() + 30_000L

        fun awaitResult(): String? {
            try {
                if (!latch.await((deadline - SystemClock.elapsedRealtime()).coerceAtLeast(0), TimeUnit.MILLISECONDS)) {
                    error.compareAndSet(null, "TIMEOUT")
                }
            } catch (_: InterruptedException) {
                error.compareAndSet(null, "INTERRUPTED")
                Thread.currentThread().interrupt()
            }
            return error.get()
        }

        fun close(context: Context) {
            receiver?.let { runCatching { context.unregisterReceiver(it) } }
            receiver = null
            intents.forEach { it.cancel() }
        }

        companion object {
            fun completed(error: String) = Sending(0).also { it.error.set(error) }
        }
    }
}
