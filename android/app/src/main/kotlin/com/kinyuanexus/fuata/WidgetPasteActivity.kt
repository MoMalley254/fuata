package com.kinyuanexus.fuata

import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.util.Log
import android.view.WindowManager
import android.widget.Toast
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Issue #153: the home-screen widget's Paste button lands here.
 *
 * A transparent activity with its own Flutter engine, so the add-
 * transaction sheet rises over the launcher without the app's UI ever
 * coming to the front.
 *
 * Why an activity at all: since Android 10 only the app that has input
 * focus may read the clipboard. A widget's PendingIntent has no focus, so
 * the read happens here, in onWindowFocusChanged(true) — the first moment
 * this window is allowed to. Dart asks for the text over
 * `fuata/widget_paste`; if it asks before focus arrives the reply is held
 * until the read is done.
 *
 * FLAG_SECURE is always on: this window shows amounts, and Dart can't
 * decide the person's "hide amounts" choice before the first frame.
 */
class WidgetPasteActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var homeWidget: HomeWidgetChannel? = null

    private var createdAt = 0L

    private var clipboardRead = false
    private var clipboardText: String? = null
    private var pendingClipboardResult: MethodChannel.Result? = null

    // Entry point lives in main.dart (the root library) — see widgetPasteMain.
    override fun getDartEntrypointFunctionName(): String = "widgetPasteMain"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        createdAt = SystemClock.elapsedRealtime()
        Log.d(TAG, "+0ms  onCreate")
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "+${elapsed()}ms  configureFlutterEngine")
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // refreshDerivedState() pushes the widget snapshot through this
        // channel, and this engine has no other native side for it.
        homeWidget = HomeWidgetChannel(applicationContext, messenger)

        channel = MethodChannel(messenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getClipboard" -> {
                        if (clipboardRead) {
                            result.success(clipboardText)
                        } else {
                            pendingClipboardResult = result
                        }
                    }

                    "msSinceCreate" -> result.success(elapsed().toInt())

                    "finish" -> {
                        val message = call.argument<String>("message")
                        if (!message.isNullOrBlank()) {
                            Toast.makeText(
                                applicationContext, message, Toast.LENGTH_SHORT,
                            ).show()
                        }
                        result.success(null)
                        finish()
                    }

                    "openApp" -> {
                        packageManager.getLaunchIntentForPackage(packageName)
                            ?.apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                        Intent.FLAG_ACTIVITY_CLEAR_TOP
                            }
                            ?.let { startActivity(it) }
                        result.success(null)
                        finish()
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        homeWidget?.dispose()
        homeWidget = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && !clipboardRead) {
            Log.d(TAG, "+${elapsed()}ms  window focus")
            clipboardText = readClipboard()
            clipboardRead = true
            Log.d(TAG, "+${elapsed()}ms  clipboard read")
            pendingClipboardResult?.success(clipboardText)
            pendingClipboardResult = null
        }
    }

    private fun readClipboard(): String? = try {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        val clip = cm?.primaryClip
        if (clip != null && clip.itemCount > 0) {
            clip.getItemAt(0).coerceToText(this)?.toString()?.trim()
                ?.takeIf { it.isNotEmpty() }
        } else null
    } catch (_: Exception) {
        null
    }

    private fun elapsed(): Long = SystemClock.elapsedRealtime() - createdAt

    companion object {
        const val CHANNEL = "fuata/widget_paste"
        private const val TAG = "widget-paste"
    }
}