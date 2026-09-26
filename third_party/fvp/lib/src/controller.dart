// ignore_for_file: invalid_use_of_visible_for_testing_member

// see https://github.com/ardera/flutter_packages/blob/main/packages/flutterpi_gstreamer_video_player/lib/src/controller.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'media_info.dart'
    if (dart.library.js_interop) 'media_info_dummy.dart'
    if (dart.library.html) 'media_info_dummy.dart';
import 'video_player_mdk.dart'
    if (dart.library.js_interop) 'video_player_dummy.dart'
    if (dart.library.html) 'video_player_dummy.dart';

MdkVideoPlayerPlatform get _platform {
  if (VideoPlayerPlatform.instance is! MdkVideoPlayerPlatform) {
    throw StateError(
      '`VideoPlayerPlatform.instance` have to be of `MdkVideoPlayerPlatform` to use advanced video player features.'
      'Make sure you\'ve called `fvp.registerWith()`',
    );
  }
  return VideoPlayerPlatform.instance as MdkVideoPlayerPlatform;
}

/// Advanced features for [VideoPlayerController].
///
/// All methods in this extension must be called after initialized, otherwise no effect.
extension FVPControllerExtensions on VideoPlayerController {
  /*
  static int Function(VideoPlayerController)? _idGetter;
  int _getId(VideoPlayerController controller) {
    _idGetter ??= _getIdFunc();
    return _idGetter!(this);
  }
  int Function(VideoPlayerController) _getIdFunc() {
    //final dynamic self = this;
    try { // try to get textureId
      //final _ = self.textureId;
      final _ = (this as dynamic).textureId;
      return (dynamic c) => c.textureId;
    } on NoSuchMethodError { // since video_player 2.10.0 to support platform view
      return (dynamic c) => c.playerId;
    }
  }
  // extension can't override existing method, e.g. `dynamic noSuchMethod(Invocation invocation)`
*/
  static final int Function(VideoPlayerController c) _getId = () {
    // prefer playerId when available(since video_player 2.10.0 to support platform view), fallback to textureId for older video_player versions
    try {
      // try to get playerId. static implies late, but can't access this
      final _ = (VideoPlayerController.file(File('')) as dynamic).playerId;
      return (dynamic c) => c.playerId as int;
    } on NoSuchMethodError {
      return (dynamic c) => c.textureId as int;
    }
  }();

  /// Indicates whether current media is a live stream or not
  bool isLive() {
    return _platform.isLive(_getId(this));
  }

  /// Get current media info.
  MediaInfo? getMediaInfo() {
    return _platform.getMediaInfo(_getId(this));
  }

  /// set additional properties
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setpropertyconst-stdstring-key-const-stdstring-value
  void setProperty(String name, String value) {
    _platform.setProperty(_getId(this), name, value);
  }

  /// Change video decoder list on the fly.
  /// NOTE: the default decoder list used by [VideoPlayerController] constructor MUST set via [registerWith].
  /// Detail: https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setdecodersmediatype-type-const-stdvectorstdstring-names
  void setVideoDecoders(List<String> value) {
    _platform.setVideoDecoders(_getId(this), value);
  }

  /// Start to record if [to] is not null. Stop recording if [to] is null.
  /// [to] can be a local file, or are network stream, for example rtmp.
  /// If not stopped by user, recording will be stopped when playback is finished.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-recordconst-char-url--nullptr-const-char-format--nullptr
  void record({String? to, String? format}) {
    _platform.record(_getId(this), to: to, format: format);
  }

  /// Take a snapshot for current rendered frame.
  ///
  /// [width] snapshot width. if not set, result is `mediaInfo.video[current_track].codec.width`
  /// [height] snapshot height. if not set, result is `mediaInfo.video[current_track].codec.height`
  /// Return rgba data of image size [width]x[height], stride is `width*4`
  Future<Uint8List?> snapshot({int? width, int? height}) async {
    return _platform.snapshot(_getId(this), width: width, height: height);
  }

