// Module: lib/src/jdlive/jdlive_api.dart
// Purpose: 京东直播的请求面:JD 网关的 body=json 形状、按 currentCount 续着的目录游标、房间即播地址、
// 以及"hls 与 flv 是同一路流"的主清单校验。
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoints, the gateway envelope, the directory continuation, the `secret` app-only flag, the
// two-container identity check and the playlist child rules follow the v1-maintained JD line (origin/master
// lib/shared/platforms/jdlive/). Fresh implementation against the v2 capability contracts, not a file merge
// (UPSTREAM_REVIEW_POLICY.md).
//
// A site is two files (docs/architecture/package-architecture.md §2.1): this one owns the requests and how their
// answers are read, jdlive_site.dart owns the capability answers. No model file.
//
// The rules that are worth more than the endpoint list:
//   * **one gateway, many functions**. Every call is `GET https://api.m.jd.com/api?appid=h5-live&functionId=…
//     &body=<json>`; the body is a json *string* in the query, and `code`/`subCode` are **text** `'0'` — comparing
//     them as numbers is how a working answer reads as a refusal.
//   * **the directory continues by count, not by page**. One walk shares a timestamp and each answer's
//     `currentCount` is what the next request sends back; a page past the first asked without that cursor is
//     refused instead of restarting the list.
//   * **a card is only a card when its two ids agree**. `liveId` and `id` have to name the same broadcast, and a
//     card whose template type is not a room is skipped rather than turned into a broken tile.
//   * **hls and flv are the same stream, and the site proves it**: the two addresses differ only by extension, so
//     an answer whose stems disagree is a schema change. That identity is why this port lists them as two
//     *containers of one profile* (like 猫耳FM) rather than as two qualities the way v1's menu did.
//   * **an address is only handed out after its playlist has been read**. Every child of the master must stay on
//     the same host, under `/live/`, and keep the stream's own stem - the site's grant is a directory, and a
//     playlist pointing elsewhere is not this broadcast.
//   * **`secret == 1` is the app** - the web path can describe the room and cannot play it.

import 'dart:convert';

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import '../common/site_json.dart';

const String jdliveSourceId = 'jdlive.live';
const String jdliveApiOrigin = 'https://api.m.jd.com';
const String jdliveWebOrigin = 'https://lives.jd.com';

/// The H5 client the site's own mobile page sends. The gateway answers the playlist only to it.
const String jdliveUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

const Map<String, String> jdliveApiHeaders = <String, String>{
  'user-agent': jdliveUserAgent,
  'accept': 'application/json, text/plain, */*',
  'origin': jdliveWebOrigin,
  'referer': '$jdliveWebOrigin/',
};

/// The directory's own page fill.
const int jdlivePageSize = 30;

/// The most rows or playlist references one answer may carry.
const int jdliveRowLimit = 1000;
const int jdlivePlaylistReferenceLimit = 1000;

const String jdliveFeaturedCategory = 'featured';

/// A jdlive answer that is not the answer we asked for.
final class JdFailure implements Exception {
  const JdFailure(this.message, {this.code, this.subCode, this.cause, this.missing = false});

  final String message;

  /// The gateway's `code`, when it sent one.
  final String? code;

  /// The gateway's `subCode`, the field that distinguishes "no such live" from "the service refused".
  final String? subCode;
  final Object? cause;

  /// "No such broadcast." Not an offline room and not the service.
  final bool missing;

  @override
  String toString() =>
      'JdFailure($message'
      '${code == null ? '' : ', code $code'}'
      '${subCode == null ? '' : ', subCode $subCode'}'
      '${cause == null ? '' : ': $cause'})';
}

/// What the site says about the broadcast.
enum JdState { live, preview, offline, replay, paused, unknown }

/// One room as an endpoint described it.
final class JdRoom {
  const JdRoom({
    required this.liveId,
    required this.state,
    this.statusCode,
    this.authorId = '',
    this.nick = '',
    this.title = '',
    this.avatar = '',
    this.cover = '',
    this.totalViews,
    this.hls,
    this.flv,
    this.appOnly = false,
  });

  final String liveId;
  final JdState state;

  /// The site's raw `status` number, kept so a code that stops mapping stays visible in a stored row.
  final int? statusCode;
  final String authorId;
  final String nick;
  final String title;
  final String avatar;
  final String cover;

