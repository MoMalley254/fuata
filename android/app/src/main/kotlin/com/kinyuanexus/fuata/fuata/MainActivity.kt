package com.kinyuanexus.fuata.fuata

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * `fuata/listener_spike` channel: issue #18 only. Stores the Dart callback
 * handle NotificationListener.kt needs, and opens Android's notification
 * access settings. Throwaway — removed or replaced by real plugin wiring
 * once #22 lands.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fuata/listener_spike")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setCallbackHandle" -> {
                        val handle = (call.arguments as Number).toLong()
                        NotificationListener.writeCallbackHandle(applicationContext, handle)
                        result.success(null)
                    }
                    "openNotificationAccessSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}