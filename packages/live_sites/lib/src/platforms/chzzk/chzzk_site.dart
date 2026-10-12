import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/chzzk/danmaku/chzzk_session.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_parser.dart';

/// The CHZZK (Naver) adapter: channel + live-detail flow, plus the chat.
///
/// The directory (the live list and an area's lives) and the area catalogue
/// are migrated; search is not.
final class ChzzkSite
    with SiteRoomGuard
    implements LiveSite, LiveAreaCatalog, LiveDirectoryCapability, LiveDanmakuCapability {
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

  /// The site's areas, from the first catalogue page.
  ///
  /// One request answers the areas that matter: the endpoint sorts by
  /// viewers, so the first page of
  /// [ChzzkParser.categoryPageSize] holds the areas with a real audience.
  /// Walking the cursor for the rest lands with the room-list mapping, which
  /// reads the same pages — and until then a catalogue that covers the
  /// popular areas beats one that covers none.
  @override
  Future<List<LiveArea>> getAreas() async {
    final response = await http.send(
      LiveRequest.get(
        Uri.https('api.chzzk.naver.com', '/service/v1/categories/live', ChzzkParser.categoriesQuery(const {})),
        headers: ChzzkParser.headers,
        site: siteId,
      ),
    );
    final content = ChzzkParser.content(response.text, status: response.statusCode, what: 'categories/live');
    if (content == null) {
      throw const SiteApiChangedError('chzzk categories/live: no content object');
    }
    return ChzzkParser.categoryPage(content).areas;
  }

  /// The site-wide live list, the most-watched first.
  ///
  /// The same endpoint serves an area's list when it is filtered by
  /// [LiveArea], which is what [getCategoryRooms] does. The answer carries
  /// the page size and the cursor rather than a total, so `hasMore` is the
  /// honest "a full page came back" it is elsewhere on this platform.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) => _lives(page: page);

  /// Not migrated yet, and the finding is recorded here rather than guessed
  /// at again: the live list ignores the `categoryType`/`categoryId`
  /// parameters this build sends — with them it answers the site-wide list,
  /// starting with the same room — and the filtered paths tried
  /// (`categories/live/<id>/lives`, `filterType=CATEGORY`) answer nothing at
  /// all.
  ///
  /// Since then these were tried and are known *not* to work either, so a
  /// next attempt should look elsewhere than parameter and version shapes:
  /// `categoryId` alone, `categoryType`+`categoryId`+`sortType=POPULAR`
  /// +`filterType=CATEGORY`, and the `v2`/`v3` live paths (which answer
  /// nothing at all, not even JSON). The real endpoint is somewhere else —
  /// most likely the one the site's own category page calls, which may carry
  /// a signature. A category listing that silently returns the unfiltered list is
  /// worse than one that says it is missing, because the viewer sees rooms
  /// that are not in the category they picked and has no way to tell.
  ///
  /// The area *catalogue* above is unaffected: its ids are the site's own,
  /// and [getRecommendRooms] works, which is why the directory capability is
  /// declared while this one call is not.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    throw UnimplementedError('chzzk category lives land with the category-filter migration');
  }

  Future<LivePage<LiveRoom>> _lives({required int page}) async {
    final number = page < 1 ? 1 : page;
    final response = await http.send(
      LiveRequest.get(
        Uri.https('api.chzzk.naver.com', '/service/v1/lives', {
          'size': '${ChzzkParser.categoryPageSize}',
          'page': '$number',
        }),
        headers: ChzzkParser.headers,
        site: siteId,
      ),
    );
    final content = ChzzkParser.content(response.text, status: response.statusCode, what: 'lives');
    if (content == null) {
      throw const SiteApiChangedError('chzzk lives: no content object');
    }
    final rows = SiteJson.list(content['data']).length;
    final pageInfo = SiteJson.object(content['page']);
    return ChzzkParser.lives(content, hasMore: pageInfo['next'] != null || rows >= ChzzkParser.categoryPageSize);
  }

  /// Opens the live's chat: a session keyed by the room's channel id, which
  /// is what the live-status poll names the chat channel from.
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) {
    guardRoom(room);
    return ChzzkDanmakuSession.connect(http, room.roomId);
  }

  /// Channels matching [keyword], live and offline: one request a page, [page]
  /// of `20` from offset `(page - 1) × 20`, the keyword cut to 100 characters
  /// ([ChzzkParser.searchKeyword]). A page below 1 or a blank keyword finds
  /// nothing without a request; an offset over [ChzzkParser.maxSearchOffset] is
  /// a caller error.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    if (page < 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final text = ChzzkParser.searchKeyword(keyword);
    if (text.isEmpty) {
      return const LivePage<LiveRoom>(items: []);
    }
    final offset = (page - 1) * ChzzkParser.searchPageSize;
    if (offset > ChzzkParser.maxSearchOffset) {
      throw RangeError.range(offset, 0, ChzzkParser.maxSearchOffset, 'offset');
    }
    final response = await http.send(
      LiveRequest.get(
        Uri.https('api.chzzk.naver.com', '/service/v1/search/channels', {
          'keyword': text,
          'offset': '$offset',
          'size': '${ChzzkParser.searchPageSize}',
        }),
        headers: ChzzkParser.headers,
        site: siteId,
      ),
    );
    final rooms = ChzzkParser.searchRooms(response.text, status: response.statusCode);
    final hasMore = rooms.length >= ChzzkParser.searchPageSize;
    return LivePage(items: rooms, hasMore: hasMore, nextPage: hasMore ? page + 1 : null);
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
