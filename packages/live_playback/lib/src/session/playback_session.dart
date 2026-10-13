import 'dart:async';

import 'package:live_playback/src/model/content_type.dart';
import 'package:live_playback/src/model/playback_event.dart';
import 'package:live_playback/src/model/playback_failure.dart';
import 'package:live_playback/src/model/playback_metadata.dart';
import 'package:live_playback/src/model/playback_state.dart';
import 'package:live_playback/src/model/playback_system_state.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart';
import 'package:rxdart/rxdart.dart';

/// A business-level playback session for one room or video.
///
/// It wraps a [PlayerHandle] from the media kernel and adds what the kernel
/// deliberately does not know:
///
/// - **recovery**: the [RecoveryLadder] turns adapter failures into the
///   live ladder (same line → next line → next quality → refresh → give up)
///   and publishes the business [PlaybackState] the UI renders;
/// - **chat**: an optional [DanmakuController] per room, plus the rule that a
///   thumbnail presentation (PiP, floating) shows no danmaku;
/// - **identity**: the room title, streamer and cover the notification and
///   every non-video surface name the stream with.
///
/// It does not own presentation mechanics or window geometry — those belong
/// to the kernel's presentation driver and the page that hosts the surface.
final class PlaybackSession {
  /// Creates a session over an opened [handle].
  ///
  /// [sourceCandidates] are the alternative lines/qualities the recovery
  /// ladder may escalate to, best first. [danmaku] is optional: a platform
  /// with no chat integration never passes one.
  new({
    required this.id,
    required this.handle,
    required this.kernel,
    this.contentType = ContentType.live,
    this.sourceCandidates = const <PlayerSource>[],
    this.metadata = PlaybackMetadata.none,
    this.danmaku,
  }) {
    _init();
  }

  /// Unique business identifier (room id, video id).
  final String id;

  /// The underlying media kernel handle.
  final PlayerHandle handle;

  /// The kernel that created [handle]; used to release it.
  final PlayerKernel kernel;

  /// Live or recorded.
  final ContentType contentType;

  /// Alternative sources for the recovery ladder, best first.
  final List<PlayerSource> sourceCandidates;

  /// Chat controller for this room, when the platform has one.
  ///
  /// The caller owns its transport: only the site layer knows which protocol
  /// a platform's chat speaks, so the controller arrives already installed.
  final DanmakuController? danmaku;

  // --- Business state ---

  final BehaviorSubject<PlaybackState> _stateSubject = BehaviorSubject<PlaybackState>.seeded(const PlaybackState());

  final StreamController<PlaybackEvent> _eventController = StreamController<PlaybackEvent>.broadcast();

  late final RecoveryLadder _ladder;
  StreamSubscription<PlayerAdapterEvent>? _adapterSub;
  StreamSubscription<RecoveryLadderEvent>? _ladderSub;

  // --- Danmaku state ---

  /// The viewer's own danmaku preference for this room.
  final BehaviorSubject<bool> _danmakuWanted = BehaviorSubject<bool>.seeded(true);

  /// Whether the current presentation mode suppresses danmaku (thumbnail).
  bool _danmakuSuppressedByMode = false;

  final BehaviorSubject<bool> _danmakuEnabled = BehaviorSubject<bool>.seeded(true);

  // --- Audio bookkeeping ---

  /// Whether the sound is muted, as a stream: the system state snapshot follows
  /// it, and a muting that nothing else announces (another window claiming the
  /// channel) would otherwise leave a stale flag in that snapshot.
  final BehaviorSubject<bool> _mutedSubject = BehaviorSubject<bool>.seeded(false);

  /// Business state: phase, quality, line and recovery attempts.
  ValueStream<PlaybackState> get state => _stateSubject.stream;

  /// Current business state.
  PlaybackState get currentState => _stateSubject.value;

  /// Diagnostic events (started, failed, recovered, renewing, gave up).
  Stream<PlaybackEvent> get events => _eventController.stream;

  /// The kernel's combined snapshot: playback, geometry, session, recovery.
  PlayerHandleSnapshot get snapshot => handle.combinedSnapshot;

  /// The kernel's transport state stream.
  ValueStream<PlayerTransportState> get transportState => handle.stateChanges;

  /// Room identity: what the notification and overlays call this stream.
  PlaybackMetadata metadata;

  /// Whether the session is in a thumbnail presentation (PiP or floating).
  bool get isThumbnail => _thumbnailMode;

  bool _thumbnailMode = false;

