package dev.steenbakker.mobile_scanner

import android.app.Activity
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.Surface
import android.view.WindowManager
import dev.steenbakker.mobile_scanner.utils.serialize
import io.flutter.embedding.engine.systemchannels.PlatformChannel
import io.flutter.plugin.common.EventChannel

/**
 * This class listens to display orientation changes.
 *
 * The orientation is determined from the display rotation rather than raw sensor data.
 * This ensures that the reported orientation respects both the system rotation lock
 * and Flutter `SystemChrome.setPreferredOrientations`.
 */
class DeviceOrientationListener(
    private val activity: Activity,
) : EventChannel.StreamHandler {

    // The event sink that handles device orientation events.
    private var deviceOrientationEventSink: EventChannel.EventSink? = null

    // The last received orientation. This is used to prevent duplicate events.
    private var lastOrientation: PlatformChannel.DeviceOrientation? = null

    // Called with the new [Surface.ROTATION_*] value whenever the display rotation changes.
    var onDisplayRotationChanged: ((Int) -> Unit)? = null

    // Listener for display configuration changes.
    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) {}
        override fun onDisplayRemoved(displayId: Int) {}
        override fun onDisplayChanged(displayId: Int) {
            onDisplayRotationChanged?.invoke(getDisplay().rotation)
            sendOrientationIfChanged()
        }
    }

    override fun onListen(event: Any?, eventSink: EventChannel.EventSink?) {
        deviceOrientationEventSink = eventSink
    }

    override fun onCancel(event: Any?) {
        deviceOrientationEventSink = null
    }

    /**
     * Start listening to display orientation changes.
     */
    fun start() {
        val displayManager = activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        displayManager.registerDisplayListener(displayListener, Handler(Looper.getMainLooper()))
    }

    /**
     * Stop listening to display orientation changes.
     */
    fun stop() {
        val displayManager = activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        displayManager.unregisterDisplayListener(displayListener)
        onDisplayRotationChanged = null
    }

    @Suppress("deprecation")
    private fun getDisplay(): Display {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display?.let { return it }
        }
        return (activity.getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay
    }

    /**
     * Gets the current user interface orientation from the display.
     * This respects the system's rotation lock setting.
     */
    private fun getUIOrientation(): PlatformChannel.DeviceOrientation {
        return when (getDisplay().rotation) {
            Surface.ROTATION_0 -> PlatformChannel.DeviceOrientation.PORTRAIT_UP
            Surface.ROTATION_90 -> PlatformChannel.DeviceOrientation.LANDSCAPE_LEFT
            Surface.ROTATION_180 -> PlatformChannel.DeviceOrientation.PORTRAIT_DOWN
            Surface.ROTATION_270 -> PlatformChannel.DeviceOrientation.LANDSCAPE_RIGHT
            else -> PlatformChannel.DeviceOrientation.PORTRAIT_UP
        }
    }

    /**
     * Check the current display orientation and send an event if it changed.
     */
    private fun sendOrientationIfChanged() {
        val newOrientation = getUIOrientation()

        if (newOrientation != lastOrientation) {
            lastOrientation = newOrientation
            Handler(Looper.getMainLooper()).post {
                deviceOrientationEventSink?.success(newOrientation.serialize())
            }
        }
    }

    fun getOrientation(): PlatformChannel.DeviceOrientation {
        return lastOrientation ?: getUIOrientation()
    }
}
