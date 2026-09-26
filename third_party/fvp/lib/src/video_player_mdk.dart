// Copyright 2022-2026 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/widgets.dart'; //
import 'package:flutter/services.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:ffi/ffi.dart';

import 'fvp_platform_interface.dart';
import 'extensions.dart';
import 'lib.dart';
import 'media_info.dart';

import '../mdk.dart' as mdk;

final _log = Logger('fvp');

// Default MDK_KEY bundled with this plugin. Users can override it by passing
// {'global': {'MDK_KEY': '<key>'}} to registerWith().
const _kDefaultMdkKey =
    '4DF316BC71206BCEECD01559CC0FEDAF32DF8ECAE656BD9999CB821B67DB5B33'
    '2B323F24539BA7172746B8F5A64CA67AF342B16BF4B418F76718B821F77BEA07'
    '22F71DBC8EDF9431132FEAA633F0125072DF8DAC90268C62D0E4BA7D6DF9A6C4'
    '976AB1146EC55FFD1945CAB4125B20D5C77976CF1BCB77B14C563868EA00EA07';

class MdkVideoPlayer extends mdk.Player {
  final streamCtl = StreamController<VideoEvent>();
  bool _initialized = false;

  @override
  void dispose() {
    streamCtl.close();
    _initialized = false;
    super.dispose();
  }

  MdkVideoPlayer() : super() {
    onMediaStatus.listen((event) {
      final oldValue = event.oldValue;
      final newValue = event.newValue;
      _log.fine(
        '$hashCode player$nativeHandle onMediaStatus: $oldValue => $newValue',
      );
      if (!oldValue.test(mdk.MediaStatus.loaded) &&
          newValue.test(mdk.MediaStatus.loaded)) {
        // initialized event must be sent only once. keep_open=1 is another solution
        //if ((playerId.value ?? -1) >= 0) {
        //  return true; // prepared callback is invoked before MediaStatus.loaded, so playerId can be a valid value here
        //}
        if (_initialized) {
          _log.fine('$hashCode player$nativeHandle already initialized');
          return;
        }
        _initialized = true;
        textureSize.then((size) {
          if (size == null) {
            return;
          }
          streamCtl.add(
            VideoEvent(
              eventType: VideoEventType.initialized,
              duration: Duration(
                microseconds: isLive
                    // int max for live streams, duration.inMicroseconds == 9223372036854775807
                    ? double.maxFinite.toInt()
                    : mediaInfo.duration * 1000,
              ),
              size: size,
            ),
          );
        });
      } else if (!oldValue.test(mdk.MediaStatus.buffering) &&
          newValue.test(mdk.MediaStatus.buffering)) {
        streamCtl.add(VideoEvent(eventType: VideoEventType.bufferingStart));
      } else if (!oldValue.test(mdk.MediaStatus.buffered) &&
          newValue.test(mdk.MediaStatus.buffered)) {
        streamCtl.add(VideoEvent(eventType: VideoEventType.bufferingEnd));
      }
    });

    onEvent.listen((ev) {
      _log.fine(
        '$hashCode player$nativeHandle onEvent: ${ev.category} - ${ev.detail} - ${ev.error}',
      );
      if (ev.category == "reader.buffering") {
        final pos = position;
        final bufLen = buffered();
        streamCtl.add(
          VideoEvent(
            eventType: VideoEventType.bufferingUpdate,
            buffered: [
              DurationRange(
                Duration(microseconds: pos),
                Duration(milliseconds: pos + bufLen),
              ),
            ],
          ),
        );
      }
    });

    onStateChanged.listen((event) {
      _log.fine(
        '$hashCode player$nativeHandle onPlaybackStateChanged: ${event.oldValue} => ${event.newValue}',
      );
      if (event.newValue == mdk.PlaybackState.stopped) {
        // FIXME: keep_open no stopped
        streamCtl.add(VideoEvent(eventType: VideoEventType.completed));
        return;
      }
      streamCtl.add(
        VideoEvent(
          eventType: VideoEventType.isPlayingStateUpdate,
          isPlaying: event.newValue == mdk.PlaybackState.playing,
        ),
      );
    });
  }
}

