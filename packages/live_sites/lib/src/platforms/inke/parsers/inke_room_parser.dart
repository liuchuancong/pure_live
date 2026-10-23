import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/inke/api/inke_endpoints.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_failure.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

const _site = 'inke';

/// A live broadcast as the app API answers it (`now_publish`'s `live`,
/// `simpleall`'s `lives[]`). The broadcast id is new every time the anchor
/// goes live; the uid is the room identity.
final class InkeBroadcast {
  /// Creates the broadcast.
  const InkeBroadcast({
    required this.liveId,
    this.pullUrl,
    this.originUrl,
    this.title = '',
    this.cover = '',
    this.startedAt,
    this.online,
    this.heat,
  });

  /// `id`: the broadcast id.
  final String liveId;

  /// `stream_addr` when it is the Wangsu H.264 pull URL of this broadcast
  /// (see [InkeRoomParser.plainFlv]); null otherwise.
  final String? pullUrl;

  /// `stream_multi_addr` when it is the Zego pull URL of this broadcast, the
  /// anchor's original stream (HEVC; see [InkeRoomParser.zegoFlv]); null
  /// otherwise.
  final String? originUrl;

  /// `name`, the broadcast title; empty when missing or the platform's
  /// stand-in [InkeEndpoints.placeholderTitle].
  final String title;

  /// `cover`, the broadcast's cover; empty when missing.
  final String cover;

  /// `start_time`, when the broadcast started.
  final DateTime? startedAt;

  /// `numbers.real`: the "N人在看" the app shows (concurrent viewers).
  final int? online;

  /// `online_users`: a larger display figure, kept as heat.
  final int? heat;

  /// Whether the app gave this client a line: a broadcast with one plays for
  /// anyone ([LiveRestriction.none]); without one the answer says nothing
  /// about a restriction.
  bool get hasLine => pullUrl != null || originUrl != null;
}

/// What a room entry knows besides its uid: the current broadcast
/// (`live_share_pc`'s `liveid`, plus the app's answer when it gave one) and
/// when that answer arrived. It is the playback handle the site keeps for the
/// room: a null [liveId] and a null [broadcast] mean the platform called the
/// room offline.
final class InkeRoomData {
  /// Creates the data.
  const InkeRoomData({required this.liveId, this.broadcast, this.receivedAt});

  /// The broadcast id (1–18 digits), when the website advertised a live one.
  final String? liveId;

  /// The app's answer for this broadcast (`now_publish`), when it gave one:
  /// its signed lines serve the first play (see the site's `answerReuse`).
  final InkeBroadcast? broadcast;

  /// When [broadcast] was received.
  final DateTime? receivedAt;
}

/// One channel of the website's catalog: its `tab_key` (the area id), its
/// name and its rows.
typedef InkeChannel = ({String key, String name, List<Map<String, dynamic>> rows});

/// Pure parsing of Inke (映客) responses (3.x's `InkeApi`): the showcases, the
/// app's hot list, the room detail, the app's broadcast, and the v2 rooms,
/// qualities and lines.
///
/// The website API (`webapi.busi.inke.cn/web/…`, `{error_code, data}`) has no
/// index of live rooms, only finite showcases: the top list (8 rooms), the
/// hot lists and six channels. The app API (`service.inke.cn/api/live`,
/// `{dm_error, …}`) has the hot list `simpleall` (about 20 broadcasts with
/// titles, covers, start times and audiences; the recommendations) and
/// `now_publish`, the current broadcast of any anchor with its signed Wangsu
/// (H.264) and Zego (the original, HEVC) lines.
///
/// A room is an anchor: its id is the anchor's uid, and every broadcast has a
/// new id. Answers are checked strictly; a broken row of a showcase list only
/// drops that row, but a bad envelope, an answer about another anchor or a
/// list that is not a list is api-changed.
abstract final class InkeRoomParser {
  // Envelopes -----------------------------------------------------------------

