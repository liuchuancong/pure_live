// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:better_player_plus/src/configuration/better_player_buffering_configuration.dart';
import 'package:better_player_plus/src/video_player/method_channel_video_player.dart';
import 'package:better_player_plus/src/video_player/video_player.dart' show VideoPlayerController;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The interface that implementations of video_player must implement.
///
/// Platform implementations should extend this class rather than implement it as `video_player`
/// does not consider newly added methods to be breaking changes. Extending this class
/// (using `extends`) ensures that the subclass will get the default implementation, while
/// platform implementations that `implements` this interface will be broken by newly added
/// [VideoPlayerPlatform] methods.
abstract class VideoPlayerPlatform {
  /// Only mock implementations should set this to true.
  ///
  /// Mockito mocks are implementing this class with `implements` which is forbidden for anything
  /// other than mocks (see class docs). This property provides a backdoor for mockito mocks to
  /// skip the verification that the class isn't implemented with `implements`.
  @visibleForTesting
  bool get isMock => false;

  static VideoPlayerPlatform _instance = MethodChannelVideoPlayer();

  /// The default instance of [VideoPlayerPlatform] to use.
  ///
  /// Platform-specific plugins should override this with their own
  /// platform-specific class that extends [VideoPlayerPlatform] when they
  /// register themselves.
  ///
  /// Defaults to [MethodChannelVideoPlayer].
  static VideoPlayerPlatform get instance => _instance;

  // https://github.com/flutter/flutter/issues/43368
  static set instance(VideoPlayerPlatform instance) {
    if (!instance.isMock) {
      try {
        instance._verifyProvidesDefaultImplementations();
      } catch (_) {
        throw AssertionError('Platform interfaces must not be implemented with `implements`');
      }
    }
    _instance = instance;
  }

  /// Initializes the platform interface and disposes all existing players.
  ///
  /// This method is called when the plugin is first initialized
  /// and on every full restart.
  Future<void> init() {
    throw UnimplementedError('init() has not been implemented.');
  }

  /// Clears one video.
  Future<void> dispose(int? textureId) {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  /// Creates an instance of a video player and returns its textureId.
  Future<int?> create({BetterPlayerBufferingConfiguration? bufferingConfiguration}) {
    throw UnimplementedError('create() has not been implemented.');
  }

  /// Pre-caches a video.
  Future<void> preCache(DataSource dataSource, int preCacheSize) {
    throw UnimplementedError('preCache() has not been implemented.');
  }

  /// Pre-caches a video.
  Future<void> stopPreCache(String url, String? cacheKey) {
    throw UnimplementedError('stopPreCache() has not been implemented.');
  }

  /// Set data source of video.
  Future<void> setDataSource(int? textureId, DataSource dataSource) {
    throw UnimplementedError('setDataSource() has not been implemented.');
  }

  /// Returns a Stream of [VideoEventType]s.
  Stream<VideoEvent> videoEventsFor(int? textureId) {
    throw UnimplementedError('videoEventsFor() has not been implemented.');
  }

  /// Sets the looping attribute of the video.
  Future<void> setLooping(int? textureId, bool looping) {
    throw UnimplementedError('setLooping() has not been implemented.');
  }

  /// Starts the video playback.
  Future<void> play(int? textureId) {
    throw UnimplementedError('play() has not been implemented.');
  }

  /// Stops the video playback.
  Future<void> pause(int? textureId) {
    throw UnimplementedError('pause() has not been implemented.');
  }

  /// Sets the volume to a range between 0.0 and 1.0.
  Future<void> setVolume(int? textureId, double volume) {
    throw UnimplementedError('setVolume() has not been implemented.');
  }

  /// Sets the video speed to a range between 0.0 and 2.0
  Future<void> setSpeed(int? textureId, double speed) {
    throw UnimplementedError('setSpeed() has not been implemented.');
  }

  Future<void> setAspectRatio(int? textureId, String aspectRatio) {
    throw UnimplementedError('setAspectRatio() has not been implemented.');
  }

  /// Sets the video track parameters (used to select quality of the video)
  Future<void> setTrackParameters(int? textureId, int? width, int? height, int? bitrate) {
    throw UnimplementedError('setTrackParameters() has not been implemented.');
  }

  /// Sets the video position to a [Duration] from the start.
  Future<void> seekTo(int? textureId, Duration? position) {
    throw UnimplementedError('seekTo() has not been implemented.');
  }

  /// Gets the video position as [Duration] from the start.
  Future<Duration> getPosition(int? textureId) {
    throw UnimplementedError('getPosition() has not been implemented.');
  }

  /// Gets the video position as [DateTime].
  Future<DateTime?> getAbsolutePosition(int? textureId) {
    throw UnimplementedError('getAbsolutePosition() has not been implemented.');
  }

  ///Enables PiP mode.
  Future<void> enablePictureInPicture(int? textureId, double? top, double? left, double? width, double? height) {
    throw UnimplementedError('enablePictureInPicture() has not been implemented.');
  }

  ///Disables PiP mode.
  Future<void> disablePictureInPicture(int? textureId) {
    throw UnimplementedError('disablePictureInPicture() has not been implemented.');
  }

  Future<bool?> isPictureInPictureEnabled(int? textureId) {
    throw UnimplementedError('isPictureInPictureEnabled() has not been implemented.');
  }

  Future<void> setAudioTrack(int? textureId, String? name, int? index) {
    throw UnimplementedError('setAudio() has not been implemented.');
  }

  Future<void> setMixWithOthers(int? textureId, bool mixWithOthers) {
    throw UnimplementedError('setMixWithOthers() has not been implemented.');
  }

  Future<void> clearCache() {
    throw UnimplementedError('clearCache() has not been implemented.');
  }

  /// Returns a widget displaying the video with a given textureID.
  Widget buildView(int? textureId) {
    throw UnimplementedError('buildView() has not been implemented.');
  }

  // This method makes sure that VideoPlayer isn't implemented with `implements`.
  //
  // See class docs for more details on why implementing this class is forbidden.
  //
  // This private method is called by the instance setter, which fails if the class is
  // implemented with `implements`.
  void _verifyProvidesDefaultImplementations() {}
}

/// Description of the data source used to create an instance of
/// the video player.
class DataSource {
  /// Constructs an instance of [DataSource].
  ///
  /// The [sourceType] is always required.
  ///
  /// The [uri] argument takes the form of `'https://example.com/video.mp4'` or
  /// `'file://${file.path}'`.
  ///
  /// The [formatHint] argument can be null.
  ///
  /// The [asset] argument takes the form of `'assets/video.mp4'`.
  ///
  /// The [package] argument must be non-null when the asset comes from a
  /// package and null otherwise.
  ///
  DataSource({
    required this.sourceType,
    this.uri,
    this.formatHint,
    this.asset,
    this.package,
    this.headers,
    this.useCache = false,
    this.maxCacheSize = _maxCacheSize,
    this.maxCacheFileSize = _maxCacheFileSize,
    this.cacheKey,
    this.showNotification = false,
    this.title,
    this.author,
    this.imageUrl,
    this.notificationChannelName,
    this.overriddenDuration,
    this.licenseUrl,
    this.certificateUrl,
    this.drmHeaders,
    this.activityName,
    this.clearKey,
    this.videoExtension,
  }) : assert(uri == null || asset == null, 'You can provide uri or asset but not both.');

