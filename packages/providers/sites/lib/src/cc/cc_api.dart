// Module: lib/src/cc/cc_api.dart
// Purpose: 网易CC直播的请求面:Dashen 目录两块拼装、分类与推荐的 start/size 翻页、房间两步换址、主播搜索,
// 以及按清晰度分组的多 CDN 线路读法。
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoints, the two-endpoint catalogue assembly, the official-entry destination rules, the tier
// reflect table, the cdn priority and the `startat` UTC+8 reading follow the v1-maintained CC line
// (origin/master lib/shared/platforms/cc/). Fresh implementation against the v2 capability contracts, not a file
// merge (UPSTREAM_REVIEW_POLICY.md).
//
// A site is two files (docs/architecture/package-architecture.md §2.1): this one owns the requests and how their
// answers are read, cc_site.dart owns the capability answers. No model file.
//
// The rules that are worth more than the endpoint list:
//   * **the legacy category endpoint is gone**. The old one now serves the Dashen application, so the menu is
//     assembled from two endpoints: a public **game registry** (names and artwork, not categories) and an
//     **official live-entry configuration** whose itemList selects which of those games are navigable at all.
//     An entry whose game is missing, whose destination is not an `https://cc.163.com` route the site owns, or
//     whose identity repeats is a changed configuration and fails the whole menu rather than dropping a row.
//   * **two audience scales arrive in one payload**. `webcc_visitor` / `hot_score` / `visitor` / `total_visitor`
//     are the platform's heat value; `vision_visitor` / `online_num` are the people watching now. Keeping both is
//     what stops 50 万热度 from being drawn as 50 万人在线.
//   * **a title can say 重播 while the status field says live**. The site streams a rebroadcast in the live slot,
//     so the room stays playable and the tag is what tells the truth.
//   * **the page width is the site's own 30**. Offsets are `start = (page-1)*30` regardless of what the caller's
//     surface shows, so a resized view does not resample the same rooms; an answer longer than asked is a schema
//     change, and a malformed row fails the page instead of committing an empty one.
//   * **the tier table is the site's wording, and unknown keys keep theirs**. `blueray`/`original` are 原画 and
//     `ultra` is 蓝光 because that is what CC publishes; a key outside that table is listed under its own name
//     rather than renamed to the nearest guess. `vbr` is absent for the untouched stream, which is why the tier
//     name - not a missing bitrate - decides its place in the menu.
//   * **one room costs two calls**. The anchor endpoint names the channel, the channel endpoint carries the
//     streams; the anchor answer is keyed by the id that was asked for, and that key is the identity evidence.

import 'dart:convert';

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import '../common/site_json.dart';

const String ccSourceId = 'cc.live';
const String ccWebOrigin = 'https://cc.163.com';
const String ccApiOrigin = 'https://api.cc.163.com';
const String ccDashenOrigin = 'https://inf.ds.163.com';
const String ccDashenActOrigin = 'https://inf-act.ds.163.com';

const String ccUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

const Map<String, String> ccWebHeaders = <String, String>{'user-agent': ccUserAgent};

/// The Dashen configuration the live-entry list lives in. Its id is published in the site's own page and the
/// answer has to carry it back, or the menu was assembled from someone else's configuration.
const String ccCatalogConfigurationId = '67b32cdd1801fc391a6c2657';

/// The width every listing is asked at. Not the surface's page size: the offsets have to stay stable when a
/// viewer resizes the grid.
const int ccNativePageSize = 30;

/// The most rows one listing answer may carry.
const int ccRowLimit = 1000;

/// The anchor search's own ceiling, kept from v1.
const int ccSearchPageSizeLimit = 50;

/// The cdn families the site itself prefers, in its order. Lines inside a tier are listed by this table so the
/// player's first pick is the one the site would have picked.
const List<String> ccCdnPriority = <String>['hs', 'ks', 'ali', 'fws', 'wy'];

/// The tier names CC publishes for its own keys.
const Map<String, String> ccTierLabels = <String, String>{
  'blueray': '原画',
  'original': '原画',
  'high': '高清',
  'medium': '标准',
  'standard': '标准',
  'low': '低清',
  'ultra': '蓝光',
};

