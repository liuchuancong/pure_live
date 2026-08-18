import 'dart:async';
import 'dart:io';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:better_player_plus/src/configuration/better_player_controller_event.dart';
import 'package:better_player_plus/src/core/better_player_utils.dart';
import 'package:better_player_plus/src/enum/aspect_enum.dart';
import 'package:better_player_plus/src/subtitles/better_player_subtitle.dart';
import 'package:better_player_plus/src/subtitles/better_player_subtitles_factory.dart';
import 'package:better_player_plus/src/video_player/video_player.dart';
import 'package:better_player_plus/src/video_player/video_player_platform_interface.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

///Class used to control overall Better Player behavior. Main class to change
///state of Better Player.
class BetterPlayerController {
  BetterPlayerController(
    this.betterPlayerConfiguration, {
    this.betterPlayerPlaylistConfiguration,
    BetterPlayerDataSource? betterPlayerDataSource,
  }) {
    _betterPlayerControlsConfiguration = betterPlayerConfiguration.controlsConfiguration;
    _eventListeners.add(eventListener);
    if (betterPlayerDataSource != null) {
      setupDataSource(betterPlayerDataSource);
    }
  }

  static const String _durationParameter = 'duration';
  static const String _progressParameter = 'progress';
  static const String _bufferedParameter = 'buffered';
  static const String _volumeParameter = 'volume';
  static const String _speedParameter = 'speed';
  static const String _dataSourceParameter = 'dataSource';
  static const String _authorizationHeader = 'Authorization';

  ///General configuration used in controller instance.
  final BetterPlayerConfiguration betterPlayerConfiguration;

  ///Playlist configuration used in controller instance.
  final BetterPlayerPlaylistConfiguration? betterPlayerPlaylistConfiguration;

  ///List of event listeners, which listen to events.
  final List<void Function(BetterPlayerEvent)?> _eventListeners = [];

  ///List of files to delete once player disposes.
  final List<File> _tempFiles = [];

  ///Stream controller which emits stream when control visibility changes.
  final StreamController<bool> _controlsVisibilityStreamController = StreamController.broadcast();

  ///Instance of video player controller which is adapter used to communicate
  ///between flutter high level code and lower level native code.
  VideoPlayerController? videoPlayerController;

  ///Controls configuration
  late BetterPlayerControlsConfiguration _betterPlayerControlsConfiguration;

  ///Controls configuration
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration => _betterPlayerControlsConfiguration;

  ///Expose all active eventListeners
  List<void Function(BetterPlayerEvent)?> get eventListeners => _eventListeners.sublist(1);

  /// Defines a event listener where video player events will be send.
  void Function(BetterPlayerEvent)? get eventListener => betterPlayerConfiguration.eventListener;

  ///Flag used to store full screen mode state.
  bool _isFullScreen = false;

  ///Flag used to store full screen mode state.
  bool get isFullScreen => _isFullScreen;

  ///Time when last progress event was sent
  int _lastPositionSelection = 0;

  ///Currently used data source in player.
  BetterPlayerDataSource? _betterPlayerDataSource;

  ///Currently used data source in player.
  BetterPlayerDataSource? get betterPlayerDataSource => _betterPlayerDataSource;

  ///List of BetterPlayerSubtitlesSources.
  final List<BetterPlayerSubtitlesSource> _betterPlayerSubtitlesSourceList = [];

  ///List of BetterPlayerSubtitlesSources.
  List<BetterPlayerSubtitlesSource> get betterPlayerSubtitlesSourceList => _betterPlayerSubtitlesSourceList;
  BetterPlayerSubtitlesSource? _betterPlayerSubtitlesSource;

  ///Currently used subtitles source.
  BetterPlayerSubtitlesSource? get betterPlayerSubtitlesSource => _betterPlayerSubtitlesSource;

  ///Subtitles lines for current data source.
  List<BetterPlayerSubtitle> subtitlesLines = [];

  ///List of tracks available for current data source. Used only for HLS / DASH.
  List<BetterPlayerAsmsTrack> _betterPlayerAsmsTracks = [];

  ///List of tracks available for current data source. Used only for HLS / DASH.
  List<BetterPlayerAsmsTrack> get betterPlayerAsmsTracks => _betterPlayerAsmsTracks;

  ///Currently selected player track. Used only for HLS / DASH.
  BetterPlayerAsmsTrack? _betterPlayerAsmsTrack;

  ///Currently selected player track. Used only for HLS / DASH.
  BetterPlayerAsmsTrack? get betterPlayerAsmsTrack => _betterPlayerAsmsTrack;

  ///Timer for next video. Used in playlist.
  Timer? _nextVideoTimer;

  ///Time for next video.
  int? _nextVideoTime;

  ///Stream controller which emits next video time.
  final StreamController<int?> _nextVideoTimeStreamController = StreamController.broadcast();

  Stream<int?> get nextVideoTimeStream => _nextVideoTimeStreamController.stream;

  ///Has player been disposed.
  bool _disposed = false;

  ///Was player playing before automatic pause.
  bool? _wasPlayingBeforePause;

  ///Currently used translations
  BetterPlayerTranslations translations = BetterPlayerTranslations();

  ///Has current data source started
  bool _hasCurrentDataSourceStarted = false;

  ///Has current data source initialized
  bool _hasCurrentDataSourceInitialized = false;

  ///Stream which sends flag whenever visibility of controls changes
  Stream<bool> get controlsVisibilityStream => _controlsVisibilityStreamController.stream;

  ///Current app lifecycle state.
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  ///Flag which determines if controls (UI interface) is shown. When false,
  ///UI won't be shown (show only player surface).
  bool _controlsEnabled = true;

  ///Flag which determines if controls (UI interface) is shown. When false,
  ///UI won't be shown (show only player surface).
  bool get controlsEnabled => _controlsEnabled;

  ///Overridden aspect ratio which will be used instead of aspect ratio passed
  ///in configuration.
  double? _overriddenAspectRatio;

  ///Overridden fit which will be used instead of fit passed in configuration.
  BoxFit? _overriddenFit;

  ///Was Picture in Picture opened.
  bool _wasInPipMode = false;

