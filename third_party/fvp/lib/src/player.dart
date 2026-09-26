// Copyright 2022-2026 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fvp_platform_interface.dart';
import 'generated_bindings.dart';
import 'global.dart';
import 'media_info.dart';
import 'lib.dart';
import 'extensions.dart';

class Player {
  int get nativeHandle => _player.address;

  /// for builder
  final ValueNotifier<int?> textureId = ValueNotifier<int?>(null);

  Player() {
    _pp.value = _player;
    _receivePort.listen((message) async {
      final type = message[0] as int;
      final rep = calloc<_CallbackReply>();
      switch (type) {
        case 0:
          {
            // event
            final error = message[1] as int;
            final category = message[2] as String;
            final detail = message[3] as String;
            final ev = MediaEvent(error, category, detail);
            if (_eventCb.hasListener) {
              _eventCb.add(ev);
            }
          }
        case 1:
          {
            // state
            final oldValue = message[1] as int;
            final newValue = message[2] as int;
            if (_stateCb.hasListener) {
              _stateCb.add((
                oldValue: PlaybackState.from(oldValue),
                newValue: PlaybackState.from(newValue),
              ));
            }
            Libfvp.replyType(nativeHandle, type, nullptr);
          }
        case 2:
          {
            // media status
            final oldValue = message[1] as int;
            final newValue = message[2] as int;
            bool ret = true;
            if (_statusCb.hasListener) {
              _statusCb.add((
                oldValue: MediaStatus(oldValue),
                newValue: MediaStatus(newValue),
              ));
            }
            rep.ref.mediaStatus.ret = ret;
            Libfvp.replyType(nativeHandle, type, rep.cast());
          }
        case 3:
          {
            // prepared
            final pos = message[1] as int;
            _live = message[2] as bool;
            if (!_prepared.isCompleted) {
              _prepared.complete(pos);
            }
            rep.ref.prepared.ret = true;
            rep.ref.prepared.boost = true;
            /*
            // callback can be late if prepare from pos > 0
            if (_videoSize.isCompleted)
              _videoSize = Completer<ui.Size?>();
            if (!_videoSize.isCompleted) {
              if (pos < 0) {
                _videoSize.complete(null);
              } else {
                _setVideoSize();
              }
            }*/
            if (_prepareCb != null) {
              rep.ref.prepared.ret = await _prepareCb!();
              _prepareCb = null;
            }
            Libfvp.replyType(nativeHandle, type, rep.cast());
          }
        case 6:
          {
            // seek
            final pos = message[1] as int;
            if (!(_seeked?.isCompleted ?? true)) {
              _seeked?.complete(pos);
            }
            _seeked = null;
          }
        case 7:
          {
            final data = message[1] as Uint8List; //null?
            if (!(_snapshot?.isCompleted ?? true)) {
              _snapshot?.complete(data.isEmpty ? null : data);
            }
            _snapshot = null;
          }
        case 8:
          {
            final start = message[1] as double;
            final end = message[2] as double;
            final texts = (message[3] as List).cast<String>();
            _subtitleCb?.call(start, end, texts);
          }
      }
      calloc.free(rep);
    });
    Libfvp.registerPort(
      nativeHandle,
      NativeApi.postCObject.cast(),
      _receivePort.sendPort.nativePort,
    );

    onStateChanged.listen((event) {
      _state = event.newValue;
    });
    Libfvp.registerType(nativeHandle, 1, false);
    onMediaStatus.listen((event) {
      final oldValue = event.oldValue;
      final newValue = event.newValue;
      if (!oldValue.test(MediaStatus.loaded) &&
          newValue.test(MediaStatus.loaded)) {
        _setVideoSize();
      }
      if (!oldValue.test(MediaStatus.loading) &&
          newValue.test(MediaStatus.loading)) {
        if (_videoSize.isCompleted) {
          // updateTexture() may be awaiting and won't wake up if reset to a new object here
          _videoSize = Completer<ui.Size?>();
        }
      }
      if (oldValue.test(MediaStatus.loading) &&
          newValue.test(MediaStatus.invalid | MediaStatus.stalled)) {
        _videoSize.complete(null);
      }
      if (oldValue.test(MediaStatus.loaded) &&
          !newValue.test(MediaStatus.loaded)) {
        // invalid mediaInfo when loaded(small probe size, bad format etc.), then failed to decode
        if (!_videoSize.isCompleted) {
          _videoSize.complete(null);
        }
      }
    });
    Libfvp.registerType(nativeHandle, 2, false);
    onEvent.listen((e) {
      if (_videoSize.isCompleted) {
        return;
      }
      if (e.category == 'decoder.video') {
        _setVideoSize();
      }
    });
    Libfvp.registerType(nativeHandle, 0, false);
  }

