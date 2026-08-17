package uz.shs.better_player_plus

import android.content.Context
import android.util.Log
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import java.io.File
import java.lang.Exception

@UnstableApi
object BetterPlayerCache {
    @Volatile
    private var instance: SimpleCache? = null
    fun createCache(context: Context, cacheFileSize: Long): SimpleCache? {
        if (instance == null) {
            synchronized(BetterPlayerCache::class.java) {
                if (instance == null) {
                    instance = SimpleCache(
                        File(context.cacheDir, "betterPlayerCache"),
                        LeastRecentlyUsedCacheEvictor(cacheFileSize),
                        StandaloneDatabaseProvider(context)
                    )
                }
            }
        }
        return instance
    }

    @JvmStatic
    fun releaseCache() {
        try {
            if (instance != null) {
                instance!!.release()
                instance = null
            }
        } catch (exception: Exception) {
            Log.e("BetterPlayerCache", exception.toString())
        }
    }
}