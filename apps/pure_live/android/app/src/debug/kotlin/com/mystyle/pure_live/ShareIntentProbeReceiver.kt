package com.mystyle.purelive

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File

/** Shell-only debug hook that emits a real ACTION_SEND_MULTIPLE ArrayList<Uri>. */
class ShareIntentProbeReceiver : BroadcastReceiver() {
    companion object {
        private const val ACTION_SEND_MULTIPLE_PROBE =
            "com.mystyle.purelive.debug.SEND_MULTIPLE_PROBE"
        private const val ACTION_PROVIDER_EDGE_PROBE =
            "com.mystyle.purelive.debug.PROVIDER_EDGE_PROBE"
        private const val EXTRA_PATHS = "paths"
        private const val MAX_ATTACHMENTS = 8
    }

    override fun onReceive(context: Context, intent: Intent) {
        val result = try {
            when {
                !BuildConfig.DEBUG -> ProbeResult(false, "error:not_debug_build")
                intent.action == ACTION_SEND_MULTIPLE_PROBE -> sendMultiple(context, intent)
                intent.action == ACTION_PROVIDER_EDGE_PROBE -> sendProviderEdges(context, intent)
                else -> ProbeResult(false, "error:invalid_action")
            }
        } catch (_: Throwable) {
            ProbeResult(false, "error:probe_failed")
        }
        resultCode = if (result.success) Activity.RESULT_OK else Activity.RESULT_CANCELED
        resultData = result.data
    }

    private fun sendMultiple(context: Context, request: Intent): ProbeResult {
        val files = validatedFiles(context, request, 1..MAX_ATTACHMENTS)
            ?: return ProbeResult(false, "error:invalid_attachment_path")

        val uris = ArrayList(files.map { file ->
            FileProvider.getUriForFile(context, "${context.packageName}.fileProvider", file)
        })
        startMultiple(context, uris)
        return ProbeResult(true, "ok:send_multiple:${uris.size}")
    }

    private fun sendProviderEdges(context: Context, request: Intent): ProbeResult {
        val files = validatedFiles(context, request, 2..2)
            ?: return ProbeResult(false, "error:invalid_attachment_path")
        val uris = arrayListOf(
            ShareIntentProbeProvider.uriFor(
                context.packageName,
                ShareIntentProbeProvider.MODE_TYPE_ERROR,
            ),
            ShareIntentProbeProvider.uriFor(
                context.packageName,
                ShareIntentProbeProvider.MODE_QUERY_ERROR,
                files[0],
            ),
            ShareIntentProbeProvider.uriFor(
                context.packageName,
                ShareIntentProbeProvider.MODE_LONG_NAME,
                files[1],
            ),
        )
        startMultiple(context, uris)
        return ProbeResult(true, "ok:provider_edges:${uris.size}")
    }

    private fun validatedFiles(context: Context, request: Intent, count: IntRange): List<File>? {
        val requestedPaths = request.getStringArrayExtra(EXTRA_PATHS)?.toList().orEmpty()
        if (requestedPaths.size !in count) return null
        val probeRoot = File(context.cacheDir, "share_probe").canonicalFile
        val files = requestedPaths.map { path -> File(path).canonicalFile }
        return files.takeIf { candidates ->
            candidates.all { file -> file.isFile && file.canRead() && file.isWithin(probeRoot) }
        }
    }

    private fun startMultiple(context: Context, uris: ArrayList<Uri>) {
        val target = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_SEND_MULTIPLE
            type = "application/octet-stream"
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(target)
    }

    private fun File.isWithin(root: File): Boolean =
        path.startsWith(root.path + File.separator)

    private data class ProbeResult(val success: Boolean, val data: String)
}
