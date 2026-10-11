// Module: lib/src/baidulive/baidulive_api.dart
// Purpose: 百度直播的请求面:签名信息流目录(session 游标)、371 房间命令、按 protocol/resolution/codec 分组的主机白名单
// 拉流地址,以及房间链接与媒体地址的读法。
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoints, the feed signature, the two different status numbering schemes, the media host family and
// the http/https split of `flv-live.bdstatic.com` follow the v1-maintained Baidu line (origin/master
// lib/shared/platforms/baidulive/). Fresh implementation against the v2 capability contracts, not a file merge
// (UPSTREAM_REVIEW_POLICY.md).
//
// A site is two files (docs/architecture/package-architecture.md §2.1): this one owns the requests and how their
// answers are read, baidulive_site.dart owns the capability answers. No model file.
//
// The rules that are worth more than the endpoint list:
//   * **the directory continues by session, not by page number**. `session_id` plus `refresh_index` come back with
//     each answer and the next request sends `refresh_index + 1`; a page 3 asked without its cursor is refused
//     instead of being answered as page 1, and a response whose `refresh_index` did not advance is the end of the
//     list rather than a page to keep requesting.
//   * **the two endpoints number the same states differently**. The feed says `live_status: 1` is broadcasting
//     while the room command says `status: 0` is. One shared mapping would silently call every live feed card
//     preview and every preview card live, so each has its own reader and the difference is a test, not a comment.
//   * **the signature is over sorted parameters plus a key baked into the site's own page**. It is the site's
//     public client secret, not a credential: it authorises nothing about a viewer, and putting it in a setting
//     would suggest a user could supply their own.
//   * **one media host is deliberately http**. `flv-live.bdstatic.com` is served without TLS and the site's own
//     client downgrades it; every other allowed host is upgraded to https. "Always https" looks like the safer
//     rule and is what makes this site's flv fail.
//   * **a pull address must name the room it was issued for**, in its path, and sit on the allowed host with the
//     container's own extension - an address from another broadcast plays someone else's show under this title.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import '../common/site_json.dart';

const String baiduliveSourceId = 'baidulive.live';
const String baiduliveWebOrigin = 'https://live.baidu.com';
const String baiduliveDetailOrigin = 'https://mbd.baidu.com';
const String baiduliveDirectoryOrigin = 'https://tiebac.baidu.com';

const String baiduliveRoomUa = '320_480_pc_1.0_0';

/// The key the site's own pc web client hashes its feed parameters with. Baked into its published javascript.
const String baiduliveFeedKey = 'CtmXzYPtdE58nCCcvqM0ectyqW3N5rfY';

const String baiduliveUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

const Map<String, String> baiduliveApiHeaders = <String, String>{
  'user-agent': baiduliveUserAgent,
  'accept': 'application/json, text/plain, */*',
  'origin': baiduliveWebOrigin,
  'referer': '$baiduliveWebOrigin/',
};

/// The rows the feed endpoint fills per page. It is the server's number, so a caller asking for 30 has to be told
/// it got ten.
const int baiduliveFeedPageSize = 10;

/// The room command whose number in the answer envelope carries the broadcast (`data['371']`).
const int baiduliveRoomCommand = 371;

/// The categories the site's own page shows before its tab block has been read.
const List<BaiduliveCategory> baiduliveFallbackCategories = <BaiduliveCategory>[
  BaiduliveCategory(id: 'rec', name: '推荐', channelId: 570),
  BaiduliveCategory(id: 'shopping', name: '购物', channelId: 574),
  BaiduliveCategory(id: 'finance', name: '财经', channelId: 611),
  BaiduliveCategory(id: 'health', name: '健康', channelId: 612),
  BaiduliveCategory(id: 'education', name: '教育', channelId: 613),
  BaiduliveCategory(id: 'news', name: '新闻', channelId: 575),
  BaiduliveCategory(id: 'leisure', name: '休闲', channelId: 616),
];

/// A baidulive answer that is not the answer we asked for.
final class BaiduliveFailure implements Exception {
  const BaiduliveFailure(this.message, {this.code, this.cause, this.missing = false});

  final String message;

  /// The site's own `errno` / `error_code` / http status behind the refusal, when there was one.
  final int? code;
  final Object? cause;

  /// "There is no such broadcast." A fact about the room, which is neither an offline room (it never existed or
  /// its id is wrong) nor a service failure - and the only reading that lets a follow list stop asking.
  final bool missing;

  @override
  String toString() =>
      'BaiduliveFailure($message${code == null ? '' : ', code $code'}${cause == null ? '' : ': $cause'})';
}

/// What the site says about a broadcast, in its own words.
///
/// [preview] and [replay] are distinct because the site distinguishes them, and both of them are not [offline]:
/// a preview room can be reminded on, and a replay is watchable.
enum BaiduliveState { live, preview, offline, replay, unknown }