/// The menu weight of a tier key. The untouched stream ships no `vbr`, so a bitrate-only sort would put 原画 at
// the bottom because its metadata happens to be absent.
const Map<String, int> ccTierRanks = <String, int>{
  'blueray': 6,
  'original': 6,
  'origin': 6,
  'source': 6,
  'ultra': 5,
  'high': 4,
  'hd': 4,
  'medium': 3,
  'standard': 3,
  'sd': 3,
  'low': 2,
  'ld': 2,
};

/// A cc answer that is not the answer we asked for.
final class CcFailure implements Exception {
  const CcFailure(this.message, {this.code, this.cause, this.missing = false});

  final String message;
  final int? code;
  final Object? cause;

  /// "There is no such room or no such configuration." Not an offline room and not the service.
  final bool missing;

  @override
  String toString() => 'CcFailure($message${code == null ? '' : ', code $code'}${cause == null ? '' : ': $cause'})';
}

/// One navigable entry of the assembled menu.
final class CcEntry {
  const CcEntry({required this.id, required this.name, required this.parentId, required this.label, this.icon});

  /// A game's numeric id, or `official:<id>` for an entry that is a destination rather than a listing.
  final String id;
  final String name;
  final String parentId;

  /// Which half of the configuration this came from: the site's category label or its official-entry label.
  final String label;
  final String? icon;

  bool get isOfficial => id.startsWith('official:');

  ContentCategory toContentCategory() => ContentCategory(id: id, name: name, parentId: parentId, icon: icon);
}

/// One tier with its cdn lines.
final class CcQuality {
  const CcQuality({required this.key, required this.label, required this.sort, required this.urls, this.bitrateKbps});

  /// The site's own tier key (`blueray`, `high`, …). Also the id a caller hands back.
  final String key;

  /// CC's published name for that key, or the key itself when the table does not know it.
  final String label;
  final int sort;
  final List<String> urls;

  /// `vbr`, when the answer stated one. The untouched tier does not, and its absence is not zero.
  final int? bitrateKbps;
}

/// One room as an endpoint described it.
final class CcRoom {
  const CcRoom({
    required this.roomId,
    required this.state,
    required this.isReplayTitle,
    this.anchorId,
    this.channelId,
    this.title = '',
    this.nick = '',
    this.avatar,
    this.cover,
    this.area,
    this.popularity,
    this.onlineViewers,
    this.followers,
    this.introduction,
    this.notice,
    this.startedAt,
    this.qualities = const <CcQuality>[],
    this.playUrl,
  });

  /// `cuteid` - the handle in `cc.163.com/<cuteid>`, and the id the caller stored.
  final String roomId;
  final LiveRoomState state;

  /// The title starts with the site's own 重播 mark while the status field still says live: the stream plays, and
  /// the tag is the truth about what it is.
  final bool isReplayTitle;

  /// `cid` - the anchor, when the answer carried it separately.
  final String? anchorId;

  /// `channel_id` / `ccid`: the live channel the streams hang off. Per broadcast, so it is a stream id and not a
  /// ref.
  final String? channelId;
  final String title;
  final String nick;
  final String? avatar;
  final String? cover;
  final String? area;

  /// The two scales, kept apart (see the file header).
  final int? popularity;
  final int? onlineViewers;
  final int? followers;
  final String? introduction;
  final String? notice;
  final DateTime? startedAt;
  final List<CcQuality> qualities;

  /// The m3u8 the channel answer gives outright. Some rooms ship tiers and some ship only this.
  final String? playUrl;

  CcRoom copyWith({List<CcQuality>? qualities, String? playUrl}) => CcRoom(
    roomId: roomId,
    state: state,
    isReplayTitle: isReplayTitle,
    anchorId: anchorId,
    channelId: channelId,
    title: title,
    nick: nick,
    avatar: avatar,
    cover: cover,
    area: area,
    popularity: popularity,
    onlineViewers: onlineViewers,
    followers: followers,
    introduction: introduction,
    notice: notice,
    startedAt: startedAt,
    qualities: qualities ?? this.qualities,
    playUrl: playUrl ?? this.playUrl,
  );

