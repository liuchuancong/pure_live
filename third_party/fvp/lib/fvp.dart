// Copyright 2022-2025 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'src/video_player_mdk.dart'
    if (dart.library.js_interop) 'src/video_player_dummy.dart'
    if (dart.library.html) 'src/video_player_dummy.dart';

export 'src/controller.dart';

/// Registers this plugin as the default instance of VideoPlayerPlatform. Then your [VideoPlayer] will support all platforms.
/// If registerWith is not called, the previous(usually official) implementation will be used when available.

/// [options] can be
/// 'platforms': a list of [Platform.operatingSystem], only these platforms will use this plugin implementation. You can still use official implementation for android and ios if they are not in the list.
/// If 'platforms' not set, this implementation will be used for all platforms.
///
/// 'fastSeek': bool. default is false, faster but not accurate, i.e. result position can be a few seconds different from requested position
///
/// "video.decoders": a list of decoder names. supported decoders: https://github.com/wang-bin/mdk-sdk/wiki/Decoders
///
/// "maxWidth", "maxHeight": texture max size. if not set, video frame size is used. a small value can reduce memory cost, but may result in lower image quality.
///
/// 'lowLatency': int. default is 0. reduce network stream latency. 1: for vod. 2: for live stream, may drop frames to ensure the latest content is displayed
///
/// "player": backend player properties of type [Map<String, String>]. See https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setpropertyconst-stdstring-key-const-stdstring-value
///
/// "global": backend global options of type [Map<String, Object>]. See https://github.com/wang-bin/mdk-sdk/wiki/Global-Options
///
/// "tunnel": android only, default is false. AMediacodec/MediaCodec decoder output to the surface directly (a SurfaceTexture, or a SurfaceView via VideoViewType.platformView) without OpenGL: no GL renderer, no EGLConfig, no GPU copy, and the video scans out at its native resolution, so "maxWidth"/"maxHeight" are not applied. This is what lets a 4K video present at full panel resolution on TVs whose UI layer runs at 1080p. Maybe more efficient, but some features are not supported, e.g. HDR tone mapping and frame readback (snapshot), and fewer codecs.
///
/// 'subtitleFontFile': default subtitle font file as the fallback, can be an http url. If not set, 'assets/subfont.ttf' will be used, you can add it in pubspec.yaml if you need it.
/// subfont.ttf can be downloaded from https://github.com/mpv-android/mpv-android/raw/master/app/src/main/assets/subfont.ttf
///
/// Example:
/// ```dart
/// registerWith(options: {
///     'platforms': ['windows', 'linux', 'macos'], # or other Platform.operatingSystem
///     'video.decoders': ['BRAW:scale=1/4', 'auto'],
///     'maxWidth': screenWidth,
///     'maxHeight': screenHeight,
///     'subtitleFontFile': 'assets/subfont.ttf',
///   });
/// ```
///
void registerWith({dynamic options}) {
  MdkVideoPlayerPlatform.registerVideoPlayerPlatformsWith(options: options);
}

/// Registers this plugin automatically by dart tooling. requires `dartPluginClass: VideoPlayerRegistrant` in pubspec.yaml
class VideoPlayerRegistrant {
  static void registerWith() {
    MdkVideoPlayerPlatform.registerVideoPlayerPlatformsWith();
  }
}

/*
bool isRegistered() {
  return VideoPlayerPlatform.instance.runtimeType == MdkVideoPlayerPlatform;
}
*/