  /// Whether this session's sound is muted.
  bool get muted => _mutedSubject.value;

  /// Stream of mute changes.
  ValueStream<bool> get mutedChanges => _mutedSubject.stream;

  /// Whether the picture is playing right now, as the kernel reports it.
  bool get isPlaying => handle.isPlaying;

  /// The volume as last set, `0.0`–`1.0`.
  double get volume => handle.volume;

  /// Danmaku connection state stream, when a controller is attached.
  Stream<DanmakuSessionState>? get danmakuState => danmaku?.onStateChanged;

  /// Whether danmaku is visible right now (preference and mode agree).
  bool get danmakuEnabled => _danmakuEnabled.value;

  /// Whether the viewer wants danmaku at all, ignoring the presentation mode.
  bool get danmakuWanted => _danmakuWanted.value;

  /// Whether danmaku would be visible in a full-size presentation.
  ValueStream<bool> get danmakuEnabledChanges => _danmakuEnabled.stream;

  // --- Lifecycle ---

  void _init() {
    _ladder = RecoveryLadder(target: handle, candidates: _LiveRecoveryCandidateProvider(sourceCandidates));
    _adapterSub = handle.adapterEvents.listen(_onAdapterEvent);
    _ladderSub = _ladder.events.listen(_onRecoveryEvent);
  }

  // --- Playback controls ---

  /// Resumes playback.
  Future<void> play() async {
    await handle.play();
    _raiseIfNeeded();
  }

  /// Pauses playback.
  Future<void> pause() async {
    await handle.pause();
    _stateSubject.add(currentState.copyWith(phase: PlaybackPhase.paused));
  }

  /// Stops playback and releases the source.
  Future<void> stop() => handle.stop();

  /// Seeks to [position].
  Future<void> seek(Duration position) => handle.seek(position);

  /// Sets the volume, `0.0`–`1.0`.
  Future<void> setVolume(double volume) => handle.setVolume(volume);

  /// Mutes or unmutes.
  Future<void> setMute({required bool muted}) async {
    _mutedSubject.add(muted);
    await handle.setMute(muted);
  }

  /// Sets the playback rate.
  Future<void> setRate(double rate) => handle.setRate(rate);

  /// Re-opens the current source.
  ///
  /// For a live stream this is "go back to the live edge": the source URL was
  /// resolved minutes ago, the broadcast moved on, and reopening is what
  /// re-syncs it. Used when a room comes back from being suspended, where
  /// resuming a stale buffer would replay what the viewer already missed.
  Future<void> refresh() async {
    final source = handle.source;
    if (source == null) {
      return;
    }

    _stateSubject.add(currentState.copyWith(phase: PlaybackPhase.opening));
    await handle.open(source);
    _stateSubject.add(currentState.copyWith(phase: PlaybackPhase.playing));
  }

  // --- Danmaku controls ---

  /// Connects the room's chat, when a controller is attached.
  Future<void> connectDanmaku(DanmakuRoomRef room) async {
    await danmaku?.connect(room);
  }

  /// Disconnects the room's chat without disposing the controller.
  Future<void> stopDanmaku() async {
    await danmaku?.stop();
  }

  /// Turns danmaku on or off for this room (the viewer's preference).
  ///
  /// [enabled] is remembered independently of the presentation mode, so
  /// leaving PiP restores whatever the viewer had chosen.
  void setDanmakuEnabled({required bool enabled}) {
    _danmakuWanted.add(enabled);
    _emitDanmakuEnabled();
  }

  /// Updates the viewer's blocklist for this room.
  void updateDanmakuPolicy(DanmakuFilterPolicy policy) {
    danmaku?.updatePolicy(policy);
  }

  /// Updates the danmaku transport tuning (timeouts, dedup windows).
  void updateDanmakuConfig(DanmakuConfig config) {
    danmaku?.updateConfig(config);
  }

  // --- Presentation policy ---

  /// Applies the business rules for a presentation [mode].
  ///
  /// PiP and floating windows are thumbnails: danmaku is suppressed there
  /// (and restored on the way back) while the viewer's own preference is
  /// left untouched. The picture keeps playing: a live stream does not stop
  /// because it shrank.
  void applyPresentationMode(PresentationMode mode) {
    final thumbnail = mode.isPip || mode.isFloating;
    if (_thumbnailMode == thumbnail) {
      return;
    }
    _thumbnailMode = thumbnail;
    _danmakuSuppressedByMode = thumbnail;
    _emitDanmakuEnabled();
  }

