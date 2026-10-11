// Module: lib/src/missevan/missevan_api.dart
// Purpose: 猫耳FM 直播的请求面:分类 tab、原生分页目录、开播房搜索、房间详情与那两条 bilivideo CDN 拉流地址。
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoints, the `code`/`500030004` envelope, the pagination identity checks, the "pagesize=20 但
// Datas 有 22 行" quirk and the media-url shape follow the v1-maintained Missevan line
// (origin/master lib/shared/platforms/missevan/missevan_api.dart). Fresh implementation against the v2 capability
// contracts, not a file merge (UPSTREAM_REVIEW_POLICY.md).
//
// The rules that are worth more than the endpoint list:
//   * **only `500030004` means "no such room"**. Any other non-zero `code` is a service failure, and treating it
//     as offline is what makes a follow list stop watching a broadcast that is up;
//   * **the pagination answer has to echo the request** (`p` and `pagesize`), and a page past `maxpage` that
//     still carries rows is a schema change, not more results;
//   * **the row count may legitimately exceed the nominal page size** (promotion entries are appended). Dropping
//     the extras to match `pagesize` is a filter nobody asked for and it silently hides live rooms;
//   * **the CDN host is bilibili's** (`*.bilivideo.com`) - the media is validated against that shape with its
//     signed `expires`, and normalised to https the way the official client does. It is not a bug to "fix".

import 'dart:convert';

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import '../common/site_json.dart';

const String missevanSourceId = 'missevan.live';
const String missevanOrigin = 'https://fm.missevan.com';
const String missevanApiPrefix = 'https://fm.missevan.com/api/v2/';

/// The server's own page size for the open-room list. It is not a knob the caller may turn.
const int missevanServerPageSize = 20;

/// The code that, alone, says "this room does not exist".
const int missevanMissingRoomCode = 500030004;

const String missevanUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

const Map<String, String> missevanHeaders = <String, String>{
  'user-agent': missevanUserAgent,
  'referer': '$missevanOrigin/',
  'origin': missevanOrigin,
};

final class MissevanFailure implements Exception {
  const MissevanFailure(this.message, {this.code, this.cause});

  final String message;
  final int? code;
  final Object? cause;

  @override
  String toString() =>
      'MissevanFailure($message${code == null ? '' : ', code $code'}${cause == null ? '' : ': $cause'})';
}

/// A category tab. Missevan addresses tabs by `(type, id)` where the id field is named after the type
/// (`catalog_id` / `tag_id`), so both parts have to travel together.
final class MissevanTab {
  const MissevanTab({required this.type, required this.id, required this.name, this.icon});

  final String type;
  final int id;
  final String name;
  final String? icon;

  static String encode(String type, int id) => '$type:$id';
}

/// One room as the list or the detail answer described it.
final class MissevanRoom {
  const MissevanRoom({
    required this.roomId,
    required this.creatorId,
    required this.isOpen,
    required this.title,
    required this.nick,
    required this.link,
    this.cover,
    this.avatar,
    this.introduction,
    this.notice,
    this.area,
    this.popularity,
    this.followers,
    this.streamUrls = const <String>[],
  });

  final String roomId;
  final String creatorId;

  /// `status.open == 1`. The site's own word for "this room is broadcasting".
  final bool isOpen;
  final String title;
  final String nick;
  final String link;
  final String? cover;
  final String? avatar;
  final String? introduction;
  final String? notice;
  final String? area;

  /// `statistics.score` - a heat/popularity score. It is deliberately not named `viewers`: the v1 sampling says
  /// attention_count is followers and nothing on this answer counts heads.
  final int? popularity;
  final int? followers;

  /// The flv and hls pull addresses, in that order, once the media endpoint has been consulted.
  final List<String> streamUrls;

