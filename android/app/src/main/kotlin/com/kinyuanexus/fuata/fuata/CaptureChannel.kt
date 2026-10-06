package com.kinyuanexus.fuata.fuata

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * `fuata/capture` channel: the UI isolate's line to the capture side
 * (issue #22; replaces the spike's `fuata/listener_spike`).
 *
 * Dart -> native: setCallbackHandle, setAllowedPackages,
 * openNotificationAccessSettings, isNotificationAccessEnabled,
 * listLaunchableApps.
 * Native -> Dart: onCapturesChanged (the background isolate just wrote).
 */
class CaptureChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val io: ExecutorService = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private val notifyUi: () -> Unit = {
        Log.d("fuata_capture", "onCapturesChanged → pinging UI")
        channel.invokeMethod("onCapturesChanged", null)
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setCallbackHandle" -> {
                    CaptureStore.writeCallbackHandle(context, (call.arguments as Number).toLong())
                    result.success(null)
                }

                "setAllowedPackages" -> {
                    val list = (call.arguments as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                    CaptureStore.writeAllowedPackages(context, list)
                    result.success(null)
                }

                "openNotificationAccessSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(null)
                }

                "isNotificationAccessEnabled" -> result.success(isAccessEnabled())

                "listLaunchableApps" -> {
                    // Loading labels for a hundred-odd apps is slow enough
                    // to jank the UI thread; do it elsewhere and reply on main.
                    io.execute {
                        val apps = launchableApps()
                        main.post { result.success(apps) }
                    }
                }

                "openAppNotificationSettings" -> {
                    val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                        putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
        CaptureEngine.onCapturesChanged = notifyUi
    }

    fun dispose() {
        // Only detach if it is still ours: a newer activity may already
        // have installed its own notifier.
        if (CaptureEngine.onCapturesChanged === notifyUi) {
            CaptureEngine.onCapturesChanged = null
        }
        channel.setMethodCallHandler(null)
        io.shutdown()
    }

    /**
     * True when the person has granted Fuata notification access. This is
     * the GRANT — design.md 5.1 documents a device where it was granted
     * but the service never bound. Detecting that is #36.
     */
    private fun isAccessEnabled(): Boolean {
        val flat = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return flat.split(":").any {
            ComponentName.unflattenFromString(it)?.packageName == context.packageName
        }
    }

    /**
     * Launchable apps only (needs the launcher-intent `<queries>` entry in
     * the manifest on Android 11+) — deliberately not QUERY_ALL_PACKAGES,
     * which Play policy restricts and Fuata doesn't need.
     */
    @Suppress("DEPRECATION")
    private fun launchableApps(): List<Map<String, String>> {
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .asSequence()
            .map { it.activityInfo.packageName to it.loadLabel(pm).toString() }
            .filter { (pkg, _) -> pkg != context.packageName }
            .distinctBy { it.first }
            .map { (pkg, label) -> mapOf("packageName" to pkg, "label" to label) }
            .toList()
    }

    companion object {
        const val CHANNEL = "fuata/capture"
    }
}