  /// The `data` of a website answer. The status gate runs first; a body that
  /// is not a JSON object or carries no `error_code` is api-changed, and so
  /// is any code but 0 — except [InkeEndpoints.noLiveCode] with [offline]
  /// (the room endpoint), which gives null.
  static Map<String, dynamic>? webData(String body, {required String what, int status = 200, bool offline = false}) {
    final root = InkeJson.json(body, what, status);
    final code = InkeJson.integer(root['error_code']);
    if (code == null) throw InkeFailure(InkeFailureKind.apiChanged, '$what: no error_code');
    if (offline && code == InkeEndpoints.noLiveCode) return null;
    if (code != 0) throw InkeFailure(InkeFailureKind.apiChanged, '$what: error_code $code');
    return InkeJson.object(root['data'], '$what.data');
  }

  /// An app answer (`{dm_error, …}`), checked like [webData]; a missing or
  /// non-zero `dm_error` is api-changed.
  static Map<String, dynamic> appData(String body, {required String what, int status = 200}) {
    final root = InkeJson.json(body, what, status);
    final code = InkeJson.integer(root['dm_error']);
    if (code == null) throw InkeFailure(InkeFailureKind.apiChanged, '$what: no dm_error');
    if (code != 0) throw InkeFailure(InkeFailureKind.apiChanged, '$what: dm_error $code');
    return root;
  }

  // Catalog -------------------------------------------------------------------

  /// `Live_channel_pc`: the areas as the catalog presents them — the
  /// website's top list ([InkeEndpoints.topAreaId]) and then the channels in
  /// the site's order, all under the one category 映客. A channel without an
  /// alphanumeric `tab_key` (up to 64 characters), with one an earlier
  /// channel has, without a name or without a list of rows is skipped; more
  /// than [InkeEndpoints.maxChannels] channels, or no list of them, is
  /// api-changed.
  static List<LiveArea> areas(String body, {int status = 200}) => [
    _topArea,
    for (final channel in _channels(body, status))
      LiveArea.normalized(
        platform: _site,
        areaId: channel.key,
        areaName: channel.name,
        parentAreaId: InkeEndpoints.categoryId,
        parentAreaName: InkeEndpoints.categoryName,
      ),
  ];

  /// The rooms of channel [tabKey] of `Live_channel_pc`, each once; an
  /// unknown channel is not-found.
  static List<LiveRoom> channelPage(String body, {required String tabKey, int status = 200}) {
    final group = _channels(body, status).where((channel) => channel.key == tabKey).firstOrNull;
    if (group == null) throw InkeFailure(InkeFailureKind.notFound, 'channel $tabKey is not listed');
    return _unique(_cards(group.rows));
  }

  /// Every room of every channel of `Live_channel_pc`, in the site's order
  /// (the keyword search's second part).
  static List<LiveRoom> channelRooms(String body, {int status = 200}) => [
    for (final channel in _channels(body, status)) ..._cards(channel.rows),
  ];

  /// `Live_top_pc`: the top list's slots, each room once.
  static List<LiveRoom> topPage(String body, {int status = 200}) {
    const what = InkeEndpoints.topAreaId;
    final data = webData(body, what: what, status: status)!;
    return _unique(_cards(InkeJson.rows(data['list'], '$what.list')));
  }

  static final LiveArea _topArea = LiveArea.normalized(
    platform: _site,
    areaId: InkeEndpoints.topAreaId,
    areaName: InkeEndpoints.topAreaName,
    parentAreaId: InkeEndpoints.categoryId,
    parentAreaName: InkeEndpoints.categoryName,
  );

