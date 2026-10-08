package dev.steenbakker.mobile_scanner

import android.Manifest.permission
import android.app.Activity
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import dev.steenbakker.mobile_scanner.objects.MobileScannerErrorCodes
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener

/**
 * This class handles the camera permissions for the Mobile Scanner.
 */
class MobileScannerPermissions {
    companion object {
        /**
         * When the application's activity is [androidx.fragment.app.FragmentActivity], requestCode can only use the lower 16 bits.
         * @see androidx.fragment.app.FragmentActivity.validateRequestPermissionsRequestCode
         */
        const val REQUEST_CODE = 0x0786
    }

    interface ResultCallback {
        fun onResult(errorCode: String?)
    }

    private var listener: RequestPermissionsResultListener? = null

    fun getPermissionListener(): RequestPermissionsResultListener? {
        return listener
    }

    private var ongoing: Boolean = false

    fun hasCameraPermission(activity: Activity) : Int {
        val hasPermission = ContextCompat.checkSelfPermission(
            activity,
            permission.CAMERA,
        ) == PackageManager.PERMISSION_GRANTED

        return if (hasPermission) {
            1
        } else {
            2
        }
    }

    fun requestPermission(activity: Activity,
                          addPermissionListener: (RequestPermissionsResultListener) -> Unit,
                          callback: ResultCallback) {
        if (ongoing) {
            callback.onResult(MobileScannerErrorCodes.CAMERA_PERMISSIONS_REQUEST_ONGOING)
            return
        }

        if(hasCameraPermission(activity) == 1) {
            // Permissions already exist. Call the callback with success.
            callback.onResult(null)
            return
        }

        if(listener == null) {
            // Keep track of the listener, so that it can be unregistered later.
            listener = MobileScannerPermissionsListener(
                object: ResultCallback {
                    override fun onResult(errorCode: String?) {
                        ongoing = false
                        listener = null
                        callback.onResult(errorCode)
                    }
                }
            )
            listener?.let { listener -> addPermissionListener(listener) }
        }

        ongoing = true
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(permission.CAMERA),
            REQUEST_CODE
        )
    }
}

