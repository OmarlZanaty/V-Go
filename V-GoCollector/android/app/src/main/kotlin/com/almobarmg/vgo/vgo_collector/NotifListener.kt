package com.almobarmg.vgo.vgo_collector

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import java.security.MessageDigest

/**
 * Picks up InstaPay payment notifications (the InstaPay app, or a bank app whose push
 * mentions InstaPay) and queues them for the server. Chat / SMS apps are ignored: a
 * WhatsApp message saying "instapay" is not a payment, and SMS come from the inbox.
 */
class NotifListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            handle(sbn)
        } catch (e: Exception) {
            Log.w("VGoRelay", "notification skipped", e)
        }
    }

    private fun handle(sbn: StatusBarNotification) {
        val p = Prefs(this)
        if (!p.paired || !p.enabled) return
        val pkg = sbn.packageName ?: return
        if (pkg == packageName || pkg in IGNORED || IGNORED_PREFIXES.any { pkg.startsWith(it) }) return
        val n = sbn.notification ?: return
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

        val extras = n.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty().trim()
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty().trim()
        val body = listOf(title, text).filter { it.isNotBlank() }.joinToString("\n")
        if (body.isBlank()) return

        val wanted = pkg in p.notificationPackages ||
            p.instaPayKeywords.any { body.contains(it, ignoreCase = true) }
        if (!wanted) return

        // `when` is the app's own event time and survives re-posts of the same
        // notification, so an update never becomes a second payment.
        val at = n.`when`.takeIf { it > 0 } ?: sbn.postTime
        val clientId = "ntf-${sha1("$pkg|$title|$text|$at").take(20)}-$at"
        Relay.enqueueNotification(this, clientId, appLabel(this, pkg), body, at, pkg)

        Thread {
            try { Relay.sweep(applicationContext, timeoutMs = 10000) } catch (_: Exception) { }
        }.start()
    }

    companion object {
        private val IGNORED = setOf(
            "com.whatsapp", "com.whatsapp.w4b", "org.telegram.messenger", "com.facebook.orca",
            "com.facebook.katana", "com.instagram.android", "com.google.android.gm", "com.viber.voip",
            "com.google.android.apps.messaging", "com.android.mms", "com.samsung.android.messaging",
            "com.android.systemui",
        )
        private val IGNORED_PREFIXES = listOf("com.miui.", "com.android.")

        private fun sha1(s: String): String =
            MessageDigest.getInstance("SHA-1").digest(s.toByteArray()).joinToString("") { "%02x".format(it) }

        private fun appLabel(context: Context, pkg: String): String = try {
            val pm = context.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (_: Exception) { pkg }

        fun hasAccess(context: Context) =
            NotificationManagerCompat.getEnabledListenerPackages(context).contains(context.packageName)
    }
}
