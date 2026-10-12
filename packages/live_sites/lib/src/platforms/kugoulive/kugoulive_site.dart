import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_danmaku.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_session.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_parser.dart';

/// The Kugou Live adapter: getEnterRoomInfo rooms, the streamaddr multi-line
/// play answer and the `index/list` directory.
///
/// Not migrated yet: search (jsonp). The chat ([connect]) is the scheduler's
/// hosts and a protobuf-over-WebSocket login ([KugouLiveDanmakuSession]); the
/// room id is the numeric room number.
final class KugouLiveSite
    with SiteRoomGuard
    implements LiveSite, LiveAreaCatalog, LiveDirectoryCapability, LiveDanmakuCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.kugouLive;

  @override
  String get id => SiteIds.kugouLive;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.kugouLive, displayName: '酷狗直播', homeUrl: 'https://fanxing.kugou.com');

  /// The site's areas, read from its own home page.
  ///
  /// A single request, and the page is also where the room links live, so
  /// the answer is cached for the session: the catalogue and the directory
  /// then agree about what the site currently offers.
  @override
  Future<List<LiveArea>> getAreas() async {
    final html = await _home();
    return KugouLiveParser.areas(html);
  }

  Future<String> _home() => _homeHtml ??= _fetchHome();

  Future<String> _fetchHome() async {
    final response = await http.send(
      LiveRequest.get(Uri.https('fanxing.kugou.com', '/'), headers: KugouLiveParser.apiHeaders, site: siteId),
    );
    if (response.statusCode != 200) {
      throw SiteApiChangedError('kugoulive home page: HTTP ${response.statusCode}');
    }
    return response.text;
  }

  Future<String>? _homeHtml;

  /// Page [page] (1–10000) of the site's recommendations (推荐).
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) => _directory(null, page);

  /// Page [page] of one area: the same listing, with the area's `cid`.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) => _directory(area, page);

  Future<LivePage<LiveRoom>> _directory(LiveArea? area, int page) async {
    final id = KugouLiveParser.areaId(area);
    if (page < 1 || page > KugouLiveParser.maxPage) {
      throw RangeError.range(page, 1, KugouLiveParser.maxPage, 'page');
    }
    final response = await http.send(
      LiveRequest.get(KugouLiveParser.directoryUrl(page, id), headers: KugouLiveParser.apiHeaders, site: siteId),
    );
    return KugouLiveParser.directoryPage(response.text, page: page, status: response.statusCode);
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('kugoulive search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _info(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final lines = await _stream(room.roomId);
    final rates = <int>{
      for (final line in lines)
        if (line.height != null) line.height!,
    };
    return [
      for (final (index, rate) in (rates.toList()..sort((a, b) => b.compareTo(a))).indexed)
        LivePlayQuality(label: rate == 0 ? '原画' : '${rate}K', sort: -index, quality: rate),
    ];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final lines = await _stream(room.roomId);
    final rate = quality.quality;
    if (rate == null) {
      return lines;
    }
    final matching = lines.where((line) => line.height == rate).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _info(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _info(String roomId) async {
    final response = await http.send(
      LiveRequest.get(KugouLiveParser.roomInfoUrl(roomId), headers: KugouLiveParser.apiHeaders, site: id),
    );
    return KugouLiveParser.roomInfo(response.text, roomId: roomId, status: response.statusCode);
  }

  Future<List<LivePlayLine>> _stream(String roomId) async {
    final response = await http.send(
      LiveRequest.get(
        KugouLiveParser.streamUrl(roomId, millis: DateTime.now().millisecondsSinceEpoch),
        headers: KugouLiveParser.apiHeaders,
        site: id,
      ),
    );
    return KugouLiveParser.playLines(response.text, roomId: roomId, status: response.statusCode);
  }

  /// The room's chat: the scheduler's hosts and token, then the login socket
  /// ([KugouLiveDanmakuSession.connect]). The room id is the numeric room
  /// number; a join or scheduler failure surfaces on the message stream, which
  /// the caller's supervisor reconnects.
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) {
    guardRoom(room);
    return KugouLiveDanmakuSession.connect(http, KugouLiveDanmakuArgs(room.roomId));
  }
}
