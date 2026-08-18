package dev.steenbakker.mobile_scanner

import android.hardware.camera2.CameraManager
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import org.mockito.Mockito

/**
 * Unit tests for the lens classification functions in [MobileScannerCameraLensSelector].
 *
 * These tests verify the 35mm equivalent focal length classification logic.
 * Tests that require Android SDK classes (like SizeF) should be run as
 * instrumented tests on a device or emulator.
 *
 * Run these tests from the command line by running `./gradlew testDebugUnitTest`
 * in the `example/android/` directory.
 */
internal class MobileScannerCameraLensSelectorTest {

    // ==========================================================================
    // calculate35mmEquivalent tests
    // ==========================================================================

    @Test
    fun calculate35mmEquivalent_typicalSmartphoneSensor_returnsExpectedValue() {
        // Typical smartphone sensor: ~5.6mm x 4.2mm diagonal ≈ 7mm
        // With 4.3mm focal length: 4.3 * (43.27 / 7) ≈ 26mm (standard main lens)
        val result = MobileScannerCameraLensSelector.calculate35mmEquivalent(4.3f, 5.6f, 4.2f)
        assertEquals(26, result)
    }

    @Test
    fun calculate35mmEquivalent_ultraWideLens_returnsExpectedValue() {
        // Ultra-wide lens with shorter focal length
        // ~2.0mm focal length on same sensor: 2.0 * (43.27 / 7) ≈ 12mm
        val result = MobileScannerCameraLensSelector.calculate35mmEquivalent(2.0f, 5.6f, 4.2f)
        assertEquals(12, result)
    }

    @Test
    fun calculate35mmEquivalent_telephotoLens_returnsExpectedValue() {
        // Telephoto lens with longer focal length
        // ~8.0mm focal length on same sensor: 8.0 * (43.27 / 7) ≈ 49mm
        val result = MobileScannerCameraLensSelector.calculate35mmEquivalent(8.0f, 5.6f, 4.2f)
        assertEquals(49, result)
    }

    @Test
    fun calculate35mmEquivalent_zeroSensorWidth_returnsNegativeOne() {
        val result = MobileScannerCameraLensSelector.calculate35mmEquivalent(4.3f, 0f, 4.2f)
        assertEquals(-1, result)
    }

    @Test
    fun calculate35mmEquivalent_zeroSensorHeight_returnsNegativeOne() {
        val result = MobileScannerCameraLensSelector.calculate35mmEquivalent(4.3f, 5.6f, 0f)
        assertEquals(-1, result)
    }

    @Test
    fun calculate35mmEquivalent_negativeSensorWidth_returnsNegativeOne() {
        val result = MobileScannerCameraLensSelector.calculate35mmEquivalent(4.3f, -5.6f, 4.2f)
        assertEquals(-1, result)
    }

    @Test
    fun calculate35mmEquivalent_negativeSensorHeight_returnsNegativeOne() {
        val result = MobileScannerCameraLensSelector.calculate35mmEquivalent(4.3f, 5.6f, -4.2f)
        assertEquals(-1, result)
    }

    @Test
    fun calculate35mmEquivalent_negativeFocalLength_returnsNegativeOne() {
        val result = MobileScannerCameraLensSelector.calculate35mmEquivalent(-4.3f, 5.6f, 4.2f)
        assertEquals(-1, result)
    }

    @Test
    fun calculate35mmEquivalent_zeroFocalLength_returnsZero() {
        // Zero focal length with valid sensor should return 0 (not -1)
        val result = MobileScannerCameraLensSelector.calculate35mmEquivalent(0f, 5.6f, 4.2f)
        assertEquals(0, result)
    }

    @Test
    fun calculate35mmEquivalent_verySmallSensor_returnsLargeEquivalent() {
        // Very small sensor results in high crop factor and large 35mm equivalent
        // 4.3mm focal length on 1mm x 1mm sensor: 4.3 * (43.27 / 1.41) ≈ 131mm
        val result = MobileScannerCameraLensSelector.calculate35mmEquivalent(4.3f, 1f, 1f)
        assertEquals(131, result)
    }