/// One tab of the site's feed. The endpoint needs both the letter-name and the numeric channel.
final class BaiduliveCategory {
  const BaiduliveCategory({required this.id, required this.name, required this.channelId});

  final String id;
  final String name;
  final int channelId;

  ContentCategory toContentCategory() => ContentCategory(id: id, name: name);
}

/// One address group: a protocol, a resolution and a codec, with the cdn urls that serve it.
final class BaiduliveVariant {
  const BaiduliveVariant({required this.protocol, required this.resolution, required this.codec, required this.urls});

  final String protocol;
  final int resolution;
  final String codec;
  final List<String> urls;

  /// `protocol:resolution:codec` - the three things the site itself varies, and the reason flv and hls of one
  /// resolution are two options rather than two lines of one.
  String get id => '$protocol:$resolution:$codec';

  /// What the site labels it. A resolution of 0 means the answer stated none, and inventing "原画" for it would
  /// be our word on the menu.
  String get label => resolution > 0
      ? '${protocol.toUpperCase()} $resolution ${codec.toUpperCase()}'
      : '${protocol.toUpperCase()} ${codec.toUpperCase()}';
}

/// One room as an endpoint described it.
final class BaiduliveRoom {
  BaiduliveRoom({
    required this.roomId,
    required this.state,
    this.userId = '',
    this.nick = '',
    this.title = '',
    this.avatar = '',
    this.cover = '',
    this.category = '',
    this.viewers,
    this.followers,
    this.restriction,
    this.variants = const <BaiduliveVariant>[],
    this.danmaku = const <String, Object?>{},
    this.sessionCookie = '',
  });

  final String roomId;
  final BaiduliveState state;
  final String userId;
  final String nick;
  final String title;
  final String avatar;
  final String cover;
  final String category;

  /// `online_users` / `audience_count`, and only while the answer says the room is on air.
  final int? viewers;
  final int? followers;
  final LiveRestriction? restriction;
  final List<BaiduliveVariant> variants;

  /// The chat-poll handshake: the site delivers danmaku as an HLS-ish list url plus a poll interval.
  final Map<String, Object?> danmaku;
  final String sessionCookie;

  bool get isLiveNow => state == BaiduliveState.live;
  bool get isReplay => state == BaiduliveState.replay;

  /// Metadata a directory card saw, used to fill the holes a thin room answer leaves. Only ever fills absent
  /// fields: an answer that says something is never overwritten by what an older page said.
  BaiduliveRoom filledBy(BaiduliveRoom? known) {
    if (known == null) {
      return this;
    }
    return BaiduliveRoom(
      roomId: roomId,
      state: state,
      userId: userId.isNotEmpty ? userId : known.userId,
      nick: nick.isNotEmpty ? nick : known.nick,
      title: title.isNotEmpty ? title : known.title,
      avatar: avatar.isNotEmpty ? avatar : known.avatar,
      cover: cover.isNotEmpty ? cover : known.cover,
      category: category.isNotEmpty ? category : known.category,
      // The audience is never padded: a live card's viewer count is not an answer about the audience of a
      // broadcast the room command says is not on air.
      viewers: viewers,
      followers: followers ?? known.followers,
      restriction: restriction,
      variants: variants,
      danmaku: danmaku.isNotEmpty ? danmaku : known.danmaku,
      sessionCookie: sessionCookie,
    );
  }

  LiveRoom toLiveRoom({String catchUpSource = 'baidulive.live_status'}) => LiveRoom(
    ref: ContentRef(sourceId: baiduliveSourceId, contentId: roomId, kind: ContentKind.liveRoom),
    state: switch (state) {
      BaiduliveState.live => LiveRoomState.live,
      BaiduliveState.preview => LiveRoomState.notStarted,
      BaiduliveState.offline => LiveRoomState.ended,
      // A replay is a broadcast that ended; it is offered as catch-up below rather than as "on air".
      BaiduliveState.replay => LiveRoomState.ended,
      BaiduliveState.unknown => LiveRoomState.unknown,
    },
    title: title,
    anchorName: nick.isEmpty ? null : nick,
    anchorId: userId.isEmpty ? null : userId,
    avatar: avatar.isEmpty ? null : avatar,
    cover: cover.isEmpty ? null : cover,
    area: category.isEmpty ? null : category,
    link: baiduliveRoomUrl(roomId),
    // The audience figure is stated only while on air; a room that is not broadcasting reports no number here
    // rather than the last one its feed card carried.
    audience: viewers == null ? null : LiveAudience.ofMetric(viewers, LiveAudienceMetric.onlineViewers),
    followers: followers,
    restriction: restriction,
    streamId: isLiveNow || isReplay ? roomId : null,
    catchUp: isReplay ? LiveCatchUp(active: true, source: catchUpSource) : null,
    danmakuPayload: danmaku,
    headers: baiduliveMediaHeaders(roomId),
    sitePayload: const <String, Object?>{},
    extra: <String, Object?>{'baidulive.state': state.name},
  );

