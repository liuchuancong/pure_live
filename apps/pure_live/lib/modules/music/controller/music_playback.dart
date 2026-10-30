import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:convert' show Utf8Decoder, jsonDecode, jsonEncode, latin1;
import 'dart:io' show File;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core/media_core.dart' show PlayerAudioDevice, PlayerConfig;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:media_core_mpv_audio/media_core_mpv_audio.dart'
    show
        Device,
        FftFrame,
        MediaAction,
        MediaSession,
        MediaSessionArtwork,
        MediaSessionCommandNext,
        MediaSessionCommandPrevious,
        MpvAudioPlayerAdapter,
        kMpvAudioBackendId;
import 'package:pure_live/app/app.dart' show playerKernelProvider;
import 'package:pure_live/modules/music/controller/eq/music_eq_config.dart'
    show MusicEqConfig, musicEqApplyFailedProvider, musicEqProvider;
import 'package:pure_live/modules/music/controller/eq/music_eq_engine_effects.dart'
    show musicEqAudioEffects, musicEqPitchRate;
import 'package:pure_live/modules/music/controller/music_dislikes.dart' show musicDislikesProvider;
import 'package:pure_live/modules/music/controller/music_library.dart'
    show musicRecentProvider, musicTrackFromJson, musicTrackKey, musicTrackToJson;
import 'package:pure_live/modules/music/controller/music_lyric_overrides.dart' show musicLyricOverridesProvider;
import 'package:pure_live/modules/music/controller/music_settings.dart'
    show MusicQuality, MusicSettings, musicSettingsProvider;
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceListProvider, musicSourceProvider;

/// The preference the last queue is kept under, so 打开时继续播放 has
/// something to resume.
const String kMusicQueueKey = 'music.queue';

/// The preference the chosen audio output device is kept under — an mpv
/// `audio-device` name, replayed onto every new engine instance.
const String kMusicAudioDeviceKey = 'music.play.audioDevice';

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

/// The preference the per-song playback positions are kept under.
const String kMusicProgressKey = 'music.playback.positions';

/// How many songs keep a resume position; the oldest falls off first.
const int kMusicProgressLimit = 200;

/// Where each song stopped, keyed by `sourceId:id` in milliseconds.
final class MusicProgressStore {
  /// The store.
  const MusicProgressStore();

  /// The stored positions; an unreadable store answers empty.
  Map<String, int> read() {
    try {
      final raw = StoragePrefs.getString(kMusicProgressKey);
      if (raw == null || raw.isEmpty) return const <String, int>{};
      final json = jsonDecode(raw);
      if (json is! Map) return const <String, int>{};
      return <String, int>{
        for (final entry in json.entries)
          if (entry.key is String && entry.value is num) entry.key as String: (entry.value as num).toInt(),
      };
    } on Object {
      return const <String, int>{};
    }
  }