  /// `pv` - the cumulative audience. It is not a headcount of who is watching now, and this site never states
  /// concurrent viewers, so no concurrent number is invented here.
  final int? totalViews;

  final Uri? hls;
  final Uri? flv;

  /// `secret == 1`: the web path may describe it and may not play it.
  final bool appOnly;

  bool get isLive => state == JdState.live;

  /// The two containers of one profile.
  List<Uri> get addresses => <Uri>[if (hls != null) hls!, if (flv != null) flv!];

  LiveRestriction? get restriction {
    if (appOnly) {
      return LiveRestriction.appOnly;
    }
    if (!isLive) {
      return null;
    }
    return addresses.isEmpty ? LiveRestriction.unplayable : LiveRestriction.none;
  }

  /// Metadata a directory card saw. The room answer is about the broadcast; the card is about the person, and a
  /// thin room answer keeps what the card showed - never an audience number it did not state.
  JdRoom filledBy(JdRoom? known) {
    if (known == null) {
      return this;
    }
    return JdRoom(
      liveId: liveId,
      state: state,
      statusCode: statusCode ?? known.statusCode,
      authorId: authorId.isNotEmpty ? authorId : known.authorId,
      nick: nick.isNotEmpty ? nick : known.nick,
      title: title.isNotEmpty ? title : known.title,
      avatar: avatar.isNotEmpty ? avatar : known.avatar,
      cover: cover.isNotEmpty ? cover : known.cover,
      // The room answer's own view count wins; a card's number is not carried onto a fresh answer.
      totalViews: totalViews,
      hls: hls,
      flv: flv,
      appOnly: appOnly,
    );
  }

  LiveRoom toLiveRoom() => LiveRoom(
    ref: ContentRef(sourceId: jdliveSourceId, contentId: liveId, kind: ContentKind.liveRoom),
    state: switch (state) {
      JdState.live => LiveRoomState.live,
      JdState.preview => LiveRoomState.notStarted,
      JdState.offline => LiveRoomState.ended,
      JdState.replay => LiveRoomState.ended,
      // A paused room is the site saying "not right now" without saying it ended; unknown is the honest reading.
      JdState.paused => LiveRoomState.unknown,
      JdState.unknown => LiveRoomState.unknown,
    },
    title: title,
    anchorName: nick.isEmpty ? null : nick,
    anchorId: authorId.isEmpty ? null : authorId,
    avatar: avatar.isEmpty ? (cover.isEmpty ? null : cover) : avatar,
    cover: cover.isEmpty ? null : cover,
    link: jdliveWatchUrl(liveId),
    audience: totalViews == null ? null : LiveAudience.ofMetric(totalViews, LiveAudienceMetric.totalViewers),
    restriction: isLive || appOnly ? restriction : null,
    reportedStateCode: statusCode,
    // A replay card is the finished part of this broadcast, and the site's own route says so.
    catchUp: state == JdState.replay ? const LiveCatchUp(active: true, source: 'jdlive.status') : null,
    danmakuPayload: <String, Object?>{if (isLive) 'liveId': liveId},
    headers: jdliveMediaHeaders(liveId),
    sitePayload: const <String, Object?>{},
    extra: <String, Object?>{'jdlive.state': state.name, if (appOnly) 'jdlive.secret': true},
  );
}

/// One cursor page of the directory.
final class JdDirectoryPage {
  const JdDirectoryPage({required this.rooms, required this.cursor, required this.hasMore});

  final List<JdRoom> rooms;
  final String? cursor;
  final bool hasMore;
}

/// The walk's continuation: the timestamp the first request used and the count the last answer reported.
String jdliveEncodeCursor(int timestamp, int currentCount) => '$timestamp@$currentCount';

({int timestamp, int currentCount})? jdliveDecodeCursor(String? cursor) {
  final value = cursor?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  final at = value.lastIndexOf('@');
  if (at <= 0 || at == value.length - 1) {
    throw const JdFailure('not a jdlive directory cursor');
  }
  final timestamp = int.tryParse(value.substring(0, at));
  final currentCount = int.tryParse(value.substring(at + 1));
  if (timestamp == null || timestamp < 1 || currentCount == null || currentCount < 0) {
    throw const JdFailure('not a jdlive directory cursor');
  }
  return (timestamp: timestamp, currentCount: currentCount);
}

