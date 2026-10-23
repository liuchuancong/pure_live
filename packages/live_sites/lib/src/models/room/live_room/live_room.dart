// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/guide/room_guide/room_guide.dart';
import 'package:live_sites/src/models/room/live_room_ref/live_room_ref.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/models/room/room_local/room_local.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'live_room.g.dart';

/// A live room: what lists show, what the room page loads, and what is
/// stored for follows and history.
///
/// Identity lives in [ref]; `LiveRoom` compares by value (all fields), so a
/// refreshed title makes a new value — identity checks, dedup and merging
/// always go through `room.ref` / `ref.identityKey` (MODELS.md §1.5.1).
/// Every concern is its own sub-object: [anchor] (broadcaster), [area]
/// (category), [audience] (viewer counts), [broadcast] (state),
/// [content] (display text), [links] (web/app/share), [guide] (IPTV),
/// [local] (per-user state) and [runtime] (transient handles, never
/// stored).
abstract class LiveRoom implements Built<LiveRoom, LiveRoomBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LiveRoom([void Function(LiveRoomBuilder)? updates]) = _$LiveRoom;

  /// The normalized-fields constructor; fields are already normalized —
  /// construct through [LiveRoom.normalized] unless the caller normalized
  /// upstream.
  /// The normalized-fields constructor; fields are already normalized —
  /// construct through [LiveRoom.normalized] unless the caller normalized
  /// upstream.
  factory LiveRoom.of({
    required LiveRoomRef ref,
    RoomContent? content,
    RoomAudience? audience,
    RoomBroadcast? broadcast,
    RoomLinks? links,
    RoomGuide? guide,
    RoomLocal? local,
    RoomRuntime? runtime,
    LiveAnchor? anchor,
    LiveArea? area,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LiveRoom(
    (b) => b
      ..ref.replace(ref)
      ..content.replace(content ?? RoomContent())
      ..audience.replace(audience ?? RoomAudience())
      ..broadcast.replace(broadcast ?? RoomBroadcast())
      ..links.replace(links ?? RoomLinks())
      ..guide.replace(guide ?? RoomGuide())
      ..local.replace(local ?? RoomLocal())
      ..runtime = (runtime ?? RoomRuntime()).toBuilder()
      ..anchor = anchor?.toBuilder()
      ..area = area?.toBuilder()
      ..createdAt = createdAt
      ..updatedAt = updatedAt,
  );

  LiveRoom._();

  /// Deserializes a stored JSON record.
  factory LiveRoom.fromJson(Map<String, Object?> json) => serializers.deserializeWith(LiveRoom.serializer, json)!;

  /// Adapter entry point: normalizes identity once (platform lower-cased,
  /// ids trimmed) and delegates. Must stay idempotent.
  factory LiveRoom.normalized({
    String platform = '',
    String roomId = '',
    RoomContent? content,
    RoomAudience? audience,
    RoomBroadcast? broadcast,
    RoomLinks? links,
    RoomGuide? guide,
    RoomLocal? local,
    RoomRuntime? runtime,
    LiveAnchor? anchor,
    LiveArea? area,
  }) => LiveRoom.of(
    ref: LiveRoomRef.of(platform: platform.trim().toLowerCase(), roomId: roomId.trim()),
    content: content,
    audience: audience,
    broadcast: broadcast,
    links: links,
    guide: guide,
    local: local,
    runtime: runtime,
    anchor: anchor,
    area: area,
  );

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LiveRoomBuilder b) => b
    ..content.replace(RoomContent())
    ..audience.replace(RoomAudience())
    ..broadcast.replace(RoomBroadcast())
    ..links.replace(RoomLinks())
    ..guide.replace(RoomGuide())
    ..local.replace(RoomLocal())
    ..runtime.replace(RoomRuntime());

  /// The serializer built_value registers in [serializers].
  static Serializer<LiveRoom> get serializer => _$liveRoomSerializer;

  /// The room's identity.
  LiveRoomRef get ref;

  /// The room's display text and imagery.
  RoomContent get content;

  /// The room's audience figures.
  RoomAudience get audience;

  /// The room's broadcast state.
  RoomBroadcast get broadcast;

  /// How to reach the room outside the app.
  RoomLinks get links;

  /// The IPTV side of the room, when it is a channel.
  RoomGuide get guide;

  /// The per-user, this-device-only state.
  RoomLocal get local;

  /// The transient handles; never serialized.
  RoomRuntime get runtime;

  /// The broadcaster, when the source carries one.
  LiveAnchor? get anchor;

  /// The category, when the source carries one.
  LiveArea? get area;

  /// When the record was created.
  DateTime? get createdAt;

  /// When the record was last updated.
  DateTime? get updatedAt;
}

/// Identity accessors and the sparse refresh merge for [LiveRoom].
extension LiveRoomIdentity on LiveRoom {
  /// The platform id (lower case).
  String get platform => ref.platform;

  /// The room id within the platform.
  String get roomId => ref.roomId;

  /// `platform:roomId` — the identity used by follows, tags and merges.
  String get identityKey => ref.identityKey;

  /// A sparse refresh merge: fields [incoming] left out never erase stored
  /// values; local tags and runtime handles stay this room's own.
  LiveRoom mergedWith(LiveRoom incoming) {
    if (ref != incoming.ref) return this;
    return rebuild(
      (b) => b
        ..content.replace(content.mergedWith(incoming.content))
        ..audience.replace(audience.mergedWith(incoming.audience))
        ..broadcast.replace(broadcast.mergedWith(incoming.broadcast))
        ..anchor = (incoming.anchor ?? anchor)?.toBuilder()
        ..area = (incoming.area ?? area)?.toBuilder()
        ..guide.replace(incoming.guide == RoomGuide() ? guide : incoming.guide)
        ..createdAt = createdAt ?? incoming.createdAt
        ..updatedAt = updatedAt ?? incoming.updatedAt,
    );
  }
}
