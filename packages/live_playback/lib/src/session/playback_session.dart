import 'dart:async';

import 'package:live_playback/src/model/playback_event.dart';
import 'package:live_playback/src/model/playback_failure.dart';
import 'package:live_playback/src/model/playback_state.dart';
import 'package:media_core/media_core.dart';
import 'package:rxdart/rxdart.dart';

/// A business-level playback session for a live room.
///
/// It wraps a [PlayerHandle] and adds the [RecoveryLadder] to handle
/// the specific failure/retry logic of live streaming.
final class PlaybackSession {

  /// Creates a new [PlaybackSession].
  PlaybackSession({
    required this.handle,
    required this.sourceCandidates,
    required this.kernel,
  }) {
    _init();
  }
  /// The underlying media handle.
  final PlayerHandle handle;
  
  /// The available sources for recovery.
  final List<PlayerSource> sourceCandidates;
  
  /// The kernel for coordination.
  final PlayerKernel kernel;

  final BehaviorSubject<PlaybackState> _stateSubject = BehaviorSubject.seeded(
    const PlaybackState(),
  );

  final StreamController<PlaybackEvent> _eventController = StreamController<PlaybackEvent>.broadcast();

  late final RecoveryLadder _ladder;
  StreamSubscription<PlayerAdapterEvent>? _adapterSub;
  StreamSubscription<RecoveryLadderEvent>? _ladderSub;

  /// Public state stream.
  ValueStream<PlaybackState> get state => _stateSubject.stream;
  
  /// Public event stream.
  Stream<PlaybackEvent> get events => _eventController.stream;

  void _init() {
    _ladder = RecoveryLadder(
      target: handle, 
      candidates: _LiveRecoveryCandidateProvider(sourceCandidates),
    );

    _adapterSub = handle.adapterEvents.listen(_onAdapterEvent);
    _ladderSub = _ladder.events.listen(_onRecoveryEvent);
  }

  void _onAdapterEvent(PlayerAdapterEvent event) {
    if (event is PlayerAdapterErrorEvent) {
      final error = event.error;
      if (error == null) return;
      
      final failure = _classify(error);
      _stateSubject.add(_stateSubject.value.copyWith(
        phase: PlaybackPhase.recovering,
        lastFailure: failure,
      ));
      
      _ladder.report(RecoveryFailure(
        code: _mapToCoreCode(failure), 
        message: failure.detail,
        source: RecoveryFailureSource.adapter,
      ));
    }
  }

  void _onRecoveryEvent(RecoveryLadderEvent event) {
    if (event is RecoveryLadderStepStarted) {
      _stateSubject.add(_stateSubject.value.copyWith(phase: PlaybackPhase.recovering));
    } else if (event is RecoveryLadderCompleted) {
      _stateSubject.add(_stateSubject.value.copyWith(
        phase: PlaybackPhase.playing,
        recoveryAttempts: _ladder.attempt,
      ));
      _eventController.add(PlaybackEvent.recovered(
        quality: 'recovered', 
        attempt: _ladder.attempt,
      ));
    } else if (event is RecoveryLadderExhausted) {
      _stateSubject.add(_stateSubject.value.copyWith(phase: PlaybackPhase.ended));
      final failure = _lastFailure;
      if (failure != null) {
        _eventController.add(PlaybackEvent.gaveUp(failure: failure));
      }
    }
  }

  PlaybackFailure _classify(Object error) {
    return PlaybackFailure.engine(detail: error.toString());
  }

  PlayerErrorCode _mapToCoreCode(PlaybackFailure failure) {
    return switch (failure) {
      StreamUnavailableFailure() => PlayerErrorCode.sourceMissing,
      NotLiveFailure() => PlayerErrorCode.noPlayableStream,
      NeedsLoginFailure() => PlayerErrorCode.authenticationRequired,
      RateLimitedFailure() => PlayerErrorCode.networkConnectionRefused,
      NetworkFailure() => PlayerErrorCode.network,
      EngineFailure() => PlayerErrorCode.playbackFailed,
      ApiChangedFailure() => PlayerErrorCode.unsupported,
    };
  }

  PlaybackFailure? get _lastFailure => _stateSubject.value.lastFailure;


  /// Disposes the session and its associated resources.
  Future<void> dispose() async {
    await _adapterSub?.cancel();
    await _ladderSub?.cancel();
    await _stateSubject.close();
    await _eventController.close();
  }
}

/// Internal provider for the recovery ladder.
class _LiveRecoveryCandidateProvider implements RecoveryCandidateProvider {
  _LiveRecoveryCandidateProvider(this.sources);
  final List<PlayerSource> sources;

  @override
  RecoveryCandidates candidatesFor(RecoveryFailure failure) {
    return RecoveryCandidates(
      sources: sources, 
    );
  }
}