  static List<InkeChannel> _channels(String body, int status) {
    const what = 'Live_channel_pc';
    final data = webData(body, what: what, status: status)!;
    final groups = InkeJson.rows(data['list'], '$what.list');
    if (groups.length > InkeEndpoints.maxChannels) {
      throw InkeFailure(InkeFailureKind.apiChanged, '$what: ${groups.length} channels');
    }
    final keys = <String>{};
    final channels = <InkeChannel>[];
    for (final group in groups) {
      final key = InkeJson.text(group['tab_key']);
      final name = InkeJson.text(group['channel_name']);
      final rows = group['list'];
      if (!InkeEndpoints.isChannelKey(key) ||
          name.isEmpty ||
          rows is! List ||
          rows.length > InkeEndpoints.maxRows ||
          !keys.add(key)) {
        continue;
      }
      channels.add((key: key, name: name, rows: InkeJson.rows(rows, 'channel $key')));
    }
    return channels;
  }

  /// The cards of showcase [rows] that are readable (see [_showcaseCard]).
  static Iterable<LiveRoom> _cards(Iterable<Map<String, dynamic>> rows) sync* {
    for (final row in rows) {
      final room = _showcaseCard(row);
      if (room != null) yield room;
    }
  }

  /// A showcase row as a card: live, the nickname as title, the portrait as
  /// avatar and cover, no audience (the showcases have none). A row without
  /// a uid, broadcast id or nickname is skipped (3.x failed the list).
  static LiveRoom? _showcaseCard(Map<String, dynamic> row) {
    final uid = InkeJson.idOrNull(row['uid']);
    final liveId = InkeJson.idOrNull(row['live_id']);
    final nick = InkeJson.text(row['nick']);
    if (uid == null || liveId == null || nick.isEmpty) return null;
    final portrait = InkeJson.picture(row['portrait']);
    return LiveRoom.normalized(
      platform: _site,
      roomId: uid,
      content: RoomContent.of(title: nick, coverUrl: portrait),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: uid,
        name: nick,
        avatarUrl: portrait,
        liveStatus: LiveStatus.live,
      ),
      audience: RoomAudience.of(primaryMetric: LiveAudienceMetricType.unknown),
      broadcast: RoomBroadcast.of(liveStatus: LiveStatus.live),
      links: RoomLinks.of(webUrl: InkeEndpoints.roomUrl(uid, liveId: liveId)),
    );
  }

  /// [rooms] with each uid once (the first wins), in order.
  static List<LiveRoom> _unique(Iterable<LiveRoom> rooms) {
    final seen = <String>{};
    return [
      for (final room in rooms)
        if (seen.add(room.roomId)) room,
    ];
  }

  // App hot list --------------------------------------------------------------

  /// `simpleall`: the app's hot list (about 20 broadcasts, different at each
  /// request), the recommendations, each uid once. Every card is live, with
  /// the app's title, cover, start time and audience ([appRoom]). A row that
  /// is not a live broadcast (`status` 1) with a uid (`creator.id`) and a
  /// broadcast id is skipped.
  static List<LiveRoom> hotPage(String body, {int status = 200}) {
    const what = 'simpleall';
    final root = appData(body, what: what, status: status);
    final rooms = <LiveRoom>[];
    for (final row in InkeJson.rows(root['lives'], '$what.lives')) {
      final creator = row['creator'];
      if (creator is! Map<String, dynamic>) continue;
      final uid = InkeJson.idOrNull(creator['id']);
      final liveId = InkeJson.idOrNull(row['id']);
      if (uid == null || liveId == null || InkeJson.integer(row['status']) != 1) continue;
      rooms.add(
        appRoom(
          uid: uid,
          nick: InkeJson.text(creator['nick']),
          avatar: InkeJson.picture(creator['portrait']),
          broadcast: _broadcast(row, liveId),
        ),
      );
    }
    return _unique(rooms);
  }

  /// The live card of [broadcast] by anchor [uid]: its title (else the
  /// nickname, as 3.x titled untitled broadcasts), its cover (else the
  /// avatar), its start time, the app's "N人在看" as concurrent viewers and
  /// `online_users` as heat, and no restriction when the app gave a line.
  static LiveRoom appRoom({
    required String uid,
    required String nick,
    required String avatar,
    required InkeBroadcast broadcast,
  }) => LiveRoom.normalized(
    platform: _site,
    roomId: uid,
    content: RoomContent.of(
      title: broadcast.title.isEmpty ? nick : broadcast.title,
      coverUrl: broadcast.cover.isEmpty ? avatar : broadcast.cover,
    ),
    anchor: LiveAnchor.normalized(platform: _site, anchorId: uid, name: nick, avatarUrl: avatar),
    audience: _audience(broadcast),
    broadcast: RoomBroadcast.of(
      liveStatus: LiveStatus.live,
      startedAt: broadcast.startedAt,
      restriction: broadcast.hasLine ? LiveRestriction.none : null,
    ),
    links: RoomLinks.of(webUrl: InkeEndpoints.roomUrl(uid, liveId: broadcast.liveId)),
  );

  static RoomAudience _audience(InkeBroadcast broadcast) => RoomAudience.of(
    popularity: broadcast.heat,
    onlineViewers: broadcast.online,
    primaryMetric: broadcast.online != null
        ? LiveAudienceMetricType.onlineViewers
        : broadcast.heat != null
        ? LiveAudienceMetricType.popularity
        : LiveAudienceMetricType.unknown,
  );

  // Search --------------------------------------------------------------------

  /// The rooms of [rooms] (the top list, then the channels) and [hot] (the
  /// app's hot list) whose nickname contains [keyword] (trimmed, case
  /// ignored), each uid once at its first place, page [page] of [pageSize],
  /// and whether a further page holds more. A room the hot list also has is
  /// its hot card: the app's title, cover, audience and start time. There is
  /// no server search.
  static ({List<LiveRoom> rooms, bool hasMore}) searchShowcases(
    String keyword,
    Iterable<LiveRoom> rooms, {
    Iterable<LiveRoom> hot = const [],
    int page = 1,
    int pageSize = 20,
  }) {
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) return (rooms: const <LiveRoom>[], hasMore: false);
    final cards = <String, LiveRoom>{};
    for (final room in hot) {
      cards.putIfAbsent(room.roomId, () => room);
    }
    final matches = _unique(
      [...rooms, ...hot].where((room) => room.anchor?.name.toLowerCase().contains(query) ?? false),
    );
    final start = (page - 1) * pageSize;
    return (
      rooms: matches.skip(start).take(pageSize).map((room) => cards[room.roomId] ?? room).toList(),
      hasMore: start + pageSize < matches.length,
    );
  }

  /// The pull URLs found in showcase [path] (one of
  /// [InkeEndpoints.showcasePaths]) for broadcast [liveId] of [uid]: rows of
  /// that uid and broadcast whose `stream_addr` passes [plainFlv], each once.
  /// Empty when the showcase does not hold the broadcast. A group that is no
  /// list of rows, or a row without a readable uid or broadcast id, is
  /// skipped.
  static List<String> showcaseUrls(
    String body, {
    required String path,
    required String uid,
    required String liveId,
    int status = 200,
  }) {
    final data = webData(body, what: path, status: status)!;
    final groups = switch (path) {
      'Live_hot_pc' => InkeJson.object(data['list'], '$path.list').values.toList(),
      'Live_channel_pc' => [for (final group in InkeJson.rows(data['list'], '$path.list')) group['list']],
      _ => <Object?>[InkeJson.rows(data['list'], '$path.list')],
    };
    if (groups.length > InkeEndpoints.maxChannels) {
      throw InkeFailure(InkeFailureKind.apiChanged, '$path: ${groups.length} groups');
    }
    final urls = <String>{};
    for (final group in groups) {
      if (group is! List || group.length > InkeEndpoints.maxRows) continue;
      for (final row in group.whereType<Map<String, dynamic>>()) {
        if (InkeJson.idOrNull(row['uid']) != uid || InkeJson.idOrNull(row['live_id']) != liveId) continue;
        final url = plainFlv(row['stream_addr'], liveId: liveId);
        if (url != null) urls.add(url);
      }
    }
    return urls.toList();
  }

  // Rooms ---------------------------------------------------------------------

  /// `live_share_pc?uid=`: the room [uid] as the website answers it, under
  /// that uid, carrying its broadcast id as the room's stream handle.
  ///
  /// [InkeEndpoints.noLiveCode] is offline, with nothing but the uid and a
  /// link without a broadcast (the answer has no profile). Otherwise the
  /// answer must be the live broadcast of that very anchor (`live_uid`,
  /// `media_info.inke_id`, `status` 1, a broadcast id and a nickname), or it
  /// is api-changed. The title is `live_name`, else (or when it is
  /// [InkeEndpoints.placeholderTitle]) the nickname; the avatar is the
  /// anchor's portrait and the cover the room's (both the same picture); no
  /// audience. The app's answer is added by [withBroadcast].
  static LiveRoom detail(String body, {required String uid, int status = 200}) {
    const what = 'live_share_pc';
    final info = webData(body, what: what, status: status, offline: true);
    if (info == null) {
      return LiveRoom.normalized(
        platform: _site,
        roomId: uid,
        broadcast: RoomBroadcast.of(liveStatus: LiveStatus.offline),
        links: RoomLinks.of(webUrl: InkeEndpoints.roomUrl(uid)),
      );
    }
    if (InkeJson.idOf(info['live_uid'], '$what.live_uid') != uid || !const {1, '1', true}.contains(info['status'])) {
      throw InkeFailure(InkeFailureKind.apiChanged, '$what: not the live room of $uid');
    }
    final liveId = InkeJson.idOf(info['liveid'], '$what.liveid');
    final owner = InkeJson.object(info['media_info'], '$what.media_info');
    final nick = InkeJson.text(owner['nick']);
    if (InkeJson.idOf(owner['inke_id'], '$what.media_info.inke_id') != uid || nick.isEmpty) {
      throw InkeFailure(InkeFailureKind.apiChanged, '$what: not the anchor $uid');
    }
    final name = _title(info['live_name']);
    return LiveRoom.normalized(
      platform: _site,
      roomId: uid,
      content: RoomContent.of(title: name.isEmpty ? nick : name, coverUrl: InkeJson.picture(info['portrait'])),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: uid,
        name: nick,
        avatarUrl: InkeJson.picture(owner['portrait']),
        liveStatus: LiveStatus.live,
      ),
      audience: RoomAudience.of(primaryMetric: LiveAudienceMetricType.unknown),
      broadcast: RoomBroadcast.of(liveStatus: LiveStatus.live),
      links: RoomLinks.of(webUrl: InkeEndpoints.roomUrl(uid, liveId: liveId)),
      runtime: RoomRuntime.of(streamHandle: InkeRoomData(liveId: liveId)),
    );
  }

  /// The live [room] of a room entry with the app's [broadcast], received at
  /// [receivedAt]: the app's title and cover where it has them (else the
  /// website's), its audience and start time, no restriction when it gave a
  /// line, and [data] as the room's stream handle (for the link and the
  /// first play).
  static LiveRoom withBroadcast(
    LiveRoom room,
    InkeBroadcast broadcast, {
    required DateTime receivedAt,
    required InkeRoomData data,
  }) => room.rebuild(
    (b) => b
      ..content.replace(
        RoomContent.of(
          title: broadcast.title.isEmpty ? room.content.title : broadcast.title,
          coverUrl: broadcast.cover.isEmpty ? room.content.coverUrl : broadcast.cover,
        ),
      )
      ..audience.replace(_audience(broadcast))
      ..broadcast.replace(
        RoomBroadcast.of(
          liveStatus: room.broadcast.liveStatus,
          startedAt: broadcast.startedAt,
          restriction: broadcast.hasLine ? LiveRestriction.none : null,
        ),
      )
      ..links.replace(RoomLinks.of(webUrl: InkeEndpoints.roomUrl(room.roomId, liveId: broadcast.liveId)))
      ..runtime = RoomRuntime.of(streamHandle: data).toBuilder(),
  );

  /// `now_publish?id=`: the broadcast the app says [uid] is live with, or
  /// null when it says none (`live` null, or a `status` other than 1). A
  /// broadcast of another anchor or without an id is api-changed.
  static InkeBroadcast? broadcast(String body, {required String uid, int status = 200}) {
    const what = 'now_publish';
    final live = appData(body, what: what, status: status)['live'];
    if (live == null) return null;
    final map = InkeJson.object(live, '$what.live');
    if (InkeJson.idOrNull(map['creator']) != uid) {
      throw InkeFailure(InkeFailureKind.apiChanged, '$what: a broadcast of ${map['creator']} for $uid');
    }
    if (InkeJson.integer(map['status']) != 1) return null;
    return _broadcast(map, InkeJson.idOf(map['id'], '$what.live.id'));
  }

  /// An app broadcast [live] with id [liveId] (see [InkeBroadcast]).
  static InkeBroadcast _broadcast(Map<String, dynamic> live, String liveId) {
    final numbers = live['numbers'];
    return InkeBroadcast(
      liveId: liveId,
      pullUrl: plainFlv(live['stream_addr'], liveId: liveId),
      originUrl: zegoFlv(live['stream_multi_addr'], liveId: liveId),
      title: _title(live['name']),
      cover: InkeJson.picture(live['cover']),
      startedAt: InkeJson.startedAt(live['start_time']),
      online: numbers is Map ? InkeJson.count(numbers['real']) : null,
      heat: InkeJson.count(live['online_users']),
    );
  }

  // Streams -------------------------------------------------------------------

  /// The qualities of the broadcast [data] holds, in display order: 3.x's FLV
  /// ([InkeEndpoints.flvQualityId], H.264), and the original
  /// ([InkeEndpoints.originQualityId], HEVC) when the room entry's app answer
  /// has its line. With "prefer H.264" on (the default) FLV comes first, else
  /// the original. A room the platform called offline is stream-unavailable;
  /// whether a live room plays is settled when its lines are resolved.
  static List<LivePlayQuality> qualities(InkeRoomData data, {required bool preferH264}) {
    if (data.liveId == null && data.broadcast == null) {
      throw const InkeFailure(InkeFailureKind.streamUnavailable, 'the room is not live');
    }
    const flv = LivePlayQuality(
      label: InkeEndpoints.flvQualityLabel,
      qualityId: InkeEndpoints.flvQualityId,
      codec: LiveStreamCodec.avc,
    );
    if (data.broadcast?.originUrl == null) return [flv];
    const origin = LivePlayQuality(
      label: InkeEndpoints.originQualityLabel,
      qualityId: InkeEndpoints.originQualityId,
      platformOrder: 1,
      codec: LiveStreamCodec.hevc,
    );
    return preferH264 ? [flv, origin] : [origin, flv];
  }

  /// [value] when it is the Wangsu pull URL of broadcast [liveId] (3.x's
  /// check): http(s), host `live-pull-ws.ikstatic.cn`, the default port, no
  /// user info or fragment, path `/live/<liveId>_t.flv` (the H.264
  /// transcode). The signed query is kept as written; the Zego address never
  /// passes. Null otherwise.
  static String? plainFlv(Object? value, {required String liveId}) =>
      _pullUrl(value, host: InkeEndpoints.pullHostWs, path: '/live/${liveId}_t.flv', liveId: liveId);

  /// [value] when it is the Zego pull URL of broadcast [liveId]: http(s),
  /// host `live-pull-zego.ikstatic.cn`, the default port, no user info or
  /// fragment, path `/inkemain/<liveId>_0_en.flv` (the anchor's original
  /// stream, HEVC when it says `codecInfo=8192`). Kept as written (the app
  /// gives http). Null otherwise.
  static String? zegoFlv(Object? value, {required String liveId}) =>
      _pullUrl(value, host: InkeEndpoints.pullHostZego, path: '/inkemain/${liveId}_0_en.flv', liveId: liveId);

  static String? _pullUrl(Object? value, {required String host, required String path, required String liveId}) {
    final text = InkeJson.text(value);
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !InkeEndpoints.isId(liveId) ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
        uri.host != host ||
        uri.hasFragment ||
        uri.path != path) {
      return null;
    }
    return text;
  }

  /// The codec of the Zego pull URL [url]: HEVC for `codecInfo=8192` (every
  /// broadcast recorded or probed), null (not declared) otherwise.
  static LiveStreamCodec? zegoCodec(String url) {
    final List<String>? values;
    try {
      values = Uri.tryParse(url)?.queryParametersAll['codecInfo'];
    } on FormatException {
      return null;
    }
    return values != null && values.length == 1 && values.single == '8192' ? LiveStreamCodec.hevc : null;
  }

  /// The line of a Wangsu pull URL received at [issuedAt]: the media
  /// headers, FLV, H.264, the Wangsu line label and the lease of its
  /// `wsABStime`.
  static LivePlayLine flvLine(String url, {required DateTime issuedAt}) => LivePlayLine(
    url: url,
    format: LiveStreamFormat.flv,
    formatSource: LivePlayFormatSource.declared,
    codec: LiveStreamCodec.avc,
    lineLabel: InkeEndpoints.lineLabel,
    headers: InkeEndpoints.headers,
    lease: lease(url, issuedAt: issuedAt),
  );

  /// The line of the Zego pull URL [url] received at [issuedAt]: the media
  /// headers, FLV, its codec ([zegoCodec]), the Zego line label and the lease
  /// of its `wsABStime` (the broadcast's start plus a day).
  static LivePlayLine zegoLine(String url, {required DateTime issuedAt}) => LivePlayLine(
    url: url,
    format: LiveStreamFormat.flv,
    formatSource: LivePlayFormatSource.declared,
    codec: zegoCodec(url),
    lineLabel: InkeEndpoints.zegoLineLabel,
    headers: InkeEndpoints.headers,
    lease: lease(url, issuedAt: issuedAt),
  );

  /// The lease of a pull URL received at [issuedAt]: `wsABStime` is the
  /// expiry in hexadecimal Unix seconds (Wangsu about two hours after issue,
  /// Zego a day after the broadcast started); renew [InkeEndpoints.leaseLead]
  /// (at most a quarter of the lifetime) before. The CDN checks it when a
  /// connection opens, so an established FLV connection keeps flowing. No
  /// single `wsABStime`, or one already past, is no lease.
  static LivePlayLease? lease(String url, {required DateTime issuedAt}) {
    final List<String>? values;
    try {
      values = Uri.tryParse(url)?.queryParametersAll['wsABStime'];
    } on FormatException {
      return null;
    }
    if (values == null || values.length != 1 || !RegExp(r'^[0-9a-fA-F]{1,12}$').hasMatch(values.single)) return null;
    final expires = int.parse(values.single, radix: 16);
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expires * 1000, isUtc: true);
    final lifetime = expiresAt.difference(issuedAt);
    if (expires <= 0 || lifetime <= Duration.zero) return null;
    final quarter = lifetime ~/ 4;
    final lead = quarter < InkeEndpoints.leaseLead ? quarter : InkeEndpoints.leaseLead;
    return LivePlayLease(refreshAt: expiresAt.subtract(lead), expiresAt: expiresAt);
  }

  /// A broadcast title: trimmed text, empty for
  /// [InkeEndpoints.placeholderTitle].
  static String _title(Object? value) {
    final text = InkeJson.text(value);
    return text == InkeEndpoints.placeholderTitle ? '' : text;
  }
}
