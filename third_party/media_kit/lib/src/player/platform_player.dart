/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:collection/collection.dart';

import 'package:media_kit/src/models/track.dart';
import 'package:media_kit/src/models/playable.dart';
import 'package:media_kit/src/models/playlist.dart';
import 'package:media_kit/src/models/player_log.dart';
import 'package:media_kit/src/models/media/media.dart';
import 'package:media_kit/src/models/audio_device.dart';
import 'package:media_kit/src/models/audio_params.dart';
import 'package:media_kit/src/models/video_params.dart';
import 'package:media_kit/src/models/player_state.dart';
import 'package:media_kit/src/models/playlist_mode.dart';
import 'package:media_kit/src/models/player_stream.dart';

/// {@template platform_player}
/// PlatformPlayer
/// --------------
///
/// This class provides the interface for platform specific [Player] implementations.
/// The platform specific implementations are expected to implement the methods accordingly.
///
/// The subclasses are then used in composition with the [Player] class, based on the platform the application is running on.
///
/// {@endtemplate}
abstract class PlatformPlayer {
  /// {@macro platform_player}
  PlatformPlayer({required this.configuration});

  /// User defined configuration for [Player].
  final PlayerConfiguration configuration;

  /// Current state of the player.
  late PlayerState state = PlayerState();

  /// Current state of the player available as listenable [Stream]s.
  late PlayerStream stream = PlayerStream(
    playlistController.stream.distinct(
      (previous, current) => previous == current,
    ),
    playingController.stream.distinct(
      (previous, current) => previous == current,
    ),
    completedController.stream.distinct(
      (previous, current) => previous == current,
    ),
    positionController.stream.distinct(
      (previous, current) => previous == current,
    ),
    durationController.stream.distinct(
      (previous, current) => previous == current,
    ),
    volumeController.stream.distinct(
      (previous, current) => previous == current,
    ),
    rateController.stream.distinct(
      (previous, current) => previous == current,
    ),
    pitchController.stream.distinct(
      (previous, current) => previous == current,
    ),
    bufferingController.stream.distinct(
      (previous, current) => previous == current,
    ),
    bufferingPercentageController.stream.distinct(
      (previous, current) => previous == current,
    ),
    bufferController.stream.distinct(
      (previous, current) => previous == current,
    ),
    playlistModeController.stream.distinct(
      (previous, current) => previous == current,
    ),
    /* AUDIO-PARAMS STREAM SHOULD NOT BE DISTINCT */
    audioParamsController.stream,
    /* VIDEO-PARAMS STREAM SHOULD NOT BE DISTINCT */
    videoParamsController.stream,
    audioBitrateController.stream.distinct(
      (previous, current) => previous == current,
    ),
    videoBitrateController.stream.distinct(
      (previous, current) => previous == current,
    ),
    audioDeviceController.stream.distinct(
      (previous, current) => previous == current,
    ),
    audioDevicesController.stream.distinct(
      (previous, current) => ListEquality().equals(previous, current),
    ),
    trackController.stream.distinct(
      (previous, current) => previous == current,
    ),
    tracksController.stream.distinct(
      (previous, current) => previous == current,
    ),
    widthController.stream.distinct(
      (previous, current) => previous == current,
    ),
    heightController.stream.distinct(
      (previous, current) => previous == current,
    ),
    subtitleController.stream.distinct(
      (previous, current) => ListEquality().equals(previous, current),
    ),
    logController.stream.distinct(
      (previous, current) => previous == current,
    ),
    /* ERROR STREAM SHOULD NOT BE DISTINCT */
    errorController.stream,
  );

