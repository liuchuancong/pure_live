// Module: lib/src/models/live/live_room.dart
// Purpose: 直播间本身 - one room, described once, with the live facts as fields instead of string keys.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/capability-contract.md §1 (the live surface). This is the object a live source hands a
// room page, a recorder and a follow-list poller, and it is the reason `models/live/` exists: what a room is
// (anchor, area, on-air state, whether it is paid, when the broadcast began) is live-domain knowledge, and it
// does not belong smuggled through `ContentMetadata.extra` under keys each site spells differently.
//
// A source that already answers `liveStatus` and `detail` can build this from the same envelope - the point of
// the model is that the *caller* stops reading a map.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../support/json.dart';
import '../content/content_ref.dart';
import 'anchor_summary.dart';
import 'live_room_state.dart';

part 'live_room.freezed.dart';
part 'live_room.g.dart';

/// One live room as its source described it.
@freezed
abstract class LiveRoom with _$LiveRoom {
  const factory LiveRoom({
    /// The room's own ref. Some sites address a room by the anchor (acfun), some by a room id (huya, douyu);
    /// this is whichever the source uses, and it is what `resolve` and `liveStatus` must be handed back.
    @JsonKey(fromJson: refFromJson, toJson: refToJson) required ContentRef ref,

    /// On air, ended, scheduled, or the source could not tell. [LiveRoomState.unknown] is not [LiveRoomState.ended]:
    /// a poll that timed out and is stored as "finished" makes a follow list stop watching a live stream.
    @JsonKey(fromJson: _state) required LiveRoomState state,

    /// The title as the room set it, not the anchor's name. Empty is allowed - some rooms have no title, and a
    /// surface then shows [anchorName] - but it is never filled in by guessing.
    required String title,
    @JsonKey(fromJson: _text) String? anchorName,

    /// The anchor's own id when the answer carries it separately from the room id (douyu's `owner_id`, huya's
    /// `sponsorInfo.uid`). Null means the source did not distinguish them.
    @JsonKey(fromJson: _text) String? anchorId,
    @JsonKey(fromJson: _text) String? avatar,
    @JsonKey(fromJson: _text) String? cover,

    /// 分区 / game / category as the source words it. The platform does not rename these or map them onto a
    /// shared taxonomy - a viewer searching "电竞" means the site's row, not ours.
    @JsonKey(fromJson: _text) String? area,

    /// Room introduction / announcement text, when the site keeps one apart from the title.
    @JsonKey(fromJson: _text) String? introduction,

    /// The audience figure exactly as the platform reported it. Null is "it did not say" - which is not zero, and
    /// a room page that shows "0 人看过" for an unstated count is putting a number on the site's silence.
    @JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? viewers,

    /// Followers / fan count when the room answer carries it (acfun's `user.fanCountValue` is a *label*, so that
    /// one goes in [extra] instead of being parsed into a number nobody asked for).
    @JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? followers,

    /// When the broadcast began, from a field the source stated. A room page's "已直播 2 小时" comes from here and
    /// from nowhere else.
    @JsonKey(fromJson: _at, toJson: formatUtc) DateTime? startedAt,

    /// The stream is behind a paywall, a fan club gate, or an account the anonymous path cannot satisfy. Set it
    /// when the source says so: a viewer who pressed play and got a black screen with no explanation blames the
    /// player, and this is the field that lets the surface say why instead.
    @Default(false) bool requiresAuth,

    /// The broadcast is scheduled for later as well as not-yet-on-air. Only meaningful with
    /// [LiveRoomState.notStarted], and it is what a reminder can be offered on.
    @Default(false) bool isScheduled,

    /// The liveId / stream name this answer describes, when the source has one distinct from the room id. It is
    /// per-broadcast: storing it as the ref would orphan the room the moment the anchor goes off air.
    @JsonKey(fromJson: _text) String? streamId,

    @JsonKey(fromJson: _stringList, toJson: _stringListOut) @Default(<String>[]) List<String> tags,

    /// Whatever this site states that this shape cannot name. The bar for a key here is "the platform said it and
    /// we have no field for it" - not "this was convenient".
    @JsonKey(fromJson: _map, toJson: _mapOut) @Default(<String, Object?>{}) Map<String, Object?> extra,
  }) = _LiveRoom;

  const LiveRoom._();

  factory LiveRoom.fromJson(Map<String, Object?> json) => _$LiveRoomFromJson(json);

  bool get isLive => state == LiveRoomState.live;

  /// The row the room page lists and a follow entry stores: the room is the content, the anchor is a column.
  ContentSummary get summary => ContentSummary(
    ref: ref,
    title: title.isNotEmpty ? title : (anchorName ?? ''),
    subtitle: <String>[if (anchorName != null) anchorName!, if (area != null) area!].join(' · '),
    cover: cover,
    metadata: ContentMetadata(popularity: viewers, extra: extra),
  );

  /// The person, when the answer named them: an anchor row a surface can link to.
  AnchorSummary? anchor() {
    final name = anchorName;
    if (name == null || name.isEmpty) {
      return null;
    }
    return AnchorSummary(
      ref: ContentRef(sourceId: ref.sourceId, contentId: anchorId ?? ref.contentId, kind: ContentKind.anchor),
      name: name,
      avatar: avatar,
      fans: followers,
      currentRoom: isLive ? ref : null,
    );
  }
}

LiveRoomState _state(Object? value) => enumByName(LiveRoomState.values, value as String?) ?? LiveRoomState.unknown;

String? _text(Object? value) => value is String && value.trim().isNotEmpty ? value.trim() : null;

int? _intOrNull(Object? value) => switch (value) {
  final num number => number.toInt(),
  final String text => int.tryParse(text.trim()),
  _ => null,
};

DateTime? _at(Object? value) => parseUtc(value);

List<String> _stringList(Object? value) => <String>[
  for (final item in value is List ? value : const <Object?>[])
    if ('${item ?? ''}'.trim().isNotEmpty) '${item}'.trim(),
];

List<String> _stringListOut(List<String> value) => value;

Map<String, Object?> _map(Object? value) => asObjectMap(value);

Map<String, Object?> _mapOut(Map<String, Object?> value) => value;