  /// Release resources
  void dispose() async {
    if (_pp == nullptr) {
      textureId.dispose();
      return;
    }
    // await: ensure no player ref in fvp plugin before mdkPlayerAPI_delete() in dart
    await updateTexture(width: -1);
    state = PlaybackState.stopped;
    Libfvp.unregisterPort(nativeHandle);
    _eventCb.close();
    Libfvp.unregisterType(nativeHandle, 0);
    _stateCb.close();
    Libfvp.unregisterType(nativeHandle, 1);
    _statusCb.close();
    Libfvp.unregisterType(nativeHandle, 2);

    _receivePort.close();

    Libmdk.instance.mdkPlayerAPI_delete(_pp);
    calloc.free(_pp);
    _pp = nullptr;
    textureId.dispose();
  }

  /// Release current texture then create a new one for current [media], and update [textureId].
  ///
  /// Texture will be created when media is loaded and mediaInfo.video is not empty.
  /// If both [width] and [height] are null, texture size is video frame size, otherwise is requested size.
  Future<int> updateTexture({
    int? width,
    int? height,
    bool? tunnel,
    bool? fit,
  }) async {
    if ((textureId.value ?? -1) >= 0) {
      await FvpPlatform.instance.releaseTexture(nativeHandle, textureId.value!);
      textureId.value = null;
    }
    final size = await _videoSize.future;
    if (size == null) {
      return -1;
    }
    if (width == null && height == null) {
      // original size
      textureId.value = await FvpPlatform.instance.createTexture(
        nativeHandle,
        size.width.toInt(),
        size.height.toInt(),
        tunnel ?? false,
      );
      return textureId.value!;
    }
    if (width != null && height != null && width > 0 && height > 0) {
      if (fit ?? true) {
        final r = size.width / size.height;
        final w = (height * r).toInt();
        if (w <= width) {
          width = w;
        } else {
          height = (width / r).toInt();
        }
      }
      textureId.value = await FvpPlatform.instance.createTexture(
        nativeHandle,
        width,
        height,
        tunnel ?? false,
      );
      return textureId.value!;
    }
    // release texture if width or height <= 0
    return -1;
  }

  Future<ui.Size?> get textureSize => _videoSize.future;

  /// Mute the audio or not
  set mute(bool value) {
    _mute = value;
    _player.ref.setMute.asFunction<void Function(Pointer<mdkPlayer>, bool)>(
      isLeaf: true,
    )(_player.ref.object, value);
  }

  /// Mute value.
  bool get mute => _mute;

  /// Set audio volume value. 1.0 is source value
  set volume(double value) {
    _volume = value;
    _player.ref.setVolume
        .asFunction<void Function(Pointer<mdkPlayer>, double)>()(
      _player.ref.object,
      value,
    );
  }

  /// Audio volume value
  double get volume => _volume;

  /// Set the audio renderer. Can be 'AudioTrack', 'OpenSL' on android.
  set audioBackends(List<String> value) {
    final u8p = value.toCZ();
    _player.ref.setAudioBackends
        .asFunction<
          void Function(Pointer<mdkPlayer>, Pointer<Pointer<Char>>)
        >()(_player.ref.object, u8p.cast());
    u8p.free();
  }

