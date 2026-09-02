package com.mystyle.purelive

import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.view.Display
import android.window.BackEvent
import android.window.OnBackAnimationCallback
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.round

class MainActivity : AudioServiceActivity() {

    companion object {
        private const val DISPLAY_MODE_CHANNEL = "pure_live/display_mode"
        private const val BACKGROUND_PLAYBACK_CHANNEL =
            "pure_live/background_playback"
        private const val RECORDING_KEEP_ALIVE_CHANNEL =
            "pure_live/recording_keep_alive"
        private const val SYSTEM_BACK_CHANNEL =
            "pure_live/system_back"

        private var playbackWakeLock: PowerManager.WakeLock? = null
        private var playbackWifiLock: WifiManager.WifiLock? = null
    }

    // ============================================================
    // High refresh rate
    // ============================================================

    private var highRefreshRateEnabled = false

    private var displayModeChannel: MethodChannel? = null

    private var displayListenerRegistered = false

    private var lastPublishedDisplayModeInfo: Map<String, Any>? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    private val displayModeRefresh = Runnable {
        val info = applyPreferredDisplayMode(highRefreshRateEnabled)

        if (info != lastPublishedDisplayModeInfo) {
            lastPublishedDisplayModeInfo = info
            displayModeChannel?.invokeMethod(
                "displayModeChanged",
                info,
            )
        }
    }

    private val displayListener = object : DisplayManager.DisplayListener {

        override fun onDisplayAdded(displayId: Int) {
            scheduleDisplayModeRefresh()
        }

        override fun onDisplayRemoved(displayId: Int) {
            scheduleDisplayModeRefresh()
        }

        override fun onDisplayChanged(displayId: Int) {
            val currentDisplayId = activeDisplay()?.displayId

            if (
                currentDisplayId == null ||
                currentDisplayId == displayId
            ) {
                scheduleDisplayModeRefresh()
            }
        }
    }

    // ============================================================
    // System Back
    //
    // Android 6~12:
    //     Activity.onBackPressed()
    //
    // Android 13:
    //     OnBackInvokedCallback
    //
    // Android 14+:
    //     OnBackAnimationCallback
    // ============================================================

    private var systemBackChannel: MethodChannel? = null

    /**
     * Whether Dart currently owns the system Back.
     *
     * This is intentionally NOT limited to Android 13+.
     *
     * Android 6~12 uses onBackPressed().
     * Android 13+ additionally registers OnBackInvokedDispatcher.
     */
    private var systemBackEnabled = false

    /**
     * Whether the Android 13+ callback has actually been registered.
     */
    private var systemBackRegistered = false