  LiveRoom toLiveRoom() => LiveRoom(
    ref: ContentRef(sourceId: ccSourceId, contentId: roomId, kind: ContentKind.liveRoom),
    state: state,
    title: title,
    anchorName: nick.isEmpty ? null : nick,
    anchorId: anchorId,
    avatar: avatar,
    cover: cover,
    area: area,
    link: '$ccWebOrigin/$roomId/',
    introduction: introduction,
    notice: notice,
    followers: followers,
    audience: LiveAudience(
      onlineViewers: onlineViewers,
      // The heat number keeps its own field: a room that reports both is not reporting one of them twice.
      popularity: popularity,
      metric: onlineViewers != null ? LiveAudienceMetric.onlineViewers : LiveAudienceMetric.popularity,
    ),
    startedAt: startedAt,
    restriction: restriction,
    streamId: channelId,
    tags: <String>[if (isReplayTitle) '重播'],
    danmakuPayload: <String, Object?>{'cuteid': roomId, if (channelId != null) 'channelId': channelId},
    headers: ccWebHeaders,
    sitePayload: <String, Object?>{
      if (channelId != null) 'cc.channelId': channelId,
      if (playUrl != null) 'cc.m3u8': playUrl,
    },
    extra: <String, Object?>{if (isReplayTitle) 'cc.replayTitle': true},
  );

  /// The gate the answer states. A live room with neither tiers nor a direct address cannot be opened, which is a
  /// different fact from "this room is not broadcasting".
  LiveRestriction? get restriction {
    if (state != LiveRoomState.live) {
      return null;
    }
    return qualities.isEmpty && playUrl == null ? LiveRestriction.unplayable : LiveRestriction.none;
  }

  AnchorSummary toAnchorSummary() => AnchorSummary(
    ref: ContentRef(sourceId: ccSourceId, contentId: roomId, kind: ContentKind.anchor),
    name: nick.isEmpty ? title : nick,
    avatar: avatar,
    fans: followers,
    currentRoom: state == LiveRoomState.live
        ? ContentRef(sourceId: ccSourceId, contentId: roomId, kind: ContentKind.liveRoom)
        : null,
  );
}

/// A room id (`cuteid`): positive, at most 32 digits, and never javascript's rounded double of a bigger number.
String ccRoomId(String value) {
  final id = value.trim();
  if (!RegExp(r'^[1-9][0-9]{0,31}$').hasMatch(id)) {
    throw CcFailure('not a cc room id: "$id"');
  }
  return id;
}

/// A game id from the configuration. The same shape is what the listing endpoint wants.
String ccGameId(String value) {
  final id = value.trim();
  if (!RegExp(r'^[1-9][0-9]{0,15}$').hasMatch(id)) {
    throw CcFailure('not a cc game id: "$id"');
  }
  return id;
}