  ///Was player in fullscreen before Picture in Picture opened.
  bool _wasInFullScreenBeforePiP = false;

  ///Was controls enabled before Picture in Picture opened.
  bool _wasControlsEnabledBeforePiP = false;

  ///GlobalKey of the BetterPlayer widget
  GlobalKey? _betterPlayerGlobalKey;

  ///Getter of the GlobalKey
  GlobalKey? get betterPlayerGlobalKey => _betterPlayerGlobalKey;

  ///StreamSubscription for VideoEvent listener
  StreamSubscription<VideoEvent>? _videoEventStreamSubscription;

  ///Are controls always visible
  bool _controlsAlwaysVisible = false;

  ///Are controls always visible
  bool get controlsAlwaysVisible => _controlsAlwaysVisible;

  ///List of all possible audio tracks returned from ASMS stream
  List<BetterPlayerAsmsAudioTrack>? _betterPlayerAsmsAudioTracks;

  ///List of all possible audio tracks returned from ASMS stream
  List<BetterPlayerAsmsAudioTrack>? get betterPlayerAsmsAudioTracks => _betterPlayerAsmsAudioTracks;

  ///Selected ASMS audio track
  BetterPlayerAsmsAudioTrack? _betterPlayerAsmsAudioTrack;

  ///Selected ASMS audio track
  BetterPlayerAsmsAudioTrack? get betterPlayerAsmsAudioTrack => _betterPlayerAsmsAudioTrack;

  ///Selected videoPlayerValue when error occurred.
  VideoPlayerValue? _videoPlayerValueOnError;

  ///Flag which holds information about player visibility
  bool _isPlayerVisible = true;

  final StreamController<BetterPlayerControllerEvent> _controllerEventStreamController = StreamController.broadcast();

  ///Stream of internal controller events. Shouldn't be used inside app. For
  ///normal events, use eventListener.
  Stream<BetterPlayerControllerEvent> get controllerEventStream => _controllerEventStreamController.stream;

  ///Flag which determines whether are ASMS segments loading
  bool _asmsSegmentsLoading = false;

  ///List of loaded ASMS segments
  final List<String> _asmsSegmentsLoaded = [];

  ///Currently displayed [BetterPlayerSubtitle].
  BetterPlayerSubtitle? renderedSubtitle;

  ///Get BetterPlayerController from context. Used in InheritedWidget.
  static BetterPlayerController of(BuildContext context) {
    final betterPLayerControllerProvider = context
        .dependOnInheritedWidgetOfExactType<BetterPlayerControllerProvider>()!;

    return betterPLayerControllerProvider.controller;
  }

  ///Setup new data source in Better Player.
  Future<void> setupDataSource(BetterPlayerDataSource betterPlayerDataSource) async {
    postEvent(
      BetterPlayerEvent(
        BetterPlayerEventType.setupDataSource,
        parameters: <String, dynamic>{_dataSourceParameter: betterPlayerDataSource},
      ),
    );
    _postControllerEvent(BetterPlayerControllerEvent.setupDataSource);
    _hasCurrentDataSourceStarted = false;
    _hasCurrentDataSourceInitialized = false;
    _betterPlayerDataSource = betterPlayerDataSource;
    _betterPlayerSubtitlesSourceList.clear();

    ///Build videoPlayerController if null
    if (videoPlayerController == null) {
      videoPlayerController = VideoPlayerController(
        bufferingConfiguration: betterPlayerDataSource.bufferingConfiguration,
      );
      videoPlayerController?.addListener(_onVideoPlayerChanged);
    }

    ///Clear asms tracks
    betterPlayerAsmsTracks.clear();

    ///Setup subtitles
    final List<BetterPlayerSubtitlesSource>? betterPlayerSubtitlesSourceList = betterPlayerDataSource.subtitles;
    if (betterPlayerSubtitlesSourceList != null) {
      _betterPlayerSubtitlesSourceList.addAll(betterPlayerDataSource.subtitles!);
    }

    if (_isDataSourceAsms(betterPlayerDataSource)) {
      unawaited(
        _setupAsmsDataSource(betterPlayerDataSource).then((value) {
          _setupSubtitles();
        }),
      );
    } else {
      _setupSubtitles();
    }

    ///Process data source
    await _setupDataSource(betterPlayerDataSource);
    await setTrack(BetterPlayerAsmsTrack.defaultTrack());
  }

  ///Configure subtitles based on subtitles source.
  void _setupSubtitles() {
    _betterPlayerSubtitlesSourceList.add(BetterPlayerSubtitlesSource(type: BetterPlayerSubtitlesSourceType.none));
    final defaultSubtitle = _betterPlayerSubtitlesSourceList.firstWhereOrNull(
      (element) => element.selectedByDefault ?? false,
    );

    ///Setup subtitles (none is default)
    setupSubtitleSource(defaultSubtitle ?? _betterPlayerSubtitlesSourceList.last, sourceInitialize: true);
  }

  ///Check if given [betterPlayerDataSource] is HLS / DASH-type data source.
  bool _isDataSourceAsms(BetterPlayerDataSource betterPlayerDataSource) =>
      (BetterPlayerAsmsUtils.isDataSourceHls(betterPlayerDataSource.url) ||
          betterPlayerDataSource.videoFormat == BetterPlayerVideoFormat.hls) ||
      (BetterPlayerAsmsUtils.isDataSourceDash(betterPlayerDataSource.url) ||
          betterPlayerDataSource.videoFormat == BetterPlayerVideoFormat.dash);

