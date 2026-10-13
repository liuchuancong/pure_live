import 'dart:async';

import 'package:live_playback/src/coordinator/playback_session_coordinator.dart';
import 'package:live_playback/src/session/playback_session.dart';
import 'package:rxdart/rxdart.dart';

/// How one tile of a multi-view layout behaves.
final class MultiViewSlot {
  /// Creates a slot.
  const new({required this.id, this.isMuted = true, this.showDanmaku = false});

  /// The session id shown in this slot.
  final String id;

  /// Whether the slot starts muted. Only one slot is ever audible.
  final bool isMuted;

  /// Whether the slot shows chat. A grid of four rooms each with chat is not
  /// something anyone can read; chat belongs to the audible tile.
  final bool showDanmaku;
}

/// Which rooms are on screen and who is allowed to talk.
final class MultiViewState {
  /// Creates multi-view state.
  const new({required this.slotIds, this.audioOwnerId});

  /// The ids on screen, in layout order.
  final List<String> slotIds;

  /// The tile the viewer is listening to.
  final String? audioOwnerId;

  /// Whether any tile is on screen.
  bool get isEmpty => slotIds.isEmpty;

  /// Whether a tile owns the audio.
  bool get hasAudio => audioOwnerId != null;

  /// A copy with fields replaced.
  MultiViewState copyWith({List<String>? slotIds, String? audioOwnerId, bool clearAudioOwner = false}) {
    return MultiViewState(
      slotIds: slotIds ?? this.slotIds,
      audioOwnerId: clearAudioOwner ? null : (audioOwnerId ?? this.audioOwnerId),
    );
  }
}

/// Several rooms on screen at once, with one of them audible.
///
/// The grid is the host's UI; what lives here is the part that is easy to get
/// wrong when several video surfaces share a device:
///
/// - **who talks**: exactly one tile owns the audio channel. Tapping a tile
///   moves ownership; it never produces a grid of four rooms talking over each
///   other;
/// - **what moves together**: play/pause/seek across tiles, for the layouts
///   where the tiles are the *same* content at different lines or angles and
///   must stay in step;
/// - **what stays silent**: chat and idle tiles are muted, and a tile that
///   enters a small window does not take the sound with it.
///
/// Opening and closing sessions stays the coordinator's job: a tile is added
/// here only once its session exists.
final class MultiViewManager {
  /// Creates a multi-view manager.
  new({required this.coordinator});

  /// The session registry.
  final PlaybackSessionCoordinator coordinator;

  final BehaviorSubject<MultiViewState> _stateSubject = BehaviorSubject<MultiViewState>.seeded(
    const MultiViewState(slotIds: <String>[]),
  );

  /// Current layout state.
  ValueStream<MultiViewState> get state => _stateSubject.stream;

  /// The ids on screen, in layout order.
  List<String> get slotIds => _stateSubject.value.slotIds;

  /// Adds an open session to the layout.
  ///
  /// The slot starts muted unless it is the only one: the first tile on
  /// screen is the one the viewer expects to hear.
  Future<void> addSlot(MultiViewSlot slot) async {
    final current = _stateSubject.value;
    if (current.slotIds.contains(slot.id)) {
      return;
    }

    final session = coordinator.sessionFor(slot.id);
    if (session == null) {
      throw StateError('No open session for id: ${slot.id}; start it before adding the tile');
    }

    final isFirst = current.slotIds.isEmpty;
    final nextSlots = <String>[...current.slotIds, slot.id];

    if (isFirst || !slot.isMuted) {
      await coordinator.claimAudio(slot.id);
    } else {
      await session.setMute(muted: true);
    }

    session.setDanmakuEnabled(enabled: slot.showDanmaku);

    _stateSubject.add(MultiViewState(slotIds: nextSlots, audioOwnerId: isFirst ? slot.id : current.audioOwnerId));
  }

  /// Removes a tile and stops its session.
  Future<void> removeSlot(String id) async {
    final current = _stateSubject.value;
    if (!current.slotIds.contains(id)) {
      return;
    }

    await coordinator.stopSession(id);

    final nextSlots = current.slotIds.where((slotId) => slotId != id).toList(growable: false);
    final ownerLost = current.audioOwnerId == id;

    _stateSubject.add(MultiViewState(slotIds: nextSlots, audioOwnerId: ownerLost ? null : current.audioOwnerId));

    // The grid must not go silent because the audible tile was the one closed.
    if (ownerLost && nextSlots.isNotEmpty) {
      await coordinator.claimAudio(nextSlots.first);
      _stateSubject.add(_stateSubject.value.copyWith(audioOwnerId: nextSlots.first));
    }
  }

  /// Moves the audio channel to a tile.
  Future<void> focusSlot(String id) async {
    if (!_stateSubject.value.slotIds.contains(id)) {
      return;
    }
    await coordinator.claimAudio(id);
    _stateSubject.add(_stateSubject.value.copyWith(audioOwnerId: id));
  }

  // --- Synchronized transport ---

  Iterable<PlaybackSession> get _visibleSessions =>
      _stateSubject.value.slotIds.map(coordinator.sessionFor).whereType<PlaybackSession>();

  /// Resumes every tile.
  Future<void> playAll() async {
    await Future.wait(_visibleSessions.map((session) => session.play()));
  }

  /// Pauses every tile.
  Future<void> pauseAll() async {
    await Future.wait(_visibleSessions.map((session) => session.pause()));
  }

  /// Seeks every tile to [position].
  ///
  /// For layouts showing the same stream at different lines this is what keeps
  /// the pictures in step; their lines were resolved from the same wall clock,
  /// so one shared position is the sync.
  Future<void> seekAll(Duration position) async {
    await Future.wait(_visibleSessions.map((session) => session.seek(position)));
  }

  /// Mutes every tile.
  Future<void> muteAll() => coordinator.muteAll();

  /// Turns chat off on every tile.
  Future<void> stopAllDanmaku() => coordinator.setAllDanmakuEnabled(enabled: false);

  /// Stops every tile and empties the layout.
  Future<void> clear() async {
    await coordinator.stopAll();
    _stateSubject.add(const MultiViewState(slotIds: <String>[]));
  }

  /// Releases the manager's streams. Sessions stay open.
  Future<void> dispose() => _stateSubject.close();
}
