package com.kinyuanexus.fuata

import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * `fuata/share_intake` channel: issue #21. Android delivers ACTION_SEND
 * text/plain here (see the manifest's intent-filter); the text is
 * forwarded to Dart, with a small stash so a cold start from another
 * app's share sheet can't lose it before the Dart handler is up.
 */
class ShareIntakeChannel(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, CHANNEL)
    private var pendingSharedText: String? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedText" -> {
                    result.success(pendingSharedText)
                    pendingSharedText = null
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Route an ACTION_SEND text/plain intent to Dart (stashing if needed). */
    fun handleShareIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND) return
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return

        // Stash first: if the Dart handler isn't registered yet the
        // invoke fails silently, and getSharedText covers that case.
        pendingSharedText = text
        channel.invokeMethod(
            "onSharedText",
            text,
            object : MethodChannel.Result {
                // The Dart handler consumed it — drop the stash so a
                // later getSharedText can't deliver it a second time.
                override fun success(result: Any?) {
                    pendingSharedText = null
                }

                override fun error(
                    errorCode: String,
                    errorMessage: String?,
                    errorDetails: Any?,
                ) {
                }

                override fun notImplemented() {
                }
            },
        )
    }

    companion object {
        const val CHANNEL = "fuata/share_intake"
    }
}