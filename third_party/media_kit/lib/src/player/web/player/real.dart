/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:typed_data';
import 'dart:collection';
import 'dart:html' as html;
import 'package:meta/meta.dart';
import 'package:collection/collection.dart';
import 'package:synchronized/synchronized.dart';

import 'package:media_kit/src/player/platform_player.dart';

import 'package:media_kit/src/player/web/utils/hls.dart';
import 'package:media_kit/src/player/web/utils/duration.dart';

import 'package:media_kit/src/models/track.dart';
import 'package:media_kit/src/models/playable.dart';
import 'package:media_kit/src/models/playlist.dart';
import 'package:media_kit/src/models/media/media.dart';
import 'package:media_kit/src/models/audio_device.dart';
import 'package:media_kit/src/models/player_state.dart';
import 'package:media_kit/src/models/audio_params.dart';
import 'package:media_kit/src/models/video_params.dart';
import 'package:media_kit/src/models/playlist_mode.dart';

/// Initializes the web backend for package:media_kit.
void webEnsureInitialized({String? libmpv}) {}

/// {@template web_player}
///
/// WebPlayer
/// ---------
///
/// HTML `<video>` implementation of [PlatformPlayer].
///
/// {@endtemplate}
class WebPlayer extends PlatformPlayer {
  /// {@macro web_player}
  WebPlayer({required super.configuration})
      : id = js.context[kInstanceCount] ?? 0,
        element = html.VideoElement() {
    lock.synchronized(() async {
      element
        // Do not add autoplay=false attribute: https://stackoverflow.com/a/19664804/12825435
        /* ..autoplay = false */
        ..controls = false
        ..muted = test
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        /* ..setAttribute('autoplay', 'false') */
        ..setAttribute('playsinline', 'true')
        ..pause();
      // Initialize or increment the instance count.
      js.context[kInstanceCount] ??= 0;
      js.context[kInstanceCount]++;
      // Store the [html.VideoElement] instance in global [js.context].
      js.context[kInstances] ??= js.JsObject.jsify({});
      js.context[kInstances][id] = element;
      // --------------------------------------------------
      // Event streams handling:
      element.onPlay.listen((_) {
        lock.synchronized(() async {
          // PlayerState.state.playing & PlayerState.stream.playing
          state = state.copyWith(playing: true);
          if (!playingController.isClosed) {
            playingController.add(true);
          }
        });
      });
      element.onPause.listen((_) {
        lock.synchronized(() async {
          // PlayerState.state.playing & PlayerState.stream.playing
          state = state.copyWith(playing: false);
          if (!playingController.isClosed) {
            playingController.add(false);
          }
        });
      });
      element.onPlaying.listen((_) {
        lock.synchronized(() async {
          // PlayerState.state.playing & PlayerState.stream.playing
          // PlayerState.state.buffering & PlayerState.stream.buffering
          state = state.copyWith(
            playing: true,
            completed: false,
          );
          if (!playingController.isClosed) {
            playingController.add(true);
          }
          if (!completedController.isClosed) {
            completedController.add(false);
          }
        });
      });
      element.onEnded.listen((_) {
        lock.synchronized(() async {
          // NOTE: Playlist index transition.
          await _transition();
        });
      });
      element.onTimeUpdate.listen((_) {
        lock.synchronized(() async {
          // PlayerState.state.position & PlayerState.stream.position
          Duration? position = convertNumVideoDurationToPluginDuration(
            element.currentTime,
          );

          // Clamp between current [Media]'s start & end.
          try {
            if (_index >= 0 && _index < _playlist.length) {
              final start = _playlist[_index].start?.inMilliseconds;
              final end = _playlist[_index].end?.inMilliseconds;
              if (position != null) {
                position = Duration(
                  milliseconds: position.inMilliseconds.clamp(
                    start ?? 0,
                    // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number/MAX_SAFE_INTEGER
                    end ?? 9007199254740991,
                  ),
                );

                if (position == _playlist[_index].end) {
                  // NOTE: Playlist index transition. onEnded callback will not be invoked.
                  await _transition();
                  return;
                }
              }
            }
          } catch (exception, stacktrace) {
            print(exception.toString());
            print(stacktrace.toString());
          }

          if (position != null) {
            state = state.copyWith(position: position);
            if (!positionController.isClosed) {
              positionController.add(position);
            }
            // PlayerState.state.buffer & PlayerState.stream.buffer
            final i = element.buffered.length - 1;
            if (i >= 0) {
              final buffer = convertNumVideoDurationToPluginDuration(
                element.buffered.end(i),
              );
              if (buffer != null) {
                state = state.copyWith(buffer: buffer);
                if (!bufferController.isClosed) {
                  bufferController.add(buffer);
                }
              }
            }
          }
        });
      });
      element.onDurationChange.listen((_) {
        lock.synchronized(() async {
          // PlayerState.state.duration & PlayerState.stream.duration
          final duration = convertNumVideoDurationToPluginDuration(
            element.duration,
          );
          if (duration != null) {
            state = state.copyWith(duration: duration);
            if (!durationController.isClosed) {
              durationController.add(duration);
            }
          }
        });
      });
      element.onWaiting.listen((_) {
        lock.synchronized(() async {
          // PlayerState.state.buffering & PlayerState.stream.buffering
          state = state.copyWith(buffering: true);
          if (!bufferingController.isClosed) {
            bufferingController.add(true);
          }
          // PlayerState.state.buffer & PlayerState.stream.buffer
          final i = element.buffered.length - 1;
          if (i >= 0) {
            final value = element.buffered.end(i) * 1000 ~/ 1;
            final buffer = Duration(milliseconds: value);
            if (!bufferController.isClosed) {
              bufferController.add(buffer);
            }
          }
        });
      });
      element.onCanPlay.listen((_) {
        lock.synchronized(() async {
          // PlayerState.state.buffering & PlayerState.stream.buffering
          state = state.copyWith(buffering: false);
          if (!bufferingController.isClosed) {
            bufferingController.add(false);
          }
        });
      });
      element.onCanPlayThrough.listen((_) {
        lock.synchronized(() async {
          // PlayerState.state.buffering & PlayerState.stream.buffering
          state = state.copyWith(buffering: false);
          if (!bufferingController.isClosed) {
            bufferingController.add(false);
          }
        });
      });
      element.onVolumeChange.listen((_) {
        lock.synchronized(() async {
          // PlayerState.state.volume & PlayerState.stream.volume
          final volume = element.volume * 100.0;
          state = state.copyWith(volume: volume);
          if (!volumeController.isClosed) {
            volumeController.add(volume);
          }
        });
      });
      element.onRateChange.listen((_) {
        lock.synchronized(() async {
          // PlayerState.state.speed & PlayerState.stream.speed
          final rate = element.playbackRate * 1.0;
          state = state.copyWith(rate: rate);
          if (!rateController.isClosed) {
            rateController.add(rate);
          }
        });
      });
      element.onError.listen((_) {
        lock.synchronized(() async {
          // PlayerState.state.buffering & PlayerState.stream.buffering
          state = state.copyWith(buffering: false);
          if (!bufferingController.isClosed) {
            bufferingController.add(false);
          }
          // PlayerStream.error
          final error = element.error!;
          if (!errorController.isClosed) {
            errorController.add(error.message ?? '');
          }
        });
      });
      element.onResize.listen((_) {
        lock.synchronized(() async {
          // PlayerState.state.width & PlayerState.stream.width
          // PlayerState.state.height & PlayerState.stream.height
          final width = element.videoWidth;
          final height = element.videoHeight;
          state = state.copyWith(
            width: width,
            height: height,
          );
          if (!widthController.isClosed) {
            widthController.add(width);
          }
          if (!heightController.isClosed) {
            heightController.add(height);
          }
        });
      });

      if (configuration.muted) {
        element.muted = true;
        state = state.copyWith(volume: 0.0);
        if (!volumeController.isClosed) {
          volumeController.add(0.0);
        }
      }

      await HLS.ensureInitialized(
        hls: test ? HLS.kHLSCDN : null,
      );
      completer.complete();
      try {
        configuration.ready?.call();
      } catch (_) {}
      // --------------------------------------------------
    });
  }