  LiveRoom toLiveRoom() => LiveRoom(
    ref: ContentRef(sourceId: missevanSourceId, contentId: roomId, kind: ContentKind.liveRoom),
    state: isOpen ? LiveRoomState.live : LiveRoomState.ended,
    title: title.isEmpty ? nick : title,
    anchorName: nick.isEmpty ? null : nick,
    anchorId: creatorId,
    link: link,
    avatar: avatar,
    cover: cover,
    area: area,
    introduction: introduction,
    notice: notice,
    followers: followers,
    // The score is a heat number; saying `popularity` out loud is what keeps a surface from printing 人在看.
    audience: LiveAudience(popularity: popularity, metric: LiveAudienceMetric.popularity),
    streamId: isOpen ? roomId : null,
    // Missevan is audio-first on FM: v1 refuses to infer "audio only" from the platform label, because the
    // sampled broadcasts carry AAC *plus* a 16x16 H.264 track. The player decides from the media, not from us.
    sitePayload: const <String, Object?>{},
    danmakuPayload: isOpen ? <String, Object?>{'roomId': roomId} : const <String, Object?>{},
    headers: const <String, String>{'referer': missevanOrigin, 'origin': missevanOrigin},
    extra: <String, Object?>{if (popularity != null) 'score': popularity},
  );
}

/// One native page, with the server's own pagination evidence kept alongside it.
final class MissevanDirectoryPage {
  const MissevanDirectoryPage({required this.rooms, required this.page, required this.maxPage, required this.count});

  final List<MissevanRoom> rooms;
  final int page;
  final int maxPage;
  final int count;

  bool get hasMore => page < maxPage;
}

/// The Missevan live client.
final class MissevanApi {
  MissevanApi({NetworkClient? client}) : _client = client ?? NetworkClient(), _ownsClient = client == null;

  final NetworkClient _client;
  final bool _ownsClient;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// The category tabs. A tab whose id field is not named after its type, or that repeats, is a schema change and
  /// is reported as one: a half-read category list silently drops a whole section of the site.
  Future<List<MissevanTab>> tabs() async {
    final info = await _get('meta/data');
    final list = info['tabs'];
    if (list is! List || list.isEmpty || list.length > 100) {
      throw const MissevanFailure('the tab list is missing, empty or unreasonably long');
    }
    final byKey = <String, MissevanTab>{};
    for (final raw in list) {
      final tab = jsonMap(raw) ?? const <String, Object?>{};
      final type = '${tab['type'] ?? ''}'.trim();
      final id = jsonInt(tab['${type}_id']);
      final name = '${tab['name'] ?? ''}'.trim();
      if (!const <String>{'catalog', 'tag'}.contains(type) || id == null || id <= 0 || name.isEmpty) {
        throw MissevanFailure('a tab carries an unusable type/id pair: "$type"/"$id"');
      }
      final key = MissevanTab.encode(type, id);
      if (byKey.containsKey(key)) {
        throw MissevanFailure('the tab list repeats $key');
      }
      byKey[key] = MissevanTab(type: type, id: id, name: name, icon: _picture(tab['icon_url']));
    }
    return byKey.values.toList(growable: false);
  }

  /// One native page of rooms that are open right now.
  Future<MissevanDirectoryPage> directory({int page = 1, String? tab}) async {
    if (page < 1 || page > 10000) {
      throw const MissevanFailure('directory pages are 1..10000');
    }
    final query = <String, String>{'p': '$page'};
    if (tab != null && tab.isNotEmpty) {
      final parts = tab.split(':');
      if (parts.length != 2 || !const <String>{'catalog', 'tag'}.contains(parts.first)) {
        throw MissevanFailure('not a missevan tab key: "$tab"');
      }
      query['${parts.first}_id'] = validateRoomId(parts.last);
    }
    final info = await _get('chatroom/open/list', query: query);
    final pagination = jsonMap(info['pagination']) ?? const <String, Object?>{};
    final maxPage = jsonInt(pagination['maxpage']);
    final count = jsonInt(pagination['count']);
    final rows = info['Datas'];
    // The answer must echo what was asked. A page that comes back with someone else's `p` or a different
    // pagesize is a redirect or a cache, and paging on top of it duplicates or skips rooms.
    if (jsonInt(pagination['p']) != page ||
        jsonInt(pagination['pagesize']) != missevanServerPageSize ||
        maxPage == null ||
        maxPage < 0 ||
        count == null ||
        count < 0 ||
        rows is! List ||
        rows.length > 100 ||
        (page > maxPage && rows.isNotEmpty)) {
      throw const MissevanFailure('the directory pagination does not describe this request');
    }
    final seen = <String>{};
    final rooms = <MissevanRoom>[];
    for (final raw in rows) {
      final room = _room(jsonMap(raw) ?? const <String, Object?>{});
      // Only open rooms: the list mixes in scheduled and closed ones, and a closed room on a live grid reads as
      // a broken tile.
      if (room.isOpen && seen.add(room.roomId)) {
        rooms.add(room);
      }
    }
    return MissevanDirectoryPage(rooms: rooms, page: page, maxPage: maxPage, count: count);
  }

