package com.kinyuanexus.fuata

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-arms the scheduled export after a reboot or an app update
 * (issue #35). `setInexactRepeating` alarms are not durable across a
 * reboot; the engine re-arms from its own saved trigger/interval so the
 * first export after a reboot is due at the next occurrence.
 */
class ScheduledExportBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                ScheduledExportEngine.rearmFromPrefs(context.applicationContext)
            }
        }
    }
}