  /// Set media, can be url, file path, assets://path etc.
  set media(String value) {
    if (_media != value) {
      if (!_videoSize.isCompleted) {
        _videoSize.complete(null);
      }
      _videoSize = Completer<ui.Size?>();
    }
    _media = value;
    final cs = value.toNativeUtf8();
    _player.ref.setMedia
        .asFunction<void Function(Pointer<mdkPlayer>, Pointer<Char>)>()(
      _player.ref.object,
      cs.cast(),
    );
    malloc.free(cs);
  }

  /// Current media.
  String get media => _media;

  /// Set audio decoder priority. Usually not required.
  set audioDecoders(List<String> value) => setDecoders(MediaType.audio, value);

  List<String> get audioDecoders => _adec;

  /// Set video decoder priority. Default is 'auto' decoder, which is usually 'FFmpeg'.
  /// Detail: https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setdecodersmediatype-type-const-stdvectorstdstring-names
  set videoDecoders(List<String> value) => setDecoders(MediaType.video, value);

  /// Decoder list set by user
  List<String> get videoDecoders => _vdec;

  /// Set active audio tracks. Other tracks will be disabled.
  /// The tracks can be from [media], or an external audio source set by [setMedia] with [MediaType.audio].
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setactivetracksmediatype-type-const-stdsetint-tracks
  set activeAudioTracks(List<int> value) =>
      setActiveTracks(MediaType.audio, value);

  /// Active audio tracks set by user
  List<int> get activeAudioTracks => _activeAT;

  /// Set active video tracks. Other tracks will be disabled.
  /// The tracks can be from [media], or an external video source set by [setMedia] with [MediaType.video].
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setactivetracksmediatype-type-const-stdsetint-tracks
  set activeVideoTracks(List<int> value) =>
      setActiveTracks(MediaType.video, value);

  /// Active video tracks set by user
  List<int> get activeVideoTracks => _activeVT;

  /// Set active subtitle tracks. Other tracks will be disabled.
  /// The tracks can be from [media], or an external video source set by [setMedia] with [MediaType.subtitle].
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setactivetracksmediatype-type-const-stdsetint-tracks
  set activeSubtitleTracks(List<int> value) =>
      setActiveTracks(MediaType.subtitle, value);

  /// Active subtitle tracks set by user
  List<int> get activeSubtitleTracks => _activeST;

  /// Set playback state to start, pause and stop the media.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setstateplaybackstate-value
  set state(PlaybackState value) {
    _state = value;
    _player.ref.setState.asFunction<void Function(Pointer<mdkPlayer>, int)>()(
      _player.ref.object,
      value.rawValue,
    );
  }

  /// Current playback state.
  PlaybackState get state => _state;

  /// Current [MediaStatus] value
  MediaStatus get mediaStatus => MediaStatus(
    _player.ref.mediaStatus.asFunction<int Function(Pointer<mdkPlayer>)>()(
      _player.ref.object,
    ),
  );

  /// Set loop count. -1 is infinite loop. 0 is no loop.
  set loop(int value) {
    _loop = value;
    _player.ref.setLoop.asFunction<void Function(Pointer<mdkPlayer>, int)>()(
      _player.ref.object,
      value,
    );
  }

  /// Loop count set by user.
  int get loop => _loop;

  /// Preload the next media set by [setNext] immediately or when current playback is finished.
  set preloadImmediately(bool value) {
    _preloadImmediately = value;
    _player.ref.setPreloadImmediately
        .asFunction<void Function(Pointer<mdkPlayer>, bool)>()(
      _player.ref.object,
      value,
    );
  }

  bool get preloadImmediately => _preloadImmediately;

  /// Get current playback position in milliseconds relative to media's first timestamp.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#int64_t-position-const
  int get position => _player.ref.position
      .asFunction<int Function(Pointer<mdkPlayer>)>()(_player.ref.object);

  /// Playback speed. 1.0 is original speed.
  set playbackRate(double value) {
    _playbackRate = value;
    _player.ref.setPlaybackRate
        .asFunction<void Function(Pointer<mdkPlayer>, double)>()(
      _player.ref.object,
      value,
    );
  }

  /// Playback speed set by user.
  double get playbackRate => _playbackRate;

  /// It's a live stream or not.
  bool get isLive => _live;