  AnchorSummary toAnchorSummary() => AnchorSummary(
    ref: ContentRef(sourceId: baiduliveSourceId, contentId: userId.isEmpty ? roomId : userId, kind: ContentKind.anchor),
    name: nick.isEmpty ? title : nick,
    avatar: avatar.isEmpty ? null : avatar,
    fans: followers,
    currentRoom: isLiveNow
        ? ContentRef(sourceId: baiduliveSourceId, contentId: roomId, kind: ContentKind.liveRoom)
        : null,
  );
}

/// One page of the session-paged directory.
final class BaiduliveDirectoryPage {
  BaiduliveDirectoryPage({required this.rooms, required this.categories, required this.cursor, required this.hasMore});

  final List<BaiduliveRoom> rooms;

  /// The tab block the feed answer carries with its first page (and re-carries when the site changes its menu).
  final List<BaiduliveCategory> categories;

  /// What the next request has to send back to continue. Empty when the list ended.
  final String cursor;
  final bool hasMore;
}

/// The continuation token: what the site stated about where this list is.
///
/// Both parts are the server's own values. The requested next `refresh_index` is the stored one plus one, so a
/// cursor is an *answer*, never a page number the caller invented.
String? baiduliveEncodeCursor(String sessionId, int refreshIndex) {
  if (sessionId.isEmpty || sessionId.length > 128 || refreshIndex < 1) {
    return null;
  }
  return '${Uri.encodeComponent(sessionId)}@$refreshIndex';
}

({String sessionId, int refreshIndex})? baiduliveDecodeCursor(String? cursor) {
  final value = cursor?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  final at = value.lastIndexOf('@');
  if (at <= 0 || at == value.length - 1) {
    throw const BaiduliveFailure('not a baidulive directory cursor');
  }
  final sessionId = Uri.decodeComponent(value.substring(0, at));
  final refreshIndex = int.tryParse(value.substring(at + 1));
  if (sessionId.isEmpty || sessionId.length > 128 || refreshIndex == null || refreshIndex < 1) {
    throw const BaiduliveFailure('not a baidulive directory cursor');
  }
  return (sessionId: sessionId, refreshIndex: refreshIndex);
}

/// The watch page. A room id is 6..20 digits and never anything else, so a url built from a wrong id fails here
/// rather than at the endpoint.
String baiduliveRoomUrl(String roomId) => '$baiduliveWebOrigin/m/room/${baiduliveRoomId(roomId)}';

/// The per-room headers the media needs. The cdn checks the referer against the room it issued the address for.
Map<String, String> baiduliveMediaHeaders(String roomId) => <String, String>{
  'user-agent': baiduliveUserAgent,
  'origin': baiduliveWebOrigin,
  'referer': baiduliveRoomUrl(roomId),
};

/// A room id, or one of the three page shapes the site publishes for a room.
String baiduliveRoomId(String value) {
  final id = baiduliveParseRoomId(value);
  if (id == null) {
    throw BaiduliveFailure('not a baidulive room id or room page: "$value"');
  }
  return id;
}

String? baiduliveParseRoomId(String value) {
  final raw = value.trim();
  if (_roomIdPattern.hasMatch(raw)) {
    return raw;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null) {
    return null;
  }
  return baiduliveRoomFromUri(uri);
}

final RegExp _roomIdPattern = RegExp(r'^[1-9][0-9]{5,19}$');

/// The room id inside a baidulive url, or null.
///
/// Three shapes are accepted because the site publishes three: `/m/room/<id>`, the pc player page with
/// `?room_id=`, and a multipage share whose last segment is a token. A `room_id` on any other path is not a room
/// page - that parameter appears on pages that are about something else, and taking it would resolve a link to a
/// broadcast nobody linked.
String? baiduliveRoomFromUri(Uri uri) {
  if (!const <String>{'http', 'https'}.contains(uri.scheme) ||
      uri.host.toLowerCase() != 'live.baidu.com' ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
    return null;
  }
  final segments = <String>[
    for (final segment in uri.pathSegments)
      if (segment.isNotEmpty) segment,
  ];
  if (segments.length == 3 && segments[0] == 'm' && segments[1] == 'room' && _roomIdPattern.hasMatch(segments[2])) {
    return segments[2];
  }
  final id = uri.queryParameters['room_id']?.trim() ?? '';
  if (!_roomIdPattern.hasMatch(id)) {
    return null;
  }
  final path = '/${segments.join('/')}';
  if (path == '/m/media/pclive/pchome/live.html') {
    return id;
  }
  if (segments.length == 6 &&
      segments.take(5).join('/') == 'm/media/multipage/liveshow/index' &&
      RegExp(r'^[A-Za-z0-9_\-]{1,64}$').hasMatch(segments[5])) {
    return id;
  }
  return null;
}

