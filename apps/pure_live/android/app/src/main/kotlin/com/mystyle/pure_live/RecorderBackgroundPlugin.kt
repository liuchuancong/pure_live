package com.mystyle.purelive

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.service.media.MediaBrowserService
import com.ryanheise.audioservice.AudioService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque

/** Engine-scoped bridge for the recording foreground-service lifetime. */
class RecorderBackgroundPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL_NAME = "pure_live/recorder_background"
        private const val ERROR_CODE = "recorder_background_unavailable"
    }

    private var channel: MethodChannel? = null
    private var coordinator: Coordinator? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel = methodChannel
        coordinator = Coordinator(binding.applicationContext) { reason ->
            channel?.invokeMethod("interrupted", mapOf("reason" to reason))
        }
        methodChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val activeCoordinator = coordinator
        if (call.method == "releaseIdle") {
            if (activeCoordinator == null) {
                result.unavailable("Recorder background bridge is detached")
            } else {
                activeCoordinator.releaseIdle(result)
            }
            return
        }
        if (call.method != "setActive") return result.notImplemented()
        val active = call.argument<Boolean>("active")
        if (active == null) {
            result.unavailable("Missing active flag")
            return
        }
        if (activeCoordinator == null) {
            result.unavailable("Recorder background bridge is detached")
            return
        }
        if (!active) {
            activeCoordinator.deactivate(result)
            return
        }
        val title = call.argument<String>("title")?.trim().orEmpty()
        val text = call.argument<String>("text")?.trim().orEmpty()
        if (title.isEmpty() || text.isEmpty()) {
            result.unavailable("Notification title and text are required")
            return
        }
        activeCoordinator.activate(title.take(120), text.take(240), result)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        coordinator?.disconnectEngine()
        coordinator = null
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun MethodChannel.Result.unavailable(message: String) {
        error(ERROR_CODE, sanitize(message), null)
    }

    private enum class State { IDLE, STARTING, ACTIVE, STOPPING, DRAINING, DISPOSED }

    private class Coordinator(
        context: Context,
        private val interrupted: (String) -> Unit,
    ) : RecorderForegroundService.Listener {
        companion object {
            private const val START_TIMEOUT_MILLIS = 15_000L
            private const val STOP_TIMEOUT_MILLIS = 15_000L
            private const val IDLE_RELEASE_TIMEOUT_MILLIS = 15_000L
            private const val TIMEOUT_DRAIN_MILLIS = 45_000L
        }

        private val context = context.applicationContext
        private val handler = Handler(Looper.getMainLooper())
        private var state = State.IDLE
        private var generation = 0L
        private var serviceLaunchIssued = false
        private var foregroundReady = false
        private var engineLeaseReady = false
        private var engineBindingStarted = false
        private var engineConnection: EngineConnection? = null
        private var wakeLock: PowerManager.WakeLock? = null
        private var wifiLock: WifiManager.WifiLock? = null
        private var stopObserved = false
        private var interruptionSent = false
        private var retainEngineWhenStopped = false
        private var restartRequest: Pair<String, String>? = null
        private val activateResults = ArrayDeque<MethodChannel.Result>()
        private val deactivateResults = ArrayDeque<MethodChannel.Result>()
        private var deadline: Runnable? = null
        private var hardReleaseAtMillis: Long? = null

        fun activate(title: String, text: String, result: MethodChannel.Result) = onMain {
            when (state) {
                State.IDLE -> {
                    cancelDeadline()
                    activateResults += result
                    beginStart(title, text)
                }
                State.STARTING -> activateResults += result
                State.ACTIVE -> result.success(null)
                State.STOPPING -> {
                    restartRequest = title to text
                    activateResults += result
                }
                State.DRAINING -> result.unavailable(
                    "The previous recording is still completing after a system timeout",
                )
                State.DISPOSED -> result.unavailable("Recorder background bridge is detached")
            }
        }

        fun deactivate(result: MethodChannel.Result) = onMain {
            when (state) {
                State.IDLE -> result.success(null)
                State.STARTING -> {
                    retainEngineWhenStopped = true
                    deactivateResults += result
                    failPendingActivation("Activation was superseded by a stop request")
                    beginStop()
                }
                State.ACTIVE -> {
                    retainEngineWhenStopped = true
                    deactivateResults += result
                    beginStop()
                }
                State.STOPPING -> {
                    restartRequest = null
                    failPendingActivation("Activation was superseded by a stop request")
                    deactivateResults += result
                }
                State.DRAINING -> {
                    retainEngineWhenStopped = true
                    deactivateResults += result
                    if (stopObserved) finishStopped() else RecorderForegroundService.cancel(generation)
                }
                State.DISPOSED -> result.unavailable("Recorder background bridge is detached")
            }
        }

        fun releaseIdle(result: MethodChannel.Result) = onMain {
            if (state != State.IDLE) {
                // A stale release from the previous Dart queue must never tear
                // down a newer recording generation.
                result.success(null)
                return@onMain
            }
            cancelDeadline()
            hardReleaseAtMillis = null
            // Send the response into the engine before the synchronous unbind.
            // By the time Dart observes the Future, this stack has released it.
            result.success(null)
            releaseEngineBinding()
        }

        fun disconnectEngine() = onMain {
            if (state == State.DISPOSED) return@onMain
            if (state != State.IDLE) sendInterrupted("engine_disconnected")
            cancelDeadline()
            hardReleaseAtMillis = null
            if (generation != 0L) {
                RecorderForegroundService.cancel(generation)
                RecorderForegroundService.forget(generation)
            }
            failAll(activateResults, "Recorder engine disconnected")
            failAll(deactivateResults, "Recorder engine disconnected")
            releaseResources()
            restartRequest = null
            generation = 0
            state = State.DISPOSED
        }

        override fun onForegroundReady(generation: Long) = onMain {
            if (!isCurrent(generation) || state != State.STARTING) return@onMain
            foregroundReady = true
            maybeFinishStart()
        }

        override fun onStartFailed(generation: Long, message: String) = onMain {
            if (!isCurrent(generation)) return@onMain
            // The service has already rejected this generation or scheduled
            // its own stop. Do not let this generation cancel a different
            // engine's still-active service instance.
            failPendingActivation(message)
            state = State.STOPPING
            releaseEngineBinding()
            releaseLocks()
            scheduleDeadline(STOP_TIMEOUT_MILLIS) {
                failAll(deactivateResults, "Timed out while cleaning up recorder background support")
                finishStopped(forceReleaseEngine = true)
            }
        }

        override fun onTimedOut(generation: Long) = onMain {
            if (!isCurrent(generation) || state == State.IDLE || state == State.DISPOSED) return@onMain
            sendInterrupted("timeout")
            if (state == State.STOPPING) return@onMain
            failPendingActivation("Recording foreground service timed out")
            state = State.DRAINING
            stopObserved = false
            scheduleDrainDeadline()
        }

        override fun onStopped(generation: Long) = onMain {
            if (!isCurrent(generation) || state == State.DISPOSED) return@onMain
            RecorderForegroundService.acknowledgeStopped(generation)
            stopObserved = true
            when (state) {
                State.DRAINING -> if (deactivateResults.isNotEmpty()) finishStopped()
                State.STOPPING -> finishStopped()
                State.STARTING -> {
                    failPendingActivation("Recording foreground service stopped during startup")
                    finishStopped()
                }
                State.ACTIVE -> {
                    // An unexpected service destruction is not a Dart drain.
                    // Keep the engine and locks until setActive(false) confirms
                    // that native recording and metadata persistence finished.
                    retainEngineWhenStopped = true
                    state = State.DRAINING
                    scheduleDrainDeadline()
                    sendInterrupted("service_stopped")
                }
                else -> Unit
            }
        }

        private fun beginStart(title: String, text: String) {
            cancelDeadline()
            hardReleaseAtMillis = null
            val reuseEngineLease =
                engineBindingStarted && engineConnection != null
            state = State.STARTING
            generation = RecorderForegroundService.newGeneration()
            serviceLaunchIssued = false
            foregroundReady = false
            if (!reuseEngineLease) {
                releaseEngineBinding()
            }
            stopObserved = false
            interruptionSent = false
            retainEngineWhenStopped = false
            RecorderForegroundService.observe(generation, this)
            scheduleDeadline(START_TIMEOUT_MILLIS) {
                failStart("Timed out while starting recorder background support")
            }

            val serviceIntent = RecorderForegroundService.createStartIntent(
                context,
                generation,
                title,
                text,
            )
            try {
                context.startForegroundService(serviceIntent)
                serviceLaunchIssued = true
            } catch (exception: Exception) {
                failStartBeforeLaunch(exception.localizedMessage ?: "Foreground service startup failed")
                return
            }
            if (reuseEngineLease) {
                maybeFinishStart()
            } else {
                bindEngineLease()
            }
        }

        private fun bindEngineLease() {
            val connection = EngineConnection()
            engineConnection = connection
            engineBindingStarted = true
            val intent = Intent(context, AudioService::class.java).apply {
                action = MediaBrowserService.SERVICE_INTERFACE
            }
            try {
                if (!context.bindService(intent, connection, Context.BIND_AUTO_CREATE)) {
                    failStart("Shared recorder engine service rejected its binding")
                }
            } catch (exception: Exception) {
                failStart(exception.localizedMessage ?: "Shared recorder engine binding failed")
            }
        }

        private fun maybeFinishStart() {
            if (state != State.STARTING || !foregroundReady || !engineLeaseReady) return
            try {
                acquireLocks()
            } catch (exception: Exception) {
                failStart(exception.localizedMessage ?: "Recording resource lock acquisition failed")
                return
            }
            cancelDeadline()
            state = State.ACTIVE
            completeSuccess(activateResults)
        }

        private fun beginStop() {
            if (state != State.STARTING && state != State.ACTIVE) return
            state = State.STOPPING
            RecorderForegroundService.cancel(generation)
            scheduleDeadline(STOP_TIMEOUT_MILLIS) {
                failAll(deactivateResults, "Timed out while stopping recorder background support")
                failAll(activateResults, "Recorder restart was cancelled after a stop timeout")
                restartRequest = null
                finishStopped(forceReleaseEngine = true)
            }
        }

        private fun failStart(message: String) {
            if (state == State.DISPOSED || state == State.IDLE) return
            failPendingActivation(message)
            if (!serviceLaunchIssued) {
                finishStopped()
                return
            }
            state = State.STOPPING
            RecorderForegroundService.cancel(generation)
            releaseEngineBinding()
            releaseLocks()
            scheduleDeadline(STOP_TIMEOUT_MILLIS) {
                failAll(deactivateResults, "Timed out while cleaning up recorder background support")
                finishStopped(forceReleaseEngine = true)
            }
        }

        private fun failStartBeforeLaunch(message: String) {
            serviceLaunchIssued = false
            failPendingActivation(message)
            finishStopped()
        }

        private fun failPendingActivation(message: String) = failAll(activateResults, message)

        private fun finishStopped(forceReleaseEngine: Boolean = false) {
            cancelDeadline()
            val remainingHardReleaseMillis = hardReleaseAtMillis?.let {
                (it - SystemClock.uptimeMillis()).coerceAtLeast(0L)
            }
            val oldGeneration = generation
            if (oldGeneration != 0L) RecorderForegroundService.forget(oldGeneration)
            // The recording service and locks belong to the completed
            // generation. The engine binding becomes a short idle handoff
            // lease and is released only by releaseIdle or its hard deadline.
            releaseLocks()
            generation = 0
            serviceLaunchIssued = false
            foregroundReady = false
            stopObserved = false
            interruptionSent = false
            val restart = restartRequest
            restartRequest = null
            state = State.IDLE
            completeSuccess(deactivateResults)
            val keepEngineLease =
                !forceReleaseEngine &&
                    engineBindingStarted &&
                    engineConnection != null &&
                    (retainEngineWhenStopped || restart != null)
            retainEngineWhenStopped = false
            if (!keepEngineLease) releaseEngineBinding()
            if (restart != null && activateResults.isNotEmpty()) {
                beginStart(restart.first, restart.second)
            } else if (keepEngineLease) {
                val idleReleaseDelay = remainingHardReleaseMillis
                    ?.coerceAtMost(IDLE_RELEASE_TIMEOUT_MILLIS)
                    ?: IDLE_RELEASE_TIMEOUT_MILLIS
                scheduleDeadline(idleReleaseDelay) {
                    if (state == State.IDLE) {
                        hardReleaseAtMillis = null
                        releaseEngineBinding()
                    }
                }
            } else {
                hardReleaseAtMillis = null
            }
        }

        private fun finishDrainDeadline() {
            if (state != State.DRAINING) return
            hardReleaseAtMillis = null
            if (!stopObserved) {
                failAll(deactivateResults, "Timed out while stopping after the system limit")
            } else {
                completeSuccess(deactivateResults)
            }
            finishStopped(forceReleaseEngine = true)
        }

        private fun scheduleDrainDeadline() {
            hardReleaseAtMillis = SystemClock.uptimeMillis() + TIMEOUT_DRAIN_MILLIS
            scheduleDeadline(TIMEOUT_DRAIN_MILLIS) { finishDrainDeadline() }
        }

        private fun acquireLocks() {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "${context.packageName}:recording",
            ).apply {
                setReferenceCounted(false)
                acquire()
            }
            try {
                val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
                @Suppress("DEPRECATION")
                wifiLock = wifiManager.createWifiLock(
                    WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                    "${context.packageName}:recording",
                ).apply {
                    setReferenceCounted(false)
                    acquire()
                }
            } catch (exception: Exception) {
                releaseLocks()
                throw exception
            }
        }

        private fun releaseResources() {
            releaseEngineBinding()
            releaseLocks()
        }

        private fun releaseEngineBinding() {
            val connection = engineConnection
            engineConnection = null
            engineLeaseReady = false
            if (engineBindingStarted && connection != null) {
                connection.released = true
                try {
                    context.unbindService(connection)
                } catch (_: IllegalArgumentException) {
                    // A dead/null binding may already have been removed by Android.
                }
            }
            engineBindingStarted = false
        }

        private fun releaseLocks() {
            wifiLock?.let { if (it.isHeld) it.release() }
            wifiLock = null
            wakeLock?.let { if (it.isHeld) it.release() }
            wakeLock = null
        }

        private fun sendInterrupted(reason: String) {
            if (interruptionSent) return
            interruptionSent = true
            interrupted(reason)
        }

        private fun scheduleDeadline(delayMillis: Long, action: () -> Unit) {
            cancelDeadline()
            Runnable(action).also {
                deadline = it
                handler.postDelayed(it, delayMillis)
            }
        }

        private fun cancelDeadline() {
            deadline?.let(handler::removeCallbacks)
            deadline = null
        }

        private fun isCurrent(callbackGeneration: Long): Boolean =
            generation != 0L && callbackGeneration == generation

        private fun completeSuccess(results: ArrayDeque<MethodChannel.Result>) {
            while (results.isNotEmpty()) results.removeFirst().success(null)
        }

        private fun failAll(results: ArrayDeque<MethodChannel.Result>, message: String) {
            while (results.isNotEmpty()) results.removeFirst().unavailable(message)
        }

        private fun onMain(action: () -> Unit) {
            if (Looper.myLooper() == Looper.getMainLooper()) action() else handler.post(action)
        }

        private inner class EngineConnection : ServiceConnection {
            var released = false

            override fun onServiceConnected(name: ComponentName?, service: IBinder?) = onMain {
                if (released || engineConnection !== this) return@onMain
                engineLeaseReady = true
                if (state == State.STARTING) maybeFinishStart()
            }

            override fun onServiceDisconnected(name: ComponentName?) {
                engineConnectionLost()
            }

            override fun onBindingDied(name: ComponentName?) {
                engineConnectionLost()
            }

            override fun onNullBinding(name: ComponentName?) = onMain {
                if (released || engineConnection !== this) return@onMain
                if (state == State.IDLE) {
                    releaseEngineBinding()
                    return@onMain
                }
                failStart("Shared recorder engine service returned a null binding")
            }

            private fun engineConnectionLost() = onMain {
                if (released || engineConnection !== this || state == State.DISPOSED) return@onMain
                engineLeaseReady = false
                if (state == State.IDLE) {
                    releaseEngineBinding()
                    return@onMain
                }
                sendInterrupted("engine_disconnected")
                failPendingActivation("Shared recorder engine disconnected")
                if (state == State.DRAINING) {
                    releaseEngineBinding()
                    return@onMain
                }
                if (state != State.STOPPING) beginStop()
            }
        }
    }
}

private fun MethodChannel.Result.unavailable(message: String) {
    error("recorder_background_unavailable", sanitize(message), null)
}

private fun sanitize(message: String): String = message
    .replace(Regex("https?://\\S+", RegexOption.IGNORE_CASE), "<redacted>")
    .replace(Regex("[\\r\\n\\t]+"), " ")
    .trim()
    .ifEmpty { "Recorder background support failed" }
    .take(240)