class MdkVideoPlayerPlatform extends VideoPlayerPlatform {
  static final _players = <int, MdkVideoPlayer>{};
  static Map<String, Object>? _globalOpts;
  static Map<String, String>? _playerOpts;
  static int? _maxWidth;
  static int? _maxHeight;
  static bool? _fitMaxSize;
  static bool? _tunnel;
  static String? _subtitleFontFile;
  static int _lowLatency = 0;
  static int _seekFlags = mdk.SeekFlag.fromStart | mdk.SeekFlag.inCache;
  static List<String>? _decoders;
  static final _mdkLog = Logger('mdk');
  // _prevImpl: required if registerWith() can be invoked multiple times by user
  static VideoPlayerPlatform? _prevImpl;

  /*
  Registers this class as the default instance of [VideoPlayerPlatform].

  [options] can be
  "video.decoders": a list of decoder names. supported decoders: https://github.com/wang-bin/mdk-sdk/wiki/Decoders
  "maxWidth", "maxHeight": texture max size. if not set, video frame size is used. a small value can reduce memory cost, but may result in lower image quality.
 */
  static void registerVideoPlayerPlatformsWith({dynamic options}) {
    _log.fine('registerVideoPlayerPlatformsWith: $options');
    if (options is Map<String, dynamic>) {
      final platforms = options['platforms'];
      if (platforms is List<String>) {
        if (!platforms.contains(Platform.operatingSystem)) {
          if (_prevImpl != null &&
              VideoPlayerPlatform.instance is MdkVideoPlayerPlatform) {
            // null if it's the 1st time to call registerWith() including current platform
            // if current is not MdkVideoPlayerPlatform, another plugin may set instance
            // if current is MdkVideoPlayerPlatform, we have to restore instance,  _prevImpl is correct and no one changed instance
            VideoPlayerPlatform.instance = _prevImpl!;
          }
          return;
        }
      }

      if ((options['fastSeek'] ?? false) as bool) {
        _seekFlags |= mdk.SeekFlag.keyFrame;
      }
      _lowLatency = (options['lowLatency'] ?? 0) as int;
      _maxWidth = options["maxWidth"];
      _maxHeight = options["maxHeight"];
      _fitMaxSize = options["fitMaxSize"];
      _tunnel = options["tunnel"];
      _playerOpts = options['player'];
      _globalOpts = options['global'];
      // TODO: _env => putenv
      _decoders = options['video.decoders'];
      _subtitleFontFile = options['subtitleFontFile'];
    }

    if (_decoders == null && !PlatformEx.isAndroidEmulator()) {
      // prefer hardware decoders
      const vdRk = ['rockchip', 'rkmpp', 'FFmpeg', 'dav1d'];
      const vdPi = ['V4L2M2M', 'FFmpeg:hwcontext=drm', 'FFmpeg', 'dav1d'];
      final vdLinux = PlatformEx.isRockchip()
          ? vdRk
          : (PlatformEx.isRaspberryPi()
                ? vdPi
                : ['VAAPI', 'CUDA', 'VDPAU', 'hap', 'FFmpeg', 'dav1d']);
      final vd = {
        'windows': [
          'MFT:d3d=11',
          "D3D11",
          "DXVA",
          'CUDA',
          'hap',
          'FFmpeg',
          'dav1d',
        ],
        'macos': ['VT', 'hap', 'FFmpeg', 'dav1d'],
        'ios': ['VT', 'FFmpeg', 'dav1d'],
        'linux': vdLinux,
        'android': ['AMediaCodec', 'FFmpeg', 'dav1d'],
        'ohos': ['OH', 'FFmpeg', 'dav1d'],
      };
      _decoders = vd[Platform.operatingSystem];
    }

    // delay: ensure log handler is set in main(), blank window if run with debugger.
    // registerWith() can be invoked by dart_plugin_registrant.dart before main. when debugging, won't enter main if posting message from native to dart(new native log message) before main?
    Future.delayed(const Duration(milliseconds: 0), () {
      _setupMdk();
    });

    _prevImpl ??= VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = MdkVideoPlayerPlatform();
  }

