import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_parser.dart';

/// The NetEase CC adapter: the two-step guest flow (anchor lives →
/// channel) plus the h5 `video_play_url` tiers.
///
/// Not migrated yet: the category and search endpoints, the room page's
/// `__NEXT_DATA__` entry for anchors without a live channel, and the
/// danmaku capability (CC has no danmaku in 3.x either).
final class CcSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.cc;

  @override
  String get id => SiteIds.cc;

  @override
  SiteMetadata get metadata => const SiteMetadata(id: SiteIds.cc, displayName: '网易CC直播', homeUrl: 'https://cc.163.com');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('cc directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('cc directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('cc search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _freshRoom(room);
    // An anchor with no live channel: keep the stored fields, mark
    // offline.
    return room.mergeFrom(fresh ?? room.copyWith(status: LiveStatus.offline));
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final data = await _playData(room.roomId, vbrname: null, cdn: '');
    return CcParser.qualities(data);
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final channel = switch (room.data) {
      final String value when value.isNotEmpty => value,
      _ => '',
    };
    final data = await _playData(room.roomId, vbrname: quality.label, cdn: channel);
    return CcParser.playLines(data, room.roomId, cdn: channel);
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _freshRoom(room);
    if (fresh != null) {
      return room.mergeFrom(fresh);
    }
    return room.copyWith(status: LiveStatus.offline);
  }

  /// The fresh room from the lives → channel flow, or null when the
  /// anchor exists but is not broadcasting.
  Future<LiveRoom?> _freshRoom(LiveRoom room) async {
    final ccid = room.roomId.trim();
    final lives = await http.send(
      LiveRequest.get(
        Uri.https('api.cc.163.com', '/v1/activitylives/anchor/lives', {'anchor_ccid': ccid}),
        headers: CcParser.mediaHeaders(ccid),
        site: id,
      ),
    );
    final channel = CcParser.liveChannel(lives.text, ccid: ccid, status: lives.statusCode);
    if (channel == null) {
      return null;
    }
    final response = await http.send(
      LiveRequest.get(
        Uri.https('cc.163.com', '/live/channel/', {'channelids': channel}),
        headers: CcParser.mediaHeaders(ccid),
        site: id,
      ),
    );
    return CcParser.channelRoom(response.text, ccid: ccid, status: response.statusCode);
  }

  Future<Map<String, Object?>> _playData(String ccid, {required String? vbrname, required String cdn}) async {
    final response = await http.send(
      LiveRequest.get(
        Uri.https('vapi.cc.163.com', '/video_play_url/$ccid', {
          'src': 'webcc_h5',
          'vbrmode': '1',
          'use_new_vbrmap': '1',
          'secure': '1',
          'vbrname': ?vbrname,
          if (cdn.isNotEmpty) 'cdn': cdn,
        }),
        headers: CcParser.mediaHeaders(ccid),
        site: id,
      ),
    );
    return CcParser.playData(response.text, status: response.statusCode);
  }
}
