import 'dart:math';

import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_parser.dart';

/// The Baidu Live adapter: rooms through the searchbox 371 room command.
///
/// Not migrated yet: the feed (directory), search, replay variants and
/// the danmaku session (the message-list playlist is signed). One
/// request serves both detail and play — the room command carries the
/// video URLs, so play reuses the last answer.
final class BaiduLiveSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  late final String _deviceId = _newDeviceId();

  String? _lastBody;
  String? _lastRoomId;

  @override
  String get siteId => SiteIds.baiduLive;

  @override
  String get id => SiteIds.baiduLive;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.baiduLive, displayName: '百度直播', homeUrl: 'https://live.baidu.com');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('baidulive feed lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('baidulive feed lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('baidulive search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _fetch(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final body = await _bodyFor(room.roomId);
    final lines = BaiduLiveParser.playLines(body, roomId: room.roomId);
    final heights = <int>{
      for (final line in lines)
        if (line.height != null) line.height!,
    };
    return [
      for (final (index, height) in (heights.toList()..sort((a, b) => b.compareTo(a))).indexed)
        LivePlayQuality(label: '${height}P', sort: -index),
    ];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final body = await _bodyFor(room.roomId);
    final lines = BaiduLiveParser.playLines(body, roomId: room.roomId);
    final height = int.tryParse(quality.label.replaceAll('P', ''));
    if (height == null) {
      return lines;
    }
    return lines.where((line) => line.height == height).toList();
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _fetch(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _fetch(String roomId) async {
    final body = await _bodyFor(roomId);
    return BaiduLiveParser.room(body, roomId: roomId);
  }

  /// The room command body, memoised per room so play does not re-request
  /// what the detail just fetched.
  Future<String> _bodyFor(String roomId) async {
    if (_lastRoomId == roomId && _lastBody != null) {
      return _lastBody!;
    }
    final response = await http.send(
      LiveRequest.get(
        Uri.https('mbd.baidu.com', '/searchbox', BaiduLiveParser.roomQuery(roomId, deviceId: _deviceId)),
        headers: BaiduLiveParser.apiHeaders,
        site: id,
      ),
    );
    _lastRoomId = roomId;
    return _lastBody = response.text;
  }

  static String _newDeviceId() {
    final random = Random.secure();
    return 'pc-${[for (var i = 0; i < 12; i++) random.nextInt(36).toRadixString(36)].join()}baidulive';
  }
}
