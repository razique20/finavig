package com.finavig.finavig

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.os.Handler
import android.os.Looper

/// Background service that receives device notifications.
/// Captures banking & transaction alerts from everywhere: banking apps, SMS apps,
/// messaging apps (WhatsApp, Telegram, etc.), digital wallets, and fintechs.
class FinavigNotificationListener : NotificationListenerService() {

    // Cache of recent notification hashes with timestamps to prevent duplicate events
    // when Android or messaging apps update/re-post notifications.
    private val recentHashes = object : LinkedHashMap<String, Long>(50, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Long>?): Boolean {
            return size > 60
        }
    }

    // Packages to explicitly ignore (system internals and Finavig itself)
    private val ignoredPackages = setOf(
        "com.android.systemui",
        "android",
        "com.android.vending",
        "com.google.android.gms",
    )

    // Known banking & fintech app packages — notifications from these are processed immediately.
    private val knownBankingPackages = listOf(
        // UAE Banks
        "com.adcb", "ae.adcb",
        "com.fab", "ae.fab",
        "com.enbd", "ae.emiratesnbd",
        "com.mashreq", "ae.mashreq",
        "com.dib", "ae.dib",
        "com.cbd", "ae.cbd",
        "com.rakbank", "ae.rakbank",
        "com.adib", "ae.adib",
        "com.hsbc", "com.sc.", "com.citi",
        "com.nbf", "com.almasraf", "com.ajmanbank", "com.uab",
        // Neobanks & Digital Wallets
        "com.wio", "com.pyypl", "ai.tabby", "com.tamara",
        "com.revolut", "com.transferwise", "com.paypal",
        "com.google.android.apps.wallet", "com.samsung.android.spay",
        // Saudi & GCC Banks
        "com.alrajhi", "com.snb", "com.riyad", "com.alinma",
        "sa.com.stcpay", "com.benefit",
    )

    // Currencies that indicate financial transactions
    private val currencyIndicators = listOf(
        "AED", "SAR", "KWD", "QAR", "BHD", "OMR",
        "USD", "EUR", "GBP", "DH", "DHS", "$", "€", "£",
    )

    // Banking & transaction action keywords
    private val transactionKeywords = listOf(
        "debited", "credited", "purchase", "payment",
        "paid", "spent", "withdrawn", "transferred", "transfer",
        "received", "salary", "refund", "reversal",
        "card ending", "ending in", "account **", "account ending",
        "avl bal", "avail bal", "available balance",
        "pos txn", "atm withdrawal", "bill payment",
    )

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        val notification = sbn.notification ?: return

        // Never intercept Finavig's own notifications
        if (packageName == applicationContext.packageName) return
        if (ignoredPackages.contains(packageName)) return

        // Extract notification text
        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""

        val body = if (bigText.isNotEmpty()) bigText else text
        if (body.isEmpty()) return

        val combined = "$title $body".lowercase()

        // Check if this notification is from a known banking app OR contains transaction signals
        val isKnownBank = knownBankingPackages.any { packageName.startsWith(it) }
        val hasTransactionSignal = hasTransactionKeywords(combined)

        // Only process if it is from a bank or carries clear transaction text
        if (!isKnownBank && !hasTransactionSignal) {
            return
        }

        // Quick native deduplication: avoid processing the exact same notification twice
        // within a 15-second window (e.g. notification updates or multi-channel delivery)
        val dedupeKey = "$packageName|$title|$body"
        val now = System.currentTimeMillis()
        synchronized(recentHashes) {
            val lastSeen = recentHashes[dedupeKey]
            if (lastSeen != null && (now - lastSeen) < 15000L) {
                return // Drop duplicate
            }
            recentHashes[dedupeKey] = now
        }

        // Forward to Flutter via MethodChannel on the main thread
        val data = HashMap<String, Any?>()
        data["packageName"] = packageName
        data["title"] = title
        data["text"] = body

        Handler(Looper.getMainLooper()).post {
            try {
                MainActivity.methodChannel?.invokeMethod("onNotificationReceived", data)
            } catch (e: Exception) {
                // Flutter engine may not be running — safe to ignore.
            }
        }
    }

    private fun hasTransactionKeywords(text: String): Boolean {
        // Must contain at least one currency indicator
        val hasCurrency = currencyIndicators.any { text.contains(it.lowercase()) }
        // Must contain at least one transaction action keyword
        val hasAction = transactionKeywords.any { text.contains(it.lowercase()) }
        return hasCurrency && hasAction
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // No action needed when notifications are dismissed.
    }
}
