import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/youtube/danmaku/youtube_danmaku.dart';
import 'package:live_sites/src/platforms/youtube/danmaku/youtube_session.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_parser.dart';

/// The YouTube adapter: the ANDROID InnerTube player flow (anonymous HLS
/// manifest, no browser proofs needed), the WEB InnerTube live tab (`browse`)
/// and live search, and the live chat.
///
/// Not migrated yet: the watch page's API key discovery (the public fallback key
/// is used). Directory and search return the first answer's live rooms (keyed by
/// video id); the InnerTube continuation paging and the channel-id identity of
/// the reference are not ported. The chat ([connect]) is the WEB InnerTube poll
/// ([YouTubeDanmakuSession]); the room id is the broadcast's video id.
final class YouTubeSite with SiteRoomGuard implements LiveSite, LiveDanmakuCapability {
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

  /// Page 1 of the site's "Live" tab (`browse` of the live destination). The
  /// first answer's live rooms are returned whole; [page] past 1 is empty.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    if (page != 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final response = await http.send(
      LiveRequest.json(
        YouTubeParser.apiUrl('browse'),
        body: YouTubeParser.browseBody(),
        headers: YouTubeParser.apiHeaders,
        site: id,
      ),
    );
    return YouTubeParser.listing(response.text, search: false, status: response.statusCode);
  }

  /// There is no area catalogue: every area's listing is the live tab.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    if (page != 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final response = await http.send(
      LiveRequest.json(
        YouTubeParser.apiUrl('browse'),
        body: YouTubeParser.browseBody(),
        headers: YouTubeParser.apiHeaders,
        site: id,
      ),
    );
    return YouTubeParser.listing(response.text, search: false, status: response.statusCode);
  }

  /// A live search of [keyword]: the first page's live rooms. A blank keyword
  /// or a page past 1 finds nothing.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    final text = keyword.trim();
    if (text.isEmpty || page != 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final response = await http.send(
      LiveRequest.json(
        YouTubeParser.apiUrl('search'),
        body: YouTubeParser.searchBody(text),
        headers: YouTubeParser.apiHeaders,
        site: id,
      ),
    );
    return YouTubeParser.listing(response.text, search: true, status: response.statusCode);
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

  /// The broadcast's live chat: the room id is the video id, polled by
  /// [YouTubeDanmakuSession.connect] (join failures surface on the message
  /// stream, which the caller's supervisor reconnects).
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) =>
      YouTubeDanmakuSession.connect(http, YouTubeDanmakuArgs(room.roomId));
}
