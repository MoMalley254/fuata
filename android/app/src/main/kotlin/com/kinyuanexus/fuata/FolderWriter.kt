package com.kinyuanexus.fuata

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract

/**
 * Shared SAF-tree file logic for scheduled export (issue #35). Both the
 * UI channel (for the "Run now" button) and the background channel (for
 * the scheduled run) delegate here, so there is exactly one place that
 * knows how a Fuata file gets written into a chosen folder.
 */
object FolderWriter {

    fun hasPersistedPermission(context: Context, uri: Uri): Boolean {
        return context.contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isWritePermission
        }
    }

    fun displayName(context: Context, folderUri: Uri): String? = try {
        val docUri = DocumentsContract.buildDocumentUriUsingTree(
            folderUri,
            DocumentsContract.getTreeDocumentId(folderUri),
        )
        context.contentResolver.query(
            docUri,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null, null, null,
        )?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
    } catch (_: Exception) {
        null
    }

    /**
     * Writes [content] to a new file named [filename] inside [folderUri].
     * Timestamped filenames (see scheduledExportFileName in Dart) mean
     * collisions are essentially impossible; if one does occur, delete
     * the existing file and retry, which is the one time we're willing to
     * lose data — a "same-second" retry after a visible failure is more
     * useful than refusing forever.
     */
    fun write(
        context: Context,
        folderUri: Uri,
        filename: String,
        content: String,
    ): Boolean = try {
        val resolver = context.contentResolver
        val parentDoc = DocumentsContract.buildDocumentUriUsingTree(
            folderUri,
            DocumentsContract.getTreeDocumentId(folderUri),
        )
        var target = tryCreate(resolver, parentDoc, filename)
        if (target == null) {
            // Provider says the name is taken: delete and retry once.
            findChild(resolver, folderUri, filename)?.let {
                try { DocumentsContract.deleteDocument(resolver, it) } catch (_: Exception) {}
            }
            target = tryCreate(resolver, parentDoc, filename)
        }
        if (target == null) return false
        resolver.openOutputStream(target, "wt")?.use {
            it.write(content.toByteArray(Charsets.UTF_8))
        } ?: return false
        true
    } catch (_: Exception) {
        false
    }

    private fun tryCreate(
        resolver: android.content.ContentResolver,
        parentDoc: Uri,
        filename: String,
    ): Uri? = try {
        DocumentsContract.createDocument(
            resolver, parentDoc, "application/octet-stream", filename,
        )
    } catch (_: Exception) {
        null
    }

    private fun findChild(
        resolver: android.content.ContentResolver,
        folderUri: Uri,
        filename: String,
    ): Uri? {
        val treeDocId = DocumentsContract.getTreeDocumentId(folderUri)
        val childrenUri =
            DocumentsContract.buildChildDocumentsUriUsingTree(folderUri, treeDocId)
        resolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            ),
            null, null, null,
        )?.use { c ->
            while (c.moveToNext()) {
                if (c.getString(1) == filename) {
                    return DocumentsContract.buildDocumentUriUsingTree(
                        folderUri, c.getString(0),
                    )
                }
            }
        }
        return null
    }
}