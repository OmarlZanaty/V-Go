package com.almobarmg.vgo.collector

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Everything the relay keeps between runs. Shared by the UI, the service and the workers. */
class Prefs(context: Context) {
    private val sp = context.applicationContext.getSharedPreferences("collector", Context.MODE_PRIVATE)

    var baseUrl: String
        get() = sp.getString("baseUrl", DEFAULT_URL) ?: DEFAULT_URL
        set(v) = sp.edit().putString("baseUrl", v.trim().trimEnd('/')).apply()

    var deviceKey: String?
        get() = sp.getString("deviceKey", null)
        set(v) = sp.edit().putString("deviceKey", v).apply()

    var deviceName: String
        get() = sp.getString("deviceName", "") ?: ""
        set(v) = sp.edit().putString("deviceName", v).apply()

    val paired: Boolean get() = !deviceKey.isNullOrBlank()

    var enabled: Boolean
        get() = sp.getBoolean("enabled", true)
        set(v) = sp.edit().putBoolean("enabled", v).apply()

    var senderHints: List<String>
        get() = sp.getString("senderHints", null)?.split('|')?.filter { it.isNotBlank() } ?: DEFAULT_HINTS
        set(v) = sp.edit().putString("senderHints", v.joinToString("|")).apply()

    var otpEnabled: Boolean
        get() = sp.getBoolean("otpEnabled", true)
        set(v) = sp.edit().putBoolean("otpEnabled", v).apply()

    var otpSubscriptionId: Int
        get() = sp.getInt("otpSubscriptionId", -1)
        set(v) = sp.edit().putInt("otpSubscriptionId", v).apply()

    var otpSentTotal: Int
        get() = sp.getInt("otpSentTotal", 0)
        set(v) = sp.edit().putInt("otpSentTotal", v).apply()

    val otpDeliveredTotal: Int get() = sp.getInt("otpDeliveredTotal", 0)

    // Receiver and worker share this lock; commits keep progress and results atomic.
    fun beginDelivery(id: String, attempt: String, count: Int, device: String, server: String) = synchronized(deliveryLock) {
        val progress = JSONObject(sp.getString("otpDeliveryProgress", "{}") ?: "{}")
        progress.put(id, JSONObject().put("attempt", attempt).put("count", count)
            .put("device", device).put("server", server).put("parts", JSONObject()))
        sp.edit().putString("otpDeliveryProgress", progress.toString()).commit()
    }

    fun recordDelivery(id: String, attempt: String, part: Int, count: Int, status: Int) = synchronized(deliveryLock) {
        val progress = JSONObject(sp.getString("otpDeliveryProgress", "{}") ?: "{}")
        val entry = progress.optJSONObject(id) ?: return@synchronized
        if (entry.optString("attempt") != attempt || entry.optInt("count") != count || part !in 0 until count) return@synchronized
        if (entry.optString("device") != deviceKey?.substringBefore('.') || entry.optString("server") != baseUrl) return@synchronized
        if (entry.optString("result") in listOf("delivered", "failed")) return@synchronized
        val parts = entry.getJSONObject("parts")
        val previous = parts.optInt(part.toString(), -1)
        if (previous == 0 || previous >= 64) return@synchronized
        parts.put(part.toString(), status)
        val delivered = (0 until count).all { parts.optInt(it.toString(), -1) == 0 }
        val failed = (0 until count).map { parts.optInt(it.toString(), -1) }.firstOrNull { it >= 64 }
        val result = when {
            failed != null -> "failed"
            delivered -> "delivered"
            status in 32..63 && parts.length() == 1 -> "pending"
            else -> null
        }
        val editor = sp.edit()
        if (result != null && entry.optString("result") != result) {
            entry.put("result", result)
            val queue = JSONArray(sp.getString("otpDeliveryResults", "[]") ?: "[]")
            queue.put(JSONObject().put("token", java.util.UUID.randomUUID().toString())
                .put("id", id).put("device", entry.getString("device")).put("server", entry.getString("server"))
                .put("delivered", delivered).put("status", if (failed != null) "DELIVERY_FAILED_$failed" else result))
            editor.putString("otpDeliveryResults", queue.toString())
            if (delivered) editor.putInt("otpDeliveredTotal", otpDeliveredTotal + 1)
        }
        editor.putString("otpDeliveryProgress", progress.toString()).commit()
    }

    fun deliveryResults(): JSONArray = synchronized(deliveryLock) {
        JSONArray(sp.getString("otpDeliveryResults", "[]") ?: "[]")
    }

