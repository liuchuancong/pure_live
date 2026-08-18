package uz.shs.better_player_plus

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import androidx.media3.common.util.UnstableApi
import androidx.work.Data
import androidx.work.WorkerParameters
import androidx.work.Worker
import java.io.FileOutputStream
import java.io.InputStream
import java.lang.Exception
import java.net.HttpURLConnection
import java.net.URL
import androidx.core.net.toUri

@UnstableApi
class ImageWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {
    override fun doWork(): Result {
        return try {
            val imageUrl = inputData.getString(BetterPlayerPlugin.URL_PARAMETER)
                ?: return Result.failure()
            val bitmap: Bitmap? = if (DataSourceUtils.isHTTP(imageUrl.toUri())) {
                getBitmapFromExternalURL(imageUrl)
            } else {
                getBitmapFromInternalURL(imageUrl)
            }
            val fileName = imageUrl.hashCode().toString() + IMAGE_EXTENSION
            val filePath = applicationContext.cacheDir.absolutePath + fileName
            if (bitmap == null) {
                return Result.failure()
            }
            val out = FileOutputStream(filePath)
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            val data =
                Data.Builder().putString(BetterPlayerPlugin.FILE_PATH_PARAMETER, filePath).build()
            Result.success(data)
        } catch (e: Exception) {
            e.printStackTrace()
            Result.failure()
        }
    }

    private fun getBitmapFromExternalURL(src: String): Bitmap? {
        var inputStream: InputStream? = null
        return try {
            val url = URL(src)
            var connection = url.openConnection() as HttpURLConnection
            inputStream = connection.inputStream
            val options = BitmapFactory.Options()
            options.inJustDecodeBounds = true
            BitmapFactory.decodeStream(inputStream, null, options)
            inputStream.close()
            connection = url.openConnection() as HttpURLConnection
            inputStream = connection.inputStream
            options.inSampleSize = calculateBitmapInSampleSize(
                options
            )
            options.inJustDecodeBounds = false
            BitmapFactory.decodeStream(inputStream, null, options)
        } catch (_: Exception) {
            Log.e(TAG, "Failed to get bitmap from external url: $src")
            null
        } finally {
            try {
                inputStream?.close()
            } catch (_: Exception) {
                Log.e(TAG, "Failed to close bitmap input stream/")
            }
        }
    }

    private fun calculateBitmapInSampleSize(
        options: BitmapFactory.Options
    ): Int {
        val height = options.outHeight
        val width = options.outWidth
        var inSampleSize = 1
        if (height > DEFAULT_NOTIFICATION_IMAGE_SIZE_PX
            || width > DEFAULT_NOTIFICATION_IMAGE_SIZE_PX
        ) {
            val halfHeight = height / 2
            val halfWidth = width / 2
            while (halfHeight / inSampleSize >= DEFAULT_NOTIFICATION_IMAGE_SIZE_PX
                && halfWidth / inSampleSize >= DEFAULT_NOTIFICATION_IMAGE_SIZE_PX
            ) {
                inSampleSize *= 2
            }
        }
        return inSampleSize
    }

    private fun getBitmapFromInternalURL(src: String): Bitmap? {
        return try {
            val options = BitmapFactory.Options()
            options.inJustDecodeBounds = true
            options.inSampleSize = calculateBitmapInSampleSize(
                options
            )
            options.inJustDecodeBounds = false
            BitmapFactory.decodeFile(src)
        } catch (_: Exception) {
            Log.e(TAG, "Failed to get bitmap from internal url: $src")
            null
        }
    }

    companion object {
        private const val TAG = "ImageWorker"
        private const val IMAGE_EXTENSION = ".png"
        private const val DEFAULT_NOTIFICATION_IMAGE_SIZE_PX = 256
    }
}