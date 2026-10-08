package com.mystyle.purelive

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper

/** Shell-only debug hooks for exercising recorder lifecycle callbacks on a device. */
class RecorderLifecycleProbeReceiver : BroadcastReceiver() {
    companion object {
        private const val ACTION_PROBE =
            "com.mystyle.purelive.debug.RECORDER_LIFECYCLE_PROBE"
        private const val ACTION_TIMEOUT = "$ACTION_PROBE.timeout"
        private const val ACTION_FINISH_ACTIVITY = "$ACTION_PROBE.finishActivity"
        private const val ACTION_SERVICE_STOP = "$ACTION_PROBE.serviceStop"
        private const val EXTRA_OPERATION = "operation"

        private const val OP_TIMEOUT = "timeout"
        private const val OP_FINISH_ACTIVITY = "finishActivity"
        private const val OP_SERVICE_STOP = "serviceStop"

        private val mainHandler = Handler(Looper.getMainLooper())
    }

    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        mainHandler.post {
            val result = try {
                when {
                    !BuildConfig.DEBUG -> ProbeResult(false, "error:not_debug_build")
                    else -> when (resolveOperation(intent)) {
                        Operation.TIMEOUT -> serviceResult(
                            RecorderForegroundService.debugInjectTimeout(),
                            "ok:timeout_callback_injected",
                        )
                        Operation.FINISH_ACTIVITY -> activityResult(
                            MainActivity.debugFinishActiveActivity(),
                        )
                        Operation.SERVICE_STOP -> serviceResult(
                            RecorderForegroundService.debugStopActiveService(),
                            "ok:service_stop_requested",
                        )
                        null -> ProbeResult(false, "error:invalid_operation")
                    }
                }
            } catch (_: Throwable) {
                ProbeResult(false, "error:probe_failed")
            }
            try {
                pendingResult.resultCode =
                    if (result.success) Activity.RESULT_OK else Activity.RESULT_CANCELED
                pendingResult.resultData = result.data
            } finally {
                pendingResult.finish()
            }
        }
    }

    private fun resolveOperation(intent: Intent): Operation? {
        val actionOperation = when (intent.action) {
            ACTION_TIMEOUT -> Operation.TIMEOUT
            ACTION_FINISH_ACTIVITY -> Operation.FINISH_ACTIVITY
            ACTION_SERVICE_STOP -> Operation.SERVICE_STOP
            null, ACTION_PROBE -> null
            else -> return null
        }
        val extraOperation = when (intent.getStringExtra(EXTRA_OPERATION)) {
            OP_TIMEOUT -> Operation.TIMEOUT
            OP_FINISH_ACTIVITY -> Operation.FINISH_ACTIVITY
            OP_SERVICE_STOP -> Operation.SERVICE_STOP
            null -> null
            else -> return null
        }
        if (actionOperation != null && extraOperation != null && actionOperation != extraOperation) {
            return null
        }
        return actionOperation ?: extraOperation
    }

    private fun serviceResult(success: Boolean, successData: String): ProbeResult =
        if (success) ProbeResult(true, successData)
        else ProbeResult(false, "no_active_service")

    private fun activityResult(success: Boolean): ProbeResult =
        if (success) ProbeResult(true, "ok:activity_finish_requested")
        else ProbeResult(false, "no_active_activity")

    private enum class Operation {
        TIMEOUT,
        FINISH_ACTIVITY,
        SERVICE_STOP,
    }

    private data class ProbeResult(val success: Boolean, val data: String)
}