/// The room id in a cc url, or null. `cc.163.com/<id>/` is the watch page; everything else on that host is a
/// page the site has for other reasons.
String? ccRoomFromUri(Uri uri) {
  if (!const <String>{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
      uri.host.toLowerCase() != 'cc.163.com' ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    return null;
  }
  final segments = <String>[
    for (final segment in uri.pathSegments)
      if (segment.isNotEmpty) segment,
  ];
  if (segments.length != 1) {
    return null;
  }
  try {
    return ccRoomId(segments.first);
  } on CcFailure {
    return null;
  }
}

/// The web destination of an official entry, rebuilt from its bounded identity.
///
/// A stored category never holds a url, so a saved entry cannot be pointed at another host or scheme later: the
/// destination is reconstructed from the id the configuration was checked against.
Uri? ccOfficialEntryUri(String id) {
  final raw = id.trim();
  if (!raw.startsWith('official:')) {
    return null;
  }
  final destination = raw.substring('official:'.length);
  if (!RegExp(r'^[1-9][0-9]{0,15}$').hasMatch(destination)) {
    return null;
  }
  return Uri.https('cc.163.com', '/$destination/', <String, String>{
    'open': 'blizzardtv',
    'from': '8382',
    'platform': 'ds',
  });
}

/// The audience, with both scales kept.
///
/// The site ships two different numbers in one payload and they are not the same measure; the aliases are tried
/// in the site's own order and a value is only taken when it actually contains a digit.
({int? popularity, int? onlineViewers}) ccAudience(Map<String, Object?> room) => (
  popularity: _firstNumber(<Object?>[room['webcc_visitor'], room['hot_score'], room['visitor'], room['total_visitor']]),
  onlineViewers: _firstNumber(<Object?>[room['vision_visitor'], room['online_num']]),
);

int? _firstNumber(List<Object?> values) {
  for (final value in values) {
    final text = value == null ? '' : '${value}'.trim();
    if (text == 'null' || text.isEmpty || !RegExp('[0-9]').hasMatch(text)) {
      continue;
    }
    final number = jsonInt(value);
    if (number != null && number >= 0) {
      return number;
    }
  }
  return null;
}

/// `startat` as the site writes it: `yyyy-MM-dd HH:mm:ss` in its own UTC+8 wall clock.
///
/// Converted to UTC by subtracting the offset the site's pages are published in, because a start time kept as a
/// local reading turns into "已直播 -3 小时" the moment the viewer's clock is somewhere else. A year before 2000
/// or an unparseable shape is "the site did not say".
DateTime? ccStartedAt(Object? raw) {
  final value = raw == null ? '' : '${raw}'.trim();
  final match = RegExp(r'^([0-9]{4})-([0-9]{2})-([0-9]{2}) ([0-9]{2}):([0-9]{2}):([0-9]{2})$').firstMatch(value);
  if (match == null) {
    return null;
  }
  final parts = <int?>[for (var index = 1; index <= 6; index++) int.tryParse(match.group(index) ?? '')];
  if (parts.any((int? part) => part == null)) {
    return null;
  }
  if (parts[0]! < 2000) {
    return null;
  }
  return DateTime.utc(
    parts[0]!,
    parts[1]!,
    parts[2]!,
    parts[3]!,
    parts[4]!,
    parts[5]!,
  ).subtract(const Duration(hours: 8));
}

/// The site's own mark for a rebroadcast running in the live slot.
bool ccIsReplayTitle(Object? raw) => '${raw ?? ''}'.trimLeft().startsWith('【重播】');

LiveRoomState ccState(Object? status, {required bool assumeLive}) {
  final code = jsonInt(status);
  if (code == 1) {
    return LiveRoomState.live;
  }
  if (code == 0) {
    return LiveRoomState.ended;
  }
  // A listing that carries no status at all is the site's live grid; a status that is neither 0 nor 1 is the site
  // not saying, which is unknown and not ended.
  return assumeLive ? LiveRoomState.live : LiveRoomState.unknown;
}

/// One listing row. Both listings (the recommendation block and a game's grid) answer the same shape.
CcRoom? ccListingRow(Object? raw, {required bool gameRow, bool assumeLive = false}) {
  final item = jsonMap(raw);
  if (item == null) {
    // v1 refused the whole page on a non-object row. Kept: this list is a snapshot a viewer scrolls, and a page
    // that quietly skipped a malformed row is a page that lost a room without saying so.
    throw const CcFailure('a listing row is not an object');
  }
  final rawId = item['cuteid'];
  if (rawId is! String && rawId is! int) {
    throw const CcFailure('a listing row carries no room id');
  }
  if (rawId is int && rawId > 9007199254740991) {
    throw const CcFailure('a listing row names an id past javascript exactness');
  }
  final roomId = ccRoomId('$rawId');
  final audience = ccAudience(item);
  final status = ccState(item['status'], assumeLive: assumeLive);
  final replay = ccIsReplayTitle(item['title']);
  final gameName = _firstText(<Object?>[item['game_name'], item['gamename']]);
  return CcRoom(
    roomId: roomId,
    state: status,
    isReplayTitle: replay,
    title: _text(item['title']),
    nick: _text(item['nickname']),
    avatar: _picture(item['purl']),
    // A game grid's `cover` and the search row's `portrait` are the same picture under two names.
    cover: _firstPicture(<Object?>[item['cover'], item['portrait']]),
    area: gameName,
    popularity: audience.popularity,
    onlineViewers: audience.onlineViewers,
    followers: jsonInt(item['follower_num']),
    startedAt: status == LiveRoomState.live ? ccStartedAt(item['startat']) : null,
    // A listing never carries the manifest: that is the two-call channel answer's job.
    playUrl: gameRow ? null : _m3u8(item['m3u8']),
  );
}

/// The channel answer's room row, with the payload the tiers hang off.
CcRoom ccChannelRoom(Map<String, Object?> room, {required String askedRoomId}) {
  final audience = ccAudience(room);
  final status = ccState(room['status'], assumeLive: false);
  final replay = ccIsReplayTitle(room['title']);
  final channelId = _text(room['ccid']);
  return CcRoom(
    // The caller's id is the ref: the anchor answer was keyed by it, and a stored favourite has to keep pointing
    // at the same room whatever the channel block happens to call itself today.
    roomId: askedRoomId,
    state: status,
    isReplayTitle: replay,
    anchorId: _emptyToNull(_text(room['cid'])),
    channelId: channelId.isEmpty ? null : channelId,
    title: _text(room['title']),
    nick: _text(room['nickname']),
    avatar: _picture(room['purl']),
    cover: _picture(room['cover']),
    area: _firstText(<Object?>[room['gamename'], room['game_name']]),
    popularity: audience.popularity,
    onlineViewers: audience.onlineViewers,
    followers: jsonInt(room['follower_num']),
    introduction: _emptyToNull(_text(room['personal_label'])),
    notice: _emptyToNull(_text(room['personal_label'])),
    startedAt: status == LiveRoomState.live ? ccStartedAt(room['startat']) : null,
    qualities: ccQualities(room, baseUrl: _m3u8(room['m3u8']) ?? ''),
    playUrl: _m3u8(room['m3u8']),
  );
}

/// The tiers, from either shape the channel answer ships.
///
/// `quickplay` is the live bundle, whose tiers carry `CDN_FMT` and whose line values are sometimes only a query
/// suffix that belongs on the room's own m3u8 address. `stream_list` is the recorded shape, whose tiers carry
/// `cdn` with complete urls. Reading one as the other is what puts a bare `?sign=` into the player.
List<CcQuality> ccQualities(Map<String, Object?> room, {String baseUrl = ''}) {
  final quickplay = jsonMap(room['quickplay']);
  final source = quickplay ?? jsonMap(room['stream_list']);
  if (source == null) {
    return const <CcQuality>[];
  }
  // A bundle whose tiers are the map itself versus one that nests them under `resolution`.
  final isLiveBundle = quickplay != null && source['resolution'] == null;
  final tiers = jsonMap(isLiveBundle ? source : source['resolution']) ?? const <String, Object?>{};
  final qualities = <CcQuality>[];
  for (final entry in tiers.entries) {
    final tier = jsonMap(entry.value);
    if (tier == null) {
      continue;
    }
    final cdn = jsonMap(isLiveBundle ? tier['CDN_FMT'] : tier['cdn']);
    if (cdn == null) {
      continue;
    }
    final key = '${entry.key}';
    final preferred = <String>[];
    final others = <String>[];
    for (final line in cdn.entries) {
      final url = isLiveBundle ? ccLiveLineUrl('$baseUrl', '${line.value}') : ccDirectUrl('${line.value}');
      if (url == null) {
        continue;
      }
      final target = ccCdnPriority.contains('${line.key}'.toLowerCase()) ? preferred : others;
      if (!target.contains(url)) {
        target.add(url);
      }
    }
    if (preferred.isEmpty && others.isEmpty) {
      continue;
    }
    final bitrate = jsonInt(tier['vbr']);
    qualities.add(
      CcQuality(
        key: key,
        label: ccTierLabels[key.toLowerCase()] ?? key,
        sort: ccTierSort(key, bitrate),
        bitrateKbps: bitrate,
        urls: List<String>.unmodifiable(<String>[...preferred, ...others]),
      ),
    );
  }
  qualities.sort((CcQuality left, CcQuality right) => right.sort.compareTo(left.sort));
  return List<CcQuality>.unmodifiable(qualities);
}

/// The menu weight: the published tier first, the bitrate as the tie-break inside it.
///
/// A key outside the table keeps its own name and sorts by bitrate alone, which is the honest reading: the site
/// never said where the new tier belongs among the old ones.
int ccTierSort(String rawKey, int? bitrateKbps) {
  final key = rawKey.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '');
  final rank = ccTierRanks[key] ?? 0;
  final bitrate = bitrateKbps ?? 0;
  return rank == 0 ? bitrate : rank * 1000000 + bitrate.clamp(0, 999999);
}

