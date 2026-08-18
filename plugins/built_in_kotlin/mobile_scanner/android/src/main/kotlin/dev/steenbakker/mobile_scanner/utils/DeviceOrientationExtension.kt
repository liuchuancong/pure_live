package dev.steenbakker.mobile_scanner.utils

import io.flutter.embedding.engine.systemchannels.PlatformChannel

/**
 * This function serializes a device orientation to a string,
 * for sending back over a method or event channel.
 */
fun PlatformChannel.DeviceOrientation.serialize(): String {
    return when(this) {
        PlatformChannel.DeviceOrientation.PORTRAIT_UP -> "PORTRAIT_UP"
        PlatformChannel.DeviceOrientation.PORTRAIT_DOWN -> "PORTRAIT_DOWN"
        PlatformChannel.DeviceOrientation.LANDSCAPE_LEFT -> "LANDSCAPE_LEFT"
        PlatformChannel.DeviceOrientation.LANDSCAPE_RIGHT -> "LANDSCAPE_RIGHT"
    }
}