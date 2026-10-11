import 'package:live_playback/src/model/playback_state.dart';
import 'package:live_playback/src/session/playback_session.dart';
import 'package:live_sites/live_sites.dart';

/// Keeps the app's playback sessions in order and decides who owns the
/// audio.
///
/// One session per window (multi-window playback): the coordinator hands
/// out session ids, tracks each session's state, and guarantees a single
/// audio owner — when another session starts playing, the previous audio
/// owner is asked to drop to mute-only (or is stopped, per the caller's
/// policy).
final class PlaybackCoordinator {
  /// A coordinator over sessions created through [sessionFactory], with
  /// [sessionFactory] invoked per [open] call.
  new({required this.sessionFactory});

  /// Creates a session for one room; each call yields a fresh session.
  final PlaybackSession Function(LiveRoom room, LiveSite site) sessionFactory;

  final Map<int, PlaybackSession> _sessions = {};
  final List<void Function(PlaybackSession)> _listeners = [];
  int _nextId = 1;
  int? _audioOwnerId;

  /// The id of the session that currently owns the audio, if any.
  int? get audioOwnerId => _audioOwnerId;

  /// Every live session, keyed by id.
  Map<int, PlaybackSession> get sessions => Map.unmodifiable(_sessions);

  /// Adds a listener notified when a session's audio ownership changes.
  void addListener(void Function(PlaybackSession) listener) => _listeners.add(listener);

  /// Adds a listener.
  void removeListener(void Function(PlaybackSession) listener) => _listeners.remove(listener);

  /// Opens a new session for [room] over [site] and returns its id.
  ///
  /// The newest session claims the audio by default ([claimAudio]);
  /// pass false to open it muted (a background window).
  int open(LiveRoom room, LiveSite site, {bool claimAudio = true}) {
    final id = _nextId++;
    final session = sessionFactory(room, site);
    _sessions[id] = session;
    session.addListener((state) => _onSessionState(id, session, state));
    if (claimAudio) {
      _audioOwnerId = id;
    }
    return id;
  }

  /// Takes the session out of the coordinator and disposes it.
  Future<void> close(int id) async {
    final session = _sessions.remove(id);
    if (session == null) {
      return;
    }
    if (_audioOwnerId == id) {
      _audioOwnerId = null;
    }
    await session.dispose();
  }

  /// Makes [id] the audio owner; the previous owner keeps playing (the
  /// app mutes it through its own engine control).
  void claimAudio(int id) {
    if (!_sessions.containsKey(id)) {
      return;
    }
    _audioOwnerId = id;
    for (final listener in List.of(_listeners)) {
      listener(_sessions[id]!);
    }
  }

  /// The session holding the audio, if any.
  PlaybackSession? get audioOwner {
    final id = _audioOwnerId;
    return id == null ? null : _sessions[id];
  }

  /// Disposes every session.
  Future<void> disposeAll() async {
    for (final id in List.of(_sessions.keys)) {
      await close(id);
    }
    _listeners.clear();
  }

  void _onSessionState(int id, PlaybackSession session, PlaybackState state) {
    if (state.isEnded && _audioOwnerId == id) {
      _audioOwnerId = null;
    }
  }
}