  ///Configure HLS / DASH data source based on provided data source and configuration.
  ///This method configures tracks, subtitles and audio tracks from given
  ///master playlist.
  Future<void> _setupAsmsDataSource(BetterPlayerDataSource source) async {
    final String? data = await BetterPlayerAsmsUtils.getDataFromUrl(betterPlayerDataSource!.url, _getHeaders());
    if (data != null) {
      final BetterPlayerAsmsDataHolder response = await BetterPlayerAsmsUtils.parse(data, betterPlayerDataSource!.url);

      /// Load tracks
      if (_betterPlayerDataSource?.useAsmsTracks ?? false) {
        _betterPlayerAsmsTracks = response.tracks ?? [];
      }

      /// Load subtitles
      if (betterPlayerDataSource?.useAsmsSubtitles ?? false) {
        final List<BetterPlayerAsmsSubtitle> asmsSubtitles = response.subtitles ?? [];
        for (final asmsSubtitle in asmsSubtitles) {
          _betterPlayerSubtitlesSourceList.add(
            BetterPlayerSubtitlesSource(
              type: BetterPlayerSubtitlesSourceType.network,
              name: asmsSubtitle.name,
              urls: asmsSubtitle.realUrls,
              asmsIsSegmented: asmsSubtitle.isSegmented,
              asmsSegmentsTime: asmsSubtitle.segmentsTime,
              asmsSegments: asmsSubtitle.segments,
              selectedByDefault: asmsSubtitle.isDefault,
            ),
          );
        }
      }

      ///Load audio tracks
      if ((betterPlayerDataSource?.useAsmsAudioTracks ?? false) && _isDataSourceAsms(betterPlayerDataSource!)) {
        _betterPlayerAsmsAudioTracks = response.audios ?? [];
        if (_betterPlayerAsmsAudioTracks?.isNotEmpty ?? false) {
          setAudioTrack(_betterPlayerAsmsAudioTracks!.first);
        }
      }
    }
  }

  ///Setup subtitles to be displayed from given subtitle source.
  ///If subtitles source is segmented then don't load videos at start. Videos
  ///will load with just in time policy.
  Future<void> setupSubtitleSource(BetterPlayerSubtitlesSource subtitlesSource, {bool sourceInitialize = false}) async {
    _betterPlayerSubtitlesSource = subtitlesSource;
    subtitlesLines.clear();
    _asmsSegmentsLoaded.clear();
    _asmsSegmentsLoading = false;

    if (subtitlesSource.type != BetterPlayerSubtitlesSourceType.none) {
      if (subtitlesSource.asmsIsSegmented ?? false) {
        return;
      }
      final subtitlesParsed = await BetterPlayerSubtitlesFactory.parseSubtitles(subtitlesSource);
      subtitlesLines.addAll(subtitlesParsed);
    }

    _postEvent(BetterPlayerEvent(BetterPlayerEventType.changedSubtitles));
    if (!_disposed && !sourceInitialize) {
      _postControllerEvent(BetterPlayerControllerEvent.changeSubtitles);
    }
  }

  ///Load ASMS subtitles segments for given [position].
  ///Segments are being loaded within range (current video position;endPosition)
  ///where endPosition is based on time segment detected in HLS playlist. If
  ///time segment is not present then 5000 ms will be used. Also time segment
  ///is multiplied by 5 to increase window of duration.
  ///Segments are also cached, so same segment won't load twice. Only one
  ///pack of segments can be load at given time.
  Future<void> _loadAsmsSubtitlesSegments(Duration position) async {
    try {
      if (_asmsSegmentsLoading) {
        return;
      }
      _asmsSegmentsLoading = true;
      final BetterPlayerSubtitlesSource? source = _betterPlayerSubtitlesSource;
      final Duration loadDurationEnd = Duration(
        milliseconds: position.inMilliseconds + 5 * (_betterPlayerSubtitlesSource?.asmsSegmentsTime ?? 5000),
      );

      final segmentsToLoad = _betterPlayerSubtitlesSource?.asmsSegments
          ?.where(
            (segment) =>
                segment.startTime > position &&
                segment.endTime < loadDurationEnd &&
                !_asmsSegmentsLoaded.contains(segment.realUrl),
          )
          .map((segment) => segment.realUrl)
          .toList();

      if (segmentsToLoad != null && segmentsToLoad.isNotEmpty) {
        final subtitlesParsed = await BetterPlayerSubtitlesFactory.parseSubtitles(
          BetterPlayerSubtitlesSource(
            type: _betterPlayerSubtitlesSource!.type,
            headers: _betterPlayerSubtitlesSource!.headers,
            urls: segmentsToLoad,
          ),
        );

        ///Additional check if current source of subtitles is same as source
        ///used to start loading subtitles. It can be different when user
        ///changes subtitles and there was already pending load.
        if (source == _betterPlayerSubtitlesSource) {
          subtitlesLines.addAll(subtitlesParsed);
          _asmsSegmentsLoaded.addAll(segmentsToLoad);
        }
      }
      _asmsSegmentsLoading = false;
    } on Exception catch (exception) {
      BetterPlayerUtils.log('Load ASMS subtitle segments failed: $exception');
    }
  }

  ///Get VideoFormat from BetterPlayerVideoFormat (adapter method which translates
  ///to video_player supported format).
  VideoFormat? _getVideoFormat(BetterPlayerVideoFormat? betterPlayerVideoFormat) {
    if (betterPlayerVideoFormat == null) {
      return null;
    }
    switch (betterPlayerVideoFormat) {
      case BetterPlayerVideoFormat.dash:
        return VideoFormat.dash;
      case BetterPlayerVideoFormat.hls:
        return VideoFormat.hls;
      case BetterPlayerVideoFormat.ss:
        return VideoFormat.ss;
      case BetterPlayerVideoFormat.other:
        return VideoFormat.other;
    }
  }

