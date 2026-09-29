package com.kinyuanexus.fuata.fuata

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation

/**
 * Runs the headless Flutter engine that turns a notification into a
 * transaction (issue #22; replaces the spike's engine-per-notification).
 *
 * One engine, kept alive while notifications keep arriving and torn down
 * after a short idle period:
 *  - notifications that arrive together (an SMS and its push twin) go to
 *    the SAME Dart isolate, which handles them one at a time, so dedupe
 *    can't race itself;
 *  - a burst doesn't pay engine start-up per message;
 *  - nothing is left running when there is nothing to do.
 *
 * Every field below is touched only on the main thread: [submit] hops to
 * it, and MethodChannel callbacks arrive on it.
 *
 * Nothing here logs notification text.
 */

object CaptureEngine {
    private const val TAG = "fuata_capture"
    private const val BG_CHANNEL = "fuata/capture_bg"
    private const val IDLE_TEARDOWN_MS = 20_000L
    private const val WATCHDOG_MS = 90_000L

    private val main = Handler(Looper.getMainLooper())

    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var starting = false
    private var ready = false
    private var inFlight = 0
    private val queue = ArrayDeque<Map<String, String>>()

    /**
     * Set by [CaptureChannel] while a UI engine exists. The background
     * isolate writes through its own database connection, so a running UI
     * never hears about the write on its own — this tells it to re-query.
     */
    @Volatile
    var onCapturesChanged: (() -> Unit)? = null

    /** Idle timeout after the last capture, or a watchdog while one is in flight. */
    private val teardown = Runnable { destroy("idle or watchdog timeout") }

    fun submit(context: Context, packageName: String, text: String) {
        val app = context.applicationContext
        main.post {
            queue.addLast(mapOf("packageName" to packageName, "text" to text))
            when {
                // flush() re-arms the watchdog, replacing any idle timer.
                ready -> flush()
                !starting -> start(app)
                // else: still starting. Leave the start watchdog alone;
                // flush() runs when Dart says it's ready.
            }
        }
    }

    private fun start(context: Context) {
        val handle = CaptureStore.readCallbackHandle(context)
        if (handle == null) {
            // Never registered: the app hasn't been opened since install /
            // update. Dropping is the only option; say so without content.
            Log.w(TAG, "No callback handle registered — open the app once first. Dropped ${queue.size}.")
            queue.clear()
            return
        }

        starting = true
        armTeardown(WATCHDOG_MS) // a start that never completes must not wedge us

        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(context)
        loader.ensureInitializationCompleteAsync(context, null, main) {
            val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(handle)
            if (callbackInfo == null) {
                // Stale handle (app updated, not yet reopened).
                Log.e(TAG, "Callback lookup failed for handle $handle — open the app once.")
                destroy("callback lookup failed")
                return@ensureInitializationCompleteAsync
            }

            val eng = FlutterEngine(context)
            val ch = MethodChannel(eng.dartExecutor.binaryMessenger, BG_CHANNEL)
            ch.setMethodCallHandler { call, result ->
                if (call.method == "backgroundIsolateReady" && engine === eng) {
                    starting = false
                    ready = true
                    result.success(null)
                    flush()
                } else {
                    result.notImplemented()
                }
            }
            engine = eng
            channel = ch
            eng.dartExecutor.executeDartCallback(
                DartExecutor.DartCallback(
                    context.assets,
                    loader.findAppBundlePath(),
                    callbackInfo,
                ),
            )
        }
    }

    private fun flush() {
        val ch = channel ?: return
        while (queue.isNotEmpty()) {
            val payload = queue.removeFirst()
            inFlight++
            armTeardown(WATCHDOG_MS)
            ch.invokeMethod(
                "onNotification",
                payload,
                object : MethodChannel.Result {
                    // Dart answers true when it wrote something.
                    override fun success(result: Any?) = finish(result == true)

                    override fun error(code: String, message: String?, details: Any?) {
                        // Code only — a message could echo notification text.
                        Log.e(TAG, "capture failed: $code")
                        finish(false)
                    }

                    override fun notImplemented() = finish(false)
                },
            )
        }
    }

    private fun finish(wrote: Boolean) {
        inFlight = (inFlight - 1).coerceAtLeast(0)
        if (wrote) onCapturesChanged?.invoke()
        if (inFlight == 0 && queue.isEmpty()) armTeardown(IDLE_TEARDOWN_MS)
    }

    private fun armTeardown(delayMs: Long) {
        main.removeCallbacks(teardown)
        main.postDelayed(teardown, delayMs)
    }

    private fun destroy(reason: String) {
        Log.i(TAG, "tearing down capture engine ($reason); dropping ${queue.size} queued")
        main.removeCallbacks(teardown)
        channel?.setMethodCallHandler(null)
        engine?.destroy()
        engine = null
        channel = null
        starting = false
        ready = false
        inFlight = 0
        queue.clear()
    }
}