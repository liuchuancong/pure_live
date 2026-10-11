// Module: lib/src/models/live/live_room/live_room.dart
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

import '../../../support/json.dart';
import '../../content/content_kind/content_kind.dart';
import '../../content/content_metadata/content_metadata.dart';
import '../../content/content_ref/content_ref.dart';
import '../../content/content_summary/content_summary.dart';
import '../anchor_summary/anchor_summary.dart';
import '../live_audience/live_audience.dart';
import '../live_audience_metric/live_audience_metric.dart';
import '../live_catch_up/live_catch_up.dart';
import '../live_restriction/live_restriction.dart';
import '../live_room_state/live_room_state.dart';

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
    /// 分区 / game / category as the source words it, plus its id when the site has one. The platform does not
    /// rename these or map them onto a shared taxonomy - a viewer searching "电竞" means the site's row, not ours.
    @JsonKey(fromJson: _text) String? area,
    @JsonKey(fromJson: _text) String? areaId,

    /// The room's web page, as the site builds it (acfun keys it on the anchor, weibo on the live id). A
    /// "在浏览器打开" item and a recorder's provenance note both read this instead of guessing a url pattern.
    @JsonKey(fromJson: _text) String? link,

    /// The pinned notice (公告). Distinct from [introduction]: sites carry both, and users read them as two
    /// different things on one page.
    @JsonKey(fromJson: _text) String? notice,

    /// The audience, with each figure keeping its own meaning. Null means the site stated nothing at all - which
    /// is not "0 人看过", and [viewers] keeps that distinction readable by callers.
    @JsonKey(fromJson: _audience, toJson: _audienceOut) LiveAudience? audience,

    /// Room introduction / announcement text, when the site keeps one apart from the title.
    @JsonKey(fromJson: _text) String? introduction,

    /// The audience figure exactly as the platform reported it, when it gave a bare number and named its kind.
    /// Prefer [audience], which can hold all three figures at once; this is the shorthand the sites that report
    /// exactly one number fill in, and it is read back through the getter below rather than stored twice.
    @JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? viewers,

    /// What [viewers] measures. Defaults to [LiveAudienceMetric.unknown] so a heat score cannot be printed as a
    /// headcount by omission.
    @JsonKey(fromJson: _metric) @Default(LiveAudienceMetric.unknown) LiveAudienceMetric viewersMetric,

    /// Followers / fan count when the room answer carries it (acfun's `user.fanCountValue` is a *label*, so that
    /// one goes in [extra] instead of being parsed into a number nobody asked for).
    @JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? followers,

    /// When the broadcast began, from a field the source stated. A room page's "已直播 2 小时" comes from here and
    /// from nowhere else.
    @JsonKey(fromJson: _at, toJson: formatUtc) DateTime? startedAt,

    /// Why an on-air room cannot be opened. [LiveRestriction.none] is the affirmative "the anonymous path may
    /// play this"; null means the site never said either way, which is *not* the same as none.
    @JsonKey(fromJson: _restriction, toJson: _restrictionName) LiveRestriction? restriction,

    /// The site's raw status value behind [state] (`liveType`, `watch_limit`, `show_status`, `status`). Kept so a
    /// code that stops mapping is visible in a stored row instead of having been silently folded into unknown.
    @JsonKey(fromJson: _intOrNull, toJson: _intOrNull) int? reportedStateCode,

    /// Whether the finished part of this broadcast is replayable, and how far back.
    @JsonKey(fromJson: _catchUp, toJson: _catchUpOut) LiveCatchUp? catchUp,

    /// The programme join, when the site publishes one (and for channel-shaped sources, when our EPG has a row to
    /// match it against).
    @JsonKey(fromJson: _text) String? epgId,
    @JsonKey(fromJson: _text) String? currentProgramme,
    @JsonKey(fromJson: _text) String? currentProgrammeDescription,

    /// The broadcast is scheduled for later as well as not-yet-on-air. Only meaningful with
    /// [LiveRoomState.notStarted], and it is what a reminder can be offered on.
    @Default(false) bool isScheduled,

    /// The liveId / stream name this answer describes, when the source has one distinct from the room id. It is
    /// per-broadcast: storing it as the ref would orphan the room the moment the anchor goes off air.
    @JsonKey(fromJson: _text) String? streamId,

    @JsonKey(fromJson: _stringList, toJson: _stringListOut) @Default(<String>[]) List<String> tags,

    /// The headers the media address needs, per room (a referer pinned to the room page, a session cookie, a
    /// device id). The player reads these and nothing else, so this is the only place a source can say "the url
    /// alone is not enough".
    @JsonKey(fromJson: _stringMap, toJson: _stringMapOut) @Default(<String, String>{}) Map<String, String> headers,

    /// The site's own continuation payload for playback (a signed descriptor, a visitor session, a ticket list).
    /// Opaque on purpose: the source produced it and only the source can read it. Passing it back is what keeps
    /// one room open at one request instead of four - the reference product plays the same trick with `data`.
    @JsonKey(fromJson: _map, toJson: _mapOut) @Default(<String, Object?>{}) Map<String, Object?> sitePayload,

    /// The same idea for the danmaku socket: the handshake material the play path already obtained (the
    /// reference product's `danmakuData`).
    @JsonKey(fromJson: _map, toJson: _mapOut) @Default(<String, Object?>{}) Map<String, Object?> danmakuPayload,

    /// Whatever this site states that this shape cannot name. The bar for a key here is "the platform said it and
    /// we have no field for it" - not "this was convenient".
    @JsonKey(fromJson: _map, toJson: _mapOut) @Default(<String, Object?>{}) Map<String, Object?> extra,
  }) = _LiveRoom;

  const LiveRoom._();

  factory LiveRoom.fromJson(Map<String, Object?> json) => _$LiveRoomFromJson(json);

  bool get isLive => state == LiveRoomState.live;

  /// The number a surface shows, or null when nothing was stated. Reads [audience] first, so a site that
  /// reports all three figures at once is not flattened to whichever one [viewers] happens to hold.
  int? get audiencePrimary => audience?.primary ?? viewers;

  /// What [audiencePrimary] measures: the metric the site named, never one we assumed.
  LiveAudienceMetric get audienceMetric => audience?.metric ?? viewersMetric;

  /// Whether [audiencePrimary] counts people. False means "do not print this as 人在看" - it is a heat score, or
  /// the site never said what the number is.
  bool get audienceCountsPeople => audience?.countsPeople ?? (viewersMetric != LiveAudienceMetric.unknown);

  /// The shorthand for "something stands between the viewer and this stream". Derived, so a site cannot set it
  /// against its own [restriction] and leave the two disagreeing.
  bool get requiresAuth => restriction != null && restriction != LiveRestriction.none;

  /// The row the room page lists and a follow entry stores: the room is the content, the anchor is a column.
  ContentSummary get summary => ContentSummary(
    ref: ref,
    title: title.isNotEmpty ? title : (anchorName ?? ''),
    subtitle: <String>[if (anchorName != null) anchorName!, if (area != null) area!].join(' · '),
    cover: cover,
    metadata: ContentMetadata(popularity: audiencePrimary, extra: extra),
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

LiveAudience? _audience(Object? value) {
  final map = value is Map ? Map<String, Object?>.from(value) : null;
  return map == null || map.isEmpty ? null : LiveAudience.fromJson(map);
}

Object? _audienceOut(LiveAudience? value) => value?.toJson();

LiveAudienceMetric _metric(Object? value) =>
    enumByName(LiveAudienceMetric.values, value as String?) ?? LiveAudienceMetric.unknown;

LiveRestriction? _restriction(Object? value) => value == null ? null : enumByName(LiveRestriction.values, '$value');

String? _restrictionName(LiveRestriction? value) => value?.name;

LiveCatchUp? _catchUp(Object? value) {
  final map = value is Map ? Map<String, Object?>.from(value) : null;
  return map == null || map.isEmpty ? null : LiveCatchUp.fromJson(map);
}

Object? _catchUpOut(LiveCatchUp? value) => value?.toJson();

Map<String, String> _stringMap(Object? value) => <String, String>{
  for (final entry in asObjectMap(value).entries)
    if (entry.value is String && '${entry.value}'.isNotEmpty) '${entry.key}': '${entry.value}',
};

Map<String, String> _stringMapOut(Map<String, String> value) => value;
