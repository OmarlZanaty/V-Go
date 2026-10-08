package com.almobarmg.vgo.vgo_collector

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.BatteryManager
import android.util.Log
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Reads the wallet notification SMS from the phone's inbox and uploads the ones the
 * server doesn't have yet. The inbox (not the broadcast) is the source of truth: every
 * run re-reads the last `lookbackHours`, so a message missed while the phone was off,
 * offline or the app was killed is picked up on the next run. Each message is uploaded
 * with a stable id (inbox _id + date), so retries are idempotent on the server.
 */
object Relay {
    private const val TAG = "VGoRelay"
    private const val BATCH = 50

    data class Http(val code: Int, val body: String)

    private fun request(baseUrl: String, path: String, method: String, body: JSONObject?, key: String?, timeoutMs: Int = 15000): Http {
        val conn = URL("$baseUrl/api/Collector/$path").openConnection() as HttpURLConnection
        try {
            conn.requestMethod = method
            conn.connectTimeout = timeoutMs
            conn.readTimeout = timeoutMs
            conn.setRequestProperty("Accept", "application/json")
            if (key != null) conn.setRequestProperty("X-Device-Key", key)
            if (body != null) {
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                conn.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            }
            val code = conn.responseCode
            val stream = if (code < 400) conn.inputStream else conn.errorStream
            val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""
            return Http(code, text)
        } finally {
            conn.disconnect()
        }
    }

    private fun serverMessage(http: Http): String? =
        runCatching { JSONObject(http.body).optString("message").takeIf { it.isNotBlank() } }.getOrNull()

    private fun describe(http: Http): String = when (http.code) {
        401 -> serverMessage(http) ?: "الموبايل مش مربوط أو اتوقف من لوحة التحكم"
        404 -> "العنوان ده مش سيرفر V-Go فيه التحصيل"
        429 -> "طلبات كتير ورا بعض، هنحاول تاني"
        in 500..599 -> "السيرفر عنده مشكلة (${http.code})"
        else -> serverMessage(http) ?: "السيرفر رد بـ ${http.code}"
    }

    // ---------------------------------------------------------------- pairing (UI thread → worker thread)

    /** Checks the address is a V-Go server with collection; null when fine, else a message. */
    fun ping(baseUrl: String): String? = try {
        val http = request(baseUrl.trimEnd('/'), "ping", "GET", null, null, 10000)
        when {
            http.code == 404 -> "العنوان ده سيرفر مافيهوش التحصيل (أو العنوان غلط)"
            http.code != 200 -> describe(http)
            !http.body.contains("vgo-collector") -> "العنوان ده مش سيرفر V-Go"
            else -> null
        }
    } catch (e: Exception) {
        "السيرفر مش بيرد: ${e.javaClass.simpleName}"
    }

    /** Exchanges the dashboard code for a device key. Returns null on success, else a message. */
    fun pair(context: Context, baseUrl: String, code: String, appVersion: String): String? {
        ping(baseUrl)?.let { return it }
        return try {
            val body = JSONObject()
                .put("code", code.trim())
                .put("deviceName", android.os.Build.MODEL)
                .put("appVersion", appVersion)
            val http = request(baseUrl.trimEnd('/'), "pair", "POST", body, null)
            if (http.code != 200) return describe(http)
            val data = JSONObject(http.body).getJSONObject("data")
            val p = Prefs(context)
            p.baseUrl = baseUrl
            p.deviceKey = data.getString("deviceKey")
            p.deviceName = data.optString("name")
            p.lastError = null
            p.enabled = true
            null
        } catch (e: Exception) {
            "فشل الربط: ${e.message ?: e.javaClass.simpleName}"
        }
    }

    // ---------------------------------------------------------------- heartbeat

