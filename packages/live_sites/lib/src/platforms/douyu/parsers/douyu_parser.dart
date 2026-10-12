import 'dart:convert';

import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/douyu/douyu_models.dart';

/// Static parsers for the Douyu web APIs and page payloads.
abstract final class DouyuParser {
  static final RegExp _htmlPage = RegExp(r'^\s*<');

  /// Validates a JSON envelope (`error`/`code` on the webconf APIs) and
  /// returns the decoded root.
  static Object? checked(String body, {int status = 200, String what = 'response'}) {
    if (status != 200) {
      throw SiteApiChangedError('douyu $what: HTTP $status');
    }
    final Object? root;
    try {
      root = jsonDecode(body);
    } on FormatException catch (error) {
      throw SiteApiChangedError('douyu $what: body is not JSON (${error.message})');
    }
    if (root is! Map<String, Object?>) {
      throw SiteApiChangedError('douyu $what: body is not an object');
    }
    final error = SiteCounts.integer(root['error']) ?? SiteCounts.integer(root['code']) ?? 0;
    if (error != 0) {
      final message = root['msg']?.toString() ?? root['message']?.toString() ?? '';
      throw SiteApiChangedError('douyu $what: error $error $message'.trim());
    }
    return root;
  }

  /// `getEncryption` payload → descriptor; incomplete or already-expired
  /// descriptors are API-changed errors.
  static DouyuDescriptor descriptor(Map<String, Object?> root, {required DateTime now}) {
    final descriptor = DouyuDescriptor.fromJson(root['data']);
    if (descriptor == null || !descriptor.usableAt(now)) {
      throw const SiteApiChangedError('getEncryption: descriptor incomplete or expired');
    }
    return descriptor;
  }