/// The feed signature: sorted `k=v` pairs, the key appended, md5'd.
///
/// `sign` itself is excluded, and the pair order is the *sorted* order rather than insertion order - the site's
/// client builds the string from a sorted copy, and hashing what we happen to have inserted first produces a
/// signature that is only right by accident.
String baiduliveSign(Map<String, String> parameters) {
  final keys = parameters.keys.where((String key) => key != 'sign').toList(growable: false)..sort();
  final canonical = keys.map((String key) => '$key=${parameters[key]}').join('&');
  return md5.convert(utf8.encode('$canonical&$baiduliveFeedKey')).toString();
}

/// The host family that serves this site's streams.
bool baiduliveAllowedMediaHost(String host) =>
    host == 'hls-live.bdstatic.com' || host == 'flv-live.bdstatic.com' || host.endsWith('.liveshow.bdstatic.com');

/// The host family that serves this site's pictures.
bool baiduliveAllowedImageHost(String host) =>
    host == 'bdstatic.com' ||
    host.endsWith('.bdstatic.com') ||
    host == 'bdimg.com' ||
    host.endsWith('.bdimg.com') ||
    host == 'bcebos.com' ||
    host.endsWith('.bcebos.com');

/// A picture url, or null when it is not on the site's own image hosts over https.
String? baiduliveImage(Object? raw) {
  final value = _text(raw);
  if (value.isEmpty) {
    return null;
  }
  final candidate = value.startsWith('//') ? 'https:$value' : value;
  final uri = Uri.tryParse(candidate);
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) {
    return null;
  }
  return baiduliveAllowedImageHost(uri.host.toLowerCase()) ? uri.toString() : null;
}

/// A pull address, normalised the way the site's own client asks for it.
///
/// `flv-live.bdstatic.com` is served **without** TLS and the client downgrades it to http; every other allowed
/// host is upgraded to https. The path has to start at `/live/`, carry this room's id as a whole token, and end
/// with the container's own extension. Anything else is dropped rather than played: the id check is what stops a
/// reused address from another broadcast playing under this title.
String? baiduliveMediaUrl(Object? raw, {required String roomId, required String protocol}) {
  final value = _text(raw);
  if (value.isEmpty) {
    return null;
  }
  var uri = Uri.tryParse(value);
  if (uri == null) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (!baiduliveAllowedMediaHost(host)) {
    return null;
  }
  if (host == 'flv-live.bdstatic.com') {
    uri = uri.replace(scheme: 'http', port: 80);
  } else {
    uri = uri.replace(scheme: 'https', port: 443);
  }
  final extension = protocol == 'hls' ? '.m3u8' : '.flv';
  if (uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      !uri.path.startsWith('/live/') ||
      !uri.path.toLowerCase().endsWith(extension) ||
      !RegExp('(?:^|_)${RegExp.escape(roomId)}(?:[-./]|\$)').hasMatch(uri.path)) {
    return null;
  }
  return uri.toString();
}

/// The feed's state numbering: 1 is broadcasting, 0 is a preview, 3 is a replay.
BaiduliveState baiduliveFeedState(Object? raw) => switch (jsonInt(raw)) {
  1 => BaiduliveState.live,
  0 => BaiduliveState.preview,
  2 => BaiduliveState.offline,
  3 => BaiduliveState.replay,
  _ => BaiduliveState.unknown,
};

/// The room command's state numbering - **not the feed's**: here 0 is broadcasting and 2/20 are off air.
///
/// These two are separate functions on purpose. A shared mapping is what makes every live card read as a preview.
BaiduliveState baiduliveCommandState(Object? raw) => switch (jsonInt(raw)) {
  0 => BaiduliveState.live,
  -1 || 1 => BaiduliveState.preview,
  2 || 20 => BaiduliveState.offline,
  3 => BaiduliveState.replay,
  _ => BaiduliveState.unknown,
};

/// One feed card. A card whose room id is not a room id is dropped: it is a banner or an ad slot, not a tile.
BaiduliveRoom? baiduliveFeedCard(Object? raw) {
  final item = jsonMap(raw);
  if (item == null) {
    return null;
  }
  final roomId = baiduliveParseRoomId(_text(item['room_id']));
  if (roomId == null) {
    return null;
  }
  final host = jsonMap(item['host']) ?? const <String, Object?>{};
  final label = jsonMap(item['left_label']);
  final state = baiduliveFeedState(item['live_status']);
  final nick = _text(host['name']);
  return BaiduliveRoom(
    roomId: roomId,
    state: state,
    userId: _text(host['uk']),
    nick: nick,
    title: _firstText(<Object?>[item['title'], nick]),
    avatar: baiduliveImage(host['avatar']) ?? '',
    cover: baiduliveImage(item['cover']) ?? '',
    category: _firstText(<Object?>[item['live_tag'], label?['text']]),
    // The audience is stated for a room the card says is on air. For every other state the field describes an
    // audience there is not, so it stays absent instead of being carried over.
    viewers: state == BaiduliveState.live ? jsonInt(item['audience_count']) : null,
    // A feed card ships no manifest: whether this room can be opened is a question for the room command.
    variants: const <BaiduliveVariant>[],
  );
}

