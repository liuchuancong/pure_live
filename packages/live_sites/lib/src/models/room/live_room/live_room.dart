import 'package:freezed_annotation/freezed_annotation.dart';
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

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_room.freezed.dart';
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
/// [local] (per-user state) and [runtime] (transient handles, never stored).
@freezed
abstract class LiveRoom with _$LiveRoom {
  /// The normalized-fields constructor (code generation and copyWith
  /// target); fields are already normalized — construct through
  /// [LiveRoom.normalized] unless the caller normalized upstream.
  const factory LiveRoom({
    required LiveRoomRef ref,
    @Default(RoomContent()) RoomContent content,
    @Default(RoomAudience()) RoomAudience audience,
    @Default(RoomBroadcast()) RoomBroadcast broadcast,
    @Default(RoomLinks()) RoomLinks links,
    @Default(RoomGuide()) RoomGuide guide,
    @Default(RoomLocal()) RoomLocal local,
    @Default(RoomRuntime()) @JsonKey(includeFromJson: false, includeToJson: false) RoomRuntime runtime,
    LiveAnchor? anchor,
    LiveArea? area,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _LiveRoom;

  /// Deserializes a stored JSON record.
  factory LiveRoom.fromJson(Map<String, Object?> json) => _$LiveRoomFromJson(json);

  /// Adapter entry point: normalizes identity once (platform lower-cased,
  /// ids trimmed) and delegates. Must stay idempotent.
  factory LiveRoom.normalized({
    String platform = '',
    String roomId = '',
    RoomContent content = const RoomContent(),
    RoomAudience audience = const RoomAudience(),
    RoomBroadcast broadcast = const RoomBroadcast(),
    RoomLinks links = const RoomLinks(),
    RoomGuide guide = const RoomGuide(),
    RoomLocal local = const RoomLocal(),
    RoomRuntime runtime = const RoomRuntime(),
    LiveAnchor? anchor,
    LiveArea? area,
  }) => LiveRoom(
    ref: LiveRoomRef(platform: platform.trim().toLowerCase(), roomId: roomId.trim()),
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
}

/// Identity accessors and the sparse refresh merge for [LiveRoom].
///
/// A separate extension because freezed cannot implement a private
/// generative constructor next to the required `ref` parameter.
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
    return copyWith(
      content: content.mergedWith(incoming.content),
      audience: audience.mergedWith(incoming.audience),
      broadcast: broadcast.mergedWith(incoming.broadcast),
      anchor: incoming.anchor ?? anchor,
      area: incoming.area ?? area,
      guide: incoming.guide == const RoomGuide() ? guide : incoming.guide,
      createdAt: createdAt ?? incoming.createdAt,
      updatedAt: incoming.updatedAt ?? updatedAt,
    );
  }
}