/// A live id: 5..18 digits with no leading zero.
String jdliveId(String value) {
  final id = value.trim();
  if (!RegExp(r'^[1-9][0-9]{4,17}$').hasMatch(id)) {
    throw JdFailure('not a jdlive live id: "$id"');
  }
  return id;
}

/// The watch page. The site is a hash-routed app, so the route lives in the fragment.
String jdliveWatchUrl(String liveId) => '$jdliveWebOrigin/#/${jdliveId(liveId)}';

/// The per-room media headers. The cdn checks the referer against the room it issued the address for.
Map<String, String> jdliveMediaHeaders(String liveId) => <String, String>{
  'user-agent': jdliveUserAgent,
  'origin': jdliveWebOrigin,
  'referer': jdliveWatchUrl(liveId),
};

/// The live id in a jdlive url, or null. `#/<id>` with an optional route word (`live`, `notice`, `closed`,
/// `replay`) is what the app publishes; a url without the fragment is the shell and names nobody.
String? jdliveRoomFromUri(Uri uri) {
  if (!const <String>{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
      uri.host.toLowerCase() != 'lives.jd.com' ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
    return null;
  }
  final match = RegExp(r'^/?([1-9][0-9]{4,17})(?:/(?:live|notice|closed|replay))?(?:\?.*)?$').firstMatch(uri.fragment);
  final id = match?.group(1);
  return id == null ? null : jdliveId(id);
}

/// The state numbers. The directory and the room answer share them.
JdState jdliveState(int? status) => switch (status) {
  1 => JdState.live,
  0 => JdState.preview,
  2 => JdState.offline,
  3 => JdState.replay,
  10 || 11 => JdState.paused,
  _ => JdState.unknown,
};

/// A media address: https on the delivery family, under `/live/`, with the container's own extension.
Uri? jdliveMediaUri(Object? raw, {required String extension}) {
  final value = _text(raw);
  if (value.isEmpty || value.length > 8192 || RegExp(r'[\s\x00-\x1f]').hasMatch(value)) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      !jdliveHostIs(uri.host, 'jdcloud.com') ||
      (uri.hasPort && uri.port != 443) ||
      !uri.path.startsWith('/live/') ||
      !uri.path.toLowerCase().endsWith(extension)) {
    return null;
  }
  return uri;
}

bool jdliveHostIs(String host, String root) {
  final value = host.toLowerCase();
  return value == root || value.endsWith('.$root');
}

String? jdliveImage(Object? raw) {
  final value = _text(raw);
  if (value.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      !jdliveHostIs(uri.host, '360buyimg.com')) {
    return null;
  }
  return uri.toString();
}

/// The stem that identifies one stream regardless of container.
String jdliveStreamKey(Uri uri) {
  final segments = uri.pathSegments;
  final name = segments.isEmpty ? '' : segments.last;
  return name.replaceFirst(RegExp(r'\.(?:m3u8|flv)$', caseSensitive: false), '');
}

/// The master playlist, checked before its address is handed to a player.
///
/// Every reference has to stay on the issuing host, under `/live/`, and keep the stream's own stem; an answer
/// with no media reference at all is a stub page, not a playlist.
void jdliveValidatePlaylist(String source, {required Uri expected}) {
  if (source.length > 1024 * 1024 || !source.trimLeft().startsWith('#EXTM3U')) {
    throw const JdFailure('the playlist is not an m3u8');
  }
  final stem = jdliveStreamKey(expected);
  var references = 0;
  for (final raw in const LineSplitter().convert(source)) {
    final line = raw.trim();
    if (line.isEmpty) {
      continue;
    }
    if (line.startsWith('#')) {
      for (final match in RegExp('URI="([^"]+)"').allMatches(line)) {
        if (!_validChild(expected, match.group(1)!, stem)) {
          throw const JdFailure('the playlist points outside this stream');
        }
        references++;
      }
      continue;
    }
    if (!_validChild(expected, line, stem)) {
      throw const JdFailure('the playlist points outside this stream');
    }
    references++;
    if (references > jdlivePlaylistReferenceLimit) {
      throw const JdFailure('the playlist names more references than a live stream should');
    }
  }
  if (references < 1) {
    throw const JdFailure('the playlist names no media');
  }
}

