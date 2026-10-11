import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_parser.dart';

/// The Bigo Live adapter: the token → studio flow (the studio API needs a
/// signed anonymous web token).
///
/// Not migrated yet: directory, search, the password/paid detail and the
/// danmaku transport.
final class BigoSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  /// The last web token, reused for refreshes.
  String? _token;

  @override
  String get siteId => SiteIds.bigo;

  @override
  String get id => SiteIds.bigo;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.bigo, displayName: 'Bigo Live', homeUrl: 'https://www.bigo.tv');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('bigo directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('bigo directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('bigo search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final studio = await _studio(room.roomId);
    return room.mergeFrom(BigoParser.room(studio));
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    return const [LivePlayQuality(label: '原画')];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final studio = await _studio(room.roomId);
    final hls = studio.hls;
    if (hls == null) {
      throw SiteNotFoundError('bigo ${room.roomId}: no playlist');
    }
    return [BigoParser.line(hls, studio.siteId)];
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final studio = await _studio(room.roomId);
    return room.mergeFrom(BigoParser.room(studio));
  }

  /// The studio of [siteId] with the token chain (server time → token →
  /// studio), the token reused for one refresh.
  Future<
    ({
      String siteId,
      bool alive,
      bool needsLogin,
      bool restricted,
      String? title,
      String? nick,
      String? avatar,
      String? cover,
      String? area,
      String? hls,
    })
  >
  _studio(String siteId) async {
    final token = _token ?? await _fetchToken();
    final response = await http.send(
      LiveRequest.custom(
        url: Uri.https(BigoParser.apiHost, '/official_website/studio/getInternalStudioInfo', {
          'siteId': siteId,
          'verify': '',
          'token': token,
        }),
        method: 'POST',
        body: '',
        headers: BigoParser.headers,
        site: id,
      ),
    );
    return BigoParser.studio(response.text, requestedSiteId: siteId, status: response.statusCode);
  }

  /// A fresh anonymous token: server time, then the keyed status call.
  Future<String> _fetchToken() async {
    final timeCallback = BigoParser.callback();
    final time = await http.send(
      LiveRequest.get(
        Uri.https(BigoParser.tokenHost, '/v1/webjs/t', {'callback': timeCallback}),
        headers: BigoParser.headers,
        site: id,
      ),
    );
    final timestamp = BigoParser.serverTime(time.text, callback: timeCallback, status: time.statusCode);
    final statusCallback = BigoParser.callback();
    final status = await http.send(
      LiveRequest.get(
        Uri.https(BigoParser.tokenHost, '/v1/webjs/status', {
          'callback': statusCallback,
          'data': await BigoParser.tokenData(timestamp),
        }),
        headers: BigoParser.headers,
        site: id,
      ),
    );
    return _token = BigoParser.token(status.text, callback: statusCallback, status: status.statusCode);
  }
}
