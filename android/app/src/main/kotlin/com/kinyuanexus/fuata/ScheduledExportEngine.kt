package com.kinyuanexus.fuata

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.view.FlutterCallbackInformation

/**
 * The scheduled export's alarm and background engine (issue #35).
 *
 * `setInexactRepeating` on RTC (not RTC_WAKEUP): a backup is not urgent
 * enough to wake the phone, and Android will fire the delayed alarm once
 * the phone is awake. No SCHEDULE_EXACT_ALARM permission, so the person
 * can never revoke a permission the feature depends on.
 *
 * The trigger time and interval are computed in Dart by
 * `nextScheduledExportTrigger` (tested in test/domain/scheduled_export_test.dart)
 * and handed to `schedule`. The boot receiver re-arms from prefs; DST
 * drift of up to an hour twice a year is accepted for a daily backup.
 */
object ScheduledExportEngine {
    private const val TAG = "fuata_scheduled_export"
    private const val PREFS = "fuata_scheduled_export"
    private const val KEY_TRIGGER = "trigger_at_ms"
    private const val KEY_INTERVAL = "interval_ms"
    private const val KEY_CALLBACK_HANDLE = "callback_handle"
    private const val KEY_LAST_RUN = "last_run_at"
    private const val KEY_LAST_SUCCESS = "last_run_success"
    private const val KEY_LAST_ERROR = "last_run_error"
    private const val REQ_ALARM = 41210

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun writeCallbackHandle(context: Context, handle: Long) {
        prefs(context).edit().putLong(KEY_CALLBACK_HANDLE, handle).apply()
    }

    private fun readCallbackHandle(context: Context): Long? {
        val v = prefs(context).getLong(KEY_CALLBACK_HANDLE, 0L)
        return if (v == 0L) null else v
    }

    fun schedule(context: Context, triggerAtMillis: Long, intervalMillis: Long) {
        prefs(context).edit()
            .putLong(KEY_TRIGGER, triggerAtMillis)
            .putLong(KEY_INTERVAL, intervalMillis)
            .apply()
        arm(context, triggerAtMillis, intervalMillis)
    }

    fun cancel(context: Context) {
        prefs(context).edit()
            .remove(KEY_TRIGGER)
            .remove(KEY_INTERVAL)
            .apply()
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(alarmIntent(context))
    }

    /** Called by the boot receiver: re-arms from whatever was saved. */
    fun rearmFromPrefs(context: Context) {
        val p = prefs(context)
        val trigger = p.getLong(KEY_TRIGGER, 0L)
        val interval = p.getLong(KEY_INTERVAL, 0L)
        if (trigger == 0L || interval == 0L) return
        // If the saved trigger is in the past, roll forward by whole
        // intervals. A reboot that lost an hour of DST still fires.
        val now = System.currentTimeMillis()
        var next = trigger
        while (next <= now) next += interval
        arm(context, next, interval)
    }

    private fun arm(context: Context, triggerAtMillis: Long, intervalMillis: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = alarmIntent(context)
        am.cancel(pi)
        am.setInexactRepeating(
            AlarmManager.RTC,
            triggerAtMillis,
            intervalMillis,
            pi,
        )
    }

    private fun alarmIntent(context: Context): PendingIntent {
        val intent = Intent(context, ScheduledExportReceiver::class.java).apply {
            action = ScheduledExportReceiver.ACTION
        }
        return PendingIntent.getBroadcast(
            context, REQ_ALARM, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun recordRun(context: Context, success: Boolean, error: String?) {
        prefs(context).edit()
            .putLong(KEY_LAST_RUN, System.currentTimeMillis())
            .putBoolean(KEY_LAST_SUCCESS, success)
            .putString(KEY_LAST_ERROR, error)
            .apply()
    }

    fun lastRun(context: Context): Map<String, Any?> {
        val p = prefs(context)
        val at = p.getLong(KEY_LAST_RUN, 0L).takeIf { it > 0 }
        return mapOf(
            "at" to at,
            "success" to p.getBoolean(KEY_LAST_SUCCESS, false),
            "error" to p.getString(KEY_LAST_ERROR, null),
        )
    }

    /**
     * Called by ScheduledExportReceiver on the alarm. Starts a short-lived
     * Flutter engine running `scheduledExportDispatcher`; that isolate
     * reports back over `fuata/scheduled_export_bg`, which records the
     * result and asks us to tear the engine down.
     */
    fun startBackgroundExport(context: Context) {
        val handle = readCallbackHandle(context) ?: run {
            Log.w(TAG, "no callback handle; scheduled export skipped")
            recordRun(context, false, "Fuata has not been opened since install")
            return
        }
        val app = context.applicationContext
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(app)
        loader.ensureInitializationCompleteAsync(app, null, Handler(Looper.getMainLooper())) {
            val info = FlutterCallbackInformation.lookupCallbackInformation(handle)
            if (info == null) {
                // Stale handle (app updated, not reopened).
                recordRun(app, false, "app was updated; open Fuata once")
                return@ensureInitializationCompleteAsync
            }
            val engine = FlutterEngine(app)
            var disposed = false
            fun disposeOnce() {
                if (disposed) return
                disposed = true
                Handler(Looper.getMainLooper()).postDelayed(
                    { engine.destroy() }, 2000,
                )
            }
            val bg = ScheduledExportBackgroundChannel(
                app, engine.dartExecutor.binaryMessenger, ::disposeOnce,
            )
            engine.dartExecutor.executeDartCallback(
                DartExecutor.DartCallback(
                    app.assets,
                    loader.findAppBundlePath(),
                    info,
                ),
            )
            // A dispatcher that never reports back would leak the engine;
            // a 2-minute watchdog is more than enough for a backup write.
            Handler(Looper.getMainLooper()).postDelayed({
                if (!disposed) {
                    bg.dispose()
                    engine.destroy()
                    disposed = true
                    Log.w(TAG, "background export timed out")
                }
            }, 120_000)
        }
    }
}