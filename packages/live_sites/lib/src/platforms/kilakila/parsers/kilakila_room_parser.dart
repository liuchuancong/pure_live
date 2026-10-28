import 'dart:math' as math;

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
import 'package:live_sites/src/platforms/kilakila/api/kilakila_endpoints.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_manifest.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_failure.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_html.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One broadcast of an anchor: a timeline row, an anchor's current card or
/// `getRoomInfo`. The broadcast id is new every time the anchor goes live;
/// the uid is the room identity.
final class KilakilaBroadcast {
  /// Creates the broadcast.
  const KilakilaBroadcast({
    required this.broadcastId,
    required this.uid,
    required this.title,
    required this.nick,
    required this.status,
    required this.goldPrice,
    this.cover = '',
    this.avatar = '',
    this.startedAt,
    this.online,
    this.total,
    this.flv,
    this.hls,
  });

  /// `roomIdStr`.
  final String broadcastId;

  /// The anchor's uid.
  final String uid;

  /// Title.
  final String title;

  /// Anchor name.
  final String nick;

  /// `backPic`, else `defaultBackgroundPicUrl`.
  final String cover;

  /// Anchor avatar.
  final String avatar;

  /// The platform's state: 4 live, 10 ended (a replay); every other value is
  /// unknown.
  final int status;

  /// Price of a paid broadcast; 0 when free.
  final int goldPrice;

  /// When the broadcast went on air (`actualTime`, epoch milliseconds);
  /// only an anchor's card has it.
  final DateTime? startedAt;

  /// Listeners now (`onlineNumber`); only an anchor's card has it.
  final int? online;

  /// Listeners of this broadcast so far (`watchNumber`, only ever grows).
  final int? total;

  /// The FLV pull URL of `getRoomInfo` (null elsewhere, or when it is not a
  /// pull URL of this broadcast).
  final String? flv;

  /// The HLS pull URL of `getRoomInfo`, as [flv].
  final String? hls;

  /// Whether the platform says live (status 4).
  bool get isLive => status == 4;

  /// Whether the platform says the broadcast is over (status 10; it may keep
  /// a recording, which the anchor's room does not play).
  bool get hasEnded => status == 10;

  /// What keeps the broadcast from playing: paid when it has a price, else
  /// none.
  LiveRestriction get restriction => goldPrice == 0 ? LiveRestriction.none : LiveRestriction.paid;

  /// This broadcast (from `getRoomInfo`) with what only the anchor's [card]
  /// of the same broadcast has: the start, the listeners now, and its cover
  /// when it has one (the list's `backPic`, where `getRoomInfo` only has the
  /// default background).
  KilakilaBroadcast withCard(KilakilaBroadcast card) => KilakilaBroadcast(
    broadcastId: broadcastId,
    uid: uid,
    title: title,
    nick: nick,
    status: status,
    goldPrice: goldPrice,
    cover: card.cover.isNotEmpty ? card.cover : cover,
    avatar: avatar,
    startedAt: card.startedAt,
    online: card.online,
    total: total ?? card.total,
    flv: flv,
    hls: hls,
  );
}

/// An anchor's public profile (`Tg/personalH5`) and the broadcast it
/// advertises, if any.
final class KilakilaProfile {
  /// Creates the profile.
  const KilakilaProfile({
    required this.uid,
    required this.nick,
    this.avatar = '',
    this.introduction = '',
    this.followers,
    this.current,
  });

  /// The anchor's uid.
  final String uid;

  /// Display name.
  final String nick;

  /// Avatar.
  final String avatar;

  /// Self-introduction (`userResp.introduction`).
  final String introduction;

  /// `userResp.statisticInfo.followerNumber`, when given.
  final int? followers;

  /// The current broadcast's card; null when the card holds only routing
  /// defaults (no current broadcast).
  final KilakilaBroadcast? current;
}

/// What room entry learnt about an anchor's current broadcast; the pull
/// URLs' lease counts from [issuedAt].
final class KilakilaRoomData {
  /// Creates the data.
  const KilakilaRoomData({required this.issuedAt, this.broadcast});

  /// The current broadcast from `getRoomInfo` with its pull URLs; null when
  /// the profile advertised none.
  final KilakilaBroadcast? broadcast;

  /// When `getRoomInfo` answered.
  final DateTime issuedAt;
}

