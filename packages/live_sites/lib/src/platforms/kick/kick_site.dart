import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/kick/danmaku/kick_danmaku.dart';
import 'package:live_sites/src/platforms/kick/danmaku/kick_session.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_parser.dart';

/// The Kick adapter: one channel request per room (the answer carries the
/// stream and the signed IVS master), the two-level category directory and
/// the live-broadcast lists, and the Pusher chat WebSocket.
///
/// Not migrated yet: nothing but the deeper replay paths.
final class KickSite
    with SiteRoomGuard
    implements LiveSite, LiveDanmakuCapability, LiveAreaCatalog, LiveDirectoryCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.kick;

  @override
  String get id => SiteIds.kick;

  @override
  SiteMetadata get metadata => const SiteMetadata(id: SiteIds.kick, displayName: 'Kick', homeUrl: 'https://kick.com');

  /// The catalogue: Kick's top-level categories, each fanned out into its most
  /// watched subcategories, returned as the selectable leaf areas (each under
  /// its parent). A category whose subcategories fail is left out; when all
  /// fail, the first failure is thrown.
  @override
  Future<List<LiveArea>> getAreas() async {
    final response = await http.send(
      LiveRequest.get(KickParser.categoriesUrl(), headers: KickParser.headers, site: siteId),
    );
    final parents = KickParser.mainCategories(response.text, status: response.statusCode);
    final results = await Future.wait([
      for (final parent in parents) _subareas(parent).then<Object>((areas) => areas, onError: (Object error) => error),
    ]);
    final areas = <LiveArea>[];
    Object? failure;
    for (final result in results) {
      if (result is List<LiveArea>) {
        areas.addAll(result);
      } else {
        failure ??= result;
      }
    }
    if (areas.isEmpty && failure != null) {
      if (failure is SiteError) {
        throw failure;
      }
      throw SiteApiChangedError('kick categories: $failure');
    }
    return areas;
  }

  Future<List<LiveArea>> _subareas(({String slug, String name}) parent) async {
    final response = await http.send(
      LiveRequest.get(KickParser.subcategoriesUrl(parent.slug), headers: KickParser.headers, site: siteId),
    );
    return KickParser.subcategories(
      response.text,
      parentSlug: parent.slug,
      parentName: parent.name,
      status: response.statusCode,
    );
  }

  /// Page [page] of all of Kick's live broadcasts, by viewers.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) => _livestreams(page: page);

  /// Page [page] of one subcategory's live broadcasts; an area that is not a
  /// subcategory slug is a caller error rather than a request that cannot
  /// work.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    final slug = area.id.trim();
    if (!KickParser.isSubcategory(slug)) {
      throw SiteError.invalidRoomId(area.id);
    }
    return _livestreams(page: page, subcategory: slug);
  }

  Future<LivePage<LiveRoom>> _livestreams({required int page, String? subcategory}) async {
    const size = KickParser.pageSize;
    final number = page < 1 ? 1 : page;
    final response = await http.send(
      LiveRequest.get(
        KickParser.livestreamsUrl(page: number, pageSize: size, subcategory: subcategory),
        headers: KickParser.headers,
        site: siteId,
      ),
    );
    return KickParser.directoryPage(
      response.text,
      page: number,
      pageSize: size,
      subcategory: subcategory,
      status: response.statusCode,
    );
  }

  /// Channels matching [keyword] (its first fifty characters), live or not,
  /// then the broadcasts tagged with it. Kick's search is one page, so a later
  /// page or a blank keyword gives nothing without a request.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    final text = keyword.trim();
    if (text.isEmpty || page > 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final response = await http.send(
      LiveRequest.get(KickParser.searchUrl(text), headers: KickParser.headers, site: siteId),
    );
    return LivePage<LiveRoom>(items: KickParser.search(response.text, status: response.statusCode));
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _channel(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    return const [LivePlayQuality(label: 'master')];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _channel(room.roomId) : room;
    return KickParser.playLines(fresh.data, room.roomId);
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _channel(room.roomId);
    return room.mergeFrom(fresh);
  }

  /// Opens the Pusher chat for [room].
  ///
  /// The chatroom and channel ids come from the channel answer and are
  /// re-read on every connect (not cached). There is no subscribing to a
  /// guessed chatroom, so a channel the answer gives no chatroom id for ends
  /// with a [SiteNotFoundError] rather than a socket on the wrong room.
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final data = (await _channel(room.roomId)).data;
    final channelId = data is Map<String, Object?> ? _asInt(data['channelId']) : null;
    final chatroomId = data is Map<String, Object?> ? _asInt(data['chatroomId']) : null;
    final args = KickDanmakuProtocol.checked(
      KickDanmakuArgs(chatroomId: chatroomId ?? 0, channelId: channelId ?? 0, slug: room.roomId),
    );
    if (args == null) {
      throw SiteNotFoundError('kick ${room.roomId}: no chatroom to subscribe to');
    }
    return await KickDanmakuSession.connect(args);
  }

  static int? _asInt(Object? value) => value is int ? value : int.tryParse('$value');

  Future<LiveRoom> _channel(String roomId) async {
    final slug = KickParser.normalizeSlug(roomId);
    if (slug == null) {
      throw SiteNotFoundError('kick: "${roomId.trim()}" is not a channel');
    }
    final response = await http.send(
      LiveRequest.get(KickParser.channelUrl(slug), headers: KickParser.headers, site: id),
    );
    return KickParser.room(response.text, requestedSlug: slug, status: response.statusCode);
  }
}
