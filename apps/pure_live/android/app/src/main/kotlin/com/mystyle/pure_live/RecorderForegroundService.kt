package com.mystyle.purelive

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import java.util.concurrent.atomic.AtomicLong

/**
 * Foreground lifetime for an active recording. The actual recorder stays in Dart;
 * this service only makes that work visible to Android as data synchronization.
 */
class RecorderForegroundService : Service() {
    internal interface Listener {
        fun onForegroundReady(generation: Long)
        fun onStartFailed(generation: Long, message: String)
        fun onTimedOut(generation: Long)
        fun onStopped(generation: Long)
    }

    companion object {
        private const val ACTION_START = "com.mystyle.purelive.recorder.START"
        private const val EXTRA_GENERATION = "generation"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val CHANNEL_ID = "pure_live_recording"
        private const val CHANNEL_NAME = "Recording"
        private const val NOTIFICATION_ID = 20260906

        private val nextGeneration = AtomicLong(0)
        private val mainHandler = Handler(Looper.getMainLooper())
        private val listeners = mutableMapOf<Long, Listener>()
        private val cancelledGenerations = mutableSetOf<Long>()
        private var runningService: RecorderForegroundService? = null

        internal fun newGeneration(): Long = nextGeneration.incrementAndGet()

        internal fun createStartIntent(
            context: android.content.Context,
            generation: Long,
            title: String,
            text: String,
        ): Intent = Intent(context, RecorderForegroundService::class.java).apply {
            action = ACTION_START
            putExtra(EXTRA_GENERATION, generation)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_TEXT, text)
        }

        internal fun observe(generation: Long, listener: Listener) {
            check(Looper.myLooper() == Looper.getMainLooper())
            listeners[generation] = listener
        }

        internal fun forget(generation: Long) {
            check(Looper.myLooper() == Looper.getMainLooper())
            listeners.remove(generation)
        }

        internal fun acknowledgeStopped(generation: Long) {
            check(Looper.myLooper() == Looper.getMainLooper())
            cancelledGenerations.remove(generation)
        }

        /** Cancels only this owner generation, including a start not yet delivered. */
        internal fun cancel(generation: Long) {
            check(Looper.myLooper() == Looper.getMainLooper())
            val service = runningService?.takeIf { it.generation == generation }
            if (service == null) {
                cancelledGenerations += generation
            } else {
                service.stopGeneration(generation)
            }
        }

        /** Debug probe: injects the framework timeout callback, not its six-hour clock. */
        internal fun debugInjectTimeout(): Boolean {
            check(Looper.myLooper() == Looper.getMainLooper())
            if (!BuildConfig.DEBUG) return false
            val service = runningService?.takeIf {
                it.generation != 0L && !it.timeoutReported
            } ?: return false
            service.onTimeout(0, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            return true
        }

        /** Debug probe: requests an unexpected service teardown through onDestroy. */
        internal fun debugStopActiveService(): Boolean {
            check(Looper.myLooper() == Looper.getMainLooper())
            if (!BuildConfig.DEBUG) return false
            val service = runningService?.takeIf { it.generation != 0L } ?: return false
            service.stopSelf()
            return true
        }


        private fun notifyReady(generation: Long) {
            mainHandler.post { listeners[generation]?.onForegroundReady(generation) }
        }

        private fun notifyStartFailed(generation: Long, message: String) {
            mainHandler.post { listeners[generation]?.onStartFailed(generation, message) }
        }

        private fun notifyTimedOut(generation: Long) {
            mainHandler.post { listeners[generation]?.onTimedOut(generation) }
        }

        private fun notifyStopped(generation: Long) {
            mainHandler.post { listeners[generation]?.onStopped(generation) }
        }
    }

    private var generation: Long = 0
    private var timeoutReported = false

    override fun onCreate() {
        super.onCreate()
        runningService = this
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != ACTION_START) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        val requestedGeneration = intent.getLongExtra(EXTRA_GENERATION, 0)
        if (requestedGeneration == 0L) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        if (cancelledGenerations.remove(requestedGeneration)) {
            if (generation == 0L) {
                // This start created the service, so the coordinator must wait
                // for the matching onDestroy rather than a synthetic stop ACK.
                generation = requestedGeneration
                stopSelf(startId)
            } else {
                // A different generation owns the already-running singleton;
                // this cancelled request never acquired service ownership.
                notifyStopped(requestedGeneration)
            }
            return START_NOT_STICKY
        }
        if (generation != 0L && generation != requestedGeneration) {
            notifyStartFailed(requestedGeneration, "A recording foreground service is already active")
            notifyStopped(requestedGeneration)
            return START_NOT_STICKY
        }

        generation = requestedGeneration
        timeoutReported = false
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
        val text = intent.getStringExtra(EXTRA_TEXT).orEmpty()
        try {
            val notification = buildNotification(title, text)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            notifyReady(requestedGeneration)
        } catch (exception: Exception) {
            notifyStartFailed(
                requestedGeneration,
                exception.localizedMessage ?: "Foreground service startup failed",
            )
            stopSelf(startId)
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // Android 15 limits background dataSync foreground services to a shared
    // six-hour budget per 24 hours. Android requires a prompt stop here.
    override fun onTimeout(startId: Int, fgsType: Int) {
        if (fgsType != ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC) return
        val timedOutGeneration = generation
        if (timedOutGeneration == 0L || timeoutReported) return
        timeoutReported = true
        notifyTimedOut(timedOutGeneration)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        val stoppedGeneration = generation
        generation = 0
        cancelledGenerations.remove(stoppedGeneration)
        if (runningService === this) runningService = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        if (stoppedGeneration != 0L) notifyStopped(stoppedGeneration)
        super.onDestroy()
    }

    private fun stopGeneration(requestedGeneration: Long) {
        if (generation != requestedGeneration) return
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun createNotificationChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Active live-stream recording"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(title: String, text: String): Notification {
        val openApp = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(pendingIntent)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }
}