  /// Search over rooms. Offline creators come back too - the endpoint is a creator index, not a live grid - so
  /// callers show their state instead of assuming.
  Future<List<MissevanRoom>> search(String keyword, {int page = 1}) async {
    final term = keyword.trim();
    if (term.isEmpty || term.length > 100 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(term)) {
      throw const MissevanFailure('a search term must be 1-100 printable characters');
    }
    if (page < 1 || page > 10000) {
      throw const MissevanFailure('search pages are 1..10000');
    }
    final info = await _get(
      'chatroom/search',
      query: <String, String>{'s': term, 'p': '$page', 'page_size': '$missevanServerPageSize'},
    );
    final pagination = jsonMap(info['pagination']) ?? const <String, Object?>{};
    final maxPage = jsonInt(pagination['maxpage']);
    final rows = info['data'];
    if (jsonInt(pagination['p']) != page ||
        jsonInt(pagination['pagesize']) != missevanServerPageSize ||
        maxPage == null ||
        maxPage < 0 ||
        jsonInt(pagination['count']) == null ||
        rows is! List ||
        rows.length > 100 ||
        (page > maxPage && rows.isNotEmpty)) {
      throw const MissevanFailure('the search pagination does not describe this request');
    }
    final seen = <String>{};
    return <MissevanRoom>[
      for (final raw in rows)
        if (_room(jsonMap(raw) ?? const <String, Object?>{}) case final MissevanRoom room when seen.add(room.roomId))
          room,
    ];
  }

  /// The room in full, with its pull addresses when it is open.
  Future<MissevanRoom> room(String input) async {
    final id = validateRoomId(input);
    final info = await _get('live/$id');
    final base = _room(jsonMap(info['room']) ?? const <String, Object?>{});
    if (base.roomId != id) {
      throw MissevanFailure('the room answer is about ${base.roomId} while asking about $id');
    }
    var room = base;
    if (jsonMap(info['creator']) case final Map<String, Object?> creator) {
      // The creator block has to be the same person the room names; a mismatch is an answer about someone else.
      if (validateRoomId('${creator['user_id'] ?? ''}') != base.creatorId) {
        throw const MissevanFailure('the room and its creator block name different people');
      }
      room = MissevanRoom(
        roomId: base.roomId,
        creatorId: base.creatorId,
        isOpen: base.isOpen,
        title: base.title,
        nick: base.nick,
        link: base.link,
        cover: base.cover,
        avatar: _picture(creator['iconurl']) ?? base.avatar,
        introduction: '${creator['introduction'] ?? ''}'.trim().isEmpty
            ? base.introduction
            : '${creator['introduction']}'.trim(),
        notice: base.notice,
        area: base.area,
        popularity: base.popularity,
        followers: base.followers,
      );
    }
    if (!room.isOpen) {
      // An offline room never looks at the channel urls: they are stale from the last broadcast, and opening one
      // plays yesterday's stream under today's title.
      return room;
    }
    final channel = jsonMap(jsonMap(info['room'])?['channel']) ?? const <String, Object?>{};
    final urls = <String>[
      for (final (key, kind) in const <(String, String)>[('flv_pull_url', 'flv'), ('hls_pull_url', 'hls')])
        if (_mediaUrl(channel[key], kind: kind) case final String url) url,
    ];
    if (urls.isEmpty) {
      throw const MissevanFailure('an open room answered with no address we are willing to play');
    }
    return MissevanRoom(
      roomId: room.roomId,
      creatorId: room.creatorId,
      isOpen: room.isOpen,
      title: room.title,
      nick: room.nick,
      link: room.link,
      cover: room.cover,
      avatar: room.avatar,
      introduction: room.introduction,
      notice: room.notice,
      area: room.area,
      popularity: room.popularity,
      followers: room.followers,
      streamUrls: urls,
    );
  }