  /// Media information.
  MediaInfo get mediaInfo {
    _mediaInfoC =
        _player.ref.mediaInfo
            .asFunction<Pointer<mdkMediaInfo> Function(Pointer<mdkPlayer>)>()(
          _player.ref.object,
        );
    return MediaInfo.from(_mediaInfoC);
  }

  /// Load the [media] from [position] in milliseconds and decode the first frame, then [state] will be [PlaybackState.paused].
  /// If error occurs, will be [PlaybackState.stopped].
  /// Return the result position, or a negative value if failed.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-prepareint64_t-startposition--0-functionboolint64_t-position-bool-boost-cb--nullptr-seekflag-flags--seekflagfromstart
  ///
  /// Return
  /// 0: if mediaInfo.streams == 0, invalid media. otherwise success
  /// -1: already loading or loaded
  /// -4: requested position out of range
  /// -10: internal error
  Future<int> prepare({
    int position = 0,
    SeekFlag flags = const SeekFlag(SeekFlag.defaultFlags),
    Future<bool> Function()? callback,
    bool reply = false,
  }) async {
    _prepared = Completer<int>();
    Libfvp.registerType(nativeHandle, 3, reply);
    _prepareCb = callback;
    if (!Libfvp.prepare(
      nativeHandle,
      position,
      flags.rawValue,
      NativeApi.postCObject.cast(),
      _receivePort.sendPort.nativePort,
    )) {
      _prepared.complete(-10);
    }
    return _prepared.future;
  }

  /// Set decoder priority.
  /// Detail: https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setdecodersmediatype-type-const-stdvectorstdstring-names
  void setDecoders(MediaType type, List<String> value) {
    switch (type) {
      case MediaType.audio:
        _adec = value;
      case MediaType.video:
        _vdec = value;
      default:
    }

    final u8p = value.toCZ();
    _player.ref.setDecoders
        .asFunction<
          void Function(Pointer<mdkPlayer>, int, Pointer<Pointer<Char>>)
        >()(_player.ref.object, type.rawValue, u8p.cast());
    u8p.free();
  }

  /// Set active tracks of [type]. Other tracks of [type] will be disabled.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setactivetracksmediatype-type-const-stdsetint-tracks
  void setActiveTracks(MediaType type, List<int> value) {
    switch (type) {
      case MediaType.audio:
        _activeAT = value;
      case MediaType.video:
        _activeVT = value;
      case MediaType.subtitle:
        _activeST = value;
      default:
    }
    final ca = calloc<Int>(value.length);
    for (int i = 0; i < value.length; ++i) {
      ca[i] = value[i];
    }
    _player.ref.setActiveTracks
        .asFunction<
          void Function(Pointer<mdkPlayer>, int, Pointer<Int>, int)
        >()(_player.ref.object, type.rawValue, ca.cast(), value.length);
    calloc.free(ca);
  }

  /// Set media of [type]. Can be used to load external audio track and subtitle file.
  /// An external media can contains other [MediaType] tracks although they will not be used.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setmediaconst-char-url-mediatype-type
  void setMedia(String uri, MediaType type) {
    final cs = uri.toNativeUtf8();
    _player.ref.setMediaForType
        .asFunction<void Function(Pointer<mdkPlayer>, Pointer<Char>, int)>()(
      _player.ref.object,
      cs.cast(),
      type.rawValue,
    );
    malloc.free(cs);
  }

  void setAsset(String asset, {String? package, MediaType? type}) {
    final uri = PlatformEx.assetUri(asset, package: package);
    if (type == null) {
      media = uri;
    } else {
      setMedia(uri, type);
    }
  }

  /// Set the next media to play when current media playback is finished.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setnextmediaconst-char-url-int64_t-startposition--0-seekflag-flags--seekflagfromstart
  void setNext(
    String uri, {
    int from = 0,
    SeekFlag seekFlag = const SeekFlag(SeekFlag.defaultFlags),
  }) {
    final cs = uri.toNativeUtf8();
    _player.ref.setNextMedia
        .asFunction<
          void Function(Pointer<mdkPlayer>, Pointer<Char>, int, int)
        >()(_player.ref.object, cs.cast(), from, seekFlag.rawValue);
    malloc.free(cs);
  }

