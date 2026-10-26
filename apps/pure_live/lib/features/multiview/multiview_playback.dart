import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_live/media_core_live.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/favorites/favorites.dart';
import 'package:pure_live/features/multiview/multiview_controller.dart' show multiviewProvider;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/shared/shared.dart';

/// Where one pane's session stands.
enum MultiviewPaneStage {
  /// The room is being resolved and its first stream opened.
  opening,

  /// An engine is attached and the picture is in the tree.
  playing,

  /// The room or its stream could not be opened.
  failed,
}

/// One pane's playback as the page reads it: the room, the engine's handle
/// (what `MediaPlayerView` draws), the site's quality and line catalogue
/// behind it, the transport facts the controls read, and where the session
/// stands.
typedef MultiviewPanePlayback = ({
  int slot,
  String identity,
  LiveRoom? room,
  MultiviewPaneStage stage,
  PlayerHandle? handle,
  String? error,
  List<LivePlayQuality> qualities,
  LivePlayQuality? quality,
  bool switching,
  List<LivePlayLine> lines,
  int lineIndex,
  bool paused,
  double volume,
  bool audible,
});

/// The wall's sessions: one playback per assigned pane, the pane that owns
/// the sound, whether every pane is muted, and whether the wall is on screen.
typedef MultiviewPlaybackState = ({bool active, bool allMuted, int? selected, Map<int, MultiviewPanePlayback> panes});

/// The walls' playback owner.
///
/// One `LivePlaybackController` per assigned pane, all over the room's own
/// site lines; every pane plays, and only the selected one is unmuted. Each
/// pane keeps its own quality, line and volume: the selected pane's controls
/// switch them, the wall-level switches mute or pause every pane at once.
/// The page says when it is on screen: leaving it releases every engine (a
/// branch keeps its widgets, so disposal alone would not), coming back opens
/// the wall's rooms again. The arrangement itself stays in
/// [multiviewProvider]; this controller only follows it.
final class MultiviewPlaybackController extends Notifier<MultiviewPlaybackState> {
  final List<_PaneSession> _sessions = [];
  bool _active = false;
  bool _allMuted = false;
  bool _globalMuted = false;
  int? _selected;

  @override
  MultiviewPlaybackState build() {
    _globalMuted = ref.read(playbackSettingsProvider).globalMute;
    ref.listen(playbackSettingsProvider.select((settings) => settings.globalMute), (previous, next) {
      if (previous == next) return;
      _globalMuted = next;
      if (_active) _applyFocus();
      _publish();
    });
    ref.listen(playerProxyProvider, (previous, next) {
      if (previous == next) return;
      _applyStoredEngineOptions();
    });
    ref.listen(playbackSettingsProvider.select((settings) => settings.hardwareDecoding), (previous, next) {
      if (previous == next) return;
      _applyStoredEngineOptions();
    });
    ref.listen(playerTuningProvider, (previous, next) {
      if (previous == next) return;
      unawaited(_applyTuning(previous, next));
    });
    ref.listen(superResolutionModeProvider, (previous, next) {
      if (previous == next) return;
      for (final session in _sessions) {
        final handle = session.handle;
        if (handle != null) unawaited(applySuperResolution(handle, next));
      }
    });
    ref.listen(multiviewProvider, (previous, next) {
      if (_active) _sync();
    });
    ref.listen(followsProvider.select((state) => state.rooms), (previous, next) {
      if (_active) _sync();
    });
    ref.onDispose(_releaseAll);
    return (active: false, allMuted: false, selected: null, panes: const {});
  }

  /// Tells the wall whether it is on screen; leaving releases every engine,
  /// returning opens the rooms again. The mute-all switch is a visit's
  /// choice, so a return starts with sound.
  void setActive({required bool active}) {
    if (_active == active) return;
    _active = active;
    if (active) {
      _sync();
      return;
    }
    _releaseAll();
    _allMuted = false;
    _publish();
  }