    fun removeDeliveryResult(token: String) = synchronized(deliveryLock) {
        val queue = deliveryResults()
        val remaining = JSONArray()
        for (i in 0 until queue.length()) {
            val item = queue.getJSONObject(i)
            if (item.getString("token") != token) remaining.put(item)
        }
        sp.edit().putString("otpDeliveryResults", remaining.toString()).commit()
    }

    var otpLastError: String?
        get() = sp.getString("otpLastError", null)
        set(v) = sp.edit().putString("otpLastError", v).apply()

    // Only result metadata is retained; OTP bodies and codes are never stored here.
    var otpPendingResults: String
        get() = sp.getString("otpPendingResults", "[]") ?: "[]"
        set(v) = sp.edit().putString("otpPendingResults", v).commit().let { }

    /** SMS / notifications containing one of these are forwarded whatever the sender. */
    var instaPayKeywords: List<String>
        get() = sp.getString("instaPayKeywords", null)?.split('|')?.filter { it.isNotBlank() } ?: DEFAULT_INSTAPAY
        set(v) = sp.edit().putString("instaPayKeywords", v.joinToString("|")).apply()

    /** Apps whose notifications are forwarded (the InstaPay app). */
    var notificationPackages: List<String>
        get() = sp.getString("notificationPackages", null)?.split('|')?.filter { it.isNotBlank() } ?: DEFAULT_PACKAGES
        set(v) = sp.edit().putString("notificationPackages", v.joinToString("|")).apply()

    /**
     * Notifications waiting for the server (unlike SMS there is no inbox to re-read, so
     * they're kept here until acknowledged). JSON array of {clientId, sender, body, at, pkg}.
     */
    var notificationQueue: String
        get() = sp.getString("notificationQueue", "[]") ?: "[]"
        set(v) = sp.edit().putString("notificationQueue", v).commit().let { }

    var lookbackHours: Int
        get() = sp.getInt("lookbackHours", 48)
        set(v) = sp.edit().putInt("lookbackHours", v.coerceIn(1, 24 * 14)).apply()

    var heartbeatSeconds: Int
        get() = sp.getInt("heartbeatSeconds", 60)
        set(v) = sp.edit().putInt("heartbeatSeconds", v.coerceIn(20, 3600)).apply()

    var walletsJson: String
        get() = sp.getString("wallets", "[]") ?: "[]"
        set(v) = sp.edit().putString("wallets", v).apply()

    var lastSweepAt: Long
        get() = sp.getLong("lastSweepAt", 0)
        set(v) = sp.edit().putLong("lastSweepAt", v).apply()

    var lastHeartbeatAt: Long
        get() = sp.getLong("lastHeartbeatAt", 0)
        set(v) = sp.edit().putLong("lastHeartbeatAt", v).apply()

    var lastHeartbeatOk: Boolean
        get() = sp.getBoolean("lastHeartbeatOk", false)
        set(v) = sp.edit().putBoolean("lastHeartbeatOk", v).apply()

    var lastError: String?
        get() = sp.getString("lastError", null)
        set(v) = sp.edit().putString("lastError", v).apply()

    var pending: Int
        get() = sp.getInt("pending", 0)
        set(v) = sp.edit().putInt("pending", v).apply()

    var sentTotal: Int
        get() = sp.getInt("sentTotal", 0)
        set(v) = sp.edit().putInt("sentTotal", v).apply()

    /** Upload ids the server already has (stored or duplicate). */
    var acked: Set<String>
        get() = sp.getStringSet("acked", emptySet()) ?: emptySet()
        set(v) = sp.edit().putStringSet("acked", HashSet(v)).apply()

    /** Last relayed messages for the status screen (newest first, max 40). */
    fun addLog(entry: JSONObject) {
        val old = JSONArray(sp.getString("log", "[]"))
        val next = JSONArray().put(entry)
        for (i in 0 until minOf(old.length(), 39)) next.put(old.get(i))
        sp.edit().putString("log", next.toString()).apply()
    }

    val logJson: String get() = sp.getString("log", "[]") ?: "[]"

    fun unpair() {
        sp.edit()
            .remove("deviceKey").remove("deviceName").remove("wallets")
            .remove("lastHeartbeatAt").remove("lastHeartbeatOk").remove("lastError")
            .apply()
    }

    companion object {
        private val deliveryLock = Any()
        const val DEFAULT_URL = "https://vgo.almobarmg.com"
        val DEFAULT_HINTS = listOf("vfcash", "vodafone", "vf", "etisalat", "e&", "eand", "emoney", "etmoney", "etisalatcash", "instapay")
        val DEFAULT_INSTAPAY = listOf("instapay", "insta pay", "انستاباي", "إنستاباي", "انستا باي", "إنستا باي")
        val DEFAULT_PACKAGES = listOf("com.egyptianbanks.instapay")
    }
}
