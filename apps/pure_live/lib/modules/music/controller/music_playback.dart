import 'dart:async' show StreamSubscription, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core/media_core.dart' show PlayerConfig;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/app/app.dart' show playerKernelProvider;
import 'package:pure_live/modules/music/controller/music_library.dart'
    show musicRecentProvider, musicTrackFromJson, musicTrackToJson;
import 'package:pure_live/modules/music/controller/music_settings.dart'
    show MusicQuality, MusicSettings, musicSettingsProvider;
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
  audio.DesktopLyricController? _desktopLyric;
  StreamSubscription<bool>? _desktopVisibleChanges;
  StreamSubscription<bool>? _desktopLockChanges;
  audio.MusicBackgroundBinding? _background;
  String? _recentTrack;
  String? _savedTrack;
  int _savedLength = -1;
  bool _askedNotifications = false;

  @override
  audio.AudioPlaybackState build() {
    // The kernel is read, not watched: rebuilding this controller would throw
    // its queue away, and a kernel that changes belongs to a new window.
    final settings = ref.read(musicSettingsProvider);
    _audio = audio.AudioPlaybackController(
      ref.read(playerKernelProvider),
      // The local source is registered for its sidecar lyric reader: a local
      // track resolves through its file path, but its `.lrc` is asked here.
      registry: audio.MusicSourceRegistry([ref.read(musicSourceProvider), audio.LocalMusicSource(roots: const [])]),
      config: audio.AudioPlaybackConfig(initialQuality: musicQualityOf(settings.quality)),
      // Music is the one player that keeps going after the app is backgrounded:
      // the kernel's own policy would pause it with every other player.
      playerConfig: const PlayerConfig(pauseWhenBackgrounded: false),
    );
    _audio.setLyricOffset(Duration(milliseconds: settings.lyricOffsetMs));
    // The app arms the OS surfaces once at boot; a live driver lets the music
    // player publish its queue to the notification, lock screen or MPRIS. A
    // boot that lost that race (or failed once) is retried here, because a
    // song without its notification is a silent loss of the feature.
    final session = audio.MediaSessionBootstrap.current;
    if (session != null) {
      _attachBackground(session);
    } else {
      unawaited(
        audio.MediaSessionBootstrap.enable()
            .then((driver) {
              if (ref.mounted) _attachBackground(driver);
            })
            .catchError((Object _) {
              // The platform has no surface; playback still works.
            }),
      );
    }
    // A quality choice reaches the source on the next track: the engine notes
    // the tier, resolution asks the source for it.
    ref.listen(musicSettingsProvider.select((settings) => settings.quality), (_, quality) {
      _audio.setQuality(musicQualityOf(quality));
    });
    ref.listen(musicSettingsProvider.select((settings) => settings.lyricOffsetMs), (_, offsetMs) {
      _audio.setLyricOffset(Duration(milliseconds: offsetMs));
    });
    ref.listen(musicSettingsProvider.select((settings) => (settings.showTranslation, settings.showRomanization)), (
      _,
      display,
    ) {
      unawaited(
        _desktopLyric?.setDisplayOptions(
              audio.LyricDisplayOptions(showTranslation: display.$1, showRomanization: display.$2),
            ) ??
            Future<void>.value(),
      );
    });
    ref.listen(
      musicSettingsProvider.select(
        (settings) => (
          settings.desktopLyricFontSize,
          settings.desktopLyricOpacity,
          settings.desktopLyricTextColor,
          settings.desktopLyricAlignment,
          settings.desktopLyricLocked,
        ),
      ),
      (previous, next) {
        final desktop = _desktopLyric;
        if (desktop == null) return;
        if (previous != null &&
            (previous.$1 != next.$1 || previous.$2 != next.$2 || previous.$3 != next.$3 || previous.$4 != next.$4)) {
          final settings = ref.read(musicSettingsProvider);
          unawaited(desktop.setStyle(_desktopStyle(settings)));
        }
        if (previous == null || previous.$5 != next.$5) {
          unawaited(desktop.setLocked(locked: next.$5));
        }
      },
    );
    _states = _audio.stateStream.listen((next) {
      if (!ref.mounted) return;
      state = next;
      _follow(next);
      // Android 13+ hides the media notification without this permission; ask
      // when the viewer actually starts a song, not on some unrelated page.
      if (next.playing && !_askedNotifications) {
        _askedNotifications = true;
        unawaited(audio.AudioPermissionService().request(audio.AudioPermission.notifications));
      }
    });
    ref.onDispose(() {
      unawaited(_states?.cancel() ?? Future<void>.value());
      unawaited(_desktopVisibleChanges?.cancel() ?? Future<void>.value());
      unawaited(_desktopLockChanges?.cancel() ?? Future<void>.value());
      _background?.detach();
      unawaited(_desktopLyric?.dispose() ?? Future<void>.value());
      unawaited(_audio.dispose());
    });
    unawaited(_restore());
    unawaited(_restoreDesktopLyric());
    return _audio.state;
  }

  /// Mirrors the player onto the OS surface once a driver exists.
  void _attachBackground(audio.MediaSessionDriver session) {
    _background ??= audio.MusicBackgroundBinding(_audio, session)..attach();
  }

  /// The overlay style the preferences describe.
  static audio.DesktopLyricStyle _desktopStyle(MusicSettings settings) => audio.DesktopLyricStyle(
    fontSize: settings.desktopLyricFontSize,
    opacity: settings.desktopLyricOpacity,
    textColor: settings.desktopLyricTextColor,
    alignment: settings.desktopLyricAlignment,
  );

  /// The overlay controller, created on first use with the current style.
  audio.DesktopLyricController _desktopController(MusicSettings settings) {
    final existing = _desktopLyric;
    if (existing != null) return existing;
    final desktop = audio.DesktopLyricController(
      _audio,
      style: _desktopStyle(settings),
      showTranslation: settings.showTranslation,
      showRomanization: settings.showRomanization,
    );
    _desktopLyric = desktop;
    // The overlay has its own close and lock buttons: following its stream
    // keeps the saved choice (and the menu's check marks) honest when the
    // viewer reaches for the window instead of the settings page.
    _desktopVisibleChanges = desktop.visibleChanges.listen((visible) {
      if (!ref.mounted) return;
      unawaited(ref.read(musicSettingsProvider.notifier).setDesktopLyrics(visible: visible));
    });
    _desktopLockChanges = desktop.lockedChanges.listen((locked) {
      if (!ref.mounted) return;
      unawaited(ref.read(musicSettingsProvider.notifier).setDesktopLyricLocked(locked: locked));
    });
    if (settings.desktopLyricLocked) {
      unawaited(desktop.setLocked(locked: true));
    }
    return desktop;
  }

  /// Reopens the overlay on the next run when the viewer left it on. It never
  /// prompts: the permission round trip belongs to [toggleDesktopLyric], and a
  /// restored overlay that cannot draw simply stays hidden.
  Future<void> _restoreDesktopLyric() async {
    final settings = ref.read(musicSettingsProvider);
    if (!settings.desktopLyrics) return;
    try {
      final desktop = _desktopController(settings);
      if (!await desktop.hasPermission()) return;
      if (!ref.mounted) return;
      await desktop.show();
    } on Object {
      // No overlay window on this platform.
    }
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

  Future<void> setRate(double rate) => _audio.setRate(rate);

  /// Starts, replaces or clears the sleep timer.
  void setSleepTimer(Duration? duration) => _audio.setSleepTimer(duration);

  /// Moves the lyric delay; the preference keeps it for the next run.
  Future<void> setLyricOffset(Duration offset) async {
    _audio.setLyricOffset(offset);
    await ref.read(musicSettingsProvider.notifier).setLyricOffsetMs(offset.inMilliseconds);
  }

  /// Drops the queue entry at [index].
  Future<void> removeAt(int index) => _audio.removeAt(index);

  /// Empties the queue and stops.
  Future<void> clearQueue() => _audio.clearQueue();

  void setMode(audio.PlayMode mode) => _audio.setPlayMode(mode);

  /// The current track's lyric, fetched through its source and parsed; empty
  /// when the song has none.
  Future<audio.LyricDocument> loadLyric({bool force = false}) => _audio.loadCurrentLyric(force: force);

  /// Whether the desktop lyric overlay is on screen.
  bool get desktopLyricVisible => _desktopLyric?.visible ?? false;

  /// Whether the overlay ignores pointer input.
  bool get desktopLyricLocked => ref.read(musicSettingsProvider).desktopLyricLocked;

  /// Shows or hides the desktop lyric overlay and remembers the choice; false
  /// means the host has no overlay window (or the viewer refused the
  /// permission).
  Future<bool> toggleDesktopLyric() async {
    final settings = ref.read(musicSettingsProvider);
    final desktop = _desktopController(settings);
    try {
      final visible = await desktop.toggle();
      await ref.read(musicSettingsProvider.notifier).setDesktopLyrics(visible: visible);
      return visible;
    } on Object {
      // A host without the overlay plugin.
      return false;
    }
  }

  /// Shows or hides the overlay explicitly, so a switch that is out of sync
  /// with the native window still does what its new value says.
  Future<bool> setDesktopLyricVisible({required bool visible}) async {
    final settings = ref.read(musicSettingsProvider);
    final existing = _desktopLyric;
    // Turning off an overlay that was never opened needs no controller; it
    // would only subscribe to the player for nothing.
    if (!visible && existing == null) {
      await ref.read(musicSettingsProvider.notifier).setDesktopLyrics(visible: false);
      return false;
    }
    final desktop = existing ?? _desktopController(settings);
    try {
      if (visible) {
        final shown = await desktop.show();
        await ref.read(musicSettingsProvider.notifier).setDesktopLyrics(visible: shown);
        return shown;
      }
      await desktop.hide();
    } on Object {
      // A host without the overlay plugin.
    }
    await ref.read(musicSettingsProvider.notifier).setDesktopLyrics(visible: false);
    return false;
  }

  /// Locks the overlay into click-through mode, or unlocks it.
  Future<void> setDesktopLyricLocked({required bool locked}) async {
    await ref.read(musicSettingsProvider.notifier).setDesktopLyricLocked(locked: locked);
    await _desktopLyric?.setLocked(locked: locked);
  }

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
