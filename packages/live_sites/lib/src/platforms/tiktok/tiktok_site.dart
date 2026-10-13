import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_parser.dart';

/// The TikTok adapter: the user/room flow (the answer carries the room
/// state and its stream tiers).
///
/// TikTok has no anonymous directory: [getRecommendRooms] is empty and
/// [getCategoryRooms] is a caller error, exactly as 3.x refused it. Search
/// resolves a username or `@name` link; not migrated yet: the `share/live` and
/// short-link resolution (through room-info/redirect) and the danmaku
/// transport.
final class TikTokSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.tiktok;

  @override
  String get id => SiteIds.tiktok;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.tiktok, displayName: 'TikTok Live', homeUrl: 'https://www.tiktok.com/live');

  /// Always empty: no public directory is reachable anonymously, and nothing
  /// is requested. A page below one is a caller error, as 3.x refused it.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    return const LivePage<LiveRoom>(items: []);
  }

  /// TikTok has no categories, so any area is a caller error refused before a
  /// request — a category listing that returned the unfiltered list would be
  /// worse than one that says there is none.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    throw SiteError.invalidRoomId(area.id);
  }

  /// The one room [keyword] names: a username, an `@name` or a
  /// `tiktok.com/@name` link (page 1 only); anything else — a `share/live`
  /// room or a short link, which resolve through the owner/redirect path —
  /// gives nothing. TikTok has no keyword search.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    if (page != 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final username = TikTokParser.usernameFrom(keyword);
    if (username == null) {
      return const LivePage<LiveRoom>(items: []);
    }
    try {
      return LivePage<LiveRoom>(items: [await _room(username)]);
    } on SiteNotFoundError {
      return const LivePage<LiveRoom>(items: []);
    }
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _room(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final fresh = room.data == null ? await _room(room.roomId) : room;
    final lines = TikTokParser.playLines(fresh.data, room.roomId);
    final labels = <String>{
      for (final line in lines)
        if (line.lineId != null) line.lineId!,
    };
    return [for (final (index, label) in labels.indexed) LivePlayQuality(label: label, sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _room(room.roomId) : room;
    final lines = TikTokParser.playLines(fresh.data, room.roomId);
    final matching = lines.where((line) => line.lineId == quality.label).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _room(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _room(String roomId) async {
    final username = TikTokParser.normalizeUsername(roomId);
    if (username == null) {
      throw SiteNotFoundError('tiktok: "$roomId" is not a username');
    }
    final response = await http.send(
      LiveRequest.get(
        TikTokParser.userRoomUrl(username),
        headers: TikTokParser.headers(username: username),
        site: id,
      ),
    );
    return TikTokParser.room(response.text, username: username, status: response.statusCode);
  }
}
