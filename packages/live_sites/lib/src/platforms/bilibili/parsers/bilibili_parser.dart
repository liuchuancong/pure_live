import 'dart:convert';

import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_models.dart';

/// Static parsers for the Bilibili live web APIs: JSON body in, domain
/// models out. Status codes other than 200 map to typed errors.
abstract final class BilibiliParser {
  /// Validates the envelope (`code`/`message`) and returns the payload
  /// object.
  static Map<String, Object?> checked(String body, {int status = 200, String what = 'response'}) {
    if (status == 412) {
      throw SiteRateLimitedError('bilibili $what: request intercepted (412)');
    }
    if (status != 200) {
      throw SiteApiChangedError('bilibili $what: HTTP $status');
    }
    final Object? root;
    try {
      root = jsonDecode(body);
    } on FormatException catch (error) {
      throw SiteApiChangedError('bilibili $what: body is not JSON (${error.message})');
    }
    if (root is! Map<String, Object?>) {
      throw SiteApiChangedError('bilibili $what: body is not an object');
    }
    final code = SiteCounts.integer(root['code']);
    if (code == 0) {
      final data = root['data'];
      if (data is Map<String, Object?>) {
        return data;
      }
      throw SiteApiChangedError('bilibili $what: data is not an object');
    }
    final message = root['message']?.toString() ?? root['msg']?.toString() ?? '';
    if (code == -404 || message.contains('不存在')) {
      throw SiteNotFoundError('bilibili $what: $message');
    }
    if (code == -101) {
      throw SiteNeedsLoginError('bilibili $what: $message');
    }
    if (code == -352 || code == -799) {
      throw SiteRiskControlError('bilibili $what: $message');
    }
    throw SiteApiChangedError('bilibili $what: code $code, $message');
  }

  /// Like [checked], but for the endpoints whose `data` is an array.
  ///
  /// `Area/getList` answers `{"code":0,"data":[…]}` — the same envelope with
  /// a list where the others put an object — so the object-shaped rule
  /// rejects an answer that is perfectly fine.
  static List<Object?> checkedList(String body, {int status = 200, String what = 'response'}) {
    if (status == 412) {
      throw SiteRateLimitedError('bilibili $what: request intercepted (412)');
    }
    if (status != 200) {
      throw SiteApiChangedError('bilibili $what: HTTP $status');
    }
    final Object? root;
    try {
      root = jsonDecode(body);
    } on FormatException catch (error) {
      throw SiteApiChangedError('bilibili $what: body is not JSON (${error.message})');
    }
    if (root is! Map<String, Object?>) {
      throw SiteApiChangedError('bilibili $what: body is not an object');
    }
    final code = SiteCounts.integer(root['code']);
    if (code != 0) {
      final message = root['message']?.toString() ?? root['msg']?.toString() ?? '';
      throw SiteApiChangedError('bilibili $what: code $code, $message');
    }
    final data = root['data'];
    return data is List ? data : const <Object?>[];
  }

  /// The envelope rule for endpoints a *guest* is allowed to call.
  ///
  /// `nav` answers `code: -101 账号未登录` to an anonymous session and still
  /// ships the WBI keys in `data` — which is exactly what a guest needs,
  /// because signing is what makes an anonymous call legal in the first
  /// place. Applying the strict rule here (as this used to) turned every
  /// signed request into "账号未登录" before it reached its endpoint; the
  /// payload is only rejected when the keys really are missing.
  static Map<String, Object?> anonymousChecked(String body, {int status = 200, String what = 'response'}) {
    if (status == 200) {
      Object? root;
      try {
        root = jsonDecode(body);
      } on FormatException {
        root = null;
      }
      if (root is Map<String, Object?>) {
        final data = root['data'];
        if (data is Map<String, Object?> && data.isNotEmpty) {
          return data;
        }
      }
    }
    return checked(body, status: status, what: what);
  }

  /// `room/v1/Room/get_info` payload → room detail.
  static LiveRoom roomDetail(Map<String, Object?> data, {required String requestedId}) {
    final longId = data['room_id']?.toString() ?? requestedId;
    final liveStatus = SiteCounts.integer(data['live_status']) ?? 0;
    return LiveRoom(
      platform: SiteIds.bilibili,
      roomId: longId,
      title: data['title']?.toString() ?? '',
      nick: _userName(data),
      areaId: data['area_id']?.toString(),
      areaName: data['area_name']?.toString(),
      status: _status(liveStatus),
      watching: SiteCounts.integer(data['online']),
      startedAt: (data['live_time'] as String?) == null || data['live_time'] == '0' || data['live_time'] == ''
          ? null
          : DateTime.tryParse(data['live_time']!.toString()),
    );
  }

