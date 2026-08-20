package com.mystyle.purelive

import android.content.Context
import android.hardware.display.DisplayManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.view.Display
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val DISPLAY_MODE_CHANNEL = "pure_live/display_mode"
        private const val BACKGROUND_PLAYBACK_CHANNEL = "pure_live/background_playback"
        private var playbackWakeLock: PowerManager.WakeLock? = null
        private var playbackWifiLock: WifiManager.WifiLock? = null
    }

    private var highRefreshRateEnabled = true
    private var displayModeChannel: MethodChannel? = null
    private var displayListenerRegistered = false
    private var lastPublishedDisplayModeInfo: Map<String, Any>? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val displayModeRefresh = Runnable {
        val info = applyPreferredDisplayMode(highRefreshRateEnabled)
        if (info != lastPublishedDisplayModeInfo) {
            lastPublishedDisplayModeInfo = info
            displayModeChannel?.invokeMethod("displayModeChanged", info)
        }
    }
    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = scheduleDisplayModeRefresh()

        override fun onDisplayRemoved(displayId: Int) = scheduleDisplayModeRefresh()

        override fun onDisplayChanged(displayId: Int) {
            val currentDisplayId = activeDisplay()?.displayId
            if (currentDisplayId == null || currentDisplayId == displayId) {
                scheduleDisplayModeRefresh()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        displayModeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DISPLAY_MODE_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setHighRefreshRate" -> {
                        highRefreshRateEnabled = call.argument<Boolean>("enabled") ?: true
                        val info = applyPreferredDisplayMode(highRefreshRateEnabled)
                        lastPublishedDisplayModeInfo = info
                        result.success(info)
                    }

                    "getDisplayModeInfo" -> result.success(displayModeInfo())
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BACKGROUND_PLAYBACK_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setKeepAlive" -> {
                    setPlaybackKeepAlive(call.argument<Boolean>("enabled") ?: false)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        applyPreferredDisplayMode(highRefreshRateEnabled)
    }

    override fun onStart() {
        super.onStart()
        registerDisplayListener()
        scheduleDisplayModeRefresh(delayMillis = 0)
    }

    @Suppress("DEPRECATION")
    private fun setPlaybackKeepAlive(enabled: Boolean) {
        if (enabled) {
            if (playbackWakeLock == null) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                playbackWakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "$packageName:backgroundPlayback",
                ).apply { setReferenceCounted(false) }
            }
            if (playbackWakeLock?.isHeld != true) playbackWakeLock?.acquire()

            if (playbackWifiLock == null) {
                val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    WifiManager.WIFI_MODE_FULL_LOW_LATENCY
                } else {
                    WifiManager.WIFI_MODE_FULL_HIGH_PERF
                }
                playbackWifiLock = wifiManager.createWifiLock(mode, "$packageName:backgroundPlayback").apply {
                    setReferenceCounted(false)
                }
            }
            if (playbackWifiLock?.isHeld != true) playbackWifiLock?.acquire()
        } else {
            if (playbackWifiLock?.isHeld == true) playbackWifiLock?.release()
            if (playbackWakeLock?.isHeld == true) playbackWakeLock?.release()
        }
    }

    override fun onResume() {
        super.onResume()
        scheduleDisplayModeRefresh(delayMillis = 0)
    }

    override fun onStop() {
        unregisterDisplayListener()
        super.onStop()
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(displayModeRefresh)
        displayModeChannel = null
        super.onDestroy()
    }

    private fun registerDisplayListener() {
        if (displayListenerRegistered) return
        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        displayManager.registerDisplayListener(displayListener, mainHandler)
        displayListenerRegistered = true
    }

    private fun unregisterDisplayListener() {
        if (!displayListenerRegistered) return
        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        displayManager.unregisterDisplayListener(displayListener)
        displayListenerRegistered = false
        mainHandler.removeCallbacks(displayModeRefresh)
    }

    private fun scheduleDisplayModeRefresh(delayMillis: Long = 160) {
        mainHandler.removeCallbacks(displayModeRefresh)
        mainHandler.postDelayed(displayModeRefresh, delayMillis)
    }

    @Suppress("DEPRECATION")
    private fun activeDisplay(): Display? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay

    private fun applyPreferredDisplayMode(enabled: Boolean): Map<String, Any> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return displayModeInfo()
        val activeDisplay = activeDisplay() ?: return displayModeInfo()
        val currentMode = activeDisplay.mode
        val compatibleModes = activeDisplay.supportedModes.filter {
            it.physicalWidth == currentMode.physicalWidth &&
                it.physicalHeight == currentMode.physicalHeight
        }
        val preferredMode = compatibleModes.maxWithOrNull(
            compareBy<Display.Mode> { it.refreshRate }.thenBy { it.modeId },
        ) ?: currentMode

        val attributes = window.attributes
        // Android recommends preferredRefreshRate when only the refresh rate
        // should change. Pinning preferredDisplayModeId as well can force a
        // heavy vendor mode transition and leaves less room for the scheduler
        // to reconcile Flutter, video and PiP surfaces.
        val targetModeId = 0
        val targetRefreshRate = if (enabled) preferredMode.refreshRate else 0f
        if (
            attributes.preferredDisplayModeId != targetModeId ||
            kotlin.math.abs(attributes.preferredRefreshRate - targetRefreshRate) > 0.01f
        ) {
            attributes.preferredDisplayModeId = targetModeId
            attributes.preferredRefreshRate = targetRefreshRate
            window.attributes = attributes
        }
        return displayModeInfo(if (enabled) preferredMode else currentMode)
    }

    private fun displayModeInfo(preferredMode: Display.Mode? = null): Map<String, Any> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return mapOf(
                "enabled" to highRefreshRateEnabled,
                "currentRefreshRate" to 60.0,
                "maxRefreshRate" to 60.0,
                "preferredRefreshRate" to 60.0,
                "supportedRefreshRates" to listOf(60.0),
            )
        }

        val activeDisplay = activeDisplay()
            ?: return mapOf("enabled" to highRefreshRateEnabled)
        val currentMode = activeDisplay.mode
        val compatibleModes = activeDisplay.supportedModes.filter {
            it.physicalWidth == currentMode.physicalWidth &&
                it.physicalHeight == currentMode.physicalHeight
        }
        val rates = compatibleModes
            .map { it.refreshRate.toDouble() }
            .distinctBy { kotlin.math.round(it * 100).toInt() }
            .sorted()
        val bestMode = preferredMode ?: compatibleModes.maxByOrNull { it.refreshRate } ?: currentMode

        return mapOf(
            "enabled" to highRefreshRateEnabled,
            "currentRefreshRate" to currentMode.refreshRate.toDouble(),
            "maxRefreshRate" to (rates.maxOrNull() ?: currentMode.refreshRate.toDouble()),
            "preferredRefreshRate" to bestMode.refreshRate.toDouble(),
            "supportedRefreshRates" to rates,
            "width" to currentMode.physicalWidth,
            "height" to currentMode.physicalHeight,
            "displayId" to activeDisplay.displayId,
            "preferredDisplayModeId" to window.attributes.preferredDisplayModeId,
            "requestedRefreshRate" to window.attributes.preferredRefreshRate.toDouble(),
        )
    }
}