  static void _setupMdk() {
    mdk.setLogHandler((level, msg) {
      if (msg.endsWith('\n')) {
        msg = msg.substring(0, msg.length - 1);
      }
      switch (level) {
        case mdk.LogLevel.error:
          _mdkLog.severe(msg);
        case mdk.LogLevel.warning:
          _mdkLog.warning(msg);
        case mdk.LogLevel.info:
          _mdkLog.info(msg);
        case mdk.LogLevel.debug:
          _mdkLog.fine(msg);
        case mdk.LogLevel.all:
          _mdkLog.finest(msg);
        default:
          return;
      }
    });
    // mdk.setGlobalOptions('plugins', 'mdk-braw');
    mdk.setGlobalOption("log", "all");
    mdk.setGlobalOption('d3d11.sync.cpu', 1);
    if (_subtitleFontFile?.startsWith('http') ?? false) {
      final fileName = _subtitleFontFile!.split('/').last;
      getApplicationCacheDirectory().then((dir) {
        final fontPath = '${dir.path}/$fileName';
        _log.fine('check font path: $fontPath');
        if (File(fontPath).existsSync()) {
          mdk.setGlobalOption('subtitle.fonts.file', fontPath);
          return;
        }
        _log.fine('downloading font file: $_subtitleFontFile');
        http.get(Uri.parse(_subtitleFontFile!)).then((response) {
          if (response.statusCode == 200) {
            _log.fine('save font file: $fontPath');
            File(fontPath).writeAsBytes(response.bodyBytes).then((_) {
              mdk.setGlobalOption('subtitle.fonts.file', fontPath);
            });
          }
        });
      });
    } else {
      mdk.setGlobalOption(
        'subtitle.fonts.file',
        PlatformEx.assetUri(_subtitleFontFile ?? 'assets/subfont.ttf'),
      );
    }
    _globalOpts?.forEach((key, value) {
      if (key == 'MDK_KEY') return; // handled separately below
      mdk.setGlobalOption(key, value);
    });
    final mdkKey = _globalOpts?['MDK_KEY'] as String? ?? _kDefaultMdkKey;
    final k = mdkKey.toNativeUtf8();
    Libfvp.setKey(k.cast());
    malloc.free(k);
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int playerId) async {
    _platformViewParams.remove(playerId);
    _players.remove(playerId)?.dispose();
  }

