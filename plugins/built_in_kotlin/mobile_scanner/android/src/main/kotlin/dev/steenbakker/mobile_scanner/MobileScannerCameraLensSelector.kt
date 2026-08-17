package dev.steenbakker.mobile_scanner

import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.util.Log
import android.util.SizeF
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.core.CameraSelector
import kotlin.math.sqrt

/**
 * Utility class for camera lens detection and selection.
 *
 * Provides functions to:
 * - Calculate 35mm equivalent focal lengths from physical focal length and sensor size
 * - Classify lenses into categories (wide, normal, zoom) based on 35mm equivalent
 * - Select cameras based on facing direction and lens type
 * - Query supported lens types on a device
 *
 * The classification uses industry-standard 35mm equivalent focal length ranges:
 * - Wide (Ultra-Wide): <20mm equivalent - The "0.5x" lens
 * - Normal (Standard): 20-35mm equivalent - The "1x" main lens
 * - Zoom (Telephoto): >35mm equivalent - The "2x", "3x", "5x" telephoto lenses
 */
object MobileScannerCameraLensSelector {

    private const val TAG = "MobileScannerLensSelector"

    /**
     * Lens type constants matching the Dart enum values.
     */
    const val LENS_TYPE_NORMAL = 0
    const val LENS_TYPE_WIDE = 1
    const val LENS_TYPE_ZOOM = 2
    const val LENS_TYPE_ANY = -1

    /**
     * The diagonal of a standard 35mm full-frame sensor in millimeters.
     * Used as the reference for calculating 35mm equivalent focal lengths.
     */
    const val FULL_FRAME_DIAGONAL_MM = 43.27f

    /**
     * 35mm equivalent focal length thresholds for classifying smartphone camera lenses.
     *
     * These thresholds are based on standard photography conventions:
     *
     * - Ultra-Wide (Wide): <20mm equivalent - The "0.5x" lens
     * - Standard (Normal): 20-35mm equivalent - The "1x" main lens (typically ~24-28mm)
     * - Telephoto (Zoom): >35mm equivalent - The "2x", "3x", "5x" telephoto lenses
     *
     * The 35mm equivalent is calculated using the formula:
     * equivalent = focalLength * (43.27 / sensorDiagonal)
     *
     * This approach is more accurate than using raw focal lengths because it
     * accounts for sensor size variations between devices.
     *
     * References:
     * - 35mm equivalent focal length: https://developer.android.com/reference/android/hardware/camera2/CameraCharacteristics
     * - Android CameraCharacteristics documentation
     */
    const val EQUIVALENT_35MM_WIDE_THRESHOLD = 20
    const val EQUIVALENT_35MM_ZOOM_THRESHOLD = 35

    // ==========================================================================
    // 35mm Equivalent Calculation
    // ==========================================================================

    /**
     * Calculates the 35mm equivalent focal length.
     *
     * @param focalLengthMm The physical focal length in millimeters
     * @param sensorWidthMm The physical sensor width in millimeters
     * @param sensorHeightMm The physical sensor height in millimeters
     * @return The 35mm equivalent focal length as an integer, or -1 if inputs are invalid
     */
    fun calculate35mmEquivalent(focalLengthMm: Float, sensorWidthMm: Float, sensorHeightMm: Float): Int {
        if (sensorWidthMm <= 0f || sensorHeightMm <= 0f || focalLengthMm < 0f) {
            return -1
        }
        val sensorDiagonal = sqrt(
            (sensorWidthMm * sensorWidthMm) +
            (sensorHeightMm * sensorHeightMm)
        )
        val cropFactor = FULL_FRAME_DIAGONAL_MM / sensorDiagonal
        return (focalLengthMm * cropFactor).toInt()
    }

    /**
     * Calculates the 35mm equivalent focal length.
     *
     * @param focalLengthMm The physical focal length in millimeters
     * @param sensorSize The physical sensor size (width x height) in millimeters
     * @return The 35mm equivalent focal length as an integer, or -1 if the sensor size is invalid
     */
    fun calculate35mmEquivalent(focalLengthMm: Float, sensorSize: SizeF): Int {
        return calculate35mmEquivalent(focalLengthMm, sensorSize.width, sensorSize.height)
    }

    // ==========================================================================
    // Lens Type Classification
    // ==========================================================================

