import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_parser.dart';

/// The CHZZK (Naver) adapter: channel + live-detail flow.
///
/// The directory (the live list and an area's lives) and the area catalogue
/// are migrated; search and the chat WebSocket are not.
final class ChzzkSite with SiteRoomGuard implements LiveSite, LiveAreaCatalog, LiveDirectoryCapability {
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
  /// all. A category listing that silently returns the unfiltered list is
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