/// The tab block the feed answer carries.
List<BaiduliveCategory> baiduliveCategories(Object? raw) {
  final tab = jsonMap(raw);
  if (tab == null || tab.isEmpty) {
    return const <BaiduliveCategory>[];
  }
  final error = jsonInt(tab['inner_errno']);
  if (error != null && error != 0) {
    throw BaiduliveFailure('the tab block refused', code: error);
  }
  final seen = <String>{};
  return <BaiduliveCategory>[
    for (final raw in jsonList(tab['items']))
      if (_categoryRow(raw) case final BaiduliveCategory category when seen.add(category.id)) category,
  ];
}

BaiduliveCategory? _categoryRow(Object? raw) {
  final item = jsonMap(raw);
  if (item == null) {
    return null;
  }
  final id = _text(item['type']).toLowerCase();
  final name = _text(item['name']);
  final channelId = jsonInt(item['channel_id']);
  // The tab name doubles as the request's `tab` parameter, so it is validated against that shape before it can be
  // stored as an id a later browse() will send back.
  if (!RegExp(r'^[a-z][a-z0-9_]{0,31}$').hasMatch(id) || name.isEmpty || channelId == null || channelId < 1) {
    return null;
  }
  return BaiduliveCategory(id: id, name: name, channelId: channelId);
}

/// The directory answer: its cards, its tab block and the cursor that continues it.
BaiduliveDirectoryPage baiduliveDirectory(Object? value, {String? previousCursor}) {
  final root = jsonMap(value);
  if (root == null) {
    throw const BaiduliveFailure('the directory answer is not an object');
  }
  final errno = jsonInt(root['errno']);
  if (errno == null) {
    throw const BaiduliveFailure('the directory answer carries no errno');
  }
  if (errno != 0) {
    throw BaiduliveFailure('the directory refused the request', code: errno);
  }
  final data = jsonMap(root['data']) ?? const <String, Object?>{};
  final feed = jsonMap(data['feed']);
  if (feed == null) {
    throw const BaiduliveFailure('the directory answer carries no feed block');
  }
  final innerErrno = jsonInt(feed['inner_errno']);
  if (innerErrno != null && innerErrno != 0) {
    throw BaiduliveFailure('the feed refused the request', code: innerErrno);
  }
  final rows = feed['items'];
  if (rows is! List) {
    throw const BaiduliveFailure('the feed carries no items');
  }
  final seen = <String>{};
  final rooms = <BaiduliveRoom>[
    for (final raw in rows)
      if (baiduliveFeedCard(raw) case final BaiduliveRoom room when seen.add(room.roomId)) room,
  ];
  final sessionId = _text(feed['session_id']);
  final refreshIndex = jsonInt(feed['refresh_index']);
  if (sessionId.isEmpty || sessionId.length > 128 || refreshIndex == null || refreshIndex < 0) {
    throw const BaiduliveFailure('the feed carries no usable continuation');
  }
  // The continuation has to move. A server that repeats its own `refresh_index` is telling us the next request
  // would return the same page, and paging on that loops the same rooms forever.
  final previous = baiduliveDecodeCursor(previousCursor);
  final advanced = previous == null || refreshIndex > previous.refreshIndex;
  final cursor = baiduliveEncodeCursor(sessionId, refreshIndex) ?? '';
  return BaiduliveDirectoryPage(
    rooms: rooms,
    categories: baiduliveCategories(data['tab']),
    cursor: cursor,
    hasMore: advanced && rows.length >= baiduliveFeedPageSize && cursor.isNotEmpty,
  );
}

