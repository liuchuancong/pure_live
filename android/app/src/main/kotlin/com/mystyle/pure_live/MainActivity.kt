package com.mystyle.purelive

import android.os.Build
import android.view.Display
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val DISPLAY_MODE_CHANNEL = "pure_live/display_mode"
    }

    private var highRefreshRateEnabled = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DISPLAY_MODE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setHighRefreshRate" -> {
                    highRefreshRateEnabled = call.argument<Boolean>("enabled") ?: true
                    result.success(applyPreferredDisplayMode(highRefreshRateEnabled))
                }

                "getDisplayModeInfo" -> result.success(displayModeInfo())
                else -> result.notImplemented()
            }
        }
        applyPreferredDisplayMode(highRefreshRateEnabled)
    }

    override fun onResume() {
        super.onResume()
        applyPreferredDisplayMode(highRefreshRateEnabled)
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
        val targetModeId = if (enabled) preferredMode.modeId else 0
        if (attributes.preferredDisplayModeId != targetModeId) {
            attributes.preferredDisplayModeId = targetModeId
            window.attributes = attributes
        }
        return displayModeInfo(preferredMode)
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
            "preferredDisplayModeId" to window.attributes.preferredDisplayModeId,
        )
    }
}
