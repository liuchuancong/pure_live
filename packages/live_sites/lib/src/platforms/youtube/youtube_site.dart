import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_parser.dart';

/// The YouTube adapter: the ANDROID InnerTube player flow (anonymous HLS
/// manifest, no browser proofs needed).
///
/// Not migrated yet: the watch page's API key discovery (the public
/// fallback key is used), directory, search and the live chat.
final class YouTubeSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http, this.apiKey = YouTubeParser.fallbackApiKey});

  /// The HTTP transport.
  final LiveHttp http;

  /// The InnerTube API key (the public fallback unless the shell provides
  /// a fresher one from a watch page).
  final String apiKey;

  @override
  String get siteId => SiteIds.youtube;

  @override
  String get id => SiteIds.youtube;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.youtube, displayName: 'YouTube Live', homeUrl: 'https://www.youtube.com');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('youtube directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('youtube directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('youtube search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _player(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    return const [LivePlayQuality(label: 'auto')];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _player(room.roomId) : room;
    return YouTubeParser.playLines(fresh.data, room.roomId);
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _player(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _player(String videoId) async {
    final id = YouTubeParser.normalizeVideoId(videoId);
    if (id == null) {
      throw SiteNotFoundError('youtube: "$videoId" is not a video id');
    }
    final response = await http.send(
      LiveRequest.json(
        YouTubeParser.playerUrl(apiKey),
        body: YouTubeParser.playerBody(id),
        headers: YouTubeParser.playerHeaders(id),
        site: this.id,
      ),
    );
    return YouTubeParser.video(response.text, videoId: id, status: response.statusCode);
  }
}
