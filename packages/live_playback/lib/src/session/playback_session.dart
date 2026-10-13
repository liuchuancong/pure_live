import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_playback/src/engine/playback_engine.dart';
import 'package:live_playback/src/model/playback_event.dart';
import 'package:live_playback/src/model/playback_failure.dart';
import 'package:live_playback/src/model/playback_state.dart';
import 'package:live_playback/src/session/lease_scheduler.dart';
import 'package:live_playback/src/session/quality_selector.dart';
import 'package:live_sites/live_sites.dart';

/// One room's playback session: resolves qualities and lines through the
/// site, drives the engine, renews leases and walks the recovery ladder.
///
/// Recovery order, from the architecture spec: re-open the same line, then
/// the next line of the same quality, then the next quality, then refresh
/// the play URLs (a fresh resolve), then give up. A not-live room and a
/// login requirement skip the ladder entirely
/// (`PlaybackFailure.isRetryable`).
final class PlaybackSession {
  /// A session for [room] over [site], driving engines from
  /// [engineFactory].
  new({
    required this.room,
    required this.site,
    required this.engineFactory,
    QualitySelector? selector,
    this.maxRecoveryAttempts = 3,
    DateTime Function()? now,
  }) : selector = selector ?? const QualitySelector() {
    _engine = engineFactory();
    _engineEvents = _engine.events.listen(_onEngineEvent);
    _lease = LeaseScheduler(onRenew: _onLeaseDue, now: now);
  }

  /// The room this session plays.
  final LiveRoom room;

  /// The site the room belongs to.
  final LiveSite site;

  /// Creates the engine (one per session).
  final PlaybackEngineFactory engineFactory;

  /// The quality/line order strategy.
  final QualitySelector selector;

  /// How many ladder advances are spent before giving up.
  final int maxRecoveryAttempts;

  late final PlaybackEngine _engine;
  late final StreamSubscription<PlaybackEngineEvent> _engineEvents;
  late final LeaseScheduler _lease;

  final _states = StreamController<PlaybackState>.broadcast();
  final _events = StreamController<PlaybackEvent>.broadcast();
  final List<void Function(PlaybackState)> _listeners = [];

  PlaybackState _state = const PlaybackState();
  List<LivePlayQuality> _order = const [];
  int _qualityIndex = 0;
  int _lineIndex = 0;
  bool _disposed = false;
  bool _opening = false;

  /// The current state.
  PlaybackState get state => _state;

  /// A stream of state snapshots.
  Stream<PlaybackState> get states => _states.stream;

  /// A stream of diagnostics events.
  Stream<PlaybackEvent> get events => _events.stream;

  /// Starts playback: resolves the room's qualities and opens the first
  /// line of the preferred quality.
  Future<void> start() async {
    if (_disposed || _state.isBusy || _state.isActive) {
      return;
    }
    await _resolve(refresh: true);
  }

  /// Stops playback and releases the engine-driven source.
  Future<void> stop() async {
    _lease.cancel();
    await _engine.stop();
    _setState(_state.copyWith(phase: PlaybackPhase.idle, qualityLabel: null, lineId: null, recoveryAttempts: 0));
  }

  /// Pauses playback.
  Future<void> pause() async {
    if (_state.phase != PlaybackPhase.playing) {
      return;
    }
    await _engine.pause();
    _setState(_state.copyWith(phase: PlaybackPhase.paused));
  }

  /// Resumes playback.
  Future<void> resume() async {
    if (_state.phase != PlaybackPhase.paused) {
      return;
    }
    await _engine.resume();
    _setState(_state.copyWith(phase: PlaybackPhase.playing));
  }

