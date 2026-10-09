package com.kinyuanexus.fuata.fuata

import android.app.Activity
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * `fuata/privacy` channel: issue #84, finding F20.
 *
 * One thing: set or clear `WindowManager.LayoutParams.FLAG_SECURE` on the
 * Activity's window. While set, Android blocks screenshots and screen
 * recording, and shows a blank card for Fuata in the app switcher. That's
 * the whole feature — the toggle in Settings stores the person's choice,
 * and this is what tells Android about it.
 *
 * Takes the Activity rather than the application context (unlike
 * CaptureChannel): the window flag lives on a specific Activity's window,
 * and there is no way to reach it from an application context.
 *
 * applySecure is idempotent. Re-sending the same value is a no-op, so the
 * Dart side can push on every settings emission without churning the
 * window, which is noticeable as a flicker on some devices.
 */
class PrivacyChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL)
    private var lastValue: Boolean? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val secure = call.arguments as? Boolean
                    if (secure == null) {
                        result.error("bad_args", "Expected true or false", null)
                        return@setMethodCallHandler
                    }
                    applySecure(secure)
                    result.success(null)
                }

                // Read-only, for tests and for anything that wants to know
                // what the OS currently has without changing it.
                "isSecure" -> result.success(lastValue ?: false)

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Sets or clears FLAG_SECURE on the window. Field writes go through
     * `lastValue` so a caller that pushes the same value twice doesn't
     * touch the window at all.
     */
    private fun applySecure(secure: Boolean) {
        if (lastValue == secure) return
        lastValue = secure
        if (secure) {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        lastValue = null
    }

    companion object {
        const val CHANNEL = "fuata/privacy"
    }
}