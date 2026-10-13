import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/fc2live/danmaku/fc2live_danmaku.dart';
import 'package:live_sites/src/platforms/fc2live/danmaku/fc2live_session.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_parser.dart';

/// The FC2 Live adapter: one member-API request per room, and a directory
/// from the site's whole-channel list.
///
/// Playback is not migrated yet: an FC2 stream is authorized through the
/// control WebSocket (`wss://<node>.live.fc2.com/control/channels/<id>`)
/// and played through a relay recipe, so
/// [getPlayQualities]/[getPlayUrls] throw until that transport lands. The
/// comments ride the same control socket, opened from a fresh grant
/// ([connect]).
final class Fc2LiveSite
    with SiteRoomGuard
    implements LiveSite, LiveAreaCatalog, LiveDirectoryCapability, LiveDanmakuCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.fc2Live;

  @override
  String get id => SiteIds.fc2Live;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.fc2Live, displayName: 'FC2 Live', homeUrl: 'https://live.fc2.com');

  /// The catalogue: the site's six constant areas, so no request is spent
  /// finding them out.
  @override
  Future<List<LiveArea>> getAreas() async => Fc2LiveParser.areas();

  /// Page [page] of every channel on air — the site's own directory.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) => _directory(null, page);

  /// Page [page] of one area; an area the catalogue does not know is a caller
  /// error rather than an empty page.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    final filter = Fc2LiveParser.areaFilter(area);
    if (filter == null && area.id.trim() != Fc2LiveParser.allAreaId) {
      throw SiteError.invalidRoomId(area.id);
    }
    return _directory(filter, page);
  }

  /// Page [page] of the channels [filter] keeps (null keeps every one).
  ///
  /// The directory is one answer carrying every channel on air, sliced
  /// locally at the site's own page size. Page 1 asks anew (the pull to
  /// refresh) and a later page reuses the answer while it is younger than
  /// [snapshotLifetime], so the pages of one browse neither repeat nor skip
  /// rooms of the first.
  Future<LivePage<LiveRoom>> _directory(int? filter, int page) async {
    if (page < 1 || page > Fc2LiveParser.maxPage) {
      throw RangeError.range(page, 1, Fc2LiveParser.maxPage, 'page');
    }
    final channels = await _snapshot(fresh: page == 1);
    final matching = [
      for (final channel in channels)
        if (Fc2LiveParser.inArea(channel.categoryId, filter)) channel.room,
    ];
    final start = (page - 1) * Fc2LiveParser.directoryPageSize;
    if (start >= matching.length) {
      return LivePage<LiveRoom>(items: const [], totalCount: matching.length);
    }
    final end = (start + Fc2LiveParser.directoryPageSize).clamp(start, matching.length);
    final hasMore = end < matching.length;
    return LivePage<LiveRoom>(
      items: matching.sublist(start, end),
      hasMore: hasMore,
      nextPage: hasMore ? page + 1 : null,
      totalCount: matching.length,
    );
  }

  /// The channel snapshot: page 1 asks anew, a later page reuses the answer
  /// while it is younger than [snapshotLifetime]. Every area is one answer,
  /// so paging costs one request rather than one per page.
  Future<List<({LiveRoom room, int categoryId})>> _snapshot({required bool fresh}) async {
    final cached = _channels;
    final at = _channelsAt;
    if (!fresh && cached != null && at != null && DateTime.now().difference(at) < snapshotLifetime) {
      return cached;
    }
    final response = await http.send(
      LiveRequest.custom(
        url: Fc2LiveParser.snapshotUrl(),
        method: 'POST',
        headers: {...Fc2LiveParser.headers, 'content-type': 'application/x-www-form-urlencoded; charset=UTF-8'},
        body: '',
        site: id,
      ),
    );
    final channels = Fc2LiveParser.snapshot(response.text, status: response.statusCode);
    _channels = channels;
    _channelsAt = DateTime.now();
    return channels;
  }

  /// How long the channel snapshot is reused after it arrived.
  static const Duration snapshotLifetime = Duration(seconds: 30);

  List<({LiveRoom room, int categoryId})>? _channels;
  DateTime? _channelsAt;

  /// 3.x's search, one snapshot: a channel id or link is that channel (the
  /// member answer, page 1 only); any other keyword filters the channel
  /// snapshot by name or title (case ignored) and slices it at the site's page
  /// size. A blank keyword or a page below one gives nothing without a request;
  /// a later page reuses the first's snapshot while it is young.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    const size = Fc2LiveParser.directoryPageSize;
    final query = keyword.trim();
    if (query.isEmpty || page < 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final exact = Fc2LiveParser.channelId(query);
    if (exact != null) {
      if (page != 1) {
        return const LivePage<LiveRoom>(items: []);
      }
      try {
        return LivePage<LiveRoom>(items: [(await _member(exact)).room]);
      } on SiteNotFoundError {
        return const LivePage<LiveRoom>(items: []);
      }
    }
    final channels = await _snapshot(fresh: page == 1);
    final needle = query.toLowerCase();
    final seen = <String>{};
    final matching = [
      for (final channel in channels)
        if ((channel.room.nick.toLowerCase().contains(needle) || channel.room.title.toLowerCase().contains(needle)) &&
            seen.add(channel.room.roomId))
          channel.room,
    ];
    final start = (page - 1) * size;
    if (start >= matching.length) {
      return LivePage<LiveRoom>(items: const [], totalCount: matching.length);
    }
    final end = (start + size).clamp(start, matching.length);
    final hasMore = end < matching.length;
    return LivePage<LiveRoom>(
      items: matching.sublist(start, end),
      hasMore: hasMore,
      nextPage: hasMore ? page + 1 : null,
      totalCount: matching.length,
    );
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _member(room.roomId);
    return room.mergeFrom(fresh.room);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    throw UnimplementedError('fc2live playback needs the control WebSocket transport');
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    throw UnimplementedError('fc2live playback needs the control WebSocket transport');
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _member(room.roomId);
    return room.mergeFrom(fresh.room);
  }

  /// The member-API request of [roomId]: the room and the channel's version.
  Future<({LiveRoom room, String version})> _member(String roomId) async {
    final channelId = Fc2LiveParser.channelId(roomId);
    if (channelId == null) {
      throw SiteNotFoundError('fc2live: "${roomId.trim()}" is not an FC2 channel');
    }
    final response = await http.send(
      LiveRequest.form(
        Uri.https('live.fc2.com', Fc2LiveParser.memberPath),
        fields: {'channel': '1', 'profile': '1', 'user': '1', 'streamid': channelId},
        headers: Fc2LiveParser.headers,
        site: id,
      ),
    );
    return Fc2LiveParser.room(response.text, channelId: channelId, status: response.statusCode);
  }

  /// Opens FC2's control socket for [room]'s comments: `memberApi` (which says
  /// the channel is on air and gives its version), then `getControlServer`
  /// for the grant that names the socket and its session cookie. A channel not
  /// on air, or a grant the site refuses, ends with a [SiteError] rather than
  /// an opening socket.
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    return await Fc2LiveDanmakuSession.connect(await _danmakuArgs(room.roomId));
  }

  Future<Fc2LiveDanmakuArgs> _danmakuArgs(String roomId) async {
    final channelId = Fc2LiveParser.channelId(roomId);
    if (channelId == null) {
      throw SiteNotFoundError('fc2live: "${roomId.trim()}" is not an FC2 channel');
    }
    final member = await _member(channelId);
    if (member.room.status != LiveStatus.live) {
      throw SiteNotFoundError('fc2live: channel $channelId is not on air');
    }
    if (member.version.isEmpty) {
      throw const SiteApiChangedError('fc2live memberApi: channel is live without a version');
    }
    final response = await http.send(
      LiveRequest.form(
        Uri.https('live.fc2.com', Fc2LiveParser.controlPath),
        fields: {
          'channel_id': channelId,
          'mode': 'play',
          'orz': '',
          'channel_version': member.version,
          'client_version': '2.1.0\n [1]',
          'client_type': 'pc',
          'client_app': 'browser_hls',
          'ipv6': '',
        },
        headers: Fc2LiveParser.headers,
        site: id,
      ),
    );
    final grant = Fc2LiveParser.grant(response.text, channelId: channelId, status: response.statusCode);
    return Fc2LiveDanmakuArgs(channelId: channelId, endpoint: grant.endpoint, headers: grant.headers);
  }
}
