import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_models.dart';
import 'package:live_sites/src/platforms/bilibili/danmaku/bilibili_session.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_parser.dart';
import 'package:live_sites/src/platforms/bilibili/session/bilibili_guest_session.dart';

/// The Bilibili adapter: guest (unsigned) flows over [LiveHttp] plus the
/// protover-2 danmaku gateway.
///
/// Deliberately not migrated yet, and marked by throwing
/// [UnimplementedError]: WBI request signing (required for
/// `getDanmuInfo` and the second getList), the cookie/session store, risk
/// control retries, carousel rooms, super chats and the gift catalog.
/// Those land with the session-layer migration.
final class BilibiliSite
    with SiteRoomGuard
    implements LiveSite, LiveDanmakuCapability, LiveDirectoryCapability, LiveSearchCapability {
  /// A site over [http]; the guest session owns cookies and WBI keys.
  new({required LiveHttp http}) : session = BilibiliGuestSession(http: http);

  /// The guest session (buvid cookies, WBI keys, signed GETs).
  final BilibiliGuestSession session;

  @override
  String get siteId => SiteIds.bilibili;

  @override
  String get id => SiteIds.bilibili;

  @override
  SiteMetadata get metadata => const SiteMetadata(
    id: SiteIds.bilibili,
    displayName: '哔哩哔哩直播',
    homeUrl: 'https://live.bilibili.com',
    logoUrl: 'https://i0.hdslb.com/bfs/static/jinkela/long/images/TV-Bgroup.png',
  );

  /// The anonymous ranked list, then the recommendation feed.
  ///
  /// Two endpoints because they fail independently: `getListByAreaID` is
  /// the ranked list the site's own home page shows and answers with a
  /// clean `list` payload, while `getMoreRecList` is the personalisation
  /// feed that keeps working when the ranked list is being rate-limited.
  /// The ranked list is tried twice (a 180 ms pause between tries, because
  /// the first call of a cold session sometimes comes back empty), and the
  /// feed is the fallback; when both fail the ranked list's error is the one
  /// reported, since that is the request the caller asked for.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    final number = page < 1 ? 1 : page;
    SiteError? rankedFailure;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_rankedRetryDelay);
      }
      try {
        final data = await _get('/room/v1/Area/getListByAreaID', {
          'areaId': '0',
          'parent_area_id': '0',
          'sort': 'online',
          'pageSize': '30',
          'page': '$number',
        });
        return BilibiliParser.roomList(data);
      } on SiteError catch (error) {
        rankedFailure = error;
      }
    }
    try {
      final data = await _get('/xlive/web-interface/v1/webMain/getMoreRecList', {'platform': 'web', 'page': '$number'});
      return BilibiliParser.roomList(data);
    } on SiteError {
      // The ranked list is what the caller asked for, so its failure is the
      // one reported — not the fallback's.
      throw rankedFailure!;
    }
  }

  /// The pause between the two ranked-list attempts.
  static const Duration _rankedRetryDelay = Duration(milliseconds: 180);

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    final data = await _get('/room/v1/area/getRoomList', {
      'platform': 'web',
      'parent_area_id': area.parentId ?? '0',
      'area_id': area.id,
      'sort_type': 'online',
      'page': '$page',
      'page_size': '30',
    });
    return BilibiliParser.roomList(data);
  }

  /// Live search.
  ///
  /// The search endpoint lives on the *main* site (`api.bilibili.com`), not
  /// on the live host, and answers an anonymous GET: asking the live host
  /// for it returns a 404 (`WebProxyNeedLess`), which is how this method
  /// failed before. A blank keyword asks for nothing.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    final text = keyword.trim();
    if (text.isEmpty) {
      return const LivePage<LiveRoom>(items: []);
    }
    final number = page < 1 ? 1 : page;
    final data = await session.getMain('/x/web-interface/search/type', {
      'search_type': 'live_room',
      'keyword': text,
      'page': '$number',
      'page_size': '30',
    });
    return BilibiliParser.searchRooms(data, page: number);
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final id = _numericId(room.roomId);
    final data = await session.getSigned(BilibiliConstants.apiHost, '/xlive/web-room/v1/index/getInfoByRoom', {
      'room_id': id,
    });
    return room.mergeFrom(BilibiliParser.roomDetail(data, requestedId: id));
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    // The unsigned play-info payload carries only the current quality in
    // its durl flavour; the full quality list arrives with the signed
    // play-url migration.
    return const [LivePlayQuality(label: '原画', quality: 4)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final data = await session.getSigned(BilibiliConstants.apiHost, '/xlive/web-room/v2/index/getRoomPlayInfo', {
      'room_id': room.roomId,
      'protocol': '0,1',
      'format': '0,1,2',
      'codec': '0',
      'qn': '${quality.quality ?? 4}',
      'platform': 'web',
    });
    return BilibiliParser.playLines(data);
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final data = await _get('/room/v1/Room/get_info', {'room_id': room.roomId});
    return room.mergeFrom(BilibiliParser.roomDetail(data, requestedId: room.roomId));
  }

  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) {
    guardRoom(room);
    return BilibiliDanmakuSession.connect(_danmakuArgs(room));
  }

  /// Anonymous danmaku credentials against the default gateway. The
  /// signed `getDanmuInfo` flow arrives with the session-layer migration;
  /// the server accepts anonymous auth packets on it.
  BilibiliDanmakuArgs _danmakuArgs(LiveRoom room) {
    final longId = int.tryParse(room.roomId);
    if (longId == null || longId <= 0) {
      throw SiteError.invalidRoomId(room.roomId);
    }
    return BilibiliDanmakuArgs(roomId: longId, uid: 0, token: '', server: BilibiliConstants.danmakuGateway);
  }

  Future<Map<String, Object?>> _get(String path, Map<String, String> query) => session.get(path, query);

  String _numericId(String roomId) {
    final id = int.tryParse(roomId);
    if (id == null || id <= 0) {
      throw SiteError.invalidRoomId(roomId);
    }
    return '$id';
  }
}