  /// Picks the pane whose sound plays; every other pane is muted.
  void select(int slot) {
    if (_selected == slot) return;
    if (!_sessions.any((session) => session.slot == slot)) return;
    _selected = slot;
    _applyFocus();
    _publish();
  }

  /// Opens [slot] again after a failure, at the volume the pane held.
  Future<void> retry(int slot) async {
    final session = _sessionOf(slot);
    if (session == null) return;
    final room = session.room;
    final identity = session.identity;
    final volume = session.volume;
    _release(session);
    if (!_active) return;
    final fresh = _PaneSession(slot: slot, identity: identity, volume: volume)..room = room;
    _sessions.add(fresh);
    _ensureSelection();
    _publish();
    await _open(fresh, room);
  }

  /// Plays [quality] in [slot], refetching that quality's plan; the old
  /// stream keeps playing until the new lines resolve. False when the new
  /// quality could not be read — the pane keeps its current stream.
  Future<bool> selectQuality(int slot, LivePlayQuality quality) async {
    final session = _sessionOf(slot);
    if (session == null) return true;
    if (session.switching || session.quality == quality || session.stage != MultiviewPaneStage.playing) {
      return true;
    }
    final playback = session.playback;
    if (playback == null) return true;
    final epoch = ++session.epoch;
    session.switching = true;
    _publish();
    try {
      final lines = await _linesOf(session, quality);
      if (session.disposed || epoch != session.epoch) return true;
      if (lines.isEmpty) return false;
      session
        ..quality = quality
        ..lines = lines
        ..lineIndex = 0
        ..paused = false;
      await playback.play(
        LiveSourceRequest(
          sources: roomSourcesOf(lines),
          title: session.room?.content.title ?? '',
          allowEngineFallback: true,
          engineOptions: await _engineOptions(),
        ),
        preferredBackend: ref.read(playerKernelBackendProvider).id,
      );
      return true;
    } on Object {
      return false;
    } finally {
      if (!session.disposed && epoch == session.epoch) {
        session.switching = false;
        _publish();
      }
    }
  }

  /// Moves [slot] to line [index] of its current plan.
  Future<void> selectLine(int slot, int index) async {
    final session = _sessionOf(slot);
    final playback = session?.playback;
    if (session == null || playback == null) return;
    if (index < 0 || index >= session.lines.length || index == session.lineIndex) return;
    session.lineIndex = index;
    _publish();
    await playback.switchLine(index);
  }

  /// Pauses or resumes [slot].
  Future<void> togglePause(int slot) async {
    await _sessionOf(slot)?.playback?.togglePlayPause();
  }

  /// Pauses every playing pane, or resumes the panes it paused.
  Future<void> togglePauseAll() async {
    final playing = [
      for (final session in _sessions)
        if (session.stage == MultiviewPaneStage.playing && session.playback != null) session,
    ];
    if (playing.isEmpty) return;
    final pause = playing.any((session) => !session.paused);
    for (final session in playing) {
      if (pause && !session.paused) {
        await session.playback?.pause();
      } else if (!pause && session.paused) {
        await session.playback?.resume();
      }
    }
  }

  /// Silences every pane, or gives the selected pane its sound back.
  void toggleMuteAll() {
    _allMuted = !_allMuted;
    for (final session in _sessions) {
      unawaited(_applyAudio(session));
    }
    _publish();
  }

  /// Sets [slot]'s volume. While a slider moves ([commit] false) only the
  /// engine hears it, so the wall does not rebuild on every step.
  Future<void> setVolume(int slot, double volume, {bool commit = true}) async {
    final session = _sessionOf(slot);
    if (session == null) return;
    final value = volume.isFinite ? volume.clamp(0.0, 1.0) : 1.0;
    session.volume = value;
    final handle = session.handle;
    if (handle != null && _audible(session)) {
      try {
        await handle.setVolume(value);
      } on Object {
        // A pane the engine refused to change is not a playback failure.
      }
    }
    if (commit) _publish();
  }