bool _validChild(Uri expected, String raw, String stem) {
  final child = expected.resolve(raw);
  return child.scheme == 'https' &&
      child.userInfo.isEmpty &&
      !child.hasFragment &&
      child.host.toLowerCase() == expected.host.toLowerCase() &&
      (!child.hasPort || child.port == 443) &&
      child.path.startsWith('/live/') &&
      child.pathSegments.isNotEmpty &&
      child.pathSegments.last.startsWith(stem);
}

/// A directory card. A row that is not a room template, or whose two id fields disagree, is skipped: those rows
/// are banners and slots the site interleaves, and turning one into a tile gives a card that cannot be opened.
JdRoom? jdliveCard(Object? raw) {
  final card = jsonMap(raw);
  if (card == null) {
    throw const JdFailure('a directory row is not an object');
  }
  if (jsonInt(card['templateType']) != 1) {
    return null;
  }
  final item = jsonMap(card['data']) ?? const <String, Object?>{};
  final liveId = _id(item['liveId'] ?? item['id']);
  if (liveId == null || _id(item['id']) != liveId) {
    return null;
  }
  final status = jsonInt(item['status']);
  return JdRoom(
    liveId: liveId,
    state: jdliveState(status),
    statusCode: status,
    authorId: _id(item['authorId']) ?? '',
    nick: _text(item['userName']),
    title: _text(item['title']),
    avatar: jdliveImage(item['userPic']) ?? '',
    cover: jdliveImage(item['indexImage']) ?? '',
    totalViews: jsonInt(item['pv']),
    // A card never carries the address: that is the room endpoint's answer.
  );
}

/// The directory answer: its rooms and the count the next request has to send back.
({List<JdRoom> rooms, int nextCount, bool advanced}) jdliveDirectory(Object? value, {int? previousCount}) {
  final data = _data(value);
  final seen = <String>{};
  final rooms = <JdRoom>[
    for (final raw in _rows(data['list']))
      if (jdliveCard(raw) case final JdRoom room when seen.add(room.liveId)) room,
  ];
  final nextCount = jsonInt(data['currentCount']);
  if (nextCount == null || nextCount < 0) {
    throw const JdFailure('the directory carries no continuation count');
  }
  // A count that did not move is the site saying it has nothing further to give.
  return (rooms: rooms, nextCount: nextCount, advanced: previousCount == null || nextCount > previousCount);
}

/// The room answer, with its two containers.
JdRoom jdliveRoom(Object? value, {required String expectedLiveId}) {
  final liveId = jdliveId(expectedLiveId);
  final data = _data(value);
  if (_id(data['liveId']) != liveId) {
    throw JdFailure('the room answer is about ${data['liveId']} while asking about $liveId');
  }
  final status = jsonInt(data['status']);
  final state = jdliveState(status);
  final hls = jdliveMediaUri(data['h5VideoUrl'], extension: '.m3u8');
  final flv = jdliveMediaUri(data['videoUrl'], extension: '.flv');
  // The site's own proof that the two addresses are one stream. If the stems disagree, the answer pairs this
  // broadcast with someone else's file and nothing about it is safe to play.
  if (state == JdState.live && hls != null && flv != null && jdliveStreamKey(hls) != jdliveStreamKey(flv)) {
    throw const JdFailure('the hls and flv addresses name different streams');
  }
  return JdRoom(
    liveId: liveId,
    state: state,
    statusCode: status,
    hls: hls,
    flv: flv,
    appOnly: jsonInt(data['secret']) == 1,
  );
}

Map<String, Object?> _data(Object? value) {
  final root = jsonMap(value);
  if (root == null) {
    throw const JdFailure('the answer is not an object');
  }
  // `code` and `subCode` are text on this gateway, so '0' is the success value and 0 never matches.
  final code = _text(root['code']);
  if (code != '0') {
    throw JdFailure('the gateway refused', code: code);
  }
  final subCode = _text(root['subCode']);
  if (subCode != '0') {
    throw JdFailure('the gateway has no such live', code: code, subCode: subCode, missing: true);
  }
  return jsonMap(root['data']) ?? const <String, Object?>{};
}