  Future<Map<String, Object?>> _get(String path, {Map<String, String>? query}) async {
    final response = await _client.getText('$missevanApiPrefix$path', headers: missevanHeaders, queryParameters: query);
    if (response.statusCode != 200) {
      throw MissevanFailure('$path answered ${response.statusCode}', code: response.statusCode);
    }
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw MissevanFailure('$path answered something that is not json', cause: error);
    }
    final data = jsonMap(decoded);
    if (data == null) {
      throw const MissevanFailure('the answer is not a json object');
    }
    final code = jsonInt(data['code']);
    if (code == null) {
      throw const MissevanFailure('the answer carries no code field');
    }
    if (code == missevanMissingRoomCode) {
      throw MissevanFailure('no such room', code: code);
    }
    if (code != 0) {
      throw MissevanFailure('missevan refused the request', code: code);
    }
    return jsonMap(data['info']) ?? const <String, Object?>{};
  }

  static MissevanRoom _room(Map<String, Object?> row) {
    final roomId = validateRoomId('${row['room_id'] ?? ''}');
    final creatorId = validateRoomId('${row['creator_id'] ?? roomId}');
    final open = jsonInt(jsonMap(row['status'])?['open']);
    if (open != 0 && open != 1) {
      throw MissevanFailure('a room row carries status.open as "$open"');
    }
    final stats = jsonMap(row['statistics']) ?? const <String, Object?>{};
    final score = jsonInt(stats['score']);
    if (score != null && score < 0) {
      throw const MissevanFailure('a room row carries a negative score');
    }
    final followers = jsonInt(stats['attention_count']);
    return MissevanRoom(
      roomId: roomId,
      creatorId: creatorId,
      isOpen: open == 1,
      title: _text(row['name']),
      nick: _text(row['creator_username']),
      link: '$missevanOrigin/live/$roomId',
      cover: _picture(row['cover_url']),
      avatar: _picture(row['creator_iconurl']),
      introduction: _emptyToNull(_text(row['creator_introduction'])),
      notice: _emptyToNull(_text(row['announcement'])),
      area: _emptyToNull(_text(row['catalog_name'])),
      popularity: score,
      followers: followers != null && followers >= 0 ? followers : null,
    );
  }

  /// A room id is a positive integer that fits 64 bits.
  static String validateRoomId(String value) {
    final id = value.trim();
    if (!RegExp(r'^[1-9][0-9]{0,17}$').hasMatch(id)) {
      throw MissevanFailure('not a missevan room id: "$id"');
    }
    return id;
  }

  /// The watch-page link, or null. `…/live/<id>` and nothing else.
  static String? roomFromUri(Uri uri) {
    if (!const <String>{'http', 'https'}.contains(uri.scheme) ||
        uri.host != 'fm.missevan.com' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
      return null;
    }
    final parts = <String>[
      for (final part in uri.pathSegments)
        if (part.isNotEmpty) part,
    ];
    if (parts.length != 2 || parts.first != 'live') {
      return null;
    }
    try {
      return validateRoomId(parts.last);
    } on MissevanFailure {
      return null;
    }
  }

  /// A pull address.
  ///
  /// The CDN is bilibili's (`*.bilivideo.com`) - 猫耳FM rents bilibili's live delivery - so the host is part of
  /// the expected shape, not a mistake. The extension must match the kind, the signed `expires` must be a single
  /// ten-digit value, and the address is normalised to https the way the official client does, with the query
  /// kept byte-for-byte.
  static String? _mediaUrl(Object? raw, {required String kind}) {
    final value = _text(raw);
    if (value.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !const <String>{'http', 'https'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
        !uri.host.endsWith('.bilivideo.com') ||
        !uri.path.endsWith(kind == 'hls' ? '.m3u8' : '.flv')) {
      throw MissevanFailure('a $kind pull address is not the shape the site ships');
    }
    final expires = uri.queryParametersAll['expires'];
    if (expires != null && (expires.length != 1 || !RegExp(r'^[0-9]{10}$').hasMatch(expires.single))) {
      throw const MissevanFailure('a pull address carries an unreadable expiry');
    }
    return uri.replace(scheme: 'https', port: 443).toString();
  }

  static String _text(Object? raw) => raw is String ? raw.trim() : '';

  static String? _emptyToNull(String value) => value.isEmpty ? null : value;

  static String? _picture(Object? raw) {
    var value = _text(raw);
    if (value.isEmpty) {
      return null;
    }
    if (value.startsWith('//')) {
      value = 'https:$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !const <String>{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
      return null;
    }
    return uri.userInfo.isEmpty ? value : null;
  }
}
