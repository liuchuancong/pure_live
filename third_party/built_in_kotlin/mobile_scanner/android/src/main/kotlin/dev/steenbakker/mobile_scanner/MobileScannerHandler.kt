package dev.steenbakker.mobile_scanner

import android.app.Activity
import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Size
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ExperimentalLensFacing
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import dev.steenbakker.mobile_scanner.objects.BarcodeFormats
import dev.steenbakker.mobile_scanner.objects.DetectionSpeed
import dev.steenbakker.mobile_scanner.objects.MobileScannerErrorCodes
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.view.TextureRegistry
import java.io.File
import com.google.mlkit.vision.barcode.ZoomSuggestionOptions

class MobileScannerHandler(
    private val activity: Activity,
    private val barcodeHandler: BarcodeHandler,
    binaryMessenger: BinaryMessenger,
    private val permissions: MobileScannerPermissions,
    private val addPermissionListener: (RequestPermissionsResultListener) -> Unit,
    textureRegistry: TextureRegistry): MethodChannel.MethodCallHandler {

    /**
     * Cached CameraManager instance to avoid repeated system service lookups.
     */
    private val cameraManager: CameraManager by lazy {
        activity.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    }

    private val analyzeImageErrorCallback: AnalyzerErrorCallback = {
        Handler(Looper.getMainLooper()).post {
            analyzerResult?.error(MobileScannerErrorCodes.BARCODE_ERROR, it, null)
            analyzerResult = null
        }
    }

    private val analyzeImageSuccessCallback: AnalyzerSuccessCallback = {
        Handler(Looper.getMainLooper()).post {
            // TODO: Open for discussion if we want to publish the results on the barcode stream as well.
//            // Also publish on controller result
//            barcodeHandler.publishEvent(mapOf(
//                "name" to "barcode",
//                "data" to it,
//            ))

            analyzerResult?.success(mapOf(
                "name" to "barcode",
                "data" to it
            ))
            analyzerResult = null
        }
    }

    private var analyzerResult: MethodChannel.Result? = null

    private val callback: MobileScannerCallback = { barcodes: List<Map<String, Any?>>, image: ByteArray?, width: Int?, height: Int? ->
        barcodeHandler.publishEvent(mapOf(
            "name" to "barcode",
            "data" to barcodes,
            // The image dimensions are always provided.
            // The image bytes are only non-null when `returnImage` is true.
            "image" to mapOf(
                "bytes" to image,
                "width" to width?.toDouble(),
                "height" to height?.toDouble(),
            )
        ))
    }

    private val errorCallback: MobileScannerErrorCallback = {error: String ->
        barcodeHandler.publishError(MobileScannerErrorCodes.BARCODE_ERROR, error, null)
    }

    private var methodChannel: MethodChannel? = null
    private var deviceOrientationChannel: EventChannel? = null

    private var mobileScanner: MobileScanner? = null

    private val torchStateCallback: TorchStateCallback = {state: Int ->
        // Off = 0, On = 1
        barcodeHandler.publishEvent(mapOf("name" to "torchState", "data" to state))
    }

    private val zoomScaleStateCallback: ZoomScaleStateCallback = {zoomScale: Double ->
        barcodeHandler.publishEvent(mapOf("name" to "zoomScaleState", "data" to zoomScale))
    }

    init {
        methodChannel = MethodChannel(binaryMessenger,
            "dev.steenbakker.mobile_scanner/scanner/method")
        methodChannel!!.setMethodCallHandler(this)

        val deviceOrientationListener = DeviceOrientationListener(activity)

        deviceOrientationChannel = EventChannel(binaryMessenger,
            "dev.steenbakker.mobile_scanner/scanner/deviceOrientation")
        deviceOrientationChannel!!.setStreamHandler(deviceOrientationListener)

        mobileScanner = MobileScanner(
            activity, textureRegistry, callback, errorCallback, deviceOrientationListener)
    }

    fun dispose(activityPluginBinding: ActivityPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        deviceOrientationChannel?.setStreamHandler(null)
        deviceOrientationChannel = null
        barcodeHandler.dispose()
        mobileScanner?.dispose()
        mobileScanner = null

        val listener: RequestPermissionsResultListener? = permissions.getPermissionListener()

        if(listener != null) {
            activityPluginBinding.removeRequestPermissionsResultListener(listener)
        }
    }

    @ExperimentalLensFacing
    @ExperimentalGetImage
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "state" -> result.success(permissions.hasCameraPermission(activity))
            "request" -> permissions.requestPermission(
                activity,
                addPermissionListener,
                object: MobileScannerPermissions.ResultCallback {
                    override fun onResult(errorCode: String?) {
                        when(errorCode) {
                            null -> result.success(true)
                            MobileScannerErrorCodes.CAMERA_ACCESS_DENIED -> result.success(false)
                            MobileScannerErrorCodes.CAMERA_PERMISSIONS_REQUEST_ONGOING -> result.error(
                                MobileScannerErrorCodes.CAMERA_PERMISSIONS_REQUEST_ONGOING,
                                MobileScannerErrorCodes.CAMERA_PERMISSIONS_REQUEST_ONGOING_MESSAGE, null)
                            else -> result.error(
                                MobileScannerErrorCodes.GENERIC_ERROR, MobileScannerErrorCodes.GENERIC_ERROR_MESSAGE, null)
                        }
                    }
                })
            "start" -> start(call, result)
            "pause" -> pause(call, result)
            "stop" -> stop(call, result)
            "toggleTorch" -> toggleTorch(result)
            "getSupportedLenses" -> getSupportedLenses(call, result)
            "getBestCloseRangeScanningLens" -> getBestCloseRangeScanningLens(result)
            "analyzeImage" -> analyzeImage(call, result)
            "setScale" -> setScale(call, result)
            "resetScale" -> resetScale(result)
            "updateScanWindow" -> updateScanWindow(call, result)
            "setFocus" -> setFocus(call, result)
            else -> result.notImplemented()
        }
    }

    @ExperimentalLensFacing
    @ExperimentalGetImage
    private fun start(call: MethodCall, result: MethodChannel.Result) {
        val torch: Boolean = call.argument<Boolean>("torch") ?: false
        val facing: Int = call.argument<Int>("facing") ?: 0
        val lensType: Int = call.argument<Int>("lensType") ?: -1
        val formats: List<Int>? = call.argument<List<Int>>("formats")
        val returnImage: Boolean = call.argument<Boolean>("returnImage") ?: false
        val speed: Int = call.argument<Int>("speed") ?: 1
        val timeout: Int = call.argument<Int>("timeout") ?: 250
        val cameraResolutionValues: List<Int>? = call.argument<List<Int>>("cameraResolution")
        val autoZoom: Boolean = call.argument<Boolean>("autoZoom") ?: false
        val cameraResolution: Size? = if (cameraResolutionValues != null) {
            Size(cameraResolutionValues[0], cameraResolutionValues[1])
        } else {
            null
        }
        val invertImage: Boolean = call.argument<Boolean>("invertImage") ?: false
        val initialZoom: Double? = call.argument<Double?>("initialZoom")

        val barcodeScannerOptions: BarcodeScannerOptions? = buildBarcodeScannerOptions(formats, autoZoom)

        val position = MobileScannerCameraLensSelector.selectCamera(cameraManager, facing, lensType)

        val detectionSpeed: DetectionSpeed = when (speed) {
            0 -> DetectionSpeed.NO_DUPLICATES
            1 -> DetectionSpeed.NORMAL
            else -> DetectionSpeed.UNRESTRICTED
        }

        mobileScanner!!.start(
            barcodeScannerOptions,
            returnImage,
            position,
            torch,
            detectionSpeed,
            torchStateCallback,
            zoomScaleStateCallback,
            mobileScannerStartedCallback = {
                Handler(Looper.getMainLooper()).post {
                    result.success(mapOf(
                        "textureId" to it.id,
                        "size" to mapOf("width" to it.width, "height" to it.height),
                        "naturalDeviceOrientation" to it.naturalDeviceOrientation,
                        "handlesCropAndRotation" to it.handlesCropAndRotation,
                        "sensorOrientation" to it.sensorOrientation,
                        "currentTorchState" to it.currentTorchState,
                        "numberOfCameras" to it.numberOfCameras,
                        "cameraDirection" to it.cameraDirection
                    ))
                }
            },
            mobileScannerErrorCallback = {
                Handler(Looper.getMainLooper()).post {
                    when (it) {
                        is AlreadyStarted -> {
                            result.error(
                                MobileScannerErrorCodes.ALREADY_STARTED_ERROR,
                                MobileScannerErrorCodes.ALREADY_STARTED_ERROR_MESSAGE,
                                null
                            )
                        }
                        is CameraError -> {
                            result.error(
                                MobileScannerErrorCodes.CAMERA_ERROR,
                                MobileScannerErrorCodes.CAMERA_ERROR_MESSAGE,
                                null
                            )
                        }
                        is NoCamera -> {
                            result.error(
                                MobileScannerErrorCodes.NO_CAMERA_ERROR,
                                MobileScannerErrorCodes.NO_CAMERA_ERROR_MESSAGE,
                                null
                            )
                        }
                        else -> {
                            result.error(
                                MobileScannerErrorCodes.GENERIC_ERROR,
                                MobileScannerErrorCodes.GENERIC_ERROR_MESSAGE,
                                null
                            )
                        }
                    }
                }
            },
            timeout.toLong(),
            cameraResolution,
            invertImage,
            initialZoom
        )
    }

    private fun pause(call: MethodCall, result: MethodChannel.Result) {
        val force: Boolean = call.argument<Boolean>("force") ?: false
        try {
            mobileScanner!!.pause(force)
            result.success(null)
        } catch (e: Exception) {
            when (e) {
                is AlreadyPaused, is AlreadyStopped -> result.success(null)
                else -> throw e
            }
        }
    }

    private fun stop(call: MethodCall, result: MethodChannel.Result) {
        val force: Boolean = call.argument<Boolean>("force") ?: false
        try {
            mobileScanner!!.stop(force)
            result.success(null)
        } catch (e: AlreadyStopped) {
            result.success(null)
        }
    }

    private fun analyzeImage(call: MethodCall, result: MethodChannel.Result) {
        analyzerResult = result

        val formats: List<Int>? = call.argument<List<Int>>("formats")
        val filePath: String = call.argument<String>("filePath")!!

        mobileScanner!!.analyzeImage(
            Uri.fromFile(File(filePath)),
            buildBarcodeScannerOptions(formats, false),
            analyzeImageSuccessCallback,
            analyzeImageErrorCallback)
    }

    private fun toggleTorch(result: MethodChannel.Result) {
        mobileScanner?.toggleTorch()
        result.success(null)
    }

    /**
     * Get the list of supported lens types on this device for a given facing direction.
     *
     * Accepts an optional "facing" argument (0 = front, 1 = back).
     * When omitted, lenses for all cameras are returned.
     */
    private fun getSupportedLenses(call: MethodCall, result: MethodChannel.Result) {
        val facing: Int? = call.argument<Int>("facing")
        try {
            val supportedLenses = MobileScannerCameraLensSelector.getSupportedLenses(cameraManager, facing)
            result.success(supportedLenses.toList())
        } catch (e: Exception) {
            result.error(
                MobileScannerErrorCodes.GENERIC_ERROR,
                e.localizedMessage ?: MobileScannerErrorCodes.GENERIC_ERROR_MESSAGE,
                null
            )
        }
    }

    /**
     * Get the lens type best suited for close-range scanning.
     *
     * Returns the normal (main) camera lens, or null if the device has no camera;
     * see [MobileScannerCameraLensSelector.getBestCloseRangeScanningLens] for why it does
     * not depend on facing.
     */
    private fun getBestCloseRangeScanningLens(result: MethodChannel.Result) {
        try {
            val lensType = MobileScannerCameraLensSelector.getBestCloseRangeScanningLens(cameraManager)
            result.success(lensType)
        } catch (e: Exception) {
            result.error(
                MobileScannerErrorCodes.GENERIC_ERROR,
                e.localizedMessage ?: MobileScannerErrorCodes.GENERIC_ERROR_MESSAGE,
                null
            )
        }
    }

    private fun setScale(call: MethodCall, result: MethodChannel.Result) {
        try {
            mobileScanner!!.setScale(call.arguments as Double)
            result.success(null)
        } catch (e: ZoomWhenStopped) {
            result.error(
                MobileScannerErrorCodes.SET_SCALE_WHEN_STOPPED_ERROR, MobileScannerErrorCodes.SET_SCALE_WHEN_STOPPED_ERROR_MESSAGE, null)
        } catch (e: ZoomNotInRange) {
            result.error(
                MobileScannerErrorCodes.GENERIC_ERROR, MobileScannerErrorCodes.INVALID_ZOOM_SCALE_ERROR_MESSAGE, null)
        }
    }

    private fun setZoomRatio(scale: Float) : Boolean {
        try {
            mobileScanner!!.setZoomRatio(scale.toDouble())
            return true
        } catch (e: ZoomWhenStopped) { }
        return false
    }

    private fun resetScale(result: MethodChannel.Result) {
        try {
            mobileScanner!!.resetScale()
            result.success(null)
        } catch (e: ZoomWhenStopped) {
            result.error(
                MobileScannerErrorCodes.SET_SCALE_WHEN_STOPPED_ERROR, MobileScannerErrorCodes.SET_SCALE_WHEN_STOPPED_ERROR_MESSAGE, null)
        }
    }

    private fun updateScanWindow(call: MethodCall, result: MethodChannel.Result) {
        mobileScanner?.scanWindow = call.argument<List<Float>?>("rect")

        result.success(null)
    }

    private fun buildBarcodeScannerOptions(formats: List<Int>?, autoZoom: Boolean): BarcodeScannerOptions? {
        val builder : BarcodeScannerOptions.Builder?
        if (formats == null) {
            builder = BarcodeScannerOptions.Builder()
        } else {
            val formatsList: MutableList<Int> = mutableListOf()

            for (formatValue in formats) {
                formatsList.add(BarcodeFormats.fromRawValue(formatValue).intValue)
            }

            if (formatsList.size == 1) {
                builder = BarcodeScannerOptions.Builder().setBarcodeFormats(formatsList.first())
            } else {
                builder = BarcodeScannerOptions.Builder().setBarcodeFormats(
                    formatsList.first(),
                    *formatsList.subList(1, formatsList.size).toIntArray()
                )
            }
        }

        if (autoZoom) {
            builder.setZoomSuggestionOptions(
                ZoomSuggestionOptions.Builder {
                    setZoomRatio(it)
                }.setMaxSupportedZoomRatio(getMaxZoomRatio())
                    .build())
        }

        return builder.build()
    }

    private fun getMaxZoomRatio(): Float {
        var maxZoom = 1.0F

        try {
            for (cameraId in cameraManager.cameraIdList) {
                val characteristics = cameraManager.getCameraCharacteristics(cameraId)

                val maxZoomRatio = characteristics.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM)
                if (maxZoomRatio != null && maxZoomRatio > maxZoom) {
                    maxZoom = maxZoomRatio
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return maxZoom
    }

    private fun setFocus(call: MethodCall, result: MethodChannel.Result) {
        val dx = call.argument<Double>("dx")?.toFloat()
        val dy = call.argument<Double>("dy")?.toFloat()

        if (dx == null || dy == null || dx !in 0f..1f || dy !in 0f..1f) {
            result.error(
                MobileScannerErrorCodes.INVALID_FOCUS_POINT,
                MobileScannerErrorCodes.INVALID_FOCUS_POINT_MESSAGE,
                null
            )
            return
        }

        try {
            mobileScanner?.setFocus(dx, dy)
            result.success(null)
        } catch (e: ZoomWhenStopped) {
            result.error(
                MobileScannerErrorCodes.GENERIC_ERROR,
                "Cannot set focus when camera is stopped.",
                null
            )
        } catch (e: Exception) {
            result.error(
                MobileScannerErrorCodes.GENERIC_ERROR,
                MobileScannerErrorCodes.GENERIC_ERROR_MESSAGE,
                e.localizedMessage
            )
        }
    }

}