  /// Releases the session: engine, streams and timers.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _lease.cancel();
    await _engineEvents.cancel();
    await _engine.dispose();
    await _states.close();
    await _events.close();
    _listeners.clear();
  }

  /// Adds a state listener.
  void addListener(void Function(PlaybackState) listener) => _listeners.add(listener);

  /// Removes a state listener.
  void removeListener(void Function(PlaybackState) listener) => _listeners.remove(listener);

  /// Resolves qualities and lines and opens the current pick.
  ///
  /// [refresh] forces a fresh quality resolve (recovery); without it the
  /// cached order is kept.
  Future<void> _resolve({required bool refresh}) async {
    if (_disposed) {
      return;
    }
    _setState(_state.copyWith(phase: PlaybackPhase.resolving));
    try {
      if (_order.isEmpty || refresh) {
        final provider = site.capability<LivePlaybackProvider>();
        if (provider == null) {
          _giveUp(const PlaybackFailure.apiChanged(detail: 'site exposes no playback capability'));
          return;
        }
        final qualities = await provider
            .getQualities(roomId: room.roomId)
            .then((result) => result.fold((error) => throw SiteFailure(error), (values) => values));
        _order = selector.order(qualities);
        _qualityIndex = 0;
        _lineIndex = 0;
      }
      if (_order.isEmpty) {
        _giveUp(const PlaybackFailure.notLive(detail: 'no playable quality'));
        return;
      }
      await _openCurrent();
    } on Object catch (error) {
      await _advanceLadder(_classify(error));
    }
  }

  /// Opens the line at the current (quality, line) cursor.
  Future<void> _openCurrent() async {
    final quality = _order[_qualityIndex];
    final lines = await _linesOf(quality);
    if (_lineIndex >= lines.length) {
      await _advanceLadder(PlaybackFailure.streamUnavailable(detail: 'no line left in ${quality.label}'));
      return;
    }
    final line = lines[_lineIndex];
    if (_opening || _disposed) {
      return;
    }
    _opening = true;
    _setState(_state.copyWith(phase: PlaybackPhase.opening, qualityLabel: quality.label, lineId: line.lineLabel));
    try {
      await _engine.open(line);
    } on Object catch (error) {
      _opening = false;
      await _advanceLadder(_classify(error));
      return;
    }
    _opening = false;
    _lease.arm(line);
    _setState(_state.copyWith(phase: PlaybackPhase.playing));
    _events.add(PlaybackEvent.started(quality: quality.label, lineId: line.lineLabel));
  }

  Future<List<LivePlayLine>> _linesOf(LivePlayQuality quality) async {
    final provider = site.capability<LivePlaybackProvider>();
    if (provider == null) {
      throw const PlaybackFailure.apiChanged(detail: 'site exposes no playback capability');
    }
    final result = await provider.getLines(roomId: room.roomId, quality: quality);
    return switch (result) {
      Left(:final value) => throw SiteFailure(value),
      Right(:final value) => value,
    };
  }

  /// Advances the ladder after [failure]: next line, then next quality,
  /// then a fresh resolve, then give up.
  Future<void> _advanceLadder(PlaybackFailure failure) async {
    if (_disposed) {
      return;
    }
    if (!failure.isRetryable) {
      _giveUp(failure);
      return;
    }
    _events.add(PlaybackEvent.failed(failure: failure));
    final attempts = _state.recoveryAttempts + 1;
    if (attempts > maxRecoveryAttempts) {
      _giveUp(failure);
      return;
    }
    _setState(_state.copyWith(phase: PlaybackPhase.recovering, recoveryAttempts: attempts, lastFailure: failure));
    var refresh = false;
    if (_qualityIndex < _order.length) {
      final lines = await _lineCount(_order[_qualityIndex]);
      if (_lineIndex + 1 < lines) {
        _lineIndex++;
      } else if (_qualityIndex + 1 < _order.length) {
        _qualityIndex++;
        _lineIndex = 0;
      } else {
        // The whole ladder is exhausted: refresh the play URLs once more
        // before giving up.
        refresh = true;
        _order = const [];
        _qualityIndex = 0;
        _lineIndex = 0;
      }
    } else {
      refresh = true;
    }
    await _resolve(refresh: refresh);
    if (_state.isEnded) {
      return;
    }
    _events.add(PlaybackEvent.recovered(quality: _order.isEmpty ? '' : _order[_qualityIndex].label, attempt: attempts));
  }

  Future<int> _lineCount(LivePlayQuality quality) async {
    try {
      return (await _linesOf(quality)).length;
    } on Object {
      return 0;
    }
  }

  /// A lease deadline passed: advance the ladder (a fresh resolve brings
  /// renewed URLs).
  void _onLeaseDue() {
    if (_disposed || !_state.isActive) {
      return;
    }
    _events.add(PlaybackEvent.renewing(quality: _state.qualityLabel ?? ''));
    unawaited(_advanceLadder(const PlaybackFailure.streamUnavailable(detail: 'lease expired')));
  }

  void _onEngineEvent(PlaybackEngineEvent event) {
    if (_disposed) {
      return;
    }
    switch (event) {
      case EngineReady():
        if (_state.phase == PlaybackPhase.opening) {
          _setState(_state.copyWith(phase: PlaybackPhase.playing));
        }
      case EngineStopped(:final error):
        if (_state.phase == PlaybackPhase.playing || _state.phase == PlaybackPhase.opening) {
          unawaited(_advanceLadder(_classify(error ?? 'engine stopped')));
        }
      case EngineProgress():
        break;
    }
  }

  /// Maps a site error or engine failure onto [PlaybackFailure].
  PlaybackFailure _classify(Object? error) {
    if (error is PlaybackFailure) {
      return error;
    }
    if (error is SiteFailure) {
      return _classifySite(error.error);
    }
    return switch (error) {
      _ => PlaybackFailure.engine(detail: '$error', cause: error),
    };
  }

  /// Maps an Either-reported site error onto [PlaybackFailure].
  PlaybackFailure _classifySite(LiveSiteError error) {
    return switch (error) {
      LiveSiteNotFound(:final message) => PlaybackFailure.streamUnavailable(detail: message),
      LiveSiteUnsupported(:final message) ||
      LiveSiteParseError(:final message) ||
      LiveSiteInvalidArgument(:final message) => PlaybackFailure.apiChanged(detail: message),
      LiveSiteAuthenticationError(:final message) => PlaybackFailure.needsLogin(detail: message),
      LiveSiteRateLimitError(:final message) => PlaybackFailure.rateLimited(detail: message),
      LiveSiteNetworkError(:final message) => PlaybackFailure.network(detail: message),
      _ => PlaybackFailure.engine(detail: '$error', cause: error),
    };
  }

  void _giveUp(PlaybackFailure failure) {
    _setState(_state.copyWith(phase: PlaybackPhase.ended, lastFailure: failure));
    _events.add(PlaybackEvent.gaveUp(failure: failure));
  }

  void _setState(PlaybackState next) {
    _state = next;
    _states.add(next);
    for (final listener in List.of(_listeners)) {
      listener(next);
    }
  }
}

/// Bridges an Either-reported site error into the session's
/// exception-driven recovery ladder.
final class SiteFailure implements Exception {
  /// Wraps the site error returned by a capability's Either.
  new(this.error);

  /// The site error the capability returned.
  final LiveSiteError error;

  @override
  String toString() => 'SiteFailure(${error.message})';
}