  /// The maximum cache size to keep on disk in bytes.
  static const int _maxCacheSize = 100 * 1024 * 1024;

  /// The maximum size of each individual file in bytes.
  static const int _maxCacheFileSize = 10 * 1024 * 1024;

  /// Describes the type of data source this [VideoPlayerController]
  /// is constructed with.
  ///
  /// The way in which the video was originally loaded.
  ///
  /// This has nothing to do with the video's file type. It's just the place
  /// from which the video is fetched from.
  final DataSourceType sourceType;

  /// The URI to the video file.
  ///
  /// This will be in different formats depending on the [DataSourceType] of
  /// the original video.
  final String? uri;

  /// **Android only**. Will override the platform's generic file format
  /// detection with whatever is set here.
  final VideoFormat? formatHint;

  /// **Android only**. String representation of a formatHint.
  String? get rawFormalHint {
    switch (formatHint) {
      case VideoFormat.ss:
        return 'ss';
      case VideoFormat.hls:
        return 'hls';
      case VideoFormat.dash:
        return 'dash';
      case VideoFormat.other:
        return 'other';
      default:
        return null;
    }
  }

  /// The name of the asset. Only set for [DataSourceType.asset] videos.
  final String? asset;

  /// The package that the asset was loaded from. Only set for
  /// [DataSourceType.asset] videos.
  final String? package;

  final Map<String, String?>? headers;

  final bool useCache;

  final int? maxCacheSize;

  final int? maxCacheFileSize;

  final String? cacheKey;

  final bool? showNotification;

  final String? title;

  final String? author;

  final String? imageUrl;

  final String? notificationChannelName;

  final Duration? overriddenDuration;

  final String? licenseUrl;

  final String? certificateUrl;

  final Map<String, String>? drmHeaders;

  final String? activityName;

  final String? clearKey;

  final String? videoExtension;

  /// Key to compare DataSource
  String get key {
    String? result = '';

    if (uri != null && uri!.isNotEmpty) {
      result = uri;
    } else if (package != null && package!.isNotEmpty) {
      result = '$package:$asset';
    } else {
      result = asset;
    }

    if (formatHint != null) {
      result = '$result:$rawFormalHint';
    }

    return result!;
  }

