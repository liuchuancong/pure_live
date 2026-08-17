package dev.steenbakker.mobile_scanner.utils

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import androidx.core.graphics.createBitmap

// Efficiently invert bitmap colors using ColorMatrix
fun invertBitmapColors(bitmap: Bitmap): Bitmap {
    val colorMatrix = ColorMatrix().apply {
        set(floatArrayOf(
            -1f, 0f, 0f, 0f, 255f,  // Red
            0f, -1f, 0f, 0f, 255f,  // Green
            0f, 0f, -1f, 0f, 255f,  // Blue
            0f, 0f, 0f, 1f, 0f      // Alpha
        ))
    }
    val paint = Paint().apply { colorFilter = ColorMatrixColorFilter(colorMatrix) }

    val invertedBitmap = createBitmap(bitmap.width, bitmap.height, bitmap.config!!)
    val canvas = Canvas(invertedBitmap)
    canvas.drawBitmap(bitmap, 0f, 0f, paint)

    return invertedBitmap
}

fun rotateBitmap(bitmap: Bitmap, rotationDegrees: Int): Bitmap {
    val matrix = Matrix()
    matrix.postRotate(rotationDegrees.toFloat())
    return Bitmap.createBitmap(
        bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), matrix,
        true
    )
}