  @override
  Future<void> dispose({bool synchronized = true}) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      // To match NativePlayer behavior.

      await pause(synchronized: false);

      state = state.copyWith(
        track: state.track.copyWith(
          video: VideoTrack.no(),
        ),
      );
      if (!trackController.isClosed) {
        trackController.add(state.track);
      }
      state = state.copyWith(
        track: state.track.copyWith(
          audio: AudioTrack.no(),
        ),
      );
      if (!trackController.isClosed) {
        trackController.add(state.track);
      }
      state = state.copyWith(
        track: state.track.copyWith(
          subtitle: SubtitleTrack.no(),
        ),
      );
      if (!trackController.isClosed) {
        trackController.add(state.track);
      }

      disposed = true;

      element
        ..src = ''
        ..load()
        ..remove();

      // Remove the [html.VideoElement] instance from global [js.context].
      js.context[kInstances].deleteProperty(id);

      await super.dispose();
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> open(
    Playable playable, {
    bool play = true,
    bool synchronized = true,
  }) async {
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

      // Restore original state & reset public [PlayerState] & [PlayerStream] values e.g. width=null, height=null, subtitle=['', ''] etc.
      await stop(
        open: true,
        synchronized: false,
      );

      element.pause();
      // Enter paused state.
      // NOTE: Handled as part of [stop] logic.
      // state = state.copyWith(playing: false);
      // if (!playingController.isClosed) {
      //   playingController.add(false);
      // }

      _index = index;
      _playlist = playlist;

      _shuffle.clear();

      state = state.copyWith(
        playlist: Playlist(
          playlist,
          index: index,
        ),
      );
      if (!playlistController.isClosed) {
        playlistController.add(
          Playlist(
            playlist,
            index: index,
          ),
        );
      }

      _loadSource(_playlist[_index]);

      if (play) {
        element.play().catchError(
          (error) {
            // PlayerStream.error
            final e = error as html.DomException;
            if (!errorController.isClosed) {
              errorController.add(e.message ?? '');
            }
          },
        );
      } else {
        // A minimal quirk to match the native backend behavior.
        state = state.copyWith(
          buffering: true,
        );
        if (!bufferingController.isClosed) {
          bufferingController.add(true);
        }
        // [onCanPlay] & [onCanPlayThrough] will emit buffering = false.
      }
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
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      element.children.clear();
      state = state.copyWith(track: Track());
      if (!trackController.isClosed) {
        trackController.add(Track());
      }

      element
        ..src = ''
        ..load();

      _shuffle.clear();
      _index = 0;
      _playlist = [];

      // Reset the remaining attributes.
      state = PlayerState().copyWith(
        volume: state.volume,
        rate: state.rate,
        pitch: state.pitch,
        playlistMode: state.playlistMode,
        audioDevice: state.audioDevice,
        audioDevices: state.audioDevices,
      );
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
      // if (!volumeController.isClosed) {
      //   volumeController.add(0.0);
      // }
      // if (!rateController.isClosed) {
      //   rateController.add(0.0);
      // }
      // if (!pitchController.isClosed) {
      //   pitchController.add(0.0);
      // }
      if (!bufferingController.isClosed) {
        bufferingController.add(false);
      }
      if (!bufferController.isClosed) {
        bufferController.add(Duration.zero);
      }
      // if (!playlistModeController.isClosed) {
      //   playlistModeController.add(PlaylistMode.none);
      // }
      if (!audioParamsController.isClosed) {
        audioParamsController.add(const AudioParams());
      }
      if (!videoParamsController.isClosed) {
        videoParamsController.add(const VideoParams());
      }
      if (!audioBitrateController.isClosed) {
        audioBitrateController.add(null);
      }
      if (!videoBitrateController.isClosed) {
        videoBitrateController.add(null);
      }
      // if (!audioDeviceController.isClosed) {
      //   audioDeviceController.add(AudioDevice.auto());
      // }
      // if (!audioDevicesController.isClosed) {
      //   audioDevicesController.add([AudioDevice.auto()]);
      // }
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

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> play({bool synchronized = true}) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;
      element.play().catchError(
        (error) {
          // PlayerStream.error
          final e = error as html.DomException;
          if (!errorController.isClosed) {
            errorController.add(e.message ?? '');
          }
        },
      );
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> pause({bool synchronized = true}) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;
      element.pause();
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> playOrPause({bool synchronized = true}) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;
      if (element.paused) {
        await play(synchronized: false);
      } else {
        await pause(synchronized: false);
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> add(
    Media media, {
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      _playlist = [..._playlist, media];

      state = state.copyWith(
        playlist: state.playlist.copyWith(
          medias: _playlist,
        ),
      );
      if (!playlistController.isClosed) {
        playlistController.add(state.playlist);
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> remove(
    int index, {
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      // If we remove the last item in the playlist while playlist mode is none or single, then playback will stop.
      // In this situation, the playlist doesn't seem to be updated, so we manually update it.
      if (_index == index &&
          _playlist.length - 1 == index &&
          [
            PlaylistMode.none,
            PlaylistMode.single,
          ].contains(_playlistMode)) {
        _index = _playlist.length - 2 < 0 ? 0 : _playlist.length - 2;

        state = state.copyWith(
          // Allow playOrPause /w state.completed code-path to play the playlist again.
          completed: true,
          playlist: state.playlist.copyWith(
            medias: _playlist.sublist(0, _playlist.length - 1),
            index: _index,
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
      else if (_index == index &&
          _playlist.length - 1 == index &&
          _playlistMode == PlaylistMode.loop) {
        element.children.clear();
        state = state.copyWith(track: Track());
        if (!trackController.isClosed) {
          trackController.add(Track());
        }

        _index = 0;
        _loadSource(_playlist[_index]);
        await play(synchronized: false);

        state = state.copyWith(
          // Allow playOrPause /w state.completed code-path to play the playlist again.
          completed: true,
          playlist: state.playlist.copyWith(
            medias: _playlist.sublist(0, _playlist.length - 1),
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
        _playlist = [..._playlist];
        _playlist.removeAt(index);

        // If the current index is greater than the removed index, then the current index should be reduced by 1.
        // If the current index is equal or less than the removed index, then the current index should not be changed.
        if (_index > index) {
          _index--;
        }

        state = state.copyWith(
          playlist: state.playlist.copyWith(
            medias: _playlist,
            index: _index,
          ),
        );
        if (!playlistController.isClosed) {
          playlistController.add(state.playlist);
        }
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> next({
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      Future<void> start() async {
        state = state.copyWith(
          playlist: state.playlist.copyWith(
            index: _index,
          ),
        );
        if (!playlistController.isClosed) {
          playlistController.add(state.playlist);
        }

        element.children.clear();
        state = state.copyWith(track: Track());
        if (!trackController.isClosed) {
          trackController.add(Track());
        }
        _loadSource(_playlist[_index]);
        await play(synchronized: false);

        state = state.copyWith(playing: true);
        if (!playingController.isClosed) {
          playingController.add(true);
        }
      }

      switch (_playlistMode) {
        case PlaylistMode.none:
          {
            if (_index < _playlist.length - 1) {
              _index++;
              await start();
            } else {
              // No transition.
            }
            break;
          }
        case PlaylistMode.single:
          {
            if (_index < _playlist.length - 1) {
              _index++;
              await start();
            } else {
              // No transition.
            }
            break;
          }
        case PlaylistMode.loop:
          {
            _index = (_index + 1) % _playlist.length;
            await start();
            break;
          }
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> previous({
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      Future<void> start() async {
        state = state.copyWith(
          playlist: state.playlist.copyWith(
            index: _index,
          ),
        );
        if (!playlistController.isClosed) {
          playlistController.add(state.playlist);
        }

        element.children.clear();
        state = state.copyWith(track: Track());
        if (!trackController.isClosed) {
          trackController.add(Track());
        }
        _loadSource(_playlist[_index]);
        await play(synchronized: false);

        state = state.copyWith(playing: true);
        if (!playingController.isClosed) {
          playingController.add(true);
        }
      }

      switch (_playlistMode) {
        case PlaylistMode.none:
          {
            if (_index > 0) {
              _index--;
              await start();
            } else {
              // No transition.
            }
            break;
          }
        case PlaylistMode.single:
          {
            if (_index > 0) {
              _index--;
              await start();
            } else {
              // No transition.
            }
            break;
          }
        case PlaylistMode.loop:
          {
            _index = (_index - 1) % _playlist.length;
            await start();
            break;
          }
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> jump(
    int index, {
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      _index = index;

      element.children.clear();
      state = state.copyWith(track: Track());
      if (!trackController.isClosed) {
        trackController.add(Track());
      }
      _loadSource(_playlist[_index]);
      await play(synchronized: false);

      state = state.copyWith(playing: true);
      if (!playingController.isClosed) {
        playingController.add(true);
      }

      state = state.copyWith(
        playlist: state.playlist.copyWith(
          index: _index,
        ),
      );
      if (!playlistController.isClosed) {
        playlistController.add(state.playlist);
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> move(
    int from,
    int to, {
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      // ---------------------------------------------
      final map = SplayTreeMap<double, Media>.from(
        _playlist.asMap().map((key, value) => MapEntry(key * 1.0, value)),
      );
      final item = map.remove(from * 1.0);
      if (item != null) {
        map[to - 0.5] = item;
      }
      final keys = map.keys.toList();
      final values = map.values.toList();

      final current = _index;

      _index = keys.contains(current * 1.0)
          ? keys.indexOf(current * 1.0)
          : keys.indexOf(to - 0.5);
      _playlist = values;
      // ---------------------------------------------

      state = state.copyWith(
        playlist: Playlist(
          _playlist,
          index: _index,
        ),
      );
      if (!playlistController.isClosed) {
        playlistController.add(state.playlist);
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> seek(
    Duration duration, {
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      element.currentTime = duration.inMilliseconds.toDouble() / 1000.0;

      // It is self explanatory that PlayerState.completed & PlayerStreams.completed must enter the false state if seek is called. Typically after EOF.
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

  @override
  Future<void> setPlaylistMode(
    PlaylistMode playlistMode, {
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;
      _playlistMode = playlistMode;

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

  @override
  Future<void> setVolume(
    double volume, {
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      // Unmute the player before setting the volume.
      if (element.muted) {
        element.muted = false;
      }

      element.volume = volume / 100.0;
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> setRate(
    double rate, {
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }

      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      if (rate <= 0.0) {
        throw ArgumentError.value(
          rate,
          'rate',
          'Must be greater than 0.0',
        );
      }
      element.playbackRate = rate;
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> setPitch(
    double pitch, {
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }

      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      throw UnsupportedError('[Player.setPitch] is not supported on web');

      // if (pitch <= 0.0) {
      //   throw ArgumentError.value(
      //     pitch,
      //     'pitch',
      //     'Must be greater than 0.0',
      //   );
      // }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> setShuffle(
    bool shuffle, {
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      final current = _playlist[_index];

      if (shuffle && _shuffle.isEmpty) {
        _shuffle.addAll(_playlist);
        if (_playlist.length > 1) {
          while (ListEquality().equals(_shuffle, _playlist)) {
            _playlist.shuffle();
          }
        }
        _index = _playlist.indexOf(current);

        state = state.copyWith(
          playlist: Playlist(
            [..._playlist],
            index: _index,
          ),
        );
        if (!playlistController.isClosed) {
          playlistController.add(state.playlist);
        }
      } else if (!shuffle && _shuffle.isNotEmpty) {
        _playlist.clear();
        _playlist.addAll(_shuffle);
        _index = _playlist.indexOf(current);
        _shuffle.clear();

        state = state.copyWith(
          playlist: Playlist(
            [..._playlist],
            index: _index,
          ),
        );
        if (!playlistController.isClosed) {
          playlistController.add(state.playlist);
        }
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> setAudioDevice(
    AudioDevice audioDevice, {
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;
      throw UnsupportedError('[Player.setAudioDevice] is not supported on web');
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> setVideoTrack(
    VideoTrack track, {
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;
      throw UnsupportedError(
        '[Player.setVideoTrack] is not supported on web',
      );
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> setAudioTrack(
    AudioTrack track, {
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      if (track.uri) {
        element.children.removeWhere((e) => e is html.SourceElement);

        final child = html.SourceElement();
        child.src = track.id;
        element.append(child);

        state = state.copyWith(track: state.track.copyWith(audio: track));
        if (!trackController.isClosed) {
          trackController.add(state.track);
        }
      } else {
        throw UnsupportedError(
          '[Player.setAudioTrack] is only supported with [AudioTrack.uri] on web',
        );
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<void> setSubtitleTrack(
    SubtitleTrack track, {
    bool synchronized = true,
  }) async {
    Future<void> function() async {
      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }
      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      // Reset existing Player.state.subtitle & Player.stream.subtitle.
      state = state.copyWith(
        subtitle: const PlayerState().subtitle,
      );
      if (!subtitleController.isClosed) {
        subtitleController.add(state.subtitle);
      }

      if (['no', 'auto'].contains(track.id)) {
        // N / A
      } else if (track.uri || track.data) {
        final String uri;
        if (track.uri) {
          uri = track.id;
        } else if (track.data) {
          // Create object URL from subtitle data.
          final src = html.Url.createObjectUrlFromBlob(html.Blob([track.id]));
          // Revoke the object URL upon [dispose].
          release.add(() async {
            html.Url.revokeObjectUrl(src);
          });
          uri = src;
        } else {
          return;
        }

        element.children.removeWhere((e) => e is html.TrackElement);

        final child = html.TrackElement();
        child.src = uri;
        child.kind = 'subtitles';
        child.label = track.title;
        child.srclang = track.language;
        element.append(child);

        state = state.copyWith(track: state.track.copyWith(subtitle: track));
        if (!trackController.isClosed) {
          trackController.add(state.track);
        }

        // To match NativePlayer behavior.
        state = state.copyWith(subtitle: ['', '']);
        if (!subtitleController.isClosed) {
          subtitleController.add(['', '']);
        }

        final tracks = element.textTracks?.toList() ?? <html.TextTrack>[];
        tracks.first.mode = 'hidden';
        tracks.first.onCueChange.listen((_) {
          try {
            final data = tracks.first.activeCues?.map((e) {
              final text = (e as dynamic).text as String;
              return text
                  .replaceAll(RegExp('<[^>]*>'), ' ')
                  .replaceAll(RegExp('\\s+'), ' ')
                  .trim();
            }).toList();
            if (data != null) {
              final subtitle = ['', ''];
              if (data.length == 1) {
                subtitle[0] = data[0];
              } else if (data.length == 2) {
                subtitle[0] = data[0];
                subtitle[1] = data.skip(1).join('\n');
              }
              state = state.copyWith(subtitle: subtitle);
              if (!subtitleController.isClosed) {
                subtitleController.add(subtitle);
              }
            }
          } catch (exception, stacktrace) {
            print(exception);
            print(stacktrace);
          }
        });
      } else {
        throw UnsupportedError(
          '[Player.setSubtitleTrack] is only supported with [SubtitleTrack.uri] & [SubtitleTrack.data] on web',
        );
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  /// Takes the snapshot of the current frame & returns encoded image bytes as [Uint8List].
  ///
  /// The [format] parameter specifies the format of the image to be returned. Supported values are:
  /// * `image/jpeg`
  /// * `image/png`
  ///
  /// [includeLibassSubtitles] is ignored.
  @override
  Future<Uint8List?> screenshot(
      {String? format = 'image/jpeg',
      bool synchronized = true,
      bool includeLibassSubtitles = false}) async {
    Future<Uint8List?> function() async {
      if (![
        'image/jpeg',
        'image/png',
      ].contains(format)) {
        throw ArgumentError.value(
          format,
          'format',
          'Supported values are: image/jpeg, image/png',
        );
      }

      if (disposed) {
        throw AssertionError('[Player] has been disposed');
      }

      await waitForPlayerInitialization;
      await waitForVideoControllerInitializationIfAttached;

      try {
        // Kind of limited in usage:
        // https://stackoverflow.com/questions/35244215/html5-video-screenshot-via-canvas-using-cors
        final canvas = html.CanvasElement();
        canvas.width = element.videoWidth;
        canvas.height = element.videoHeight;
        final context = canvas.context2D;
        context.drawImage(element, 0, 0);

        final data = canvas.toDataUrl(format!);
        final bytes = base64.decode(data.split(',').last);

        canvas.remove();

        return bytes;
      } catch (_) {
        return null;
      }
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  @override
  Future<Uint8List?> safeScreenshot(
      {String? format = 'image/jpeg',
      bool synchronized = true,
      bool includeLibassSubtitles = false}) {
    return screenshot(
      format: format,
      synchronized: synchronized,
      includeLibassSubtitles: includeLibassSubtitles,
    );
  }

  void _loadSource(Media media) {
    try {
      if (_isHLS(media.uri)) {
        final hls = Hls();
        hls.loadSource(media.uri);
        hls.attachMedia(element);
      } else {
        // Default
        String src = media.uri;

        // https://www.w3.org/TR/media-frags/
        if (media.start != null || media.end != null) {
          src += '#t=';
          final start = media.start?.inSeconds ?? 0;
          final end = media.end?.inSeconds ?? 0;
          src += [start, if (end != 0) end].join(',');
        }

        element.src = src;
      }
    } catch (exception) {
      // PlayerStream.error
      final e = exception as html.DomException;
      if (!errorController.isClosed) {
        errorController.add(e.message ?? '');
      }
    }
  }

  bool _isHLS(String src) {
    final userAgent = html.window.navigator.userAgent;
    final isAndroidChrome =
        userAgent.contains("Android") && userAgent.contains("Chrome");

    if (!isAndroidChrome &&
        element.canPlayType('application/vnd.apple.mpegurl') != '') {
      return false;
    }
    if (isHLSSupported() && src.toLowerCase().contains('m3u8')) {
      return true;
    }
    return false;
  }

  Future<void> _transition() async {
    // PlayerState.state.playing & PlayerState.stream.playing
    // PlayerState.state.completed & PlayerState.stream.completed
    // PlayerState.state.buffering & PlayerState.stream.buffering

    // A minimal quirk to match the NativePlayer behavior.
    state = state.copyWith(
      buffering: true,
    );
    if (!bufferingController.isClosed) {
      bufferingController.add(true);
    }

    state = state.copyWith(
      playing: false,
      completed: true,
      buffering: false,
    );
    if (!playingController.isClosed) {
      playingController.add(false);
    }
    if (!completedController.isClosed) {
      completedController.add(true);
    }
    if (!bufferingController.isClosed) {
      bufferingController.add(false);
    }

    element.children.clear();
    state = state.copyWith(track: Track());
    if (!trackController.isClosed) {
      trackController.add(Track());
    }

    // PlayerState.state.playlist.index & PlayerState.stream.playlist.index
    switch (_playlistMode) {
      case PlaylistMode.none:
        {
          if (_index < _playlist.length - 1) {
            _index = _index + 1;
            final current = _playlist[_index];
            _loadSource(current);
            await play(synchronized: false);
          } else {
            // Playback must end.
          }
          break;
        }
      case PlaylistMode.single:
        {
          final current = _playlist[_index];
          _loadSource(current);
          await play(synchronized: false);
          break;
        }
      case PlaylistMode.loop:
        {
          _index = (_index + 1) % _playlist.length;
          final current = _playlist[_index];
          _loadSource(current);
          await play(synchronized: false);
          break;
        }
    }
    // Update:
    state = state.copyWith(
      playlist: state.playlist.copyWith(
        index: _index,
      ),
    );
    if (!playlistController.isClosed) {
      playlistController.add(state.playlist);
    }
  }

  // --------------------------------------------------

  /// Current loaded [Media] queue before shuffle.
  final List<Media> _shuffle = <Media>[];

  /// Current index of the [Media] in the queue.
  int _index = 0;

  /// Current loaded [Media] queue.
  List<Media> _playlist = <Media>[];

  /// Current playlist mode.
  PlaylistMode _playlistMode = PlaylistMode.none;

  // --------------------------------------------------

  /// Internal platform specific identifier for this [Player] instance.
  ///
  /// Since, [int] is a primitive type, it can be used to pass this [Player] instance to native code without directly depending upon this library.
  ///
  @override
  Future<int> get handle => Future.value(id);

  /// Unique handle of this [Player] instance.
  final int id;

  /// [html.VideoElement] instance reference.
  final html.VideoElement element;

  /// Whether the [Player] has been disposed.
  bool disposed = false;

  /// Synchronization & mutual exclusion between methods of this class.
  final Lock lock = Lock();

  /// JavaScript object attribute used to store various [VideoElement] instances in [js.context].
  static const kInstances = '\$com.alexmercerind.media_kit.instances';

  /// JavaScript object attribute used to store the instance count of [Player] in [js.context].
  static const kInstanceCount = '\$com.alexmercerind.media_kit.instance_count';

  /// Whether the [WebPlayer] is initialized for unit-testing.
  @visibleForTesting
  static bool test = false;
}
