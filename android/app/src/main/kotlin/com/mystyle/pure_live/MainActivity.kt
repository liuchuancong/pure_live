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

// Android 13+
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher

// Android 14+
import android.window.BackEvent
import android.window.OnBackAnimationCallback

class MainActivity : AudioServiceActivity() {

    companion object {
        private const val DISPLAY_MODE_CHANNEL =
            "pure_live/display_mode"

        private const val BACKGROUND_PLAYBACK_CHANNEL =
            "pure_live/background_playback"

        private const val PREDICTIVE_BACK_CHANNEL =
            "pure_live/predictive_back"

        private var playbackWakeLock: PowerManager.WakeLock? = null
        private var playbackWifiLock: WifiManager.WifiLock? = null
    }

    // -------------------------------------------------------------------------
    // Display mode
    // -------------------------------------------------------------------------

    // Start in Android's dynamic policy. Dart raises the request only around
    // active touch/scroll/transition bursts when the user setting is enabled.
    private var highRefreshRateEnabled = false

    private var displayModeChannel: MethodChannel? = null

    private var displayListenerRegistered = false

    private var lastPublishedDisplayModeInfo: Map<String, Any>? = null

    private val mainHandler =
        Handler(Looper.getMainLooper())

    private val displayModeRefresh = Runnable {
        val info =
            applyPreferredDisplayMode(
                highRefreshRateEnabled,
            )

        if (info != lastPublishedDisplayModeInfo) {
            lastPublishedDisplayModeInfo = info

            displayModeChannel?.invokeMethod(
                "displayModeChanged",
                info,
            )
        }
    }

    private val displayListener =
        object : DisplayManager.DisplayListener {

            override fun onDisplayAdded(
                displayId: Int,
            ) = scheduleDisplayModeRefresh()

            override fun onDisplayRemoved(
                displayId: Int,
            ) = scheduleDisplayModeRefresh()

            override fun onDisplayChanged(
                displayId: Int,
            ) {
                val currentDisplayId =
                    activeDisplay()?.displayId

                if (
                    currentDisplayId == null ||
                    currentDisplayId == displayId
                ) {
                    scheduleDisplayModeRefresh()
                }
            }
        }

    // -------------------------------------------------------------------------
    // Predictive Back
    // -------------------------------------------------------------------------

    /**
     * Flutter MethodChannel.
     *
     * Android:
     *
     *   Back
     *      ↓
     *   Native Android Back API
     *      ↓
     *   pure_live/predictive_back
     *      ↓
     *   AndroidPredictiveBackService
     *      ↓
     *   LivePlayBackScope
     */
    private var predictiveBackChannel: MethodChannel? = null

    /**
     * Whether Flutter currently asks Android to intercept Back.
     *
     * true:
     *   Live player is in fullscreen / widescreen presentation.
     *
     * false:
     *   Normal room. Flutter Navigator handles Back normally.
     */
    private var predictiveBackEnabled = false

    /**
     * Whether the Android 13+ callback is currently registered.
     */
    private var predictiveBackRegistered = false

