import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_parser.dart';

/// The Weibo adapter: one broadcast per live id (every broadcast has its own
/// link, so a room id is a broadcast id), the official recommendation
/// snapshot as the directory, and a nickname filter over that snapshot as the
/// search.
///
/// The snapshot is one page (no server paging), so pages after the first are
/// empty without a request. Not migrated yet: the `t.cn` short-link search
/// branch (which resolves the redirect first) and the danmaku transport.
final class WeiboSite with SiteRoomGuard implements LiveSite, LiveAreaCatalog, LiveDirectoryCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.weibo;

  @override
  String get id => SiteIds.weibo;

  @override
  SiteMetadata get metadata => const SiteMetadata(id: SiteIds.weibo, displayName: '微博直播', homeUrl: 'https://weibo.com');

  /// The catalogue: the one area, the official recommendation snapshot.
  @override
  Future<List<LiveArea>> getAreas() async => const [LiveArea(id: WeiboParser.areaId, name: WeiboParser.areaName)];

  /// Page [page] of the recommendation snapshot: one page of live broadcasts,
  /// the most-watched first, without audience. Pages after the first are
  /// empty without a request.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    if (page > 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final response = await http.send(
      LiveRequest.get(WeiboParser.recommendUrl(), headers: WeiboParser.headers, site: siteId),
    );
    return WeiboParser.recommendations(response.text, status: response.statusCode);
  }

  /// As [getRecommendRooms], for the one area; any other area is a caller
  /// error refused before a request.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    if (area.id.trim() != WeiboParser.areaId) {
      throw SiteError.invalidRoomId(area.id);
    }
    return getRecommendRooms(page: page);
  }

  /// 3.x's search, on page 1 only (a later page is empty without a request):
  /// a broadcast id or room link finds that room (a room the site does not
  /// know is nothing); another link or a blank keyword is nothing; anything
  /// else filters the snapshot's nicknames. The `t.cn` short link is not
  /// resolved yet.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    if (page > 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final input = keyword.trim();
    final exact = WeiboParser.exactRoom(input);
    if (exact != null) {
      try {
        return LivePage<LiveRoom>(items: [await _detail(exact)]);
      } on SiteNotFoundError {
        return const LivePage<LiveRoom>(items: []);
      }
    }
    if (input.isEmpty || _isLink(input)) {
      return const LivePage<LiveRoom>(items: []);
    }
    final snapshot = await getRecommendRooms();
    return LivePage<LiveRoom>(items: WeiboParser.searchSnapshot(input, snapshot.items));
  }

  /// Whether [input] is a link (`scheme://…`) rather than a keyword. 3.x
  /// filtered the snapshot's nicknames with it, which never matched.
  static bool _isLink(String input) {
    final uri = Uri.tryParse(input);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _detail(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final fresh = room.data == null ? await _detail(room.roomId) : room;
    final lines = WeiboParser.playLines(fresh.data, room.roomId);
    final labels = <String>{
      for (final line in lines)
        if (line.lineId != null) line.lineId!,
    };
    return [for (final (index, label) in labels.indexed) LivePlayQuality(label: label.toUpperCase(), sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _detail(room.roomId) : room;
    final lines = WeiboParser.playLines(fresh.data, room.roomId);
    final matching = lines.where((line) => line.lineId?.toUpperCase() == quality.label).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _detail(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _detail(String liveId) async {
    final response = await http.send(
      LiveRequest.get(WeiboParser.detailUrl(liveId), headers: WeiboParser.headers, site: id),
    );
    return WeiboParser.room(response.text, liveId: liveId, status: response.statusCode);
  }
}
