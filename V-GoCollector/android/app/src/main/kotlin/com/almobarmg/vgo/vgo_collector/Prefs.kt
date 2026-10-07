package com.almobarmg.vgo.vgo_collector

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
        const val DEFAULT_URL = "https://vgo.almobarmg.com"
        val DEFAULT_HINTS = listOf("vfcash", "vodafone", "vf", "etisalat", "e&", "eand", "emoney", "etisalatcash")
    }
}