  @mustCallSuper
  Future<void> dispose() async {
    await Future.wait(
      [
        playlistController.close(),
        playingController.close(),
        completedController.close(),
        positionController.close(),
        durationController.close(),
        volumeController.close(),
        rateController.close(),
        pitchController.close(),
        bufferingController.close(),
        bufferingPercentageController.close(),
        bufferController.close(),
        playlistModeController.close(),
        audioParamsController.close(),
        videoParamsController.close(),
        audioBitrateController.close(),
        videoBitrateController.close(),
        audioDeviceController.close(),
        audioDevicesController.close(),
        trackController.close(),
        tracksController.close(),
        widthController.close(),
        heightController.close(),
        subtitleController.close(),
        logController.close(),
        errorController.close(),
      ],
    );
    for (final callback in release) {
      try {
        await callback.call();
      } catch (exception, stacktrace) {
        print(exception.toString());
        print(stacktrace.toString());
      }
    }
  }

  Future<void> open(
    Playable playable, {
    bool play = true,
  }) {
    throw UnimplementedError(
      '[PlatformPlayer.open] is not implemented',
    );
  }

  Future<void> stop() {
    throw UnimplementedError(
      '[PlatformPlayer.stop] is not implemented',
    );
  }

  Future<void> play() {
    throw UnimplementedError(
      '[PlatformPlayer.play] is not implemented',
    );
  }

  Future<void> pause() {
    throw UnimplementedError(
      '[PlatformPlayer.pause] is not implemented',
    );
  }

  Future<void> playOrPause() {
    throw UnimplementedError(
      '[PlatformPlayer.playOrPause] is not implemented',
    );
  }

  Future<void> add(Media media) {
    throw UnimplementedError(
      '[PlatformPlayer.add] is not implemented',
    );
  }

  Future<void> remove(int index) {
    throw UnimplementedError(
      '[PlatformPlayer.remove] is not implemented',
    );
  }

  Future<void> next() {
    throw UnimplementedError(
      '[PlatformPlayer.next] is not implemented',
    );
  }

  Future<void> previous() {
    throw UnimplementedError(
      '[PlatformPlayer.previous] is not implemented',
    );
  }

  Future<void> jump(int index) {
    throw UnimplementedError(
      '[PlatformPlayer.jump] is not implemented',
    );
  }

  Future<void> move(int from, int to) {
    throw UnimplementedError(
      '[PlatformPlayer.move] is not implemented',
    );
  }

  Future<void> seek(Duration duration) {
    throw UnimplementedError(
      '[PlatformPlayer.seek] is not implemented',
    );
  }

  Future<void> setPlaylistMode(PlaylistMode playlistMode) {
    throw UnimplementedError(
      '[PlatformPlayer.setPlaylistMode] is not implemented',
    );
  }

  Future<void> setVolume(double volume) {
    throw UnimplementedError(
      '[PlatformPlayer.volume] is not implemented',
    );
  }

  Future<void> setRate(double rate) {
    throw UnimplementedError(
      '[PlatformPlayer.rate] is not implemented',
    );
  }

  Future<void> setPitch(double pitch) {
    throw UnimplementedError(
      '[PlatformPlayer.pitch] is not implemented',
    );
  }

  Future<void> setShuffle(bool shuffle) {
    throw UnimplementedError(
      '[PlatformPlayer.shuffle] is not implemented',
    );
  }

  Future<void> setAudioDevice(AudioDevice audioDevice) {
    throw UnimplementedError(
      '[PlatformPlayer.setAudioDevice] is not implemented',
    );
  }

  Future<void> setVideoTrack(VideoTrack track) {
    throw UnimplementedError(
      '[PlatformPlayer.setVideoTrack] is not implemented',
    );
  }

  Future<void> setAudioTrack(AudioTrack track) {
    throw UnimplementedError(
      '[PlatformPlayer.setAudioTrack] is not implemented',
    );
  }

  Future<void> setSubtitleTrack(SubtitleTrack track) {
    throw UnimplementedError(
      '[PlatformPlayer.setSubtitleTrack] is not implemented',
    );
  }

  Future<Uint8List?> screenshot(
      {String? format = 'image/jpeg',
      bool includeLibassSubtitles = false}) async {
    throw UnimplementedError(
      '[PlatformPlayer.screenshot] is not implemented',
    );
  }