  /// Follows the wall's slots and the follows: one session per assigned pane,
  /// unchanged panes keep their engine (a layout switch does not restart them).
  void _sync() {
    if (!_active) return;
    final wall = ref.read(multiviewProvider);
    if (!wall.ready) return;
    final followed = {for (final room in ref.read(followsProvider).rooms) room.ref.identityKey: room};
    for (final session in [..._sessions]) {
      if (session.slot >= wall.slots.length || wall.slots[session.slot] != session.identity) {
        _release(session);
      }
    }
    for (var slot = 0; slot < wall.slots.length; slot++) {
      final identity = wall.slots[slot];
      if (identity == null) continue;
      if (_sessions.any((session) => session.slot == slot)) continue;
      final volume = ref.read(playbackSettingsProvider.notifier).volume;
      final session = _PaneSession(slot: slot, identity: identity, volume: volume.clamp(0.0, 1.0));
      _sessions.add(session);
      unawaited(_open(session, followed[identity]));
    }
    _ensureSelection();
    _publish();
  }

  Future<void> _open(_PaneSession session, LiveRoom? known) async {
    final epoch = ++session.epoch;
    bool stale() => session.disposed || epoch != session.epoch;
    try {
      final room = known ?? await _roomOf(session.identity);
      if (stale()) return;
      session.room = room;
      final site = ref.read(sitesProvider).getById(room.ref.platform);
      final capability = site?.capability<LivePlaybackProvider>();
      if (capability == null) {
        _fail(session, 'the site has no playback capability');
        return;
      }
      session.capability = capability;
      final qualities = await capability
          .getQualities(room: room)
          .then((answer) => answer.fold((error) => throw _PaneOpenFailure(error.message), (qualities) => qualities));
      if (stale()) return;
      session.qualities = qualities;
      final quality = _pickQuality(qualities);
      final lines = await _linesOf(session, quality);
      if (stale()) return;
      if (lines.isEmpty) {
        _fail(session, 'the room has nothing to play');
        return;
      }
      session
        ..quality = quality
        ..lines = lines
        ..lineIndex = 0;
      final playback = createRoomPlayback(
        kernel: ref.read(playerKernelProvider),
        onLinesNeeded: () => _refreshLines(session),
      );
      session.playback = playback;
      _wire(session, playback);
      await playback.play(
        LiveSourceRequest(
          sources: roomSourcesOf(lines),
          title: room.content.title,
          allowEngineFallback: true,
          engineOptions: await _engineOptions(),
        ),
        preferredBackend: ref.read(playerKernelBackendProvider).id,
      );
    } on Object catch (error) {
      if (stale()) return;
      _fail(session, error is _PaneOpenFailure ? error.message : error.toString());
    }
  }

  /// The qualities' plan for [quality]; the site's own words when it fails.
  Future<List<LivePlayLine>> _linesOf(_PaneSession session, LivePlayQuality? quality) async {
    final room = session.room;
    final capability = session.capability;
    if (room == null || capability == null) throw const _PaneOpenFailure('the pane holds no room');
    final answer = await capability.getLines(room: room, quality: quality);
    final lines = answer.fold((error) => throw _PaneOpenFailure(error.message), (lines) => lines);
    return lines;
  }

  /// Fresh URLs for the plan the pane is on now; a recovery or an engine
  /// fallback calls back here, so a quality switch moves the seam with it.
  Future<List<LivePlayLine>> _refreshLines(_PaneSession session) async {
    try {
      return await _linesOf(session, session.quality);
    } on Object {
      return const [];
    }
  }

  void _wire(_PaneSession session, LivePlaybackController playback) {
    session.handles = playback.onHandleChanged.listen((handle) {
      if (session.disposed) return;
      session
        ..handle = handle
        ..stage = MultiviewPaneStage.playing
        ..error = null;
      unawaited(_applyAudio(session));
      unawaited(_applyEngineOptions(session));
      _publish();
    });
    session.states = playback.onStateChanged.listen((state) {
      if (session.disposed) return;
      session
        ..paused = state.playback == PlayerPlaybackState.paused
        ..lineIndex = playback.sourceIndex;
      _publish();
    });
    session.failures = playback.onError.listen((failure) {
      if (session.disposed) return;
      _fail(session, failure.message ?? failure.code.name);
    });
  }

