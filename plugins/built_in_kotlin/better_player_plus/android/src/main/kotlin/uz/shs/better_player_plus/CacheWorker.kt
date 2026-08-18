package uz.shs.better_player_plus

import android.content.Context
import android.util.Log
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.HttpDataSource
import androidx.media3.datasource.cache.CacheWriter
import uz.shs.better_player_plus.DataSourceUtils.isHTTP
import uz.shs.better_player_plus.DataSourceUtils.getUserAgent
import uz.shs.better_player_plus.DataSourceUtils.getDataSourceFactory
import androidx.work.WorkerParameters
import androidx.work.Worker
import java.lang.Exception
import java.util.*
import androidx.core.net.toUri

/**
 * Cache worker which download part of video and save in cache for future usage. The cache job
 * will be executed in work manager.
 */
@UnstableApi
class CacheWorker(
    private val context: Context,
    params: WorkerParameters
) : Worker(context, params) {
    private var cacheWriter: CacheWriter? = null
    private var lastCacheReportIndex = 0
    override fun doWork(): Result {
        try {
            val data = inputData
            val url = data.getString(BetterPlayerPlugin.URL_PARAMETER)
            val cacheKey = data.getString(BetterPlayerPlugin.CACHE_KEY_PARAMETER)
            val preCacheSize = data.getLong(BetterPlayerPlugin.PRE_CACHE_SIZE_PARAMETER, 0)
            val maxCacheSize = data.getLong(BetterPlayerPlugin.MAX_CACHE_SIZE_PARAMETER, 0)
            val maxCacheFileSize = data.getLong(BetterPlayerPlugin.MAX_CACHE_FILE_SIZE_PARAMETER, 0)
            val headers: MutableMap<String, String> = HashMap()
            for (key in data.keyValueMap.keys) {
                if (key.contains(BetterPlayerPlugin.HEADER_PARAMETER)) {
                    val keySplit =
                        key.split(BetterPlayerPlugin.HEADER_PARAMETER.toRegex()).toTypedArray()[0]
                    headers[keySplit] = Objects.requireNonNull(data.keyValueMap[key]) as String
                }
            }
            val uri = url?.toUri()
            if (uri != null && isHTTP(uri)) {
                val userAgent = getUserAgent(headers)
                val dataSourceFactory = getDataSourceFactory(userAgent, headers)
                var dataSpec = DataSpec(uri, 0, preCacheSize)
                if (!cacheKey.isNullOrEmpty()) {
                    dataSpec = dataSpec.buildUpon().setKey(cacheKey).build()
                }
                val cacheDataSourceFactory = CacheDataSourceFactory(
                    context,
                    maxCacheSize,
                    maxCacheFileSize,
                    dataSourceFactory
                )
                cacheWriter = CacheWriter(
                    cacheDataSourceFactory.createDataSource(),
                    dataSpec,
                    null
                ) { _: Long, bytesCached: Long, _: Long ->
                    val completedData = (bytesCached * 100f / preCacheSize).toDouble()
                    if (completedData >= lastCacheReportIndex * 10) {
                        lastCacheReportIndex += 1
                        Log.d(
                            TAG,
                            "Completed pre cache of " + url + ": " + completedData.toInt() + "%"
                        )
                    }
                }
                cacheWriter?.cache()
            } else {
                Log.e(TAG, "Preloading only possible for remote data sources")
                return Result.failure()
            }
        } catch (exception: Exception) {
            Log.e(TAG, exception.toString())
            return if (exception is HttpDataSource.HttpDataSourceException) {
                Result.success()
            } else {
                Result.failure()
            }
        }
        return Result.success()
    }

    override fun onStopped() {
        try {
            cacheWriter?.cancel()
            super.onStopped()
        } catch (exception: Exception) {
            Log.e(TAG, exception.toString())
        }
    }

    companion object {
        private const val TAG = "CacheWorker"
    }
}