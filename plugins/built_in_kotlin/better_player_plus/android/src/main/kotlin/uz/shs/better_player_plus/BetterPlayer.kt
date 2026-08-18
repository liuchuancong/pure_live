package uz.shs.better_player_plus

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import uz.shs.better_player_plus.DataSourceUtils.getUserAgent
import uz.shs.better_player_plus.DataSourceUtils.isHTTP
import uz.shs.better_player_plus.DataSourceUtils.getDataSourceFactory
import io.flutter.plugin.common.EventChannel
import io.flutter.view.TextureRegistry.SurfaceTextureEntry
import io.flutter.plugin.common.MethodChannel
import androidx.media3.ui.PlayerNotificationManager
import androidx.work.WorkManager
import androidx.work.WorkInfo
import androidx.media3.ui.PlayerNotificationManager.MediaDescriptionAdapter
import androidx.media3.ui.PlayerNotificationManager.BitmapCallback
import androidx.work.OneTimeWorkRequest
import android.util.Log
import android.view.Surface
import androidx.annotation.OptIn
import androidx.lifecycle.Observer
import androidx.media3.extractor.DefaultExtractorsFactory
import io.flutter.plugin.common.EventChannel.EventSink
import androidx.work.Data
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.ForwardingPlayer
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.Timeline
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.util.Util
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.LoadControl
import androidx.media3.exoplayer.dash.DashMediaSource
import androidx.media3.exoplayer.dash.DefaultDashChunkSource
import androidx.media3.exoplayer.drm.DefaultDrmSessionManager
import androidx.media3.exoplayer.drm.DrmSessionManager
import androidx.media3.exoplayer.drm.DrmSessionManagerProvider
import androidx.media3.exoplayer.drm.DummyExoMediaDrm
import androidx.media3.exoplayer.drm.FrameworkMediaDrm
import androidx.media3.exoplayer.drm.HttpMediaDrmCallback
import androidx.media3.exoplayer.drm.LocalMediaDrmCallback
import androidx.media3.exoplayer.drm.UnsupportedDrmException
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.smoothstreaming.DefaultSsChunkSource
import androidx.media3.exoplayer.smoothstreaming.SsMediaSource
import androidx.media3.exoplayer.source.ClippingMediaSource
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import java.io.File
import java.lang.Exception
import java.lang.IllegalStateException
import java.util.*
import kotlin.math.max
import kotlin.math.min
import androidx.core.net.toUri

