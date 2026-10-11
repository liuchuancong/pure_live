import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_parser.dart';

/// The Huya adapter: room state and streams read from the room page's
/// embedded config blobs (TT_ROOM_DATA / HYPlayerConfig).
///
/// Not migrated yet: the search endpoint, the Tars-based danmaku
/// transport (a binary protocol over TCP, needs its own codec — the
/// danmaku capability is absent until then), and the Wup token flow for
/// higher qualities.
final class HuyaSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.huya;

  @override
  String get id => SiteIds.huya;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.huya, displayName: '虎牙直播', homeUrl: 'https://www.huya.com');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('huya directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('huya directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('huya search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final html = await _page(room.roomId);
    return room.mergeFrom(HuyaParser.roomDetail(html, requestedId: room.roomId));
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final html = await _page(room.roomId);
    return HuyaParser.playQualities(html);
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final html = await _page(room.roomId);
    final lines = HuyaParser.playLines(html);
    return quality.quality == null
        ? lines
        : lines
              .where(
                (line) =>
                    line.url.contains('ratio=${quality.quality}&') || line.url.contains('ratio=${quality.quality}'),
              )
              .toList();
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final html = await _page(room.roomId);
    return room.mergeFrom(HuyaParser.roomDetail(html, requestedId: room.roomId));
  }

  Future<String> _page(String roomId) async {
    final response = await http.send(
      LiveRequest.get(
        Uri.https('www.huya.com', '/$roomId'),
        headers: const {
          'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        },
        site: id,
      ),
    );
    if (response.statusCode != 200) {
      throw SiteApiChangedError('huya/$roomId: HTTP ${response.statusCode}');
    }
    return response.text;
  }
}
