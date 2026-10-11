import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_parser.dart';

/// The Douyin adapter: the webcast enter flow with the signer as a seam.
///
/// Request signing (`a_bogus`) is injectable through [signer]; the default
/// sends unsigned requests, which the webcast host answers for several
/// endpoints. The full browser-cipher signer and the room-page React
/// payload fallback are the next migration step — the seam exists so the
/// app can inject them without touching the adapter.
final class DouyinSite with SiteRoomGuard implements LiveSite {
  /// A site over [http]; [signer] signs query parameters (default:
  /// unsigned).
  new({required this.http, DouyinSigner? signer}) : signer = signer ?? _unsigned;

  /// The HTTP transport.
  final LiveHttp http;

  /// The request signer seam.
  final DouyinSigner signer;

  @override
  String get siteId => SiteIds.douyin;

  @override
  String get id => SiteIds.douyin;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.douyin, displayName: '抖音直播', homeUrl: 'https://live.douyin.com');

  static Uri _unsigned(Uri base, Map<String, String> params) => base.replace(queryParameters: params);

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('douyin directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('douyin directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('douyin search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _enter(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    return DouyinParser.qualities(room.data);
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    return DouyinParser.playLines(room.data, qualityId: quality.quality?.toString(), webRid: room.roomId);
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _enter(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _enter(String webRid) async {
    final url = signer(Uri.https('live.douyin.com', '/webcast/room/web/enter/'), {
      'app_name': 'douyin_web',
      'enter_from': 'web_live',
      'live_id': '1',
      'web_rid': webRid,
      'is_need_double_stream': 'false',
    });
    final response = await http.send(LiveRequest.get(url, headers: DouyinParser.apiHeaders, site: id));
    return DouyinParser.enter(response.text, webRid: webRid, status: response.statusCode);
  }
}
