package com.kinyuanexus.fuata.fuata

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fires when the scheduled export alarm goes off (issue #35).
 *
 * Fire-and-forget by design: this receiver starts the background isolate
 * and returns, so Android doesn't consider it long-running. The isolate
 * reports its own result; the receiver does not re-arm — the alarm set
 * with `setInexactRepeating` keeps repeating on its own interval, and the
 * boot receiver re-arms after a reboot.
 */
class ScheduledExportReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION) return
        ScheduledExportEngine.startBackgroundExport(context.applicationContext)
    }

    companion object {
        const val ACTION = "com.kinyuanexus.fuata.SCHEDULED_EXPORT_FIRE"
    }
}