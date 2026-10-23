import 'package:live_sites/src/common/normalization/site_urls.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/platforms/missevan/api/missevan_endpoints.dart';
import 'package:live_sites/src/platforms/missevan/danmaku/missevan_danmaku_codec.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_failure.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The pull URLs of a live room, upgraded to https. A list card, a search
/// hit and an offline room have none: an offline room's detail still lists
/// the addresses of a broadcast long gone, and they are ignored.
final class MissevanRoomData {
  /// Creates the data.
  const MissevanRoomData({this.hls = '', this.flv = ''});

  /// `channel.hls_pull_url`: an HLS media playlist; '' when the answer had
  /// none or the address was not a pull URL of its kind.
  final String hls;

  /// `channel.flv_pull_url`: HTTP-FLV, as [hls].
  final String flv;

  /// Whether neither transport is there.
  bool get isEmpty => hls.isEmpty && flv.isEmpty;
}

/// What one room entry (`live/{id}`) read: the room with the creator's
/// avatar and introduction and the follower count, the pull URLs (live
/// rooms only), and the chat arguments (live or not).
final class MissevanDetail {
  /// Creates the detail.
  const MissevanDetail({required this.room, required this.data, required this.args});

  /// The room as the detail says it.
  final LiveRoom room;

  /// The pull URLs; empty when the room is offline or no address of its own
  /// kind was usable.
  final MissevanRoomData data;

  /// The chat arguments, live or not.
  final MissevanDanmakuArgs args;
}

/// Pure parsing of Missevan (猫耳 FM) responses: the `meta/data` tabs, the
/// `chatroom` lists, the `live/{id}` detail, and the v2 rooms, qualities and
/// lines.
///
/// Every API answer is `{code, info}` and is checked strictly
/// ([MissevanJson.info]): a page whose echo, size or rows do not match is
/// api-changed, never a short page, and an unknown error code is never taken
/// for "offline". One broken row of a list only drops that row; a page none
/// of whose rows can be read is api-changed.
///
/// An audio platform: a broadcast carries AAC with a 16×16 H.264 placeholder
/// picture. Nothing here calls a room audio-only; the player goes by the
/// tracks it finds.
abstract final class MissevanRoomParser {
  /// `meta/data`: the tabs as areas, their namespace the parent group, in
  /// the order the site first lists a tab of it; areas keep the site's order
  /// within their group.
  ///
  /// A tab of another namespace is skipped (3.x failed the whole catalog on
  /// the `list` tab the site added), and so is a tab without a positive id
  /// or a name, or one that repeats an earlier tab of its namespace. No
  /// usable tab at all, or none at all, is api-changed.
  static List<LiveArea> areas(String body, {int status = 200}) {
    const what = 'meta/data';
    final data = MissevanJson.info(body, what: what, status: status);
    final tabs = data['tabs'];
    if (tabs is! List || tabs.isEmpty || tabs.length > 100) {
      throw const MissevanFailure(MissevanFailureKind.apiChanged, '$what: no tabs');
    }
    final seen = <String, Set<String>>{};
    final areas = <LiveArea>[];
    for (final raw in tabs) {
      if (raw is! Map<String, dynamic>) continue;
      final namespace = MissevanJson.text(raw['type']);
      final idField = MissevanEndpoints.namespaceTabId[namespace];
      final id = idField == null ? null : MissevanJson.integer(raw[idField]);
      final name = MissevanJson.text(raw['name']);
      if (id == null || id <= 0 || name.isEmpty) continue;
      if (!seen.putIfAbsent(namespace, () => <String>{}).add('$id')) continue;
      areas.add(
        LiveArea.normalized(
          platform: _site,
          areaId: MissevanEndpoints.areaId(namespace, id),
          areaName: name,
          parentAreaId: namespace,
          parentAreaName: MissevanEndpoints.namespaceNames[namespace],
          iconUrl: normalizeImageUrl(raw['icon_url']),
        ),
      );
    }
    if (areas.isEmpty) {
      throw const MissevanFailure(MissevanFailureKind.apiChanged, '$what: no usable tab');
    }
    return areas;
  }

