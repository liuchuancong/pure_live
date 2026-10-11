import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_parser.dart';

/// The JD Live adapter: rooms through the h5 `getImmediatePlayToM` play
/// answer.
///
/// Not migrated yet: the featured list (`liveListWithTabToM`), search,
/// the playlist validation pass and the danmaku transport.
final class JdLiveSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  /// The last card of each broadcast, filling empty display fields of
  /// later play answers.
  final Map<String, Map<String, Object?>> _known = {};
  String? _lastBody;
  String? _lastLiveId;

  @override
  String get siteId => SiteIds.jdLive;

  @override
  String get id => SiteIds.jdLive;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.jdLive, displayName: '京东直播', homeUrl: 'https://m.jd.com/live');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('jdlive directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('jdlive directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('jdlive search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final liveId = _numeric(room.roomId);
    final data = await _play(liveId);
    final fresh = JdLiveParser.room(data, liveId: liveId, known: _known[liveId]);
    _known[liveId] = data;
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final liveId = _numeric(room.roomId);
    final data = await _play(liveId);
    final status = JdLiveParser.statusOf(data['status']);
    final qualities = <LivePlayQuality>[];
    if (status == LiveStatus.live) {
      if (_has(data['h5VideoUrl'], '.m3u8')) {
        qualities.add(const LivePlayQuality(label: 'HLS'));
      }
      if (_has(data['videoUrl'], '.flv') || _has(data['pcVideoUrl'], '.flv')) {
        qualities.add(const LivePlayQuality(label: 'FLV', sort: 0));
      }
    } else if (status == LiveStatus.replay) {
      qualities.add(const LivePlayQuality(label: '原画'));
    }
    return qualities;
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final liveId = _numeric(room.roomId);
    final data = await _play(liveId);
    final status = JdLiveParser.statusOf(data['status']);
    final lines = JdLiveParser.playLines(data, liveId, status: status);
    if (quality.label == 'HLS') {
      final hls = lines.where((line) => line.format == StreamFormat.hls).toList();
      return hls.isEmpty ? lines : hls;
    }
    if (quality.label == 'FLV') {
      final flv = lines.where((line) => line.format == StreamFormat.flv).toList();
      return flv.isEmpty ? lines : flv;
    }
    return lines;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final liveId = _numeric(room.roomId);
    final data = await _play(liveId);
    return room.mergeFrom(JdLiveParser.room(data, liveId: liveId, known: _known[liveId]));
  }

  Future<Map<String, Object?>> _play(String liveId) async {
    if (_lastLiveId == liveId && _lastBody != null) {
      return JdLiveParser.data(_lastBody!, what: 'getImmediatePlayToM');
    }
    final response = await http.send(
      LiveRequest.get(
        JdLiveParser.playUrl(liveId, now: DateTime.now()),
        headers: JdLiveParser.mediaHeaders(liveId),
        site: id,
      ),
    );
    _lastLiveId = liveId;
    _lastBody = response.text;
    return JdLiveParser.data(response.text, status: response.statusCode, what: 'getImmediatePlayToM');
  }

  String _numeric(String roomId) {
    final liveId = JdLiveParser.liveIdOf(roomId);
    if (liveId == null) {
      throw SiteNotFoundError('jdlive: "${roomId.trim()}" is not a broadcast id');
    }
    return liveId;
  }

  static bool _has(Object? value, String suffix) => (value?.toString() ?? '').contains(suffix);
}