  ///Internal method which invokes videoPlayerController source setup.
  Future<void> _setupDataSource(BetterPlayerDataSource betterPlayerDataSource) async {
    switch (betterPlayerDataSource.type) {
      case BetterPlayerDataSourceType.network:
        await videoPlayerController?.setNetworkDataSource(
          betterPlayerDataSource.url,
          headers: _getHeaders(),
          useCache: _betterPlayerDataSource!.cacheConfiguration?.useCache ?? false,
          maxCacheSize: _betterPlayerDataSource!.cacheConfiguration?.maxCacheSize ?? 0,
          maxCacheFileSize: _betterPlayerDataSource!.cacheConfiguration?.maxCacheFileSize ?? 0,
          cacheKey: _betterPlayerDataSource?.cacheConfiguration?.key,
          showNotification: _betterPlayerDataSource?.notificationConfiguration?.showNotification,
          title: _betterPlayerDataSource?.notificationConfiguration?.title,
          author: _betterPlayerDataSource?.notificationConfiguration?.author,
          imageUrl: _betterPlayerDataSource?.notificationConfiguration?.imageUrl,
          notificationChannelName: _betterPlayerDataSource?.notificationConfiguration?.notificationChannelName,
          overriddenDuration: _betterPlayerDataSource!.overriddenDuration,
          formatHint: _getVideoFormat(_betterPlayerDataSource!.videoFormat),
          licenseUrl: _betterPlayerDataSource?.drmConfiguration?.licenseUrl,
          certificateUrl: _betterPlayerDataSource?.drmConfiguration?.certificateUrl,
          drmHeaders: _betterPlayerDataSource?.drmConfiguration?.headers,
          activityName: _betterPlayerDataSource?.notificationConfiguration?.activityName,
          clearKey: _betterPlayerDataSource?.drmConfiguration?.clearKey,
          videoExtension: _betterPlayerDataSource!.videoExtension,
        );

      case BetterPlayerDataSourceType.file:
        final file = File(betterPlayerDataSource.url);
        if (!file.existsSync()) {
          BetterPlayerUtils.log(
            "File ${file.path} doesn't exists. This may be because "
            "you're acessing file from native path and Flutter doesn't "
            'recognize this path.',
          );
        }

        await videoPlayerController?.setFileDataSource(
          File(betterPlayerDataSource.url),
          showNotification: _betterPlayerDataSource?.notificationConfiguration?.showNotification,
          title: _betterPlayerDataSource?.notificationConfiguration?.title,
          author: _betterPlayerDataSource?.notificationConfiguration?.author,
          imageUrl: _betterPlayerDataSource?.notificationConfiguration?.imageUrl,
          notificationChannelName: _betterPlayerDataSource?.notificationConfiguration?.notificationChannelName,
          overriddenDuration: _betterPlayerDataSource!.overriddenDuration,
          activityName: _betterPlayerDataSource?.notificationConfiguration?.activityName,
          clearKey: _betterPlayerDataSource?.drmConfiguration?.clearKey,
        );
      case BetterPlayerDataSourceType.memory:
        final file = await _createFile(
          _betterPlayerDataSource!.bytes!,
          extension: _betterPlayerDataSource!.videoExtension,
        );

        if (file.existsSync()) {
          await videoPlayerController?.setFileDataSource(
            file,
            showNotification: _betterPlayerDataSource?.notificationConfiguration?.showNotification,
            title: _betterPlayerDataSource?.notificationConfiguration?.title,
            author: _betterPlayerDataSource?.notificationConfiguration?.author,
            imageUrl: _betterPlayerDataSource?.notificationConfiguration?.imageUrl,
            notificationChannelName: _betterPlayerDataSource?.notificationConfiguration?.notificationChannelName,
            overriddenDuration: _betterPlayerDataSource!.overriddenDuration,
            activityName: _betterPlayerDataSource?.notificationConfiguration?.activityName,
            clearKey: _betterPlayerDataSource?.drmConfiguration?.clearKey,
          );
          _tempFiles.add(file);
        } else {
          throw ArgumentError("Couldn't create file from memory.");
        }
    }
    await _initializeVideo();
  }

  ///Create file from provided list of bytes. File will be created in temporary
  ///directory.
  Future<File> _createFile(List<int> bytes, {String? extension = 'temp'}) async {
    final String dir = (await getTemporaryDirectory()).path;
    final File temp = File('$dir/better_player_${DateTime.now().millisecondsSinceEpoch}.$extension');
    await temp.writeAsBytes(bytes);
    return temp;
  }

  ///Initializes video based on configuration. Invoke actions which need to be
  ///run on player start.
  Future<void> _initializeVideo() async {
    unawaited(setLooping(betterPlayerConfiguration.looping));
    unawaited(updateAspectRatioIOS(betterPlayerConfiguration.aspectRatioIOS ?? AspectRatioTypeIOS.fill));
    if (_videoEventStreamSubscription != null) {
      unawaited(_videoEventStreamSubscription!.cancel());
      _videoEventStreamSubscription = null;
    }

    _videoEventStreamSubscription = videoPlayerController?.videoEventStreamController.stream.listen(_handleVideoEvent);

    final fullScreenByDefault = betterPlayerConfiguration.fullScreenByDefault;
    if (betterPlayerConfiguration.autoPlay) {
      if (fullScreenByDefault && !isFullScreen) {
        enterFullScreen();
      }
      if (_isAutomaticPlayPauseHandled()) {
        if (_appLifecycleState == AppLifecycleState.resumed && _isPlayerVisible) {
          await play();
        } else {
          _wasPlayingBeforePause = true;
        }
      } else {
        await play();
      }
    } else {
      if (fullScreenByDefault) {
        enterFullScreen();
      }
    }

    final startAt = betterPlayerConfiguration.startAt;
    if (startAt != null) {
      await seekTo(startAt);
    }
  }

  ///Method which is invoked when full screen changes.
  Future<void> _onFullScreenStateChanged() async {
    if ((videoPlayerController?.value.isPlaying ?? false) && !_isFullScreen) {
      enterFullScreen();
      videoPlayerController?.removeListener(_onFullScreenStateChanged);
    }
  }

  ///Enables full screen mode in player. This will trigger route change.
  void enterFullScreen() {
    _isFullScreen = true;
    _postControllerEvent(BetterPlayerControllerEvent.openFullscreen);
  }

  ///Disables full screen mode in player. This will trigger route change.
  void exitFullScreen() {
    _isFullScreen = false;
    _postControllerEvent(BetterPlayerControllerEvent.hideFullscreen);
  }

  /// Coming back from FullScreen.
  void backFromFullScreen() {
    _isFullScreen = false;
    _postControllerEvent(BetterPlayerControllerEvent.hideFullscreen);
    _postEvent(BetterPlayerEvent(BetterPlayerEventType.hideFullscreen));
  }

  ///Enables/disables full screen mode based on current fullscreen state.
  void toggleFullScreen() {
    _isFullScreen = !_isFullScreen;
    if (_isFullScreen) {
      _postControllerEvent(BetterPlayerControllerEvent.openFullscreen);
    } else {
      _postControllerEvent(BetterPlayerControllerEvent.hideFullscreen);
    }
  }

