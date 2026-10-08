package com.mystyle.purelive

import io.flutter.embedding.engine.plugins.FlutterPlugin

/** Keeps recording reconnect requests available while the cached engine has no Activity. */
internal class NativeHttpPlugin : FlutterPlugin {
    private var channel: NativeHttpChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = NativeHttpChannel(binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.dispose()
        channel = null
    }
}