  /// `room/v1/area/getRoomList` payload → one page of rooms.
  /// A directory payload → one page of rooms.
  ///
  /// The live endpoints disagree on their shape, so this reads all three:
  /// `data.list` (the category list), `data.recommend_room_list` (the
  /// personalisation feed) and a bare `data` array (the ranked list). The
  /// item fields differ too — `area_name` in one, `areaName` in another,
  /// `area_v2_name` in the third — which is what [_listRoom] absorbs; a
  /// parser that knew only one shape returned an empty page for two of the
  /// three, which is exactly what happened before this was written.
  static LivePage<LiveRoom> roomList(Object? data) {
    final payload = data is Map<String, Object?> ? (data['list'] ?? data['recommend_room_list']) : data;
    final items = payload is List ? payload : const <Object?>[];
    final rooms = <LiveRoom>[
      for (final item in items)
        if (item is Map<String, Object?>)
          if (_listRoom(item) case final room when room.roomId.isNotEmpty) room,
    ];
    return LivePage<LiveRoom>(items: rooms, hasMore: rooms.isNotEmpty);
  }

  /// `search/type?search_type=live_user` → the streamers matching a keyword.
  ///
  /// The rows are *people*, not rooms: a user who is not broadcasting has no
  /// room id at all, which is why this returns anchors — the ones who are on
  /// air carry the room to open, and the rest are people the user can still
  /// find and follow.
  static LivePage<LiveAnchor> searchAnchors(List<Object?> rows) => LivePage<LiveAnchor>(
    items: [
      for (final row in rows)
        if (row is Map<String, Object?>)
          if (SiteText.trimmed(row['mid']) case final id when id.isNotEmpty)
            LiveAnchor(
              id: id,
              roomId: SiteCounts.integer(row['roomid']) == null ? null : SiteText.trimmed(row['roomid']),
              name: SiteText.title(SiteText.text(row['uname'])),
              avatar: _anchorAvatar(row['uface']),
              live: SiteCounts.flag(row['is_live']),
            ),
    ],
    hasMore: rows.length >= 30,
  );

  /// An anchor's avatar, with the size suffix the search rows need.
  static String? _anchorAvatar(Object? value) {
    final url = SiteText.trimmed(value);
    if (url.isEmpty) {
      return null;
    }
    final absolute = url.startsWith('//') ? 'https:$url' : url;
    return absolute.contains('@') ? absolute : '$absolute@240w_240h_1c_1s.webp';
  }

  /// `search/type?search_type=live_room` payload → one page of rooms.
  static LivePage<LiveRoom> searchRooms(Map<String, Object?> data, {required int page}) {
    final result = data['result'];
    final rooms = <LiveRoom>[];
    if (result is List) {
      for (final item in result) {
        if (item is! Map<String, Object?>) {
          continue;
        }
        final roomId = item['roomid']?.toString() ?? '';
        if (roomId.isEmpty) {
          continue;
        }
        rooms.add(
          LiveRoom(
            platform: SiteIds.bilibili,
            roomId: roomId,
            title: SiteText.title(SiteText.text(item['title'])),
            nick: item['uname']?.toString() ?? '',
            cover: item['user_cover']?.toString() ?? item['cover']?.toString(),
            areaName: item['cate_name']?.toString(),
            status: LiveStatus.live,
            watching: int.tryParse(item['online']?.toString() ?? ''),
          ),
        );
      }
    }
    return LivePage<LiveRoom>(items: rooms, hasMore: rooms.isNotEmpty, nextPage: page + 1);
  }

