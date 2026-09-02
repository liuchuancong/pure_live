package com.mystyle.purelive

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class RecordingForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "recording_foreground"
        private const val NOTIFICATION_ID = 2001

        private const val WAKE_LOCK_TAG =
            "com.mystyle.purelive:recording"

        private const val WIFI_LOCK_TAG =
            "com.mystyle.purelive:recording"
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onCreate() {
        super.onCreate()

        // 必须先创建通知 Channel
        createNotificationChannel()

        // 启动 Foreground Service
        startForeground(
            NOTIFICATION_ID,
            buildNotification(),
        )

        // 保持 CPU 唤醒
        acquireWakeLock()

        // 保持 WiFi 网络
        acquireWifiLock()
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        releaseWifiLock()
        releaseWakeLock()

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    // ============================================================
    // Notification
    // ============================================================

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(
            this,
            CHANNEL_ID,
        )
            .setContentTitle("纯粹直播")
            .setContentText("正在录制直播")
             .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setShowWhen(false)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager =
            getSystemService(NotificationManager::class.java)

        val channel = NotificationChannel(
            CHANNEL_ID,
            "录制后台服务",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "用于保持直播录制任务在后台继续运行"
            setShowBadge(false)
        }

        manager.createNotificationChannel(channel)
    }

    // ============================================================
    // WakeLock
    // ============================================================

    @Suppress("DEPRECATION")
    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) {
            return
        }

        val powerManager =
            getSystemService(POWER_SERVICE)
                as PowerManager

        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            WAKE_LOCK_TAG,
        ).apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
        } catch (_: Exception) {
        }

        wakeLock = null
    }

    // ============================================================
    // WifiLock
    // ============================================================

    @Suppress("DEPRECATION")
    private fun acquireWifiLock() {
        if (wifiLock?.isHeld == true) {
            return
        }

        val wifiManager =
            applicationContext.getSystemService(
                WIFI_SERVICE,
            ) as WifiManager

        val mode =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
            } else {
                WifiManager.WIFI_MODE_FULL_HIGH_PERF
            }

        wifiLock = wifiManager.createWifiLock(
            mode,
            WIFI_LOCK_TAG,
        ).apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseWifiLock() {
        try {
            wifiLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
        } catch (_: Exception) {
        }

        wifiLock = null
    }
}