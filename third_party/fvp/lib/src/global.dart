// Copyright 2022-2025 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'generated_bindings.dart';
import 'lib.dart';

/// a frame with [timestampEOS] indicates it's the last frame
// TODO: generate by ffi
const double timestampEOS = 1.7976931348623157e+308;

/// Float timestamp unit is second, integer timestamp(for example Player.position, seek) unit is millisecond.
const double timeScaleForInt = 1000.0;

/// Stretch video content to fill renderer viewport.
const double ignoreAspectRatio = 0.0;

/// Keep video frame aspect ratio and scale as large as possible inside video renderer viewport.
const double keepAspectRatio = 1.1920928955078125e-7;

/// Keep frame aspect ratio and scale as small as possible to cover renderer viewport.
const double keepAspectRatioCrop = -1.1920928955078125e-7;

typedef CallbackToken = MDK_CallbackToken;

/// https://github.com/wang-bin/mdk-sdk/wiki/Types#enum-mediatype
enum MediaType {
  unknown(MDK_MediaType.MDK_MediaType_Unknown),
  video(MDK_MediaType.MDK_MediaType_Video),
  audio(MDK_MediaType.MDK_MediaType_Audio),
  subtitle(MDK_MediaType.MDK_MediaType_Subtitle);

  final int rawValue;
  const MediaType(this.rawValue);
}

/// https://github.com/wang-bin/mdk-sdk/wiki/Types#enum-mediastatus-flags
class MediaStatus {
  static const noMedia = MDK_MediaStatus.MDK_MediaStatus_NoMedia;
  static const unloaded = MDK_MediaStatus.MDK_MediaStatus_Unloaded;
  static const loading = MDK_MediaStatus.MDK_MediaStatus_Loading;
  static const loaded = MDK_MediaStatus.MDK_MediaStatus_Loaded;
  static const prepared = MDK_MediaStatus.MDK_MediaStatus_Prepared;
  static const stalled = MDK_MediaStatus.MDK_MediaStatus_Stalled;
  static const buffering = MDK_MediaStatus.MDK_MediaStatus_Buffering;
  static const buffered = MDK_MediaStatus.MDK_MediaStatus_Buffered;
  static const end = MDK_MediaStatus.MDK_MediaStatus_End;
  static const seeking = MDK_MediaStatus.MDK_MediaStatus_Seeking;
  static const invalid = MDK_MediaStatus.MDK_MediaStatus_Invalid;

  final int rawValue;
  const MediaStatus(this.rawValue);

  bool test(int s) {
    return (rawValue & s) != 0;
  }

  @override
  String toString() {
    var s = 'MediaStatus(';
    if (rawValue == 0) s += 'noMedia';
    if (test(unloaded)) s += '+unloaded';
    if (test(loading)) s += '+loading';
    if (test(loaded)) s += '+loaded';
    if (test(prepared)) s += '+prepared';
    if (test(stalled)) s += '+stalled';
    if (test(buffering)) s += '+buffering';
    if (test(buffered)) s += '+buffered';
    if (test(end)) s += '+end';
    if (test(seeking)) s += '+seeking';
    if (test(invalid)) s += '+invalid';
    return '$s)';
  }
}

/// Playback state
enum PlaybackState {
  notRunning(MDK_State.MDK_State_NotRunning),
  stopped(MDK_State.MDK_State_Stopped),
  running(MDK_State.MDK_State_Running),
  playing(MDK_State.MDK_State_Playing),
  paused(MDK_State.MDK_State_Paused);

  final int rawValue;
  const PlaybackState(this.rawValue);

  factory PlaybackState.from(int i) {
    const states = [
      PlaybackState.stopped,
      PlaybackState.playing,
      PlaybackState.paused,
    ];
    return states[i];
  }
}

/// https://github.com/wang-bin/mdk-sdk/wiki/Types#enum-seekflag-flags
class SeekFlag {
  static const from0 = MDKSeekFlag.MDK_SeekFlag_From0;
  static const fromStart = MDKSeekFlag.MDK_SeekFlag_FromStart;
  static const fromNow = MDKSeekFlag.MDK_SeekFlag_FromNow;
  static const frame = MDKSeekFlag.MDK_SeekFlag_Frame;
  static const keyFrame = MDKSeekFlag.MDK_SeekFlag_KeyFrame;
  static const fast = MDKSeekFlag.MDK_SeekFlag_Fast;
  static const inCache = MDKSeekFlag.MDK_SeekFlag_InCache;

  /// defaultFlags is keyFrame|fromStart|inCache
  static const defaultFlags = MDKSeekFlag.MDK_SeekFlag_Default;

  final int rawValue;
  const SeekFlag(this.rawValue);

  bool test(int s) {
    return (rawValue & s) != 0;
  }

  @override
  String toString() {
    var s = 'SeekFlag(';
    if (test(from0)) s += '+from0';
    if (test(fromStart)) s += '+fromStart';
    if (test(fromNow)) s += '+fromNow';
    if (test(frame)) s += '+frame';
    if (test(keyFrame)) s += '+keyFrame';
    if (test(inCache)) s += '+inCache';
    return '$s)';
  }
}

/// https://github.com/wang-bin/mdk-sdk/wiki/Types#enum-videoeffect
enum VideoEffect {
  brightness(MDK_VideoEffect.MDK_VideoEffect_Brightness),
  contrast(MDK_VideoEffect.MDK_VideoEffect_Contrast),
  hue(MDK_VideoEffect.MDK_VideoEffect_Hue),
  saturation(MDK_VideoEffect.MDK_VideoEffect_Saturation);