  /// Wait for [state] in current thread
  bool waitFor(PlaybackState state, {int timeout = -1}) =>
      _player.ref.waitFor
          .asFunction<bool Function(Pointer<mdkPlayer>, int, int)>()(
        _player.ref.object,
        state.rawValue,
        timeout,
      );

  /// Seek to [position] in milliseconds
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#bool-seekint64_t-pos-seekflag-flags-stdfunctionvoidint64_t-ret-cb--nullptr
  Future<int> seek({
    required int position,
    SeekFlag flags = const SeekFlag(SeekFlag.defaultFlags),
  }) async {
    if (!(_seeked?.isCompleted ?? true)) {
      _seeked?.complete(-2);
    }
    _seeked = Completer<int>();
    if (!Libfvp.seek(
      nativeHandle,
      position,
      flags.rawValue,
      NativeApi.postCObject.cast(),
      _receivePort.sendPort.nativePort,
    )) {
      _seeked!.complete(-10);
    }
    return _seeked!.future;
  }

  List<DurationRange> bufferedTimeRanges() {
    const int n = 16;
    final cbytes = calloc<Int64>(2 * n);
    final count = _player.ref.bufferedTimeRanges
        .asFunction<
          int Function(Pointer<mdkPlayer>, Pointer<Int64>, int)
        >()(_player.ref.object, cbytes, n);
    var ret = <DurationRange>[];
    for (int i = 0; i < min(count, n); ++i) {
      ret.add(
        DurationRange(
          Duration(milliseconds: cbytes[2 * i].toInt()),
          Duration(milliseconds: cbytes[2 * i + 1].toInt()),
        ),
      );
    }
    calloc.free(cbytes);
    return ret;
  }

  /// Return buffered duration in milliseconds.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#int64_t-bufferedint64_t-bytes--nullptr-const
  int buffered() {
    //var cbytes = calloc<Int64>();
    final ret =
        _player.ref.buffered
            .asFunction<int Function(Pointer<mdkPlayer>, Pointer<Int64>)>()(
          _player.ref.object,
          nullptr,
        );
    //cbytes.value
    //calloc.free(cbytes);
    return ret;
  }

  /// Set duration range(milliseconds) of buffered data.
  ///
  /// [min] default 1000. wait for buffered duration >= [min]
  ///   If [min] < 0, then [min], [max] and [drop] will be reset to the default value
  /// [max] default 4000. max buffered duration.
  ///   If [max] < 0, then [max] and drop will be reset to the default value
  ///   If [max] == 0, same as INT64_MAX
  /// [drop] = true: drop old non-key frame packets to reduce buffered duration until < [max].
  /// [drop] = false: wait for buffered duration < max before pushing packets
  ///
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setbufferrangeint64_t-minms-int64_t-maxms-bool-drop--false
  void setBufferRange({int min = -1, int max = -1, bool drop = false}) =>
      _player.ref.setBufferRange
          .asFunction<void Function(Pointer<mdkPlayer>, int, int, bool)>()(
        _player.ref.object,
        min,
        max,
        drop,
      );

  /// Start to record if [to] is not null. Stop recording if [to] is null.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-recordconst-char-url--nullptr-const-char-format--nullptr
  void record({String? to, String? format}) {
    final cto = to?.toNativeUtf8();
    final cfmt = format?.toNativeUtf8();
    _player.ref.record
        .asFunction<
          void Function(Pointer<mdkPlayer>, Pointer<Char>, Pointer<Char>)
        >()(
      _player.ref.object,
      cto?.cast() ?? nullptr,
      cfmt?.cast() ?? nullptr,
    );
    if (cto != null) {
      malloc.free(cto);
    }
    if (cfmt != null) {
      malloc.free(cfmt);
    }
  }

  /// Set position range in milliseconds. Can be used by A-B loop.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setrangeint64_t-a-int64_t-b--int64_max
  void setRange({required int from, int to = -1}) =>
      _player.ref.setRange
          .asFunction<void Function(Pointer<mdkPlayer>, int, int)>()(
        _player.ref.object,
        from,
        to,
      );