  /// `getH5PlayV1` payload → `data`. Non-zero `error` is a room state
  /// (e.g. `-5` not streaming) surfaced as "not found" — a retry cannot
  /// fix it.
  static Map<String, Object?> playData(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('getH5PlayV1: body is not an object');
    }
    final code = SiteCounts.integer(decoded['error']) ?? SiteCounts.integer(decoded['code']);
    if (code == null) {
      throw const SiteApiChangedError('getH5PlayV1: no error code');
    }
    if (code != 0) {
      throw SiteNotFoundError('getH5PlayV1: error $code ${decoded['msg']?.toString() ?? ''}'.trim());
    }
    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      throw const SiteApiChangedError('getH5PlayV1: no data');
    }
    return data;
  }

  /// Play lines from the `data`: `rtmp_url` + `rtmp_live` per entry of
  /// the answering CDN (`rtmp_multi_bitrate` for the other rates).
  static List<LivePlayLine> playLines(Map<String, Object?> data) {
    final url = data['rtmp_url']?.toString() ?? '';
    final path = data['rtmp_live']?.toString() ?? '';
    if (!url.startsWith('http') || path.isEmpty) {
      return const [];
    }
    return [
      LivePlayLine(
        url: '$url/$path',
        headers: mediaHeaders(data['room_id']?.toString() ?? ''),
        format: StreamFormat.flv,
        codec: 'avc',
        lineId: data['rtmp_cdn']?.toString() ?? 'cdn',
      ),
    ];
  }

  /// Standard media headers; the referer carries the room so the edge
  /// accepts the stream.
  /// Media headers of a room, or of the whole site when [roomId] is empty;
  /// [referer] overrides the derived one, for the search endpoints that
  /// expect their own page.
  static Map<String, String> mediaHeaders(String roomId, {String? referer}) => {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': referer ?? (roomId.isEmpty ? 'https://www.douyu.com/' : 'https://www.douyu.com/$roomId'),
  };

  /// The `betard/<rid>` page payload → room detail. The payload may be
  /// double-encoded JSON (`room` as a JSON string).
  static LiveRoom roomDetail(String body, {required String requestedId}) {
    if (_htmlPage.hasMatch(body.trimLeft())) {
      throw SiteNotFoundError('betard/$requestedId: HTML page');
    }
    var decoded = jsonDecode(body);
    if (decoded is String) {
      decoded = jsonDecode(decoded);
    }
    final root = decoded is Map<String, Object?> ? decoded['room'] : null;
    if (root is! Map<String, Object?>) {
      throw SiteApiChangedError('betard/$requestedId: no room');
    }
    final rid = root['room_id']?.toString() ?? '';
    if (rid.isEmpty) {
      throw SiteApiChangedError('betard/$requestedId: room.room_id missing');
    }
    final rawTitle = root['room_name']?.toString() ?? '';
    final replay = root['videoLoop']?.toString() == '1';
    final titleIsReplay = rawTitle.startsWith('【回放】');
    final live = root['show_status']?.toString() == '1' && !replay && !titleIsReplay;
    return LiveRoom(
      platform: SiteIds.douyu,
      roomId: rid,
      title: rawTitle,
      nick: root['owner_name']?.toString() ?? '',
      avatar: _image(root['owner_avatar']),
      cover: _image(root['room_pic']),
      areaName: root['second_lvl_name']?.toString(),
      watching: int.tryParse(switch (root['room_biz_all']) {
        final Map<String, Object?> biz => biz['hot']?.toString() ?? '',
        _ => '',
      }),
      status: replay ? LiveStatus.replay : (live ? LiveStatus.live : LiveStatus.offline),
    );
  }

  /// `web/api/room/list` payload → one page of live rooms.
  /// `japi/search/api/searchShow` → the rooms matching a keyword.
  ///
  /// The rows are the same shape as the directory's *older* endpoints
  /// (`roomName`, `nickName`, `roomSrc`), not the `rn`/`nn`/`rs16` spelling
  /// the directory itself uses — one platform, two vocabularies, which is
  /// why the two parsers stay separate rather than sharing a mapper.
  ///
  /// `isLive` 1 with `roomType` 0 is on air; `roomType` 1 is a rebroadcast
  /// channel and `roomType` 2 a recording, and both are a *replay* rather
  /// than live.
  static LivePage<LiveRoom> searchRooms(Map<String, Object?> root) {
    final data = SiteJson.object(root['data']);
    final rows = SiteJson.objects(data['relateShow']);
    final rooms = <LiveRoom>[
      for (final item in rows)
        if (SiteText.trimmed(item['rid']) case final id when id.isNotEmpty) _searchRoom(item, id),
    ];
    return LivePage<LiveRoom>(items: rooms, hasMore: rows.length >= 30);
  }

  static LiveRoom _searchRoom(Map<String, Object?> item, String id) {
    final live = SiteCounts.integer(item['isLive']) == 1;
    final roomType = SiteCounts.integer(item['roomType']) ?? 0;
    return LiveRoom(
      platform: SiteIds.douyu,
      roomId: id,
      title: SiteText.title(SiteText.text(item['roomName'])),
      nick: SiteText.title(SiteText.text(item['nickName'])),
      avatar: SiteText.trimmed(item['avatar']).isEmpty ? null : SiteText.trimmed(item['avatar']),
      cover: SiteText.trimmed(item['roomSrc']).isEmpty ? null : SiteText.trimmed(item['roomSrc']),
      areaName: SiteText.trimmed(item['cateName']),
      watching: SiteCounts.scaled(item['hot']),
      status: live ? (roomType == 0 ? LiveStatus.live : LiveStatus.replay) : LiveStatus.offline,
    );
  }

  /// `japi/search/api/searchUser` → the streamers matching a keyword.
  ///
  /// Each row wraps its person in `anchorInfo`, so a row without one (an
  /// advertisement, a game) names nobody and is skipped. The room id is the
  /// anchor's own `rid` — a streamer who is not broadcasting still has one,
  /// which is what makes them followable before they go live.
  static LivePage<LiveAnchor> searchAnchors(Map<String, Object?> root) {
    final data = SiteJson.object(root['data']);
    final rows = SiteJson.objects(data['relateUser']);
    final anchors = <LiveAnchor>[
      for (final item in rows)
        if (SiteJson.object(item['anchorInfo']) case final anchor when anchor.isNotEmpty)
          if (SiteText.trimmed(anchor['rid']) case final id when id.isNotEmpty)
            LiveAnchor(
              id: id,
              roomId: id,
              name: SiteText.title(SiteText.text(anchor['nickName'])),
              avatar: SiteText.trimmed(anchor['avatar']).isEmpty ? null : SiteText.trimmed(anchor['avatar']),
              live: SiteCounts.integer(anchor['isLive']) == 1 && (SiteCounts.integer(anchor['roomType']) ?? 0) == 0,
              // The follower total is `fansNum` (a number); `fansNumStr` is
              // the display form of the same value.
              count: SiteCounts.integer(anchor['fansNum']),
              areaName: SiteText.trimmed(anchor['cateName']),
            ),
    ];
    return LivePage<LiveAnchor>(items: anchors, hasMore: rows.length >= 30);
  }

  /// A directory payload → one page of rooms.
  ///
  /// The directory endpoints answer with `data.rl`, whose field names are
  /// Douyu's short ones (`rid`, `rn`, `nn`, `ol`, `c2name`, `rs16`), and
  /// `data.pgcnt` carries the page count — so `hasMore` is the site's own
  /// answer rather than a guess from a non-empty page. Items whose `type`
  /// is not a live room (advertisement and banner entries) are dropped; the
  /// room id is validated, because a garbage id would produce a card that
  /// can never open.
  static LivePage<LiveRoom> roomList(Map<String, Object?> root) {
    final data = root['data'];
    final raw = data is Map<String, Object?> ? data['rl'] : null;
    final items = raw is List ? raw : const <Object?>[];
    final rooms = <LiveRoom>[];
    for (final item in items) {
      if (item is! Map<String, Object?>) {
        continue;
      }
      final room = _listRoom(item);
      if (room != null) {
        rooms.add(room);
      }
    }
    final pages = data is Map<String, Object?> ? (SiteCounts.integer(data['pgcnt']) ?? 0) : 0;
    return LivePage<LiveRoom>(items: rooms, hasMore: rooms.isNotEmpty && pages > 0 && pages > 1);
  }

  /// One directory item, or null when it is not a live room.
  static LiveRoom? _listRoom(Map<String, Object?> item) {
    final roomId = item['rid']?.toString().trim() ?? '';
    if (roomId.isEmpty || (item['type'] is num && (item['type']! as num).toInt() != 1)) {
      return null;
    }
    return LiveRoom(
      platform: SiteIds.douyu,
      roomId: roomId,
      title: item['rn']?.toString() ?? '',
      nick: item['nn']?.toString() ?? '',
      avatar: _image(item['av']),
      cover: _cover(item['rs16']),
      areaName: item['c2name']?.toString(),
      watching: SiteCounts.integer(item['ol']),
      status: LiveStatus.live,
    );
  }

  /// The cover URL: the directory's `rs16` is already a full CDN URL, while
  /// the older endpoints hand over a bare upload path.
  static String? _cover(Object? value) => SiteImages.url(value, cdnBase: _cdn, suffix: '_middle.jpg');

  /// `m.douyu.com/api/cate/list` → the site's categories, flattened.
  ///
  /// The answer carries two flat lists — `cate1Info` (the boards) and
  /// `cate2Info` (every area of every board, each naming its board by
  /// `cate1Id`) — so the tree is rebuilt by matching those ids. The boards
  /// are sorted numerically, which is the order the site's own side bar
  /// shows rather than the order the lists happen to arrive in.
  static List<LiveArea> categories(Map<String, Object?> root) {
    final data = SiteJson.object(root['data']);
    final groups = SiteJson.objects(data['cate1Info']);
    final areas = SiteJson.objects(data['cate2Info']);
    if (groups.isEmpty && areas.isEmpty) {
      throw const SiteApiChangedError('douyu cate/list: no cate1Info or cate2Info');
    }
    final result = <LiveArea>[
      for (final group in groups)
        if (SiteText.trimmed(group['cate1Id']) case final boardId when boardId.isNotEmpty)
          LiveArea(
            id: boardId,
            name: SiteText.title(SiteText.text(group['cate1Name'])),
            sort: SiteCounts.integer(group['cate1Id']) ?? 0,
          ),
      for (final area in areas)
        if (SiteText.trimmed(area['cate2Id']) case final id when id.isNotEmpty)
          LiveArea(
            id: id,
            name: SiteText.title(SiteText.text(area['cate2Name'])),
            parentId: SiteText.trimmed(area['cate1Id']),
          ),
    ];
    return result;
  }

  /// The avatar/cover CDN base, used through [SiteImages].
  static const String _cdn = 'https://apic.douyucdn.cn/upload';

  /// A bare upload path becomes the `_middle.jpg` derivative; a full URL
  /// passes through.
  static String? _image(Object? value) => SiteImages.url(value, cdnBase: _cdn, suffix: '_middle.jpg');
}