    @Synchronized
    fun heartbeat(context: Context, appVersion: String) {
        val p = Prefs(context)
        val key = p.deviceKey ?: return
        try {
            val battery = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
            val plugged = (battery?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0) != 0
            val body = JSONObject()
                .put("appVersion", appVersion)
                .put("battery", if (level >= 0) level * 100 / scale else JSONObject.NULL)
                .put("charging", plugged)
                .put("smsPermission", hasSmsPermission(context))
                .put("notificationAccess", NotifListener.hasAccess(context))
                .put("pending", p.pending)
                .put("lastError", p.lastError ?: JSONObject.NULL)
            val http = request(p.baseUrl, "heartbeat", "POST", body, key)
            p.lastHeartbeatAt = System.currentTimeMillis()
            if (http.code != 200) {
                p.lastHeartbeatOk = false
                p.lastError = describe(http)
                return
            }
            val data = JSONObject(http.body).getJSONObject("data")
            fun list(name: String) = data.optJSONArray(name)?.let { a -> (0 until a.length()).map { a.getString(it) } }
            list("senderHints")?.takeIf { it.isNotEmpty() }?.let { p.senderHints = it }
            list("instaPayKeywords")?.takeIf { it.isNotEmpty() }?.let { p.instaPayKeywords = it }
            list("notificationPackages")?.takeIf { it.isNotEmpty() }?.let { p.notificationPackages = it }
            p.lookbackHours = data.optInt("lookbackHours", p.lookbackHours)
            p.heartbeatSeconds = data.optInt("heartbeatSeconds", p.heartbeatSeconds)
            p.deviceName = data.optString("deviceName", p.deviceName)
            p.walletsJson = (data.optJSONArray("wallets") ?: JSONArray()).toString()
            p.lastHeartbeatOk = true
        } catch (e: Exception) {
            p.lastHeartbeatAt = System.currentTimeMillis()
            p.lastHeartbeatOk = false
            p.lastError = "مفيش اتصال بالسيرفر (${e.javaClass.simpleName})"
            Log.w(TAG, "heartbeat failed", e)
        }
    }

    // ---------------------------------------------------------------- inbox sweep

    fun hasSmsPermission(context: Context) =
        ContextCompat.checkSelfPermission(context, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED

    private fun isWalletSender(address: String?, hints: List<String>): Boolean {
        if (address.isNullOrBlank()) return false
        val s = address.lowercase().replace(Regex("[\\s\\-_.]"), "")
        // Personal numbers never carry wallet notifications.
        if (Regex("^\\+?\\d{6,}$").matches(s)) return false
        return hints.any { h -> if (h == "vf") s.startsWith("vf") else s.contains(h) }
    }

    private fun mentionsInstaPay(text: String?, keywords: List<String>) =
        !text.isNullOrBlank() && keywords.any { text.contains(it, ignoreCase = true) }

    private data class Sms(
        val clientId: String, val sender: String, val body: String, val date: Long,
        val source: String = "sms", val pkg: String? = null,
    )

    // ---------------------------------------------------------------- notifications

    /** Keeps a payment notification until the server acknowledges it. */
    @Synchronized
    fun enqueueNotification(context: Context, clientId: String, sender: String, body: String, at: Long, pkg: String) {
        val p = Prefs(context)
        val queue = JSONArray(p.notificationQueue)
        for (i in 0 until queue.length()) if (queue.getJSONObject(i).optString("clientId") == clientId) return
        if (clientId in p.acked) return
        queue.put(JSONObject().put("clientId", clientId).put("sender", sender).put("body", body).put("at", at).put("pkg", pkg))
        // Bounded: the oldest go first if the phone stays offline for very long.
        val trimmed = JSONArray()
        for (i in maxOf(0, queue.length() - 300) until queue.length()) trimmed.put(queue.get(i))
        p.notificationQueue = trimmed.toString()
    }

    private fun queuedNotifications(p: Prefs): List<Sms> {
        val queue = JSONArray(p.notificationQueue)
        return (0 until queue.length()).map { queue.getJSONObject(it) }.map {
            Sms(it.optString("clientId"), it.optString("sender"), it.optString("body"), it.optLong("at"),
                "notification", it.optString("pkg"))
        }
    }

    private fun dropFromQueue(p: Prefs, done: Set<String>, olderThan: Long) {
        val queue = JSONArray(p.notificationQueue)
        val keep = JSONArray()
        for (i in 0 until queue.length()) {
            val o = queue.getJSONObject(i)
            if (o.optString("clientId") !in done && o.optLong("at") >= olderThan) keep.put(o)
        }
        p.notificationQueue = keep.toString()
    }

    /**
     * Uploads every wallet / InstaPay SMS and queued payment notification the server
     * hasn't acknowledged. Returns how many were sent.
     */
    @Synchronized
    fun sweep(context: Context, timeoutMs: Int = 15000): Int {
        val p = Prefs(context)
        val key = p.deviceKey ?: return 0
        if (!p.enabled) return 0

        val since = System.currentTimeMillis() - p.lookbackHours * 3_600_000L
        val hints = p.senderHints
        val keywords = p.instaPayKeywords
        val acked = p.acked.toMutableSet()
        val fresh = mutableListOf<Sms>()
        var smsError: String? = null
        if (!hasSmsPermission(context)) {
            smsError = "صلاحية قراءة الرسايل مقفولة"
        } else try {
            context.contentResolver.query(
                Uri.parse("content://sms/inbox"),
                arrayOf("_id", "address", "body", "date"),
                "date >= ?", arrayOf(since.toString()), "date ASC"
            )?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getLong(0)
                    val address = c.getString(1)
                    val body = c.getString(2) ?: ""
                    val date = c.getLong(3)
                    val clientId = "sms-$id-$date"
                    if (clientId in acked) continue
                    // Wallet senders, plus bank SMS about InstaPay (never personal numbers).
                    val personal = address != null && Regex("^\\+?\\d{6,}$").matches(address.replace(" ", ""))
                    if (!isWalletSender(address, hints) && (personal || !mentionsInstaPay(body, keywords))) continue
                    fresh += Sms(clientId, address ?: "", body, date)
                }
            }
        } catch (e: SecurityException) {
            smsError = "صلاحية قراءة الرسايل مقفولة"
        }
        fresh += queuedNotifications(p).filter { it.clientId !in acked }