  /// Set additional properties.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setpropertyconst-stdstring-key-const-stdstring-value
  void setProperty(String name, String value) {
    final ck = name.toNativeUtf8();
    final cv = value.toNativeUtf8();
    _player.ref.setProperty
        .asFunction<
          void Function(Pointer<mdkPlayer>, Pointer<Char>, Pointer<Char>)
        >()(_player.ref.object, ck.cast(), cv.cast());
    malloc.free(ck);
    malloc.free(cv);
  }

  /// Get property value for [name]
  String? getProperty(String name) {
    final ck = name.toNativeUtf8();
    final cv = _player.ref.getProperty
        .asFunction<
          Pointer<Char> Function(Pointer<mdkPlayer>, Pointer<Char>)
        >()(_player.ref.object, ck.cast());
    malloc.free(ck);
    if (cv.address == 0) {
      return null;
    }
    return cv.cast<Utf8>().toDartString();
  }

  // video renderer apis

  /// Set video renderer size or destroy renderer.
  /// Usually NOT used in dart.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setvideosurfacesizeint-width-int-height-void-vo_opaque--nullptr
  void setVideoSurfaceSize(int width, int height) => _player
      .ref
      .setVideoSurfaceSize
      .asFunction<
        void Function(Pointer<mdkPlayer>, int, int, Pointer<Void>)
      >()(_player.ref.object, width, height, _getVid());

  void setVideoViewport(double x, double y, double width, double height) =>
      _player.ref.setVideoViewport
          .asFunction<
            void Function(
              Pointer<mdkPlayer>,
              double,
              double,
              double,
              double,
              Pointer<Void>,
            )
          >()(_player.ref.object, x, y, width, height, _getVid());

  /// Set video content aspect ratio. No effect if texture width/height == original video frame width/height.
  /// [value] can be [ignoreAspectRatio], [keepAspectRatio], [keepAspectRatioCrop] and other desired ratio = width/height
  ///
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setaspectratiofloat-value-void-vo_opaque--nullptr
  void setAspectRatio(double value) => _player.ref.setAspectRatio
      .asFunction<
        void Function(Pointer<mdkPlayer>, double, Pointer<Void>)
      >()(_player.ref.object, value, _getVid());

  /// Set region-of-interest mapping for video display
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setpointmapconst-float-videoroi-const-float-viewroi--nullptr-int-count--2-void-vo_opaque--nullptr
  void setPointMap({
    List<double>? videoRoi,
    List<double>? viewRoi,
    int count = 2,
  }) {
    final cv = (videoRoi != null)
        ? () {
            final p = calloc<Float>(count * 2);
            for (int i = 0; i < videoRoi.length; ++i) {
              p[i] = videoRoi[i];
            }
            return p;
          }()
        : nullptr;
    final cw = (viewRoi != null)
        ? () {
            final p = calloc<Float>(count * 2);
            for (int i = 0; i < viewRoi.length; ++i) {
              p[i] = viewRoi[i];
            }
            return p;
          }()
        : nullptr;
    _player.ref.setPointMap
        .asFunction<
          void Function(
            Pointer<mdkPlayer>,
            Pointer<Float>,
            Pointer<Float>,
            int,
            Pointer<Void>,
          )
        >()(_player.ref.object, cv.cast(), cw.cast(), count, _getVid());
    if (cv != nullptr) {
      calloc.free(cv);
    }
    if (cw != nullptr) {
      calloc.free(cw);
    }
  }

  /// Map a point between viewport coordinates and video frame coordinates.
  /// Returns the mapped coordinates as a record `({double x, double y})`.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-mappointmapdirection-dir-float-x-float-y-float-z--nullptr-void-vo_opaque--nullptr
  ({double x, double y}) mapPoint(
    MapDirection direction, {
    required double x,
    required double y,
  }) {
    final cx = calloc<Float>();
    final cy = calloc<Float>();
    final cz = calloc<Float>();
    cx.value = x;
    cy.value = y;
    _player.ref.mapPoint
        .asFunction<
          void Function(
            Pointer<mdkPlayer>,
            int,
            Pointer<Float>,
            Pointer<Float>,
            Pointer<Float>,
            Pointer<Void>,
          )
        >()(_player.ref.object, direction.rawValue, cx, cy, cz, _getVid());
    final result = (x: cx.value, y: cy.value);
    calloc.free(cx);
    calloc.free(cy);
    calloc.free(cz);
    return result;
  }