/// The room command's answer.
BaiduliveRoom baiduliveRoomDetail(Object? value, {required String expectedRoomId}) {
  final root = jsonMap(value);
  if (root == null) {
    throw const BaiduliveFailure('the room answer is not an object');
  }
  final errno = jsonInt(root['errno']);
  if (errno == null) {
    throw const BaiduliveFailure('the room answer carries no errno');
  }
  if (errno != 0) {
    throw BaiduliveFailure('the room endpoint refused the request', code: errno);
  }
  final command = jsonMap(jsonMap(root['data'])?['$baiduliveRoomCommand']);
  if (command == null || command.isEmpty) {
    throw BaiduliveFailure('there is no such broadcast', code: errno, missing: true);
  }
  final error = jsonInt(command['error_code']);
  if (error != null && error != 0) {
    // 1 and 4 are the site's "no such room". Anything else is the service, and reading the service as an absent
    // room is what makes a follow list forget a broadcast that is up.
    throw BaiduliveFailure(
      const <int>{1, 4}.contains(error) ? 'the room command reports no such broadcast' : 'the room command refused',
      code: error,
      missing: const <int>{1, 4}.contains(error),
    );
  }
  // The answer's own share url is the strongest identity statement it makes: if it names a different room, the
  // command came back about someone else's broadcast.
  final shareUrl = _text(command['share_url']);
  if (shareUrl.isNotEmpty) {
    final shared = baiduliveParseRoomId(shareUrl);
    if (shared != null && shared != expectedRoomId) {
      throw BaiduliveFailure('the room answer is about $shared while asking about $expectedRoomId');
    }
  }
  final host = jsonMap(command['host']) ?? const <String, Object?>{};
  final video = jsonMap(command['video']) ?? const <String, Object?>{};
  if (host.isEmpty && video.isEmpty) {
    throw BaiduliveFailure('there is no broadcast behind this room', missing: true);
  }
  final state = baiduliveCommandState(command['status']);
  final variants = state == BaiduliveState.live
      ? baiduliveVariants(video, roomId: expectedRoomId)
      : const <BaiduliveVariant>[];
  return BaiduliveRoom(
    roomId: expectedRoomId,
    state: state,
    userId: _text(host['uk']),
    nick: _firstText(<Object?>[host['nick_name'], host['name']]),
    title: _firstText(<Object?>[video['title'], host['nick_name'], host['name']]),
    avatar: baiduliveImage(jsonMap(host['image'])?['image_33']) ?? '',
    cover:
        baiduliveImage(jsonMap(video['cover'])?['cover_100']) ??
        baiduliveImage(jsonMap(video['cover'])?['vertical_cover']) ??
        '',
    category: _text(command['category']),
    viewers: state == BaiduliveState.live ? jsonInt(command['online_users']) : null,
    followers: jsonInt(command['real_fans_num'] ?? host['fans']),
    restriction: baiduliveRestriction(command, state: state, variants: variants),
    variants: variants,
    danmaku: baiduliveChatPayload(command, video, roomId: expectedRoomId),
  );
}

/// Why an on-air room cannot be opened, in the order the site's own flags say so.
LiveRestriction? baiduliveRestriction(
  Map<String, Object?> command, {
  required BaiduliveState state,
  required List<BaiduliveVariant> variants,
}) {
  if (state != BaiduliveState.live && state != BaiduliveState.replay) {
    return null;
  }
  if ((jsonInt(command['is_forbidden_url']) ?? 0) > 0 || (jsonInt(command['ban_status']) ?? 0) > 0) {
    return LiveRestriction.unplayable;
  }
  if ((jsonInt(command['has_pay_service']) ?? 0) > 0) {
    return LiveRestriction.paid;
  }
  return variants.isEmpty ? LiveRestriction.unplayable : LiveRestriction.none;
}

/// The chat-poll handshake material. The site delivers danmaku as a list url it re-reads on an interval, so the
/// interval is part of the payload and its clamp is the site's own (1..10s, default 5).
Map<String, Object?> baiduliveChatPayload(
  Map<String, Object?> command,
  Map<String, Object?> video, {
  required String roomId,
}) {
  final chat = _firstText(<Object?>[command['chat_msg_hls_url'], video['msg_hls_url']]);
  if (chat.isEmpty) {
    return const <String, Object?>{};
  }
  final stated = jsonInt(command['msg_hls_pull_internal_in_second'] ?? video['msg_hls_pull_internal_in_second']);
  final seconds = stated == null || stated <= 0 ? 5 : stated.clamp(1, 10);
  return <String, Object?>{
    'chatListUrl': chat,
    'reliableListUrl': _firstText(<Object?>[command['reliable_msg_hls_url']]),
    'hostListUrl': _firstText(<Object?>[command['host_msg_hls_url']]),
    'pollSeconds': seconds,
    'roomId': roomId,
  };
}

