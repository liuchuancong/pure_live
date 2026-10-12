import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/soop/danmaku/soop_danmaku.dart';
import 'package:live_sites/src/platforms/soop/danmaku/soop_session.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_parser.dart';

/// The SOOP (formerly AfreecaTV) adapter: player_live_api live/aid and the
/// stream assignment flow, plus the `chat` WebSocket.
///
/// Not migrated yet: the station profile, directory and search.
final class SoopSite
    with SiteRoomGuard
    implements LiveSite, LiveDanmakuCapability, LiveAreaCatalog, LiveDirectoryCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.soop;

  @override
  String get id => SiteIds.soop;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.soop, displayName: 'SOOP', homeUrl: 'https://www.sooplive.co.kr');

  /// The catalogue: every area of the one category, walked from
  /// `categoryList` until it says there is no more — twenty pages at most,
  /// because the site repeats its list when paged past the end. A failing
  /// first page fails the catalogue; a later failing one ends it with the
  /// areas so far, as the previous generation showed a partial list rather
  /// than none.
  @override
  Future<List<LiveArea>> getAreas() async {
    final areas = <String, LiveArea>{};
    for (var page = 1; page <= SoopParser.maxCategoryPages; page++) {
      final ({List<LiveArea> areas, bool hasMore}) result;
      try {
        final response = await http.send(
          LiveRequest.get(SoopParser.categoryListUrl(page), headers: SoopParser.headers, site: siteId),
        );
        result = SoopParser.categoryPage(response.text, status: response.statusCode);
      } on SiteError {
        if (page == 1) {
          rethrow;
        }
        break;
      }
      var added = false;
      for (final area in result.areas) {
        if (areas.containsKey(area.id)) {
          continue;
        }
        areas[area.id] = area;
        added = true;
      }
      if (!result.hasMore || !added) {
        break;
      }
    }
    return [...areas.values];
  }

  /// Page [page] of the site's recommendations: sixty rooms by viewers, and
  /// the list ends with an empty page.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    final response = await http.send(
      LiveRequest.get(SoopParser.recommendUrl(page), headers: SoopParser.headers, site: siteId),
    );
    return SoopParser.recommendPage(response.text, status: response.statusCode);
  }

  /// Page [page] of one area's live listing; an area id that is not a
  /// category number is a caller error rather than a request that cannot
  /// work.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    final no = area.id.trim();
    if (!RegExp(r'^[0-9]{4,12}$').hasMatch(no)) {
      throw SiteError.invalidRoomId(area.id);
    }
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    final response = await http.send(
      LiveRequest.get(SoopParser.areaListUrl(no, page), headers: SoopParser.headers, site: siteId),
    );
    return SoopParser.areaPage(response.text, areaName: area.name, status: response.statusCode);
  }

  /// Live rooms matching [keyword] (`liveSearch`), paged by [page]. A blank
  /// keyword or a page below 1 gives nothing without a request.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    final text = keyword.trim();
    if (text.isEmpty || page < 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final response = await http.send(
      LiveRequest.get(
        SoopParser.searchUrl(text, page: page),
        headers: SoopParser.headers,
        site: siteId,
      ),
    );
    final result = SoopParser.searchPage(response.text, status: response.statusCode);
    return LivePage(items: result.items, hasMore: result.hasMore, nextPage: result.hasMore ? page + 1 : null);
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _live(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final fresh = room.data == null ? await _live(room.roomId) : room;
    final presets = _presetsOf(fresh.data);
    return [for (final (index, preset) in presets.indexed) LivePlayQuality(label: preset.name, sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _live(room.roomId) : room;
    final data = fresh.data;
    if (data is! Map<String, Object?>) {
      throw SiteNotFoundError('soop ${room.roomId}: not live');
    }
    final bno = data['bno']?.toString() ?? '';
    final rmd = data['rmd']?.toString() ?? '';
    final cdn = data['cdn']?.toString() ?? '';
    final presets = _presetsOf(data);
    final preset = presets.where((p) => p.name == quality.label).firstOrNull ?? presets.firstOrNull;
    final presetName = preset?.name ?? quality.label;
    final key = await _aid(room.roomId, bno: bno, quality: presetName);
    final assign = await http.send(
      LiveRequest.get(
        SoopParser.assignUrl(rmd: rmd, cdn: cdn, bno: bno, quality: presetName),
        headers: SoopParser.headers,
        site: id,
      ),
    );
    final playlist = SoopParser.assignedPlaylist(assign.text, status: assign.statusCode);
    return [SoopParser.line(playlist: playlist, aid: key, roomId: room.roomId, cdn: cdn, codec: preset?.codec)];
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _live(room.roomId);
    return room.mergeFrom(fresh);
  }

  /// Opens the `chat` WebSocket for [room].
  ///
  /// The chat host, port and room number come from the live answer's
  /// `CHANNEL` and are re-read on every connect (not cached): they belong to
  /// one broadcast, so a reconnect after a restart needs the new ones — and a
  /// room that is not on air has no chat server, which is why this answers
  /// with a [SiteNotFoundError] instead of dialing a socket that would join
  /// nothing.
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final data = (await _live(room.roomId)).data;
    if (data is! Map<String, Object?>) {
      throw SiteNotFoundError('soop ${room.roomId}: not live, no chat server');
    }
    final chatNo = data['chatNo']?.toString() ?? '';
    final host = data['chatHost']?.toString() ?? '';
    final rawPort = data['chatPort'];
    final port = rawPort is int ? rawPort : int.tryParse('$rawPort');
    if (chatNo.isEmpty || host.isEmpty || port == null || port <= 0 || port >= 65535) {
      throw SiteNotFoundError('soop ${room.roomId}: no chat server');
    }
    return await SoopDanmakuSession.connect(
      SoopDanmakuArgs(
        url: Uri(scheme: 'wss', host: host, port: port + 1, pathSegments: ['Websocket', room.roomId]),
        plainUrl: Uri(scheme: 'ws', host: host, port: port, pathSegments: ['Websocket', room.roomId]),
        chatNo: chatNo,
        headers: SoopParser.headers,
      ),
    );
  }

  Future<LiveRoom> _live(String roomId) async {
    final response = await http.send(
      LiveRequest.form(
        SoopParser.playerUrl(roomId),
        fields: SoopParser.playerForm(roomId, type: 'live'),
        headers: SoopParser.headers,
        site: id,
      ),
    );
    return SoopParser.room(response.text, roomId: roomId, status: response.statusCode);
  }

  Future<String> _aid(String roomId, {required String bno, required String quality}) async {
    final response = await http.send(
      LiveRequest.form(
        SoopParser.playerUrl(roomId),
        fields: SoopParser.playerForm(roomId, type: 'aid', bno: bno, quality: quality),
        headers: SoopParser.headers,
        site: id,
      ),
    );
    return SoopParser.aid(response.text, status: response.statusCode);
  }

  static List<({String name, String? codec})> _presetsOf(Object? data) =>
      data is Map<String, Object?> ? SoopParser.presets(data['presets']) : const [];
}
