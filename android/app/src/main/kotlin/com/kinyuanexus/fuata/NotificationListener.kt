package com.kinyuanexus.fuata

import android.util.Log
import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Issue #22 — the real listener; replaces the #18 spike.
 *
 * The privacy gate is the first thing that happens: a notification from
 * any app that is not on the person's allow-list is dropped right here —
 * no text is read, no engine is started, nothing is stored (US-10,
 * requirements.md Privacy row). Only allow-listed notifications continue,
 * and even then their text goes straight to the capture pipeline in
 * memory; only what the parser extracts, or an unreadable message the
 * person can teach Fuata to read, is ever written.
 *
 * design.md 5.1: on some phones (confirmed on MIUI) this service is only
 * bound after the notification-access switch is toggled off and on in
 * Android's own settings screen. The Auto-catch screen says so.
 */
class NotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        Log.d("fuata_capture", "onNotificationPosted pkg=${sbn.packageName}")
        val packageName = sbn.packageName ?: return

        // Never read our own notifications (the banner, #16).
        if (packageName == applicationContext.packageName) return

        // The gate. Everything below only runs for allowed apps.
        if (!CaptureStore.isAllowed(applicationContext, packageName)) return

        val notification = sbn.notification ?: return

        // A group summary is a container for children the app posts as
        // separate notifications (Android's bundling contract); reading it
        // would just produce unreadable "3 new messages" entries.
        if ((notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return

        val text = NotificationText.extract(notification) ?: return

        CaptureEngine.submit(applicationContext, packageName, text)
    }
}