  /// rotate video content around the center. [degree] can be 0, 90, 180, 270 in counterclockwise.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-rotateint-degree-void-vo_opaque--nullptr
  void rotate(int degree) =>
      _player.ref.rotate
          .asFunction<void Function(Pointer<mdkPlayer>, int, Pointer<Void>)>()(
        _player.ref.object,
        degree,
        _getVid(),
      );

  /// scale video content. 1.0 is no scale.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-scalefloat-x-float-y-void-vo_opaque--nullptr
  void scale(double x, double y) => _player.ref.scale
      .asFunction<
        void Function(Pointer<mdkPlayer>, double, double, Pointer<Void>)
      >()(_player.ref.object, x, y, _getVid());

  /// Set background color.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setbackgroundcolorfloat-r-float-g-float-b-float-a-void-vo_opaque--nullptr
  void setBackgroundColor(double r, double g, double b, double a) => _player
      .ref
      .setBackgroundColor
      .asFunction<
        void Function(
          Pointer<mdkPlayer>,
          double,
          double,
          double,
          double,
          Pointer<Void>,
        )
      >()(_player.ref.object, r, g, b, a, _getVid());

  /// Set a built-in video effect.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#player-setvideoeffect-effect-const-float-values-void-vo_opaque--nullptr
  void setVideoEffect(VideoEffect effect, List<double> value) {
    final cv = calloc<Float>(value.length);
    for (int i = 0; i < value.length; ++i) {
      cv[i] = value[i];
    }
    _player.ref.setVideoEffect
        .asFunction<
          void Function(Pointer<mdkPlayer>, int, Pointer<Float>, Pointer<Void>)
        >()(_player.ref.object, effect.rawValue, cv.cast(), _getVid());
    calloc.free(cv);
  }

  /// Set target color space.
  /// Usually NOT used by dart because flutter only supports SDR output.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#player-setcolorspace-value-void-vo_opaque--nullptr
  void setColorSpace(ColorSpace value) =>
      _player.ref.setColorSpace
          .asFunction<void Function(Pointer<mdkPlayer>, int, Pointer<Void>)>()(
        _player.ref.object,
        value.rawValue,
        _getVid(),
      );

  /// Draw the current video frame and return frame timestamp in seconds.
  /// Usually NOT used in dart.
  double renderVideo() =>
      _player.ref.renderVideo
          .asFunction<double Function(Pointer<mdkPlayer>, Pointer<Void>)>()(
        _player.ref.object,
        _getVid(),
      );

  /// Take a snapshot for current rendered frame.
  ///
  /// [width] snapshot width. if not set, result is `mediaInfo.video[current_track].codec.width`
  /// [height] snapshot height. if not set, result is `mediaInfo.video[current_track].codec.height`
  /// Return rgba data of image size [width]x[height], stride is `width*4`
  Future<Uint8List?> snapshot({int? width, int? height}) {
    if (!(_snapshot?.isCompleted ?? true)) {
      _snapshot?.complete(null);
    }
    _snapshot = Completer<Uint8List?>();
    if (!Libfvp.snapshot(
      nativeHandle,
      textureId.value ?? -1,
      width ?? 0,
      height ?? 0,
      NativeApi.postCObject.cast(),
      _receivePort.sendPort.nativePort,
    )) {
      _snapshot!.complete(null);
    }
    return _snapshot!.future;
  }
  // callbacks

  /// Get a [MediaEvent] stream.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#player-oneventstdfunctionboolconst-mediaevent-cb-callbacktoken-token--nullptr
  Stream<MediaEvent> get onEvent => _eventCb.stream;