  /// Removes the search highlight tags (`<em class=…>text</em>`).
  /// `Area/getList` rows → one level of the area tree.
  ///
  /// A row without an area id is skipped: an area nobody can browse by is a
  /// picker entry that does nothing.
  static List<LiveArea> areaList(List<Object?> rows) => [
    for (final row in rows)
      if (row is Map<String, Object?>)
        if (SiteText.trimmed(row['id'] ?? row['area_id']) case final id when id.isNotEmpty)
          LiveArea(
            id: id,
            name: SiteText.title(SiteText.text(row['name'] ?? row['area_name'])),
            parentId: SiteText.trimmed(row['parent_id']).isEmpty ? null : SiteText.trimmed(row['parent_id']),
            sort: SiteCounts.integer(row['sort']) ?? 0,
          ),
  ];

  /// `Area/getList` rows → the whole area tree, parents first.
  ///
  /// One request answers both levels: each parent carries its children in a
  /// nested `list`, which is what the site's own side bar draws. The children
  /// get their parent's id when they do not carry one, so `parentId` is
  /// always usable for grouping.
  static List<LiveArea> areaTree(List<Object?> parents) {
    final areas = <LiveArea>[];
    for (final parent in parents) {
      if (parent is! Map<String, Object?>) {
        continue;
      }
      final parentAreas = areaList([parent]);
      if (parentAreas.isEmpty) {
        continue;
      }
      final head = parentAreas.first;
      areas.add(head);
      for (final child in areaList(SiteJson.list(parent['list']))) {
        areas.add(child.parentId == null ? child.copyWith(parentId: head.id) : child);
      }
    }
    return areas;
  }

  /// `getRoomPlayInfo` payload → current-quality play lines (the `durl`
  /// list of the default quality).
  static List<LivePlayLine> playLines(Map<String, Object?> data) {
    final durl = data['durl'];
    final lines = <LivePlayLine>[];
    if (durl is List) {
      for (final item in durl) {
        if (item is! Map<String, Object?>) {
          continue;
        }
        final url = item['url']?.toString() ?? '';
        if (url.startsWith('http')) {
          lines.add(
            LivePlayLine(
              url: url,
              headers: BilibiliConstants.mediaHeaders,
              format: StreamFormat.flv,
              codec: SiteCounts.integer(data['current_quality']) == null ? null : 'avc',
              lineId: 'durl-${lines.length}',
            ),
          );
        }
      }
    }
    return lines;
  }

  /// `getDanmuInfo` payload → the auth token and gateway list.
  static ({String token, List<String> servers}) danmakuInfo(Map<String, Object?> data) {
    final token = data['token']?.toString() ?? '';
    final servers = <String>[BilibiliConstants.danmakuGateway];
    final hosts = data['host_list'];
    if (hosts is List) {
      for (final item in hosts) {
        if (item is! Map<String, Object?>) {
          continue;
        }
        final host = item['host']?.toString();
        if (host == null || host.isEmpty) {
          continue;
        }
        final port = SiteCounts.integer(item['wss_port']) ?? 443;
        final endpoint = 'wss://$host${port == 443 ? '' : ':$port'}/sub';
        if (!servers.contains(endpoint)) {
          servers.add(endpoint);
        }
      }
    }
    return (token: token, servers: servers);
  }

  /// One directory item, with every spelling the three payloads use.
  ///
  /// `title` is HTML-escaped in the ranked list and tag-wrapped in the feed,
  /// so it goes through the shared title pipeline (`SiteText.title`).
  static LiveRoom _listRoom(Map<String, Object?> item) => LiveRoom(
    platform: SiteIds.bilibili,
    roomId: item['roomid']?.toString() ?? '',
    title: SiteText.title(SiteText.text(item['title'])),
    nick: SiteText.title(SiteText.text(item['uname'])),
    avatar: item['uface']?.toString() ?? item['face']?.toString(),
    cover: item['user_cover']?.toString() ?? item['cover']?.toString(),
    areaName: item['area_name']?.toString() ?? item['areaName']?.toString() ?? item['area_v2_name']?.toString(),
    status: LiveStatus.live,
    watching: SiteCounts.integer(item['online']),
  );

  static String _userName(Map<String, Object?> data) {
    final info = data['anchor_info'];
    if (info is Map<String, Object?>) {
      final base = info['base_info'];
      if (base is Map<String, Object?>) {
        return base['uname']?.toString() ?? '';
      }
    }
    return '';
  }

  static LiveStatus _status(int liveStatus) => switch (liveStatus) {
    1 => LiveStatus.live,
    2 => LiveStatus.carousel,
    _ => LiveStatus.offline,
  };
}
