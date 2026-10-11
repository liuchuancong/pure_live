import 'dart:async';

import 'package:live_interaction/src/audience/audience_tracker.dart';
import 'package:live_interaction/src/model/interaction_state.dart';
import 'package:live_interaction/src/pipeline/message_filter.dart';
import 'package:live_interaction/src/pipeline/message_gate.dart';
import 'package:live_interaction/src/source/interaction_source.dart';
import 'package:live_sites/live_sites.dart';

/// One room's interaction session: connects every source, merges their
/// messages, gates and filters them, and distributes audience updates.
///
/// Lifecycle: [start] connects the sources; a source error flips the
/// state to reconnecting and re-listens with exponential backoff
/// (attempt * 2 s, capped at [maxBackoff]) until [maxReconnects] is
/// spent; [stop] closes every source; [dispose] releases the session.
/// The messages themselves arrive on [messages] — already deduplicated,
/// backlog-dropped and filtered.
final class InteractionSession {
  /// A session over [sources], filtered by [filter].
  new({
    required List<InteractionSource> sources,
    this.filter,
    MessageGate? gate,
    this.maxReconnects = 5,
    this.maxBackoff = const Duration(seconds: 30),
    Duration Function(int attempt)? backoff,
  }) : _sources = List.of(sources),
       _gate = gate ?? MessageGate(),
       _backoff = backoff ?? ((attempt) => Duration(seconds: attempt * 2));

  /// How many reconnect attempts are spent per source before giving up.
  final int maxReconnects;

  /// The cap for the reconnect backoff.
  final Duration maxBackoff;

  /// The message filter applied after the gate, when configured.
  final MessageFilter? filter;

  final List<InteractionSource> _sources;
  final MessageGate _gate;
  final Duration Function(int attempt) _backoff;

  final Map<String, StreamSubscription<LiveMessage>> _subscriptions = {};
  final _messages = StreamController<LiveMessage>.broadcast();
  final _states = StreamController<InteractionState>.broadcast();
  final Map<String, int> _attempts = {};

  InteractionState _state = const InteractionState();
  bool _disposed = false;

  /// The session's audience readings.
  final AudienceTracker audience = AudienceTracker();

  /// The filtered message stream; multi-subscription.
  Stream<LiveMessage> get messages => _messages.stream;

  /// A stream of state snapshots.
  Stream<InteractionState> get states => _states.stream;

  /// The current state.
  InteractionState get state => _state;

  /// Connects the sources (idempotent while connected).
  Future<void> start() async {
    if (_disposed || _state.phase == InteractionPhase.connected) {
      return;
    }
    _sources.forEach(_listen);
    _setState(
      _state.copyWith(phase: InteractionPhase.connected, activeSources: [for (final source in _sources) source.id]),
    );
  }

  /// Closes every source and stops listening.
  Future<void> stop() async {
    for (final subscription in List.of(_subscriptions.values)) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await Future.forEach(_sources, (source) => source.close());
    _setState(_state.copyWith(phase: InteractionPhase.idle, activeSources: const []));
  }

  /// Releases the session: sources, streams and subscriptions.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    await stop();
    _disposed = true;
    await _messages.close();
    await _states.close();
  }

  void _listen(InteractionSource source) {
    _subscriptions[source.id] = source.messages.listen(
      _onMessage,
      onError: (Object error, StackTrace stack) => _onSourceError(source, error),
      onDone: () => _onSourceDone(source),
      cancelOnError: true,
    );
  }

  void _onMessage(LiveMessage message) {
    audience.consume(message);
    if (!_gate.allows(message)) {
      return;
    }
    final filter = this.filter;
    if (filter != null && !filter.allows(message)) {
      return;
    }
    _messages.add(message);
  }

  void _onSourceError(InteractionSource source, Object error) {
    if (_disposed) {
      return;
    }
    unawaited(_reconnect(source, error));
  }

  void _onSourceDone(InteractionSource source) {
    if (_disposed || _state.phase == InteractionPhase.idle) {
      return;
    }
    unawaited(_reconnect(source, 'source ${source.id} closed'));
  }

  /// Reconnects [source] with backoff until the attempt budget is spent.
  Future<void> _reconnect(InteractionSource source, Object error) async {
    final attempts = (_attempts[source.id] ?? 0) + 1;
    _attempts[source.id] = attempts;
    if (attempts > maxReconnects) {
      _setState(
        _state.copyWith(
          phase: InteractionPhase.ended,
          reconnectAttempts: attempts - 1,
          activeSources: [
            for (final id in _state.activeSources)
              if (id != source.id) id,
          ],
          lastError: error,
        ),
      );
      _messages.addError(error);
      return;
    }
    _setState(_state.copyWith(phase: InteractionPhase.reconnecting, reconnectAttempts: attempts, lastError: error));
    _gate.openReconnectWindow();
    final delay = _backoff(attempts);
    await Future<void>.delayed(delay > maxBackoff ? maxBackoff : delay);
    if (_disposed || _state.isEnded) {
      return;
    }
    // Drop the failed subscription, then listen again: the danmaku source
    // re-invokes its connect on the next listen.
    final failed = _subscriptions.remove(source.id);
    await failed?.cancel();
    if (_disposed) {
      return;
    }
    _listen(source);
    _attempts[source.id] = 0;
    _setState(
      _state.copyWith(
        phase: InteractionPhase.connected,
        activeSources: [for (final candidate in _sources) candidate.id],
      ),
    );
  }

  void _setState(InteractionState next) {
    _state = next;
    _states.add(next);
  }
}
