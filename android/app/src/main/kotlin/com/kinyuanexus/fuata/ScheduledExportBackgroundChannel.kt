package com.kinyuanexus.fuata

import android.content.Context
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * `fuata/scheduled_export_bg` — the background isolate's channel
 * (issue #35). Three methods only, all application-context-only; the
 * folder picker and any intent-launching live on the UI channel.
 *
 *  backgroundIsolateReady                        -> null
 *  saveToFolder {uri, filename, content}        -> bool
 *  reportResult {success, error?}               -> null
 */
class ScheduledExportBackgroundChannel(
    private val context: Context,
    messenger: BinaryMessenger,
    private val onFinished: () -> Unit,
) {
    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "backgroundIsolateReady" -> result.success(null)
                "saveToFolder" -> {
                    val m = call.arguments as? Map<*, *>
                    val uri = (m?.get("uri") as? String)?.let(Uri::parse)
                    val name = m?.get("filename") as? String
                    val content = m?.get("content") as? String
                    if (uri == null || name == null || content == null) {
                        result.error("bad_args", "uri, filename and content required", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        val ok = FolderWriter.write(context, uri, name, content)
                        result.success(ok)
                    }.start()
                }
                "reportResult" -> {
                    val m = call.arguments as? Map<*, *>
                    val success = (m?.get("success") as? Boolean) ?: false
                    val error = m?.get("error") as? String
                    ScheduledExportEngine.recordRun(context, success, error)
                    result.success(null)
                    onFinished()
                }
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    companion object {
        const val CHANNEL = "fuata/scheduled_export_bg"
    }
}