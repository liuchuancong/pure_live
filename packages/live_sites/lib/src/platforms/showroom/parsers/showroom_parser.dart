import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/platforms/showroom/api/showroom_endpoints.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_failure.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_json.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_models.dart';
import 'package:live_sites/src/platforms/showroom/showroom_manifest.dart';

/// Pure parsing of SHOWROOM responses (the reference's `ShowroomApi`, its
/// models and its link reader).
///
/// Answers are checked strictly: an unknown status, a body that is not a JSON
/// object, an answer about another room and a live state the platform does
/// not name are api-changed (or the status's own kind). An irregular row of a
/// list drops only itself; a snapshot or a stream answer none of whose rows
/// can be read is api-changed, so a changed API never looks like an empty
/// directory or a room without a stream.
abstract final class ShowroomParser {
  // Snapshot ------------------------------------------------------------------

  /// `live/onlives`: every genre (a repeated `genre_id` is skipped) with its
  /// live rooms. A genre with nobody live holds a message cell (`cell_type`
  /// 7, no `room_id`), which is skipped.
  ///
  /// An irregular row (no name, a bad room id or key, a bad count) drops only
  /// itself, and a genre without a valid id, name or row list only itself. A
  /// snapshot with live rows none of which can be read, or without a genre,
  /// is api-changed. The rows' own `streaming_url_list` is not read: a room's
  /// streams come from `live/streaming_url`.
  static ShowroomSnapshot snapshot(String body, {int status = 200}) {
    const what = 'onlives';
    final root = ShowroomJson.checked(body, status: status, what: what);
    final genres = <ShowroomGenre>[];
    final seen = <int>{};
    var rows = 0;
    var read = 0;
    for (final raw in ShowroomJson.list(root['onlives'], what, max: 128)) {
      final int id;
      final String name;
      final List<Object?> cells;
      try {
        final object = ShowroomJson.object(raw, '$what genre');
        id = ShowroomJson.count(object['genre_id'], 'genre_id');
        name = ShowroomJson.text(object['genre_name'], 'genre_name');
        cells = ShowroomJson.list(object['lives'], 'lives', max: 5000);
      } on ShowroomFailure {
        continue;
      }
      if (!seen.add(id)) continue;
      final lives = <ShowroomLive>[];
      for (final cell in cells) {
        if (cell is Map && cell['room_id'] == null && cell['cell_type'] != null) continue;
        rows++;
        try {
          lives.add(_live(ShowroomJson.object(cell, 'live of genre $id')));
          read++;
        } on ShowroomFailure {
          continue;
        }
      }
      genres.add(ShowroomGenre(id: id, name: name, lives: lives));
    }
    if (genres.isEmpty) {
      throw const ShowroomFailure(ShowroomFailureKind.apiChanged, '$what: no genre');
    }
    if (rows > 0 && read == 0) {
      throw ShowroomFailure(ShowroomFailureKind.apiChanged, '$what: none of the $rows live rows can be read');
    }
    return ShowroomSnapshot(genres);
  }

  static ShowroomLive _live(Map<String, dynamic> row) {
    final roomId = ShowroomJson.positive(row['room_id'], 'room_id');
    return ShowroomLive(
      roomId: roomId,
      roomUrlKey: ShowroomJson.key(row['room_url_key'], 'room_url_key of $roomId'),
      name: ShowroomJson.text(row['main_name'], 'main_name of $roomId'),
      cover: ShowroomJson.image(row['image_square'] ?? row['image']),
      genreId: ShowroomJson.count(row['genre_id'], 'genre_id of $roomId'),
      genreName: ShowroomJson.optionalText(row['genre_name'], 'genre_name of $roomId'),
      followers: ShowroomJson.optionalCount(row['follower_num'], 'follower_num of $roomId'),
      views: ShowroomJson.optionalCount(row['view_num'], 'view_num of $roomId'),
      telop: ShowroomJson.optionalText(row['telop'], 'telop of $roomId'),
      startedAt: startTime(row['started_at']),
      restriction: restrictionOf(row['premium_room_type']),
    );
  }