/// Pure parsing of KilaKila responses: the timeline, the search page, the
/// anchor profile, the broadcast answer, and the v2 rooms, qualities and
/// lines.
///
/// A room is an anchor: its id is the anchor's uid, and every broadcast has a
/// new `roomIdStr`. Answers are checked strictly, except that one broken row
/// of a list only drops that row; a page whose echo or identity does not
/// match, or whose rows are all broken, is api-changed. An anchor the
/// platform says has no broadcast, or whose broadcast ended, is offline; any
/// other state the platform does not name stays unknown.
abstract final class KilakilaRoomParser {
  /// The platform's areas: the two timelines, without a request.
  static List<LiveArea> areas() => [
    for (final entry in KilakilaEndpoints.timelines.entries)
      LiveArea.normalized(
        platform: kilakilaSiteId,
        areaId: entry.key,
        areaName: entry.value,
        parentAreaId: 'kilakila',
        parentAreaName: KilakilaEndpoints.categoryName,
      ),
  ];

  // Timeline ------------------------------------------------------------------

  /// A `pcLive/timeline` page: the live rows of timeline [type] (`dataType`
  /// 8, and 2 on the rising stars 107), each broadcast and each anchor once,
  /// and whether another page follows.
  ///
  /// The answer is wrapped twice (`code`, then `data.body` with `{h, b}`);
  /// `b` must echo [page] and [pageSize]. Rows of other types are skipped. A
  /// row that is broken is left out; a page with a broken row and no usable
  /// one is api-changed, so a changed API never reads as an empty timeline.
  ///
  /// The timeline ends at `isLastPage`, at a page without any row, and at
  /// [KilakilaEndpoints.maxPages]. A page whose rows are all of other types
  /// does not end it. An `isLastPage` that is there must be a boolean.
  static ({List<KilakilaBroadcast> rooms, bool hasMore}) timelinePage(
    String body, {
    required int page,
    required int pageSize,
    required int type,
    int status = 200,
  }) {
    const what = 'timeline';
    final root = KilakilaJson.json(body, what, status);
    KilakilaJson.code(root['code'], what);
    final envelope = KilakilaJson.object(KilakilaJson.object(root['data'], '$what.data')['body'], '$what.data.body');
    KilakilaJson.header(envelope, what);
    final data = KilakilaJson.object(envelope['b'], '$what.b');
    final last = data['isLastPage'];
    if (KilakilaJson.integer(data['pageNo']) != page ||
        KilakilaJson.integer(data['pageSize']) != pageSize ||
        (last != null && last is! bool)) {
      throw KilakilaFailure(
        KilakilaFailureKind.apiChanged,
        '$what page $page: echo pageNo ${data['pageNo']}, pageSize ${data['pageSize']}, isLastPage $last',
      );
    }
    final rows = data['data'];
    if (rows is! List || rows.length > 1000) {
      throw const KilakilaFailure(KilakilaFailureKind.apiChanged, '$what.b.data: expected a list');
    }
    final broadcasts = <String>{};
    final anchors = <String>{};
    final rooms = <KilakilaBroadcast>[];
    var broken = 0;
    for (final row in rows) {
      final KilakilaBroadcast broadcast;
      try {
        final fields = KilakilaJson.object(row, '$what row');
        final kind = KilakilaJson.nonNegative(fields['dataType'], '$what row dataType');
        if (kind != 8 && !(type == 107 && kind == 2)) continue;
        broadcast = _broadcast(
          KilakilaJson.object(fields['roomResq'], '$what row roomResq'),
          KilakilaJson.object(fields['userResp'], '$what row userResp'),
        );
      } on KilakilaFailure {
        broken++;
        continue;
      }
      if (!broadcasts.add(broadcast.broadcastId) || !anchors.add(broadcast.uid)) continue;
      rooms.add(broadcast);
    }
    if (broken > 0 && rooms.isEmpty) {
      throw KilakilaFailure(KilakilaFailureKind.apiChanged, '$what page $page: $broken broken rows, none usable');
    }
    return (rooms: rooms, hasMore: last != true && rows.isNotEmpty && page < KilakilaEndpoints.maxPages);
  }

  // Search --------------------------------------------------------------------

  /// The keyword sent for [keyword]: trimmed and cut to the platform's limit
  /// in UTF-16 code units, never inside a surrogate pair, then trimmed
  /// again. Empty when there is nothing to search for.
  static String searchKeyword(String keyword) {
    var text = keyword.trim();
    if (text.length > KilakilaEndpoints.keywordLimit) {
      var end = KilakilaEndpoints.keywordLimit;
      final last = text.codeUnitAt(end - 1);
      if (last >= 0xD800 && last <= 0xDBFF) end--;
      text = text.substring(0, end).trim();
    }
    return text;
  }