    /**
     * Android 13+ callback.
     */
    private val systemBackCallback =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            @Suppress("NewApi")
            OnBackInvokedCallback {
                dispatchSystemBack()
            }
        } else {
            null
        }

    /**
     * Android 14+ predictive back animation callback.
     */
    @Suppress("NewApi")
    private val systemBackAnimationCallback =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            object : OnBackAnimationCallback {

                override fun onBackStarted(
                    backEvent: BackEvent,
                ) {
                    systemBackChannel?.invokeMethod(
                        "backStarted",
                        null,
                    )
                }

                override fun onBackProgressed(
                    backEvent: BackEvent,
                ) {
                    systemBackChannel?.invokeMethod(
                        "backProgress",
                        mapOf(
                            "progress" to
                                backEvent.progress.toDouble(),
                        ),
                    )
                }

                override fun onBackCancelled() {
                    systemBackChannel?.invokeMethod(
                        "backCancelled",
                        null,
                    )
                }

                override fun onBackInvoked() {
                    dispatchSystemBack()
                }
            }
        } else {
            null
        }

    // ============================================================
    // Flutter Engine
    // ============================================================

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine,
    ) {
        super.configureFlutterEngine(flutterEngine)

        // ========================================================
        // Display mode / refresh rate
        // ========================================================

        displayModeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DISPLAY_MODE_CHANNEL,
        ).also { channel ->

            channel.setMethodCallHandler { call, result ->

                when (call.method) {

                    "setHighRefreshRate" -> {
                        highRefreshRateEnabled =
                            call.argument<Boolean>("enabled")
                                ?: true

                        val info =
                            applyPreferredDisplayMode(
                                highRefreshRateEnabled,
                            )

                        lastPublishedDisplayModeInfo = info

                        result.success(info)
                    }

                    "getDisplayModeInfo" -> {
                        result.success(
                            displayModeInfo(),
                        )
                    }

                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }

        // ========================================================
        // Background playback KeepAlive
        // ========================================================

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BACKGROUND_PLAYBACK_CHANNEL,
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "setKeepAlive" -> {
                    setPlaybackKeepAlive(
                        call.argument<Boolean>("enabled")
                            ?: false,
                    )

                    result.success(null)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        // ========================================================
        // Recording Foreground Service
        // ========================================================

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RECORDING_KEEP_ALIVE_CHANNEL,
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "start" -> {
                    startRecordingForegroundService()
                    result.success(null)
                }

                "stop" -> {
                    stopRecordingForegroundService()
                    result.success(null)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        // ========================================================
        // System Back
        // ========================================================

        systemBackChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYSTEM_BACK_CHANNEL,
        ).also { channel ->

            channel.setMethodCallHandler { call, result ->

                when (call.method) {

                    "setEnabled" -> {
                        val enabled =
                            call.argument<Boolean>("enabled")
                                ?: false

                        setSystemBackEnabled(enabled)

                        result.success(null)
                    }

                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }

        applyPreferredDisplayMode(
            highRefreshRateEnabled,
        )
    }

    // ============================================================
    // System Back
    // ============================================================

    /**
     * Sends Back to Dart.
     *
     * This is shared by:
     *
     * Android 6~12 -> onBackPressed()
     * Android 13+  -> OnBackInvokedCallback
     */
    private fun dispatchSystemBack() {
        if (!systemBackEnabled) {
            return
        }

        systemBackChannel?.invokeMethod(
            "backInvoked",
            null,
        )
    }

    /**
     * Enables/disables Dart ownership of system Back.
     *
     * Important:
     * Android 6~12 also uses this flag.
     */
    private fun setSystemBackEnabled(
        enabled: Boolean,
    ) {
        systemBackEnabled = enabled

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (enabled) {
                registerSystemBack()
            } else {
                unregisterSystemBack()
            }
        }
    }

    /**
     * Register Android 13+ system Back callback.
     */
    @Suppress("NewApi")
    private fun registerSystemBack() {

        if (
            Build.VERSION.SDK_INT <
                Build.VERSION_CODES.TIRAMISU
        ) {
            return
        }

        if (systemBackRegistered) {
            return
        }

        val callback =
            if (
                Build.VERSION.SDK_INT >=
                    Build.VERSION_CODES.UPSIDE_DOWN_CAKE
            ) {
                systemBackAnimationCallback
            } else {
                systemBackCallback
            }

        if (callback == null) {
            return
        }

        onBackInvokedDispatcher.registerOnBackInvokedCallback(
            OnBackInvokedDispatcher.PRIORITY_OVERLAY,
            callback,
        )

        systemBackRegistered = true
    }

    /**
     * Unregister Android 13+ system Back callback.
     */
    @Suppress("NewApi")
    private fun unregisterSystemBack() {

        if (
            Build.VERSION.SDK_INT <
                Build.VERSION_CODES.TIRAMISU
        ) {
            return
        }

        if (!systemBackRegistered) {
            return
        }

        if (
            Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.UPSIDE_DOWN_CAKE
        ) {
            systemBackAnimationCallback?.let {
                onBackInvokedDispatcher
                    .unregisterOnBackInvokedCallback(it)
            }
        } else {
            systemBackCallback?.let {
                onBackInvokedDispatcher
                    .unregisterOnBackInvokedCallback(it)
            }
        }

        systemBackRegistered = false
    }

    /**
     * Android 6~12 fallback.
     *
     * This is the important part for Android 6+ support.
     */
    @Suppress("DEPRECATION")
    override fun onBackPressed() {

        if (systemBackEnabled) {
            dispatchSystemBack()
            return
        }

        super.onBackPressed()
    }

    // ============================================================
    // Lifecycle
    // ============================================================

    override fun onStart() {
        super.onStart()

        registerDisplayListener()

        scheduleDisplayModeRefresh(
            delayMillis = 0,
        )
    }

    override fun onResume() {
        super.onResume()

        scheduleDisplayModeRefresh(
            delayMillis = 0,
        )

        if (
            systemBackEnabled &&
            Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.TIRAMISU
        ) {
            registerSystemBack()
        }
    }

    override fun onStop() {

        unregisterDisplayListener()

        if (
            Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.TIRAMISU
        ) {
            unregisterSystemBack()
        }

        super.onStop()
    }

    override fun onDestroy() {

        mainHandler.removeCallbacks(
            displayModeRefresh,
        )

        displayModeChannel = null

        if (
            Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.TIRAMISU
        ) {
            unregisterSystemBack()
        }

        systemBackChannel = null

        super.onDestroy()
    }

    // ============================================================
    // Background Playback KeepAlive
    // ============================================================

    @Suppress("DEPRECATION")
    private fun setPlaybackKeepAlive(
        enabled: Boolean,
    ) {

        if (enabled) {

            // ----------------------------------------------------
            // WakeLock
            // ----------------------------------------------------

            if (playbackWakeLock == null) {

                val powerManager =
                    getSystemService(
                        Context.POWER_SERVICE,
                    ) as PowerManager

                playbackWakeLock =
                    powerManager.newWakeLock(
                        PowerManager.PARTIAL_WAKE_LOCK,
                        "$packageName:backgroundPlayback",
                    ).apply {
                        setReferenceCounted(false)
                    }
            }

            if (playbackWakeLock?.isHeld != true) {
                playbackWakeLock?.acquire()
            }

            // ----------------------------------------------------
            // WifiLock
            // ----------------------------------------------------

            if (playbackWifiLock == null) {

                val wifiManager =
                    applicationContext.getSystemService(
                        Context.WIFI_SERVICE,
                    ) as WifiManager

                val mode =
                    if (
                        Build.VERSION.SDK_INT >=
                            Build.VERSION_CODES.Q
                    ) {
                        WifiManager.WIFI_MODE_FULL_LOW_LATENCY
                    } else {
                        WifiManager.WIFI_MODE_FULL_HIGH_PERF
                    }

                playbackWifiLock =
                    wifiManager.createWifiLock(
                        mode,
                        "$packageName:backgroundPlayback",
                    ).apply {
                        setReferenceCounted(false)
                    }
            }

            if (playbackWifiLock?.isHeld != true) {
                playbackWifiLock?.acquire()
            }

        } else {

            if (playbackWifiLock?.isHeld == true) {
                playbackWifiLock?.release()
            }

            if (playbackWakeLock?.isHeld == true) {
                playbackWakeLock?.release()
            }
        }
    }

    // ============================================================
    // Recording Foreground Service
    // ============================================================

    private fun startRecordingForegroundService() {

        val intent = Intent(
            this,
            RecordingForegroundService::class.java,
        )

        ContextCompat.startForegroundService(
            this,
            intent,
        )
    }

    private fun stopRecordingForegroundService() {

        val intent = Intent(
            this,
            RecordingForegroundService::class.java,
        )

        stopService(intent)
    }

    // ============================================================
    // Display Listener
    // ============================================================

    private fun registerDisplayListener() {

        if (displayListenerRegistered) {
            return
        }

        val displayManager =
            getSystemService(
                Context.DISPLAY_SERVICE,
            ) as DisplayManager

        displayManager.registerDisplayListener(
            displayListener,
            mainHandler,
        )

        displayListenerRegistered = true
    }

    private fun unregisterDisplayListener() {

        if (!displayListenerRegistered) {
            return
        }

        val displayManager =
            getSystemService(
                Context.DISPLAY_SERVICE,
            ) as DisplayManager

        displayManager.unregisterDisplayListener(
            displayListener,
        )

        displayListenerRegistered = false

        mainHandler.removeCallbacks(
            displayModeRefresh,
        )
    }

    private fun scheduleDisplayModeRefresh(
        delayMillis: Long = 160,
    ) {

        mainHandler.removeCallbacks(
            displayModeRefresh,
        )

        mainHandler.postDelayed(
            displayModeRefresh,
            delayMillis,
        )
    }

    // ============================================================
    // Display Mode
    // ============================================================

    @Suppress("DEPRECATION")
    private fun activeDisplay(): Display? {

        return if (
            Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.R
        ) {
            display
        } else {
            windowManager.defaultDisplay
        }
    }

    private fun applyPreferredDisplayMode(
        enabled: Boolean,
    ): Map<String, Any> {

        if (
            Build.VERSION.SDK_INT <
                Build.VERSION_CODES.M
        ) {
            return displayModeInfo()
        }

        val activeDisplay =
            activeDisplay()
                ?: return displayModeInfo()

        val currentMode =
            activeDisplay.mode

        val compatibleModes =
            activeDisplay.supportedModes.filter {

                it.physicalWidth ==
                    currentMode.physicalWidth &&
                    it.physicalHeight ==
                    currentMode.physicalHeight
            }

        val preferredMode =
            compatibleModes.maxWithOrNull(
                compareBy<Display.Mode> {
                    it.refreshRate
                }.thenBy {
                    it.modeId
                },
            ) ?: currentMode

        val attributes =
            window.attributes

        /*
         * Android recommends preferredRefreshRate when
         * only the refresh rate should change.
         *
         * Do not pin preferredDisplayModeId because some
         * vendor devices can perform heavy mode transitions.
         */
        val targetModeId = 0

        val targetRefreshRate =
            if (enabled) {
                preferredMode.refreshRate
            } else {
                0f
            }

        if (
            attributes.preferredDisplayModeId !=
                targetModeId ||
                abs(
                    attributes.preferredRefreshRate -
                        targetRefreshRate,
                ) > 0.01f
        ) {

            attributes.preferredDisplayModeId =
                targetModeId

            attributes.preferredRefreshRate =
                targetRefreshRate

            window.attributes =
                attributes
        }

        return displayModeInfo(
            if (enabled) {
                preferredMode
            } else {
                currentMode
            },
        )
    }

    private fun displayModeInfo(
        preferredMode: Display.Mode? = null,
    ): Map<String, Any> {

        if (
            Build.VERSION.SDK_INT <
                Build.VERSION_CODES.M
        ) {
            return mapOf(
                "enabled" to highRefreshRateEnabled,
                "currentRefreshRate" to 60.0,
                "maxRefreshRate" to 60.0,
                "preferredRefreshRate" to 60.0,
                "supportedRefreshRates" to listOf(
                    60.0,
                ),
            )
        }

        val activeDisplay =
            activeDisplay()
                ?: return mapOf(
                    "enabled" to highRefreshRateEnabled,
                )

        val currentMode =
            activeDisplay.mode

        val compatibleModes =
            activeDisplay.supportedModes.filter {

                it.physicalWidth ==
                    currentMode.physicalWidth &&
                    it.physicalHeight ==
                    currentMode.physicalHeight
            }

        val rates =
            compatibleModes
                .map {
                    it.refreshRate.toDouble()
                }
                .distinctBy {
                    round(it * 100).toInt()
                }
                .sorted()

        val bestMode =
            preferredMode
                ?: compatibleModes.maxByOrNull {
                    it.refreshRate
                }
                ?: currentMode

        return mapOf(
            "enabled" to highRefreshRateEnabled,
            "currentRefreshRate" to
                currentMode.refreshRate.toDouble(),
            "maxRefreshRate" to
                (
                    rates.maxOrNull()
                        ?: currentMode.refreshRate.toDouble()
                ),
            "preferredRefreshRate" to
                bestMode.refreshRate.toDouble(),
            "supportedRefreshRates" to rates,
            "width" to currentMode.physicalWidth,
            "height" to currentMode.physicalHeight,
            "displayId" to activeDisplay.displayId,
            "preferredDisplayModeId" to
                window.attributes.preferredDisplayModeId,
            "requestedRefreshRate" to
                window.attributes.preferredRefreshRate
                    .toDouble(),
        )
    }
}