  /// Set position range in milliseconds. Can be used by A-B loop.
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setrangeint64_t-a-int64_t-b--int64_max
  void setRange({required int from, int to = -1}) {
    _platform.setRange(_getId(this), from: from, to: to);
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
  /// NOTE: default values are set in [VideoPlayerController] constructor if 'lowLatency' is enabled in [registerWith]
  void setBufferRange({int min = -1, int max = -1, bool drop = false}) {
    _platform.setBufferRange(_getId(this), min: min, max: max, drop: drop);
  }

  /// fast seek to a key frame
  Future<void> fastSeekTo(Duration position) async {
    return _platform.fastSeekTo(_getId(this), position);
  }

  /// Step forward or backward.
  /// Step forward if [frames] > 0, backward otherwise.
  Future<void> step({int frames = 1}) async {
    return _platform.step(_getId(this), frames);
  }

  /// set brightness. -1 <= [value] <= 1
  void setBrightness(double value) {
    _platform.setBrightness(_getId(this), value);
  }

  /// set contrast. -1 <= [value] <= 1
  void setContrast(double value) {
    _platform.setContrast(_getId(this), value);
  }

  /// set hue. -1 <= [value] <= 1
  void setHue(double value) {
    _platform.setHue(_getId(this), value);
  }

  /// set saturation. -1 <= [value] <= 1
  void setSaturation(double value) {
    _platform.setSaturation(_getId(this), value);
  }

  /// Set a program to play. used by mpegts programs or hls.
  /// [programId] is the index in [MediaInfo.programs]
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setactivetracksmediatype-type-const-stdsetint-tracks
  void setProgram(int programId) {
    _platform.setProgram(_getId(this), programId);
  }

  /// Set active audio tracks. Other tracks will be disabled.
  /// The tracks can be from data source from [VideoPlayerController] constructor, or an external audio data source via [setExternalAudio]
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setactivetracksmediatype-type-const-stdsetint-tracks
  void setAudioTracks(List<int> value) {
    _platform.setAudioTracks(_getId(this), value);
  }

  /// Get active audio tracks.
  List<int>? getActiveAudioTracks() {
    return _platform.getActiveAudioTracks(_getId(this));
  }

  /// Set active video tracks. Other tracks will be disabled.
  /// The tracks can be from data source from [VideoPlayerController] constructor, or an external video data source via [setExternalVideo]
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setactivetracksmediatype-type-const-stdsetint-tracks
  void setVideoTracks(List<int> value) {
    _platform.setVideoTracks(_getId(this), value);
  }

  /// Get active video tracks.
  List<int>? getActiveVideoTracks() {
    return _platform.getActiveVideoTracks(_getId(this));
  }

  /// Set active subtitle tracks. Other tracks will be disabled.
  /// The tracks can be from data source from [VideoPlayerController] constructor, or an external subtitle data source via [setExternalSubtitle]
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setactivetracksmediatype-type-const-stdsetint-tracks
  void setSubtitleTracks(List<int> value) {
    _platform.setSubtitleTracks(_getId(this), value);
  }

  /// Get active subtitle tracks.
  List<int>? getActiveSubtitleTracks() {
    return _platform.getActiveSubtitleTracks(_getId(this));
  }

  /// set an external audio data source
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setmediaconst-char-url-mediatype-type
  void setExternalAudio(String uri) {
    _platform.setExternalAudio(_getId(this), uri);
  }

  /// set an external video data source
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setmediaconst-char-url-mediatype-type
  void setExternalVideo(String uri) {
    _platform.setExternalVideo(_getId(this), uri);
  }

  /// set an external subtitle data source
  /// https://github.com/wang-bin/mdk-sdk/wiki/Player-APIs#void-setmediaconst-char-url-mediatype-type
  void setExternalSubtitle(String uri) {
    _platform.setExternalSubtitle(_getId(this), uri);
  }

  /// Set a callback to receive subtitle text when active subtitle track renders a new piece of text.
  /// [start] and [end] are in seconds. [text] is the subtitle text lines. Pass null to disable.
  void onSubtitleText(
    void Function(double start, double end, List<String> text)? callback,
  ) {
    _platform.onSubtitleText(_getId(this), callback);
  }
}
