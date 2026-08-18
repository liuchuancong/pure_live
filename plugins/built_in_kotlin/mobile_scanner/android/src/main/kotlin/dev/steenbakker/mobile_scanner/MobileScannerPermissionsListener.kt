package dev.steenbakker.mobile_scanner

import android.content.pm.PackageManager
import dev.steenbakker.mobile_scanner.objects.MobileScannerErrorCodes
import io.flutter.plugin.common.PluginRegistry

/**
 * This class handles incoming camera permission results.
 */
internal class MobileScannerPermissionsListener(
    private val resultCallback: MobileScannerPermissions.ResultCallback,
): PluginRegistry.RequestPermissionsResultListener {
    // There's no way to unregister permission listeners in the v1 embedding, so we'll be called
    // duplicate times in cases where the user denies and then grants a permission. Keep track of if
    // we've responded before and bail out of handling the callback manually if this is a repeat
    // call.
    private var alreadyCalled: Boolean = false

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (alreadyCalled || requestCode != MobileScannerPermissions.REQUEST_CODE) {
            return false
        }

        alreadyCalled = true

        // grantResults could be empty if the permissions request with the user is interrupted
        // https://developer.android.com/reference/android/app/Activity#onRequestPermissionsResult(int,%20java.lang.String[],%20int[])
        if (grantResults.isEmpty() || grantResults[0] != PackageManager.PERMISSION_GRANTED) {
            resultCallback.onResult(MobileScannerErrorCodes.CAMERA_ACCESS_DENIED)
        } else {
            resultCallback.onResult(null)
        }

        return true
    }
}