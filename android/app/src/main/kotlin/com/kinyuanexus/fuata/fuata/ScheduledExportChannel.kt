package com.kinyuanexus.fuata.fuata

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * `fuata/scheduled_export` — the UI isolate's channel (issue #35).
 *
 *  schedule {triggerAtMillis, intervalMillis}   -> null
 *  cancel                                      -> null
 *  pickFolder                                  -> tree URI string or null
 *  hasPersistedFolder {uri}                    -> bool
 *  folderDisplayName {uri}                     -> string or null
 *  clearFolder {uri}                           -> null
 *  saveToFolder {uri, filename, content}       -> bool
 *  lastRun                                     -> {at, success, error}
 *  setCallbackHandle {handle}                  -> null
 *
 * The folder picker needs an Activity (it uses startActivityForResult), so
 * this channel takes one; the background channel does not need it and
 * lives in its own file.
 */
class ScheduledExportChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL)

    private var pendingFolder: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    val m = call.arguments as? Map<*, *>
                    val trigger = (m?.get("triggerAtMillis") as? Number)?.toLong()
                    val interval = (m?.get("intervalMillis") as? Number)?.toLong()
                    if (trigger == null || interval == null) {
                        result.error("bad_args", "trigger + interval required", null)
                        return@setMethodCallHandler
                    }
                    ScheduledExportEngine.schedule(activity.applicationContext, trigger, interval)
                    result.success(null)
                }
                "cancel" -> {
                    ScheduledExportEngine.cancel(activity.applicationContext)
                    result.success(null)
                }
                "pickFolder" -> {
                    if (pendingFolder != null) {
                        result.error("busy", "A folder picker is already open", null)
                        return@setMethodCallHandler
                    }
                    pendingFolder = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                        )
                    }
                    activity.startActivityForResult(intent, REQ_PICK_FOLDER)
                }
                "hasPersistedFolder" -> {
                    val uri = uriArg(call.arguments) ?: run {
                        result.success(false); return@setMethodCallHandler
                    }
                    result.success(
                        FolderWriter.hasPersistedPermission(
                            activity.applicationContext, uri,
                        ),
                    )
                }
                "folderDisplayName" -> {
                    val uri = uriArg(call.arguments)
                    result.success(
                        uri?.let {
                            FolderWriter.displayName(activity.applicationContext, it)
                        },
                    )
                }
                "clearFolder" -> {
                    val uri = uriArg(call.arguments) ?: run {
                        result.success(null); return@setMethodCallHandler
                    }
                    try {
                        activity.contentResolver.releasePersistableUriPermission(
                            uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                        )
                    } catch (_: SecurityException) {
                        // already released, or never held — nothing to do
                    }
                    result.success(null)
                }
                "saveToFolder" -> {
                    val m = call.arguments as? Map<*, *>
                    val uri = (m?.get("uri") as? String)?.let(Uri::parse)
                    val name = m?.get("filename") as? String
                    val content = m?.get("content") as? String
                    if (uri == null || name == null || content == null) {
                        result.error("bad_args", "uri, filename and content required", null)
                        return@setMethodCallHandler
                    }
                    // Writing to disk from a channel handler would block the
                    // main thread; do it elsewhere and reply on main.
                    Thread {
                        val ok = FolderWriter.write(
                            activity.applicationContext, uri, name, content,
                        )
                        activity.runOnUiThread { result.success(ok) }
                    }.start()
                }
                "lastRun" -> result.success(
                    ScheduledExportEngine.lastRun(activity.applicationContext),
                )
                "setCallbackHandle" -> {
                    val handle = (call.arguments as? Number)?.toLong() ?: return@setMethodCallHandler
                    ScheduledExportEngine.writeCallbackHandle(
                        activity.applicationContext, handle,
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Returns true if [requestCode] was ours. */
    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQ_PICK_FOLDER) return false
        val result = pendingFolder
        pendingFolder = null
        if (result == null) return true

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        try {
            activity.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            result.success(uri.toString())
        } catch (e: SecurityException) {
            result.error(
                "permission_failed",
                "That folder can't be used for backups.",
                null,
            )
        }
        return true
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pendingFolder = null
    }

    private fun uriArg(args: Any?): Uri? =
        ((args as? Map<*, *>)?.get("uri") as? String)?.let(Uri::parse)

    companion object {
        const val CHANNEL = "fuata/scheduled_export"
        private const val REQ_PICK_FOLDER = 41201
    }
}