  /// The room behind [identity], fetched from its site when the follows do
  /// not hold it (a pane keeps its room after an unfollow).
  Future<LiveRoom> _roomOf(String identity) async {
    final at = identity.indexOf(':');
    if (at < 0) throw const _PaneOpenFailure('the pane holds no room');
    final platform = identity.substring(0, at);
    final roomId = identity.substring(at + 1);
    final provider = ref.read(sitesProvider).getById(platform)?.capability<LiveRoomProvider>();
    if (provider == null) throw _PaneOpenFailure('no site for "$platform"');
    final answer = await provider.getRoom(roomId);
    final room = answer.fold((error) => throw _PaneOpenFailure(error.message), (room) => room);
    return room;
  }

  /// The viewer's preferred tier at an exact label, or the nearest tier by
  /// position when the room spells them differently.
  LivePlayQuality? _pickQuality(List<LivePlayQuality> qualities) {
    if (qualities.isEmpty) return null;
    final settings = ref.read(playbackSettingsProvider);
    final cellular = ref.read(networkTypeProvider.notifier).usesCellular;
    final index = preferredQualityIndex(
      qualities.map((quality) => quality.label),
      cellular ? settings.preferredQualityCellular : settings.preferredQuality,
    );
    return qualities[index];
  }

  /// Keeps the selection on a pane that still holds a room.
  void _ensureSelection() {
    final assigned = _sessions.map((session) => session.slot);
    if (_selected != null && assigned.contains(_selected)) return;
    _selected = _sessions.isEmpty ? null : _sessions.map((session) => session.slot).reduce((a, b) => a < b ? a : b);
    _applyFocus();
  }

  /// One pane's session by slot, or null when it holds no room.
  _PaneSession? _sessionOf(int slot) => _sessions.where((session) => session.slot == slot).firstOrNull;

  /// Whether [session]'s sound is the one on the wall: the selected pane's,
  /// unless every pane or the app-wide mute silences the wall.
  bool _audible(_PaneSession session) => !_allMuted && !_globalMuted && session.slot == _selected;

  /// Applies the focus to every pane: the selected one is audible, the rest
  /// are muted.
  void _applyFocus() {
    for (final session in _sessions) {
      unawaited(_applyAudio(session));
    }
  }

  /// Hands [session]'s engine its volume and mute state; both are re-applied
  /// whenever the pane gets a fresh handle (a line switch, a recovery) or the
  /// focus moves.
  Future<void> _applyAudio(_PaneSession session) async {
    final handle = session.handle;
    if (handle == null) return;
    try {
      await handle.setVolume(session.volume);
      await handle.setMute(muted: !_audible(session));
    } on Object {
      // A pane the engine refused to mute is not a playback failure.
    }
  }

  /// The engine options every pane keeps for its next line, engine fallback
  /// or recovery: hardware decoding and the player proxy.
  List<EngineOption> _storedEngineOptions() => playerStoredEngineOptions(
    hardwareDecoding: ref.read(playbackSettingsProvider).hardwareDecoding,
    tuning: ref.read(playerTuningProvider),
    proxy: ref.read(playerProxyProvider),
  );

  /// The stored options plus the chosen shader chain, for a pane's first
  /// engine and every later line or recovery.
  Future<List<EngineOption>> _engineOptions() =>
      withSuperResolution(_storedEngineOptions(), ref.read(superResolutionModeProvider));

  /// Pushes the stored options into every playing pane when the proxy or the
  /// hardware-decoding switch changes; the walls' next open uses the same
  /// list.
  void _applyStoredEngineOptions() {
    final options = _storedEngineOptions();
    for (final session in _sessions) {
      final playback = session.playback;
      if (playback != null) unawaited(playback.updateEngineOptions(options));
    }
  }

