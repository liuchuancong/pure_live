// This file is a part of media_kit (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:io';
import 'dart:ffi';
import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:path/path.dart';
import 'package:meta/meta.dart';
import 'package:image/image.dart';
import 'package:synchronized/synchronized.dart';
import 'package:safe_local_storage/safe_local_storage.dart';

import 'package:media_kit/ffi/ffi.dart';

import 'package:media_kit/src/models/audio_device.dart';
import 'package:media_kit/src/models/audio_params.dart';
import 'package:media_kit/src/models/media/media.dart';
import 'package:media_kit/src/models/playable.dart';
import 'package:media_kit/src/models/player_log.dart';
import 'package:media_kit/src/models/player_state.dart';
import 'package:media_kit/src/models/playlist_mode.dart';
import 'package:media_kit/src/models/playlist.dart';
import 'package:media_kit/src/models/track.dart';
import 'package:media_kit/src/models/video_params.dart';
import 'package:media_kit/src/player/native/core/fallback_bitrate_handler.dart';
import 'package:media_kit/src/player/native/core/native_event_loop.dart';
import 'package:media_kit/src/player/native/core/native_library.dart';
import 'package:media_kit/src/player/native/utils/android_asset_loader.dart';
import 'package:media_kit/src/player/native/utils/android_helper.dart';
import 'package:media_kit/src/player/native/utils/isolates.dart';
import 'package:media_kit/src/player/native/utils/temp_file.dart';
import 'package:media_kit/src/player/platform_player.dart';

import 'package:media_kit/generated/libmpv/bindings.dart' as generated;

/// Initializes the native backend for package:media_kit.
void nativeEnsureInitialized({String? libmpv}) {
  NativeLibrary.ensureInitialized(libmpv: libmpv);
  AndroidHelper.ensureInitialized(libmpv: NativeLibrary.path);
}

/// {@template native_player}
///
/// NativePlayer
/// ------------
///
/// Native implementation of [PlatformPlayer].
///
/// {@endtemplate}
class NativePlayer extends PlatformPlayer {
  /// {@macro native_player}
  NativePlayer({required super.configuration})
    : nativeLibraryPath = NativeLibrary.path,
      mpv = generated.MPV(DynamicLibrary.open(NativeLibrary.path)) {
    future = _create();
    unawaited(
      future!.then(
        (_) {
          try {
            configuration.ready?.call();
          } catch (_) {}
        },
        onError: (Object error, StackTrace stack) {
          if (!errorController.isClosed) errorController.add(error.toString());
        },
      ),
    );
  }

  /// Disposes the [Player] instance & releases the resources.
  @override
  Future<void> dispose({bool synchronized = true}) {
    Future<void> function() async {
      try {
        await waitForPlayerInitialization;
        await waitForVideoControllerInitializationIfAttached;
        await stop(notify: false, synchronized: false);
      } finally {
        disposed = true;
        try {
          // Release video render contexts before shutting down the mpv core.
          await super.dispose();
        } finally {
          await _eventLoop?.dispose();
          ctx = nullptr;
          _eventLoop = null;
          for (final request in [
            ..._setPropertyRequests.values,
            ..._commandRequests.values,
            ..._screenshotRequests.values.map((request) => request.completer),
          ]) {
            request.completeError(StateError('Player has been disposed'));
          }
          _setPropertyRequests.clear();
          _commandRequests.clear();
          _screenshotRequests.clear();
        }
      }
    }

    return _disposeFuture ??= synchronized
        ? lock.synchronized(function)
        : function();
  }

  @override
  Future<void> get waitForPlayerInitialization async {
    // A failed create must propagate instead of waiting forever for idle-active.
    await future;
    await super.waitForPlayerInitialization;
  }

  /// Opens a [Media] or [Playlist] into the [Player].
  /// Passing [play] as `true` starts the playback immediately.
  ///
  /// ```dart
  /// await player.open(Media('asset:///assets/videos/sample.mp4'));
  /// await player.open(Media('file:///C:/Users/Hitesh/Music/Sample.mp3'));
  /// await player.open(
  ///   Playlist(
  ///     [
  ///       Media('file:///C:/Users/Hitesh/Music/Sample.mp3'),
  ///       Media('file:///C:/Users/Hitesh/Video/Sample.mkv'),
  ///       Media('https://www.example.com/sample.mp4'),
  ///       Media('rtsp://www.example.com/live'),
  ///     ],
  ///   ),
  /// );
  /// ```
  ///
  @override
  Future<void> open(
    Playable playable, {
    bool play = true,
    bool synchronized = true,
  }) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      final int index;
      final List<Media> playlist = <Media>[];
      if (playable is Media) {
        index = 0;
        playlist.add(playable);
      } else if (playable is Playlist) {
        index = playable.index;
        playlist.addAll(playable.medias);
      } else {
        index = -1;
      }

      // Keep these [Media] objects in memory.
      current = playlist;

      // External List<Media>:
      // ---------------------------------------------
      state = state.copyWith(playlist: Playlist(playlist, index: index));
      if (!playlistController.isClosed) {
        playlistController.add(Playlist(playlist, index: index));
      }
      // ---------------------------------------------

      // Restore original state & reset public [PlayerState] & [PlayerStream] values e.g. width=null, height=null, subtitle=['', ''] etc.
      await stop(open: true, synchronized: false);

      // Enter paused state.
      await _setPropertyFlag('pause', true);

      if (playlist.any((media) => media.uri.startsWith('fd://'))) {
        // The fd:// scheme is used to reference content:// URIs on Android.
        // The loadlist command does not support this by default, yielding "Refusing to load potentially unsafe URL from a playlist."
        // So, we fallback to loading each file individually.
        for (int i = 0; i < playlist.length; i++) {
          await _command(['loadfile', playlist[i].uri, 'append']);
        }
      } else {
        final file = await TempFile.create();
        final buffer = StringBuffer();
        for (final media in playlist) {
          buffer.writeln(media.uri);
        }
        final list = buffer.toString();

        await file.write_(list);

        await _command(['loadlist', file.path, 'append']);

        Future.delayed(const Duration(seconds: 5), () {
          file.delete_();
        });
      }

      // If [play] is `true`, then exit paused state.
      if (play) {
        isPlayingStateChangeAllowed = true;
        await _setPropertyFlag('pause', false);
        state = state.copyWith(playing: true);
        if (!playingController.isClosed) {
          playingController.add(true);
        }
      }