  @override
  String toString() =>
      'DataSource{sourceType: $sourceType, uri: $uri certificateUrl: $certificateUrl, formatHint:'
      ' $formatHint, asset: $asset, package: $package, headers: $headers,'
      ' useCache: $useCache,maxCacheSize: $maxCacheSize, maxCacheFileSize: '
      '$maxCacheFileSize, showNotification: $showNotification, title: $title,'
      ' author: $author}';
}

/// The way in which the video was originally loaded.
///
/// This has nothing to do with the video's file type. It's just the place
/// from which the video is fetched from.
enum DataSourceType {
  /// The video was included in the app's asset files.
  asset,

  /// The video was downloaded from the internet.
  network,

  /// The video was loaded off of the local filesystem.
  file,
}

/// The file format of the given video.
enum VideoFormat {
  /// Dynamic Adaptive Streaming over HTTP, also known as MPEG-DASH.
  dash,

  /// HTTP Live Streaming.
  hls,

  /// Smooth Streaming.
  ss,

  /// Any format other than the other ones defined in this enum.
  other,
}

/// Event emitted from the platform implementation.
@immutable
class VideoEvent {
  /// Creates an instance of [VideoEvent].
  ///
  /// The [eventType] argument is required.
  ///
  /// Depending on the [eventType], the [duration], [size] and [buffered]
  /// arguments can be null.
  const VideoEvent({
    required this.eventType,
    required this.key,
    this.duration,
    this.size,
    this.buffered,
    this.position,
  });

  /// The type of the event.
  final VideoEventType eventType;

  /// Data source of the video.
  ///
  /// Used to determine which video the event belongs to.
  final String? key;

  /// Duration of the video.
  ///
  /// Only used if [eventType] is [VideoEventType.initialized].
  final Duration? duration;

  /// Size of the video.
  ///
  /// Only used if [eventType] is [VideoEventType.initialized].
  final Size? size;

  /// Buffered parts of the video.
  ///
  /// Only used if [eventType] is [VideoEventType.bufferingUpdate].
  final List<DurationRange>? buffered;

  ///Seek position
  final Duration? position;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoEvent &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          eventType == other.eventType &&
          duration == other.duration &&
          size == other.size &&
          listEquals(buffered, other.buffered);

  @override
  int get hashCode => eventType.hashCode ^ duration.hashCode ^ size.hashCode ^ buffered.hashCode;
}

/// Type of the event.
///
/// Emitted by the platform implementation when the video is initialized or
/// completed or to communicate buffering events.
enum VideoEventType {
  /// The video has been initialized.
  initialized,

  /// The playback has ended.
  completed,

  /// Updated information on the buffering state.
  bufferingUpdate,

  /// The video started to buffer.
  bufferingStart,

  /// The video stopped to buffer.
  bufferingEnd,

  /// The video is set to play
  play,

  /// The video is set to pause
  pause,

  /// The video is set to given to position
  seek,

  /// The video is displayed in Picture in Picture mode
  pipStart,

  /// Picture in picture mode has been dismissed
  pipStop,

  /// An unknown event has been received.
  unknown,
}

/// Describes a discrete segment of time within a video using a [start] and
/// [end] [Duration].
@immutable
class DurationRange {
  /// Trusts that the given [start] and [end] are actually in order. They should
  /// both be non-null.
  const DurationRange(this.start, this.end);

  /// The beginning of the segment described relative to the beginning of the
  /// entire video. Should be shorter than or equal to [end].
  ///
  /// For example, if the entire video is 4 minutes long and the range is from
  /// 1:00-2:00, this should be a `Duration` of one minute.
  final Duration start;

  /// The end of the segment described as a duration relative to the beginning of
  /// the entire video. This is expected to be non-null and longer than or equal
  /// to [start].
  ///
  /// For example, if the entire video is 4 minutes long and the range is from
  /// 1:00-2:00, this should be a `Duration` of two minutes.
  final Duration end;

  /// Assumes that [duration] is the total length of the video that this
  /// DurationRange is a segment form. It returns the percentage that [start] is
  /// through the entire video.
  ///
  /// For example, assume that the entire video is 4 minutes long. If [start] has
  /// a duration of one minute, this will return `0.25` since the DurationRange
  /// starts 25% of the way through the video's total length.
  double startFraction(Duration duration) => start.inMilliseconds / duration.inMilliseconds;

  /// Assumes that [duration] is the total length of the video that this
  /// DurationRange is a segment form. It returns the percentage that [start] is
  /// through the entire video.
  ///
  /// For example, assume that the entire video is 4 minutes long. If [end] has a
  /// duration of two minutes, this will return `0.5` since the DurationRange
  /// ends 50% of the way through the video's total length.
  double endFraction(Duration duration) => end.inMilliseconds / duration.inMilliseconds;

  @override
  String toString() => 'DurationRange(start: $start, end: $end)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DurationRange && runtimeType == other.runtimeType && start == other.start && end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}
