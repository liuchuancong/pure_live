import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_parser.dart';

/// The Inke adapter: live_share_pc rooms enriched by the app's
/// now_publish broadcast (who carries the signed pull URLs), plus the
/// website's showcases and the app's hot list.
///
/// Not migrated yet: search, the Zego original-quality line as a separate
/// quality, the showcase URL lookup fallback and the danmaku transport.
final class InkeSite with SiteRoomGuard implements LiveSite, LiveAreaCatalog, LiveDirectoryCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.inke;

  @override
  String get id => SiteIds.inke;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.inke, displayName: '映客直播', homeUrl: 'https://www.inke.cn');

  /// The catalogue: the website's top list and its channels, read from the
  /// one answer that also carries their rooms.
  @override
  Future<List<LiveArea>> getAreas() async {
    final response = await http.send(
      LiveRequest.get(InkeParser.channelListUrl(), headers: InkeParser.headers, site: siteId),
    );
    return InkeParser.areas(response.text, status: response.statusCode);
  }

  /// The app's hot list — about twenty broadcasts, different at every call —
  /// which is what the site recommends; it is one page, so a later page is
  /// empty without a request.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    if (page > 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final response = await http.send(LiveRequest.get(InkeParser.hotUrl(), headers: InkeParser.headers, site: siteId));
    return LivePage<LiveRoom>(items: InkeParser.hotRooms(response.text, status: response.statusCode));
  }

  /// The rooms of one showcase, one page: the top list for its own area,
  /// else the channel's rows of the website's channel list. A channel the
  /// site has retired is not found rather than empty.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    if (page > 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final key = area.id.trim();
    if (key == InkeParser.topAreaId) {
      final response = await http.send(LiveRequest.get(InkeParser.topUrl(), headers: InkeParser.headers, site: siteId));
      return LivePage<LiveRoom>(items: InkeParser.topRooms(response.text, status: response.statusCode));
    }
    if (!RegExp(r'^[A-Za-z0-9_]{1,64}$').hasMatch(key)) {
      throw SiteError.invalidRoomId(area.id);
    }
    final response = await http.send(
      LiveRequest.get(InkeParser.channelListUrl(), headers: InkeParser.headers, site: siteId),
    );
    final rooms = InkeParser.channelRooms(response.text, tabKey: key, status: response.statusCode);
    if (rooms == null) {
      throw SiteNotFoundError('inke: the site no longer has the channel $key');
    }
    return LivePage<LiveRoom>(items: rooms);
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('inke search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final uid = _uid(room.roomId);
    final fresh = await _share(uid);
    if (fresh.status != LiveStatus.live && fresh.data == null) {
      return room.mergeFrom(fresh);
    }
    // The app's answer carries the audience, cover and start time.
    final broadcast = await _broadcast(uid);
    if (broadcast == null) {
      return room.mergeFrom(fresh);
    }
    var merged = fresh;
    if (broadcast.cover != null) merged = merged.copyWith(cover: broadcast.cover);
    if (broadcast.watching != null) merged = merged.copyWith(watching: broadcast.watching);
    if (broadcast.startedAt != null) merged = merged.copyWith(startedAt: broadcast.startedAt);
    merged = merged.copyWith(data: {...?fresh.data as Map<String, Object?>?, 'broadcast': broadcast.lines});
    return room.mergeFrom(merged);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final broadcast = await _broadcast(_uid(room.roomId));
    if (broadcast == null || broadcast.lines.isEmpty) {
      throw SiteNotFoundError('inke ${room.roomId}: not live');
    }
    return [
      for (final (index, line) in broadcast.lines.indexed)
        LivePlayQuality(label: line.lineId == 'original' ? '原画' : 'HLS', sort: -index),
    ];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final broadcast = await _broadcast(_uid(room.roomId));
    if (broadcast == null || broadcast.lines.isEmpty) {
      throw SiteNotFoundError('inke ${room.roomId}: not live');
    }
    final wantOriginal = quality.label == '原画';
    final matching = broadcast.lines.where((line) => (line.lineId == 'original') == wantOriginal).toList();
    return matching.isEmpty ? broadcast.lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _share(_uid(room.roomId));
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _share(String uid) async {
    final response = await http.send(LiveRequest.get(InkeParser.shareUrl(uid), headers: InkeParser.headers, site: id));
    return InkeParser.room(response.text, uid: uid, status: response.statusCode)!;
  }

  Future<({List<LivePlayLine> lines, String? cover, int? watching, DateTime? startedAt})?> _broadcast(
    String uid,
  ) async {
    final response = await http.send(
      LiveRequest.get(InkeParser.publishUrl(uid), headers: InkeParser.headers, site: id),
    );
    return InkeParser.broadcast(response.text, uid: uid, status: response.statusCode);
  }

  String _uid(String roomId) {
    if (!InkeParser.isUid(roomId)) {
      throw SiteNotFoundError('inke: "${roomId.trim()}" is not a uid');
    }
    return roomId.trim();
  }
}