        var sent = 0
        var failure: String? = null
        for (chunk in fresh.chunked(BATCH)) {
            val messages = JSONArray()
            chunk.forEach {
                messages.put(JSONObject().put("clientId", it.clientId).put("sender", it.sender)
                    .put("body", it.body).put("receivedAtMs", it.date)
                    .put("source", it.source).put("package", it.pkg ?: JSONObject.NULL))
            }
            try {
                val http = request(p.baseUrl, "sms", "POST", JSONObject().put("messages", messages), key, timeoutMs)
                if (http.code != 200) { failure = describe(http); break }
                val results = JSONObject(http.body).getJSONArray("data")
                val bySender = chunk.associateBy { it.clientId }
                for (i in 0 until results.length()) {
                    val r = results.getJSONObject(i)
                    val clientId = r.optString("clientId")
                    val status = r.optString("status")
                    if (status == "stored" || status == "duplicate") acked += clientId
                    if (status == "stored") sent++
                    val sms = bySender[clientId] ?: continue
                    if (status == "stored") {
                        p.addLog(JSONObject()
                            .put("at", System.currentTimeMillis())
                            .put("receivedAt", sms.date)
                            .put("sender", sms.sender)
                            .put("preview", sms.body.take(140))
                            .put("kind", r.optString("kind"))
                            .put("match", r.optString("matchStatus")))
                    }
                }
            } catch (e: Exception) {
                failure = "مفيش اتصال بالسيرفر (${e.javaClass.simpleName})"
                Log.w(TAG, "upload failed", e)
                break
            }
        }

        // Forget acknowledgements older than the scan window (their messages won't be read again).
        val cutoff = since - 3_600_000L
        dropFromQueue(p, acked, cutoff)
        p.acked = acked.filterTo(HashSet()) { id -> id.substringAfterLast('-').toLongOrNull()?.let { it >= cutoff } ?: false }
        p.pending = fresh.count { it.clientId !in acked }
        p.sentTotal = p.sentTotal + sent
        p.lastSweepAt = System.currentTimeMillis()
        p.lastError = failure ?: smsError
        return sent
    }
}
