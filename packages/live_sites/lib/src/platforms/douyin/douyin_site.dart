import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_danmaku.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_session.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_sign.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_parser.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_sign.dart';

/// The Douyin adapter: the webcast enter flow with the `a_bogus` signer.
///
/// Request signing goes through [signer]; by default it is the pure-Dart
/// [DouyinWebSigner] for the adapter's own UA. The room-page React payload
/// fallback and the directory/search migration are still ahead.
final class DouyinSite with SiteRoomGuard implements LiveSite, LiveDanmakuCapability {
  /// A site over [http]; [signer] signs query parameters (default: the full
  /// `a_bogus` signer for [DouyinParser]'s UA).
  new({required this.http, DouyinSigner? signer})
    : signer = signer ?? DouyinWebSigner(userAgent: DouyinParser.apiHeaders['user-agent']!).signedUrl;

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

  /// The room's chat: a fresh enter brings this broadcast's numeric room id (the
  /// web IM channel's name) in [LiveRoom.danmakuData]; the visitor id is generated
  /// per connect ([DouyinSign.visitorId]) and the socket is signed and opened by
  /// [DouyinDanmakuSession.connect].
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final detail = await _enter(room.roomId);
    final numeric = detail.danmakuData;
    if (numeric is! String || numeric.isEmpty) {
      throw SiteNotFoundError('douyin ${room.roomId}: no broadcast room id');
    }
    final args = DouyinDanmakuArgs(webRid: room.roomId, roomId: numeric, userId: DouyinSign.visitorId());
    return await DouyinDanmakuSession.connect(args);
  }
}
