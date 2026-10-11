import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_parser.dart';

/// The Kuaishou adapter: rooms parsed from the page's embedded
/// `window.__INITIAL_STATE__`.
///
/// Not migrated yet: directory boards, search, the session cookie dance
/// (verification pages surface as risk control) and the danmaku
/// transport.
final class KuaishouSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  String? _lastHtml;
  String? _lastRoomId;

  @override
  String get siteId => SiteIds.kuaishou;

  @override
  String get id => SiteIds.kuaishou;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.kuaishou, displayName: '快手直播', homeUrl: 'https://live.kuaishou.com');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('kuaishou directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('kuaishou directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('kuaishou search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final html = await _page(room.roomId);
    return room.mergeFrom(KuaishouParser.roomDetail(html, requestedId: room.roomId));
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final lines = await _lines(room.roomId);
    final labels = <String>{
      for (final line in lines)
        if (line.lineId != null) line.lineId!,
    };
    return [for (final (index, label) in labels.indexed) LivePlayQuality(label: label, sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final lines = await _lines(room.roomId);
    final matching = lines.where((line) => line.lineId == quality.label).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final html = await _page(room.roomId);
    return room.mergeFrom(KuaishouParser.roomDetail(html, requestedId: room.roomId));
  }

  Future<List<LivePlayLine>> _lines(String roomId) async {
    final html = await _page(roomId);
    final state = KuaishouParser.initialState(html);
    return KuaishouParser.playLinesFromRoom(KuaishouParser.playItem(state));
  }

  Future<String> _page(String roomId) async {
    if (_lastRoomId == roomId && _lastHtml != null) {
      return _lastHtml!;
    }
    final response = await http.send(
      LiveRequest.get(Uri.https('live.kuaishou.com', '/u/$roomId'), headers: KuaishouParser.webHeaders, site: id),
    );
    _lastRoomId = roomId;
    return _lastHtml = response.text;
  }
}