/// The manifest, grouped by the three things the site varies.
///
/// `url_clarity_list` is the modern shape (one entry per resolution, with an `avc_flv` / `flv` / `hls` /
/// `hevc_flv` map inside); `url_list` and the bare `live_hls_url` / `live_flv_url` fields are the older ones the
/// answer still ships. All are read, because an answer that carries only the bare fields is a live room with real
/// addresses, and reading only the list would report it as unplayable.
List<BaiduliveVariant> baiduliveVariants(Map<String, Object?> video, {required String roomId}) {
  final grouped = <String, ({String protocol, int resolution, String codec, List<String> urls})>{};

  void add(Object? raw, String protocol, int resolution, String codec) {
    final url = baiduliveMediaUrl(raw, roomId: roomId, protocol: protocol);
    if (url == null) {
      return;
    }
    final id = '$protocol:$resolution:$codec';
    final bucket = grouped.putIfAbsent(
      id,
      () => (protocol: protocol, resolution: resolution, codec: codec, urls: <String>[]),
    );
    if (!bucket.urls.contains(url)) {
      bucket.urls.add(url);
    }
  }

  final clarity = jsonList(video['url_clarity_list']);
  for (final raw in clarity) {
    final item = jsonMap(raw) ?? const <String, Object?>{};
    final resolution = jsonInt(item['resolution']) ?? 0;
    final urls = jsonMap(item['urls']) ?? const <String, Object?>{};
    add(urls['avc_flv'], 'flv', resolution, 'avc');
    add(urls['flv'], 'flv', resolution, 'avc');
    add(urls['hls'], 'hls', resolution, 'avc');
    add(urls['hevc_flv'], 'flv', resolution, 'hevc');
  }
  final urlList = jsonList(video['url_list']);
  for (final raw in urlList) {
    final item = jsonMap(raw) ?? const <String, Object?>{};
    final resolution = jsonInt(item['resolution']) ?? 0;
    for (final rawUrls in jsonList(item['urls'])) {
      final urls = jsonMap(rawUrls) ?? const <String, Object?>{};
      add(urls['flv'], 'flv', resolution, 'avc');
      add(urls['hls'], 'hls', resolution, 'avc');
    }
  }
  final bareHls = _text(video['live_hls_url']);
  add(bareHls, 'hls', _resolutionNamedBy(bareHls, urlList), 'avc');
  if (clarity.isEmpty) {
    add(video['live_flv_url'], 'flv', 0, 'avc');
    add(video['live_flv_url_origin'], 'flv', 0, 'avc');
  }
  add(video['hevc_url'], 'flv', 0, 'hevc');

  final variants =
      grouped.entries
          .where(
            (MapEntry<String, ({String protocol, int resolution, String codec, List<String> urls})> entry) =>
                entry.value.urls.isNotEmpty,
          )
          .map(
            (MapEntry<String, ({String protocol, int resolution, String codec, List<String> urls})> entry) =>
                BaiduliveVariant(
                  protocol: entry.value.protocol,
                  resolution: entry.value.resolution,
                  codec: entry.value.codec,
                  urls: List<String>.unmodifiable(entry.value.urls),
                ),
          )
          .toList(growable: false)
        ..sort((BaiduliveVariant left, BaiduliveVariant right) {
          final byResolution = right.resolution.compareTo(left.resolution);
          if (byResolution != 0) {
            return byResolution;
          }
          // Protocol then codec break the tie: Dart's sort is not stable, and a menu whose order changes between
          // two identical answers is a bug report nobody can reproduce.
          final byProtocol = left.protocol.compareTo(right.protocol);
          return byProtocol != 0 ? byProtocol : left.codec.compareTo(right.codec);
        });
  return List<BaiduliveVariant>.unmodifiable(variants);
}

/// The resolution a bare url belongs to, found by matching its file name against the listed ones.
///
/// The bare field carries no resolution of its own. Guessing one would put a fake 1080p row on the menu; matching
/// the file name against a listed address gives the number the site wrote next to that same file.
int _resolutionNamedBy(String raw, List<Object?> urlList) {
  final candidate = Uri.tryParse(raw);
  if (candidate == null) {
    return 0;
  }
  final segments = candidate.pathSegments;
  final name = segments.isEmpty ? '' : segments.last;
  if (name.isEmpty) {
    return 0;
  }
  for (final raw in urlList) {
    final item = jsonMap(raw) ?? const <String, Object?>{};
    final resolution = jsonInt(item['resolution']);
    if (resolution == null) {
      continue;
    }
    for (final rawUrls in jsonList(item['urls'])) {
      final other = Uri.tryParse(_text(jsonMap(rawUrls)?['hls']));
      final segments = other?.pathSegments;
      if (segments != null && segments.isNotEmpty && segments.last == name) {
        return resolution;
      }
    }
  }
  return 0;
}

String _text(Object? raw) => raw is String ? raw.trim() : (raw == null ? '' : '${raw}'.trim());