  /// The list parameter of a composite area id ([MissevanEndpoints
  /// .splitAreaId]): `catalog_id`, `tag_id` or `type`. Anything else is a
  /// caller error.
  static Map<String, String> areaQuery(String areaId) {
    final (namespace, id) =
        MissevanEndpoints.splitAreaId(areaId) ??
        (throw MissevanFailure(MissevanFailureKind.invalidArgument, 'area "$areaId" is not a Missevan tab'));
    return {MissevanEndpoints.namespaceQuery[namespace]!: id};
  }

  /// A `chatroom/open/list` page (the recommendations, or one area's): its
  /// live rooms, each once, and whether page `maxpage` is still ahead.
  ///
  /// Every row is kept, including those past `pagesize` (promoted rooms), and
  /// pages go by number; a page whose rooms were all offline still has a next
  /// page. The page must echo [page], `pagesize`
  /// [MissevanEndpoints.serverPageSize] and a `maxpage` and `count`; a page
  /// past `maxpage` must be empty. A row that cannot be read is skipped, but
  /// a page none of whose rows can be read is api-changed, never an empty
  /// page.
  static ({List<LiveRoom> rooms, bool hasMore}) directoryPage(String body, {required int page, int status = 200}) {
    final listed = _page(
      body,
      what: 'open/list',
      page: page,
      pageSize: MissevanEndpoints.serverPageSize,
      status: status,
    );
    return (
      rooms: [
        for (final room in listed.rooms)
          if (room.broadcast.isLiveNow) room,
      ],
      hasMore: listed.hasMore,
    );
  }

  /// A `chatroom/search` page: rooms live and offline, each once, and
  /// whether page `maxpage` is still ahead. The page must echo [page] and
  /// [pageSize]. Search rows carry no start time.
  static ({List<LiveRoom> rooms, bool hasMore}) searchPage(
    String body, {
    required int page,
    required int pageSize,
    int status = 200,
  }) => _page(body, what: 'chatroom/search', page: page, pageSize: pageSize, status: status);