  final int rawValue;
  const VideoEffect(this.rawValue);
}

/// https://github.com/wang-bin/mdk-sdk/wiki/Types#enum-colorspace
enum ColorSpace {
  unknown(MDK_ColorSpace.MDK_ColorSpace_Unknown),
  bt709(MDK_ColorSpace.MDK_ColorSpace_BT709),
  bt2100PQ(MDK_ColorSpace.MDK_ColorSpace_BT2100_PQ),
  scrgb(MDK_ColorSpace.MDK_ColorSpace_scRGB),
  bt2100hlg(MDK_ColorSpace.MDK_ColorSpace_BT2100_HLG);

  final int rawValue;
  const ColorSpace(this.rawValue);

  factory ColorSpace.from(int rawValue) {
    switch (rawValue) {
      case MDK_ColorSpace.MDK_ColorSpace_Unknown:
        return unknown;
      case MDK_ColorSpace.MDK_ColorSpace_BT709:
        return bt709;
      case MDK_ColorSpace.MDK_ColorSpace_BT2100_PQ:
        return bt2100PQ;
      case MDK_ColorSpace.MDK_ColorSpace_scRGB:
        return scrgb;
      case MDK_ColorSpace.MDK_ColorSpace_BT2100_HLG:
        return bt2100hlg;
      default:
        return unknown;
    }
  }
}

/// https://github.com/wang-bin/mdk-sdk/wiki/Types#enum-mapdirection
enum MapDirection {
  frameToViewport(MDK_MapDirection.MDK_MapDirection_FrameToViewport),
  viewportToFrame(MDK_MapDirection.MDK_MapDirection_ViewportToFrame);

  final int rawValue;
  const MapDirection(this.rawValue);
}

enum LogLevel {
  off(MDK_LogLevel.MDK_LogLevel_Off),
  error(MDK_LogLevel.MDK_LogLevel_Error),
  warning(MDK_LogLevel.MDK_LogLevel_Warning),
  info(MDK_LogLevel.MDK_LogLevel_Info),
  debug(MDK_LogLevel.MDK_LogLevel_Debug),
  all(MDK_LogLevel.MDK_LogLevel_All);

  final int rawValue;
  const LogLevel(this.rawValue);

  factory LogLevel.from(int rawValue) {
    switch (rawValue) {
      case MDK_LogLevel.MDK_LogLevel_Off:
        return off;
      case MDK_LogLevel.MDK_LogLevel_Error:
        return error;
      case MDK_LogLevel.MDK_LogLevel_Warning:
        return warning;
      case MDK_LogLevel.MDK_LogLevel_Info:
        return info;
      case MDK_LogLevel.MDK_LogLevel_Debug:
        return debug;
      case MDK_LogLevel.MDK_LogLevel_All:
        return all;
      default:
        return info;
    }
  }
}

/// https://github.com/wang-bin/mdk-sdk/wiki/Types#class-mediaevent
class MediaEvent {
  final int error; // progress value [0, 100] if category is "reader.buffering"
  final String category;
  final String detail;

  const MediaEvent(this.error, this.category, this.detail);
}

/// libmdk version.
int version() => Libmdk.instance.MDK_version();

/// Global options: https://github.com/wang-bin/mdk-sdk/wiki/Global-Options
void setGlobalOption<T>(String name, T value) {
  final k = name.toNativeUtf8();
  if (value is String) {
    // T == String
    final v = value.toNativeUtf8();
    Libmdk.instance.MDK_setGlobalOptionString(k.cast(), v.cast());
    malloc.free(v);
  } else if (value is int) {
    Libmdk.instance.MDK_setGlobalOptionInt32(k.cast(), value);
  } else if (value is bool) {
    Libmdk.instance.MDK_setGlobalOptionInt32(k.cast(), value ? 1 : 0);
  } else if (value is LogLevel) {
    Libmdk.instance.MDK_setGlobalOptionInt32(k.cast(), value.rawValue);
  }
  malloc.free(k);
}
/*
T? getGlobalOption<T>(String name) {
  final k = name.toNativeUtf8();
  if (T == String) {
    String? ret;
    final p = calloc<Pointer<Char>>();
    final found = Libmdk.instance.MDK_getGlobalOptionString(k.cast(), p.cast());
    malloc.free(k);
    if (found) {
      ret = p.value.cast<Utf8>().toDartString();
    }
    calloc.free(p);
    return ret;
  }
}
*/

/// Set log handler for mdk internal logs
void setLogHandler(void Function(LogLevel, String)? cb) {
  _GlobalCallbacks.instance.setLogHandler(cb);
}

class _GlobalCallbacks {
  static final _receivePort = ReceivePort();

  void Function(LogLevel, String)? _logCb;

  static _GlobalCallbacks instance = _GlobalCallbacks();

  _GlobalCallbacks() {
    // registerType() before registerPort() to ensure no log will be dropped
    Libfvp.registerType(0, 5, false);
    _receivePort.listen((message) {
      final type = message[0] as int;
      switch (type) {
        case 5:
          {
            // log
            final level = message[1] as int;
            final msg = message[2] as String;
            if (_logCb != null) {
              _logCb!(LogLevel.from(level), msg);
            }
          }
      }
    });
    Libfvp.registerPort(
      0,
      NativeApi.postCObject.cast(),
      _receivePort.sendPort.nativePort,
    );
  }

  void setLogHandler(void Function(LogLevel, String)? cb) {
    _logCb = cb;
    if (cb == null) {
      Libfvp.unregisterType(0, 5);
      return;
    }
    Libfvp.registerType(0, 5, false);
  }
}