    /**
     * Android 13+ normal Back callback.
     *
     * Used on Android 13.
     *
     * Android 14+ uses OnBackAnimationCallback instead so that predictive
     * gesture progress can be forwarded to Flutter.
     */
    private val predictiveBackCallback =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            @Suppress("NewApi")
            OnBackInvokedCallback {
                handlePredictiveBackInvoked()
            }
        } else {
            null
        }

    /**
     * Android 14+ predictive Back callback.
     *
     * Android 14 introduced the animation callbacks:
     *
     *   onBackStarted()
     *   onBackProgressed()
     *   onBackCancelled()
     *   onBackInvoked()
     *
     * We forward all four events to Flutter.
     */
    @Suppress("NewApi")
    private val predictiveBackAnimationCallback =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            object : OnBackAnimationCallback {

                override fun onBackStarted(
                    backEvent: BackEvent,
                ) {
                    predictiveBackChannel?.invokeMethod(
                        "backStarted",
                        mapOf(
                            "progress" to 0.0,
                            "swipeEdge" to backEvent.swipeEdge,
                            "touchX" to backEvent.touchX.toDouble(),
                            "touchY" to backEvent.touchY.toDouble(),
                        ),
                    )
                }

                override fun onBackProgressed(
                    backEvent: BackEvent,
                ) {
                    predictiveBackChannel?.invokeMethod(
                        "backProgress",
                        mapOf(
                            "progress" to
                                backEvent.progress.toDouble(),
                            "swipeEdge" to
                                backEvent.swipeEdge,
                            "touchX" to
                                backEvent.touchX.toDouble(),
                            "touchY" to
                                backEvent.touchY.toDouble(),
                        ),
                    )
                }

                override fun onBackCancelled() {
                    predictiveBackChannel?.invokeMethod(
                        "backCancelled",
                        null,
                    )
                }

                override fun onBackInvoked() {
                    handlePredictiveBackInvoked()
                }
            }
        } else {
            null
        }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine,
    ) {
        super.configureFlutterEngine(
            flutterEngine,
        )

        // ---------------------------------------------------------------------
        // Display mode channel
        // ---------------------------------------------------------------------

        displayModeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DISPLAY_MODE_CHANNEL,
        ).also { channel ->

            channel.setMethodCallHandler { call, result ->

                when (call.method) {

                    "setHighRefreshRate" -> {
                        highRefreshRateEnabled =
                            call.argument<Boolean>(
                                "enabled",
                            ) ?: true

                        val info =
                            applyPreferredDisplayMode(
                                highRefreshRateEnabled,
                            )

                        lastPublishedDisplayModeInfo =
                            info

                        result.success(info)
                    }

                    "getDisplayModeInfo" -> {
                        result.success(
                            displayModeInfo(),
                        )
                    }

                    else -> result.notImplemented()
                }
            }
        }

        // ---------------------------------------------------------------------
        // Background playback
        // ---------------------------------------------------------------------

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BACKGROUND_PLAYBACK_CHANNEL,
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "setKeepAlive" -> {
                    setPlaybackKeepAlive(
                        call.argument<Boolean>(
                            "enabled",
                        ) ?: false,
                    )

                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        // ---------------------------------------------------------------------
        // Predictive Back
        // ---------------------------------------------------------------------

        predictiveBackChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PREDICTIVE_BACK_CHANNEL,
        ).also { channel ->

            channel.setMethodCallHandler { call, result ->

                when (call.method) {

                    /**
                     * Flutter controls whether this Activity should intercept
                     * Android Back.
                     *
                     * enabled = true:
                     *   fullscreen / widescreen presentation
                     *
                     * enabled = false:
                     *   normal room
                     */
                    "setEnabled" -> {
                        val enabled =
                            call.argument<Boolean>(
                                "enabled",
                            ) ?: false

                        setPredictiveBackEnabled(
                            enabled,
                        )

                        result.success(null)
                    }

                    "isEnabled" -> {
                        result.success(
                            predictiveBackEnabled,
                        )
                    }

                    else -> result.notImplemented()
                }
            }
        }

        // ---------------------------------------------------------------------
        // Initial display state
        // ---------------------------------------------------------------------

        applyPreferredDisplayMode(
            highRefreshRateEnabled,
        )
    }

    /**
     * Called when Android Back has been committed.
     *
     * This can be:
     *
     * - Android physical Back key
     * - Android system Back
     * - Android 13 Back
     * - Android 14+ predictive Back gesture
     *
     * We do NOT finish the Activity here.
     *
     * Flutter decides what to do.
     *
     * Native Back
     *     ↓
     * MethodChannel
     *     ↓
     * AndroidPredictiveBackService
     *     ↓
     * LivePlayBackScope
     *     ↓
     * exitPresentationForSystemBack()
     */
    private fun handlePredictiveBackInvoked() {

        if (!predictiveBackEnabled) {
            return
        }

        predictiveBackChannel?.invokeMethod(
            "backInvoked",
            null,
        )
    }

    /**
     * Enables or disables Android Back interception.
     *
     * Android 6 ~ 12:
     *
     *   Activity.onBackPressed()
     *
     * Android 13:
     *
     *   OnBackInvokedCallback
     *
     * Android 14+:
     *
     *   OnBackAnimationCallback
     */
    private fun setPredictiveBackEnabled(
        enabled: Boolean,
    ) {

        if (predictiveBackEnabled == enabled) {
            return
        }

        predictiveBackEnabled = enabled

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {

            if (enabled) {
                registerPredictiveBack()
            } else {
                unregisterPredictiveBack()
            }
        }
    }

    /**
     * Registers Android 13+ Back callbacks.
     */
    @Suppress("NewApi")
    private fun registerPredictiveBack() {

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return
        }

        if (predictiveBackRegistered) {
            return
        }

        val callback =
            if (
                Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.UPSIDE_DOWN_CAKE
            ) {
                predictiveBackAnimationCallback
            } else {
                predictiveBackCallback
            }

        if (callback == null) {
            return
        }

        onBackInvokedDispatcher.registerOnBackInvokedCallback(
            OnBackInvokedDispatcher.PRIORITY_DEFAULT,
            callback,
        )

        predictiveBackRegistered = true
    }

    /**
     * Unregisters Android 13+ Back callbacks.
     */
    @Suppress("NewApi")
    private fun unregisterPredictiveBack() {

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return
        }

        if (!predictiveBackRegistered) {
            return
        }

        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.UPSIDE_DOWN_CAKE
        ) {
            predictiveBackAnimationCallback?.let {
                onBackInvokedDispatcher
                    .unregisterOnBackInvokedCallback(it)
            }
        } else {
            predictiveBackCallback?.let {
                onBackInvokedDispatcher
                    .unregisterOnBackInvokedCallback(it)
            }
        }

        predictiveBackRegistered = false
    }

    /**
     * Android 6 ~ 12 Back support.
     *
     * IMPORTANT:
     *
     * Do not use OnBackPressedDispatcher here because MainActivity extends
     * AudioServiceActivity, not ComponentActivity.
     *
     * When interception is disabled, super.onBackPressed() is called so
     * Flutter receives the normal Back event.
     *
     * When interception is enabled, the event is forwarded to Flutter
     * through MethodChannel and the Activity is NOT finished.
     */
    @Suppress("DEPRECATION")
    override fun onBackPressed() {

        if (
            Build.VERSION.SDK_INT <
            Build.VERSION_CODES.TIRAMISU
        ) {
            if (predictiveBackEnabled) {
                handlePredictiveBackInvoked()
                return
            }
        }

        super.onBackPressed()
    }

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    override fun onStart() {
        super.onStart()

        registerDisplayListener()

        scheduleDisplayModeRefresh(
            delayMillis = 0,
        )
    }

    @Suppress("DEPRECATION")
    private fun setPlaybackKeepAlive(
        enabled: Boolean,
    ) {

        if (enabled) {

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

    override fun onResume() {
        super.onResume()

        scheduleDisplayModeRefresh(
            delayMillis = 0,
        )

        /**
         * Activity resumed.
         *
         * Android 13+ needs the native callback registered again if the
         * Activity lifecycle recreated or the callback was previously
         * unregistered.
         */
        if (
            predictiveBackEnabled &&
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.TIRAMISU
        ) {
            registerPredictiveBack()
        }
    }

    override fun onStop() {

        unregisterDisplayListener()

        /**
         * Native Android 13+ callback is not kept while Activity is stopped.
         *
         * predictiveBackEnabled itself remains true so it can be restored
         * when the Activity resumes.
         */
        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.TIRAMISU
        ) {
            unregisterPredictiveBack()
        }

        super.onStop()
    }

    override fun onDestroy() {

        mainHandler.removeCallbacks(
            displayModeRefresh,
        )

        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.TIRAMISU
        ) {
            unregisterPredictiveBack()
        }

        displayModeChannel = null
        predictiveBackChannel = null

        super.onDestroy()
    }

    // -------------------------------------------------------------------------
    // Display listener
    // -------------------------------------------------------------------------

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

    // -------------------------------------------------------------------------
    // Display
    // -------------------------------------------------------------------------

    @Suppress("DEPRECATION")
    private fun activeDisplay(): Display? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            windowManager.defaultDisplay
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

        // Android recommends preferredRefreshRate when only the refresh rate
        // should change. Pinning preferredDisplayModeId as well can force a
        // heavy vendor mode transition and leaves less room for the scheduler
        // to reconcile Flutter, video and PiP surfaces.
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
            kotlin.math.abs(
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
                "supportedRefreshRates" to listOf(60.0),
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
                    kotlin.math.round(
                        it * 100,
                    ).toInt()
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
            "maxRefreshRate" to (
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
                window.attributes.preferredRefreshRate.toDouble(),
        )
    }
}