  /// A custom-output or driver change reaches every running pane: the stored
  /// options feed each pane's next line, each handle gets them now, and a
  /// changed video/audio output rebuilds that pane's render context in place.
  Future<void> _applyTuning(PlayerTuning? previous, PlayerTuning next) async {
    final options = _storedEngineOptions();
    final rebuild = previous != null && playerOutputChanged(previous, next);
    final transition = previous == null ? const <EngineOption>[] : playerPresetTransitionOptions(previous, next);
    for (final session in [..._sessions]) {
      final playback = session.playback;
      if (playback != null) unawaited(playback.updateEngineOptions(options));
      final handle = session.handle;
      if (handle == null) continue;
      try {
        await handle.applyEngineOptions(<EngineOption>[...await _engineOptions(), ...transition]);
        if (rebuild) await handle.rebuildEngine(reason: 'video output settings changed');
      } on Object {
        // A pane the engine refused an option is not a playback failure.
      }
    }
  }

  /// Gives a fresh handle the same stored options; a line switch, engine
  /// fallback or recovery must not keep an old decoder or route.
  Future<void> _applyEngineOptions(_PaneSession session) async {
    final handle = session.handle;
    if (handle == null) return;
    try {
      await handle.applyEngineOptions(await _engineOptions());
    } on Object {
      // A pane the engine refused an option is not a playback failure.
    }
  }

  void _fail(_PaneSession session, String message) {
    session
      ..stage = MultiviewPaneStage.failed
      ..error = message;
    _publish();
  }

  void _release(_PaneSession session) {
    if (session.disposed) return;
    session.disposed = true;
    session.epoch++;
    unawaited(session.handles?.cancel() ?? Future<void>.value());
    unawaited(session.states?.cancel() ?? Future<void>.value());
    unawaited(session.failures?.cancel() ?? Future<void>.value());
    session
      ..handles = null
      ..states = null
      ..failures = null;
    unawaited(session.playback?.dispose() ?? Future<void>.value());
    session
      ..playback = null
      ..handle = null;
    _sessions.remove(session);
  }

  void _releaseAll() {
    [..._sessions].forEach(_release);
  }

  void _publish() {
    state = (
      active: _active,
      allMuted: _allMuted,
      selected: _selected,
      panes: {
        for (final session in _sessions)
          session.slot: (
            slot: session.slot,
            identity: session.identity,
            room: session.room,
            stage: session.stage,
            handle: session.handle,
            error: session.error,
            qualities: session.qualities,
            quality: session.quality,
            switching: session.switching,
            lines: session.lines,
            lineIndex: session.lineIndex,
            paused: session.paused,
            volume: session.volume,
            audible: _audible(session),
          ),
      },
    );
  }
}

/// One pane's session holder: the mutable facts the controller changes and
/// the page reads through [MultiviewPlaybackState].
final class _PaneSession {
  _PaneSession({required this.slot, required this.identity, this.volume = 1});

  final int slot;
  final String identity;
  LiveRoom? room;
  LivePlaybackProvider? capability;
  MultiviewPaneStage stage = MultiviewPaneStage.opening;
  PlayerHandle? handle;
  String? error;
  List<LivePlayQuality> qualities = const [];
  LivePlayQuality? quality;
  bool switching = false;
  List<LivePlayLine> lines = const [];
  int lineIndex = 0;
  bool paused = false;
  double volume;
  LivePlaybackController? playback;
  // Cancelled in _release.
  // ignore: cancel_subscriptions
  StreamSubscription<PlayerHandle>? handles;
  // Cancelled in _release.
  // ignore: cancel_subscriptions
  StreamSubscription<PlayerCoreState>? states;
  // Cancelled in _release.
  // ignore: cancel_subscriptions
  StreamSubscription<PlayerFailure>? failures;
  int epoch = 0;
  bool disposed = false;
}

/// Why a pane could not open, with the site's own words when it has them.
final class _PaneOpenFailure implements Exception {
  const _PaneOpenFailure(this.message);

  final String message;
}

/// The wall's playback sessions.
final multiviewPlaybackProvider = NotifierProvider<MultiviewPlaybackController, MultiviewPlaybackState>(
  MultiviewPlaybackController.new,
);
