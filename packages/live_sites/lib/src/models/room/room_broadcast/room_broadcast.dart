// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/enums/live_follow_group.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_room_activity.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'room_broadcast.g.dart';

/// The broadcast state of a room: status, start time, restriction, format.
///
/// [liveStatus] null = the source said nothing (≠ [LiveStatus.unknown],
/// which is an explicit unknown).
abstract class RoomBroadcast implements Built<RoomBroadcast, RoomBroadcastBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory RoomBroadcast([void Function(RoomBroadcastBuilder)? updates]) = _$RoomBroadcast;

  /// Creates a RoomBroadcast with already-normalized fields.
  /// Creates a RoomBroadcast with already-normalized fields.
  factory RoomBroadcast.of({
    LiveStatus? liveStatus,
    DateTime? startedAt,
    LiveRestriction? restriction,
    LiveRoomActivity activity = LiveRoomActivity.none,
  }) => RoomBroadcast(
    (b) => b
      ..liveStatus = liveStatus
      ..startedAt = startedAt
      ..restriction = restriction
      ..activity = activity,
  );

  RoomBroadcast._();

  /// Deserializes a stored JSON record.
  factory RoomBroadcast.fromJson(Map<String, Object?> json) =>
      serializers.deserializeWith(RoomBroadcast.serializer, json)!;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(RoomBroadcastBuilder b) => b..activity = LiveRoomActivity.none;

  /// The serializer built_value registers in [serializers].
  static Serializer<RoomBroadcast> get serializer => _$roomBroadcastSerializer;

  /// The platform's live status, when it said one.
  LiveStatus? get liveStatus;

  /// When the current session started.
  DateTime? get startedAt;

  /// A restriction on playing the room.
  LiveRestriction? get restriction;

  /// A special activity the room is running.
  LiveRoomActivity get activity;

  /// The state used for display and playback; unknown when not given.
  LiveStatus get effectiveLiveStatus => liveStatus ?? LiveStatus.unknown;

  /// Broadcasting now, restricted or not.
  bool get isLiveNow => effectiveLiveStatus == LiveStatus.live;

  /// Live, replay or carousel: something can be played.
  bool get isPlayableNow => switch (effectiveLiveStatus) {
    LiveStatus.live || LiveStatus.replay || LiveStatus.carousel => true,
    _ => false,
  };

  /// The platform said offline, banned or carousel: the streamer is off.
  bool get isExplicitlyOfflineNow => switch (effectiveLiveStatus) {
    LiveStatus.offline || LiveStatus.banned || LiveStatus.carousel => true,
    _ => false,
  };

  /// The state has not been resolved yet.
  bool get isPending => effectiveLiveStatus == LiveStatus.unknown;

  /// Playing a recording or replay.
  bool get isRecord => effectiveLiveStatus == LiveStatus.replay;

  /// The restriction, or [LiveRestriction.none] when the source said nothing.
  LiveRestriction get effectiveRestriction => restriction ?? LiveRestriction.none;

  /// A restriction is known (for the card's mark).
  bool get isRestricted => effectiveRestriction != LiveRestriction.none;

  /// The group the follow page lists this room under.
  LiveFollowGroup get followGroup => switch (effectiveLiveStatus) {
    LiveStatus.live => LiveFollowGroup.live,
    LiveStatus.replay when effectiveRestriction != LiveRestriction.unplayable => LiveFollowGroup.replay,
    _ => LiveFollowGroup.offline,
  };

  /// A sparse refresh merge: an omitted value never erases a stored one,
  /// and a changed status invalidates the previous start time.
  RoomBroadcast mergedWith(RoomBroadcast incoming) {
    final sameStatus = switch ((liveStatus, incoming.liveStatus)) {
      (_, null) || (_, LiveStatus.unknown) => true,
      (final current, final next) => current == next,
    };
    return rebuild(
      (b) => b
        ..liveStatus = incoming.liveStatus ?? liveStatus
        ..startedAt = incoming.startedAt ?? (sameStatus ? startedAt : null)
        ..restriction = incoming.restriction ?? (sameStatus ? restriction : null)
        ..activity = incoming.activity != LiveRoomActivity.none ? incoming.activity : activity,
    );
  }
}
