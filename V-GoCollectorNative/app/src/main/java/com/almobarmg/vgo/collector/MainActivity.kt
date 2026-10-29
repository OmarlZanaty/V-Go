package com.almobarmg.vgo.collector

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.telephony.SubscriptionManager
import android.text.InputFilter
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import android.widget.Switch
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

/**
 * Native (dependency-free) rebuild of the Flutter collector screen. One scrolling
 * column, built in code the same way VIP Relay's is, because Play Protect blocked
 * the Flutter build on the company phones. The relay logic (Relay / RelayService /
 * NotifListener / Receivers / Prefs) is unchanged from the Flutter app.
 */
class MainActivity : Activity() {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private lateinit var root: LinearLayout
    private var pairingScreenShown = false
    private val tick = object : Runnable {
        override fun run() {
            if (Prefs(this@MainActivity).paired) render()
            main.postDelayed(this, 5000)
        }
    }

    // Palette (matches the old Flutter theme).
    private val yellow = Color.parseColor("#DCE01E")
    private val black = Color.parseColor("#030407")
    private val card = Color.parseColor("#252525")
    private val grey = Color.parseColor("#9E9E9E")
    private val green = Color.parseColor("#2ECC71")
    private val red = Color.parseColor("#E74C3C")
    private val orange = Color.parseColor("#FE7600")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val scroll = ScrollView(this).apply {
            setBackgroundColor(black)
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            fitsSystemWindows = true
        }
        root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(20), dp(16), dp(24))
        }
        scroll.addView(root)
        setContentView(scroll)
        if (Prefs(this).paired && Prefs(this).enabled) RelayService.start(this)
    }

    override fun onResume() {
        super.onResume()
        if (Prefs(this).paired || !pairingScreenShown) render()
        main.postDelayed(tick, 5000)
    }

    override fun onPause() {
        main.removeCallbacks(tick)
        super.onPause()
    }

    // ------------------------------------------------------------------ render

    private fun render() {
        val p = Prefs(this)
        pairingScreenShown = !p.paired
        root.removeAllViews()
        if (p.paired) renderStatus(p) else renderPair(p)
    }

    private fun renderPair(p: Prefs) {
        header("ربط موبايل التحصيل")
        root.addView(text("من لوحة التحكم ← التحصيل اليومي ← المحافظ وموبايل التحصيل ← إضافة موبايل، هيظهر كود. اكتبه هنا.", grey))

        val url = edit(p.baseUrl, "عنوان السيرفر", InputType.TYPE_TEXT_VARIATION_URI)
        val code = edit("", "كود الربط", InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS).apply {
            filters = arrayOf(InputFilter.AllCaps())
            gravity = Gravity.CENTER; textSize = 22f
        }
        root.addView(label("عنوان السيرفر")); root.addView(url)
        root.addView(label("كود الربط")); root.addView(code)

        val err = text("", red)
        root.addView(err)
        val btn = primaryButton("ربط")
        root.addView(btn)
        btn.setOnClickListener {
            var u = url.text.toString().trim()
            if (!u.startsWith("http")) u = "https://$u"
            val c = code.text.toString().trim()
            if (c.length < 6) { err.text = "اكتب كود الربط اللي ظاهر في لوحة التحكم"; return@setOnClickListener }
            btn.isEnabled = false; btn.text = "بيربط…"; err.text = ""
            background({
                Relay.pair(this, u, c, RelayService.appVersion(this)).also { e ->
                    if (e == null) {
                        Relay.heartbeat(this, RelayService.appVersion(this))
                        main.post { RelayService.start(this) }
                    }
                }
            }) { e ->
                btn.isEnabled = true; btn.text = "ربط"
                if (e == null) render() else err.text = e
            }
        }
    }

    @SuppressLint("SetTextI18n")
    private fun renderStatus(p: Prefs) {
        val sms = Relay.hasSmsPermission(this)
        val notif = NotifListener.hasAccess(this)
        val battery = getSystemService(PowerManager::class.java)?.isIgnoringBatteryOptimizations(packageName) == true
        val hbAgoMs = System.currentTimeMillis() - p.lastHeartbeatAt
        val healthy = p.lastHeartbeatOk && p.lastHeartbeatAt > 0 && hbAgoMs < 180_000

        val color = when {
            !p.enabled -> grey
            !sms -> red
            healthy && p.lastError == null -> green
            healthy -> orange
            else -> red
        }
        val headline = when {
            !p.enabled -> "متوقف"
            !sms -> "محتاج صلاحية الرسايل"
            healthy -> if (p.lastError == null) "شغال ومتصل" else "متصل بس فيه مشكلة"
            else -> "مش متصل بالسيرفر"
        }

        // Status card
        val c = cardBox(color)
        c.addView(TextView(this).apply {
            text = "● $headline"; setTextColor(color); textSize = 18f
            setTypeface(typeface, Typeface.BOLD)
        })
        kv(c, "الموبايل", p.deviceName.ifEmpty { "—" })
        kv(c, "السيرفر", p.baseUrl)
        kv(c, "آخر اتصال بالسيرفر", ago(p.lastHeartbeatAt))
        kv(c, "آخر قراءة للرسايل", ago(p.lastSweepAt))
        kv(c, "رسايل اتبعتت", p.sentTotal.toString())
        if (p.pending > 0) kv(c, "مستنية الإرسال", p.pending.toString(), orange)
        p.lastError?.let { c.addView(text(it, red)) }
        val toggle = Button(this).apply {
            text = if (p.enabled) "إيقاف" else "تشغيل"
            setOnClickListener {
                p.enabled = !p.enabled
                if (p.enabled) RelayService.start(this@MainActivity) else RelayService.stop(this@MainActivity)
                render()
            }
        }
        c.addView(toggle)
        val sync = Button(this).apply {
            text = "ابعت دلوقتي"
            setOnClickListener {
                isEnabled = false; text = "بيبعت…"
                background({ val s = Relay.sweep(this@MainActivity); Relay.heartbeat(this@MainActivity, RelayService.appVersion(this@MainActivity)); s }) { sent ->
                    isEnabled = true; text = "ابعت دلوقتي"
                    toast("اتبعت $sent رسالة جديدة"); render()
                }
            }
        }
        c.addView(sync)
        root.addView(c)

        val otpCard = cardBox(null)
        otpCard.addView(Switch(this).apply {
            text = "إرسال أكواد التحقق (OTP)"
            setTextColor(Color.WHITE)
            isChecked = p.otpEnabled
            setOnCheckedChangeListener { _, checked ->
                p.otpEnabled = checked
                if (checked && !OtpSender.hasPermission(this@MainActivity)) askSms()
                if (p.enabled) RelayService.start(this@MainActivity)
            }
        })
        otpCard.addView(Button(this).apply {
            text = "شريحة أكواد التحقق: ${otpSimLabel(p.otpSubscriptionId)}"
            setOnClickListener { pickOtpSim() }
        })
        kv(otpCard, "أكواد اتبعتت", p.otpSentTotal.toString())
        p.otpLastError?.let { otpCard.addView(text("مشكلة إرسال الأكواد: $it", red)) }
        root.addView(otpCard)

        // Wallets
        val wallets = JSONArray(p.walletsJson)
        val wc = cardBox(if (wallets.length() == 0) orange else null)
        if (wallets.length() == 0) {
            wc.addView(text("مفيش محافظ متربوطة بالموبايل ده. من لوحة التحكم عدّل المحفظة واختار الموبايل ده.", null))
        } else {
            wc.addView(boldText("المحافظ على الموبايل ده"))
            for (i in 0 until wallets.length()) {
                val w = wallets.getJSONObject(i)
                val prov = when (w.optString("provider")) {
                    "VodafoneCash" -> "فودافون كاش"; "EtisalatCash" -> "اتصالات كاش"; else -> "انستاباي"
                }
                wc.addView(text("$prov  ${w.optString("phoneNumber")}", null))
            }
        }
        root.addView(wc)

        // Checklist
        val cl = cardBox(null)
        cl.addView(boldText("علشان يفضل شغال 24 ساعة"))
        step(cl, sms, "صلاحية قراءة الرسايل", if (sms) null else "اسمح" to { askSms() })
        val sendSms = OtpSender.hasPermission(this)
        val phoneState = checkSelfPermission(Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
        step(cl, sendSms, "صلاحية إرسال أكواد التحقق", if (sendSms) null else "اسمح" to { askSms() })
        step(cl, phoneState, "صلاحية اختيار الشريحة", if (phoneState) null else "اسمح" to { askSms() })
        if (!sms) cl.addView(text("لو الزرار مقفول أو ظهر \"Restricted setting\": الإعدادات ← التطبيقات ← V-Go Collector ← ⋮ ← Allow restricted settings، وبعدين اضغط \"اسمح\" تاني.", orange))
        step(cl, notif, "قراءة إشعارات انستاباي", if (notif) null else "افتح" to { open(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS) })
        step(cl, battery, "إيقاف توفير البطارية للتطبيق", if (battery) null else "افتح" to { requestBattery() })
        if (isAggressive()) step(cl, null, "التشغيل التلقائي (Autostart)", "افتح" to { openAutostart() })
        cl.addView(text("خلي الموبايل على الشاحن ومتصل بالنت دايماً، وما تقفلش التطبيق من قايمة التطبيقات المفتوحة.", grey))
        root.addView(cl)

        // Log
        root.addView(boldText("آخر الرسايل اللي اتبعتت"))
        val log = JSONArray(p.logJson)
        if (log.length() == 0) root.addView(text("لسه مفيش.", grey))
        for (i in 0 until log.length()) {
            val e = log.getJSONObject(i)
            val (lbl, lc) = when (e.optString("match")) {
                "Matched" -> "اتطابق مع كابتن ✅" to green
                "Unclaimed" -> "مستني طلب الكابتن" to orange
                "NeedsReview" -> "محتاج مراجعة" to orange
                "NotApplicable" -> "مش تحويل وارد" to grey
                else -> e.optString("match") to grey
            }
            val lb = cardBox(null)
            lb.addView(TextView(this).apply { text = "${e.optString("sender")}   $lbl"; setTextColor(lc); textSize = 13f })
            lb.addView(text(e.optString("preview"), grey))
            if (e.optLong("receivedAt") > 0) lb.addView(text(time(Date(e.optLong("receivedAt"))), grey))
            root.addView(lb)
        }

        val unpair = TextView(this).apply {
            text = "فك ربط الموبايل"; setTextColor(red); gravity = Gravity.CENTER
            setPadding(0, dp(20), 0, dp(8)); setOnClickListener { confirmUnpair() }
        }
        root.addView(unpair)
        root.addView(TextView(this).apply {
            text = "نسخة ${RelayService.appVersion(this@MainActivity)}"; setTextColor(grey)
            textSize = 12f; gravity = Gravity.CENTER
        })
    }

    // ------------------------------------------------------------------ actions

    private val smsReq = 101
    private fun askSms() {
        val permissions = mutableListOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS,
            Manifest.permission.SEND_SMS, Manifest.permission.READ_PHONE_STATE)
        if (Build.VERSION.SDK_INT >= 33) permissions += Manifest.permission.POST_NOTIFICATIONS
        requestPermissions(permissions.toTypedArray(), smsReq)
    }

    @SuppressLint("MissingPermission")
    private fun otpSims(): List<Pair<Int, String>> {
        val choices = mutableListOf(-1 to "الشريحة الافتراضية")
        if (checkSelfPermission(Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED) {
            try {
                getSystemService(SubscriptionManager::class.java)?.activeSubscriptionInfoList
                    ?.sortedBy { it.simSlotIndex }?.forEach {
                        choices += it.subscriptionId to "${it.displayName} — الشريحة ${it.simSlotIndex + 1}"
                    }
            } catch (_: SecurityException) { }
        }
        return choices
    }

    private fun otpSimLabel(id: Int): String =
        otpSims().firstOrNull { it.first == id }?.second ?: "الشريحة المختارة غير متاحة"

    private fun pickOtpSim() {
        if (checkSelfPermission(Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
            askSms()
            return
        }
        val choices = otpSims()
        val p = Prefs(this)
        android.app.AlertDialog.Builder(this)
            .setTitle("شريحة إرسال أكواد التحقق")
            .setSingleChoiceItems(choices.map { it.second }.toTypedArray(),
                choices.indexOfFirst { it.first == p.otpSubscriptionId }) { dialog, index ->
                p.otpSubscriptionId = choices[index].first
                dialog.dismiss()
                render()
            }
            .setNegativeButton("إلغاء", null)
            .show()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        RelayService.start(this); render()
    }

    @SuppressLint("BatteryLife")
    private fun requestBattery() = try {
        startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
    } catch (_: Exception) {
        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
    }

    private fun open(action: String) = try { startActivity(Intent(action)) } catch (_: Exception) { }

    private fun isAggressive(): Boolean {
        val m = Build.MANUFACTURER.lowercase()
        return listOf("xiaomi", "redmi", "poco", "oppo", "realme", "vivo", "huawei", "honor", "oneplus", "infinix", "tecno").any { m.contains(it) }
    }

    private fun openAutostart() {
        val candidates = listOf(
            ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
            ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
            ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
        )
        for (c in candidates) {
            try { startActivity(Intent().setComponent(c).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); return } catch (_: Exception) { }
        }
        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
    }

    private fun confirmUnpair() {
        android.app.AlertDialog.Builder(this)
            .setTitle("فك الربط؟")
            .setMessage("الموبايل هيبطل يبعت رسايل الاستلام لحد ما تربطه تاني بكود جديد.")
            .setNegativeButton("لا", null)
            .setPositiveButton("فك الربط") { _, _ ->
                RelayService.stop(this); Prefs(this).unpair(); render()
            }.show()
    }

    private fun <T> background(work: () -> T, done: (T) -> Unit) {
        io.execute {
            val v = try { work() } catch (e: Exception) {
                @Suppress("UNCHECKED_CAST") (e.message ?: e.javaClass.simpleName) as T
            }
            main.post { done(v) }
        }
    }

    // ------------------------------------------------------------------ view helpers

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
    private fun toast(s: String) = Toast.makeText(this, s, Toast.LENGTH_SHORT).show()

    private fun header(s: String) = root.addView(TextView(this).apply {
        text = s; setTextColor(yellow); textSize = 22f; setTypeface(typeface, Typeface.BOLD)
        gravity = Gravity.CENTER; setPadding(0, 0, 0, dp(8))
    })

    private fun text(s: String, color: Int?) = TextView(this).apply {
        text = s; setTextColor(color ?: Color.WHITE); textSize = 14f
        setPadding(0, dp(2), 0, dp(2))
    }

    private fun boldText(s: String) = TextView(this).apply {
        text = s; setTextColor(Color.WHITE); setTypeface(typeface, Typeface.BOLD)
        setPadding(0, dp(6), 0, dp(4))
    }

    private fun label(s: String) = TextView(this).apply {
        text = s; setTextColor(grey); setPadding(0, dp(8), 0, dp(4))
    }

    private fun edit(value: String, hintText: String, type: Int) = EditText(this).apply {
        setText(value); hint = hintText; inputType = type
        setTextColor(Color.WHITE); setHintTextColor(grey)
        background = GradientDrawable().apply { cornerRadius = dp(12).toFloat(); setColor(card) }
        setPadding(dp(14), dp(12), dp(14), dp(12))
        layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)
    }

    private fun primaryButton(s: String) = Button(this).apply {
        text = s; setTextColor(black); setTypeface(typeface, Typeface.BOLD)
        background = GradientDrawable().apply { cornerRadius = dp(12).toFloat(); setColor(yellow) }
        layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { topMargin = dp(16) }
    }

    private fun cardBox(border: Int?) = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(dp(14), dp(14), dp(14), dp(14))
        background = GradientDrawable().apply {
            cornerRadius = dp(14).toFloat(); setColor(card)
            if (border != null) setStroke(dp(1), border)
        }
        layoutParams = LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { topMargin = dp(12) }
    }

    private fun kv(parent: LinearLayout, k: String, v: String, vColor: Int? = null) {
        parent.addView(LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL; setPadding(0, dp(2), 0, dp(2))
            addView(TextView(this@MainActivity).apply { text = "$k: "; setTextColor(grey); textSize = 13f })
            addView(TextView(this@MainActivity).apply { text = v; setTextColor(vColor ?: Color.WHITE); textSize = 13f })
        })
    }

    private fun step(parent: LinearLayout, done: Boolean?, title: String, action: Pair<String, () -> Unit>?) {
        parent.addView(LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(4), 0, dp(4))
            val mark = when (done) { true -> "✓" to green; false -> "✗" to red; null -> "•" to orange }
            addView(TextView(this@MainActivity).apply { text = mark.first; setTextColor(mark.second); textSize = 18f; setPadding(0, 0, dp(10), 0) })
            addView(TextView(this@MainActivity).apply {
                text = title; setTextColor(Color.WHITE); textSize = 14f
                layoutParams = LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f)
            })
            if (action != null) addView(Button(this@MainActivity).apply { text = action.first; setOnClickListener { action.second() } })
        })
    }

    private fun two(v: Int) = v.toString().padLeft(2)
    private fun time(t: Date): String {
        val f = SimpleDateFormat("dd/MM HH:mm", Locale.US); return f.format(t)
    }
    private fun ago(ms: Long): String {
        if (ms <= 0) return "لسه"
        val d = System.currentTimeMillis() - ms
        return when {
            d < 60_000 -> "من ${d / 1000} ثانية"
            d < 3_600_000 -> "من ${d / 60_000} دقيقة"
            else -> time(Date(ms))
        }
    }
    private fun String.padLeft(n: Int) = padStart(n, '0')
}