  Future<Uint8List?> safeScreenshot(
      {String? format = 'image/jpeg',
      bool includeLibassSubtitles = false}) async {
    throw UnimplementedError(
      '[PlatformPlayer.safeScreenshot] is not implemented',
    );
  }

  Future<int> get handle {
    throw UnimplementedError(
      '[PlatformPlayer.handle] is not implemented',
    );
  }

  @protected
  final StreamController<Playlist> playlistController =
      StreamController<Playlist>.broadcast();

  @protected
  final StreamController<bool> playingController =
      StreamController<bool>.broadcast();

  @protected
  final StreamController<bool> completedController =
      StreamController<bool>.broadcast();

  @protected
  final StreamController<Duration> positionController =
      StreamController<Duration>.broadcast();

  @protected
  final StreamController<Duration> durationController =
      StreamController.broadcast();

  @protected
  final StreamController<double> volumeController =
      StreamController.broadcast();

  @protected
  final StreamController<double> rateController =
      StreamController<double>.broadcast();

  @protected
  final StreamController<double> pitchController =
      StreamController<double>.broadcast();

  @protected
  final StreamController<bool> bufferingController =
      StreamController<bool>.broadcast();
  @protected
  final StreamController<double> bufferingPercentageController =
      StreamController<double>.broadcast();
  @protected
  final StreamController<Duration> bufferController =
      StreamController<Duration>.broadcast();

  @protected
  final StreamController<PlaylistMode> playlistModeController =
      StreamController<PlaylistMode>.broadcast();

  @protected
  final StreamController<PlayerLog> logController =
      StreamController<PlayerLog>.broadcast();

  @protected
  final StreamController<String> errorController =
      StreamController<String>.broadcast();

  @protected
  final StreamController<AudioParams> audioParamsController =
      StreamController<AudioParams>.broadcast();

  @protected
  final StreamController<VideoParams> videoParamsController =
      StreamController<VideoParams>.broadcast();

  @protected
  final StreamController<double?> audioBitrateController =
      StreamController<double?>.broadcast();

  @protected
  final StreamController<double?> videoBitrateController =
      StreamController<double?>.broadcast();

  @protected
  final StreamController<AudioDevice> audioDeviceController =
      StreamController<AudioDevice>.broadcast();

  @protected
  final StreamController<List<AudioDevice>> audioDevicesController =
      StreamController<List<AudioDevice>>.broadcast();

  @protected
  final StreamController<Track> trackController =
      StreamController<Track>.broadcast();

  @protected
  final StreamController<Tracks> tracksController =
      StreamController<Tracks>.broadcast();

  @protected
  final StreamController<int?> widthController =
      StreamController<int?>.broadcast();

  @protected
  final StreamController<int?> heightController =
      StreamController<int?>.broadcast();

  @protected
  final StreamController<List<String>> subtitleController =
      StreamController<List<String>>.broadcast();

  // --------------------------------------------------

  /// [Completer] to wait for initialization of this instance.
  final Completer<void> completer = Completer<void>();

  /// [Future<void>] to wait for initialization of this instance.
  Future<void> get waitForPlayerInitialization => completer.future;

  // --------------------------------------------------

  /// [bool] for signaling [VideoController] (from `package:media_kit_video`) initialization.
  bool isVideoControllerAttached = false;

  /// [Completer] for signaling [VideoController] (from `package:media_kit_video`) initialization.
  final Completer<void> videoControllerCompleter = Completer<void>();

  /// [Future<void>] to wait for [VideoController] (from `package:media_kit_video`) initialization.
  Future<void> get waitForVideoControllerInitializationIfAttached {
    if (isVideoControllerAttached) {
      return videoControllerCompleter.future;
    }
    return Future.value(null);
  }

  // --------------------------------------------------

  /// Publicly defined clean-up [Function]s which must be called before [dispose].
  final List<Future<void> Function()> release = [];
}

/// {@template player_configuration}
///
/// PlayerConfiguration
/// --------------------
/// Configurable options for customizing the [Player] behavior.
///
/// {@endtemplate}
class PlayerConfiguration {
  /// Sets the video output driver for native backend.
  ///
  /// Default: `null`.
  final String? vo;