  /// A user search page: the anchors of the `.userList` links
  /// `/zhubo/<uid>`, each once, as rooms with their name (also the title)
  /// and avatar. The page says nothing about broadcasts, so their state is
  /// unknown. An entry whose link is not an anchor page or that has no name
  /// is left out; a page without the list, with more than 100 entries, or
  /// whose entries are all broken is api-changed.
  static List<LiveRoom> searchPage(String html, {int status = 200}) {
    const what = 'search';
    KilakilaJson.checkBody(html, what, status);
    final list = KilakilaHtml.parse(html).firstWithClass('userList');
    if (list == null || list.children.length > 100) {
      throw const KilakilaFailure(KilakilaFailureKind.apiChanged, '$what: no user list');
    }
    final rooms = <String, LiveRoom>{};
    var broken = 0;
    for (final anchor in list.children.where((element) => element.name == 'a')) {
      final match = RegExp(r'^/zhubo/([1-9][0-9]{0,31})$').firstMatch(anchor.attributes['href'] ?? '');
      final nick = anchor.firstWithClass('anchor-name')?.text.trim() ?? '';
      if (match == null || nick.isEmpty) {
        broken++;
        continue;
      }
      final uid = match.group(1)!;
      final avatar = anchor.firstWithClass('anchorHeaderImg')?.first('img')?.attributes['src'];
      rooms.putIfAbsent(uid, () => _anchorRoom(uid, nick: nick, avatar: KilakilaJson.picture(avatar), title: nick));
    }
    if (broken > 0 && rooms.isEmpty) {
      throw KilakilaFailure(KilakilaFailureKind.apiChanged, '$what: $broken broken entries, none usable');
    }
    return rooms.values.toList();
  }

  // Anchors and broadcasts ----------------------------------------------------

  /// `Tg/personalH5?uid=`: the anchor [uid] and its current broadcast. Code
  /// 1013 is an unknown anchor (not-found); any other code but 200 is
  /// api-changed. A `liveCard` holding only the routing defaults
  /// `roomSourceType` and `recommendSource` (or nothing) means no current
  /// broadcast; anything else must be a whole card of this anchor.
  static KilakilaProfile profile(String body, {required String uid, int status = 200}) {
    const what = 'personalH5';
    final root = KilakilaJson.json(body, what, status);
    if (KilakilaJson.integer(root['code']) == 1013) {
      throw KilakilaFailure(KilakilaFailureKind.notFound, '$what: no anchor $uid');
    }
    KilakilaJson.code(root['code'], what);
    final data = KilakilaJson.object(root['data'], '$what.data');
    final user = KilakilaJson.object(data['userResp'], '$what.userResp');
    final card = KilakilaJson.object(data['liveCard'], '$what.liveCard');
    final nick = KilakilaJson.text(user['nickname']);
    if (nick.isEmpty || (user.containsKey('id') && KilakilaJson.id(user['id'], '$what.userResp.id') != uid)) {
      throw KilakilaFailure(KilakilaFailureKind.apiChanged, '$what: not the anchor $uid');
    }
    KilakilaBroadcast? current;
    const routingKeys = {'roomSourceType', 'recommendSource'};
    if (card.keys.every(routingKeys.contains)) {
      for (final value in card.values) {
        KilakilaJson.nonNegative(value, '$what.liveCard');
      }
    } else {
      // The profile has no uid of its own: the card must name this anchor.
      if (KilakilaJson.id(card['uid'], '$what.liveCard.uid') != uid) {
        throw const KilakilaFailure(KilakilaFailureKind.apiChanged, '$what: liveCard of another anchor');
      }
      current = _broadcast(card, {...user, 'id': uid});
    }
    final statistics = user['statisticInfo'];
    return KilakilaProfile(
      uid: uid,
      nick: nick,
      avatar: KilakilaJson.picture(user['headPortraitUrl']),
      introduction: KilakilaJson.text(user['introduction']),
      followers: statistics is Map<String, dynamic> ? KilakilaJson.count(statistics['followerNumber']) : null,
      current: current,
    );
  }