  /// Get a [PlaybackState] change stream.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#player-onstatechangedstdfunctionvoidstate-cb
  Stream<({PlaybackState oldValue, PlaybackState newValue})>
  get onStateChanged => _stateCb.stream;

  /// Get a [MediaStatus] change stream.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#player-onmediastatusstdfunctionboolmediastatus-oldvalue-mediastatus-newvalue-cb-callbacktoken-token--nullptr
  // reply: true to let native code wait for dart callback result, may result in dead lock because when native waiting main isolate reply, main isolate may execute another task(e.g. frequent seekTo) which also acquire the same lock in native
  Stream<({MediaStatus oldValue, MediaStatus newValue})> get onMediaStatus =>
      _statusCb.stream;

  void onSubtitleText(
    void Function(double start, double end, List<String> text)? callback,
  ) {
    _subtitleCb = callback;
    if (callback == null) {
      Libfvp.unregisterType(nativeHandle, 8);
    } else {
      Libfvp.registerType(nativeHandle, 8, false);
    }
  }

  void _setVideoSize() {
    if (_videoSize.isCompleted) {
      // loading=>loaded, then frame decoded
      return;
    }
    var v = mediaInfo.video?[0];
    // we don't support dynamic texture size change, so use the max video codec width
    if (v != null) {
      for (final i in mediaInfo.video!) {
        if (i.codec.width > v!.codec.width) {
          v = i;
        }
      }
    }
    // if no video stream, create a dummy texture of size 16x16
    double w = 16;
    double h = 16;
    final vc = v?.codec;
    if (vc != null) {
      if (vc.width <= 0 || vc.height <= 0) {
        // failed to parse video size, e.g. small probesize
        return;
      }
      w = vc.width.toDouble();
      h = (vc.height.toDouble() / vc.par).roundToDouble();
      if (v!.rotation % 180 == 90) {
        (w, h) = (h, w);
      }
    }
    final size = ui.Size(w, h);
    _videoSize.complete(size);
  }

  Pointer<Void> _getVid() {
    // currently only android vo_opaque is not null, and may change
    if (Platform.isAndroid) {
      return Libfvp.getVid(textureId.value ?? -1);
    }
    return Pointer.fromAddress(0);
  }

  final _player = Libmdk.instance.mdkPlayerAPI_new();
  var _pp = calloc<Pointer<mdkPlayerAPI>>();

  bool _live = false;
  var _videoSize = Completer<ui.Size?>();
  var _prepared = Completer<int>();
  Completer<Uint8List?>? _snapshot;
  Completer<int>? _seeked;
  final _receivePort = ReceivePort();

  final _eventCb = StreamController<MediaEvent>.broadcast();
  final _stateCb =
      StreamController<
        ({PlaybackState oldValue, PlaybackState newValue})
      >.broadcast();
  final _statusCb =
      StreamController<
        ({MediaStatus oldValue, MediaStatus newValue})
      >.broadcast();
  Function(double start, double end, List<String> text)? _subtitleCb;
  Future<bool> Function()? _prepareCb;

  bool _mute = false;
  double _volume = 1.0;
  String _media = "";
  List<String> _adec = ["auto"];
  List<String> _vdec = ["auto"];
  List<int> _activeAT = [0];
  List<int> _activeVT = [0];
  List<int> _activeST = [0];
  PlaybackState _state = PlaybackState.stopped;
  int _loop = 0;
  bool _preloadImmediately = true;
  double _playbackRate = 1.0;
  Pointer<mdkMediaInfo> _mediaInfoC =
      nullptr; // MediaInfo has views on mdkMediaInfo
}

final class _CallbackReply extends Union {
  external _UnnamedStruct5 mediaStatus;
  external _UnnamedStruct6 sync1;
  external _UnnamedStruct7 prepared;
}

final class _UnnamedStruct5 extends Struct {
  @Bool()
  external bool ret;
}

final class _UnnamedStruct6 extends Struct {
  @Double()
  external double ret;
}

final class _UnnamedStruct7 extends Struct {
  @Bool()
  external bool ret;
  @Bool()
  external bool boost;
}