  /// Enables on-screen controls for native backend.
  ///
  /// Default: `false`.
  final bool osc;

  /// Enables or disables pitch shift control for native backend.
  ///
  /// Enabling this option may result in de-syncing of audio & video.
  /// Thus, usage in audio only applications is recommended.
  /// This uses `scaletempo` under the hood & disables `audio-pitch-correction`.
  ///
  /// See: https://github.com/media-kit/media-kit/issues/45
  ///
  /// Default: `false`.
  final bool pitch;

  /// Sets the name of the underlying window & process for native backend.
  /// This is visible inside the Windows' volume mixer.
  ///
  /// Default: `null`.
  final String title;

  /// Optional callback invoked when the internals of the [Player] are initialized & ready for playback.
  ///
  /// Default: `null`.
  final void Function()? ready;

  /// Whether [Player] must be started in muted state.
  ///
  /// Default: `false`.
  final bool muted;

  /// Whether to use the async API for native backend.
  ///
  /// Default: `true`.
  final bool async;

  /// Whether to use [libass](https://github.com/libass/libass) based subtitle rendering for native backend.
  ///
  /// By default, subtitles rendering is Flutter `Widget` based.
  ///
  /// On Android, this option requires [libassAndroidFont] to be set.
  final bool libass;

  /// Asset name of the `.ttf` font file to be used for [libass](https://github.com/libass/libass) based subtitle rendering on Android.
  ///
  /// e.g. `assets/fonts/subtitle.ttf`
  final String? libassAndroidFont;

  /// Font name of the `.ttf` font file to be used for [libass](https://github.com/libass/libass) based subtitle rendering on Android.
  ///
  /// e.g. `Droid Sans Fallback`
  ///
  /// NOTE: The font name is required, not the file name.
  final String? libassAndroidFontName;

  /// Sets the log level on native backend.
  /// Default: `none`.
  final MPVLogLevel logLevel;

  /// Sets the demuxer cache size (in bytes) for native backend.
  ///
  /// Default: `32` MB or `32 * 1024 * 1024` bytes.
  final int bufferSize;

  /// Sets the list of allowed protocols for native backend.
  ///
  /// Default: `['file', 'tcp', 'tls', 'http', 'https', 'crypto', 'data']`.
  ///
  /// Learn more: https://ffmpeg.org/ffmpeg-protocols.html#Protocol-Options
  final List<String> protocolWhitelist;

  /// Enables HLS ad filtering via `hls_ad_filter`.
  ///
  /// Default: `false` (pass `hls_ad_filter=0`).
  /// When set to `true`, `hls_ad_filter=1` is passed to disable ads.
  final bool adBlocker;

  /// {@macro player_configuration}
  const PlayerConfiguration({
    this.vo = 'null',
    this.osc = false,
    this.pitch = false,
    this.title = 'package:media_kit',
    this.ready,
    this.muted = false,
    this.async = true,
    this.libass = false,
    this.libassAndroidFont,
    this.libassAndroidFontName,
    this.logLevel = MPVLogLevel.error,
    this.bufferSize = 32 * 1024 * 1024,
    this.protocolWhitelist = const [
      'udp',
      'rtp',
      'tcp',
      'tls',
      'data',
      'file',
      'http',
      'httpproxy',
      'https',
      'crypto',
    ],
    this.adBlocker = false,
  });
}

/// {@template mpv_log_level}
///
/// MPVLogLevel
/// --------------------
/// Options to customise the [Player] native backend log level.
///
/// {@endtemplate}
enum MPVLogLevel {
  /// Disable absolutely all messages.
  /* none, */

  /// Critical/aborting errors.
  /* fatal, */

  // package:media_kit internally consumes logs of level error.

  /// Simple errors.
  error,

  /// Possible problems.
  warn,

  /// Informational message.
  info,

  /// Noisy informational message.
  v,

  /// Very noisy technical information.
  debug,

  /// Extremely noisy.
  trace,
}