/// A live bundle's line value: a full url, a protocol-relative url, or a suffix for the room's own address.
String? ccLiveLineUrl(String baseUrl, String raw) {
  final value = raw.trim();
  if (value.startsWith('//')) {
    return _https('https:$value');
  }
  final direct = Uri.tryParse(value);
  if (direct != null && direct.hasScheme) {
    return const <String>{'http', 'https'}.contains(direct.scheme.toLowerCase()) && direct.userInfo.isEmpty
        ? value
        : null;
  }
  if (value.isEmpty) {
    return baseUrl.isEmpty ? null : _https(baseUrl);
  }
  if (baseUrl.isEmpty) {
    return null;
  }
  final suffix = value.replaceFirst(RegExp(r'^[?&]+'), '');
  return _https('${baseUrl}${baseUrl.contains('?') ? '&' : '?'}$suffix');
}

/// A recorded bundle's line value: a complete url, protocol-relative normalised.
String? ccDirectUrl(String raw) {
  final value = raw.trim();
  if (!value.startsWith('//')) {
    return _https(value);
  }
  return _https('https:$value');
}

String? _https(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !const <String>{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
    return null;
  }
  if (uri.userInfo.isNotEmpty || uri.hasFragment) {
    return null;
  }
  return value;
}

String? _m3u8(Object? raw) {
  final value = _text(raw);
  if (value.isEmpty || !Uri.parse(value).path.toLowerCase().endsWith('.m3u8')) {
    return null;
  }
  return _https(value);
}

