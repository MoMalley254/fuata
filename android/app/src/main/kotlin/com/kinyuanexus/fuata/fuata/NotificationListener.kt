package com.kinyuanexus.fuata.fuata

import android.app.Notification
import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation

/**
 * Issue #18 — SPIKE, throwaway, time-boxed to 2 hours.
 *
 * On *every* notification (no allow-list yet — that's #22), spins up a
 * headless FlutterEngine, runs the Dart entry point registered by
 * MainActivity, and asks it to write one row to fuata.sqlite. This proves
 * (or disproves) that a background isolate can safely touch the same
 * database file the UI isolate might have open at the same moment.
 *
 * Findings go in docs/design.md section 5, not here. This class is
 * replaced by the real listener in #22.
 */
class NotificationListener: NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val handle = readCallbackHandle(applicationContext)
        if (handle == null) {
            Log.w(TAG, "No callback handle registered — open the app once first.")
            return
        }

        val packageName = sbn.packageName
        val extras = sbn.notification.extras
        val text = extras?.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            ?: extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: ""

        val loader = FlutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationCompleteAsync(
            applicationContext,
            null,
            Handler(Looper.getMainLooper()),
        ) {
            val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(handle)
            if (callbackInfo == null) {
                Log.e(TAG, "Callback lookup failed for handle $handle")
                return@ensureInitializationCompleteAsync
            }

            val engine = FlutterEngine(applicationContext)
            val dartCallback = DartExecutor.DartCallback(
                applicationContext.assets,
                loader.findAppBundlePath(),
                callbackInfo,
            )
            engine.dartExecutor.executeDartCallback(dartCallback)

            val bgChannel = MethodChannel(
                engine.dartExecutor.binaryMessenger,
                "fuata/listener_spike_bg",
            )

            bgChannel.setMethodCallHandler { call, result ->
                if (call.method == "backgroundIsolateReady") {
                    bgChannel.invokeMethod(
                        "onNotification",
                        mapOf("packageName" to packageName, "text" to text),
                    )
                    result.success(null)
                    // Spike, not a long-lived worker — give the write a
                    // moment then tear the engine down.
                    Handler(Looper.getMainLooper()).postDelayed({ engine.destroy() }, 3000)
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    companion object {
        private const val TAG = "listener_spike"
        private const val PREFS = "fuata_listener_spike"
        private const val KEY_HANDLE = "callback_handle"

        fun writeCallbackHandle(context: Context, handle: Long) {
            prefs(context).edit().putLong(KEY_HANDLE, handle).apply()
        }

        private fun readCallbackHandle(context: Context): Long? {
            val v = prefs(context).getLong(KEY_HANDLE, -1L)
            return if (v == -1L) null else v
        }

        private fun prefs(context: Context): SharedPreferences =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    }
}