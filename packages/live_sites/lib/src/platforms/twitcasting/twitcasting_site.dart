import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/twitcasting/danmaku/twitcasting_session.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_parser.dart';

/// The TwitCasting adapter: channel page + streamserver flow.
///
/// Only `movie.live` is authoritative for on-air state. A password
/// (secret-word) broadcast shows as live with the password restriction.
/// The comment stream is the broadcast's event socket, whose URL the site
/// hands out per broadcast with a signature that lasts about an hour.
///
/// Not migrated yet: directory and search.
final class TwitcastingSite with SiteRoomGuard implements LiveSite, LiveDanmakuCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.twitcasting;

  @override
  String get id => SiteIds.twitcasting;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.twitcasting, displayName: 'TwitCasting', homeUrl: 'https://twitcasting.tv');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('twitcasting directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('twitcasting directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('twitcasting search lands with its migration');
  }

  /// Opens the broadcast's comment stream.
  ///
  /// The socket URL belongs to one broadcast, so it is fetched here rather
  /// than cached: a session opened after the streamer restarted subscribes
  /// to the new broadcast. A room that is not on air has no movie id at all,
  /// which is reported as "no danmaku" instead of an attempt to guess one.
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final movieId = await _movieId(room);
    if (movieId == null) {
      throw SiteNotFoundError('twitcasting ${room.roomId}: not on air, no comment stream');
    }
    return await TwitcastingDanmakuSession.connect(movieId, http);
  }

  /// The broadcast's movie id, read the same way the play-lines path reads
  /// it — from the stream server answer, which names the live broadcast.
  Future<int?> _movieId(LiveRoom room) async {
    final stream = await _stream(_channel(room.roomId));
    return stream.live ? stream.movieId : null;
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final channel = _channel(room.roomId);
    final pageResponse = await http.send(
      LiveRequest.get(Uri.https('twitcasting.tv', '/$channel'), headers: TwitcastingParser.headers, site: id),
    );
    final page = TwitcastingParser.channelPage(
      pageResponse.text,
      roomId: room.roomId,
      channel: channel,
      status: pageResponse.statusCode,
    );
    final stream = await _stream(channel);
    if (!stream.live) {
      return room.mergeFrom(page.room.copyWith(status: LiveStatus.offline));
    }
    final sameBroadcast = page.movieId == null || stream.movieId == null || page.movieId == stream.movieId;
    var merged = page.room.copyWith(status: LiveStatus.live, data: stream);
    if (sameBroadcast && page.liveStartedAt != null) {
      merged = merged.copyWith(startedAt: page.liveStartedAt);
    }
    if (page.secretWord) {
      merged = merged.copyWith(restriction: LiveRestriction.needsLogin);
    }
    return room.mergeFrom(merged);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final stream = await _streamData(room);
    final lines = TwitcastingParser.playLines(stream, _channel(room.roomId));
    final labels = <String>{
      for (final line in lines)
        if (line.lineId != null) line.lineId!,
    };
    return [for (final (index, label) in labels.indexed) LivePlayQuality(label: label, sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final stream = await _streamData(room);
    final lines = TwitcastingParser.playLines(stream, _channel(room.roomId));
    final matching = lines.where((line) => line.lineId == quality.label).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final stream = await _stream(_channel(room.roomId));
    return room.mergeFrom(
      LiveRoom(
        platform: SiteIds.twitcasting,
        roomId: room.roomId,
        status: stream.live ? LiveStatus.live : LiveStatus.offline,
        data: stream,
      ),
    );
  }

  /// The stream data, reusing the one cached in the room.
  Future<({bool live, int? movieId, Map<String, String> streams})> _streamData(LiveRoom room) async {
    final data = room.data;
    if (data is ({bool live, int? movieId, Map<String, String> streams})) {
      return data;
    }
    final stream = await _stream(_channel(room.roomId));
    return stream;
  }

  Future<({bool live, int? movieId, Map<String, String> streams})> _stream(String channel) async {
    final response = await http.send(
      LiveRequest.get(
        Uri.https('twitcasting.tv', '/streamserver.php', {'target': channel, 'mode': 'client', 'player': 'pc_web'}),
        headers: TwitcastingParser.headers,
        site: id,
      ),
    );
    return TwitcastingParser.streamServer(response.text, status: response.statusCode);
  }

  String _channel(String roomId) {
    final channel = TwitcastingParser.channelName(roomId);
    if (channel == null) {
      throw SiteNotFoundError('twitcasting: "${roomId.trim()}" is not a channel');
    }
    return channel;
  }
}