  /// `LiveRoom/getRoomInfo?roomId=`: the broadcast [broadcastId] with its
  /// pull URLs; when [uid] is given it must be that anchor's. `h.code` 5201
  /// is an unknown broadcast (not-found), 5966 a historical replay
  /// (stream-unavailable); any other code but 200, or another broadcast or
  /// anchor, is api-changed.
  static KilakilaBroadcast roomInfo(String body, {required String broadcastId, String? uid, int status = 200}) {
    const what = 'getRoomInfo';
    final root = KilakilaJson.json(body, what, status);
    final header = KilakilaJson.object(root['h'], '$what.h');
    final code = KilakilaJson.integer(header['code']);
    if (code == 5201) throw KilakilaFailure(KilakilaFailureKind.notFound, '$what: no broadcast $broadcastId');
    if (code == 5966) {
      throw KilakilaFailure(KilakilaFailureKind.streamUnavailable, '$what: $broadcastId is a historical replay');
    }
    KilakilaJson.header(root, what);
    final room = KilakilaJson.object(root['b'], '$what.b');
    if (KilakilaJson.id(room['roomIdStr'], '$what.roomIdStr') != broadcastId ||
        (uid != null && KilakilaJson.id(room['uid'], '$what.uid') != uid)) {
      throw KilakilaFailure(KilakilaFailureKind.apiChanged, '$what $broadcastId: another broadcast or anchor');
    }
    return _broadcast(room, KilakilaJson.object(room['userInfo'], '$what.userInfo'), media: true);
  }

  /// A broadcast [room] of the anchor [owner]: ids, title, name, state and
  /// price are required, the cover is `backPic` or `defaultBackgroundPicUrl`.
  /// The start (`actualTime`), listeners now (`onlineNumber`) and so far
  /// (`watchNumber`) are read where the answer has them. The pull URLs are
  /// read only with [media]. The push address (`pushFlow`, the anchor's
  /// stream key) is never read.
  static KilakilaBroadcast _broadcast(Map<String, dynamic> room, Map<String, dynamic> owner, {bool media = false}) {
    final broadcastId = KilakilaJson.id(room['roomIdStr'], 'roomIdStr');
    final uid = KilakilaJson.id(room['uid'], 'broadcast $broadcastId uid');
    final title = KilakilaJson.text(room['title']);
    final nick = KilakilaJson.text(owner['nickname']);
    if (KilakilaJson.id(owner['id'], 'broadcast $broadcastId owner') != uid || title.isEmpty || nick.isEmpty) {
      throw KilakilaFailure(KilakilaFailureKind.apiChanged, 'broadcast $broadcastId: owner, title or name missing');
    }
    final cover = KilakilaJson.picture(room['backPic']);
    return KilakilaBroadcast(
      broadcastId: broadcastId,
      uid: uid,
      title: title,
      nick: nick,
      cover: cover.isNotEmpty ? cover : KilakilaJson.picture(room['defaultBackgroundPicUrl']),
      avatar: KilakilaJson.picture(owner['headPortraitUrl']),
      status: KilakilaJson.nonNegative(room['status'], 'broadcast $broadcastId status'),
      goldPrice: KilakilaJson.nonNegative(room['goldPrice'], 'broadcast $broadcastId goldPrice'),
      startedAt: KilakilaJson.startedAt(room['actualTime']),
      online: KilakilaJson.count(room['onlineNumber']),
      total: KilakilaJson.count(room['watchNumber']),
      flv: media ? mediaUrl(room['flvPlayUrl'], broadcastId: broadcastId, isHls: false) : null,
      hls: media ? mediaUrl(room['hlsPlayUrl'], broadcastId: broadcastId, isHls: true) : null,
    );
  }

  // Rooms ---------------------------------------------------------------------