  /// Keeps [positions] for the next run.
  Future<void> write(Map<String, int> positions) async {
    try {
      await StoragePrefs.setString(kMusicProgressKey, jsonEncode(positions));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The resume positions' storage.
final musicProgressStoreProvider = Provider<MusicProgressStore>((ref) => const MusicProgressStore());

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
/// module's seam — one queue for the window that owns it, the recently played
/// list fed from it, and the last queue kept for the next run. `AppWindowRoot`
/// scopes it to the window because it holds a kernel: the controller outlives
/// the pages that watch it, so closing the player page keeps the song playing,
/// and closing the window ends it — as it does for a room.
final class MusicPlayerController extends Notifier<audio.AudioPlaybackState> {
  late final audio.AudioPlaybackController _audio;
  late final MusicProgressStore _progressStore;
  StreamSubscription<audio.AudioPlaybackState>? _states;
  audio.DesktopLyricController? _desktopLyric;
  StreamSubscription<bool>? _desktopVisibleChanges;
  StreamSubscription<bool>? _desktopLockChanges;
  audio.MusicBackgroundBinding? _background;
  String? _recentTrack;
  String? _savedTrack;
  int _savedLength = -1;
  bool _askedNotifications = false;
  Map<String, int> _positions = const <String, int>{};
  String? _progressTrackKey;
  String? _restoredProgressKey;
  int _progressPositionMs = 0;
  DateTime _lastProgressWrite = DateTime.fromMillisecondsSinceEpoch(0);
  String? _dislikedSkipKey;
  int _dislikedSkips = 0;
  String? _erroredSkipKey;
  int _erroredSkips = 0;
  String? _lyricOverrideKey;
  String? _sessionTrackKey;
  bool _engineSessionBound = false;
  MpvAudioPlayerAdapter? _sessionAdapter;

  @override
  audio.AudioPlaybackState build() {
    // The kernel is read, not watched: rebuilding this controller would throw
    // its queue away, and a kernel that changes belongs to a new window.
    final settings = ref.read(musicSettingsProvider);
    _progressStore = ref.read(musicProgressStoreProvider);
    _positions = _progressStore.read();
    _audio = audio.AudioPlaybackController(
      ref.read(playerKernelProvider),
      // The local source is registered for its sidecar lyric reader: a local
      // track resolves through its file path, but its `.lrc` is asked here.
      registry: audio.MusicSourceRegistry([
        ...ref.read(musicSourceListProvider),
        audio.LocalMusicSource(roots: const []),
      ]),
      config: audio.AudioPlaybackConfig(
        initialQuality: musicQualityOf(settings.quality),
        // The music engine is the audio-only mpv_audio backend: its patched
        // libmpv carries the audio filters the stock build lacks, plus the
        // PCM/FFT taps and the typed effects chain the module rides.
        backendId: kMpvAudioBackendId,
      ),
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
    ref.listen(musicSettingsProvider.select((settings) => settings.preservesPitch), (_, preservesPitch) {
      _applyPitchCorrection(preservesPitch);
    });
    ref.listen(
      musicSettingsProvider.select(
        (settings) => (settings.showTranslation, settings.showRomanization, settings.swapLyricSecondary),
      ),
      (_, display) {
        unawaited(
          _desktopLyric?.setDisplayOptions(
                audio.LyricDisplayOptions(
                  showTranslation: display.$1,
                  showRomanization: display.$2,
                  swapTranslationAndRomanization: display.$3,
                ),
              ) ??
              Future<void>.value(),
        );
      },
    );
    ref.listen(
      musicSettingsProvider.select(
        (settings) => (
          settings.desktopLyricFontSize,
          settings.desktopLyricOpacity,
          settings.desktopLyricTextColor,
          settings.desktopLyricAlignment,
          settings.desktopLyricStrokeColor,
          settings.desktopLyricStrokeWidth,
          settings.desktopLyricLocked,
          settings.desktopLyricLineGap,
          settings.desktopLyricBoldLine,
          settings.desktopLyricBoldExtended,
          settings.desktopLyricVertical,
        ),
      ),
      (previous, next) {
        final desktop = _desktopLyric;
        if (desktop == null) return;
        final restyled =
            previous != null &&
            (previous.$1 != next.$1 ||
                previous.$2 != next.$2 ||
                previous.$3 != next.$3 ||
                previous.$4 != next.$4 ||
                previous.$5 != next.$5 ||
                previous.$6 != next.$6 ||
                previous.$8 != next.$8 ||
                previous.$9 != next.$9 ||
                previous.$10 != next.$10);
        if (restyled) {
          final settings = ref.read(musicSettingsProvider);
          unawaited(desktop.setStyle(_desktopStyle(settings)));
        }
        if (previous == null || previous.$7 != next.$7) {
          unawaited(desktop.setLocked(locked: next.$7));
        }
      },
    );
    ref.listen(musicEqProvider, (_, eq) {
      _applyEq(eq);
    });
    _states = _audio.stateStream.listen((next) {
      if (!ref.mounted) return;
      state = next;
      _follow(next);
      _trackProgress(next);
      _skipDislikedIfNeeded(next);
      _skipErroredIfNeeded(next);
      // A rebuilt engine is a new world: the chain, the pitch correction,
      // the device choice and the session commands were bound to the old
      // adapter, and a same-track rebuild would otherwise publish nothing.
      final adapterNow = _engineAdapter;
      if (!identical(adapterNow, _sessionAdapter)) {
        _sessionAdapter = adapterNow;
        _engineSessionBound = false;
        _sessionTrackKey = null;
        _eqPending = true;
        _pitchPending = true;
        _devicePending = true;
      }
      // The engine handle appears with the first track; a sound effect chosen
      // before that waited for exactly this moment.
      if (_eqPending && next.track != null) {
        _eqPending = false;
        _applyEq(ref.read(musicEqProvider));
      }
      if (_pitchPending && next.track != null) {
        _pitchPending = false;
        _applyPitchCorrection(ref.read(musicSettingsProvider).preservesPitch);
      }
      if (_devicePending && next.track != null) {
        _devicePending = false;
        _applyAudioDevice();
      }
      _publishEngineSession(next);
      // Android 13+ hides the media notification without this permission; ask
      // when the viewer actually starts a song, not on some unrelated page.
      if (next.playing && !_askedNotifications) {
        _askedNotifications = true;
        unawaited(audio.AudioPermissionService().request(audio.AudioPermission.notifications));
      }
    });
    ref.onDispose(() {
      _eqDebounce?.cancel();
      _flushProgress();
      unawaited(_states?.cancel() ?? Future<void>.value());
      unawaited(_desktopVisibleChanges?.cancel() ?? Future<void>.value());
      unawaited(_desktopLockChanges?.cancel() ?? Future<void>.value());
      _background?.detach();
      unawaited(_desktopLyric?.dispose() ?? Future<void>.value());
      unawaited(_audio.dispose());
    });
    unawaited(_restorePlaybackPrefs());
    // The chain waits for the first engine handle when boot landed before one;
    // when a handle already exists this applies straight away.
    _applyEq(ref.read(musicEqProvider));
    _applyPitchCorrection(ref.read(musicSettingsProvider).preservesPitch);
    _applyAudioDevice();
    unawaited(_restore());
    unawaited(_restoreDesktopLyric());
    return _audio.state;
  }

  /// The engine behind this controller, for consumers that need a raw
  /// stream the state model does not carry (the loudness meter).
  audio.AudioPlaybackController get audioEngine => _audio;

  /// The engine's FFT taps — ~32 frames a second of raw bins and smoothed
  /// log-spaced bands, the spectrum UI's data source. Null before the first
  /// track creates the engine (or on a backend without taps); the stream is
  /// the engine's own broadcast, so a late listener loses nothing but time.
  Stream<FftFrame>? get spectrum => _engineAdapter?.player?.stream.fft;

  /// Mirrors the player onto the OS surface once a driver exists.
  void _attachBackground(audio.MediaSessionDriver session) {
    _background ??= audio.MusicBackgroundBinding(_audio, session)..attach();
  }

  /// Publishes the playing track onto the engine's own media session.
  ///
  /// The mpv_audio engine carries a first-class session: playback state,
  /// position and the play/pause verdict are the engine's own, so nothing
  /// here can drift from the sound. The queue stays app-side, which is why
  /// autoApplyPlaylistNavigation is off — the OS's next and
  /// previous come back through MediaSessionCommandNext/MediaSessionCommandPrevious
  /// and drive the app's queue.
  ///
  /// The first publish releases the app-wide arbitration binding: two
  /// owners would draw two SMTC cards, and the engine's is the truthful one.
  void _publishEngineSession(audio.AudioPlaybackState next) {
    final engine = _engineAdapter?.player;
    final track = next.track;
    if (engine == null || track == null) return;
    final key = musicTrackKey(track);
    if (key == _sessionTrackKey) return;
    _sessionTrackKey = key;

    _background?.detach();
    _background = null;
    _bindEngineSessionCommands(_engineAdapter!);

    final coverUri = track.coverUri;
    unawaited(
      engine.setMediaSession(
        MediaSession(
          title: track.title,
          artist: track.artist.isEmpty ? null : track.artist,
          album: track.album.isEmpty ? null : track.album,
          // A network cover is handed to the engine as a URI — it downloads
          // it in Dart (certificates verified) before it reaches the OS; no
          // cover falls back to the file's embedded art.
          artwork: coverUri == null ? MediaSessionArtwork.embedded : MediaSessionArtwork.uri(coverUri),
          duration: next.duration > Duration.zero ? next.duration : null,
          // The queue is the app's, not the engine playlist's: the OS's next
          // and previous only emit on the command stream (nothing to drive
          // with a single loaded track), so they are the queue's to take.
          autoApplyPlaylistNavigation: false,
          // What the SMTC card labels the controls with — the README's app
          // identity step; on Windows the icon itself comes from the exe.
          appName: 'Pure Live',
          actions: const <MediaAction>{
            MediaAction.play,
            MediaAction.pause,
            MediaAction.stop,
            MediaAction.next,
            MediaAction.previous,
            MediaAction.seek,
          },
        ),
      ),
    );
  }

  /// Routes the OS media commands the engine cannot satisfy itself.
  ///
  /// Per the README the player applies OS commands on its own — play, pause,
  /// seek and stop reach the engine directly and only mirror here. The two
  /// it cannot apply are the queue navigations: with `autoApplyPlaylistNavigation`
  /// off and a single track loaded, next and previous merely emit, and the
  /// app's queue is the only thing that knows what they mean. Once per engine
  /// instance, because the subscription outlives tracks.
  void _bindEngineSessionCommands(MpvAudioPlayerAdapter adapter) {
    if (_engineSessionBound) return;
    _engineSessionBound = true;
    final engine = adapter.player;
    if (engine == null) return;
    engine.stream.mediaSessionCommands.listen((command) {
      if (!ref.mounted) return;
      if (command is MediaSessionCommandNext) {
        unawaited(next());
      } else if (command is MediaSessionCommandPrevious) {
        unawaited(previous());
      }
    });
  }



  /// The overlay style the preferences describe.
  static audio.DesktopLyricStyle _desktopStyle(MusicSettings settings) => audio.DesktopLyricStyle(
    fontSize: settings.desktopLyricFontSize,
    opacity: settings.desktopLyricOpacity,
    textColor: settings.desktopLyricTextColor,
    strokeColor: settings.desktopLyricStrokeColor,
    strokeWidth: settings.desktopLyricStrokeWidth,
    lineGap: settings.desktopLyricLineGap.toDouble(),
    boldLine: settings.desktopLyricBoldLine,
    boldExtended: settings.desktopLyricBoldExtended,
    vertical: settings.desktopLyricVertical,
    alignment: settings.desktopLyricAlignment,
  );

  /// Sends the sound-effect chain to this instance's engine.
  ///
  /// The chain rides the `af` list option as one `lavfi=[…]` entry — the
  /// adapter replaces the list entry-by-entry, which is the only way a
  /// comma-heavy graph survives. The handle remembers applied options and
  /// replays them if the engine rebuilds, so the effect survives a backend
  /// swap without this controller's help. A chain change never interrupts
  /// the playing song: `af` applies on the live instance.
  bool _eqPending = false;
  Timer? _eqDebounce;

  /// The mpv_audio engine behind the current handle, when there is one.
  /// The handle-layer seams (`applyEngineOptions`, `listAudioDevices`)
  /// speak the generic dialect; the effects chain, the pitch control, the
  /// device picker and the FFT taps are the engine's own, reached here.
  MpvAudioPlayerAdapter? get _engineAdapter {
    final adapter = _audio.handle?.adapter;
    return adapter is MpvAudioPlayerAdapter ? adapter : null;
  }

  void _applyEq(MusicEqConfig eq, {bool immediate = false}) {
    // While the A/B button is held, nothing but the bypass itself writes
    // the chain — a slider drag during the hold must not leak into the
    // comparison.
    if (_compareBypass) return;
    final handle = _audio.handle;
    if (handle == null) {
      // No engine yet; the next track's first state reapplies.
      _eqPending = true;
      return;
    }
    // A slider drag arrives as a burst of states; only the settled value
    // reaches mpv, so the filter chain is not rebuilt per pixel.
    if (!immediate) {
      _eqDebounce?.cancel();
      _eqDebounce = Timer(const Duration(milliseconds: 250), () => _applyEq(eq, immediate: true));
      return;
    }
    final engine = _engineAdapter?.player;
    if (engine == null) {
      // An engine that is not the mpv_audio backend has no typed chain;
      // the page is told instead of the switch sitting on over plain sound.
      if (ref.mounted) ref.read(musicEqApplyFailedProvider.notifier).state = true;
      return;
    }
    unawaited(
      engine.setAudioEffects(musicEqAudioEffects(eq)).then<void>((_) async {
        if (!ref.mounted) return;
        // The chain took; the preamp rides the engine's native gain.
        ref.read(musicEqApplyFailedProvider.notifier).state = false;
        // Zeroed when the chain is off: the A/B bypass must lift the
        // preamp with the chain, or the comparison hears a lifted original.
        await engine.setVolumeGain(eq.enabled ? eq.preampDb : 0);
      }).catchError((Object _) {
        if (ref.mounted) ref.read(musicEqApplyFailedProvider.notifier).state = true;
      }),
    );
    // The pitch node is the engine's first-class control, not a filter.
    unawaited(engine.setPitch(musicEqPitchRate(eq)).catchError((Object _) {}));
  }

  /// Sends the pitch-compensation choice to this instance's engine — the
  /// reference's `audio.preservesPitch`, which mpv spells
  /// `audio-pitch-correction`: on, a changed speed stretches time and keeps
  /// the pitch; off, it behaves like a tape deck and the pitch follows.
  /// Like the effect chain, the handle replays the option if the engine
  /// rebuilds.
  bool _pitchPending = false;

  /// Re-applies the stored output device onto a new engine instance; a choice
  /// made before the first track waits for the handle like the others.
  bool _devicePending = false;

  void _applyAudioDevice() {
    final stored = StoragePrefs.getString(kMusicAudioDeviceKey);
    if (stored == null || stored.isEmpty) return;
    final engine = _engineAdapter?.player;
    if (engine == null) {
      _devicePending = true;
      return;
    }
    unawaited(
      engine.setAudioDevice(Device(name: stored, description: '')).catchError((Object _) {
        // An engine without the device keeps its own default.
      }),
    );
  }

  /// The engine's audio output devices, current one marked; empty when this
  /// backend has no device picker.
  Future<List<PlayerAudioDevice>> audioDevices() async {
    final engine = _engineAdapter?.player;
    if (engine == null) return const <PlayerAudioDevice>[];
    return <PlayerAudioDevice>[
      for (final device in engine.state.audioDevices)
        PlayerAudioDevice(name: device.name, description: device.description, selected: device.name == engine.state.audioDevice.name),
    ];
  }

  /// Sends the sound to [name] — an mpv `audio-device` value straight from
  /// [PlayerAudioDevice.name] — and remembers the choice for the next boot.
  Future<void> selectAudioDevice(String name) async {
    final engine = _engineAdapter?.player;
    if (engine == null) return;
    await StoragePrefs.setString(kMusicAudioDeviceKey, name);
    try {
      await engine.setAudioDevice(Device(name: name, description: ''));
    } on Object {
      // The choice is stored; the engine that refused keeps its default.
    }
  }

  void _applyPitchCorrection(bool preservesPitch) {
    final engine = _engineAdapter?.player;
    if (engine == null) {
      _pitchPending = true;
      return;
    }
    unawaited(
      engine.setPitchCorrection(preservesPitch).catchError((Object _) {
        // An engine without the control just keeps its own behaviour.
      }),
    );
  }

  /// While the A/B compare button is held, the whole chain steps aside so
  /// the listener hears the untouched mix; release restores the settled
  /// configuration immediately (no debounce — the ear compares best when
  /// the switch back is instant).
  bool _compareBypass = false;

  void setCompareBypass({required bool bypass}) {
    if (_compareBypass == bypass) return;

    // A held bypass cancels a queued apply, and a queued apply that lands
    // while the button is held must not wipe the bypass. Order matters:
    // the chain is pushed while the flag still lets it through, then the
    // flag swallows everything else until release.
    if (bypass) {
      final eq = ref.read(musicEqProvider);
      _applyEq(eq.copyWith(enabled: false, analysis: false), immediate: true);
      _compareBypass = true;
      _eqDebounce?.cancel();
    } else {
      _compareBypass = false;
      _applyEq(ref.read(musicEqProvider), immediate: true);
    }
  }

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
    if (settings.swapLyricSecondary) {
      unawaited(
        desktop.setDisplayOptions(
          audio.LyricDisplayOptions(
            showTranslation: settings.showTranslation,
            showRomanization: settings.showRomanization,
            swapTranslationAndRomanization: true,
          ),
        ),
      );
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
  ///
  /// Replaying the list already in the queue keeps the random pool unless the
  /// auto-clean setting asks for a clear — the reference's
  /// `if (isAutoCleanPlayedList || prevListId != listId) clearPlayedList()`.
  Future<void> playAll(Iterable<audio.MusicTrack> tracks, {int index = 0}) async {
    final incoming = List<audio.MusicTrack>.of(tracks);

    if (incoming.isNotEmpty && _sameQueue(incoming)) {
      await _pick(index.clamp(0, incoming.length - 1));
      return;
    }

    await _audio.setQueue(incoming, startIndex: index);
  }

  /// Plays [track], adding it to the queue when it is not there yet.
  Future<void> play(audio.MusicTrack track) async {
    final existing = _audio.queue.indexOfTrack(track);

    if (existing >= 0) {
      await _pick(existing);
      return;
    }

    await _audio.playTrack(track);
  }

  /// Plays the queue entry at [index].
  Future<void> playAt(int index) => _pick(index);

  /// Picks an in-queue entry, applying the played-list rule: with the
  /// auto-clean setting on, random mode rebuilds the shuffle so every song
  /// re-enters the pool — the reference's clearPlayedList on same-list picks.
  Future<void> _pick(int index) async {
    final settings = ref.read(musicSettingsProvider);

    if (settings.autoCleanPlayedList && _audio.queue.mode == audio.PlayMode.random) {
      await _audio.setQueue(_audio.queue.tracks, startIndex: index);
      return;
    }

    await _audio.playAt(index);
  }

  /// Whether [tracks] is the queue already in place (same songs, same order).
  bool _sameQueue(List<audio.MusicTrack> tracks) {
    final current = _audio.queue.tracks;

    if (current.length != tracks.length) {
      return false;
    }

    for (var i = 0; i < current.length; i++) {
      if (current[i] != tracks[i]) {
        return false;
      }
    }

    return true;
  }

  /// Puts [track] right after the current one.
  Future<void> playNext(audio.MusicTrack track) => _audio.playTrack(track, insertNext: true);

  Future<void> toggle() => _audio.toggle();

  Future<void> next() => _audio.next();

  Future<void> previous() => _audio.previous();

  Future<void> seek(Duration position) => _audio.seek(position);

  Future<void> setVolume(double volume) async {
    await _audio.setVolume(volume);
    await ref.read(musicSettingsProvider.notifier).setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> setMuted({required bool muted}) => _audio.setMute(muted: muted);

  Future<void> setRate(double rate) async {
    await _audio.setRate(rate);
    await ref.read(musicSettingsProvider.notifier).setPlaybackRate(rate);
  }

  /// Starts, replaces or clears the sleep timer.
  void setSleepTimer(Duration? duration) => _audio.setSleepTimer(duration);

  /// Pauses when the current song ends — the reference's
  /// 定时停止「播完当前歌曲」; one-shot, and replaces a timed sleep timer.
  void setPauseAfterCurrentTrack({required bool enabled}) => _audio.setPauseAfterCurrentTrack(enabled: enabled);

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

  /// Points [track] at the lyric file at [path], remembering the text so the
  /// association survives a restart; false when the file is unreadable or has
  /// no lyric in it.
  Future<bool> associateLyricFile(audio.MusicTrack track, String path) async {
    try {
      return await _applyLyricText(track, _decodeLyricText(await File(path).readAsBytes()));
    } on Object {
      return false;
    }
  }

  /// Searches the module's source for songs matching [keyword], so a viewer
  /// can pick the lyric of the right recording.
  Future<List<audio.MusicTrack>> searchLyricCandidates(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) return const [];
    final page = await ref.read(musicSourceProvider).search(query, pageSize: 20);
    return page.items;
  }

  /// Uses [candidate]'s lyric for [track] — the song on screen — remembering
  /// it the way a manually linked file is; false when it has no lyric.
  Future<bool> useLyricFrom(audio.MusicTrack track, audio.MusicTrack candidate) async {
    try {
      final payload = await ref.read(musicSourceProvider).resolveLyric(candidate);
      if (payload == null) return false;
      final translation = payload.translation?.trim() ?? '';
      final text = [payload.lyric, if (translation.isNotEmpty) translation].join('\n');
      return await _applyLyricText(track, text);
    } on Object {
      return false;
    }
  }

  /// Stores [text] as [track]'s lyric and hands the parsed document to the
  /// engine; false when the text has no lyric in it.
  Future<bool> _applyLyricText(audio.MusicTrack track, String text) async {
    if (text.trim().isEmpty) return false;
    await ref.read(musicLyricOverridesProvider.notifier).set(track, text);
    _lyricOverrideKey = musicTrackKey(track);
    _audio.setLyricOverride(track, const audio.LrcParser().parse(text));
    return true;
  }

  /// Returns [track] to its source's lyric, dropping the association.
  Future<void> clearLyricOverride(audio.MusicTrack track) async {
    await ref.read(musicLyricOverridesProvider.notifier).remove(track);
    _audio.setLyricOverride(track, null);
  }

  static String _decodeLyricText(List<int> bytes) {
    var start = 0;

    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      start = 3;
    }

    final body = start == 0 ? bytes : bytes.sublist(start);

    try {
      return const Utf8Decoder().convert(body);
    } on FormatException {
      return latin1.decode(body);
    }
  }

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
    if (track != null) _applyLyricOverride(track);
  }

  /// Hands the engine the lyric the viewer associated with [track], once per
  /// track change; the parse is cheap and the engine keeps it by identity.
  void _applyLyricOverride(audio.MusicTrack track) {
    final key = musicTrackKey(track);
    if (key == _lyricOverrideKey) return;
    _lyricOverrideKey = key;
    final text = ref.read(musicLyricOverridesProvider)[key];
    if (text == null) return;
    _audio.setLyricOverride(track, const audio.LrcParser().parse(text));
  }

  Future<void> _saveQueue() async {
    await ref.read(musicQueueStoreProvider).write(_audio.queue.tracks, _audio.queue.index);
  }

  /// Below this a stop is "the song was just opened", not a place to resume.
  static const int _minResumeMs = 5000;

  /// How close to the end counts as "played through", so the next open starts
  /// at the beginning instead of a second before the fade-out.
  static const int _resumeTailMs = 5000;

  /// How often a running position is written; a seek or pause writes at once.
  static const Duration _progressWriteInterval = Duration(seconds: 10);

  /// Restores a song's last position on first play, and remembers where the
  /// current one stopped. Mirrors the reference's 记住播放进度.
  void _trackProgress(audio.AudioPlaybackState next) {
    final track = next.track;
    if (track == null) return;
    if (!ref.read(musicSettingsProvider).rememberProgress) {
      _progressTrackKey = null;
      return;
    }
    final key = musicTrackKey(track);
    if (key != _progressTrackKey) {
      _flushProgress();
      _progressTrackKey = key;
      _progressPositionMs = 0;
    }
    final durationMs = next.duration.inMilliseconds;
    final positionMs = next.position.inMilliseconds;

    // Wait for a real duration: it is what tells a saved position from a
    // stale one that now points past the end.
    if (key != _restoredProgressKey && next.playing && durationMs > 0) {
      _restoredProgressKey = key;
      final saved = _positions[key];
      if (saved != null && saved >= _minResumeMs && saved <= durationMs - _resumeTailMs) {
        unawaited(_audio.seek(Duration(milliseconds: saved)));
      }
    }

    if (positionMs <= 0) return;

    if (durationMs > 0 && positionMs >= durationMs - _resumeTailMs) {
      // Played through: there is nothing to resume next time.
      if (_positions.containsKey(key)) {
        final positions = Map<String, int>.of(_positions)..remove(key);
        _persistPositions(positions);
      }
      _progressPositionMs = 0;
      return;
    }

    _progressPositionMs = positionMs;

    if (!next.playing || DateTime.now().difference(_lastProgressWrite) >= _progressWriteInterval) {
      _flushProgress();
    }
  }

  /// Writes the current song's position into the map, keeping it bounded and
  /// most-recently-used last.
  void _flushProgress() {
    final key = _progressTrackKey;
    _lastProgressWrite = DateTime.now();
    if (key == null || _progressPositionMs < _minResumeMs) return;
    if (_positions[key] == _progressPositionMs) return;
    final positions = Map<String, int>.of(_positions)
      ..remove(key)
      ..[key] = _progressPositionMs;
    while (positions.length > kMusicProgressLimit) {
      positions.remove(positions.keys.first);
    }
    _persistPositions(positions);
  }

  void _persistPositions(Map<String, int> positions) {
    _positions = positions;
    unawaited(_progressStore.write(positions));
  }

  /// Adds or removes a 不喜欢 rule; a song that just became disliked while it
  /// is on air is skipped at once.
  Future<bool> toggleDislike(audio.MusicTrack track) async {
    final disliked = await ref.read(musicDislikesProvider.notifier).toggle(track);

    if (disliked && state.track == track) {
      await _audio.next();
    }

    return disliked;
  }

  /// Skips a disliked song the queue reached.
  ///
  /// Bounded by the queue length: a queue holding nothing but rules stops
  /// instead of spinning forever, which is what a "skip everything" loop
  /// would look like from the outside.
  void _skipDislikedIfNeeded(audio.AudioPlaybackState next) {
    final track = next.track;

    if (!next.playing || track == null) {
      _dislikedSkipKey = null;
      _dislikedSkips = 0;

      return;
    }

    if (!ref.read(musicDislikesProvider).contains(musicTrackKey(track))) {
      _dislikedSkipKey = null;
      _dislikedSkips = 0;

      return;
    }

    final key = musicTrackKey(track);

    if (_dislikedSkipKey == key) {
      return;
    }

    _dislikedSkipKey = key;
    _dislikedSkips++;

    if (next.queueLength > 0 && _dislikedSkips > next.queueLength) {
      _dislikedSkips = 0;
      unawaited(_audio.stop());

      return;
    }

    unawaited(_audio.next());
  }

  /// Moves past a song the engine could not play, when the viewer asked for
  /// it — lx-music's 自动跳过播放失败的歌曲.
  ///
  /// The engine already refreshed the URL once before reporting; a second
  /// failure means the song is unusable this session. Bounded by the queue
  /// length, so a queue where nothing plays stops instead of looping.
  void _skipErroredIfNeeded(audio.AudioPlaybackState next) {
    final track = next.track;

    if (next.error == null || track == null) {
      _erroredSkipKey = null;
      _erroredSkips = 0;

      return;
    }

    if (!ref.read(musicSettingsProvider).skipOnError) {
      return;
    }

    final key = musicTrackKey(track);

    // A disliked song is already being skipped by its own rule; advancing
    // twice would lose the song after it.
    if (ref.read(musicDislikesProvider).contains(key)) {
      return;
    }

    if (_erroredSkipKey == key) {
      return;
    }

    _erroredSkipKey = key;
    _erroredSkips++;

    if (next.queueLength > 0 && _erroredSkips > next.queueLength) {
      _erroredSkips = 0;
      unawaited(_audio.stop());

      return;
    }

    unawaited(_audio.next());
  }

  /// Reopens the last queue when the viewer asked the module to continue;
  /// restored paused, because opening a page is not pressing play.
  /// Restores the viewer's volume and speed before any queue loads — the
  /// reference persists both across runs (`volume.ts`, `playbackRate.ts`).
  Future<void> _restorePlaybackPrefs() async {
    final settings = ref.read(musicSettingsProvider);
    if (settings.volume != 1) await _audio.setVolume(settings.volume);
    if (settings.playbackRate != 1) await _audio.setRate(settings.playbackRate);
  }

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

/// The active engine's audio output devices; invalidate after a selection or
/// a device plug event to re-read.
final FutureProvider<List<PlayerAudioDevice>> musicAudioDevicesProvider = FutureProvider.autoDispose<List<PlayerAudioDevice>>(
  (ref) => ref.read(musicPlayerProvider.notifier).audioDevices(),
);
