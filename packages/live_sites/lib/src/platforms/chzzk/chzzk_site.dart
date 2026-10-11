import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_parser.dart';

/// The CHZZK (Naver) adapter: channel + live-detail flow.
///
/// Not migrated yet: directory, search and the chat WebSocket.
final class ChzzkSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.chzzk;

  @override
  String get id => SiteIds.chzzk;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.chzzk, displayName: 'CHZZK', homeUrl: 'https://chzzk.naver.com');

  /// Not migrated yet, and the shape is recorded here so the next round does
  /// not re-derive it: CHZZK's directory is a *paged cursor* API
  /// (`/service/v1/categories/live` with a `next` cursor) whose areas carry a
  /// category type, so the catalogue needs a page walk, a type-name map and
  /// the area-id validation the site's own paths require (one real id even
  /// contains `&`). The room list reads the same pages, which is why both
  /// land together rather than one before the other.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) {
    throw UnimplementedError('chzzk directory lands with the category-paging migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('chzzk directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('chzzk search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final (owner, live) = await _read(room.roomId);
    return room.mergeFrom(ChzzkParser.room(owner, live));
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final (owner, live) = await _read(room.roomId);
    final lines = ChzzkParser.playLines(live.live ? live.masters : room.data, owner.id);
    final labels = <String>{
      for (final line in lines)
        if (line.lineId != null) line.lineId!,
    };
    return [for (final (index, label) in labels.indexed) LivePlayQuality(label: label, sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final (owner, live) = await _read(room.roomId);
    final lines = ChzzkParser.playLines(live.live ? live.masters : room.data, owner.id);
    final matching = lines.where((line) => line.lineId == quality.label).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final (owner, live) = await _read(room.roomId);
    return room.mergeFrom(ChzzkParser.room(owner, live));
  }

  /// The channel and its live-detail.
  Future<
    (
      ({String id, String name, String? avatar, int? followers, bool openLive}),
      ({bool live, String title, String? cover, int? watching, DateTime? startedAt, List<String> masters}),
    )
  >
  _read(String roomId) async {
    final id = roomId.trim();
    if (!ChzzkParser.isChannelId(id)) {
      throw SiteNotFoundError('chzzk: "$id" is not a channel id');
    }
    final channelResponse = await http.send(
      LiveRequest.get(
        Uri.https(ChzzkParser.apiHost, '/service/v1/channels/$id'),
        headers: ChzzkParser.headers,
        site: this.id,
      ),
    );
    final owner = ChzzkParser.channel(channelResponse.text, channelId: id, status: channelResponse.statusCode);
    final liveResponse = await http.send(
      LiveRequest.get(
        Uri.https(ChzzkParser.apiHost, '/service/v3.1/channels/$id/live-detail'),
        headers: ChzzkParser.headers,
        site: this.id,
      ),
    );
    final live = ChzzkParser.liveDetail(liveResponse.text, channelId: id, status: liveResponse.statusCode);
    return (owner, live);
  }
}