    @Test
    fun calculate35mmEquivalent_largeSensor_returnsSmallEquivalent() {
        // Larger sensor (closer to full-frame) results in lower crop factor
        // 4.3mm focal length on 30mm x 20mm sensor: 4.3 * (43.27 / 36.06) ≈ 5mm
        val result = MobileScannerCameraLensSelector.calculate35mmEquivalent(4.3f, 30f, 20f)
        assertEquals(5, result)
    }

    @Test
    fun calculate35mmEquivalent_fullFrameSensor_returnsApproximateFocalLength() {
        // Full-frame sensor (36mm x 24mm, diagonal ≈ 43.27mm) should return ~focal length
        // 50mm focal length on full-frame: 50 * (43.27 / 43.27) = 50mm
        val result = MobileScannerCameraLensSelector.calculate35mmEquivalent(50f, 36f, 24f)
        // Allow for rounding: 43.27 / sqrt(36^2 + 24^2) = 43.27 / 43.27 ≈ 1.0
        assertEquals(50, result)
    }

    // ==========================================================================
    // classifyLensType(equivalent35mm: Int) tests
    // ==========================================================================

    @Test
    fun classifyLensType_belowWideThreshold_returnsWide() {
        // Values below 20mm 35mm-equivalent should be classified as wide (ultra-wide)
        // Includes typical ultra-wide values (~13-16mm for "0.5x" lenses)
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_WIDE, MobileScannerCameraLensSelector.classifyLensType(13))
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_WIDE, MobileScannerCameraLensSelector.classifyLensType(14))
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_WIDE, MobileScannerCameraLensSelector.classifyLensType(16))
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_WIDE, MobileScannerCameraLensSelector.classifyLensType(19))
    }

    @Test
    fun classifyLensType_atWideThreshold_returnsNormal() {
        // Exactly 20mm should be classified as normal (>= 20)
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_NORMAL, MobileScannerCameraLensSelector.classifyLensType(20))
    }

    @Test
    fun classifyLensType_justAboveWideThreshold_returnsNormal() {
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_NORMAL, MobileScannerCameraLensSelector.classifyLensType(21))
    }

    @Test
    fun classifyLensType_inNormalRange_returnsNormal() {
        // Values between 20mm and 35mm should be classified as normal (standard main lens)
        // Includes typical main lens values (~24-28mm for "1x" lenses)
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_NORMAL, MobileScannerCameraLensSelector.classifyLensType(24))
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_NORMAL, MobileScannerCameraLensSelector.classifyLensType(26))
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_NORMAL, MobileScannerCameraLensSelector.classifyLensType(28))
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_NORMAL, MobileScannerCameraLensSelector.classifyLensType(32))
    }

    @Test
    fun classifyLensType_atZoomThreshold_returnsNormal() {
        // Exactly 35mm should be classified as normal (<= 35)
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_NORMAL, MobileScannerCameraLensSelector.classifyLensType(35))
    }

    @Test
    fun classifyLensType_justAboveZoomThreshold_returnsZoom() {
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_ZOOM, MobileScannerCameraLensSelector.classifyLensType(36))
    }

    @Test
    fun classifyLensType_aboveZoomThreshold_returnsZoom() {
        // Values above 35mm should be classified as zoom (telephoto)
        // Includes typical telephoto (50-75mm for "2x"/"3x") and periscope (120mm+ for "5x"/"10x")
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_ZOOM, MobileScannerCameraLensSelector.classifyLensType(50))
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_ZOOM, MobileScannerCameraLensSelector.classifyLensType(70))
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_ZOOM, MobileScannerCameraLensSelector.classifyLensType(75))
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_ZOOM, MobileScannerCameraLensSelector.classifyLensType(120))
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_ZOOM, MobileScannerCameraLensSelector.classifyLensType(200))
    }

    @Test
    fun classifyLensType_extremeSmallValue_returnsWide() {
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_WIDE, MobileScannerCameraLensSelector.classifyLensType(1))
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_WIDE, MobileScannerCameraLensSelector.classifyLensType(5))
    }

    @Test
    fun classifyLensType_extremeLargeValue_returnsZoom() {
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_ZOOM, MobileScannerCameraLensSelector.classifyLensType(500))
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_ZOOM, MobileScannerCameraLensSelector.classifyLensType(1000))
    }

    @Test
    fun classifyLensType_zeroValue_returnsWide() {
        // Zero focal length (edge case) should be classified as wide
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_WIDE, MobileScannerCameraLensSelector.classifyLensType(0))
    }

    @Test
    fun classifyLensType_negativeValue_returnsWide() {
        // Negative focal length (invalid, but should not crash) returns wide
        assertEquals(MobileScannerCameraLensSelector.LENS_TYPE_WIDE, MobileScannerCameraLensSelector.classifyLensType(-1))
    }

    // ==========================================================================
    // matchesLensType(equivalent35mm: Int, lensType: Int) tests
    // ==========================================================================

    @Test
    fun matchesLensType_anyLensType_alwaysReturnsTrue() {
        // LENS_TYPE_ANY should match any focal length
        assertTrue(MobileScannerCameraLensSelector.matchesLensType(13, MobileScannerCameraLensSelector.LENS_TYPE_ANY))
        assertTrue(MobileScannerCameraLensSelector.matchesLensType(24, MobileScannerCameraLensSelector.LENS_TYPE_ANY))
        assertTrue(MobileScannerCameraLensSelector.matchesLensType(35, MobileScannerCameraLensSelector.LENS_TYPE_ANY))
        assertTrue(MobileScannerCameraLensSelector.matchesLensType(50, MobileScannerCameraLensSelector.LENS_TYPE_ANY))
        assertTrue(MobileScannerCameraLensSelector.matchesLensType(120, MobileScannerCameraLensSelector.LENS_TYPE_ANY))
    }

    @Test
    fun matchesLensType_wideLensType_matchesWideFocalLengths() {
        // Wide lens type should match focal lengths < 20mm equivalent
        assertTrue(MobileScannerCameraLensSelector.matchesLensType(13, MobileScannerCameraLensSelector.LENS_TYPE_WIDE))
        assertTrue(MobileScannerCameraLensSelector.matchesLensType(16, MobileScannerCameraLensSelector.LENS_TYPE_WIDE))
        assertTrue(MobileScannerCameraLensSelector.matchesLensType(19, MobileScannerCameraLensSelector.LENS_TYPE_WIDE))
    }

    @Test
    fun matchesLensType_wideLensType_doesNotMatchOtherFocalLengths() {
        assertFalse(MobileScannerCameraLensSelector.matchesLensType(20, MobileScannerCameraLensSelector.LENS_TYPE_WIDE))
        assertFalse(MobileScannerCameraLensSelector.matchesLensType(24, MobileScannerCameraLensSelector.LENS_TYPE_WIDE))
        assertFalse(MobileScannerCameraLensSelector.matchesLensType(50, MobileScannerCameraLensSelector.LENS_TYPE_WIDE))
    }

    @Test
    fun matchesLensType_normalLensType_matchesNormalFocalLengths() {
        // Normal lens type should match focal lengths between 20mm and 35mm
        assertTrue(MobileScannerCameraLensSelector.matchesLensType(20, MobileScannerCameraLensSelector.LENS_TYPE_NORMAL))
        assertTrue(MobileScannerCameraLensSelector.matchesLensType(24, MobileScannerCameraLensSelector.LENS_TYPE_NORMAL))
        assertTrue(MobileScannerCameraLensSelector.matchesLensType(28, MobileScannerCameraLensSelector.LENS_TYPE_NORMAL))
        assertTrue(MobileScannerCameraLensSelector.matchesLensType(35, MobileScannerCameraLensSelector.LENS_TYPE_NORMAL))
    }

    @Test
    fun matchesLensType_normalLensType_doesNotMatchOtherFocalLengths() {
        assertFalse(MobileScannerCameraLensSelector.matchesLensType(19, MobileScannerCameraLensSelector.LENS_TYPE_NORMAL))
        assertFalse(MobileScannerCameraLensSelector.matchesLensType(36, MobileScannerCameraLensSelector.LENS_TYPE_NORMAL))
    }

    @Test
    fun matchesLensType_zoomLensType_matchesZoomFocalLengths() {
        // Zoom lens type should match focal lengths > 35mm
        assertTrue(MobileScannerCameraLensSelector.matchesLensType(36, MobileScannerCameraLensSelector.LENS_TYPE_ZOOM))
        assertTrue(MobileScannerCameraLensSelector.matchesLensType(50, MobileScannerCameraLensSelector.LENS_TYPE_ZOOM))
        assertTrue(MobileScannerCameraLensSelector.matchesLensType(120, MobileScannerCameraLensSelector.LENS_TYPE_ZOOM))
    }

    @Test
    fun matchesLensType_zoomLensType_doesNotMatchOtherFocalLengths() {
        assertFalse(MobileScannerCameraLensSelector.matchesLensType(16, MobileScannerCameraLensSelector.LENS_TYPE_ZOOM))
        assertFalse(MobileScannerCameraLensSelector.matchesLensType(24, MobileScannerCameraLensSelector.LENS_TYPE_ZOOM))
        assertFalse(MobileScannerCameraLensSelector.matchesLensType(35, MobileScannerCameraLensSelector.LENS_TYPE_ZOOM))
    }

    // ==========================================================================
    // getLensTypeName tests
    // ==========================================================================

    @Test
    fun getLensTypeName_returnsCorrectNames() {
        assertEquals("WIDE", MobileScannerCameraLensSelector.getLensTypeName(MobileScannerCameraLensSelector.LENS_TYPE_WIDE))
        assertEquals("NORMAL", MobileScannerCameraLensSelector.getLensTypeName(MobileScannerCameraLensSelector.LENS_TYPE_NORMAL))
        assertEquals("ZOOM", MobileScannerCameraLensSelector.getLensTypeName(MobileScannerCameraLensSelector.LENS_TYPE_ZOOM))
        assertEquals("ANY", MobileScannerCameraLensSelector.getLensTypeName(MobileScannerCameraLensSelector.LENS_TYPE_ANY))
        assertEquals("UNKNOWN", MobileScannerCameraLensSelector.getLensTypeName(999))
    }

    // ==========================================================================
    // Threshold constant tests
    // ==========================================================================

    @Test
    fun thresholdConstants_haveExpectedValues() {
        assertEquals(20, MobileScannerCameraLensSelector.EQUIVALENT_35MM_WIDE_THRESHOLD)
        assertEquals(35, MobileScannerCameraLensSelector.EQUIVALENT_35MM_ZOOM_THRESHOLD)
    }

    @Test
    fun fullFrameDiagonal_hasExpectedValue() {
        assertEquals(43.27f, MobileScannerCameraLensSelector.FULL_FRAME_DIAGONAL_MM)
    }

    @Test
    fun lensTypeConstants_haveExpectedValues() {
        assertEquals(0, MobileScannerCameraLensSelector.LENS_TYPE_NORMAL)
        assertEquals(1, MobileScannerCameraLensSelector.LENS_TYPE_WIDE)
        assertEquals(2, MobileScannerCameraLensSelector.LENS_TYPE_ZOOM)
        assertEquals(-1, MobileScannerCameraLensSelector.LENS_TYPE_ANY)
    }

    // ==========================================================================
    // getBestCloseRangeScanningLens tests
    // ==========================================================================
    //
    // LENS_INFO_MINIMUM_FOCUS_DISTANCE is only meaningful on physical sub-cameras,
    // which (like the rest of getSupportedLenses) are not independently selectable
    // through CameraX. getBestCloseRangeScanningLens therefore always returns
    // LENS_TYPE_NORMAL: the main camera has the most capable autofocus on
    // virtually all Android devices.

    @Test
    fun getBestCloseRangeScanningLens_returnsNormal_whenDeviceHasACamera() {
        val cameraManager = Mockito.mock(CameraManager::class.java)
        Mockito.`when`(cameraManager.cameraIdList).thenReturn(arrayOf("0"))

        assertEquals(
            MobileScannerCameraLensSelector.LENS_TYPE_NORMAL,
            MobileScannerCameraLensSelector.getBestCloseRangeScanningLens(cameraManager),
        )
    }

    @Test
    fun getBestCloseRangeScanningLens_returnsNull_whenDeviceHasNoCamera() {
        val cameraManager = Mockito.mock(CameraManager::class.java)
        Mockito.`when`(cameraManager.cameraIdList).thenReturn(arrayOf())

        assertNull(MobileScannerCameraLensSelector.getBestCloseRangeScanningLens(cameraManager))
    }
}