    /**
     * Classifies a 35mm equivalent focal length into a lens type category.
     *
     * @param equivalent35mm The 35mm equivalent focal length
     * @return The lens type: [LENS_TYPE_WIDE], [LENS_TYPE_NORMAL], or [LENS_TYPE_ZOOM]
     */
    fun classifyLensType(equivalent35mm: Int): Int {
        return when {
            equivalent35mm < EQUIVALENT_35MM_WIDE_THRESHOLD -> LENS_TYPE_WIDE
            equivalent35mm <= EQUIVALENT_35MM_ZOOM_THRESHOLD -> LENS_TYPE_NORMAL
            else -> LENS_TYPE_ZOOM
        }
    }

    /**
     * Classifies a lens using raw focal length and sensor size.
     *
     * Calculates the 35mm equivalent first, then classifies based on that.
     *
     * @param focalLengthMm The physical focal length in millimeters
     * @param sensorSize The physical sensor size (width x height) in millimeters
     * @return The lens type: [LENS_TYPE_WIDE], [LENS_TYPE_NORMAL], or [LENS_TYPE_ZOOM],
     *         or null if the sensor size is invalid
     */
    fun classifyLensType(focalLengthMm: Float, sensorSize: SizeF): Int? {
        val equivalent = calculate35mmEquivalent(focalLengthMm, sensorSize)
        if (equivalent < 0) return null
        return classifyLensType(equivalent)
    }

    // ==========================================================================
    // Lens Type Matching
    // ==========================================================================

    /**
     * Checks if a 35mm equivalent focal length matches the requested lens type.
     *
     * @param equivalent35mm The 35mm equivalent focal length
     * @param lensType The requested lens type
     * @return True if the focal length matches the lens type category
     */
    fun matchesLensType(equivalent35mm: Int, lensType: Int): Boolean {
        if (lensType == LENS_TYPE_ANY) return true
        return classifyLensType(equivalent35mm) == lensType
    }

    /**
     * Checks if a lens matches the requested type using raw focal length and sensor size.
     *
     * @param focalLengthMm The physical focal length in millimeters
     * @param sensorSize The physical sensor size (width x height) in millimeters
     * @param lensType The requested lens type
     * @return True if the lens matches the requested type, false if no match or invalid sensor size
     */
    fun matchesLensType(focalLengthMm: Float, sensorSize: SizeF, lensType: Int): Boolean {
        if (lensType == LENS_TYPE_ANY) return true
        val equivalent = calculate35mmEquivalent(focalLengthMm, sensorSize)
        if (equivalent < 0) return false
        return classifyLensType(equivalent) == lensType
    }

    // ==========================================================================
    // Camera Characteristics Helpers
    // ==========================================================================

    /**
     * Extracts the lens type from camera characteristics using 35mm equivalent calculation.
     *
     * @param characteristics The camera characteristics to analyze
     * @return The lens type, or null if the characteristics are insufficient
     */
    fun getLensTypeFromCharacteristics(characteristics: CameraCharacteristics): Int? {
        val focalLengths = characteristics.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
        val sensorSize = characteristics.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)

        if (focalLengths == null || focalLengths.isEmpty() || sensorSize == null) {
            return null
        }

