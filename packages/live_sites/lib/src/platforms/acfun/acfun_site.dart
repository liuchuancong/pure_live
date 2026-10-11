import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_parser.dart';

/// The AcFun adapter: the visitor-session → startPlay play flow.
///
/// Not migrated yet: directory, search and the paid-show ticket flow; the
/// danmaku transport (the ticket comes back from startPlay but the
/// protocol needs its own codec).
final class AcfunSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  String? _deviceId;
  ({String userId, String token})? _visitor;

  @override
  String get siteId => SiteIds.acfun;

  @override
  String get id => SiteIds.acfun;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.acfun, displayName: 'AcFun直播', homeUrl: 'https://live.acfun.cn');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('acfun directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('acfun directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('acfun search lands with its migration');
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
    // The quality list rides in the startPlay answer; one default until
    // the quality-table migration.
    return const [LivePlayQuality(label: '原画')];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final visitor = await _session();
    final deviceId = _deviceId!;
    final response = await http.send(
      LiveRequest.form(
        Uri.https('api.kuaishouzt.com', '/rest/zt/live/web/startPlay', {
          'subBiz': 'mainApp',
          'kpn': 'ACFUN_APP',
          'kpf': 'PC_WEB',
          'userId': visitor.userId,
          'did': deviceId,
          'acfun.api.visitor_st': visitor.token,
        }),
        fields: {'authorId': room.roomId, 'pullStreamType': 'FLV'},
        headers: AcfunParser.apiHeaders,
        site: id,
      ),
    );
    return AcfunParser.playLines(response.text, status: response.statusCode);
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _info(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _info(String authorId) async {
    final response = await http.send(
      LiveRequest.get(
        Uri.https('live.acfun.cn', '/api/live/info', {'authorId': authorId}),
        headers: AcfunParser.apiHeaders,
        site: id,
      ),
    );
    return AcfunParser.roomDetail(response.text, authorId: authorId, status: response.statusCode);
  }

  /// The visitor session; a refused one is replaced on the next call.
  Future<({String userId, String token})> _session() async {
    final cached = _visitor;
    if (cached != null) {
      return cached;
    }
    final deviceId = _deviceId ??= AcfunParser.deviceId();
    final response = await http.send(
      LiveRequest.form(
        Uri.https('id.app.acfun.cn', '/rest/app/visitor/login'),
        fields: const {'sid': 'acfun.api.visitor'},
        headers: {...AcfunParser.apiHeaders, 'cookie': '_did=$deviceId;'},
        site: id,
      ),
    );
    final visitor = AcfunParser.visitor(response.text, status: response.statusCode);
    return _visitor = visitor;
  }
}