List<Object?> _rows(Object? value) {
  if (value is! List || value.length > jdliveRowLimit) {
    throw const JdFailure('the list is missing or unreasonably long');
  }
  return value;
}

String? _id(Object? value) {
  final text = _text(value);
  return RegExp(r'^[1-9][0-9]{4,17}$').hasMatch(text) ? text : null;
}

String _text(Object? value) => value is String ? value.trim() : (value == null ? '' : '${value}'.trim());

/// The jdlive client.
final class JdApi {
  JdApi({NetworkClient? client, Clock? clock})
    : _client = client ?? NetworkClient(),
      _ownsClient = client == null,
      _clock = clock ?? systemClock;

  final NetworkClient _client;
  final bool _ownsClient;
  final Clock _clock;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// One page of the featured directory.
  ///
  /// The first call fixes a timestamp for the walk and sends `currentCount: 0`; every later call sends the count
  /// the previous answer reported together with that same timestamp, so the cursor - not a page number - is what
  /// makes the next request mean "after what I already showed".
  Future<JdDirectoryPage> directory({String? cursor}) async {
    final continuation = jdliveDecodeCursor(cursor);
    final timestamp = continuation?.timestamp ?? _clock().millisecondsSinceEpoch;
    final body = jsonEncode(<String, Object?>{
      'tabId': 1,
      'currentCount': '${continuation?.currentCount ?? 0}',
      'page': continuation == null ? 1 : continuation.currentCount ~/ jdlivePageSize + 1,
      'timestamp': timestamp,
    });
    final data = await _get('liveListWithTabToM', body, nonce: 'v');
    final page = jdliveDirectory(data, previousCount: continuation?.currentCount);
    final hasMore = page.advanced && page.rooms.length >= jdlivePageSize;
    return JdDirectoryPage(
      rooms: page.rooms,
      cursor: hasMore ? jdliveEncodeCursor(timestamp, page.nextCount) : null,
      hasMore: hasMore,
    );
  }

  /// The room: state, the two container addresses and the app-only flag. One call, no media read.
  Future<JdRoom> room(String input) async {
    final liveId = jdliveId(input);
    final data = await _get('getImmediatePlayToM', jsonEncode(<String, String>{'liveId': liveId}), nonce: 't');
    return jdliveRoom(data, expectedLiveId: liveId);
  }

  /// The hls grant, read before its address is handed to a player.
  ///
  /// The site's grant is a directory rather than a file, so an address whose playlist points at another stream is
  /// not this broadcast. The flv container is a direct stream with no manifest of its own and is not fetched here.
  Future<void> validateHls(JdRoom room) async {
    final hls = room.hls;
    if (hls == null) {
      throw const JdFailure('the on-air live shipped no playlist address');
    }
    jdliveValidatePlaylist(
      await _fetch(hls, liveId: room.liveId, what: 'the playlist'),
      expected: hls,
    );
  }

  Future<Map<String, Object?>> _get(
    String functionId,
    String body, {
    required String nonce,
    Map<String, String>? extra,
  }) async {
    final response = await _client.getText(
      '$jdliveApiOrigin/api',
      headers: jdliveApiHeaders,
      queryParameters: <String, String>{
        'appid': 'h5-live',
        'functionId': functionId,
        nonce: '${_clock().millisecondsSinceEpoch}',
        'body': body,
        ...?extra,
      },
    );
    return _decode(response, functionId);
  }

  Future<String> _fetch(Uri uri, {required String liveId, required String what}) async {
    final response = await _client.getText(uri.toString(), headers: jdliveMediaHeaders(liveId));
    if (response.statusCode != 200) {
      throw JdFailure('the $what answered ${response.statusCode}', code: '${response.statusCode}');
    }
    return response.body;
  }

  Map<String, Object?> _decode(TextResponse response, String what) {
    if (response.statusCode != 200) {
      throw JdFailure(
        'the $what endpoint answered ${response.statusCode}',
        code: '${response.statusCode}',
        missing: response.statusCode == 404,
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw JdFailure('the $what endpoint answered something that is not an object');
      }
      return Map<String, Object?>.from(decoded);
    } on FormatException catch (error) {
      throw JdFailure('the $what endpoint answered something that is not json', cause: error);
    }
  }
}