        // Use the first focal length (most physical lenses have fixed focal length)
        val focalLength = focalLengths[0]
        return classifyLensType(focalLength, sensorSize)
    }

    /**
     * Returns a human-readable name for a lens type constant.
     *
     * @param lensType The lens type constant
     * @return The lens type name (e.g., "WIDE", "NORMAL", "ZOOM")
     */
    fun getLensTypeName(lensType: Int): String {
        return when (lensType) {
            LENS_TYPE_WIDE -> "WIDE"
            LENS_TYPE_NORMAL -> "NORMAL"
            LENS_TYPE_ZOOM -> "ZOOM"
            LENS_TYPE_ANY -> "ANY"
            else -> "UNKNOWN"
        }
    }

    // ==========================================================================
    // Camera Selection
    // ==========================================================================

    /**
     * Get the list of supported lens types on a device.
     *
     * Analyzes the available logical cameras and categorizes them by their 35mm equivalent
     * focal lengths. Physical sub-cameras of logical multi-camera devices are not inspected,
     * because CameraX can only select cameras at the logical level.
     *
     * @param cameraManager The CameraManager instance
     * @param facing Optional facing filter: 0 = front, 1 = back. When null, all cameras are included.
     * @return A set of supported lens types, optionally filtered to the given facing direction
     */
    fun getSupportedLenses(cameraManager: CameraManager, facing: Int? = null): Set<Int> {
        val supportedLenses = mutableSetOf<Int>()
        val lensFacing = when (facing) {
            0 -> CameraCharacteristics.LENS_FACING_FRONT
            1 -> CameraCharacteristics.LENS_FACING_BACK
            else -> null
        }

        try {
            for (cameraId in cameraManager.cameraIdList) {
                val characteristics = cameraManager.getCameraCharacteristics(cameraId)

                // Skip cameras that don't match the requested facing direction, if one was given.
                if (lensFacing != null) {
                    val cameraFacing = characteristics.get(CameraCharacteristics.LENS_FACING)
                    if (cameraFacing != lensFacing) continue
                }

                // Only check the logical camera's own characteristics.
                // CameraX selects cameras at the logical level, so physical sub-cameras
                // are not independently selectable and must not be reported here.
                val lensType = getLensTypeFromCharacteristics(characteristics)
                if (lensType != null) {
                    supportedLenses.add(lensType)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to enumerate cameras", e)
        }

        return supportedLenses
    }

    /**
     * Determine the lens type best suited for close-range scanning.
     *
     * Camera2 exposes [CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE] per camera,
     * but on modern multi-camera devices that value is only meaningful on physical
     * sub-cameras, which (like the rest of [getSupportedLenses]) are not independently
     * selectable through CameraX. Since we cannot act on a physical-camera-only signal,
     * this always returns [LENS_TYPE_NORMAL] when the device has a camera: the main
     * camera has the most capable autofocus system on virtually all Android devices.
     *
     * @param cameraManager The CameraManager instance
     * @return [LENS_TYPE_NORMAL], or null if the device has no camera
     */
    fun getBestCloseRangeScanningLens(cameraManager: CameraManager): Int? {
        return try {
            if (cameraManager.cameraIdList.isEmpty()) null else LENS_TYPE_NORMAL
        } catch (e: Exception) {
            Log.e(TAG, "Failed to enumerate cameras", e)
            null
        }
    }

    /**
     * Select the appropriate camera based on facing direction and lens type.
     *
     * Uses 35mm equivalent focal length calculation for accurate lens classification.
     *
     * @param cameraManager The CameraManager instance
     * @param facing 0 = front, 1 = back
     * @param lensType [LENS_TYPE_NORMAL], [LENS_TYPE_WIDE], [LENS_TYPE_ZOOM], or [LENS_TYPE_ANY]
     * @return CameraSelector configured for the desired camera
     */
    fun selectCamera(cameraManager: CameraManager, facing: Int, lensType: Int): CameraSelector {
        val lensFacing = if (facing == 0) CameraSelector.LENS_FACING_FRONT else CameraSelector.LENS_FACING_BACK

        // If no specific lens type is requested, return default camera for facing direction
        if (lensType == LENS_TYPE_ANY) {
            return if (facing == 0) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA
        }

        // Build a camera selector that filters by both facing and lens characteristics
        return CameraSelector.Builder()
            .requireLensFacing(lensFacing)
            .addCameraFilter { cameraInfos ->
                val filteredCameras = cameraInfos.filter { cameraInfo ->
                    try {
                        // Get the camera ID from CameraInfo
                        val cameraId = Camera2CameraInfo.from(cameraInfo).cameraId
                        val characteristics = cameraManager.getCameraCharacteristics(cameraId)

                        // Get focal lengths and sensor size for 35mm equivalent calculation
                        val focalLengths = characteristics.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                        val sensorSize = characteristics.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)

                        if (focalLengths == null || focalLengths.isEmpty() || sensorSize == null) {
                            // Without focal length or sensor info, we can't determine the lens type.
                            // Exclude this camera since a specific lens type was requested.
                            // (LENS_TYPE_ANY is already handled by the early return above.)
                            return@filter false
                        }

                        // Use the first focal length (most physical lenses have fixed focal length)
                        val focalLength = focalLengths[0]
                        matchesLensType(focalLength, sensorSize, lensType)
                    } catch (e: Exception) {
                        // If we can't get characteristics, exclude this camera for consistency
                        // with the "no focal length info" case above. The fallback at the end
                        // of the filter will return all cameras if none match.
                        Log.w(TAG, "Failed to get camera characteristics", e)
                        false
                    }
                }

                // If no cameras matched the requested lens type, return an empty list.
                // CameraX will throw an error that propagates to the Dart error callback,
                // allowing callers to detect that this lens type is unavailable.
                if (filteredCameras.isEmpty()) {
                    Log.w(TAG, "Requested lens type ${getLensTypeName(lensType)} not available")
                }
                filteredCameras
            }
            .build()
    }
}