      // Jump to the specified [index] (in both cases either [play] is `true` or `false`).
      await _setPropertyInt64('playlist-pos', index);
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Stops the [Player].
  /// Unloads the current [Media] or [Playlist] from the [Player]. This method is similar to [dispose] but does not release the resources & [Player] is still usable.
  @override
  Future<void> stop({
    bool open = false,
    bool notify = true,
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      isShuffleEnabled = false;
      isPlayingStateChangeAllowed = false;
      isBufferingStateChangeAllowed = false;

      final commands = [
        ['stop'],
        ['playlist-clear'],
        ['playlist-play-index', 'none'],
      ];
      for (final command in commands) {
        await _command(command);
      }

      // Reset the remaining attributes.
      state = PlayerState().copyWith(
        volume: state.volume,
        rate: state.rate,
        pitch: state.pitch,
        playlistMode: state.playlistMode,
        audioDevice: state.audioDevice,
        audioDevices: state.audioDevices,
      );
      if (notify) {
        if (!open) {
          // Do not emit PlayerStream.playlist if invoked from [open].
          if (!playlistController.isClosed) {
            playlistController.add(Playlist([]));
          }
        }
        if (!playingController.isClosed) {
          playingController.add(false);
        }
        if (!completedController.isClosed) {
          completedController.add(false);
        }
        if (!positionController.isClosed) {
          positionController.add(Duration.zero);
        }
        if (!durationController.isClosed) {
          durationController.add(Duration.zero);
        }
        if (!bufferingController.isClosed) {
          bufferingController.add(false);
        }
        if (!bufferController.isClosed) {
          bufferController.add(Duration.zero);
        }
        if (!videoParamsController.isClosed) {
          videoParamsController.add(const VideoParams());
        }
        if (!videoBitrateController.isClosed) {
          videoBitrateController.add(null);
        }
        if (!trackController.isClosed) {
          trackController.add(Track());
        }
        if (!tracksController.isClosed) {
          tracksController.add(Tracks());
        }
        if (!widthController.isClosed) {
          widthController.add(null);
        }
        if (!heightController.isClosed) {
          heightController.add(null);
        }
        if (!subtitleController.isClosed) {
          subtitleController.add(['', '']);
        }
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Starts playing the [Player].
  @override
  Future<void> play({bool synchronized = true}) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      state = state.copyWith(playing: true);
      if (!playingController.isClosed) {
        playingController.add(true);
      }

      isPlayingStateChangeAllowed = true;

      // This condition is specifically for the case when the internal playlist is ended (with [PlaylistLoopMode.none]), and we want to play the playlist again if play/pause is pressed.
      if (state.completed) {
        await seek(Duration.zero, synchronized: false);
        await _setPropertyInt64('playlist-pos', 0);
      }
      await _setPropertyFlag('pause', false);
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Pauses the [Player].
  @override
  Future<void> pause({bool synchronized = true}) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      state = state.copyWith(playing: false);
      if (!playingController.isClosed) {
        playingController.add(false);
      }

      isPlayingStateChangeAllowed = true;
      isBufferingStateChangeAllowed = false;
      await _setPropertyFlag('pause', true);
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Cycles between [play] & [pause] states of the [Player].
  @override
  Future<void> playOrPause({bool notify = true, bool synchronized = true}) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      if (notify) {
        // Do not change the [state.playing] value if [playOrPause] was called from [play] or [pause]; where the [state.playing] value is already changed.
        state = state.copyWith(playing: !state.playing);
        if (!playingController.isClosed) {
          playingController.add(state.playing);
        }
      }

      isPlayingStateChangeAllowed = true;
      isBufferingStateChangeAllowed = false;

      // This condition is specifically for the case when the internal playlist is ended (with [PlaylistLoopMode.none]), and we want to play the playlist again if play/pause is pressed.
      if (state.completed) {
        await seek(Duration.zero, synchronized: false);
        await _setPropertyInt64('playlist-pos', 0);
      }
      await _command(['cycle', 'pause']);
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Appends a [Media] to the [Player]'s playlist.
  @override
  Future<void> add(Media media, {bool synchronized = true}) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      // External List<Media>:
      // ---------------------------------------------
      // Force a new List<T> object.
      current = [...current, media];
      final playlist = state.playlist.copyWith(medias: current);
      state = state.copyWith(playlist: playlist);
      if (!playlistController.isClosed) {
        playlistController.add(playlist);
      }
      // ---------------------------------------------

      await _command(['loadfile', media.uri, 'append']);
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Removes the [Media] at specified index from the [Player]'s playlist.
  @override
  Future<void> remove(int index, {bool synchronized = true}) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      int currentIndex = state.playlist.index;

      // If we remove the last item in the playlist while playlist mode is none or single, then playback will stop.
      // In this situation, the playlist doesn't seem to be updated, so we manually update it.
      if (currentIndex == index &&
          current.length - 1 == index &&
          [
            PlaylistMode.none,
            PlaylistMode.single,
          ].contains(state.playlistMode)) {
        currentIndex = current.length - 2 < 0 ? 0 : current.length - 2;

        state = state.copyWith(
          // Allow playOrPause /w state.completed code-path to play the playlist again.
          completed: true,
          playlist: state.playlist.copyWith(
            medias: current.sublist(0, current.length - 1),
            index: currentIndex,
          ),
        );
        if (!completedController.isClosed) {
          completedController.add(true);
        }
        if (!playlistController.isClosed) {
          playlistController.add(state.playlist);
        }
      }
      // If we remove the last item in the playlist while playlist mode is loop, jump to the index 0.
      else if (state.playlist.index == index &&
          current.length - 1 == index &&
          state.playlistMode == PlaylistMode.loop) {
        currentIndex = 0;
        state = state.copyWith(
          // Allow playOrPause /w state.completed code-path to play the playlist again.
          completed: true,
          playlist: state.playlist.copyWith(
            medias: current.sublist(0, current.length - 1),
            index: 0,
          ),
        );
        if (!completedController.isClosed) {
          completedController.add(true);
        }
        if (!playlistController.isClosed) {
          playlistController.add(state.playlist);
        }
      }
      // Default
      else {
        current = [...current]; // Force a new List<T> object.
        current.removeAt(index);

        // If the current index is greater than the removed index, then the current index should be reduced by 1.
        // If the current index is equal or less than the removed index, then the current index should not be changed.
        if (state.playlist.index > index) {
          currentIndex--;
        }

        state = state.copyWith(
          playlist: state.playlist.copyWith(
            medias: current,
            index: currentIndex,
          ),
        );
        if (!playlistController.isClosed) {
          playlistController.add(state.playlist);
        }
      }

      await _command(['playlist-remove', index.toString()]);
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Jumps to next [Media] in the [Player]'s playlist.
  @override
  Future<void> next({bool synchronized = true}) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      // Do nothing if currently present at the first or last index & playlist mode is [PlaylistMode.none] or [PlaylistMode.single].
      if ([
            PlaylistMode.none,
            PlaylistMode.single,
          ].contains(state.playlistMode) &&
          state.playlist.index == state.playlist.medias.length - 1) {
        return;
      }

      await play(synchronized: false);
      await _command(['playlist-next']);
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Jumps to previous [Media] in the [Player]'s playlist.
  @override
  Future<void> previous({bool synchronized = true}) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      // Do nothing if currently present at the first or last index & playlist mode is [PlaylistMode.none] or [PlaylistMode.single].
      if ([
            PlaylistMode.none,
            PlaylistMode.single,
          ].contains(state.playlistMode) &&
          state.playlist.index == 0) {
        return;
      }

      await play(synchronized: false);
      await _command(['playlist-prev']);
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Jumps to specified [Media]'s index in the [Player]'s playlist.
  @override
  Future<void> jump(int index, {bool synchronized = true}) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      await play(synchronized: false);
      await _setPropertyInt64('playlist-pos', index);
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Moves the playlist [Media] at [from], so that it takes the place of the [Media] [to].
  @override
  Future<void> move(int from, int to, {bool synchronized = true}) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      // External List<Media>:
      // ---------------------------------------------
      final map = SplayTreeMap<double, Media>.from(
        current.asMap().map((key, value) => MapEntry(key * 1.0, value)),
      );
      final item = map.remove(from * 1.0);
      if (item != null) {
        map[to - 0.5] = item;
      }
      final values = map.values.toList();
      current = values;
      final playlist = state.playlist.copyWith(medias: current);
      state = state.copyWith(playlist: playlist);
      if (!playlistController.isClosed) {
        playlistController.add(playlist);
      }

      // ---------------------------------------------

      await _command(['playlist-move', from.toString(), to.toString()]);
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Seeks the currently playing [Media] in the [Player] by specified [Duration].
  @override
  Future<void> seek(Duration duration, {bool synchronized = true}) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }

      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      await _command([
        'seek',
        (duration.inMilliseconds / 1000).toStringAsFixed(4),
        'absolute',
      ]);

      // It is self explanatory that PlayerState.completed & PlayerStream.completed must enter the false state if seek is called. Typically after EOF.
      // https://github.com/media-kit/media-kit/issues/221
      state = state.copyWith(completed: false);
      if (!completedController.isClosed) {
        completedController.add(false);
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Sets playlist mode.
  @override
  Future<void> setPlaylistMode(
    PlaylistMode playlistMode, {
    bool synchronized = true,
  }) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      switch (playlistMode) {
        case PlaylistMode.none:
          {
            await _setPropertyString('loop-file', 'no');
            await _setPropertyString('loop-playlist', 'no');
            break;
          }
        case PlaylistMode.single:
          {
            await _setPropertyString('loop-file', 'yes');
            await _setPropertyString('loop-playlist', 'no');
            break;
          }
        case PlaylistMode.loop:
          {
            await _setPropertyString('loop-file', 'no');
            await _setPropertyString('loop-playlist', 'yes');
            break;
          }
      }

      state = state.copyWith(playlistMode: playlistMode);
      if (!playlistModeController.isClosed) {
        playlistModeController.add(playlistMode);
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Sets the playback volume of the [Player]. Defaults to `100.0`.
  @override
  Future<void> setVolume(double volume, {bool synchronized = true}) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      await _setPropertyDouble('volume', volume);
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Sets the playback rate of the [Player]. Defaults to `1.0`.
  @override
  Future<void> setRate(double rate, {bool synchronized = true}) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      if (rate <= 0.0) {
        throw ArgumentError.value(rate, 'rate', 'Must be greater than 0.0');
      }

      if (configuration.pitch) {
        // Pitch shift control is enabled.

        state = state.copyWith(rate: rate);
        if (!rateController.isClosed) {
          rateController.add(state.rate);
        }
        // Apparently, using scaletempo:scale actually controls the playback rate as intended after setting audio-pitch-correction as FALSE.
        // speed on the other hand, changes the pitch when audio-pitch-correction is set to FALSE.
        // Since, it also alters the actual [speed], the scaletempo:scale is divided by the same value of [pitch] to compensate the speed change.
        await _setPropertyFlag('audio-pitch-correction', false);
        // Divide by [state.pitch] to compensate the speed change caused by pitch shift.
        await _setPropertyString(
          'af',
          'scaletempo:scale=${(state.rate / state.pitch).toStringAsFixed(8)}',
        );
      } else {
        // Pitch shift control is disabled.

        state = state.copyWith(rate: rate);
        if (!rateController.isClosed) {
          rateController.add(state.rate);
        }
        await _setPropertyDouble('speed', rate);
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Sets the relative pitch of the [Player]. Defaults to `1.0`.
  @override
  Future<void> setPitch(double pitch, {bool synchronized = true}) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      if (configuration.pitch) {
        if (pitch <= 0.0) {
          throw ArgumentError.value(pitch, 'pitch', 'Must be greater than 0.0');
        }

        // Pitch shift control is enabled.

        state = state.copyWith(pitch: pitch);
        if (!pitchController.isClosed) {
          pitchController.add(state.pitch);
        }
        // Apparently, using scaletempo:scale actually controls the playback rate as intended after setting audio-pitch-correction as FALSE.
        // speed on the other hand, changes the pitch when audio-pitch-correction is set to FALSE.
        // Since, it also alters the actual [speed], the scaletempo:scale is divided by the same value of [pitch] to compensate the speed change.
        await _setPropertyFlag('audio-pitch-correction', false);
        await _setPropertyDouble('speed', pitch);
        // Divide by [state.pitch] to compensate the speed change caused by pitch shift.
        await _setPropertyString(
          'af',
          'scaletempo:scale=${(state.rate / state.pitch).toStringAsFixed(8)}',
        );
      } else {
        // Pitch shift control is disabled.
        throw ArgumentError('[PlayerConfiguration.pitch] is false');
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Enables or disables shuffle for [Player]. Default is `false`.
  @override
  Future<void> setShuffle(bool shuffle, {bool synchronized = true}) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      if (shuffle == isShuffleEnabled) {
        return;
      }
      isShuffleEnabled = shuffle;

      await _command([shuffle ? 'playlist-shuffle' : 'playlist-unshuffle']);
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Sets the current [AudioDevice] for audio output.
  ///
  /// * Currently selected [AudioDevice] can be accessed using [state.audioDevice] or [stream.audioDevice].
  /// * The list of currently available [AudioDevice]s can be obtained accessed using [state.audioDevices] or [stream.audioDevices].
  @override
  Future<void> setAudioDevice(
    AudioDevice audioDevice, {
    bool synchronized = true,
  }) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      await _setPropertyString('audio-device', audioDevice.name);
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Sets the current [VideoTrack] for video output.
  ///
  /// * Currently selected [VideoTrack] can be accessed using [state.track.video] or [stream.track.video].
  /// * The list of currently available [VideoTrack]s can be obtained accessed using [state.tracks.video] or [stream.tracks.video].
  @override
  Future<void> setVideoTrack(VideoTrack track, {bool synchronized = true}) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      await _setPropertyString('vid', track.id);
      state = state.copyWith(track: state.track.copyWith(video: track));
      if (!trackController.isClosed) {
        trackController.add(state.track);
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Sets the current [AudioTrack] for audio output.
  ///
  /// * Currently selected [AudioTrack] can be accessed using [state.track.audio] or [stream.track.audio].
  /// * The list of currently available [AudioTrack]s can be obtained accessed using [state.tracks.audio] or [stream.tracks.audio].
  /// * External audio track can be loaded using [AudioTrack.uri] constructor.
  ///
  /// ```dart
  /// player.setAudioTrack(
  ///   AudioTrack.uri(
  ///     'https://www.iandevlin.com/html5test/webvtt/v/upc-tobymanley.mp4',
  ///     title: 'English',
  ///     language: 'en',
  ///   ),
  /// );
  /// ```
  ///
  @override
  Future<void> setAudioTrack(AudioTrack track, {bool synchronized = true}) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      if (track.uri) {
        await _command([
          'audio-add',
          track.id,
          'select',
          track.title ?? 'external',
          track.language ?? 'auto',
        ]);
        state = state.copyWith(track: state.track.copyWith(audio: track));
        if (!trackController.isClosed) {
          trackController.add(state.track);
        }
      } else {
        await _setPropertyString('aid', track.id);
        state = state.copyWith(track: state.track.copyWith(audio: track));
        if (!trackController.isClosed) {
          trackController.add(state.track);
        }
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Sets the current [SubtitleTrack] for subtitle output.
  ///
  /// * Currently selected [SubtitleTrack] can be accessed using [state.track.subtitle] or [stream.track.subtitle].
  /// * The list of currently available [SubtitleTrack]s can be obtained accessed using [state.tracks.subtitle] or [stream.tracks.subtitle].
  /// * External subtitle track can be loaded using [SubtitleTrack.uri] or [SubtitleTrack.data] constructor.
  ///
  /// ```dart
  /// player.setSubtitleTrack(
  ///   SubtitleTrack.uri(
  ///     'https://www.iandevlin.com/html5test/webvtt/upc-video-subtitles-en.vtt',
  ///     title: 'English',
  ///     language: 'en',
  ///   ),
  /// );
  /// ```
  ///
  @override
  Future<void> setSubtitleTrack(
    SubtitleTrack track, {
    bool synchronized = true,
  }) {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      // Reset existing Player.state.subtitle & Player.stream.subtitle.
      state = state.copyWith(subtitle: const PlayerState().subtitle);
      if (!subtitleController.isClosed) {
        subtitleController.add(state.subtitle);
      }

      if (track.uri || track.data) {
        final String uri;
        if (track.uri) {
          uri = track.id;
        } else if (track.data) {
          // Save the subtitle data to a temporary [File].
          final temp = await TempFile.create();
          await temp.write_(track.id);
          // Delete the temporary [File] upon [dispose].
          release.add(temp.delete_);
          uri = temp.uri.toString();
        } else {
          return;
        }

        await _command([
          'sub-add',
          uri,
          'select',
          track.title ?? 'external',
          track.language ?? 'auto',
        ]);
        state = state.copyWith(track: state.track.copyWith(subtitle: track));
        if (!trackController.isClosed) {
          trackController.add(state.track);
        }
      } else {
        await _setPropertyString('sid', track.id);
        state = state.copyWith(track: state.track.copyWith(subtitle: track));
        if (!trackController.isClosed) {
          trackController.add(state.track);
        }
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Takes the snapshot of the current video frame & returns encoded image bytes as [Uint8List].
  ///
  /// The [format] parameter specifies the format of the image to be returned. Supported values are:
  /// * `image/jpeg`: Returns a JPEG encoded image.
  /// * `image/png`: Returns a PNG encoded image.
  /// * `null`: Returns BGRA pixel buffer.
  ///
  /// If [includeLibassSubtitles] is `true` *and* [PlayerConfiguration.libass] is `true`, then the
  /// screenshot will include the on-screen subtitles.
  @override
  Future<Uint8List?> screenshot({
    String? format = 'image/jpeg',
    bool synchronized = true,
    bool includeLibassSubtitles = false,
  }) async {
    Future<Uint8List?> function() async {
      if (!['image/jpeg', 'image/png', null].contains(format)) {
        throw ArgumentError.value(
          format,
          'format',
          'Supported values are: image/jpeg, image/png, null',
        );
      }
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }

      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      _checkNativeHandle();
      // Only owned pixels may cross into the encoding isolate.
      final data = await _captureScreenshot(format, includeLibassSubtitles);
      return data == null ? null : compute(_encodeScreenshot, data);
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<Uint8List?> safeScreenshot({
    String? format = 'image/jpeg',
    bool synchronized = true,
    bool includeLibassSubtitles = false,
  }) => screenshot(
    format: format,
    synchronized: synchronized,
    includeLibassSubtitles: includeLibassSubtitles,
  );

  /// Internal platform specific identifier for this [Player] instance.
  ///
  /// Since, [int] is a primitive type, it can be used to pass this [Player] instance to native code without directly depending upon this library.
  ///
  @override
  Future<int> get handle async {
    await waitForPlayerInitialization;
    return ctx.address;
  }

  /// Sets property for the internal libmpv instance of this [Player].
  /// Please use this method only if you know what you are doing, existing methods in [Player] implementation are suited for the most use cases.
  ///
  /// See:
  /// * https://mpv.io/manual/master/#options
  /// * https://mpv.io/manual/master/#properties
  ///
  Future<void> setProperty(
    String property,
    String value, {
    bool waitForInitialization = true,
  }) async {
    if (disposed) {
      throw AssertionError('[Player] has been disposed');
    }

    if (waitForInitialization) {
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;
    }
    _checkNativeHandle();

    final name = property.toNativeUtf8();
    final data = value.toNativeUtf8();
    mpv.mpv_set_property_string(ctx, name.cast(), data.cast());
    calloc.free(name);
    calloc.free(data);
  }

  /// Retrieves the value of a property from the internal libmpv instance of this [Player].
  /// Please use this method only if you know what you are doing, existing methods in [Player] implementation are suited for the most use cases.
  ///
  /// See:
  /// * https://mpv.io/manual/master/#options
  /// * https://mpv.io/manual/master/#properties
  ///
  Future<String> getProperty(
    String property, {
    bool waitForInitialization = true,
  }) async {
    if (disposed) {
      throw AssertionError('[Player] has been disposed');
    }

    if (waitForInitialization) {
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;
    }
    _checkNativeHandle();

    final name = property.toNativeUtf8();
    final value = mpv.mpv_get_property_string(ctx, name.cast());
    if (value != nullptr) {
      final result = value.cast<Utf8>().toDartString();
      calloc.free(name);
      mpv.mpv_free(value.cast());

      return result;
    }

    return "";
  }

  /// Observes property for the internal libmpv instance of this [Player].
  /// Please use this method only if you know what you are doing, existing methods in [Player] implementation are suited for the most use cases.
  ///
  /// See:
  /// * https://mpv.io/manual/master/#options
  /// * https://mpv.io/manual/master/#properties
  ///
  Future<void> observeProperty(
    String property,
    Future<void> Function(String) listener, {
    bool waitForInitialization = true,
  }) async {
    if (disposed) {
      throw AssertionError('[Player] has been disposed');
    }

    if (waitForInitialization) {
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;
    }
    _checkNativeHandle();

    if (observed.containsKey(property)) {
      throw ArgumentError.value(property, 'property', 'Already observed');
    }
    final reply = property.hashCode;
    observed[property] = listener;
    final name = property.toNativeUtf8();
    mpv.mpv_observe_property(
      ctx,
      reply,
      name.cast(),
      generated.mpv_format.MPV_FORMAT_NONE,
    );
    calloc.free(name);
  }

  /// Unobserves property for the internal libmpv instance of this [Player].
  /// Please use this method only if you know what you are doing, existing methods in [Player] implementation are suited for the most use cases.
  ///
  /// See:
  /// * https://mpv.io/manual/master/#options
  /// * https://mpv.io/manual/master/#properties
  ///
  Future<void> unobserveProperty(
    String property, {
    bool waitForInitialization = true,
  }) async {
    if (disposed) {
      throw AssertionError('[Player] has been disposed');
    }

    if (waitForInitialization) {
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;
    }
    _checkNativeHandle();

    if (!observed.containsKey(property)) {
      throw ArgumentError.value(property, 'property', 'Not observed');
    }
    final reply = property.hashCode;
    observed.remove(property);
    mpv.mpv_unobserve_property(ctx, reply);
  }

  /// Invokes command for the internal libmpv instance of this [Player].
  /// Please use this method only if you know what you are doing, existing methods in [Player] implementation are suited for the most use cases.
  ///
  /// See:
  /// * https://mpv.io/manual/master/#list-of-input-commands
  ///
  Future<void> command(
    List<String> command, {
    bool waitForInitialization = true,
  }) async {
    if (disposed) {
      throw AssertionError('[Player] has been disposed');
    }

    if (waitForInitialization) {
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;
    }
    _checkNativeHandle();

    await _command(command);
  }

  Future<void> _handler(Pointer<generated.mpv_event> event) async {
    if (event.ref.event_id ==
        generated.mpv_event_id.MPV_EVENT_PROPERTY_CHANGE) {
      final prop = event.ref.data.cast<generated.mpv_event_property>();
      if (prop.ref.name.cast<Utf8>().toDartString() == 'idle-active' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_FLAG) {
        await future;
        // The [Player] has entered the idle state; initialization is complete.
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
      // Following properties are unrelated to the playback lifecycle. Thus, these can be accessed before initialization is complete.
      // e.g. audio-device & audio-device-list seem to be emitted before idle-active.
      if (prop.ref.name.cast<Utf8>().toDartString() == 'audio-device' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_NODE) {
        final value = prop.ref.data.cast<generated.mpv_node>();
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final name = value.ref.u.string.cast<Utf8>().toDartString();
          final audioDevice = AudioDevice(name, '');
          state = state.copyWith(audioDevice: audioDevice);
          if (!audioDeviceController.isClosed) {
            audioDeviceController.add(audioDevice);
          }
        }
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'audio-device-list' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_NODE) {
        final value = prop.ref.data.cast<generated.mpv_node>();
        final audioDevices = <AudioDevice>[];
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_NODE_ARRAY) {
          final list = value.ref.u.list.ref;
          for (int i = 0; i < list.num; i++) {
            if (list.values[i].format ==
                generated.mpv_format.MPV_FORMAT_NODE_MAP) {
              String name = '', description = '';
              final device = list.values[i].u.list.ref;
              for (int j = 0; j < device.num; j++) {
                if (device.values[j].format ==
                    generated.mpv_format.MPV_FORMAT_STRING) {
                  final property = device.keys[j].cast<Utf8>().toDartString();
                  final value = device.values[j].u.string
                      .cast<Utf8>()
                      .toDartString();
                  switch (property) {
                    case 'name':
                      name = value;
                      break;
                    case 'description':
                      description = value;
                      break;
                  }
                }
              }
              audioDevices.add(AudioDevice(name, description));
            }
          }
          state = state.copyWith(audioDevices: audioDevices);
          if (!audioDevicesController.isClosed) {
            audioDevicesController.add(audioDevices);
          }
        }
      }
    }
    if (event.ref.event_id ==
        generated.mpv_event_id.MPV_EVENT_SET_PROPERTY_REPLY) {
      final completer = _setPropertyRequests.remove(event.ref.reply_userdata);
      if (completer == null) {
        print(
          'Warning: Received MPV_EVENT_SET_PROPERTY_REPLY with unregistered ID ${event.ref.reply_userdata}',
        );
      } else {
        completer.complete(event.ref.error);
      }
    }
    if (event.ref.event_id == generated.mpv_event_id.MPV_EVENT_COMMAND_REPLY) {
      final screenshot = _screenshotRequests.remove(event.ref.reply_userdata);
      if (screenshot != null) {
        try {
          final data = event.ref.data;
          screenshot.completer.complete(
            event.ref.error < 0 || data == nullptr
                ? null
                : _copyScreenshot(
                    data.cast<generated.mpv_event_command>().ref.result,
                    screenshot.format,
                  ),
          );
        } catch (error, stack) {
          screenshot.completer.completeError(error, stack);
        }
      } else {
        final completer = _commandRequests.remove(event.ref.reply_userdata);
        if (completer == null) {
          print(
            'Warning: Received MPV_EVENT_COMMAND_REPLY with unregistered ID ${event.ref.reply_userdata}',
          );
        } else {
          completer.complete(event.ref.error);
        }
      }
    }

    if (!completer.isCompleted) {
      // Ignore the events which are fired before the initialization.
      return;
    }

    _logError(
      event.ref.error,
      'event:${event.ref.event_id} ${event.ref.data.cast<Uint8>()}',
    );

    if (event.ref.event_id == generated.mpv_event_id.MPV_EVENT_START_FILE) {
      if (isPlayingStateChangeAllowed) {
        state = state.copyWith(playing: true, completed: false);
        if (!playingController.isClosed) {
          playingController.add(true);
        }
        if (!completedController.isClosed) {
          completedController.add(false);
        }
      }
      state = state.copyWith(buffering: true);
      if (!bufferingController.isClosed) {
        bufferingController.add(true);
      }
    }
    if (event.ref.event_id ==
        generated.mpv_event_id.MPV_EVENT_PROPERTY_CHANGE) {
      final prop = event.ref.data.cast<generated.mpv_event_property>();
      if (prop.ref.name.cast<Utf8>().toDartString() == 'pause' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_FLAG) {
        final playing = prop.ref.data.cast<Int8>().value == 0;
        if (isPlayingStateChangeAllowed) {
          state = state.copyWith(playing: playing);
          if (!playingController.isClosed) {
            playingController.add(playing);
          }
        }
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'core-idle' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_FLAG) {
        // Check for [isBufferingStateChangeAllowed] because `pause` causes `core-idle` to be fired.
        final buffering = prop.ref.data.cast<Int8>().value == 1;
        if (buffering) {
          if (isBufferingStateChangeAllowed) {
            state = state.copyWith(buffering: true);
            if (!bufferingController.isClosed) {
              bufferingController.add(true);
            }
          }
        } else {
          state = state.copyWith(buffering: false);
          if (!bufferingController.isClosed) {
            bufferingController.add(false);
          }
        }
        isBufferingStateChangeAllowed = true;
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'paused-for-cache' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_FLAG) {
        final buffering = prop.ref.data.cast<Int8>().value == 1;
        state = state.copyWith(buffering: buffering);
        if (!bufferingController.isClosed) {
          bufferingController.add(buffering);
        }
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'demuxer-cache-time' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_DOUBLE) {
        final buffer = Duration(
          microseconds: prop.ref.data.cast<Double>().value * 1e6 ~/ 1,
        );
        state = state.copyWith(buffer: buffer);
        if (!bufferController.isClosed) {
          bufferController.add(buffer);
        }
      }
      if (prop.ref.name.cast<Utf8>().toDartString() ==
              'cache-buffering-state' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_DOUBLE) {
        final bufferingPercentage = prop.ref.data.cast<Double>().value;

        state = state.copyWith(bufferingPercentage: bufferingPercentage);
        if (!bufferingPercentageController.isClosed) {
          bufferingPercentageController.add(bufferingPercentage);
        }
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'time-pos' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_DOUBLE) {
        final position = Duration(
          microseconds: prop.ref.data.cast<Double>().value * 1e6 ~/ 1,
        );
        state = state.copyWith(position: position);
        if (!positionController.isClosed) {
          positionController.add(position);
        }
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'duration' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_DOUBLE) {
        final duration = Duration(
          microseconds: prop.ref.data.cast<Double>().value * 1e6 ~/ 1,
        );
        state = state.copyWith(duration: duration);
        if (!durationController.isClosed) {
          durationController.add(duration);
        }
        if (state.playlist.index >= 0 &&
            state.playlist.index < state.playlist.medias.length) {
          final uri = state.playlist.medias[state.playlist.index].uri;
          if (FallbackBitrateHandler.supported(uri)) {
            if (!audioBitrateCache.containsKey(Media.normalizeURI(uri))) {
              audioBitrateCache[uri] =
                  await FallbackBitrateHandler.calculateBitrate(uri, duration);
            }
            final bitrate = audioBitrateCache[uri];
            if (bitrate != null) {
              state = state.copyWith(audioBitrate: bitrate);
              if (!audioBitrateController.isClosed) {
                audioBitrateController.add(bitrate);
              }
            }
          }
        }
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'playlist-playing-pos' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_INT64 &&
          prop.ref.data != nullptr) {
        final index = prop.ref.data.cast<Int64>().value;
        if (index >= 0) {
          final playlist = Playlist(current, index: index);
          state = state.copyWith(playlist: playlist);
          if (!playlistController.isClosed) {
            playlistController.add(playlist);
          }
        }
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'volume' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_DOUBLE) {
        final volume = prop.ref.data.cast<Double>().value;
        state = state.copyWith(volume: volume);
        if (!volumeController.isClosed) {
          volumeController.add(volume);
        }
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'audio-params' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_NODE) {
        final data = prop.ref.data.cast<generated.mpv_node>();
        final list = data.ref.u.list.ref;
        final params = <String, dynamic>{};
        for (int i = 0; i < list.num; i++) {
          final key = list.keys[i].cast<Utf8>().toDartString();

          switch (key) {
            case 'format':
              {
                params[key] = list.values[i].u.string
                    .cast<Utf8>()
                    .toDartString();
                break;
              }
            case 'samplerate':
              {
                params[key] = list.values[i].u.int64;
                break;
              }
            case 'channels':
              {
                params[key] = list.values[i].u.string
                    .cast<Utf8>()
                    .toDartString();
                break;
              }
            case 'channel-count':
              {
                params[key] = list.values[i].u.int64;
                break;
              }
            case 'hr-channels':
              {
                params[key] = list.values[i].u.string
                    .cast<Utf8>()
                    .toDartString();
                break;
              }
            default:
              {
                break;
              }
          }
        }
        state = state.copyWith(
          audioParams: AudioParams(
            format: params['format'],
            sampleRate: params['samplerate'],
            channels: params['channels'],
            channelCount: params['channel-count'],
            hrChannels: params['hr-channels'],
          ),
        );
        if (!audioParamsController.isClosed) {
          audioParamsController.add(state.audioParams);
        }
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'audio-bitrate' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_DOUBLE) {
        if (state.playlist.index < state.playlist.medias.length &&
            state.playlist.index >= 0) {
          final data = prop.ref.data.cast<Double>().value;
          final uri = state.playlist.medias[state.playlist.index].uri;
          if (!FallbackBitrateHandler.supported(uri)) {
            if (!audioBitrateCache.containsKey(Media.normalizeURI(uri))) {
              audioBitrateCache[Media.normalizeURI(uri)] = data;
            }
            final bitrate = audioBitrateCache[Media.normalizeURI(uri)];
            if (!audioBitrateController.isClosed &&
                bitrate != state.audioBitrate) {
              audioBitrateController.add(bitrate);
              state = state.copyWith(audioBitrate: bitrate);
            }
          }
        } else {
          if (!audioBitrateController.isClosed) {
            audioBitrateController.add(null);
            state = state.copyWith(audioBitrate: null);
          }
        }
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'video-bitrate' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_DOUBLE) {
        if (state.playlist.index < state.playlist.medias.length &&
            state.playlist.index >= 0) {
          final bitrate = prop.ref.data.cast<Double>().value;
          if (!videoBitrateController.isClosed &&
              bitrate != state.videoBitrate) {
            videoBitrateController.add(bitrate);
            state = state.copyWith(videoBitrate: bitrate);
          }
        } else {
          if (!videoBitrateController.isClosed) {
            videoBitrateController.add(null);
            state = state.copyWith(videoBitrate: null);
          }
        }
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'track-list' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_NODE) {
        final value = prop.ref.data.cast<generated.mpv_node>();
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_NODE_ARRAY) {
          final video = [VideoTrack.auto(), VideoTrack.no()];
          final audio = [AudioTrack.auto(), AudioTrack.no()];
          final subtitle = [SubtitleTrack.auto(), SubtitleTrack.no()];

          final tracks = value.ref.u.list.ref;

          for (int i = 0; i < tracks.num; i++) {
            if (tracks.values[i].format ==
                generated.mpv_format.MPV_FORMAT_NODE_MAP) {
              final map = tracks.values[i].u.list.ref;
              String id = '';
              String type = '';
              String? title;
              String? language;
              bool? image;
              bool? albumart;
              String? codec;
              String? decoder;
              int? w;
              int? h;
              int? channelscount;
              String? channels;
              int? samplerate;
              double? fps;
              int? bitrate;
              int? rotate;
              double? par;
              int? audiochannels;
              for (int j = 0; j < map.num; j++) {
                final property = map.keys[j].cast<Utf8>().toDartString();
                if (map.values[j].format ==
                    generated.mpv_format.MPV_FORMAT_INT64) {
                  switch (property) {
                    case 'id':
                      id = map.values[j].u.int64.toString();
                      break;
                    case 'demux-w':
                      w = map.values[j].u.int64;
                      break;
                    case 'demux-h':
                      h = map.values[j].u.int64;
                      break;
                    case 'demux-channel-count':
                      channelscount = map.values[j].u.int64;
                      break;
                    case 'demux-samplerate':
                      samplerate = map.values[j].u.int64;
                      break;
                    case 'demux-bitrate':
                      bitrate = map.values[j].u.int64;
                      break;
                    case 'demux-rotate':
                      rotate = map.values[j].u.int64;
                      break;
                    case 'audio-channels':
                      audiochannels = map.values[j].u.int64;
                      break;
                  }
                }
                if (map.values[j].format ==
                    generated.mpv_format.MPV_FORMAT_FLAG) {
                  switch (property) {
                    case 'image':
                      image = map.values[j].u.flag > 0;
                      break;
                    case 'albumart':
                      albumart = map.values[j].u.flag > 0;
                      break;
                  }
                }
                if (map.values[j].format ==
                    generated.mpv_format.MPV_FORMAT_DOUBLE) {
                  switch (property) {
                    case 'demux-fps':
                      fps = map.values[j].u.double_;
                      break;
                    case 'demux-par':
                      par = map.values[j].u.double_;
                      break;
                  }
                }
                if (map.values[j].format ==
                    generated.mpv_format.MPV_FORMAT_STRING) {
                  final value = map.values[j].u.string
                      .cast<Utf8>()
                      .toDartString();
                  switch (property) {
                    case 'type':
                      type = value;
                      break;
                    case 'title':
                      title = value;
                      break;
                    case 'lang':
                      language = value;
                      break;
                    case 'codec':
                      codec = value;
                      break;
                    case 'decoder-desc':
                      decoder = value;
                      break;
                    case 'demux-channels':
                      channels = value;
                      break;
                  }
                }
              }
              switch (type) {
                case 'video':
                  video.add(
                    VideoTrack(
                      id,
                      title,
                      language,
                      image: image,
                      albumart: albumart,
                      codec: codec,
                      decoder: decoder,
                      w: w,
                      h: h,
                      channelscount: channelscount,
                      channels: channels,
                      samplerate: samplerate,
                      fps: fps,
                      bitrate: bitrate,
                      rotate: rotate,
                      par: par,
                      audiochannels: audiochannels,
                    ),
                  );
                  break;
                case 'audio':
                  audio.add(
                    AudioTrack(
                      id,
                      title,
                      language,
                      image: image,
                      albumart: albumart,
                      codec: codec,
                      decoder: decoder,
                      w: w,
                      h: h,
                      channelscount: channelscount,
                      channels: channels,
                      samplerate: samplerate,
                      fps: fps,
                      bitrate: bitrate,
                      rotate: rotate,
                      par: par,
                      audiochannels: audiochannels,
                    ),
                  );
                  break;
                case 'sub':
                  subtitle.add(
                    SubtitleTrack(
                      id,
                      title,
                      language,
                      image: image,
                      albumart: albumart,
                      codec: codec,
                      decoder: decoder,
                      w: w,
                      h: h,
                      channelscount: channelscount,
                      channels: channels,
                      samplerate: samplerate,
                      fps: fps,
                      bitrate: bitrate,
                      rotate: rotate,
                      par: par,
                      audiochannels: audiochannels,
                    ),
                  );
                  break;
              }
            }
          }

          state = state.copyWith(
            tracks: Tracks(video: video, audio: audio, subtitle: subtitle),
          );
          if (!tracksController.isClosed) {
            tracksController.add(state.tracks);
          }
        }
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'sub-text' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_NODE) {
        final value = prop.ref.data.cast<generated.mpv_node>();
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          state = state.copyWith(subtitle: [text, state.subtitle[1]]);
          if (!subtitleController.isClosed) {
            subtitleController.add(state.subtitle);
          }
        }
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'secondary-sub-text' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_NODE) {
        final value = prop.ref.data.cast<generated.mpv_node>();
        if (value.ref.format == generated.mpv_format.MPV_FORMAT_STRING) {
          final text = value.ref.u.string.cast<Utf8>().toDartString();
          state = state.copyWith(subtitle: [state.subtitle[0], text]);
          if (!subtitleController.isClosed) {
            subtitleController.add(state.subtitle);
          }
        }
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'eof-reached' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_FLAG) {
        final value = prop.ref.data.cast<Bool>().value;
        if (value) {
          if (isPlayingStateChangeAllowed) {
            state = state.copyWith(playing: false, completed: true);
            if (!playingController.isClosed) {
              playingController.add(false);
            }
            if (!completedController.isClosed) {
              completedController.add(true);
            }
          }

          state = state.copyWith(
            buffering: false,
            tracks: Tracks(),
            track: Track(),
          );
          if (!bufferingController.isClosed) {
            bufferingController.add(false);
          }
          if (!tracksController.isClosed) {
            tracksController.add(Tracks());
          }
          if (!trackController.isClosed) {
            trackController.add(Track());
          }
        }
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'video-params' &&
          prop.ref.format == generated.mpv_format.MPV_FORMAT_NODE) {
        final node = prop.ref.data.cast<generated.mpv_node>().ref;
        final data = <String, dynamic>{};
        for (int i = 0; i < node.u.list.ref.num; i++) {
          final key = node.u.list.ref.keys[i].cast<Utf8>().toDartString();
          final value = node.u.list.ref.values[i];
          switch (value.format) {
            case generated.mpv_format.MPV_FORMAT_INT64:
              data[key] = value.u.int64;
              break;
            case generated.mpv_format.MPV_FORMAT_DOUBLE:
              data[key] = value.u.double_;
              break;
            case generated.mpv_format.MPV_FORMAT_STRING:
              data[key] = value.u.string.cast<Utf8>().toDartString();
              break;
          }
        }

        final params = VideoParams(
          pixelformat: data['pixelformat'],
          hwPixelformat: data['hw-pixelformat'],
          w: data['w'],
          h: data['h'],
          dw: data['dw'],
          dh: data['dh'],
          aspect: data['aspect'],
          par: data['par'],
          colormatrix: data['colormatrix'],
          colorlevels: data['colorlevels'],
          primaries: data['primaries'],
          gamma: data['gamma'],
          sigPeak: data['sig-peak'],
          light: data['light'],
          chromaLocation: data['chroma-location'],
          rotate: data['rotate'],
          stereoIn: data['stereo-in'],
          averageBpp: data['average-bpp'],
          alpha: data['alpha'],
        );

        state = state.copyWith(videoParams: params);
        if (!videoParamsController.isClosed) {
          videoParamsController.add(params);
        }

        final dw = params.dw;
        final dh = params.dh;
        final rotate = params.rotate ?? 0;
        if (dw is int && dh is int) {
          final int width;
          final int height;
          if (rotate == 0 || rotate == 180) {
            width = dw;
            height = dh;
          } else {
            // width & height are swapped for 90 or 270 degrees rotation.
            width = dh;
            height = dw;
          }
          state = state.copyWith(width: width, height: height);
          if (!widthController.isClosed) {
            widthController.add(width);
          }
          if (!heightController.isClosed) {
            heightController.add(height);
          }
        }
      }
      if (observed.containsKey(prop.ref.name.cast<Utf8>().toDartString())) {
        if (prop.ref.format == generated.mpv_format.MPV_FORMAT_NONE) {
          final fn = observed[prop.ref.name.cast<Utf8>().toDartString()];
          if (fn != null) {
            final data = mpv.mpv_get_property_string(ctx, prop.ref.name);
            if (data != nullptr) {
              try {
                await fn.call(data.cast<Utf8>().toDartString());
              } catch (exception, stacktrace) {
                print(exception);
                print(stacktrace);
              }
              mpv.mpv_free(data.cast());
            }
          }
        }
      }
    }
    if (event.ref.event_id == generated.mpv_event_id.MPV_EVENT_LOG_MESSAGE) {
      final eventLogMessage = event.ref.data
          .cast<generated.mpv_event_log_message>()
          .ref;
      final prefix = eventLogMessage.prefix.cast<Utf8>().toDartString().trim();
      final level = eventLogMessage.level.cast<Utf8>().toDartString().trim();
      final text = eventLogMessage.text.cast<Utf8>().toDartString().trim();
      if (!logController.isClosed) {
        logController.add(PlayerLog(prefix: prefix, level: level, text: text));
        // --------------------------------------------------
        // Emit error(s) based on the log messages.
        if (level == 'error') {
          if (prefix == 'file') {
            // file:// not found.
            if (!errorController.isClosed) {
              errorController.add(text);
            }
          }
          if (prefix == 'ffmpeg') {
            if (text.startsWith('tcp:')) {
              // http:// error of any kind.
              if (!errorController.isClosed) {
                errorController.add(text);
              }
            }
          }
          if (prefix == 'vd') {
            if (!errorController.isClosed) {
              errorController.add(text);
            }
          }
          if (prefix == 'ad') {
            if (!errorController.isClosed) {
              errorController.add(text);
            }
          }
          if (prefix == 'cplayer') {
            if (!errorController.isClosed) {
              errorController.add(text);
            }
          }
          if (prefix == 'stream') {
            if (!errorController.isClosed) {
              errorController.add(text);
            }
          }
        }
        // --------------------------------------------------
      }
    }
    if (event.ref.event_id == generated.mpv_event_id.MPV_EVENT_HOOK) {
      final prop = event.ref.data.cast<generated.mpv_event_hook>();
      if (prop.ref.name.cast<Utf8>().toDartString() == 'on_load') {
        // --------------------------------------------------
        for (final hook in onLoadHooks) {
          try {
            await hook.call();
          } catch (exception, stacktrace) {
            print(exception);
            print(stacktrace);
          }
        }
        // --------------------------------------------------
        // Handle HTTP headers specified in the [Media].
        try {
          final name = 'path'.toNativeUtf8();
          final uri = mpv.mpv_get_property_string(ctx, name.cast());
          // Get the headers for current [Media] by looking up [uri] in the [HashMap].
          final headers = Media(uri.cast<Utf8>().toDartString()).httpHeaders;
          if (headers != null) {
            final property = 'http-header-fields'.toNativeUtf8();
            // Allocate & fill the [mpv_node] with the headers.
            final value = calloc<generated.mpv_node>();
            value.ref.format = generated.mpv_format.MPV_FORMAT_NODE_ARRAY;
            value.ref.u.list = calloc<generated.mpv_node_list>();
            value.ref.u.list.ref.num = headers.length;
            value.ref.u.list.ref.values = calloc<generated.mpv_node>(
              headers.length,
            );
            final entries = headers.entries.toList();
            for (int i = 0; i < entries.length; i++) {
              final k = entries[i].key;
              final v = entries[i].value;
              final data = '$k: $v'.toNativeUtf8();
              value.ref.u.list.ref.values[i].format =
                  generated.mpv_format.MPV_FORMAT_STRING;
              value.ref.u.list.ref.values[i].u.string = data.cast();
            }
            mpv.mpv_set_property(
              ctx,
              property.cast(),
              generated.mpv_format.MPV_FORMAT_NODE,
              value.cast(),
            );
            // Free the allocated memory.
            calloc.free(property);
            for (int i = 0; i < value.ref.u.list.ref.num; i++) {
              calloc.free(value.ref.u.list.ref.values[i].u.string);
            }
            calloc.free(value.ref.u.list.ref.values);
            calloc.free(value.ref.u.list);
            calloc.free(value);
          }
          mpv.mpv_free(uri.cast());
          calloc.free(name);
        } catch (exception, stacktrace) {
          print(exception);
          print(stacktrace);
        }
        // Handle start & end position specified in the [Media].
        try {
          final name = 'playlist-pos'.toNativeUtf8();
          final value = calloc<Int64>();
          value.value = -1;

          mpv.mpv_get_property(
            ctx,
            name.cast(),
            generated.mpv_format.MPV_FORMAT_INT64,
            value.cast(),
          );

          final index = value.value;

          calloc.free(name.cast());
          calloc.free(value.cast());

          if (index >= 0) {
            final start = current[index].start;
            final end = current[index].end;

            if (start != null) {
              try {
                final property = 'start'.toNativeUtf8();
                final value = (start.inMilliseconds / 1000)
                    .toStringAsFixed(3)
                    .toNativeUtf8();
                mpv.mpv_set_property_string(ctx, property.cast(), value.cast());
                calloc.free(property);
                calloc.free(value);
              } catch (exception, stacktrace) {
                print(exception);
                print(stacktrace);
              }
            }

            if (end != null) {
              try {
                final property = 'end'.toNativeUtf8();
                final value = (end.inMilliseconds / 1000)
                    .toStringAsFixed(3)
                    .toNativeUtf8();
                mpv.mpv_set_property_string(ctx, property.cast(), value.cast());
                calloc.free(property);
                calloc.free(value);
              } catch (exception, stacktrace) {
                print(exception);
                print(stacktrace);
              }
            }
          }
        } catch (_) {}
        // --------------------------------------------------
        mpv.mpv_hook_continue(ctx, prop.ref.id);
      }
      if (prop.ref.name.cast<Utf8>().toDartString() == 'on_unload') {
        // --------------------------------------------------
        for (final hook in onUnloadHooks) {
          try {
            await hook.call();
          } catch (exception, stacktrace) {
            print(exception);
            print(stacktrace);
          }
        }
        // --------------------------------------------------
        // Set http-header-fields as [generated.mpv_format.MPV_FORMAT_NONE] [generated.mpv_node].
        try {
          final property = 'http-header-fields'.toNativeUtf8();
          final value = calloc<generated.mpv_node>();
          value.ref.format = generated.mpv_format.MPV_FORMAT_NONE;
          mpv.mpv_set_property(
            ctx,
            property.cast(),
            generated.mpv_format.MPV_FORMAT_NODE,
            value.cast(),
          );
          calloc.free(property);
          calloc.free(value);
        } catch (exception, stacktrace) {
          print(exception);
          print(stacktrace);
        }
        // Set start & end position as [generated.mpv_format.MPV_FORMAT_NONE] [generated.mpv_node].
        try {
          final property = 'start'.toNativeUtf8();
          final value = 'none'.toNativeUtf8();
          mpv.mpv_set_property_string(ctx, property.cast(), value.cast());
          calloc.free(property);
          calloc.free(value);
        } catch (exception, stacktrace) {
          print(exception);
          print(stacktrace);
        }
        try {
          final property = 'end'.toNativeUtf8();
          final value = 'none'.toNativeUtf8();
          mpv.mpv_set_property_string(ctx, property.cast(), value.cast());
          calloc.free(property);
          calloc.free(value);
        } catch (exception, stacktrace) {
          print(exception);
          print(stacktrace);
        }
        // --------------------------------------------------
        mpv.mpv_hook_continue(ctx, prop.ref.id);
      }
    }
  }

  Future<void> _create() {
    return lock.synchronized(() async {
      // The options which must be set before [MPV.mpv_initialize].
      final options = <String, String>{
        // Set --vid=no by default to prevent redundant video decoding.
        // [VideoController] internally sets --vid=auto upon attachment to enable video rendering & decoding.
        if (!test) 'vid': 'no',
        // Disable OSC before Lua scripts load; builds without Lua ignore it.
        if (!configuration.osc) 'osc': 'no',
      };

      if (Platform.isAndroid &&
          configuration.libass &&
          configuration.libassAndroidFont != null &&
          configuration.libassAndroidFontName != null) {
        try {
          // On Android, the system fonts cannot be picked up by libass/fontconfig. This makes libass subtitle rendering fail.
          // We save the subtitle font to the application's cache directory and set `config` & `config-dir` to use it.
          final subfont = await AndroidAssetLoader.load(
            join('flutter_assets', configuration.libassAndroidFont),
          );
          if (subfont.isNotEmpty) {
            final directory = dirname(subfont);
            options.addAll({
              'config': 'yes',
              'sub-fonts-dir': directory,
              'sub-font': configuration.libassAndroidFontName ?? '',
            });
            print(subfont);
            print(directory);
          }
        } catch (exception, stacktrace) {
          print(exception);
          print(stacktrace);
        }
      }

      final eventLoop = await NativeEventLoop.create(
        DynamicLibrary.open(nativeLibraryPath),
        _handler,
        options: options,
      );
      _eventLoop = eventLoop;
      ctx = eventLoop.handle;

      try {
        final properties = <String, String>{
          'idle': 'yes',
          'pause': 'yes',
          'keep-open': 'yes',
          'audio-display': 'no',
          'network-timeout': '5',
          // https://github.com/mpv-player/mpv/commit/703f1588803eaa428e09c0e5547b26c0fff476a7
          // https://github.com/mpv-android/mpv-android/commit/9e5c3d8a630290fc41edb8b03aeafa3bc4c45955
          'scale': 'bilinear',
          'dscale': 'bilinear',
          'dither': 'no',
          'cache': 'yes',
          'cache-on-disk': 'yes',
          'hr-seek': 'yes',
          'hr-seek-framedrop': 'no',
          'correct-downscaling': 'no',
          'linear-downscaling': 'no',
          'sigmoid-upscaling': 'no',
          'hdr-compute-peak': 'no',
          // OpenSL ES fails on older Android emulators.
          if (Platform.isAndroid)
            'ao': AndroidHelper.isEmulator && AndroidHelper.apiLevel <= 25
                ? 'null'
                : 'opensles',
          'subs-fallback': 'yes',
          'subs-with-matching-audio': 'yes',
        };
        // Other properties based on [PlayerConfiguration].
        properties.addAll({
          if (!configuration.osc) ...{'osd-level': '0'},
          'title': configuration.title,
          'demuxer-max-bytes': configuration.bufferSize.toString(),
          'demuxer-max-back-bytes': configuration.bufferSize.toString(),
          if (configuration.vo != null) 'vo': '${configuration.vo}',
          'demuxer-lavf-o': [
            'seg_max_retry=5',
            'strict=experimental',
            'allowed_extensions=ALL',
            'protocol_whitelist=[${configuration.protocolWhitelist.join(',')}]',
          ].join(','),
          'sub-ass': configuration.libass ? 'yes' : 'no',
          'sub-visibility': configuration.libass ? 'yes' : 'no',
          'secondary-sub-visibility': configuration.libass ? 'yes' : 'no',
        });

        if (test) {
          properties['vo'] = 'null';
          properties['ao'] = 'null';
        }

        await Future.wait(
          properties.entries.map(
            (entry) => _setPropertyString(entry.key, entry.value),
          ),
        );

        if (configuration.muted) {
          await _setPropertyDouble('volume', 0);

          state = state.copyWith(volume: 0.0);
          if (!volumeController.isClosed) {
            volumeController.add(0.0);
          }
        }

        // Observe the properties to update the state & feed event stream.
        <String, int>{
          'pause': generated.mpv_format.MPV_FORMAT_FLAG,
          'time-pos': generated.mpv_format.MPV_FORMAT_DOUBLE,
          'duration': generated.mpv_format.MPV_FORMAT_DOUBLE,
          'playlist-playing-pos': generated.mpv_format.MPV_FORMAT_INT64,
          'volume': generated.mpv_format.MPV_FORMAT_DOUBLE,
          'speed': generated.mpv_format.MPV_FORMAT_DOUBLE,
          'core-idle': generated.mpv_format.MPV_FORMAT_FLAG,
          'paused-for-cache': generated.mpv_format.MPV_FORMAT_FLAG,
          'demuxer-cache-time': generated.mpv_format.MPV_FORMAT_DOUBLE,
          'cache-buffering-state': generated.mpv_format.MPV_FORMAT_DOUBLE,
          'audio-params': generated.mpv_format.MPV_FORMAT_NODE,
          'audio-bitrate': generated.mpv_format.MPV_FORMAT_DOUBLE,
          'video-bitrate': generated.mpv_format.MPV_FORMAT_DOUBLE,
          'audio-device': generated.mpv_format.MPV_FORMAT_NODE,
          'audio-device-list': generated.mpv_format.MPV_FORMAT_NODE,
          'video-params': generated.mpv_format.MPV_FORMAT_NODE,
          'track-list': generated.mpv_format.MPV_FORMAT_NODE,
          'eof-reached': generated.mpv_format.MPV_FORMAT_FLAG,
          'idle-active': generated.mpv_format.MPV_FORMAT_FLAG,
          'sub-text': generated.mpv_format.MPV_FORMAT_NODE,
          'secondary-sub-text': generated.mpv_format.MPV_FORMAT_NODE,
        }.forEach((property, format) {
          final reply = property.hashCode;
          final name = property.toNativeUtf8();
          mpv.mpv_observe_property(ctx, reply, name.cast(), format);
          calloc.free(name);
        });

        // https://github.com/mpv-player/mpv/blob/e1727553f164181265f71a20106fbd5e34fa08b0/libmpv/client.h#L1410-L1419
        final levels = {
          MPVLogLevel.error: 'error',
          MPVLogLevel.warn: 'warn',
          MPVLogLevel.info: 'info',
          MPVLogLevel.v: 'v',
          MPVLogLevel.debug: 'debug',
          MPVLogLevel.trace: 'trace',
        };
        final level = levels[configuration.logLevel];
        if (level != null) {
          final min = level.toNativeUtf8();
          mpv.mpv_request_log_messages(ctx, min.cast());
          calloc.free(min);
        }

        // Add libmpv hooks for supporting custom HTTP headers in [Media].
        final load = 'on_load'.toNativeUtf8();
        final unload = 'on_unload'.toNativeUtf8();
        mpv.mpv_hook_add(ctx, 0, load.cast(), 0);
        mpv.mpv_hook_add(ctx, 0, unload.cast(), 0);
        calloc.free(load);
        calloc.free(unload);
      } catch (_) {
        await eventLoop.dispose();
        ctx = nullptr;
        _eventLoop = null;
        rethrow;
      }
    });
  }

  /// Adds an error to the [Player.stream.error].
  void _logError(int code, String? text) {
    if (code < 0 && !logController.isClosed) {
      final message = mpv.mpv_error_string(code).cast<Utf8>().toDartString();
      logController.add(
        PlayerLog(
          prefix: 'media_kit',
          level: 'error',
          text: 'error: $message $text',
        ),
      );
    }
  }

  int _asyncRequestNumber = 0;
  final Map<int, Completer<int>> _setPropertyRequests = {};
  final Map<int, Completer<int>> _commandRequests = {};
  final Map<int, _ScreenshotRequest> _screenshotRequests = {};

  Future<_ScreenshotData?> _captureScreenshot(
    String? format,
    bool includeLibassSubtitles,
  ) async {
    _checkNativeHandle();
    final requestNumber = _asyncRequestNumber++;
    final request = _screenshotRequests[requestNumber] = _ScreenshotRequest(
      format,
    );
    final args = [
      'screenshot-raw',
      includeLibassSubtitles ? 'subtitles' : 'video',
    ];
    final pointers = args.map((arg) => arg.toNativeUtf8()).toList();
    final arr = calloc<Pointer<Utf8>>(pointers.length + 1);
    try {
      int immediate;
      try {
        for (var i = 0; i < pointers.length; i++) {
          arr[i] = pointers[i];
        }
        // Enqueue on the mpv core without blocking the Dart event consumer.
        immediate = mpv.mpv_command_async(ctx, requestNumber, arr.cast());
      } finally {
        calloc.free(arr);
        pointers.forEach(calloc.free);
      }
      if (immediate < 0) {
        _logError(immediate, 'screenshot-raw');
        return null;
      }
      return await request.completer.future;
    } finally {
      _screenshotRequests.remove(requestNumber);
    }
  }

  void _checkNativeHandle() {
    if (disposed || ctx == nullptr) {
      throw StateError('Player has been disposed or failed to initialize');
    }
  }

  Future<void> _setProperty(String name, int format, Pointer<Void> data) async {
    _checkNativeHandle();
    final namePtr = name.toNativeUtf8();
    try {
      if (configuration.async) {
        final requestNumber = _asyncRequestNumber++;
        final completer = _setPropertyRequests[requestNumber] =
            Completer<int>();
        try {
          final immediate = mpv.mpv_set_property_async(
            ctx,
            requestNumber,
            namePtr.cast(),
            format,
            data,
          );
          final result = immediate < 0 ? immediate : await completer.future;
          _logError(result, '_setProperty($name, $format)');
        } finally {
          _setPropertyRequests.remove(requestNumber);
        }
      } else {
        _logError(
          mpv.mpv_set_property(ctx, namePtr.cast(), format, data),
          '_setProperty($name, $format)',
        );
      }
    } finally {
      calloc.free(namePtr);
    }
  }

  Future<void> _setPropertyFlag(String name, bool value) async {
    // MPV_FORMAT_FLAG is an int, not a one-byte C bool.
    final ptr = calloc<Int32>()..value = value ? 1 : 0;
    try {
      await _setProperty(
        name,
        generated.mpv_format.MPV_FORMAT_FLAG,
        ptr.cast(),
      );
    } finally {
      calloc.free(ptr);
    }
  }

  Future<void> _setPropertyDouble(String name, double value) async {
    final ptr = calloc<Double>()..value = value;
    try {
      await _setProperty(
        name,
        generated.mpv_format.MPV_FORMAT_DOUBLE,
        ptr.cast(),
      );
    } finally {
      calloc.free(ptr);
    }
  }

  Future<void> _setPropertyInt64(String name, int value) async {
    final ptr = calloc<Int64>()..value = value;
    try {
      await _setProperty(
        name,
        generated.mpv_format.MPV_FORMAT_INT64,
        ptr.cast(),
      );
    } finally {
      calloc.free(ptr);
    }
  }

  Future<void> _setPropertyString(String name, String value) async {
    final string = value.toNativeUtf8();
    // API requires char**.
    final ptr = calloc<Pointer<Void>>()..value = string.cast();
    try {
      await _setProperty(
        name,
        generated.mpv_format.MPV_FORMAT_STRING,
        ptr.cast(),
      );
    } finally {
      calloc.free(ptr);
      calloc.free(string);
    }
  }

  Future<void> _command(List<String> args) async {
    _checkNativeHandle();
    final pointers = args.map((e) => e.toNativeUtf8()).toList();
    final arr = calloc<Pointer<Utf8>>(args.length + 1);
    try {
      for (int i = 0; i < args.length; i++) {
        arr[i] = pointers[i];
      }
      if (configuration.async) {
        final requestNumber = _asyncRequestNumber++;
        final completer = _commandRequests[requestNumber] = Completer<int>();
        try {
          final immediate = mpv.mpv_command_async(
            ctx,
            requestNumber,
            arr.cast(),
          );
          final result = immediate < 0 ? immediate : await completer.future;
          _logError(result, '_command(${args.join(', ')})');
        } finally {
          _commandRequests.remove(requestNumber);
        }
      } else {
        _logError(
          mpv.mpv_command(ctx, arr.cast()),
          '_command(${args.join(', ')})',
        );
      }
    } finally {
      calloc.free(arr);
      pointers.forEach(calloc.free);
    }
  }

  /// Generated libmpv C API bindings.
  final generated.MPV mpv;

  /// Video renderers must bind to this handle's owning module.
  final String nativeLibraryPath;

  /// [Pointer] to [generated.mpv_handle] of this instance.
  Pointer<generated.mpv_handle> ctx = nullptr;

  NativeEventLoop? _eventLoop;
  Future<void>? _disposeFuture;

  /// The [Future] to wait for [_create] completion.
  /// This is used to prevent signaling [completer] (from [PlatformPlayer]) before [_create] completes in any hypothetical situation (because `idle-active` may fire before it).
  Future<void>? future;

  /// Whether the [Player] has been disposed. This is used to prevent accessing dangling [ctx] after [dispose].
  bool disposed = false;

  /// A flag to keep track of [setShuffle] calls.
  bool isShuffleEnabled = false;

  /// A flag to prevent changes to [state.playing] due to `loadfile` commands in [open].
  ///
  /// By default, `MPV_EVENT_START_FILE` is fired when a new media source is loaded.
  /// This event modifies the [state.playing] & [stream.playing] to `true`.
  ///
  /// However, the [Player] is in paused state before the media source is loaded.
  /// Thus, [state.playing] should not be changed, unless the user explicitly calls [play] or [playOrPause].
  ///
  /// We set [isPlayingStateChangeAllowed] to `false` at the start of [open] to prevent this unwanted change & set it to `true` at the end of [open].
  /// While [isPlayingStateChangeAllowed] is `false`, any change to [state.playing] & [stream.playing] is ignored.
  bool isPlayingStateChangeAllowed = false;

  /// A flag to prevent changes to [state.buffering] due to `pause` causing `core-idle` to be `true`.
  ///
  /// This is used to prevent [state.buffering] being set to `true` when [pause] or [playOrPause] is called.
  bool isBufferingStateChangeAllowed = true;

  /// Current loaded [Media] queue.
  List<Media> current = <Media>[];

  /// Currently observed properties through [observeProperty].
  final HashMap<String, Future<void> Function(String)> observed =
      HashMap<String, Future<void> Function(String)>();

  /// The methods which must execute synchronously before playback of a source can begin.
  final List<Future<void> Function()> onLoadHooks = [];

  /// The methods which must execute synchronously before playback of a source can end.
  final List<Future<void> Function()> onUnloadHooks = [];

  /// Synchronization & mutual exclusion between methods of this class.
  static final Lock lock = Lock();

  /// [HashMap] for retrieving previously fetched audio-bitrate(s).
  static final HashMap<String, double> audioBitrateCache =
      HashMap<String, double>();

  /// Whether the [NativePlayer] is initialized for unit-testing.
  @visibleForTesting
  static bool test = false;
}

final class _ScreenshotData {
  final int width;
  final int height;
  final int stride;
  final Uint8List bytes;
  final String? format;

  const _ScreenshotData(
    this.width,
    this.height,
    this.stride,
    this.bytes,
    this.format,
  );
}

final class _ScreenshotRequest {
  final String? format;
  final completer = Completer<_ScreenshotData?>();
  _ScreenshotRequest(this.format);
}

// This node belongs to the current mpv event. Copy before wait_event reuses it.
_ScreenshotData? _copyScreenshot(generated.mpv_node result, String? format) {
  if (result.format == generated.mpv_format.MPV_FORMAT_NODE_MAP) {
    int? w, h, stride;
    Uint8List? bytes;

    final map = result.u.list;
    for (int i = 0; i < map.ref.num; i++) {
      final key = map.ref.keys[i].cast<Utf8>().toDartString();
      final value = map.ref.values[i];
      switch (value.format) {
        case generated.mpv_format.MPV_FORMAT_INT64:
          switch (key) {
            case 'w':
              w = value.u.int64;
              break;
            case 'h':
              h = value.u.int64;
              break;
            case 'stride':
              stride = value.u.int64;
              break;
          }
          break;
        case generated.mpv_format.MPV_FORMAT_BYTE_ARRAY:
          switch (key) {
            case 'data':
              final data = value.u.ba.ref.data.cast<Uint8>();
              bytes = data.asTypedList(value.u.ba.ref.size);
              break;
          }
          break;
      }
    }

    if (w != null && h != null && stride != null && bytes != null) {
      return _ScreenshotData(w, h, stride, Uint8List.fromList(bytes), format);
    }
  }
  return null;
}

Uint8List? _encodeScreenshot(_ScreenshotData data) {
  if (data.format == null) return data.bytes;
  final pixels = Image(width: data.width, height: data.height, numChannels: 3);
  for (final pixel in pixels) {
    final offset = pixel.y * data.stride + pixel.x * 4;
    pixel.b = data.bytes[offset];
    pixel.g = data.bytes[offset + 1];
    pixel.r = data.bytes[offset + 2];
  }
  return switch (data.format) {
    'image/jpeg' => encodeJpg(pixels),
    'image/png' => encodePng(pixels),
    _ => throw ArgumentError.value(data.format, 'format'),
  };
}
