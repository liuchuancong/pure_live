// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/models/live_follow_group/live_follow_group.dart';
import 'package:live_sites/src/models/live_restriction/live_restriction.dart';
import 'package:live_sites/src/models/live_status/live_status.dart';
import 'package:meta/meta.dart';

/// The state of one broadcast: whether it is on air, when it started, and what
/// keeps it from simply playing.
@immutable
final class LiveBroadcast {
  /// Creates the broadcast state.
  const LiveBroadcast({this.liveStatus, this.startedAt, this.restriction});

  /// Broadcast state; null when the response did not say.
  final LiveStatus? liveStatus;

  /// When the current broadcast (or the replayed one) started, UTC; null when
  /// the response did not say or the room is not on.
  final DateTime? startedAt;

  /// What keeps the current broadcast from simply playing. Null means the
  /// response did not say; [LiveRestriction.none] means the platform was
  /// checked and there is no restriction.
  final LiveRestriction? restriction;

  /// The state used for display and playback: unknown when not given.
  LiveStatus get effectiveLiveStatus => liveStatus ?? LiveStatus.unknown;

  /// Broadcasting now (restricted or not).
  bool get isLiveNow => effectiveLiveStatus == LiveStatus.live;

  /// Live or replay: something can be played. A restriction does not change
  /// this (playback explains it); a carousel is not playable.
  bool get isPlayableNow => isLiveNow || effectiveLiveStatus == LiveStatus.replay;

  /// The platform said offline, banned or carousel (the streamer is off).
  bool get isExplicitlyOfflineNow => switch (effectiveLiveStatus) {
    LiveStatus.offline || LiveStatus.banned || LiveStatus.carousel => true,
    LiveStatus.live || LiveStatus.replay || LiveStatus.unknown => false,
  };

  /// The state is not known yet.
  bool get isPending => effectiveLiveStatus == LiveStatus.unknown;

  /// Playing a recording or replay.
  bool get isRecord => effectiveLiveStatus == LiveStatus.replay;

  /// The restriction, or [LiveRestriction.none] when the response did not say.
  LiveRestriction get effectiveRestriction => restriction ?? LiveRestriction.none;

  /// Whether a restriction is known (for the card's mark).
  bool get isRestricted => effectiveRestriction != LiveRestriction.none;

  /// Where the follow page lists this broadcast: live rooms (restricted or not)
  /// as live, playable replays as replay, everything else as offline, including
  /// a carousel and a replay marked [LiveRestriction.unplayable].
  LiveFollowGroup get followGroup => switch (effectiveLiveStatus) {
    LiveStatus.live => LiveFollowGroup.live,
    LiveStatus.replay when restriction != LiveRestriction.unplayable => LiveFollowGroup.replay,
    _ => LiveFollowGroup.offline,
  };

  @override
  String toString() => 'LiveBroadcast(${effectiveLiveStatus.name})';
}