  /// Creation parameters for players rendering into a platform view
  /// (SurfaceView on Android), keyed by playerId. Absent for texture players.
  final _platformViewParams = <int, Map<String, Object>>{};

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) {
    // SurfaceView output is Android-only; other platforms keep the texture.
    return _create(
      options.dataSource,
      Platform.isAndroid ? options.viewType : VideoViewType.textureView,
    );
  }

  @override
  Future<int?> create(DataSource dataSource) =>
      _create(dataSource, VideoViewType.textureView);

  Future<int?> _create(DataSource dataSource, VideoViewType viewType) async {
    final uri = _toUri(dataSource);
    final player = MdkVideoPlayer();
    _log.fine('$hashCode player${player.nativeHandle} create($uri)');

    //player.setProperty("keep_open", "1");
    player.setProperty('video.decoder', 'shader_resource=0');
    player.setProperty('avformat.strict', 'experimental');
    player.setProperty('avformat.safe', '0');
    player.setProperty('avio.reconnect', '1');
    player.setProperty('avio.reconnect_delay_max', '7');
    player.setProperty('avformat.rtsp_transport', 'tcp');
    player.setProperty('avformat.extension_picky', '0');
    player.setProperty('avformat.allowed_segment_extensions', 'ALL');
    if (dataSource.sourceType != DataSourceType.network) {
      // for m3u8 local file etc.
      player.setProperty(
        'avio.protocol_whitelist',
        'file,ftp,rtmp,http,https,tls,rtp,tcp,udp,crypto,httpproxy,data,concatf,concat,subfile',
      );
    }
    _playerOpts?.forEach((key, value) {
      player.setProperty(key, value);
    });

    if (_decoders != null) {
      player.videoDecoders = _decoders!;
    }
    if (_lowLatency > 0) {
      // +nobuffer: the 1st key-frame packet is dropped. -nobuffer: high latency
      player.setProperty('avformat.fflags', '+nobuffer');
      player.setProperty('avformat.fpsprobesize', '0');
      player.setProperty('avformat.analyzeduration', '100000');
      if (_lowLatency > 1) {
        player.setBufferRange(min: 0, max: 1000, drop: true);
      } else {
        player.setBufferRange(min: 0);
      }
    }

    if (dataSource.httpHeaders.isNotEmpty) {
      String headers = '';
      dataSource.httpHeaders.forEach((key, value) {
        headers += '$key: $value\r\n';
      });
      player.setProperty('avio.headers', headers);
    }
    player.media = uri;
    int ret = await player.prepare(); // required!
    if (ret < 0) {
      // no throw, handle error in controller.addListener
      _players[-hashCode] = player;
      player.streamCtl.addError(
        PlatformException(
          code: 'media open error',
          message: 'invalid or unsupported media',
        ),
      );
      //player.dispose(); // dispose for throw
      return -hashCode;
    }
    if (viewType == VideoViewType.platformView) {
      // SurfaceView output (Android): no Flutter texture. The surface is
      // created by the FvpVideoView platform view and attached to the player
      // natively; buffers are sized to the video so TVs with an upscaled UI
      // layer (e.g. 1080p UI on a 4K panel) still scan out at full video
      // resolution. playerId is the native handle instead of a texture id.
      final size = await player.textureSize;
      if (size == null || size.width <= 0 || size.height <= 0) {
        _players[-hashCode] = player;
        player.streamCtl.addError(
          PlatformException(
            code: 'video size error',
            message: 'invalid or unsupported media with invalid video size',
          ),
        );
        return -hashCode;
      }
      final id = player.nativeHandle;
      // Clamp the GL render target as the texture path does — full 4K RGBA can
      // push SurfaceFlinger into GPU composition on weak GPUs. "tunnel" has no
      // GL renderer, so the decoder's own geometry stands.
      var w = size.width.toInt();
      var h = size.height.toInt();
      if (_tunnel ?? false) {
        // native size, no clamp
      } else if (_maxWidth != null &&
          _maxHeight != null &&
          (_fitMaxSize ?? true)) {
        final r = w / h;
        final fitW = (_maxHeight! * r).toInt();
        if (fitW <= _maxWidth!) {
          if (fitW < w) {
            w = fitW;
            h = _maxHeight!;
          }
        } else if (_maxWidth! < w) {
          h = (_maxWidth! / r).toInt();
          w = _maxWidth!;
        }
      } else {
        if (_maxWidth != null && _maxWidth! < w) {
          h = (h * _maxWidth! / w).round();
          w = _maxWidth!;
        }
        if (_maxHeight != null && _maxHeight! < h) {
          w = (w * _maxHeight! / h).round();
          h = _maxHeight!;
        }
      }
      _platformViewParams[id] = <String, Object>{
        'player': player.nativeHandle,
        'width': w,
        'height': h,
        'tunnel': _tunnel ?? false,
      };
      _log.fine(
        '$hashCode player${player.nativeHandle} platform view, '
        'video ${size.width.toInt()}x${size.height.toInt()}',
      );
      _players[id] = player;
      return id;
    }
    // FIXME: pending events will be processed after texture returned, but no events before prepared
    // FIXME: set tunnel too late
    final tex = await player.updateTexture(
      width: _maxWidth,
      height: _maxHeight,
      tunnel: _tunnel,
      fit: _fitMaxSize,
    );
    if (tex < 0) {
      _players[-hashCode] = player;
      player.streamCtl.addError(
        PlatformException(
          code: 'video size error',
          message: 'invalid or unsupported media with invalid video size',
        ),
      );
      //player.dispose();
      return -hashCode;
    }
    _log.fine('$hashCode player${player.nativeHandle} textureId/playerId=$tex');
    _players[tex] = player;
    return tex;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    final player = _players[playerId];
    if (player == null) return;
    player.loop = looping ? -1 : 0;
  }

  @override
  Future<void> play(int playerId) async {
    _players[playerId]?.state = mdk.PlaybackState.playing;
  }

  @override
  Future<void> pause(int playerId) async {
    _players[playerId]?.state = mdk.PlaybackState.paused;
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    _players[playerId]?.volume = volume;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    _players[playerId]?.playbackRate = speed;
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    return _seekToWithFlags(playerId, position, mdk.SeekFlag(_seekFlags));
  }

  @override
  Future<Duration> getPosition(int playerId) async {
    final player = _players[playerId];
    if (player == null) {
      return Duration.zero;
    }
    final pos = player.position;
    final bufLen = player.buffered();
    final ranges = player.bufferedTimeRanges();
    player.streamCtl.add(
      VideoEvent(
        eventType: VideoEventType.bufferingUpdate,
        buffered:
            ranges +
            [
              DurationRange(
                Duration(milliseconds: pos),
                Duration(milliseconds: pos + bufLen),
              ),
            ],
      ),
    );
    return Duration(milliseconds: pos);
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final player = _players[playerId];
    if (player != null) {
      return player.streamCtl.stream;
    }
    throw Exception('No Stream<VideoEvent> for textureId/playerId: $playerId.');
  }

  @override
  Widget buildView(int playerId) {
    return Texture(textureId: playerId);
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    final playerId = options.playerId;
    final creationParams = _platformViewParams[playerId];
    if (creationParams == null) {
      // Texture player (default).
      return buildView(playerId);
    }
    // SurfaceView requires hybrid composition (initExpensiveAndroidView):
    // under Flutter's default TLHC mode a SurfaceView draws at the wrong
    // location/z-index (see Flutter's Android platform views docs).
    // Builder: Directionality is only readable from a context below this.
    return Builder(
      builder: (context) {
        final layoutDirection =
            Directionality.maybeOf(context) ?? TextDirection.ltr;
        return PlatformViewLink(
          viewType: 'fvp/video-view',
          surfaceFactory: (context, controller) {
            return AndroidViewSurface(
              controller: controller as AndroidViewController,
              gestureRecognizers:
                  const <Factory<OneSequenceGestureRecognizer>>{},
              hitTestBehavior: PlatformViewHitTestBehavior.transparent,
            );
          },
          onCreatePlatformView: (params) {
            final controller = PlatformViewsService.initExpensiveAndroidView(
              id: params.id,
              viewType: 'fvp/video-view',
              // The direction Flutter resolved for this view's context — a
              // hard-coded ltr lays the view out wrongly in an RTL app.
              layoutDirection: layoutDirection,
              creationParams: creationParams,
              creationParamsCodec: const StandardMessageCodec(),
            );
            controller.addOnPlatformViewCreatedListener(
              params.onPlatformViewCreated,
            );
            controller.create();
            return controller;
          },
        );
      },
    );
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {
    FvpPlatform.instance.setMixWithOthers(mixWithOthers);
  }

  // more apis for fvp controller
  bool isLive(int playerId) {
    return _players[playerId]?.isLive ?? false;
  }

  MediaInfo? getMediaInfo(int playerId) {
    return _players[playerId]?.mediaInfo;
  }

  void setProperty(int playerId, String name, String value) {
    _players[playerId]?.setProperty(name, value);
  }

  void setAudioDecoders(int playerId, List<String> value) {
    _players[playerId]?.audioDecoders = value;
  }

  void setVideoDecoders(int playerId, List<String> value) {
    _players[playerId]?.videoDecoders = value;
  }

  void record(int playerId, {String? to, String? format}) {
    _players[playerId]?.record(to: to, format: format);
  }

  Future<Uint8List?> snapshot(int playerId, {int? width, int? height}) async {
    return _players[playerId]?.snapshot(width: width, height: height);
  }

  void setRange(int playerId, {required int from, int to = -1}) {
    _players[playerId]?.setRange(from: from, to: to);
  }

  void setBufferRange(
    int playerId, {
    int min = -1,
    int max = -1,
    bool drop = false,
  }) {
    _players[playerId]?.setBufferRange(min: min, max: max, drop: drop);
  }

  Future<void> fastSeekTo(int playerId, Duration position) async {
    return _seekToWithFlags(
      playerId,
      position,
      mdk.SeekFlag(_seekFlags | mdk.SeekFlag.keyFrame),
    );
  }

  Future<void> step(int playerId, int frames) async {
    final player = _players[playerId];
    if (player == null) return;
    player.seek(
      position: frames,
      flags: const mdk.SeekFlag(mdk.SeekFlag.frame | mdk.SeekFlag.fromNow),
    );
  }

  void setBrightness(int playerId, double value) {
    _players[playerId]?.setVideoEffect(mdk.VideoEffect.brightness, [value]);
  }

  void setContrast(int playerId, double value) {
    _players[playerId]?.setVideoEffect(mdk.VideoEffect.contrast, [value]);
  }

  void setHue(int playerId, double value) {
    _players[playerId]?.setVideoEffect(mdk.VideoEffect.hue, [value]);
  }

  void setSaturation(int playerId, double value) {
    _players[playerId]?.setVideoEffect(mdk.VideoEffect.saturation, [value]);
  }

  void setProgram(int playerId, int programId) {
    _players[playerId]?.setActiveTracks(mdk.MediaType.unknown, [programId]);
  }

  // embedded tracks, can be main data source from create(), or external media source via setExternalAudio
  void setAudioTracks(int playerId, List<int> value) {
    _players[playerId]?.activeAudioTracks = value;
  }

  List<int>? getActiveAudioTracks(int playerId) {
    return _players[playerId]?.activeAudioTracks;
  }

  void setVideoTracks(int playerId, List<int> value) {
    _players[playerId]?.activeVideoTracks = value;
  }

  List<int>? getActiveVideoTracks(int playerId) {
    return _players[playerId]?.activeVideoTracks;
  }

  void setSubtitleTracks(int playerId, List<int> value) {
    _players[playerId]?.activeSubtitleTracks = value;
  }

  List<int>? getActiveSubtitleTracks(int playerId) {
    return _players[playerId]?.activeSubtitleTracks;
  }

  // external track. can select external tracks via setAudioTracks()
  void setExternalAudio(int playerId, String uri) {
    _players[playerId]?.setMedia(uri, mdk.MediaType.audio);
  }

  void setExternalVideo(int playerId, String uri) {
    _players[playerId]?.setMedia(uri, mdk.MediaType.video);
  }

  void setExternalSubtitle(int playerId, String uri) {
    _players[playerId]?.setMedia(uri, mdk.MediaType.subtitle);
  }

  void onSubtitleText(
    int playerId,
    void Function(double start, double end, List<String> text)? callback,
  ) {
    _players[playerId]?.onSubtitleText(callback);
  }

  Future<void> _seekToWithFlags(
    int playerId,
    Duration position,
    mdk.SeekFlag flags,
  ) async {
    final player = _players[playerId];
    if (player == null) return;

    if (player.isLive) {
      final bufMax = player.buffered();
      final pos = player.position;
      if (position.inMilliseconds <= pos ||
          position.inMilliseconds > pos + bufMax) {
        _log.fine(
          '_seekToWithFlags: $position out of live stream buffered range [$pos, ${pos + bufMax}]',
        );
        return;
      }
    }
    player.seek(position: position.inMilliseconds, flags: flags);
  }

  String _toUri(DataSource dataSource) {
    switch (dataSource.sourceType) {
      case DataSourceType.asset:
        return PlatformEx.assetUri(
          dataSource.asset!,
          package: dataSource.package,
        );
      case DataSourceType.network:
        return dataSource.uri!;
      case DataSourceType.file:
        return Uri.decodeComponent(dataSource.uri!);
      case DataSourceType.contentUri:
        return dataSource.uri!;
    }
  }
}