@UnstableApi
internal class BetterPlayer(
    context: Context,
    private val eventChannel: EventChannel,
    private val textureEntry: SurfaceTextureEntry,
    customDefaultLoadControl: CustomDefaultLoadControl?,
    result: MethodChannel.Result
) {
    private val exoPlayer: ExoPlayer?
    private val eventSink = QueuingEventSink()
    private val trackSelector: DefaultTrackSelector = DefaultTrackSelector(context)
    private val loadControl: LoadControl
    private var isInitialized = false
    private var surface: Surface? = null
    private var key: String? = null
    private var playerNotificationManager: PlayerNotificationManager? = null
    private var refreshHandler: Handler? = null
    private var refreshRunnable: Runnable? = null
    private var exoPlayerEventListener: Player.Listener? = null
    private var bitmap: Bitmap? = null
    private var mediaSession: MediaSessionCompat? = null
    private var drmSessionManager: DrmSessionManager? = null
    private val workManager: WorkManager
    private val workerObserverMap: HashMap<UUID, Observer<WorkInfo?>>
    private val customDefaultLoadControl: CustomDefaultLoadControl =
        customDefaultLoadControl ?: CustomDefaultLoadControl()
    private var lastSendBufferedPosition = 0L

    init {
        val loadBuilder = DefaultLoadControl.Builder()
        loadBuilder.setBufferDurationsMs(
            this.customDefaultLoadControl.minBufferMs,
            this.customDefaultLoadControl.maxBufferMs,
            this.customDefaultLoadControl.bufferForPlaybackMs,
            this.customDefaultLoadControl.bufferForPlaybackAfterRebufferMs
        )
        loadControl = loadBuilder.build()
        val renderersFactory = DefaultRenderersFactory(context)
            .setEnableDecoderFallback(true)
        exoPlayer = ExoPlayer.Builder(context)
            .setRenderersFactory(renderersFactory)
            .setTrackSelector(trackSelector)
            .setLoadControl(loadControl)
            .build()
        workManager = WorkManager.getInstance(context)
        workerObserverMap = HashMap()
        setupVideoPlayer(eventChannel, textureEntry, result)
    }

    @OptIn(UnstableApi::class)
    fun setDataSource(
        context: Context,
        key: String?,
        dataSource: String?,
        formatHint: String?,
        result: MethodChannel.Result,
        headers: Map<String, String>?,
        useCache: Boolean,
        maxCacheSize: Long,
        maxCacheFileSize: Long,
        overriddenDuration: Long,
        licenseUrl: String?,
        drmHeaders: Map<String, String>?,
        cacheKey: String?,
        clearKey: String?
    ) {
        this.key = key
        isInitialized = false
        val uri = dataSource?.toUri()
        var dataSourceFactory: DataSource.Factory?
        val userAgent = getUserAgent(headers)
        if (!licenseUrl.isNullOrEmpty()) {
            val httpMediaDrmCallback =
                HttpMediaDrmCallback(licenseUrl, DefaultHttpDataSource.Factory())
            if (drmHeaders != null) {
                for ((drmKey, drmValue) in drmHeaders) {
                    httpMediaDrmCallback.setKeyRequestProperty(drmKey, drmValue)
                }
            }
            val drmSchemeUuid = Util.getDrmUuid("widevine")
            if (drmSchemeUuid != null) {
                drmSessionManager = DefaultDrmSessionManager.Builder()
                    .setUuidAndExoMediaDrmProvider(
                        drmSchemeUuid
                    ) { uuid: UUID? ->
                        try {
                            val mediaDrm = FrameworkMediaDrm.newInstance(uuid!!)
                            // Force L3.
                            mediaDrm.setPropertyString("securityLevel", "L3")
                            return@setUuidAndExoMediaDrmProvider mediaDrm
                        } catch (_: UnsupportedDrmException) {
                            return@setUuidAndExoMediaDrmProvider DummyExoMediaDrm()
                        }
                    }
                    .setMultiSession(false)
                    .build(httpMediaDrmCallback)
            }
        } else if (!clearKey.isNullOrEmpty()) {
            drmSessionManager = DefaultDrmSessionManager.Builder()
                .setUuidAndExoMediaDrmProvider(
                    C.CLEARKEY_UUID,
                    FrameworkMediaDrm.DEFAULT_PROVIDER
                ).build(LocalMediaDrmCallback(clearKey.toByteArray()))
        } else {
            drmSessionManager = null
        }
        if (isHTTP(uri)) {
            dataSourceFactory = getDataSourceFactory(userAgent, headers)
            if (useCache && maxCacheSize > 0 && maxCacheFileSize > 0) {
                dataSourceFactory = CacheDataSourceFactory(
                    context,
                    maxCacheSize,
                    maxCacheFileSize,
                    dataSourceFactory
                )
            }
        } else {
            dataSourceFactory = DefaultDataSource.Factory(context)
        }
        val mediaSource = buildMediaSource(uri, dataSourceFactory, formatHint, cacheKey, context)
        if (overriddenDuration != 0L) {
            val clippingMediaSource = ClippingMediaSource.Builder(mediaSource)
                .setStartPositionMs(0)
                .setEndPositionMs(overriddenDuration * 1000)
                .build()
            exoPlayer?.setMediaSource(clippingMediaSource)
        } else {
            exoPlayer?.setMediaSource(mediaSource)
        }
        exoPlayer?.prepare()
        result.success(null)
    }

    fun setupPlayerNotification(
        context: Context, title: String, author: String?,
        imageUrl: String?, notificationChannelName: String?,
        activityName: String
    ) {
        BetterPlayerForegroundService.start(context, title, activityName)
        val mediaDescriptionAdapter: MediaDescriptionAdapter = object : MediaDescriptionAdapter {
            override fun getCurrentContentTitle(player: Player): String {
                return title
            }

            @SuppressLint("UnspecifiedImmutableFlag")
            override fun createCurrentContentIntent(player: Player): PendingIntent? {
                val packageName = context.applicationContext.packageName
                val notificationIntent = Intent()
                notificationIntent.setClassName(
                    packageName,
                    "$packageName.$activityName"
                )
                notificationIntent.flags = (Intent.FLAG_ACTIVITY_CLEAR_TOP
                        or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                return PendingIntent.getActivity(
                    context, 0,
                    notificationIntent,
                    PendingIntent.FLAG_IMMUTABLE
                )
            }

            override fun getCurrentContentText(player: Player): String? {
                return author
            }

            override fun getCurrentLargeIcon(
                player: Player,
                callback: BitmapCallback
            ): Bitmap? {
                if (imageUrl == null) {
                    return null
                }
                if (bitmap != null) {
                    return bitmap
                }
                val imageWorkRequest = OneTimeWorkRequest.Builder(ImageWorker::class.java)
                    .addTag(imageUrl)
                    .setInputData(
                        Data.Builder()
                            .putString(BetterPlayerPlugin.URL_PARAMETER, imageUrl)
                            .build()
                    )
                    .build()
                workManager.enqueue(imageWorkRequest)
                val workInfoObserver = Observer { workInfo: WorkInfo? ->
                    try {
                        if (workInfo != null) {
                            val state = workInfo.state
                            if (state == WorkInfo.State.SUCCEEDED) {
                                val outputData = workInfo.outputData
                                val filePath =
                                    outputData.getString(BetterPlayerPlugin.FILE_PATH_PARAMETER)
                                //Bitmap here is already processed and it's very small, so it won't
                                //break anything.
                                bitmap = BitmapFactory.decodeFile(filePath)
                                bitmap?.let { bitmap ->
                                    callback.onBitmap(bitmap)
                                }
                            }
                            if (state == WorkInfo.State.SUCCEEDED || state == WorkInfo.State.CANCELLED || state == WorkInfo.State.FAILED) {
                                val uuid = imageWorkRequest.id
                                val observer = workerObserverMap.remove(uuid)
                                if (observer != null) {
                                    workManager.getWorkInfoByIdLiveData(uuid)
                                        .removeObserver(observer)
                                }
                            }
                        }
                    } catch (exception: Exception) {
                        Log.e(TAG, "Image select error: $exception")
                    }
                }
                val workerUuid = imageWorkRequest.id
                workManager.getWorkInfoByIdLiveData(workerUuid)
                    .observeForever(workInfoObserver)
                workerObserverMap[workerUuid] = workInfoObserver
                return null
            }
        }
        var playerNotificationChannelName = notificationChannelName
        if (notificationChannelName == null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val importance = NotificationManager.IMPORTANCE_LOW
                val channel = NotificationChannel(
                    DEFAULT_NOTIFICATION_CHANNEL,
                    DEFAULT_NOTIFICATION_CHANNEL, importance
                )
                channel.description = DEFAULT_NOTIFICATION_CHANNEL
                val notificationManager = context.getSystemService(
                    NotificationManager::class.java
                )
                notificationManager.createNotificationChannel(channel)
                playerNotificationChannelName = DEFAULT_NOTIFICATION_CHANNEL
            }
        }

        playerNotificationManager = PlayerNotificationManager.Builder(
            context, NOTIFICATION_ID,
            playerNotificationChannelName!!
        ).setMediaDescriptionAdapter(mediaDescriptionAdapter).build()

        playerNotificationManager?.apply {

            exoPlayer?.let {
                setPlayer(ForwardingPlayer(exoPlayer))
                setUseNextAction(false)
                setUsePreviousAction(false)
                setUseStopAction(false)
            }
        }

        refreshHandler = Handler(Looper.getMainLooper())
        refreshRunnable = Runnable {
            val playbackState: PlaybackStateCompat = if (exoPlayer?.isPlaying == true) {
                PlaybackStateCompat.Builder()
                    .setActions(PlaybackStateCompat.ACTION_SEEK_TO)
                    .setState(PlaybackStateCompat.STATE_PLAYING, position, 1.0f)
                    .build()
            } else {
                PlaybackStateCompat.Builder()
                    .setActions(PlaybackStateCompat.ACTION_SEEK_TO)
                    .setState(PlaybackStateCompat.STATE_PAUSED, position, 1.0f)
                    .build()
            }
            mediaSession?.setPlaybackState(playbackState)
            refreshHandler?.postDelayed(refreshRunnable!!, 1000)
        }
        refreshHandler?.postDelayed(refreshRunnable!!, 0)
        exoPlayerEventListener = object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                mediaSession?.setMetadata(
                    MediaMetadataCompat.Builder()
                        .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, getDuration())
                        .build()
                )
            }
        }
        exoPlayerEventListener?.let { exoPlayerEventListener ->
            exoPlayer?.addListener(exoPlayerEventListener)
        }
        exoPlayer?.seekTo(0)
    }

    fun disposeRemoteNotifications() {
        exoPlayerEventListener?.let { exoPlayerEventListener ->
            exoPlayer?.removeListener(exoPlayerEventListener)
        }
        if (refreshHandler != null) {
            refreshHandler?.removeCallbacksAndMessages(null)
            refreshHandler = null
            refreshRunnable = null
        }
        if (playerNotificationManager != null) {
            playerNotificationManager?.setPlayer(null)
        }
        bitmap = null
    }

    private fun buildMediaSource(
        uri: Uri?,
        mediaDataSourceFactory: DataSource.Factory,
        formatHint: String?,
        cacheKey: String?,
        context: Context
    ): MediaSource {
        val type: Int
        if (formatHint == null) {
            var lastPathSegment = uri?.lastPathSegment
            if (lastPathSegment == null) {
                lastPathSegment = ""
            }
            type = Util.inferContentTypeForExtension(lastPathSegment.split(".")[1])
        } else {
            type = when (formatHint) {
                FORMAT_SS -> C.CONTENT_TYPE_SS
                FORMAT_DASH -> C.CONTENT_TYPE_DASH
                FORMAT_HLS -> C.CONTENT_TYPE_HLS
                FORMAT_OTHER -> C.CONTENT_TYPE_OTHER
                else -> -1
            }
        }
        val mediaItemBuilder = MediaItem.Builder()
        mediaItemBuilder.setUri(uri)
        if (!cacheKey.isNullOrEmpty()) {
            mediaItemBuilder.setCustomCacheKey(cacheKey)
        }
        val mediaItem = mediaItemBuilder.build()
        val drmSessionManagerProvider: DrmSessionManagerProvider? = drmSessionManager?.let { drmSessionManager ->
            DrmSessionManagerProvider { drmSessionManager }
        }

        return when (type) {
            C.CONTENT_TYPE_SS -> SsMediaSource.Factory(
                DefaultSsChunkSource.Factory(mediaDataSourceFactory),
                DefaultDataSource.Factory(context, mediaDataSourceFactory)
            ).apply {
                if (drmSessionManagerProvider != null) {
                    setDrmSessionManagerProvider(drmSessionManagerProvider)
                }
            }.createMediaSource(mediaItem)

            C.CONTENT_TYPE_DASH -> DashMediaSource.Factory(
                DefaultDashChunkSource.Factory(mediaDataSourceFactory),
                DefaultDataSource.Factory(context, mediaDataSourceFactory)
            ).apply {
                if (drmSessionManagerProvider != null) {
                    setDrmSessionManagerProvider(drmSessionManagerProvider)
                }
            }.createMediaSource(mediaItem)

            C.CONTENT_TYPE_HLS -> HlsMediaSource.Factory(mediaDataSourceFactory)
                .apply {
                    if (drmSessionManagerProvider != null) {
                        setDrmSessionManagerProvider(drmSessionManagerProvider)
                    }
                }.createMediaSource(mediaItem)

            C.CONTENT_TYPE_OTHER -> ProgressiveMediaSource.Factory(
                mediaDataSourceFactory,
                DefaultExtractorsFactory()
            ).apply {
                if (drmSessionManagerProvider != null) {
                    setDrmSessionManagerProvider(drmSessionManagerProvider)
                }
            }.createMediaSource(mediaItem)

            else -> {
                throw IllegalStateException("Unsupported type: $type")
            }
        }
    }

    private fun setupVideoPlayer(
        eventChannel: EventChannel, textureEntry: SurfaceTextureEntry, result: MethodChannel.Result
    ) {
        eventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(o: Any?, sink: EventSink) {
                    eventSink.setDelegate(sink)
                }

                override fun onCancel(o: Any?) {
                    eventSink.setDelegate(null)
                }
            },
        )
        surface = Surface(textureEntry.surfaceTexture())
        exoPlayer?.setVideoSurface(surface)
        setAudioAttributes(exoPlayer, true)
        exoPlayer?.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                when (playbackState) {
                    Player.STATE_BUFFERING -> {
                        sendBufferingUpdate(true)
                        val event: MutableMap<String, Any> = HashMap()
                        event["event"] = "bufferingStart"
                        eventSink.success(event)
                    }

                    Player.STATE_READY -> {
                        if (!isInitialized) {
                            isInitialized = true
                            sendInitialized()
                        }
                        val event: MutableMap<String, Any> = HashMap()
                        event["event"] = "bufferingEnd"
                        eventSink.success(event)
                    }

                    Player.STATE_ENDED -> {
                        val event: MutableMap<String, Any?> = HashMap()
                        event["event"] = "completed"
                        event["key"] = key
                        eventSink.success(event)
                    }

                    Player.STATE_IDLE -> {
                        //no-op
                    }
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                eventSink.error("VideoError", "Video player had error $error", "")
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                // Catches play/pause state changes triggered natively (e.g. the
                // media notification's PlayerNotificationManager controls the
                // ExoPlayer instance directly), which otherwise never reach Dart.
                val event: MutableMap<String, Any> = HashMap()
                event["event"] = if (isPlaying) "play" else "pause"
                eventSink.success(event)
            }
        })
        val reply: MutableMap<String, Any> = HashMap()
        reply["textureId"] = textureEntry.id()
        result.success(reply)
    }

    fun sendBufferingUpdate(isFromBufferingStart: Boolean) {
        val bufferedPosition = exoPlayer?.bufferedPosition ?: 0L
        if (isFromBufferingStart || bufferedPosition != lastSendBufferedPosition) {
            val event: MutableMap<String, Any> = HashMap()
            event["event"] = "bufferingUpdate"
            val range: List<Number?> = listOf(0, bufferedPosition)
            // iOS supports a list of buffered ranges, so here is a list with a single range.
            event["values"] = listOf(range)
            eventSink.success(event)
            lastSendBufferedPosition = bufferedPosition
        }
    }

    @Suppress("DEPRECATION")
    private fun setAudioAttributes(exoPlayer: ExoPlayer?, mixWithOthers: Boolean) {
        exoPlayer?.setAudioAttributes(
            AudioAttributes.Builder()
                .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                .build(),
            !mixWithOthers
        )
    }

    fun play() {
        exoPlayer?.playWhenReady = true
    }

    fun pause() {
        exoPlayer?.playWhenReady = false
    }

    fun setLooping(value: Boolean) {
        exoPlayer?.repeatMode = if (value) Player.REPEAT_MODE_ALL else Player.REPEAT_MODE_OFF
    }

    fun setVolume(value: Double) {
        val bracketedValue = max(0.0, min(1.0, value))
            .toFloat()
        exoPlayer?.volume = bracketedValue
    }

    fun setSpeed(value: Double) {
        val bracketedValue = value.toFloat()
        val playbackParameters = PlaybackParameters(bracketedValue)
        exoPlayer?.playbackParameters = playbackParameters
    }

    fun setTrackParameters(width: Int, height: Int, bitrate: Int) {
        val parametersBuilder = trackSelector.buildUponParameters()
        if (width != 0 && height != 0) {
            parametersBuilder.setMaxVideoSize(width, height)
        }
        if (bitrate != 0) {
            parametersBuilder.setMaxVideoBitrate(bitrate)
        }
        if (width == 0 && height == 0 && bitrate == 0) {
            parametersBuilder.clearVideoSizeConstraints()
            parametersBuilder.setMaxVideoBitrate(Int.MAX_VALUE)
        }
        trackSelector.setParameters(parametersBuilder)
    }

    fun seekTo(location: Int) {
        exoPlayer?.seekTo(location.toLong())
    }

    val position: Long
        get() = exoPlayer?.currentPosition ?: 0L

    val absolutePosition: Long
        get() {
            exoPlayer?.let { player ->
                val timeline = player.currentTimeline
                if (!timeline.isEmpty) {
                    val windowStartTimeMs =
                        timeline.getWindow(0, Timeline.Window()).windowStartTimeMs
                    val pos = player.currentPosition
                    return windowStartTimeMs + pos
                }
            }
            return exoPlayer?.currentPosition ?: 0L
        }

    private fun sendInitialized() {
        if (isInitialized) {
            val event: MutableMap<String, Any?> = HashMap()
            event["event"] = "initialized"
            event["key"] = key
            event["duration"] = getDuration()
            exoPlayer?.let { player ->
                player.videoFormat?.let { videoFormat ->
                    var width = videoFormat.width
                    var height = videoFormat.height
                    val rotationDegrees = videoFormat.rotationDegrees
                    // Switch the width/height if video was taken in portrait mode
                    if (rotationDegrees == 90 || rotationDegrees == 270) {
                        width = videoFormat.height
                        height = videoFormat.width
                    }
                    event["width"] = width
                    event["height"] = height
                }
            }
            eventSink.success(event)
        }
    }

    private fun getDuration(): Long = exoPlayer?.duration ?: 0L

    /**
     * Create media session which will be used in notifications, pip mode.
     *
     * @param context                - android context
     * @return - configured MediaSession instance
     */
    @SuppressLint("InlinedApi")
    fun setupMediaSession(context: Context?): MediaSessionCompat? {
        mediaSession?.release()
        context?.let {

            val mediaButtonIntent = Intent(Intent.ACTION_MEDIA_BUTTON)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0, mediaButtonIntent,
                PendingIntent.FLAG_IMMUTABLE
            )
            val mediaSession = MediaSessionCompat(context, TAG, null, pendingIntent)
            mediaSession.setCallback(object : MediaSessionCompat.Callback() {
                override fun onSeekTo(pos: Long) {
                    sendSeekToEvent(pos)
                    super.onSeekTo(pos)
                }
            })
            mediaSession.isActive = true
//            val mediaSessionConnector = MediaSessionConnector(mediaSession)
//            mediaSessionConnector.setPlayer(exoPlayer)
            this.mediaSession = mediaSession
            return mediaSession
        }
        return null

    }

    fun onPictureInPictureStatusChanged(inPip: Boolean) {
        val event: MutableMap<String, Any> = HashMap()
        event["event"] = if (inPip) "pipStart" else "pipStop"
        eventSink.success(event)
    }

    fun disposeMediaSession() {
        if (mediaSession != null) {
            mediaSession?.release()
        }
        mediaSession = null
    }

    fun setAudioTrack(name: String, index: Int) {
        try {
            val mappedTrackInfo = trackSelector.currentMappedTrackInfo
            if (mappedTrackInfo != null) {
                for (rendererIndex in 0 until mappedTrackInfo.rendererCount) {
                    if (mappedTrackInfo.getRendererType(rendererIndex) != C.TRACK_TYPE_AUDIO) {
                        continue
                    }
                    val trackGroupArray = mappedTrackInfo.getTrackGroups(rendererIndex)
                    var hasElementWithoutLabel = false
                    var hasStrangeAudioTrack = false
                    for (groupIndex in 0 until trackGroupArray.length) {
                        val group = trackGroupArray[groupIndex]
                        for (groupElementIndex in 0 until group.length) {
                            val format = group.getFormat(groupElementIndex)
                            if (format.label == null) {
                                hasElementWithoutLabel = true
                            }
                            if (format.id != null && format.id == "1/15") {
                                hasStrangeAudioTrack = true
                            }
                        }
                    }
                    for (groupIndex in 0 until trackGroupArray.length) {
                        val group = trackGroupArray[groupIndex]
                        for (groupElementIndex in 0 until group.length) {
                            val label = group.getFormat(groupElementIndex).label
                            // Exact match by label and provided group index
                            if (name == label && index == groupIndex) {
                                setAudioTrack(rendererIndex, groupIndex, groupElementIndex)
                                return
                            }

                            ///Fallback option
                            if (!hasStrangeAudioTrack && hasElementWithoutLabel && index == groupIndex) {
                                // When labels are missing, default to the first track within the group
                                val safeTrackIndex = if (group.length > 0) 0 else groupElementIndex
                                setAudioTrack(rendererIndex, groupIndex, safeTrackIndex)
                                return
                            }
                            ///Fallback option
                            if (hasStrangeAudioTrack && name == label) {
                                setAudioTrack(rendererIndex, groupIndex, groupElementIndex)
                                return
                            }
                        }
                    }
                }
            }
        } catch (exception: Exception) {
            Log.e(TAG, "setAudioTrack failed$exception")
        }
    }

    private fun setAudioTrack(rendererIndex: Int, groupIndex: Int, trackIndex: Int) {
        val mappedTrackInfo = trackSelector.currentMappedTrackInfo
        if (mappedTrackInfo != null) {
            val trackGroups = mappedTrackInfo.getTrackGroups(rendererIndex)
            if (groupIndex >= 0 && groupIndex < trackGroups.length) {
                val group = trackGroups.get(groupIndex)
                val safeTrackIndex = trackIndex.coerceIn(0, group.length - 1)

		val builder = trackSelector.parameters
    			.buildUpon()
    			.setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, false)
    			.clearOverridesOfType(C.TRACK_TYPE_AUDIO)
    			.addOverride(
        			TrackSelectionOverride(group, safeTrackIndex)
    			)


                trackSelector.setParameters(builder)
            } else {
                Log.e(TAG, "setAudioTrack: groupIndex out of bounds: $groupIndex")
            }
        }
    }

    private fun sendSeekToEvent(positionMs: Long) {
        exoPlayer?.seekTo(positionMs)
        val event: MutableMap<String, Any> = HashMap()
        event["event"] = "seek"
        event["position"] = positionMs
        eventSink.success(event)
    }

    fun setMixWithOthers(mixWithOthers: Boolean) {
        setAudioAttributes(exoPlayer, mixWithOthers)
    }

    fun dispose() {
        disposeMediaSession()
        disposeRemoteNotifications()
        if (isInitialized) {
            exoPlayer?.stop()
        }
        textureEntry.release()
        eventChannel.setStreamHandler(null)
        surface?.release()
        exoPlayer?.release()
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other == null || javaClass != other.javaClass) return false
        val that = other as BetterPlayer
        if (if (exoPlayer != null) exoPlayer != that.exoPlayer else that.exoPlayer != null) return false
        return if (surface != null) surface == that.surface else that.surface == null
    }

    override fun hashCode(): Int {
        var result = exoPlayer?.hashCode() ?: 0
        result = 31 * result + (surface?.hashCode() ?: 0)
        return result
    }

    companion object {
        private const val TAG = "BetterPlayer"
        private const val FORMAT_SS = "ss"
        private const val FORMAT_DASH = "dash"
        private const val FORMAT_HLS = "hls"
        private const val FORMAT_OTHER = "other"
        private const val DEFAULT_NOTIFICATION_CHANNEL = "BETTER_PLAYER_NOTIFICATION"
        private const val NOTIFICATION_ID = 20772077

        //Clear cache without accessing BetterPlayerCache.
        fun clearCache(context: Context?, result: MethodChannel.Result) {
            try {
                context?.let {
                    val file = File(it.cacheDir, "betterPlayerCache")
                    deleteDirectory(file)
                }
                result.success(null)
            } catch (exception: Exception) {
                Log.e(TAG, exception.toString())
                result.error("", "", "")
            }
        }

        private fun deleteDirectory(file: File) {
            if (file.isDirectory) {
                val entries = file.listFiles()
                if (entries != null) {
                    for (entry in entries) {
                        deleteDirectory(entry)
                    }
                }
            }
            if (!file.delete()) {
                Log.e(TAG, "Failed to delete cache dir.")
            }
        }

        //Start pre cache of video. Invoke work manager job and start caching in background.
        fun preCache(
            context: Context?, dataSource: String?, preCacheSize: Long,
            maxCacheSize: Long, maxCacheFileSize: Long, headers: Map<String, String?>,
            cacheKey: String?, result: MethodChannel.Result
        ) {
            val dataBuilder = Data.Builder()
                .putString(BetterPlayerPlugin.URL_PARAMETER, dataSource)
                .putLong(BetterPlayerPlugin.PRE_CACHE_SIZE_PARAMETER, preCacheSize)
                .putLong(BetterPlayerPlugin.MAX_CACHE_SIZE_PARAMETER, maxCacheSize)
                .putLong(BetterPlayerPlugin.MAX_CACHE_FILE_SIZE_PARAMETER, maxCacheFileSize)
            if (cacheKey != null) {
                dataBuilder.putString(BetterPlayerPlugin.CACHE_KEY_PARAMETER, cacheKey)
            }
            for (headerKey in headers.keys) {
                dataBuilder.putString(
                    BetterPlayerPlugin.HEADER_PARAMETER + headerKey,
                    headers[headerKey]
                )
            }
            if (dataSource != null && context != null) {
                val cacheWorkRequest = OneTimeWorkRequest.Builder(CacheWorker::class.java)
                    .addTag(dataSource)
                    .setInputData(dataBuilder.build()).build()
                WorkManager.getInstance(context).enqueue(cacheWorkRequest)
            }
            result.success(null)
        }

        //Stop pre cache of video with given url. If there's no work manager job for given url, then
        //it will be ignored.
        fun stopPreCache(context: Context?, url: String?, result: MethodChannel.Result) {
            if (url != null && context != null) {
                WorkManager.getInstance(context).cancelAllWorkByTag(url)
            }
            result.success(null)
        }
    }

}