  /// The room of [broadcast]: the anchor's uid is the room id and the anchor
  /// page the link. The state is live when the platform says 4, offline when
  /// the broadcast ended (10), else unknown. A live broadcast also has its
  /// listeners now (only an anchor's card has them) and so far (cumulative,
  /// never shown as online), its start, and its restriction (paid or none).
  static LiveRoom room(KilakilaBroadcast broadcast) {
    final live = broadcast.isLive;
    final liveStatus = live ? LiveStatus.live : (broadcast.hasEnded ? LiveStatus.offline : LiveStatus.unknown);
    return LiveRoom.normalized(
      platform: kilakilaSiteId,
      roomId: broadcast.uid,
      content: RoomContent.of(title: broadcast.title, coverUrl: broadcast.cover),
      anchor: LiveAnchor.normalized(
        platform: kilakilaSiteId,
        anchorId: broadcast.uid,
        name: broadcast.nick,
        avatarUrl: broadcast.avatar,
        liveStatus: liveStatus,
      ),
      audience: RoomAudience.of(
        onlineViewers: live ? broadcast.online : null,
        totalViewers: live ? broadcast.total : null,
        primaryMetric: live ? LiveAudienceMetricType.onlineViewers : LiveAudienceMetricType.unknown,
      ),
      broadcast: RoomBroadcast.of(
        liveStatus: liveStatus,
        startedAt: live ? broadcast.startedAt : null,
        restriction: live ? broadcast.restriction : null,
      ),
      links: RoomLinks.of(webUrl: KilakilaEndpoints.ownerUrl(broadcast.uid)),
    );
  }

  /// The room of [profile] when searched for (an anchor without a current
  /// broadcast): the name is also the title; offline, since the platform
  /// says there is no broadcast.
  static LiveRoom profileRoom(KilakilaProfile profile) => _anchorRoom(
    profile.uid,
    nick: profile.nick,
    avatar: profile.avatar,
    title: profile.nick,
    liveStatus: LiveStatus.offline,
  );

  /// The detail of [profile]: its current broadcast's room, else the anchor,
  /// offline (the card says there is no broadcast). The introduction and
  /// follower count come along.
  static LiveRoom profileDetail(KilakilaProfile profile) {
    final current = profile.current;
    final base = current == null
        ? _anchorRoom(profile.uid, nick: profile.nick, avatar: profile.avatar, liveStatus: LiveStatus.offline)
        : room(current);
    return _withProfile(base, profile);
  }

  /// Room entry's room: [broadcast] from `getRoomInfo` with what the anchor's
  /// card of the same broadcast adds (start, listeners now, and the card's
  /// cover), and [profile]'s introduction and follower count.
  static LiveRoom enteredRoom(KilakilaProfile profile, KilakilaBroadcast broadcast) {
    final card = profile.current;
    final merged = card != null && card.broadcastId == broadcast.broadcastId ? broadcast.withCard(card) : broadcast;
    return _withProfile(room(merged), profile);
  }

  /// [room] with [profile]'s introduction and follower count.
  static LiveRoom _withProfile(LiveRoom room, KilakilaProfile profile) => room.rebuild(
    (b) => b
      ..content.replace(
        room.content.rebuild((b) => b..introduction = profile.introduction.isEmpty ? null : profile.introduction),
      )
      ..anchor =
          (profile.followers == null ? room.anchor : room.anchor?.rebuild((b) => b..followerCount = profile.followers))
              ?.toBuilder(),
  );

  static LiveRoom _anchorRoom(
    String uid, {
    required String nick,
    required String avatar,
    String title = '',
    LiveStatus liveStatus = LiveStatus.unknown,
  }) => LiveRoom.normalized(
    platform: kilakilaSiteId,
    roomId: uid,
    content: RoomContent.of(title: title),
    anchor: LiveAnchor.normalized(
      platform: kilakilaSiteId,
      anchorId: uid,
      name: nick,
      avatarUrl: avatar,
      liveStatus: liveStatus,
    ),
    broadcast: RoomBroadcast.of(liveStatus: liveStatus),
    links: RoomLinks.of(webUrl: KilakilaEndpoints.ownerUrl(uid)),
  );

  // Streams -------------------------------------------------------------------

  /// The qualities of the broadcast [data] holds: one, 原画, whose lines are
  /// the pull URLs, FLV then HLS. No broadcast, one that is not live (status
  /// other than 4) or without a pull URL is stream-unavailable; so is a paid
  /// one (`goldPrice` above 0), checked first.
  static List<LivePlayQuality> qualities(KilakilaRoomData data) {
    final broadcast = data.broadcast;
    if (broadcast == null) {
      throw const KilakilaFailure(KilakilaFailureKind.streamUnavailable, 'no current broadcast');
    }
    if (broadcast.restriction == LiveRestriction.paid) {
      throw KilakilaFailure(
        KilakilaFailureKind.streamUnavailable,
        'broadcast ${broadcast.broadcastId} is restricted (paid)',
      );
    }
    if (!broadcast.isLive) {
      throw KilakilaFailure(
        KilakilaFailureKind.streamUnavailable,
        'broadcast ${broadcast.broadcastId} has status ${broadcast.status}',
      );
    }
    if ((broadcast.flv == null || broadcast.flv!.isEmpty) && (broadcast.hls == null || broadcast.hls!.isEmpty)) {
      throw KilakilaFailure(
        KilakilaFailureKind.streamUnavailable,
        'broadcast ${broadcast.broadcastId} has no pull URL',
      );
    }
    return [LivePlayQuality.of(label: KilakilaEndpoints.qualityName, qualityId: KilakilaEndpoints.qualityId)];
  }