  void _emitDanmakuEnabled() {
    final enabled = _danmakuWanted.value && !_danmakuSuppressedByMode;
    if (_danmakuEnabled.value != enabled) {
      _danmakuEnabled.add(enabled);
    }
  }

  // --- Snapshot ---

  /// A read-only view of this session for the system state and any surface
  /// (PiP, multi-view tile, debug overlay) that needs one.
  PlaybackSessionSnapshot toSnapshot({bool isPrimary = false}) {
    return PlaybackSessionSnapshot(
      id: id,
      contentType: contentType,
      state: currentState,
      metadata: metadata,
      volume: volume,
      muted: muted,
      danmakuEnabled: danmakuEnabled,
      danmaku: danmaku?.state,
      player: snapshot,
      isPrimary: isPrimary,
    );
  }

  // --- Recovery wiring ---

  void _onAdapterEvent(PlayerAdapterEvent event) {
    if (event is! PlayerAdapterErrorEvent) {
      return;
    }

    final failure = _classify(event);
    _stateSubject.add(currentState.copyWith(phase: PlaybackPhase.recovering, lastFailure: failure));
    _eventController.add(PlaybackEvent.failed(failure: failure));

    _ladder.report(
      RecoveryFailure(code: _mapToCoreCode(failure), message: failure.detail, source: RecoveryFailureSource.adapter),
    );
  }

  void _onRecoveryEvent(RecoveryLadderEvent event) {
    switch (event) {
      case RecoveryLadderStepStarted():
        _stateSubject.add(currentState.copyWith(phase: PlaybackPhase.recovering));
      case RecoveryLadderCompleted():
        _stateSubject.add(currentState.copyWith(phase: PlaybackPhase.playing, recoveryAttempts: _ladder.attempt));
        _eventController.add(
          PlaybackEvent.recovered(quality: currentState.qualityLabel ?? '', attempt: _ladder.attempt),
        );
      case RecoveryLadderExhausted():
        _stateSubject.add(currentState.copyWith(phase: PlaybackPhase.ended));
        final failure = currentState.lastFailure;
        if (failure != null) {
          _eventController.add(PlaybackEvent.gaveUp(failure: failure));
        }
      case RecoveryLadderStarted():
      case RecoveryLadderStepFailed():
      case RecoveryLadderCancelled():
        break;
    }
  }

  PlaybackFailure _classify(PlayerAdapterErrorEvent event) {
    final error = event.error;
    if (error is PlayerFailure) {
      return _fromCoreFailure(error);
    }
    return PlaybackFailure.engine(detail: event.message, cause: error);
  }

  PlaybackFailure _fromCoreFailure(PlayerFailure failure) {
    final detail = failure.message ?? failure.code.value;
    return switch (failure.code) {
      PlayerErrorCode.sourceMissing => PlaybackFailure.streamUnavailable(detail: detail),
      PlayerErrorCode.noPlayableStream => PlaybackFailure.notLive(detail: detail),
      PlayerErrorCode.authenticationRequired => PlaybackFailure.needsLogin(detail: detail),
      PlayerErrorCode.network || PlayerErrorCode.networkConnectionRefused => PlaybackFailure.network(detail: detail),
      _ => PlaybackFailure.engine(detail: detail, cause: failure),
    };
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

  void _raiseIfNeeded() {
    if (currentState.phase == PlaybackPhase.idle ||
        currentState.phase == PlaybackPhase.paused ||
        currentState.phase == PlaybackPhase.opening) {
      _stateSubject.add(currentState.copyWith(phase: PlaybackPhase.playing));
    }
  }

  /// Disposes the session's own resources (ladder, chat, streams).
  ///
  /// The [handle] is *not* disposed here — the coordinator releases it
  /// through the kernel so the pool and every coordinator see the release.
  Future<void> dispose() async {
    await _adapterSub?.cancel();
    await _ladderSub?.cancel();
    await _ladder.dispose();
    await danmaku?.dispose();
    await _stateSubject.close();
    await _mutedSubject.close();
    await _danmakuWanted.close();
    await _danmakuEnabled.close();
    await _eventController.close();
  }
}

/// Internal provider for the recovery ladder.
class _LiveRecoveryCandidateProvider implements RecoveryCandidateProvider {
  const new(this.sources);

  final List<PlayerSource> sources;

  @override
  RecoveryCandidates candidatesFor(RecoveryFailure failure) {
    return RecoveryCandidates(sources: sources);
  }
}
