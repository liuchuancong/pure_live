import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_parser.dart';

/// The YY adapter: liveInfoDetail room flow plus the stream-manager play
/// answer.
///
/// Not migrated yet: directory pages (they render as HTML card lists),
/// search, the full stream-manager quality table, and the danmaku
/// transport (YY speaks its own binary packet framing).
final class YySite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  static const String _host = 'www.yy.com';
  static const String _streamManager = 'stream-manager.yy.com';

  @override
  String get siteId => SiteIds.yy;

  @override
  String get id => SiteIds.yy;

  @override
  SiteMetadata get metadata => const SiteMetadata(id: SiteIds.yy, displayName: 'YY直播', homeUrl: 'https://www.yy.com');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('yy directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('yy directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('yy search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _freshRoom(room.roomId);
    if (fresh != null) {
      return room.mergeFrom(fresh);
    }
    // The live detail says the channel is not streaming; fall back to the
    // room page for the sid mapping and report offline.
    final page = await _roomPage(room.roomId);
    return YyParser.offlineRoom(room.roomId, sid: page.sid, ssid: page.ssid);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    throw UnimplementedError('yy stream-manager quality table lands with its migration');
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final (:sid, :ssid) = await _channelOf(room);
    final sequence = DateTime.now().millisecondsSinceEpoch;
    final response = await http.send(
      LiveRequest.custom(
        url: Uri.https(_streamManager, '/v3/channel/streams', {
          'uid': '0',
          'cid': sid,
          'sid': ssid,
          'appid': '0',
          'sequence': '$sequence',
          'encode': 'json',
        }),
        method: 'POST',
        headers: {'content-type': 'application/json', 'referer': 'https://www.yy.com/$room.roomId'},
        body: jsonEncode({
          'head': {
            'seq': sequence,
            'appidstr': '0',
            'bidstr': '121',
            'cidstr': sid,
            'sidstr': ssid,
            'uid64': 0,
            'client_type': 108,
            'client_ver': '1.0.0',
            'stream_sys_ver': 1,
            'app': 'yylive_web',
            'playersdk_ver': '1.0.0',
            'thundersdk_ver': '0',
            'streamsdk_ver': '1.0.0',
          },
          'client_attribute': {
            'client': 'web',
            'model': 'web0',
            'cpu': '',
            'graphics_card': '',
            'os': 'chrome',
            'osversion': '128.0.0.0',
            'vsdk_version': '',
            'app_identify': '',
            'app_version': '',
            'business': '',
            'width': '1366',
            'height': '768',
            'scale': '',
            'client_type': 8,
            'h265': 0,
          },
          'avp_parameter': {
            'version': 1,
            'client_type': 8,
            'service_type': 0,
            'imsi': 0,
            'send_time': sequence ~/ 1000,
            'line_seq': -1,
            'gear': 0,
            'ssl': 1,
            'stream_format': 0,
          },
        }),
        site: id,
      ),
    );
    final root = YyParser.checked(response.text, status: response.statusCode, what: 'stream-manager');
    return YyParser.playLines(root);
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _freshRoom(room.roomId);
    if (fresh != null) {
      return room.mergeFrom(fresh);
    }
    return room.copyWith(status: LiveStatus.offline);
  }

  /// The live room from liveInfoDetail, or null when not streaming.
  Future<LiveRoom?> _freshRoom(String roomId) async {
    final sid = roomId;
    final response = await http.send(
      LiveRequest.get(
        Uri.https(_host, '/api/liveInfoDetail/$sid/$sid/0'),
        headers: {
          'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
          'referer': 'https://www.yy.com/$roomId',
        },
        site: id,
      ),
    );
    return YyParser.liveDetail(response.text, requestedId: roomId, status: response.statusCode);
  }

  Future<({String sid, String ssid})> _channelOf(LiveRoom room) async {
    final data = room.data;
    if (data is Map<String, Object?>) {
      final sid = YyParser.channel(data['sid']);
      final ssid = YyParser.channel(data['ssid']);
      if (sid != null && ssid != null) {
        return (sid: sid, ssid: ssid);
      }
    }
    final page = await _roomPage(room.roomId);
    return (sid: page.sid, ssid: page.ssid);
  }

  Future<({String sid, String ssid, String? nick, String? title})> _roomPage(String roomId) async {
    final response = await http.send(
      LiveRequest.get(
        Uri.https(_host, '/$roomId'),
        headers: const {
          'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        },
        site: id,
      ),
    );
    return YyParser.roomPage(response.text);
  }
}
