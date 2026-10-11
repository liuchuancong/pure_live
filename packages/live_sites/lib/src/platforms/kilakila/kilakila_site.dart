import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_parser.dart';

/// The KilaKila (奇秀) adapter: one getRoomInfo request per broadcast, plus
/// the two timeline listings.
///
/// Not migrated yet: search, the personal profile completion and the
/// danmaku transport.
final class KilakilaSite with SiteRoomGuard implements LiveSite, LiveAreaCatalog, LiveDirectoryCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.kilakila;

  @override
  String get id => SiteIds.kilakila;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.kilakila, displayName: '奇秀直播', homeUrl: 'https://live.kilakila.cn');

  /// The catalogue: the site's two constant timelines, so no request is
  /// spent finding them out.
  @override
  Future<List<LiveArea>> getAreas() async => KilakilaParser.areas();

  /// Page [page] of the hot timeline, which is what the site recommends.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) => _timeline(0, page);

  /// Page [page] of one timeline; an area that is not a timeline is a caller
  /// error rather than a request that cannot work.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    final type = SiteCounts.integer(area.id);
    if (!KilakilaParser.isTimeline(area.id) || type == null) {
      throw SiteError.invalidRoomId(area.id);
    }
    return _timeline(type, page);
  }

  /// Page [page] of timeline [type].
  ///
  /// The timelines repeat their anchors page after page, so a browse keeps
  /// what it has shown: an anchor listed on an earlier page of the same
  /// timeline — since its page 1 was last read — is left out, and three
  /// pages in a row without a new anchor end the listing (a caller scrolling
  /// on would otherwise see the same rooms forever). The record goes with
  /// the page: reading a page again gives the same rooms, and reading page 1
  /// again (a pull to refresh) starts over.
  Future<LivePage<LiveRoom>> _timeline(int type, int page) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    if (page > KilakilaParser.maxPages) {
      return const LivePage<LiveRoom>(items: []);
    }
    final response = await http.send(
      LiveRequest.get(
        KilakilaParser.timelineUrl(type: type, page: page),
        headers: KilakilaParser.headers,
        site: siteId,
      ),
    );
    final result = KilakilaParser.timeline(response.text, page: page, type: type, status: response.statusCode);
    if (page == 1) {
      _shown.removeWhere((key, _) => key.startsWith('$type/'));
    }
    final before = _shown['$type/$page'];
    final shown = {...?before?.anchors};
    final rooms = [
      for (final room in result.items)
        if (shown.add(room.nick)) room,
    ];
    final idle = rooms.isEmpty ? (before?.idle ?? 0) + 1 : 0;
    final hasMore = result.hasMore && idle < KilakilaParser.maxPagesWithoutNew;
    final next = '$type/${page + 1}';
    _shown.remove(next);
    if (hasMore) {
      _shown[next] = (anchors: Set.unmodifiable(shown), idle: idle);
    }
    while (_shown.length > 64) {
      _shown.remove(_shown.keys.first);
    }
    if (rooms.length == result.items.length && hasMore == result.hasMore) {
      return result;
    }
    return LivePage<LiveRoom>(
      items: rooms,
      hasMore: hasMore,
      nextPage: hasMore ? page + 1 : null,
      totalCount: result.totalCount,
    );
  }

  /// What each timeline page of a browse has shown: the anchors listed since
  /// that timeline's page 1 was read, and how many pages in a row brought
  /// nothing new.
  final Map<String, ({Set<String> anchors, int idle})> _shown = {};

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('kilakila search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _info(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final fresh = room.data == null ? await _info(room.roomId) : room;
    final lines = KilakilaParser.playLines(fresh.data);
    final labels = <String>{
      for (final line in lines)
        if (line.lineId != null) line.lineId!,
    };
    return [for (final (index, label) in labels.indexed) LivePlayQuality(label: label.toUpperCase(), sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _info(room.roomId) : room;
    final lines = KilakilaParser.playLines(fresh.data);
    final matching = lines.where((line) => line.lineId?.toUpperCase() == quality.label).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _info(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _info(String broadcastId) async {
    final response = await http.send(
      LiveRequest.get(KilakilaParser.roomInfoUrl(broadcastId), headers: KilakilaParser.headers, site: id),
    );
    return KilakilaParser.room(response.text, broadcastId: broadcastId, status: response.statusCode);
  }
}
