package com.kinyuanexus.fuata.fuata

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * `fuata/backup_files` channel: issue #24 (US-15, "export/import a JSON file
 * to any location the user chooses").
 *
 * Uses the system file picker (Storage Access Framework), so Fuata needs no
 * storage permission and never sees any file the person didn't pick. Both
 * calls hand a whole UTF-8 text file across the channel; the JSON is built
 * and validated on the Dart side.
 *
 *  - `saveText {name, content}` -> true if written, false if cancelled
 *  - `pickText`                 -> the file's text, or null if cancelled
 *
 * Errors come back as PlatformException codes: `busy`, `bad_args`,
 * `write_failed`, `read_failed`, `too_large`.
 */
class BackupFilesChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL)

    // Only one picker can be up at a time; the result is completed from
    // handleActivityResult.
    private var pending: MethodChannel.Result? = null
    private var pendingContent: String? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "saveText" -> {
                    val name = call.argument<String>("name") ?: "fuata-backup.json"
                    val content = call.argument<String>("content")
                    if (content == null) {
                        result.error("bad_args", "Missing content", null)
                        return@setMethodCallHandler
                    }
                    if (!claim(result)) return@setMethodCallHandler
                    pendingContent = content
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_TITLE, name)
                    }
                    activity.startActivityForResult(intent, REQ_SAVE)
                }

                "pickText" -> {
                    if (!claim(result)) return@setMethodCallHandler
                    // Providers often label .json files as text/plain or
                    // octet-stream, so accept all three rather than
                    // hiding a perfectly good backup.
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(
                            Intent.EXTRA_MIME_TYPES,
                            arrayOf(
                                "application/json",
                                "text/plain",
                                "application/octet-stream",
                            ),
                        )
                    }
                    activity.startActivityForResult(intent, REQ_OPEN)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun claim(result: MethodChannel.Result): Boolean {
        if (pending != null) {
            result.error("busy", "A file picker is already open", null)
            return false
        }
        pending = result
        return true
    }

    /** Returns true if [requestCode] was ours (and so is now handled). */
    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQ_SAVE && requestCode != REQ_OPEN) return false

        val result = pending
        val content = pendingContent
        pending = null
        pendingContent = null
        if (result == null) return true

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            // Cancelled: not an error.
            result.success(if (requestCode == REQ_SAVE) false else null)
            return true
        }

        // Disk and provider I/O off the main thread; result back on it.
        Thread {
            try {
                if (requestCode == REQ_SAVE) {
                    // "wt" truncates: overwriting a picked file must not
                    // leave the tail of a longer old one behind.
                    activity.contentResolver.openOutputStream(uri, "wt")!!.use {
                        it.write((content ?: "").toByteArray(Charsets.UTF_8))
                    }
                    activity.runOnUiThread { result.success(true) }
                } else {
                    val text = readLimited(uri)
                    activity.runOnUiThread {
                        if (text == null) {
                            result.error(
                                "too_large",
                                "That file is too big to be a Fuata backup",
                                null,
                            )
                        } else {
                            result.success(text)
                        }
                    }
                }
            } catch (e: Exception) {
                val code = if (requestCode == REQ_SAVE) "write_failed" else "read_failed"
                activity.runOnUiThread { result.error(code, e.message, null) }
            }
        }.start()
        return true
    }

    /** Whole file as UTF-8, or null if it exceeds [MAX_IMPORT_BYTES]. */
    private fun readLimited(uri: android.net.Uri): String? {
        val out = ByteArrayOutputStream()
        activity.contentResolver.openInputStream(uri)!!.use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                out.write(buffer, 0, n)
                if (out.size() > MAX_IMPORT_BYTES) return null
            }
        }
        return out.toString(Charsets.UTF_8.name())
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pending = null
        pendingContent = null
    }

    companion object {
        const val CHANNEL = "fuata/backup_files"
        private const val REQ_SAVE = 41001
        private const val REQ_OPEN = 41002

        // A backup of years of daily use is a few MB; anything past this is
        // not one, and reading it would only risk running out of memory.
        private const val MAX_IMPORT_BYTES = 32 * 1024 * 1024
    }
}