String _firstText(List<Object?> values) {
  for (final value in values) {
    final text = _text(value);
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

/// The Baidu live client.
final class BaiduliveApi {
  BaiduliveApi({NetworkClient? client, Clock? clock, Random? random, String? deviceId})
    : _client = client ?? NetworkClient(),
      _ownsClient = client == null,
      _clock = clock ?? systemClock,
      _deviceId = deviceId ?? _newDeviceId(random ?? Random.secure());

  final NetworkClient _client;
  final bool _ownsClient;
  final Clock _clock;

  /// The visitor id the feed signature and the room command are both keyed on. One per source, like the site's
  /// own client keeps one per browser.
  final String _deviceId;

  /// The cards this source has listed, so a thin room answer keeps the metadata the grid showed. Bounded: an
  /// unbounded map grows with every room a long-lived process ever opened.
  final Map<String, BaiduliveRoom> _known = <String, BaiduliveRoom>{};

  static const int _knownLimit = 200;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// `pc-` plus 24 characters from the site's own alphabet. Derived from a cryptographic source: a clock-derived
  /// id is guessable, and two launches in the same microsecond would share one visitor.
  static String _newDeviceId(Random random) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';
    final suffix = List<String>.generate(24, (_) => alphabet[random.nextInt(alphabet.length)]).join();
    return 'pc-$suffix';
  }

  /// One page of the session-paged directory.
  ///
  /// The first page asks for `banner,tab,feed` and sends no session; every later page asks for `feed` only and
  /// hands back the cursor the previous answer stated. A caller that asks for page 2 without a cursor gets a
  /// refusal, not a first page: answering it would restart the list and show the same rooms as new.
  Future<BaiduliveDirectoryPage> directory({required BaiduliveCategory category, String? cursor, int page = 1}) async {
    if (page < 1 || page > 10000) {
      throw const BaiduliveFailure('directory pages are 1..10000');
    }
    final continuation = baiduliveDecodeCursor(cursor);
    if (continuation == null && page != 1) {
      throw const BaiduliveFailure('a baidulive directory page past the first needs the cursor the first answer gave');
    }
    if (!RegExp(r'^[a-z][a-z0-9_]{0,31}$').hasMatch(category.id) ||
        category.channelId < 1 ||
        category.channelId > 100000) {
      throw BaiduliveFailure('not a baidulive tab: ${category.id}/${category.channelId}');
    }
    final first = continuation == null;
    final form = <String, String>{
      'appname': 'pclive',
      'sid': '',
      'ua': baiduliveRoomUa,
      'uid': _deviceId,
      'timestamp': '${_clock().millisecondsSinceEpoch ~/ 1000}',
      'source': 'pclive',
      'resource': first ? 'banner,tab,feed' : 'feed',
      'scene': 'pc_channel',
      'session_id': first ? '' : continuation.sessionId,
      'refresh_type': first ? '0' : '1',
      'refresh_index': first ? '1' : '${continuation.refreshIndex + 1}',
      'tab': category.id,
      'channel_id': '${category.channelId}',
    };
    form['sign'] = baiduliveSign(form);
    final body = await _post('$baiduliveDirectoryOrigin/livefeed/feed', form);
    final result = baiduliveDirectory(body, previousCursor: cursor);
    for (final room in result.rooms) {
      _remember(room);
    }
    return result;
  }

  /// The room command: state, host, manifest and chat handshake for one room.
  ///
  /// [fillFromListing] pads the answer from a card this source listed earlier, because the room command sometimes
  /// returns a bare state with no picture and no title. Padding happens against what *this* source saw, and only
  /// for fields the answer left empty.
  Future<BaiduliveRoom> room(String input, {bool fillFromListing = true}) async {
    final roomId = baiduliveRoomId(input);
    final data = jsonEncode(<String, Object?>{
      'data': <String, Object?>{'room_id': roomId, 'device_id': _deviceId, 'source_type': 0},
      'replay_slice': 0,
      'nid': '',
      'schemeParams': <String, Object?>{
        'src_pre': 'pc',
        'src_suf': 'other',
        'bd_vid': '',
        'share_uid': '',
        'share_cuk': '',
        'share_ecid': '',
        'zb_tag': '',
        'shareTaskInfo': jsonEncode(<String, String>{'room_id': roomId}),
        'share_from': '',
        'ext_params': '',
        'nid': '',
      },
    });
    final query = <String, String>{
      'cmd': '$baiduliveRoomCommand',
      'action': 'star',
      'service': 'bdbox',
      'osname': 'pc',
      'data': data,
      'ua': '360_740_ANDROID_0',
      'bd_vid': '',
      'uid': _deviceId,
      '_': '${_clock().millisecondsSinceEpoch}',
    };
    final room = baiduliveRoomDetail(
      await _get('$baiduliveDetailOrigin/searchbox', query),
      expectedRoomId: roomId,
    );
    final filled = fillFromListing ? room.filledBy(_known[roomId]) : room;
    _remember(filled);
    return filled;
  }

  void _remember(BaiduliveRoom room) {
    _known[room.roomId] = room;
    while (_known.length > _knownLimit) {
      // Drop the oldest insertion: the recent pages are the ones a viewer is actually scrolling through.
      _known.remove(_known.keys.first);
    }
  }

  Future<Object?> _get(String url, Map<String, String> query) async {
    final response = await _client.getText(url, headers: baiduliveApiHeaders, queryParameters: query);
    return _decode(url, response);
  }

  Future<Object?> _post(String url, Map<String, String> form) async {
    final response = await _client.postForm(url, form, headers: baiduliveApiHeaders);
    return _decode(url, response);
  }

  Object? _decode(String url, TextResponse response) {
    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      throw BaiduliveFailure('${Uri.parse(url).path} answered $status', code: status);
    }
    try {
      return jsonDecode(response.body);
    } on FormatException catch (error) {
      // An edge that answers an html block page instead of json is a failure to name, not a crash in the caller.
      throw BaiduliveFailure('${Uri.parse(url).path} answered something that is not json', cause: error);
    }
  }
}