  /// The rooms of one list page: the envelope and the pagination echo
  /// checked, broken rows skipped, repeats dropped, and whether `maxpage`
  /// still has a page ahead.
  static ({List<LiveRoom> rooms, bool hasMore}) _page(
    String body, {
    required String what,
    required int page,
    required int pageSize,
    required int status,
  }) {
    final data = MissevanJson.info(body, what: what, status: status);
    final pagination = MissevanJson.object(data['pagination'], '$what.pagination');
    final maxPage = MissevanJson.integer(pagination['maxpage']);
    final count = MissevanJson.integer(pagination['count']);
    final rows = data[what == 'open/list' ? 'Datas' : 'data'];
    if (MissevanJson.integer(pagination['p']) != page ||
        MissevanJson.integer(pagination['pagesize']) != pageSize ||
        maxPage == null ||
        maxPage < 0 ||
        count == null ||
        count < 0 ||
        rows is! List ||
        rows.length > 100 ||
        (page > maxPage && rows.isNotEmpty)) {
      throw MissevanFailure(MissevanFailureKind.apiChanged, '$what page $page: unexpected pagination $pagination');
    }
    final rooms = <String, LiveRoom>{};
    for (final raw in rows) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        final room = _room(raw);
        rooms.putIfAbsent(room.roomId, () => room);
      } on MissevanFailure {
        continue;
      }
    }
    if (rooms.isEmpty && rows.isNotEmpty) {
      throw MissevanFailure(MissevanFailureKind.apiChanged, '$what page $page: no readable row');
    }
    return (rooms: rooms.values.toList(), hasMore: page < maxPage);
  }

  /// [keyword] as `chatroom/search` is asked for it: trimmed and, when
  /// longer, cut to its first [MissevanEndpoints.maxKeywordLength] characters
  /// (Unicode code points, so an emoji is never split) and trimmed again.
  /// Null for a blank keyword or one with control characters.
  static String? searchKeyword(String keyword) {
    final control = RegExp(r'[\x00-\x1f\x7f]');
    final text = keyword.trim();
    if (text.isEmpty || control.hasMatch(text)) return null;
    final runes = text.runes;
    return runes.length <= MissevanEndpoints.maxKeywordLength
        ? text
        : String.fromCharCodes(runes.take(MissevanEndpoints.maxKeywordLength)).trimRight();
  }

  /// `live/{id}`: the room [roomId] as the detail answers it.
  ///
  /// The row as in the lists (with its start time); the creator's avatar and
  /// introduction, the follower count (`statistics.attention_count`) and,
  /// for a live room when [media] is set, the pull URLs and no restriction.
  /// A pull URL that is not a `*.bilivideo.com` address of its kind is left
  /// out, so only that line is missing; a live room with neither URL is
  /// api-changed. An offline room lists the URLs of an old broadcast; they
  /// are ignored. There is no area name here.
  ///
  /// The chat arguments come along, live or not.
  ///
  /// A room or creator other than the one asked for is api-changed.
  static MissevanDetail detail(String body, {required String roomId, bool media = true, int status = 200}) {
    final what = 'live/$roomId';
    final info = MissevanJson.info(body, what: what, status: status);
    final row = MissevanJson.object(info['room'], '$what.room');
    var room = _room(row);
    if (room.roomId != roomId) {
      throw MissevanFailure(MissevanFailureKind.apiChanged, '$what answered room ${room.roomId}');
    }
    final rawCreator = info['creator'];
    if (rawCreator != null) {
      final creator = MissevanJson.object(rawCreator, '$what.creator');
      if (MissevanJson.id(creator['user_id'], '$what.creator.user_id') != room.anchor?.anchorId) {
        throw MissevanFailure(MissevanFailureKind.apiChanged, '$what: the creator does not own the room');
      }
      final introduction = MissevanJson.text(creator['introduction']);
      room = room.rebuild(
        (b) => b
          ..content.replace(room.content.rebuild((b) => b..introduction = introduction.isEmpty ? null : introduction))
          ..anchor = room.anchor?.rebuild((b) => b..avatarUrl = normalizeImageUrl(creator['iconurl'])).toBuilder(),
      );
    }
    final statistics = MissevanJson.object(row['statistics'], '$what.room.statistics');
    final followers = MissevanJson.integer(statistics['attention_count']);
    if (followers != null && followers >= 0) {
      room = room.rebuild((b) => b..anchor = room.anchor?.rebuild((b) => b..followerCount = followers).toBuilder());
    }
    final args = danmakuArgs(info, roomId: room.roomId);
    if (!room.broadcast.isLiveNow || !media) {
      return MissevanDetail(room: room, data: const MissevanRoomData(), args: args);
    }
    final channel = MissevanJson.object(row['channel'], '$what.room.channel');
    String? pull(String key, {required bool isHls}) {
      final raw = channel[key];
      if (raw is! String || raw.trim().isEmpty) return null;
      return mediaUrl(raw.trim(), isHls: isHls);
    }

    final hls = pull('hls_pull_url', isHls: true) ?? '';
    final flv = pull('flv_pull_url', isHls: false) ?? '';
    if (hls.isEmpty && flv.isEmpty) {
      throw MissevanFailure(MissevanFailureKind.apiChanged, '$what: live without a usable pull URL');
    }
    return MissevanDetail(
      room: room.rebuild(
        (b) => b..broadcast.replace(room.broadcast.rebuild((b) => b..restriction = LiveRestriction.none)),
      ),
      data: MissevanRoomData(hls: hls, flv: flv),
      args: args,
    );
  }

  /// The chat arguments of a `live/{id}` answer's `info`: the first
  /// `websocket` entry that is a `wss` URL on `missevan.com` or a subdomain,
  /// without user info, for this room when it names one; else
  /// `wss://im.missevan.com/ws?room_id={roomId}`, the form the site uses.
  /// The session cookie goes to that host, hence the check.
  static MissevanDanmakuArgs danmakuArgs(Map<String, dynamic> info, {required String roomId}) {
    final sockets = info['websocket'];
    for (final raw in sockets is List ? sockets : const <Object?>[]) {
      final uri = raw is String ? Uri.tryParse(raw.trim()) : null;
      if (uri == null ||
          uri.scheme != 'wss' ||
          uri.userInfo.isNotEmpty ||
          (uri.host != 'missevan.com' && !uri.host.endsWith('.missevan.com'))) {
        continue;
      }
      final List<String> named;
      try {
        named = uri.queryParametersAll['room_id'] ?? const [];
      } on FormatException {
        continue;
      }
      if (named.length != 1 || named.single == roomId) {
        return MissevanDanmakuArgs(roomId: roomId, url: uri);
      }
    }
    return MissevanDanmakuArgs(
      roomId: roomId,
      url: Uri(scheme: 'wss', host: 'im.missevan.com', path: '/ws', queryParameters: {'room_id': roomId}),
    );
  }

  /// A room row of the lists, the search and the detail: `status.open` 1 is
  /// live, 0 offline, anything else api-changed; `statistics.score` is the
  /// heat the site shows (not viewers: `online` is always 0). The
  /// introduction is the creator's, the notice the room's announcement, the
  /// area the catalog name. A live row's start is `status.open_time` (epoch
  /// milliseconds; the lists and the detail have it, the search does not);
  /// an offline row's is the last broadcast's, so none. The site's default
  /// picture as the cover is left empty.
  static LiveRoom _room(Map<String, dynamic> row) {
    final id = MissevanJson.id(row['room_id'], 'room_id');
    final state = MissevanJson.object(row['status'], 'room $id status');
    final open = MissevanJson.integer(state['open']);
    if (open != 0 && open != 1) {
      throw MissevanFailure(MissevanFailureKind.apiChanged, 'room $id: status.open ${state['open']}');
    }
    final statistics = MissevanJson.object(row['statistics'], 'room $id statistics');
    final score = MissevanJson.integer(statistics['score']);
    if (score != null && score < 0) {
      throw MissevanFailure(MissevanFailureKind.apiChanged, 'room $id: score $score');
    }
    final cover = normalizeImageUrl(row['cover_url']);
    final live = open == 1;
    final liveStatus = live ? LiveStatus.live : LiveStatus.offline;
    return LiveRoom.normalized(
      platform: _site,
      roomId: id,
      content: RoomContent.of(
        title: MissevanJson.text(row['name']),
        coverUrl: _isPlaceholderCover(cover) ? '' : cover,
        introduction: MissevanJson.text(row['creator_introduction']),
        notice: MissevanJson.text(row['announcement']),
      ),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: MissevanJson.id(row['creator_id'], 'room $id creator_id'),
        name: MissevanJson.text(row['creator_username']),
        avatarUrl: normalizeImageUrl(row['creator_iconurl']),
        liveStatus: liveStatus,
      ),
      area: LiveArea.normalized(platform: _site, areaName: MissevanJson.text(row['catalog_name'])),
      audience: RoomAudience.of(popularity: score, primaryMetric: LiveAudienceMetricType.popularity),
      broadcast: RoomBroadcast.of(
        liveStatus: liveStatus,
        startedAt: live ? MissevanJson.startedAt(state['open_time']) : null,
      ),
      links: RoomLinks.of(webUrl: MissevanEndpoints.roomUrl(id)),
    );
  }

  /// Whether [url] is the site's default picture, whose place it must never
  /// take.
  static bool _isPlaceholderCover(String url) {
    final uri = Uri.tryParse(url);
    final placeholder = Uri.parse(MissevanEndpoints.placeholderCover);
    return uri != null && uri.host == placeholder.host && uri.path == placeholder.path;
  }

  // Streams -------------------------------------------------------------------

  /// The qualities of a room entry: the one quality 原画
  /// ([MissevanEndpoints.qualityId]), whose lines are the pull URLs, FLV
  /// first and HLS as its backup (the FLV connection outlives its signature,
  /// the HLS playlist does not). A room that is not live, or live without a
  /// pull URL, says why.
  static List<LivePlayQuality> qualities(MissevanDetail detail) {
    if (!detail.room.broadcast.isLiveNow) {
      throw MissevanFailure(MissevanFailureKind.streamUnavailable, '${detail.room.roomId} is not live');
    }
    if (detail.data.isEmpty) {
      throw MissevanFailure(MissevanFailureKind.streamUnavailable, '${detail.room.roomId} has no pull URL');
    }
    return [const LivePlayQuality(label: MissevanEndpoints.qualityName, qualityId: MissevanEndpoints.qualityId)];
  }

  /// The lines of [qualityId] (a stored `hls` or `flv` names the one
  /// quality) among a room entry's [qualities]: FLV then HLS, each with the
  /// media headers, its transport as line label and the lease of its
  /// `expires`. A quality the room does not offer says so.
  static List<LivePlayLine> lines(MissevanDetail detail, String? qualityId) {
    final wanted = MissevanEndpoints.qualityIdFromLegacy(qualityId ?? MissevanEndpoints.qualityId);
    if (wanted != MissevanEndpoints.qualityId) {
      throw MissevanFailure(MissevanFailureKind.streamUnavailable, 'quality $qualityId is not offered');
    }
    qualities(detail);
    final urls = [detail.data.flv, detail.data.hls].where((url) => url.isNotEmpty).toList();
    return [
      for (final url in urls)
        () {
          final isHls = formatOf(url) == LiveStreamFormat.hls;
          return LivePlayLine(
            url: url,
            format: isHls ? LiveStreamFormat.hls : LiveStreamFormat.flv,
            formatSource: LivePlayFormatSource.inferred,
            lineLabel: isHls ? 'hls' : 'flv',
            headers: MissevanEndpoints.headers,
            lease: lease(url),
          );
        }(),
    ];
  }

  /// [value] as an https pull URL: http(s) on a `*.bilivideo.com` host, the
  /// default port, no user info or fragment, a `.m3u8` or `.flv` path, at
  /// most one ten-digit `expires`. The signed query is kept as written.
  /// Null for anything else (only that line is then missing).
  static String? mediaUrl(String value, {required bool isHls}) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
        !uri.host.endsWith('.bilivideo.com') ||
        !uri.path.endsWith(isHls ? '.m3u8' : '.flv')) {
      return null;
    }
    try {
      final expires = uri.queryParametersAll['expires'];
      if (expires != null && (expires.length != 1 || !RegExp(r'^[0-9]{10}$').hasMatch(expires.single))) {
        return null;
      }
    } on FormatException {
      return null;
    }
    return uri.replace(scheme: 'https', port: 443).toString();
  }

  /// The container of a pull URL by its path: `.m3u8` HLS, else FLV.
  static LiveStreamFormat formatOf(String url) =>
      (Uri.tryParse(url)?.path ?? '').endsWith('.m3u8') ? LiveStreamFormat.hls : LiveStreamFormat.flv;

  /// The lease of a pull URL: it stops at `expires` (Unix seconds, about two
  /// hours after issue) and is renewed [MissevanEndpoints.leaseLead] before.
  /// An HLS playlist is fetched again and again, so its expiry ends playback;
  /// an established FLV connection keeps flowing. Null for a URL that is not
  /// a pull URL or has no `expires`.
  static LivePlayLease? lease(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || !uri.host.endsWith('.bilivideo.com')) {
      return null;
    }
    final expires = int.tryParse(uri.queryParameters['expires'] ?? '');
    if (expires == null || expires <= 0) return null;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expires * 1000, isUtc: true);
    return LivePlayLease(
      refreshAt: expiresAt.subtract(MissevanEndpoints.leaseLead),
      expiresAt: expiresAt,
      requiresReconnect: formatOf(url) == LiveStreamFormat.hls,
    );
  }
}

const String _site = 'missevan';