  ///Start video playback. Play will be triggered only if current lifecycle state
  ///is resumed.
  Future<void> play() async {
    if (videoPlayerController == null) {
      throw StateError('The data source has not been initialized');
    }

    if (_appLifecycleState == AppLifecycleState.resumed) {
      await videoPlayerController!.play();
      _hasCurrentDataSourceStarted = true;
      _wasPlayingBeforePause = null;
      _postEvent(BetterPlayerEvent(BetterPlayerEventType.play));
      _postControllerEvent(BetterPlayerControllerEvent.play);
    }
  }

  ///Enables/disables looping (infinity playback) mode.
  Future<void> setLooping(bool looping) async {
    if (videoPlayerController == null) {
      throw StateError('The data source has not been initialized');
    }

    await videoPlayerController!.setLooping(looping);
  }

  ///Stop video playback.
  Future<void> pause() async {
    if (videoPlayerController == null) {
      throw StateError('The data source has not been initialized');
    }

    await videoPlayerController!.pause();
    _postEvent(BetterPlayerEvent(BetterPlayerEventType.pause));
  }

  ///Move player to specific position/moment of the video.
  Future<void> seekTo(Duration moment) async {
    if (videoPlayerController == null) {
      throw StateError('The data source has not been initialized');
    }
    if (videoPlayerController?.value.duration == null) {
      throw StateError('The video has not been initialized yet.');
    }

    await videoPlayerController!.seekTo(moment);

    _postEvent(
      BetterPlayerEvent(BetterPlayerEventType.seekTo, parameters: <String, dynamic>{_durationParameter: moment}),
    );

    final Duration? currentDuration = videoPlayerController!.value.duration;
    if (currentDuration == null) {
      return;
    }
    if (moment > currentDuration) {
      _postEvent(BetterPlayerEvent(BetterPlayerEventType.finished));
    } else {
      cancelNextVideoTimer();
    }
  }

  ///Set volume of player. Allows values from 0.0 to 1.0.
  Future<void> setVolume(double volume) async {
    if (volume < 0.0 || volume > 1.0) {
      BetterPlayerUtils.log('Volume must be between 0.0 and 1.0');
      throw ArgumentError('Volume must be between 0.0 and 1.0');
    }
    if (videoPlayerController == null) {
      BetterPlayerUtils.log('The data source has not been initialized');
      throw StateError('The data source has not been initialized');
    }
    await videoPlayerController!.setVolume(volume);
    _postEvent(
      BetterPlayerEvent(BetterPlayerEventType.setVolume, parameters: <String, dynamic>{_volumeParameter: volume}),
    );
  }

  ///Set playback speed of video. Allows to set speed value between 0 and 2.
  Future<void> setSpeed(double speed) async {
    if (speed <= 0 || speed > 2) {
      BetterPlayerUtils.log('Speed must be between 0 and 2');
      throw ArgumentError('Speed must be between 0 and 2');
    }
    if (videoPlayerController == null) {
      BetterPlayerUtils.log('The data source has not been initialized');
      throw StateError('The data source has not been initialized');
    }
    await videoPlayerController?.setSpeed(speed);
    _postEvent(
      BetterPlayerEvent(BetterPlayerEventType.setSpeed, parameters: <String, dynamic>{_speedParameter: speed}),
    );
  }

  ///Flag which determines whenever player is playing or not.
  bool? isPlaying() {
    if (videoPlayerController == null) {
      throw StateError('The data source has not been initialized');
    }
    return videoPlayerController!.value.isPlaying;
  }

  ///Flag which determines whenever player is loading video data or not.
  bool? isBuffering() {
    if (videoPlayerController == null) {
      throw StateError('The data source has not been initialized');
    }
    return videoPlayerController!.value.isBuffering;
  }

  ///Show or hide controls manually
  void setControlsVisibility(bool isVisible) {
    _controlsVisibilityStreamController.add(isVisible);
  }

  ///Enable/disable controls (when enabled = false, controls will be always hidden)
  void setControlsEnabled(bool enabled) {
    if (!enabled) {
      _controlsVisibilityStreamController.add(false);
    }
    _controlsEnabled = enabled;
  }

  ///Internal method, used to trigger CONTROLS_VISIBLE or CONTROLS_HIDDEN event
  ///once controls state changed.
  void toggleControlsVisibility(bool isVisible) {
    _postEvent(
      isVisible
          ? BetterPlayerEvent(BetterPlayerEventType.controlsVisible)
          : BetterPlayerEvent(BetterPlayerEventType.controlsHiddenEnd),
    );
  }

  ///Send player event. Shouldn't be used manually.
  void postEvent(BetterPlayerEvent betterPlayerEvent) {
    _postEvent(betterPlayerEvent);
  }

  ///Send player event to all listeners.
  void _postEvent(BetterPlayerEvent betterPlayerEvent) {
    for (final void Function(BetterPlayerEvent)? eventListener in _eventListeners) {
      if (eventListener != null) {
        eventListener(betterPlayerEvent);
      }
    }
  }

