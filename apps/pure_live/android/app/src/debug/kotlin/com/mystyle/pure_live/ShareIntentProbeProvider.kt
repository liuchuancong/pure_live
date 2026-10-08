package com.mystyle.purelive

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File
import java.io.FileNotFoundException

/** Debug-only provider for deterministic shared-URI failure and filename coverage. */
class ShareIntentProbeProvider : ContentProvider() {
    companion object {
        const val AUTHORITY_SUFFIX = ".shareProbeProvider"
        const val MODE_TYPE_ERROR = "type-error"
        const val MODE_QUERY_ERROR = "query-error"
        const val MODE_LONG_NAME = "long-name"

        val LONG_DISPLAY_NAME = "共享\u0001附件_${"长😀".repeat(80)}.m3u"

        fun uriFor(packageName: String, mode: String, file: File? = null): Uri {
            val builder = Uri.Builder()
                .scheme("content")
                .authority(packageName + AUTHORITY_SUFFIX)
                .appendPath(mode)
            file?.let { builder.appendPath(it.name) }
            return builder.build()
        }
    }

    override fun onCreate(): Boolean = true

    override fun getType(uri: Uri): String = when (uri.mode()) {
        MODE_TYPE_ERROR -> error("intentional debug provider type failure")
        MODE_QUERY_ERROR, MODE_LONG_NAME -> "application/x-mpegURL"
        else -> throw IllegalArgumentException("Unsupported probe URI: $uri")
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = when (uri.mode()) {
        MODE_QUERY_ERROR -> error("intentional debug provider query failure")
        MODE_LONG_NAME -> MatrixCursor(arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)).apply {
            addRow(arrayOf(LONG_DISPLAY_NAME, resolveFile(uri).length()))
        }
        else -> null
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw FileNotFoundException("Probe content is read-only")
        return ParcelFileDescriptor.open(resolveFile(uri), ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0

    private fun resolveFile(uri: Uri): File {
        if (uri.mode() !in setOf(MODE_QUERY_ERROR, MODE_LONG_NAME)) {
            throw FileNotFoundException("Probe URI has no file")
        }
        val name = uri.pathSegments.getOrNull(1)
            ?: throw FileNotFoundException("Probe URI has no filename")
        val appContext = context ?: throw FileNotFoundException("Provider context is missing")
        val root = File(appContext.cacheDir, "share_probe").canonicalFile
        val file = File(root, name).canonicalFile
        if (!file.isFile || !file.canRead() || !file.isWithin(root)) {
            throw FileNotFoundException("Probe file is outside the guarded cache root")
        }
        return file
    }

    private fun Uri.mode(): String? = pathSegments.firstOrNull()

    private fun File.isWithin(root: File): Boolean = path.startsWith(root.path + File.separator)
}