String? _picture(Object? raw) {
  final value = _text(raw);
  if (value.isEmpty) {
    return null;
  }
  final candidate = value.startsWith('//') ? 'https:$value' : value;
  return Uri.tryParse(candidate)?.hasScheme ?? false ? candidate : null;
}

String _text(Object? raw) => raw is String ? raw.trim() : (raw == null ? '' : '${raw}'.trim());

String? _emptyToNull(String value) => value.isEmpty ? null : value;

String? _firstText(List<Object?> values) {
  for (final value in values) {
    final text = _text(value);
    if (text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

String? _firstPicture(List<Object?> values) {
  for (final value in values) {
    if (_picture(value) case final String url) {
      return url;
    }
  }
  return null;
}

/// The assembled menu, from the game registry and the live-entry configuration.
///
/// Both answers are needed and both are checked against each other: the registry alone would list games the site
/// has no live entry for, and the configuration alone would name entries we cannot show an icon or a label for.
List<CcEntry> ccCatalog(Object? games, Object? configuration) {
  final gameEnvelope = _envelope(games, 'game registry');
  final gameRows = _bounded(gameEnvelope['result'], 2000, 'game registry rows');
  final metadata = <String, Map<String, Object?>>{};
  for (final raw in gameRows) {
    final row = jsonMap(raw);
    if (row == null) {
      throw const CcFailure('a game row is not an object');
    }
    final key = _boundedText(row['appKey'], 64, 'game key');
    if (metadata.containsKey(key)) {
      throw CcFailure('the game registry repeats $key');
    }
    metadata[key] = row;
  }

  final configEnvelope = _envelope(configuration, 'live-entry configuration');
  final config = jsonMap(configEnvelope['result']);
  if (config == null) {
    throw const CcFailure('the live-entry configuration carries no result');
  }
  if ('${config['id']}' != ccCatalogConfigurationId) {
    throw const CcFailure('the configuration answer is about a different page');
  }
  if (_hidden(config)) {
    return const <CcEntry>[];
  }
  final groups = <Map<String, Object?>>[
    for (final raw in _bounded(config['itemList'], 256, 'configuration groups'))
      if (jsonMap(raw)?['name'] == '直播入口列表') jsonMap(raw)!,
  ];
  if (groups.length != 1) {
    throw CcFailure('the live-entry group is missing or ambiguous (${groups.length} matched)');
  }
  if (_hidden(groups.first)) {
    return const <CcEntry>[];
  }

  final entries = <CcEntry>[];
  final identities = <String>{};
  for (final raw in _bounded(groups.first['itemList'], 256, 'live entries')) {
    final entry = jsonMap(raw);
    if (entry == null) {
      throw const CcFailure('a live entry is not an object');
    }
    if (_hidden(entry)) {
      continue;
    }
    final key = _boundedText(entry['name'], 64, 'live entry name');
    final game = metadata[key];
    if (game == null) {
      throw CcFailure('the live entry $key has no game behind it');
    }
    final destination = Uri.tryParse(_boundedText(entry['content'], 2048, 'live entry destination'));
    if (destination == null ||
        destination.scheme != 'https' ||
        destination.host != 'cc.163.com' ||
        destination.userInfo.isNotEmpty ||
        destination.hasPort ||
        destination.hasFragment) {
      throw CcFailure('the live entry $key points somewhere the site does not own');
    }
    final category = RegExp(r'^/n/ds_category/([1-9][0-9]{0,15})/$').firstMatch(destination.path);
    final room = RegExp(r'^/([1-9][0-9]{0,15})/$').firstMatch(destination.path);
    if (category == null && room == null) {
      throw CcFailure('the live entry $key is a route this source cannot open');
    }
    final id = category != null ? category.group(1)! : 'official:${room!.group(1)}';
    if (!identities.add(id)) {
      throw CcFailure('the configuration lists $id twice');
    }
    entries.add(
      CcEntry(
        id: id,
        name: _boundedText(game['name'], 200, 'game name'),
        parentId: category != null ? '1' : 'official',
        label: category != null ? '直播分类' : '官方房间/专题',
        icon: _imageHost(game['icon']),
      ),
    );
  }
  return List<CcEntry>.unmodifiable(entries);
}

Map<String, Object?> _envelope(Object? value, String what) {
  final envelope = jsonMap(value);
  if (envelope == null) {
    throw CcFailure('the $what answer is not an object');
  }
  final code = jsonInt(envelope['code']);
  if (code == null) {
    throw CcFailure('the $what answer carries no code');
  }
  if (code != 200) {
    throw CcFailure('the $what endpoint refused', code: code, missing: code == 404);
  }
  return envelope;
}

List<Object?> _bounded(Object? value, int limit, String what) {
  if (value is! List || value.length > limit) {
    throw CcFailure('the $what list is missing or unreasonably long');
  }
  return value;
}

String _boundedText(Object? value, int limit, String what) {
  final text = _text(value);
  if (text.isEmpty || text.length > limit) {
    throw CcFailure('an unreadable $what');
  }
  return text;
}

bool _hidden(Map<String, Object?> value) {
  final flag = value['hidden'];
  if (flag != null && flag is! bool) {
    throw const CcFailure('a configuration visibility flag is not a bool');
  }
  return flag == true;
}

String? _imageHost(Object? raw) {
  final value = _text(raw);
  if (value.length > 2048) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    return null;
  }
  return value;
}

/// The CC client.
final class CcApi {
  CcApi({NetworkClient? client}) : _client = client ?? NetworkClient(), _ownsClient = client == null;

  final NetworkClient _client;
  final bool _ownsClient;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// The menu: the game registry plus the live-entry configuration that selects which games are navigable.
  Future<List<CcEntry>> catalog() async {
    final games = await _get(
      '$ccDashenOrigin/v1/web/game-center/basic/base-info-list/by-type',
      <String, String>{'gameType': 'NETEASE'},
      headers: <String, String>{
        'user-agent': ccUserAgent,
        'referer': 'https://ds.163.com/glive/',
        'origin': 'https://ds.163.com',
      },
      what: 'game registry',
    );
    final configuration = await _postJson(
      '$ccDashenActOrigin/v1/act-web/pageConf/commonAppConfig',
      <String, Object?>{'id': ccCatalogConfigurationId},
      headers: <String, String>{
        'user-agent': ccUserAgent,
        'referer': 'https://ds.163.com/glive/',
        'origin': 'https://ds.163.com',
      },
      what: 'live-entry configuration',
    );
    return ccCatalog(games, configuration);
  }

  /// One page of a game's grid. The row width is the site's 30 whatever the caller's surface shows.
  Future<List<CcRoom>> directory({required String gameId, int page = 1}) async {
    final game = ccGameId(gameId);
    _checkPage(page);
    final result = await _get(
      '$ccWebOrigin/api/category/$game/',
      <String, String>{
        'format': 'json',
        'tag_id': '0',
        'start': '${(page - 1) * ccNativePageSize}',
        'size': '$ccNativePageSize',
      },
      headers: ccWebHeaders,
      what: 'category listing',
    );
    // The answer names the game it is about; a redirect or a cache that answers another game's grid would put
    // someone else's rooms under this category label.
    if ('${result['gametype']}' != game) {
      throw CcFailure('the category answer is about game ${result['gametype']} while asking about $game');
    }
    return _rows(result['lives'], gameRow: true, what: 'category listing');
  }

  /// The recommendation block, at the same fixed width.
  Future<List<CcRoom>> home({int page = 1}) async {
    _checkPage(page);
    final result = await _get(
      '$ccWebOrigin/api/category/live/',
      <String, String>{'format': 'json', 'start': '${(page - 1) * ccNativePageSize}', 'size': '$ccNativePageSize'},
      headers: ccWebHeaders,
      what: 'recommendation listing',
    );
    return _rows(result['lives'], gameRow: false, assumeLive: true, what: 'recommendation listing');
  }

  /// The anchor search. Rows are people with a status flag, and they carry no manifest.
  Future<List<CcRoom>> search(String keyword, {int page = 1, int pageSize = ccNativePageSize}) async {
    final term = keyword.trim();
    if (term.isEmpty || term.length > 100 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(term)) {
      throw const CcFailure('a search term must be 1-100 printable characters');
    }
    _checkPage(page);
    final size = pageSize.clamp(1, ccSearchPageSizeLimit);
    final result = await _get(
      '$ccWebOrigin/search/anchor',
      <String, String>{'query': term, 'size': '$size', 'page': '$page'},
      headers: ccWebHeaders,
      what: 'anchor search',
    );
    final rows = jsonMap(result['webcc_anchor'])?['result'];
    if (rows is! List || rows.length > ccRowLimit) {
      throw const CcFailure('the anchor search carries no result list');
    }
    final seen = <String>{};
    return <CcRoom>[
      for (final raw in rows)
        if (ccListingRow(raw, gameRow: false, assumeLive: false) case final CcRoom room when seen.add(room.roomId))
          room,
    ];
  }

  /// The room, in the two calls the site needs: the anchor answer names the channel, the channel answer carries
  /// the streams.
  Future<CcRoom> room(String input) async {
    final roomId = ccRoomId(input);
    final anchor = await _get(
      '$ccApiOrigin/v1/activitylives/anchor/lives',
      <String, String>{'anchor_ccid': roomId},
      headers: ccWebHeaders,
      what: 'anchor listing',
    );
    final row = jsonMap(jsonMap(anchor['data'])?[roomId]);
    if (row == null) {
      throw CcFailure('the anchor answer carries no row for $roomId', missing: true);
    }
    final channelId = _text(row['channel_id']);
    if (channelId.isEmpty) {
      throw const CcFailure('the anchor answer names no channel');
    }
    final channel = await _get(
      '$ccWebOrigin/live/channel/',
      <String, String>{'channelids': channelId, 'anchor_ccid': roomId},
      headers: ccWebHeaders,
      what: 'channel answer',
    );
    final rooms = channel['data'];
    if (rooms is! List || rooms.isEmpty) {
      throw const CcFailure('the channel answer carries no room');
    }
    final detail = jsonMap(rooms.first);
    if (detail == null) {
      throw const CcFailure('the channel answer is not an object');
    }
    return ccChannelRoom(detail, askedRoomId: roomId);
  }

  void _checkPage(int page) {
    if (page < 1 || page > 100000) {
      throw const CcFailure('listing pages are 1..100000');
    }
  }

  List<CcRoom> _rows(Object? lives, {required bool gameRow, bool assumeLive = false, required String what}) {
    if (lives is! List) {
      throw CcFailure('the $what carries no lives list');
    }
    // Longer than asked means the endpoint stopped honouring the width, so the offsets are no longer ours and the
    // next page would repeat or skip rooms.
    if (lives.length > ccNativePageSize) {
      throw CcFailure('the $what exceeded the requested page size (${lives.length} rows)');
    }
    final seen = <String>{};
    return <CcRoom>[
      for (final raw in lives)
        if (ccListingRow(raw, gameRow: gameRow, assumeLive: assumeLive) case final CcRoom room
            when seen.add(room.roomId))
          room,
    ];
  }

  Future<Map<String, Object?>> _get(
    String url,
    Map<String, String> query, {
    required Map<String, String> headers,
    required String what,
  }) async {
    final response = await _client.getText(url, headers: headers, queryParameters: query);
    return _decode(response, what);
  }

  Future<Map<String, Object?>> _postJson(
    String url,
    Map<String, Object?> body, {
    required Map<String, String> headers,
    required String what,
  }) async {
    final response = await _client.postJson(url, body, headers: headers);
    return _decode(response, what);
  }

  Map<String, Object?> _decode(TextResponse response, String what) {
    if (response.statusCode != 200) {
      throw CcFailure(
        'the $what endpoint answered ${response.statusCode}',
        code: response.statusCode,
        missing: response.statusCode == 404,
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      final data = jsonMap(decoded);
      if (data == null) {
        throw CcFailure('the $what answer is not an object');
      }
      return data;
    } on FormatException catch (error) {
      throw CcFailure('the $what answer is not readable json', cause: error);
    }
  }
}
