import 'dart:async' show StreamSubscription, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/app/app.dart' show playerKernelProvider;
import 'package:pure_live/modules/music/controller/music_library.dart'
    show musicRecentProvider, musicTrackFromJson, musicTrackToJson;
import 'package:pure_live/modules/music/controller/music_settings.dart' show MusicQuality, musicSettingsProvider;
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceProvider;

/// The preference the last queue is kept under, so 打开时继续播放 has
/// something to resume.
const String kMusicQueueKey = 'music.queue';

/// The queue as the last run left it.
typedef MusicQueueSnapshot = ({List<audio.MusicTrack> tracks, int index});

/// The queue's own storage, kept out of the player controller: the controller
/// owns the engine and the queue, and a settings refresh that rebuilt it would
/// stop the music the queue describes. Nothing about the player is a setting.
final class MusicQueueStore {
  /// The store.
  const MusicQueueStore();

  /// The stored queue, or null when there is none or it is damaged.
  MusicQueueSnapshot? read() {
    try {
      final raw = StoragePrefs.getString(kMusicQueueKey);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final entries = json['tracks'];
      if (entries is! List) return null;
      final tracks = [for (final entry in entries) ?musicTrackFromJson(entry)];
      if (tracks.isEmpty) return null;
      final index = ((json['index'] as num?)?.toInt() ?? 0).clamp(0, tracks.length - 1);
      return (tracks: tracks, index: index);
    } on Object {
      return null;
    }
  }

  /// Keeps [tracks] and the current [index] for the next run.
  Future<void> write(List<audio.MusicTrack> tracks, int index) async {
    try {
      await StoragePrefs.setString(
        kMusicQueueKey,
        jsonEncode({
          'index': index,
          'tracks': [for (final track in tracks) musicTrackToJson(track)],
        }),
      );
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The queue's storage.
final musicQueueStoreProvider = Provider<MusicQueueStore>((ref) => const MusicQueueStore());

/// The engine's tier for the module's preference: the source then resolves
/// the platform's closest rendition at or below it.
audio.MusicQuality musicQualityOf(MusicQuality quality) => switch (quality) {
  MusicQuality.standard => audio.MusicQuality.k128,
  MusicQuality.high => audio.MusicQuality.k320,
  MusicQuality.lossless => audio.MusicQuality.flac,
  MusicQuality.hiRes => audio.MusicQuality.flac24bit,
};

/// The module's player: a song queue, the audio engine and the module's own
/// preferences.
///
/// The engine work belongs to `media_core_audio`'s controller; this is the
/// module's seam — one queue for every view, the recently played list fed
/// from it, and the last queue kept for the next run. The controller outlives
/// the pages that watch it, so closing the player keeps the song playing.
final class MusicPlayerController extends Notifier<audio.AudioPlaybackState> {
  late final audio.AudioPlaybackController _audio;
  StreamSubscription<audio.AudioPlaybackState>? _states;
  String? _recentTrack;
  String? _savedTrack;
  int _savedLength = -1;

  @override
  audio.AudioPlaybackState build() {
    // The kernel is read, not watched: rebuilding this controller would throw
    // its queue away, and a kernel that changes belongs to a new window.
    final settings = ref.read(musicSettingsProvider);
    _audio = audio.AudioPlaybackController(
      ref.read(playerKernelProvider),
      registry: audio.MusicSourceRegistry([ref.read(musicSourceProvider)]),
      config: audio.AudioPlaybackConfig(initialQuality: musicQualityOf(settings.quality)),
    );
    // A quality choice reaches the source on the next track: the engine notes
    // the tier, resolution asks the source for it.
    ref.listen(musicSettingsProvider.select((settings) => settings.quality), (_, quality) {
      _audio.setQuality(musicQualityOf(quality));
    });
    _states = _audio.stateStream.listen((next) {
      if (!ref.mounted) return;
      state = next;
      _follow(next);
    });
    ref.onDispose(() {
      unawaited(_states?.cancel() ?? Future<void>.value());
      unawaited(_audio.dispose());
    });
    unawaited(_restore());
    return _audio.state;
  }

  /// The queue, in order.
  List<audio.MusicTrack> get queue => _audio.queue.tracks;

  /// Replaces the queue with [tracks], starting on [index] and playing.
  Future<void> playAll(Iterable<audio.MusicTrack> tracks, {int index = 0}) =>
      _audio.setQueue(tracks, startIndex: index);

  /// Plays [track], adding it to the queue when it is not there yet.
  Future<void> play(audio.MusicTrack track) => _audio.playTrack(track);

  /// Plays the queue entry at [index].
  Future<void> playAt(int index) => _audio.playAt(index);

  /// Puts [track] right after the current one.
  Future<void> playNext(audio.MusicTrack track) => _audio.playTrack(track, insertNext: true);

  Future<void> toggle() => _audio.toggle();

  Future<void> next() => _audio.next();

  Future<void> previous() => _audio.previous();

  Future<void> seek(Duration position) => _audio.seek(position);

  Future<void> setVolume(double volume) => _audio.setVolume(volume);

  Future<void> setMuted({required bool muted}) => _audio.setMute(muted: muted);

  void setMode(audio.PlayMode mode) => _audio.setPlayMode(mode);

  /// The current track's lyric, fetched through its source and parsed; empty
  /// when the song has none.
  Future<audio.LyricDocument> loadLyric({bool force = false}) => _audio.loadCurrentLyric(force: force);

  /// Steps the mode through the reference's four, in its order: one pass,
  /// list loop, single loop, shuffle.
  void cycleMode() => setMode(_nextMode(_audio.queue.mode));

  static audio.PlayMode _nextMode(audio.PlayMode mode) => switch (mode) {
    audio.PlayMode.list => audio.PlayMode.listLoop,
    audio.PlayMode.listLoop => audio.PlayMode.singleLoop,
    audio.PlayMode.singleLoop => audio.PlayMode.random,
    audio.PlayMode.random => audio.PlayMode.list,
  };

  /// Feeds the recently played list and keeps the queue for the next run.
  void _follow(audio.AudioPlaybackState next) {
    final track = next.track;
    // A queue restored for 打开时继续播放 is not something the viewer played:
    // only a track that is being opened or is running counts as listened to.
    if (track != null && (next.playing || next.loading) && track.id != _recentTrack) {
      _recentTrack = track.id;
      unawaited(ref.read(musicRecentProvider.notifier).record(track));
    }
    if (track?.id != _savedTrack || next.queueLength != _savedLength) {
      _savedTrack = track?.id;
      _savedLength = next.queueLength;
      unawaited(_saveQueue());
    }
  }

  Future<void> _saveQueue() async {
    await ref.read(musicQueueStoreProvider).write(_audio.queue.tracks, _audio.queue.index);
  }

  /// Reopens the last queue when the viewer asked the module to continue;
  /// restored paused, because opening a page is not pressing play.
  Future<void> _restore() async {
    if (!ref.read(musicSettingsProvider).autoplay) return;
    final snapshot = ref.read(musicQueueStoreProvider).read();
    if (snapshot == null || !ref.mounted) return;
    await _audio.setQueue(snapshot.tracks, startIndex: snapshot.index, autoPlay: false);
  }
}

/// The module's player and queue.
final musicPlayerProvider = NotifierProvider<MusicPlayerController, audio.AudioPlaybackState>(
  MusicPlayerController.new,
);
