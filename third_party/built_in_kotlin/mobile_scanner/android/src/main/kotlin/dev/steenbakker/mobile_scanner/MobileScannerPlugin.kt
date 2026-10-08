package dev.steenbakker.mobile_scanner

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/** MobileScannerPlugin */
class MobileScannerPlugin : FlutterPlugin, ActivityAware {
    private var activityPluginBinding: ActivityPluginBinding? = null
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var methodCallHandler: MobileScannerHandler? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        this.flutterPluginBinding = binding
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        this.flutterPluginBinding = null
    }

    override fun onAttachedToActivity(activityPluginBinding: ActivityPluginBinding) {
        val binaryMessenger = this.flutterPluginBinding!!.binaryMessenger

        methodCallHandler = MobileScannerHandler(
            activityPluginBinding.activity,
            BarcodeHandler(binaryMessenger),
            binaryMessenger,
            MobileScannerPermissions(),
            activityPluginBinding::addRequestPermissionsResultListener,
            this.flutterPluginBinding!!.textureRegistry,
        )

        this.activityPluginBinding = activityPluginBinding
    }

    override fun onDetachedFromActivity() {
        methodCallHandler?.dispose(this.activityPluginBinding!!)
        methodCallHandler = null
        activityPluginBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }
}