  /// A time in Unix seconds (`started_at`, `current_live_started_at`) as
  /// UTC; null for 0, anything before 2000 or after 2100, and anything that
  /// is not an integer.
  static DateTime? startTime(Object? value) {
    final seconds = ShowroomJson.integer(value);
    if (seconds == null || seconds < 946684800 || seconds > 4102444800) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  /// The restriction of a live room from its `premium_room_type` (in the
  /// snapshot rows and `live/live_info`): 0, an ordinary broadcast anyone
  /// can watch, is no restriction; anything else is null (not known).
  static LiveRestriction? restrictionOf(Object? premiumRoomType) =>
      ShowroomJson.integer(premiumRoomType) == 0 ? LiveRestriction.none : null;

  /// The site's areas: the snapshot's genres, in its order, empty ones
  /// included, under the one category SHOWROOM.
  static List<LiveArea> areas(ShowroomSnapshot snapshot) => [
    for (final genre in snapshot.genres)
      LiveArea.normalized(
        platform: showroomSiteId,
        areaId: '${genre.id}',
        areaName: genre.name,
        parentAreaId: 'showroom',
        parentAreaName: ShowroomEndpoints.categoryName,
      ),
  ];

  /// A live room card: the telop as title when there is one, else the name;
  /// `view_num` as total viewers; the cover as avatar too; the start time
  /// and the restriction of the row.
  static LiveRoom card(ShowroomLive live) => _room(
    roomId: '${live.roomId}',
    roomUrlKey: live.roomUrlKey,
    name: live.name,
    title: live.telop.isEmpty ? live.name : live.telop,
    cover: live.cover,
    genreId: live.genreId,
    genreName: live.genreName,
    followers: live.followers,
    views: live.views,
    introduction: null,
    live: true,
    startedAt: live.startedAt,
    restriction: live.restriction,
  );

  /// The room of [profile] and [info]: the name as title and streamer, the
  /// square picture as cover and avatar, the description. A live room has
  /// `view_num` as total viewers, the start time and the restriction; an
  /// offline one has no audience, start time or restriction.
  static LiveRoom room(ShowroomProfile profile, ShowroomLiveInfo info) => _room(
    roomId: '${profile.roomId}',
    roomUrlKey: profile.roomUrlKey,
    name: profile.name,
    title: profile.name,
    cover: profile.cover,
    genreId: profile.genreId,
    genreName: profile.genreName,
    followers: profile.followers,
    views: profile.views,
    introduction: profile.description.isEmpty ? null : profile.description,
    live: info.live,
    startedAt: info.live ? profile.liveStartedAt : null,
    restriction: info.live ? info.restriction : null,
  );

  static LiveRoom _room({
    required String roomId,
    required String roomUrlKey,
    required String name,
    required String title,
    required String cover,
    required int genreId,
    required String genreName,
    required int? followers,
    required int? views,
    required String? introduction,
    required bool live,
    required DateTime? startedAt,
    required LiveRestriction? restriction,
  }) => LiveRoom.normalized(
    platform: showroomSiteId,
    roomId: roomId,
    content: RoomContent.of(title: title, coverUrl: cover, introduction: introduction),
    anchor: LiveAnchor.normalized(
      platform: showroomSiteId,
      anchorId: roomId,
      name: name,
      avatarUrl: cover.isEmpty ? null : cover,
      followerCount: followers,
    ),
    audience: RoomAudience.of(
      totalViewers: live ? views : null,
      primaryMetric: live && views != null ? LiveAudienceMetricType.totalViewers : LiveAudienceMetricType.unknown,
    ),
    broadcast: RoomBroadcast.of(
      liveStatus: live ? LiveStatus.live : LiveStatus.offline,
      startedAt: startedAt,
      restriction: restriction,
    ),
    links: RoomLinks.of(webUrl: ShowroomEndpoints.roomKeyUrl(roomUrlKey)),
    area: genreName.isEmpty
        ? null
        : LiveArea.normalized(
            platform: showroomSiteId,
            areaId: '$genreId',
            areaName: genreName,
            parentAreaId: 'showroom',
            parentAreaName: ShowroomEndpoints.categoryName,
          ),
  );

  // Local pages and search ----------------------------------------------------

  /// Page [page] (from 1) of [lives], [size] a page (the reference's
  /// directory page): nothing for a page past the end.
  static ({List<LiveRoom> rooms, bool hasMore}) directoryPage(
    List<ShowroomLive> lives, {
    required int page,
    int size = ShowroomEndpoints.directoryPageSize,
  }) {
    final sliced = slice(lives, page: page, pageSize: size);
    return (
      rooms: [for (final live in sliced) card(live)],
      hasMore: validSlice(page: page, pageSize: size) && page * size < lives.length,
    );
  }

  /// Page [page] of [pageSize] of [values] (the reference's `_page`): nothing
  /// for a page or size below 1, a size over [ShowroomEndpoints.maxPageSize]
  /// or a page past the end.
  static List<T> slice<T>(List<T> values, {required int page, required int pageSize}) {
    if (!validSlice(page: page, pageSize: pageSize)) return const [];
    final start = (page - 1) * pageSize;
    if (start >= values.length) return const [];
    return values.sublist(start, (start + pageSize).clamp(start, values.length));
  }

  /// Whether the reference served anything for [page] of [pageSize].
  static bool validSlice({required int page, required int pageSize}) =>
      page >= 1 && pageSize >= 1 && pageSize <= ShowroomEndpoints.maxPageSize;

  /// The lives matching [keyword] (the reference's search, over every live
  /// once): the room id or key equal to it (case ignored), or the name, telop
  /// or live genre name containing it (case ignored).
  static List<ShowroomLive> search(ShowroomSnapshot snapshot, String keyword) {
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return [
      for (final live in snapshot.uniqueLives)
        if ('${live.roomId}' == query ||
            live.roomUrlKey.toLowerCase() == query ||
            live.name.toLowerCase().contains(query) ||
            live.telop.toLowerCase().contains(query) ||
            live.genreName.toLowerCase().contains(query))
          live,
    ];
  }

  // Rooms ---------------------------------------------------------------------

  /// The room number [reference] names by itself (an integer above 0), or
  /// null when it is a room key or nothing.
  static int? roomNumber(String reference) {
    final number = int.tryParse(reference.trim());
    return number != null && number > 0 ? number : null;
  }

  /// `room/status?room_url_key=`: the room id of a key. An unknown key is
  /// HTTP 404 (not-found).
  static int roomIdOfStatus(String body, {int status = 200}) => ShowroomJson.positive(
    ShowroomJson.checked(body, status: status, what: 'room/status')['room_id'],
    'room/status room_id',
  );

  /// `room/profile` of [roomId] (the answer must be for that room, with a
  /// valid key and name, a `genre_id` and a boolean `is_onlive`), with
  /// `current_live_started_at` (see [startTime]). An unknown room is HTTP 404
  /// (not-found).
  static ShowroomProfile profile(String body, {required int roomId, int status = 200}) {
    const what = 'room/profile';
    final data = ShowroomJson.checked(body, status: status, what: what);
    final actual = ShowroomJson.positive(data['room_id'], '$what room_id');
    if (actual != roomId) {
      throw ShowroomFailure(ShowroomFailureKind.apiChanged, '$what: answer for room $actual, asked $roomId');
    }
    final room = (
      roomId: actual,
      roomUrlKey: ShowroomJson.key(data['room_url_key'], '$what room_url_key'),
      name: ShowroomJson.text(data['main_name'] ?? data['room_name'], '$what main_name'),
      cover: ShowroomJson.image(data['image_square']),
      genreId: ShowroomJson.count(data['genre_id'], '$what genre_id'),
      genreName: ShowroomJson.optionalText(data['genre_name'], '$what genre_name'),
      followers: ShowroomJson.optionalCount(data['follower_num'], '$what follower_num'),
      views: ShowroomJson.optionalCount(data['view_num'], '$what view_num'),
      description: ShowroomJson.optionalText(data['description'], '$what description'),
      liveStartedAt: startTime(data['current_live_started_at']),
    );
    if (data['is_onlive'] is! bool) {
      throw ShowroomFailure(ShowroomFailureKind.apiChanged, '$what: is_onlive is ${data['is_onlive']}');
    }
    return room;
  }

  /// `live/live_info` of [roomId]: live when `live_status` is 2; 0 and 1 are
  /// offline; anything else, or an answer for another room, is api-changed. A
  /// live room also gets its restriction ([restrictionOf]) and its comment
  /// arguments ([danmakuArgs]); an offline one has neither.
  static ShowroomLiveInfo liveInfo(String body, {required int roomId, int status = 200}) {
    const what = 'live_info';
    final data = ShowroomJson.checked(body, status: status, what: what);
    final actual = ShowroomJson.positive(data['room_id'], '$what room_id');
    if (actual != roomId) {
      throw ShowroomFailure(ShowroomFailureKind.apiChanged, '$what: answer for room $actual, asked $roomId');
    }
    final state = ShowroomJson.count(data['live_status'], 'live_status');
    if (state > 2) {
      throw ShowroomFailure(ShowroomFailureKind.apiChanged, '$what: live_status $state');
    }
    if (state != 2) return (live: false, restriction: null, danmaku: null);
    return (
      live: true,
      restriction: restrictionOf(data['premium_room_type']),
      danmaku: danmakuArgs(roomId: roomId, host: data['bcsvr_host'], key: data['bcsvr_key']),
    );
  }

  static final RegExp _hostName = RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$');

  /// The comment arguments of live room [roomId], or null unless [host] is a
  /// host name on `showroom-live.com` (no other server is connected) and
  /// [key] is at most 256 characters without white space or control
  /// characters.
  static ShowroomDanmakuArgs? danmakuArgs({required int roomId, required Object? host, required Object? key}) {
    final server = ShowroomJson.optionalString(host)?.toLowerCase();
    final broadcast = ShowroomJson.optionalString(key);
    if (server == null || server.length > 253 || !_hostName.hasMatch(server) || !ShowroomEndpoints.isSiteHost(server)) {
      return null;
    }
    if (broadcast == null || broadcast.length > 256 || broadcast.contains(RegExp(r'[\s\x00-\x1f\x7f]'))) {
      return null;
    }
    return ShowroomDanmakuArgs(roomId: '$roomId', host: server, key: broadcast);
  }

  // Gifts ---------------------------------------------------------------------

  /// The gift table of a `live/gift_list` answer: the gifts of `normal` and
  /// `enquete` by `gift_id`, each with `gift_name`, `point`, `free` and
  /// `image` (an https picture on a SHOWROOM host). Rows without a positive
  /// id are skipped; a refused or unreadable answer throws as every other
  /// answer does.
  static ShowroomGiftCatalog giftList(String body, {int status = 200}) {
    const what = 'gift_list';
    final data = ShowroomJson.checked(body, status: status, what: what);
    final gifts = <String, ShowroomGiftInfo>{};
    for (final list in [data['normal'], data['enquete']]) {
      if (list is! List) continue;
      for (final row in list) {
        if (row is! Map) continue;
        final id = row['gift_id'];
        if (id is! int || id <= 0) continue;
        final name = row['gift_name'];
        final point = row['point'];
        final image = ShowroomJson.image(row['image']);
        gifts['$id'] = ShowroomGiftInfo(
          name: name is String ? name.trim() : '',
          point: point is int && point >= 0 ? point : 0,
          free: row['free'] == true,
          image: image.isEmpty ? null : Uri.parse(image),
        );
      }
    }
    return ShowroomGiftCatalog(gifts);
  }

  // Streams -------------------------------------------------------------------

  /// `live/streaming_url`: the `streaming_url_list` rows (at most 64), not
  /// yet checked. An offline room has none.
  static List<Object?> streamRows(String body, {int status = 200}) {
    final rows = ShowroomJson.list(
      ShowroomJson.checked(body, status: status, what: 'streaming_url')['streaming_url_list'],
      'streaming_url_list',
      max: 64,
    );
    return List.unmodifiable(rows);
  }

  /// The tiers of [rows], best first: each `hls` tier by `quality` (1000
  /// 原画, 200 中画质, lower 低画质), then the adaptive `hls_all` master as
  /// 自动 ([ShowroomEndpoints.autoSort]), so 原画 is the default. The id is
  /// `{type}:{id}:{quality}` (`hls:2:1000`, `hls_all:100:0`). WebRTC and
  /// other types are skipped, a repeated URL too.
  ///
  /// An irregular HLS row (a URL that is not https on a SHOWROOM host, a
  /// missing label, id, `quality` or `is_default`, a row that is not an
  /// object) drops only its own tier. HLS rows none of which can be read are
  /// api-changed; no HLS row at all is stream-unavailable.
  static List<ShowroomTier> tiers(List<Object?> rows) {
    if (rows.length > 64) {
      throw ShowroomFailure(ShowroomFailureKind.apiChanged, 'streaming_url: ${rows.length} rows');
    }
    final tiers = <ShowroomTier>[];
    final seen = <String>{};
    var broken = 0;
    for (final raw in rows) {
      ShowroomTier? tier;
      try {
        tier = _tier(raw);
      } on ShowroomFailure catch (failure) {
        if (failure.kind != ShowroomFailureKind.apiChanged) rethrow;
        broken++;
        continue;
      }
      if (tier != null && seen.add(tier.url)) tiers.add(tier);
    }
    if (tiers.isEmpty) {
      if (broken > 0) {
        throw ShowroomFailure(
          ShowroomFailureKind.apiChanged,
          'streaming_url: none of the $broken HLS rows can be read',
        );
      }
      throw const ShowroomFailure(ShowroomFailureKind.streamUnavailable, 'no HLS stream');
    }
    tiers.sort((left, right) {
      final rank = right.quality.order.compareTo(left.quality.order);
      return rank != 0 ? rank : left.quality.id.compareTo(right.quality.id);
    });
    return List.unmodifiable(tiers);
  }

  /// The URL and quality of one `streaming_url_list` row; null for a type
  /// other than `hls` and `hls_all`; api-changed for an irregular row.
  static ShowroomTier? _tier(Object? raw) {
    final row = ShowroomJson.object(raw, 'streaming_url row');
    final type = ShowroomJson.optionalText(row['type'], 'streaming_url type');
    if (type != 'hls' && type != 'hls_all') return null;
    final url = ShowroomJson.mediaUrl(row['url'], 'streaming_url');
    final id = ShowroomJson.count(row['id'], 'streaming_url id');
    ShowroomJson.text(row['label'], 'streaming_url label');
    final level = ShowroomJson.count(row['quality'], 'streaming_url quality');
    if (row['is_default'] is! bool) {
      throw ShowroomFailure(ShowroomFailureKind.apiChanged, 'streaming_url: is_default is ${row['is_default']}');
    }
    return (
      url: url,
      quality: (
        label: switch ((type, level)) {
          ('hls_all', _) => '自动',
          (_, >= 1000) => '原画',
          (_, >= 200) => '中画质',
          _ => '低画质',
        },
        id: '$type:$id:$level',
        order: type == 'hls_all' ? ShowroomEndpoints.autoSort : level,
        type: type,
      ),
    );
  }

  /// The quality of [tier]: its label, its id `{type}:{id}:{quality}` and
  /// the platform's own order (the adaptive master 自动 is below every `hls`
  /// tier).
  static LivePlayQuality quality(ShowroomTier tier) =>
      LivePlayQuality(label: tier.quality.label, qualityId: tier.quality.id, platformOrder: tier.quality.order);

  /// The qualities of [rows], best first (see [tiers]).
  static List<LivePlayQuality> qualities(List<Object?> rows) => [for (final tier in tiers(rows)) quality(tier)];

  /// The line of [tier]: its HLS URL with the media headers and the tier's
  /// type as the line label. The URLs are not signed and do not expire, so
  /// there is no lease.
  static LivePlayLine line(ShowroomTier tier) => LivePlayLine(
    url: tier.url,
    format: LiveStreamFormat.hls,
    formatSource: LivePlayFormatSource.declared,
    lineLabel: tier.quality.type,
    headers: ShowroomEndpoints.mediaHeaders,
  );

  // Links ---------------------------------------------------------------------

  /// What a SHOWROOM link names: the room id of `room/profile?room_id={id}`,
  /// or the key of `/r/{key}` and `/{key}`, on `showroom-live.com` or a
  /// subdomain over http(s) without user info. Site pages
  /// ([ShowroomEndpoints.reservedPaths]) and anything else are null.
  static ({String? roomId, String? key})? link(Uri? uri) {
    if (uri == null ||
        (!uri.isScheme('http') && !uri.isScheme('https')) ||
        uri.userInfo.isNotEmpty ||
        !ShowroomEndpoints.isSiteHost(uri.host.toLowerCase())) {
      return null;
    }
    final List<String> segments;
    try {
      segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
      if (segments.length == 2 && segments[0] == 'room' && segments[1] == 'profile') {
        final id = uri.queryParameters['room_id']?.trim() ?? '';
        return ShowroomEndpoints.linkRoomIdPattern.hasMatch(id) ? (roomId: id, key: null) : null;
      }
    } on FormatException {
      return null;
    }
    final key = switch (segments) {
      ['r', final key] || [final key] => key.trim(),
      _ => null,
    };
    if (key == null ||
        ShowroomEndpoints.reservedPaths.contains(key.toLowerCase()) ||
        !ShowroomEndpoints.keyPattern.hasMatch(key)) {
      return null;
    }
    return (roomId: null, key: key);
  }
}
