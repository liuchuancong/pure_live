package uz.shs.better_player_plus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service that keeps the app alive during background playback.
 * This prevents Android 16's stricter Doze mode from killing network connections
 * when playing HLS live streams in the background.
 */
class BetterPlayerForegroundService : Service() {

    companion object {
        private const val TAG = "BPForegroundService"
        private const val NOTIFICATION_ID = 20772078
        private const val CHANNEL_ID = "better_player_channel"
        private const val CHANNEL_NAME = "Better Player Background Playback"
        private const val WIFI_LOCK_TAG = "better_player_plus:wifi_lock"
        private const val WAKE_LOCK_TAG = "better_player_plus:wake_lock"

        private const val EXTRA_TITLE = "title"
        private const val EXTRA_ACTIVITY_NAME = "activityName"

        fun start(context: Context, title: String?, activityName: String?) {
            try {
                val intent = Intent(context, BetterPlayerForegroundService::class.java).apply {
                    putExtra(EXTRA_TITLE, title ?: "Playing media")
                    putExtra(EXTRA_ACTIVITY_NAME, activityName ?: "MainActivity")
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start foreground service", e)
            }
        }

        fun stop(context: Context) {
            try {
                val intent = Intent(context, BetterPlayerForegroundService::class.java)
                context.stopService(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop foreground service", e)
            }
        }
    }

    private var wifiLock: WifiManager.WifiLock? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Playing media"
        val activityName = intent?.getStringExtra(EXTRA_ACTIVITY_NAME) ?: "MainActivity"

        createNotificationChannel()
        val notification = buildNotification(title, activityName)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        acquireWifiLock()
        acquireWakeLock()

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releaseWifiLock()
        releaseWakeLock()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        try {
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(NOTIFICATION_ID)
        } catch (e: Exception) {
            Log.e(TAG, "Error removing notification", e)
        } finally {
            stopSelf()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps media playing in the background"
                setShowBadge(false)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(title: String, activityName: String): Notification {
        val packageName = applicationContext.packageName
        val notificationIntent = Intent().apply {
            setClassName(packageName, "$packageName.$activityName")
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText("Playing in background")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    setCategory(Notification.CATEGORY_SERVICE)
                }
            }
            .build()
    }

    private fun acquireWifiLock() {
        try {
            val wifiManager =
                applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            wifiLock = wifiManager?.createWifiLock(
                WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                WIFI_LOCK_TAG
            )?.apply {
                setReferenceCounted(false)
                acquire()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire WiFi lock", e)
        }
    }

    private fun releaseWifiLock() {
        try {
            wifiLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
            wifiLock = null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release WiFi lock", e)
        }
    }

    private fun acquireWakeLock() {
        try {
            val powerManager =
                applicationContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
            wakeLock = powerManager?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                WAKE_LOCK_TAG
            )?.apply {
                setReferenceCounted(false)
                acquire(10 * 60 * 1000L) // 10 minutes timeout
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire wake lock", e)
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
            wakeLock = null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release wake lock", e)
        }
    }
}