  ///Listener used to handle video player changes.
  Future<void> _onVideoPlayerChanged() async {
    final VideoPlayerValue currentVideoPlayerValue =
        videoPlayerController?.value ?? VideoPlayerValue(duration: Duration.zero);

    if (currentVideoPlayerValue.hasError) {
      _videoPlayerValueOnError ??= currentVideoPlayerValue;
      _postEvent(
        BetterPlayerEvent(
          BetterPlayerEventType.exception,
          parameters: <String, dynamic>{'exception': currentVideoPlayerValue.errorDescription},
        ),
      );
    }
    if (currentVideoPlayerValue.initialized && !_hasCurrentDataSourceInitialized) {
      _hasCurrentDataSourceInitialized = true;
      _postEvent(BetterPlayerEvent(BetterPlayerEventType.initialized));
    }
    if (currentVideoPlayerValue.isPip) {
      _wasInPipMode = true;
    } else if (_wasInPipMode) {
      _postEvent(BetterPlayerEvent(BetterPlayerEventType.pipStop));
      _wasInPipMode = false;
      if (!_wasInFullScreenBeforePiP) {
        exitFullScreen();
      }
      if (_wasControlsEnabledBeforePiP) {
        setControlsEnabled(true);
      }
      videoPlayerController?.refresh();
    }

    if (_betterPlayerSubtitlesSource?.asmsIsSegmented ?? false) {
      await _loadAsmsSubtitlesSegments(currentVideoPlayerValue.position);
    }

    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPositionSelection > 500) {
      _lastPositionSelection = now;
      _postEvent(
        BetterPlayerEvent(
          BetterPlayerEventType.progress,
          parameters: <String, dynamic>{
            _progressParameter: currentVideoPlayerValue.position,
            _durationParameter: currentVideoPlayerValue.duration,
          },
        ),
      );
    }
  }

  ///Add event listener which listens to player events.
  void addEventsListener(void Function(BetterPlayerEvent) eventListener) {
    _eventListeners.add(eventListener);
  }

  ///Remove event listener. This method should be called once you're disposing
  ///Better Player.
  void removeEventsListener(void Function(BetterPlayerEvent) eventListener) {
    _eventListeners.remove(eventListener);
  }

  ///Flag which determines whenever player is playing live data source.
  bool isLiveStream() {
    if (_betterPlayerDataSource == null) {
      BetterPlayerUtils.log('The data source has not been initialized');
      throw StateError('The data source has not been initialized');
    }
    return _betterPlayerDataSource!.liveStream ?? false;
  }

  ///Flag which determines whenever player data source has been initialized.
  bool? isVideoInitialized() {
    if (videoPlayerController == null) {
      BetterPlayerUtils.log('The data source has not been initialized');
      throw StateError('The data source has not been initialized');
    }
    return videoPlayerController?.value.initialized;
  }

  ///Start timer which will trigger next video. Used in playlist. Do not use
  ///manually.
  void startNextVideoTimer() {
    if (_nextVideoTimer == null) {
      if (betterPlayerPlaylistConfiguration == null) {
        BetterPlayerUtils.log('BettterPlayerPlaylistConifugration has not been set!');
        throw StateError('BettterPlayerPlaylistConifugration has not been set!');
      }

      _nextVideoTime = betterPlayerPlaylistConfiguration!.nextVideoDelay.inSeconds;
      _nextVideoTimeStreamController.add(_nextVideoTime);
      if (_nextVideoTime == 0) {
        return;
      }

      _nextVideoTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
        if (_nextVideoTime == 1) {
          timer.cancel();
          _nextVideoTimer = null;
        }
        if (_nextVideoTime != null) {
          _nextVideoTime = _nextVideoTime! - 1;
        }
        _nextVideoTimeStreamController.add(_nextVideoTime);
      });
    }
  }

  ///Cancel next video timer. Used in playlist. Do not use manually.
  void cancelNextVideoTimer() {
    _nextVideoTime = null;
    _nextVideoTimeStreamController.add(_nextVideoTime);
    _nextVideoTimer?.cancel();
    _nextVideoTimer = null;
  }

  ///Play next video form playlist. Do not use manually.
  void playNextVideo() {
    _nextVideoTime = 0;
    _nextVideoTimeStreamController.add(_nextVideoTime);
    _postEvent(BetterPlayerEvent(BetterPlayerEventType.changedPlaylistItem));
    cancelNextVideoTimer();
  }

  ///Setup track parameters for currently played video. Can be only used for HLS or DASH
  ///data source.
  Future<void> setTrack(BetterPlayerAsmsTrack track) async {
    if (videoPlayerController == null) {
      throw StateError('The data source has not been initialized');
    }

    await videoPlayerController!.setTrackParameters(track.width, track.height, track.bitrate);
    _betterPlayerAsmsTrack = track;
    _postEvent(
      BetterPlayerEvent(
        BetterPlayerEventType.changedTrack,
        parameters: <String, dynamic>{
          'id': track.id,
          'width': track.width,
          'height': track.height,
          'bitrate': track.bitrate,
          'frameRate': track.frameRate,
          'codecs': track.codecs,
          'mimeType': track.mimeType,
        },
      ),
    );
    _postControllerEvent(BetterPlayerControllerEvent.changedTrack);
  }

  ///Check if player can be played/paused automatically
  bool _isAutomaticPlayPauseHandled() =>
      !(_betterPlayerDataSource?.notificationConfiguration?.showNotification ?? false) &&
      betterPlayerConfiguration.handleLifecycle;

  ///Listener which handles state of player visibility. If player visibility is
  ///below 0.0 then video will be paused. When value is greater than 0, video
  ///will play again. If there's different handler of visibility then it will be
  ///used. If showNotification is set in data source or handleLifecycle is false
  /// then this logic will be ignored.
  Future<void> onPlayerVisibilityChanged(double visibilityFraction) async {
    _isPlayerVisible = visibilityFraction > 0;
    if (_disposed) {
      return;
    }
    _postEvent(BetterPlayerEvent(BetterPlayerEventType.changedPlayerVisibility));

    if (_isAutomaticPlayPauseHandled()) {
      if (betterPlayerConfiguration.playerVisibilityChangedBehavior != null) {
        betterPlayerConfiguration.playerVisibilityChangedBehavior!(visibilityFraction);
      } else {
        if (visibilityFraction == 0) {
          _wasPlayingBeforePause ??= isPlaying();
          await pause();
        } else {
          if ((_wasPlayingBeforePause ?? false) && !isPlaying()!) {
            await play();
          }
        }
      }
    }
  }

  ///Set different resolution (quality) for video
  Future<void> setResolution(String url) async {
    if (videoPlayerController == null) {
      throw StateError('The data source has not been initialized');
    }
    final position = await videoPlayerController!.position;
    final wasPlayingBeforeChange = isPlaying()!;
    await pause();
    await setupDataSource(betterPlayerDataSource!.copyWith(url: url));
    await seekTo(position!);
    if (wasPlayingBeforeChange) {
      await play();
    }
    _postEvent(BetterPlayerEvent(BetterPlayerEventType.changedResolution, parameters: <String, dynamic>{'url': url}));
  }

  ///Setup translations for given locale. In normal use cases it shouldn't be
  ///called manually.
  void setupTranslations(Locale locale) {
    final String languageCode = locale.languageCode;
    translations =
        betterPlayerConfiguration.translations?.firstWhereOrNull(
          (translations) => translations.languageCode == languageCode,
        ) ??
        _getDefaultTranslations(locale);
  }

  ///Setup default translations for selected user locale. These translations
  ///are pre-build in.
  BetterPlayerTranslations _getDefaultTranslations(Locale locale) {
    final String languageCode = locale.languageCode;
    switch (languageCode) {
      case 'pl':
        return BetterPlayerTranslations.polish();
      case 'zh':
        return BetterPlayerTranslations.chinese();
      case 'hi':
        return BetterPlayerTranslations.hindi();
      case 'tr':
        return BetterPlayerTranslations.turkish();
      case 'vi':
        return BetterPlayerTranslations.vietnamese();
      case 'es':
        return BetterPlayerTranslations.spanish();
      default:
        return BetterPlayerTranslations();
    }
  }

  ///Flag which determines whenever current data source has started.
  bool get hasCurrentDataSourceStarted => _hasCurrentDataSourceStarted;

  ///Set current lifecycle state. If state is [AppLifecycleState.resumed] then
  ///player starts playing again. if lifecycle is in [AppLifecycleState.paused]
  ///state, then video playback will stop. If showNotification is set in data
  ///source or handleLifecycle is false then this logic will be ignored.
  void setAppLifecycleState(AppLifecycleState appLifecycleState) {
    if (_isAutomaticPlayPauseHandled()) {
      _appLifecycleState = appLifecycleState;
      if (appLifecycleState == AppLifecycleState.resumed) {
        if ((_wasPlayingBeforePause ?? false) && _isPlayerVisible) {
          play();
        }
      }
      if (appLifecycleState == AppLifecycleState.paused) {
        _wasPlayingBeforePause ??= isPlaying();
        pause();
      }
    }
  }

  ///Setup overridden aspect ratio.
  void setOverriddenAspectRatio(double aspectRatio) {
    _overriddenAspectRatio = aspectRatio;
  }

  ///Get aspect ratio used in current video. If aspect ratio is null, then
  ///aspect ratio from BetterPlayerConfiguration will be used. Otherwise
  ///[_overriddenAspectRatio] will be used.
  double? getAspectRatio() => _overriddenAspectRatio ?? betterPlayerConfiguration.aspectRatio;

  ///Setup overridden fit.
  void setOverriddenFit(BoxFit fit) {
    _overriddenFit = fit;
    _postControllerEvent(BetterPlayerControllerEvent.setFit);
  }

  ///Get fit used in current video. If fit is null, then fit from
  ///BetterPlayerConfiguration will be used. Otherwise [_overriddenFit] will be
  ///used.
  BoxFit getFit() => _overriddenFit ?? betterPlayerConfiguration.fit;

  Future<void>? updateAspectRatioIOS(AspectRatioTypeIOS aspectRatio) {
    if (videoPlayerController == null) {
      throw StateError('The data source has not been initialized');
    }
    return videoPlayerController!.setAspectRatio(aspectRatio.name);

  }

  ///Enable Picture in Picture (PiP) mode. [betterPlayerGlobalKey] is required
  ///to open PiP mode in iOS. When device is not supported, PiP mode won't be
  ///open.
  Future<void>? enablePictureInPicture(GlobalKey betterPlayerGlobalKey) async {
    if (videoPlayerController == null) {
      throw StateError('The data source has not been initialized');
    }

    final bool isPipSupported = (await videoPlayerController!.isPictureInPictureSupported()) ?? false;

    if (isPipSupported) {
      _wasInFullScreenBeforePiP = _isFullScreen;
      _wasControlsEnabledBeforePiP = _controlsEnabled;
      setControlsEnabled(false);
      if (Platform.isAndroid) {
        _wasInFullScreenBeforePiP = _isFullScreen;
        await videoPlayerController?.enablePictureInPicture(left: 0, top: 0, width: 0, height: 0);
        enterFullScreen();
        _postEvent(BetterPlayerEvent(BetterPlayerEventType.pipStart));
        return;
      }
      if (Platform.isIOS) {
        final RenderBox? renderBox = betterPlayerGlobalKey.currentContext!.findRenderObject() as RenderBox?;
        if (renderBox == null) {
          BetterPlayerUtils.log(
            "Can't show PiP. RenderBox is null. Did you provide valid global"
            ' key?',
          );
          return;
        }
        final Offset position = renderBox.localToGlobal(Offset.zero);
        return videoPlayerController?.enablePictureInPicture(
          left: position.dx,
          top: position.dy,
          width: renderBox.size.width,
          height: renderBox.size.height,
        );
      } else {
        BetterPlayerUtils.log('Unsupported PiP in current platform.');
      }
    } else {
      BetterPlayerUtils.log(
        "Picture in picture is not supported in this device. If you're "
        "using Android, please check if you're using activity v2 "
        'embedding.',
      );
    }
  }

  ///Disable Picture in Picture mode if it's enabled.
  Future<void>? disablePictureInPicture() {
    if (videoPlayerController == null) {
      throw StateError('The data source has not been initialized');
    }
    return videoPlayerController!.disablePictureInPicture();
  }

  ///Set GlobalKey of BetterPlayer. Used in PiP methods called from controls.
  void setBetterPlayerGlobalKey(GlobalKey betterPlayerGlobalKey) {
    _betterPlayerGlobalKey = betterPlayerGlobalKey;
  }

  ///Check if picture in picture mode is supported in this device.
  Future<bool> isPictureInPictureSupported() async {
    if (videoPlayerController == null) {
      throw StateError('The data source has not been initialized');
    }

    final bool isPipSupported = (await videoPlayerController!.isPictureInPictureSupported()) ?? false;

    return isPipSupported && !_isFullScreen;
  }

  ///Handle VideoEvent when remote controls notification / PiP is shown
  Future<void> _handleVideoEvent(VideoEvent event) async {
    switch (event.eventType) {
      case VideoEventType.play:
        _postEvent(BetterPlayerEvent(BetterPlayerEventType.play));
      case VideoEventType.pause:
        _postEvent(BetterPlayerEvent(BetterPlayerEventType.pause));
      case VideoEventType.seek:
        _postEvent(BetterPlayerEvent(BetterPlayerEventType.seekTo));
      case VideoEventType.completed:
        final VideoPlayerValue? videoValue = videoPlayerController?.value;
        _postEvent(
          BetterPlayerEvent(
            BetterPlayerEventType.finished,
            parameters: <String, dynamic>{
              _progressParameter: videoValue?.position,
              _durationParameter: videoValue?.duration,
            },
          ),
        );
      case VideoEventType.bufferingStart:
        _postEvent(BetterPlayerEvent(BetterPlayerEventType.bufferingStart));
      case VideoEventType.bufferingUpdate:
        _postEvent(
          BetterPlayerEvent(
            BetterPlayerEventType.bufferingUpdate,
            parameters: <String, dynamic>{_bufferedParameter: event.buffered},
          ),
        );
      case VideoEventType.bufferingEnd:
        _postEvent(BetterPlayerEvent(BetterPlayerEventType.bufferingEnd));
      default:
        break;
    }
  }

  ///Setup controls always visible mode
  void setControlsAlwaysVisible(bool controlsAlwaysVisible) {
    _controlsAlwaysVisible = controlsAlwaysVisible;
    _controlsVisibilityStreamController.add(controlsAlwaysVisible);
  }

  ///Retry data source if playback failed.
  Future<void> retryDataSource() async {
    await _setupDataSource(_betterPlayerDataSource!);
    if (_videoPlayerValueOnError != null) {
      final position = _videoPlayerValueOnError!.position;
      await seekTo(position);
      await play();
      _videoPlayerValueOnError = null;
    }
  }

  ///Set [audioTrack] in player. Works only for HLS or DASH streams.
  void setAudioTrack(BetterPlayerAsmsAudioTrack audioTrack) {
    if (videoPlayerController == null) {
      throw StateError('The data source has not been initialized');
    }

    if (audioTrack.language == null) {
      _betterPlayerAsmsAudioTrack = null;
      return;
    }

    _betterPlayerAsmsAudioTrack = audioTrack;
    videoPlayerController!.setAudioTrack(audioTrack.label, audioTrack.id);
  }

  ///Enable or disable audio mixing with other sound within device.
  void setMixWithOthers(bool mixWithOthers) {
    if (videoPlayerController == null) {
      throw StateError('The data source has not been initialized');
    }

    videoPlayerController!.setMixWithOthers(mixWithOthers);
  }

  ///Clear all cached data. Video player controller must be initialized to
  ///clear the cache.
  Future<void> clearCache() => VideoPlayerController.clearCache();

  ///Build headers map that will be used to setup video player controller. Apply
  ///DRM headers if available.
  Map<String, String?> _getHeaders() {
    final headers = betterPlayerDataSource!.headers ?? {};
    if (betterPlayerDataSource?.drmConfiguration?.drmType == BetterPlayerDrmType.token &&
        betterPlayerDataSource?.drmConfiguration?.token != null) {
      headers[_authorizationHeader] = betterPlayerDataSource!.drmConfiguration!.token!;
    }
    return headers;
  }

  ///PreCache a video. On Android, the future succeeds when
  ///the requested size, specified in
  ///[BetterPlayerCacheConfiguration.preCacheSize], is downloaded or when the
  ///complete file is downloaded if the file is smaller than the requested size.
  ///On iOS, the whole file will be downloaded, since [maxCacheFileSize] is
  ///currently not supported on iOS. On iOS, the video format must be in this
  ///list: https://github.com/sendyhalim/Swime/blob/master/Sources/MimeType.swift
  Future<void> preCache(BetterPlayerDataSource betterPlayerDataSource) {
    final cacheConfig =
        betterPlayerDataSource.cacheConfiguration ?? const BetterPlayerCacheConfiguration(useCache: true);

    final dataSource = DataSource(
      sourceType: DataSourceType.network,
      uri: betterPlayerDataSource.url,
      useCache: true,
      headers: betterPlayerDataSource.headers,
      maxCacheSize: cacheConfig.maxCacheSize,
      maxCacheFileSize: cacheConfig.maxCacheFileSize,
      cacheKey: cacheConfig.key,
      videoExtension: betterPlayerDataSource.videoExtension,
    );

    return VideoPlayerController.preCache(dataSource, cacheConfig.preCacheSize);
  }

  ///Stop pre cache for given [betterPlayerDataSource]. If there was no pre
  ///cache started for given [betterPlayerDataSource] then it will be ignored.
  Future<void> stopPreCache(BetterPlayerDataSource betterPlayerDataSource) =>
      VideoPlayerController.stopPreCache(betterPlayerDataSource.url, betterPlayerDataSource.cacheConfiguration?.key);

  /// Sets the new [betterPlayerControlsConfiguration] instance in the
  /// controller.
  void setBetterPlayerControlsConfiguration(BetterPlayerControlsConfiguration betterPlayerControlsConfiguration) {
    _betterPlayerControlsConfiguration = betterPlayerControlsConfiguration;
  }

  /// Add controller internal event.
  void _postControllerEvent(BetterPlayerControllerEvent event) {
    if (!_controllerEventStreamController.isClosed) {
      _controllerEventStreamController.add(event);
    }
  }

  ///Dispose BetterPlayerController. When [forceDispose] parameter is true, then
  ///autoDispose parameter will be overridden and controller will be disposed
  ///(if it wasn't disposed before).
  void dispose({bool forceDispose = false}) {
    if (!betterPlayerConfiguration.autoDispose && !forceDispose) {
      return;
    }
    if (!_disposed) {
      if (videoPlayerController != null) {
        pause();
        videoPlayerController!.removeListener(_onFullScreenStateChanged);
        videoPlayerController!.removeListener(_onVideoPlayerChanged);
        videoPlayerController!.dispose();
      }
      _eventListeners.clear();
      _nextVideoTimer?.cancel();
      _nextVideoTimeStreamController.close();
      _controlsVisibilityStreamController.close();
      _videoEventStreamSubscription?.cancel();
      _disposed = true;
      _controllerEventStreamController.close();

      ///Delete files async
      for (final file in _tempFiles) {
        file.delete();
      }
    }
  }
}