  /// The lines of [qualityId] (a stored `flv` or `hls` names the one quality)
  /// among [data]'s [qualities]: FLV then HLS, each with the media headers,
  /// its format, its transport as line label and the lease of its `auth_key`.
  /// A bad or missing URL only drops its line. A quality the broadcast does
  /// not offer is stream-unavailable.
  static List<LivePlayLine> lines(KilakilaRoomData data, String qualityId) {
    final wanted = KilakilaEndpoints.qualityIdFromLegacy(qualityId);
    if (wanted != KilakilaEndpoints.qualityId || qualities(data).isEmpty) {
      throw KilakilaFailure(KilakilaFailureKind.streamUnavailable, 'quality $qualityId is not offered');
    }
    final broadcast = data.broadcast!;
    final urls = [?broadcast.flv, ?broadcast.hls].where((url) => url.isNotEmpty).toList();
    return [
      for (final url in urls)
        () {
          final isHls = Uri.parse(url).path.endsWith('.m3u8');
          return LivePlayLine.of(
            url: url,
            format: isHls ? LiveStreamFormat.hls : LiveStreamFormat.flv,
            formatSource: LivePlayFormatSource.inferred,
            lineLabel: isHls ? 'hls' : 'flv',
            headers: KilakilaEndpoints.headers,
            lease: lease(url, issuedAt: data.issuedAt, isHls: isHls),
          );
        }(),
    ];
  }

  /// [value] when it is the pull URL for [broadcastId]:
  /// `https://pull.live.hongrenshuo.com.cn/hrs/<id>.flv` or `.m3u8`, the
  /// default port, no user info or fragment, exactly one non-empty
  /// `auth_key`; the text is kept as written. Else null (the `rtmpPlayUrl`
  /// and the push address never qualify).
  static String? mediaUrl(Object? value, {required String broadcastId, required bool isHls}) {
    final text = KilakilaJson.text(value);
    if (text.length > 8192) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != KilakilaEndpoints.mediaHost ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.hasPort && uri.port != 443) ||
        uri.path != '/hrs/$broadcastId.${isHls ? 'm3u8' : 'flv'}') {
      return null;
    }
    try {
      final auth = uri.queryParametersAll['auth_key'];
      if (auth == null || auth.length != 1 || auth.single.isEmpty || auth.single.length > 1024) return null;
      return text;
    } on FormatException {
      return null;
    }
  }

  /// The lease of a pull URL received at [issuedAt]: it stops at the first
  /// field of its `auth_key` (`<Unix seconds>-<rand>-<uid>-<md5>`, 30 days
  /// after issue) and is renewed by the lead (at most a quarter of its
  /// lifetime) before. An HLS playlist is fetched again and again, so its
  /// expiry ends playback; an established FLV connection keeps flowing. Null
  /// without a future expiry.
  static LivePlayLease? lease(
    String url, {
    required DateTime issuedAt,
    required bool isHls,
    bool allowExpired = false,
  }) {
    final uri = Uri.tryParse(url);
    final expires = int.tryParse(uri?.queryParameters['auth_key']?.split('-').first ?? '');
    if (uri == null || expires == null || expires <= 0) return null;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expires * 1000, isUtc: true);
    final lifetime = expiresAt.difference(issuedAt);
    if (lifetime <= Duration.zero) {
      return allowExpired
          ? LivePlayLease.of(
              refreshAt: expiresAt.subtract(KilakilaEndpoints.leaseLead),
              expiresAt: expiresAt,
              requiresReconnect: isHls,
            )
          : null;
    }
    final lead = Duration(
      microseconds: math.min(KilakilaEndpoints.leaseLead.inMicroseconds, lifetime.inMicroseconds ~/ 4),
    );
    return LivePlayLease.of(refreshAt: expiresAt.subtract(lead), expiresAt: expiresAt, requiresReconnect: isHls);
  }
}
