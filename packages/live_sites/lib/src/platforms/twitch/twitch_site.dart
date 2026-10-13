import 'dart:convert';
import 'dart:math';

import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/twitch/danmaku/twitch_session.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_parser.dart';

/// The Twitch adapter: anonymous GraphQL + usher flow, plus the IRC chat over
/// an anonymous WebSocket.
///
/// Not migrated yet: the directory and the session cookie.
final class TwitchSite with SiteRoomGuard implements LiveSite, LiveDanmakuCapability {
  /// A site over [http].
  new({required this.http}) : _deviceId = TwitchParser.deviceId();

  /// The HTTP transport.
  final LiveHttp http;

  final String _deviceId;

  /// The last access token per channel, reused for the play path.
  final Map<String, ({String value, String signature})> _tokens = {};

  @override
  String get siteId => SiteIds.twitch;

  @override
  String get id => SiteIds.twitch;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.twitch, displayName: 'Twitch', homeUrl: 'https://www.twitch.tv');

  /// The busiest live streams of the whole site, in Twitch's order, 30 at a
  /// time (the most Twitch gives) and paged locally from a snapshot: the first
  /// page fetches a new snapshot, later ones reuse it while it is under 30 s
  /// old and fetch the next chunk only when a page would start past its end.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) => _page('recommend', page: page, _fetchStreams);

  /// The streams of the directory `area.id` (its slug), fetched 100 at a time
  /// and paged locally, as [getRecommendRooms]. An area without a slug has no
  /// streams, without a request.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    final slug = area.id.trim();
    if (slug.isEmpty) {
      return Future.value(const LivePage<LiveRoom>(items: []));
    }
    return _page('area|$slug', page: page, (cursor) => _fetchGame(slug, cursor));
  }

  Future<({List<LiveRoom> rooms, String? cursor})> _fetchStreams(String? cursor) async {
    final response = await http.send(
      LiveRequest.custom(
        url: TwitchParser.gqlUrl,
        method: 'POST',
        body: jsonEncode(TwitchParser.streamsOperation(limit: TwitchParser.streamsLimit, cursor: cursor)),
        headers: TwitchParser.gqlHeaders(deviceId: _deviceId),
        site: id,
      ),
    );
    return TwitchParser.streams(response.text, now: _now, status: response.statusCode);
  }

  Future<({List<LiveRoom> rooms, String? cursor})> _fetchGame(String slug, String? cursor) async {
    final response = await http.send(
      LiveRequest.custom(
        url: TwitchParser.gqlUrl,
        method: 'POST',
        body: jsonEncode(TwitchParser.gameOperation(slug, limit: TwitchParser.directoryFetchLimit, cursor: cursor)),
        headers: TwitchParser.gqlHeaders(deviceId: _deviceId),
        site: id,
      ),
    );
    return TwitchParser.gameStreams(response.text, now: _now, slug: slug, status: response.statusCode);
  }

  /// Page [page] of the list [key]: up to [_pageSize] rooms cut from its
  /// snapshot, starting where the page before ended. The first page fetches a
  /// new snapshot with [fetch]; a later one does when the snapshot is missing
  /// or [_snapshotLifetime] old. Only a page that would start past the
  /// snapshot's end fetches the next chunk from its cursor, so a page may hold
  /// fewer rooms than asked; an empty page is the end.
  Future<LivePage<LiveRoom>> _page(
    String key,
    Future<({List<LiveRoom> rooms, String? cursor})> Function(String? cursor) fetch, {
    required int page,
  }) async {
    final number = page < 1 ? 1 : page;
    var snapshot = _snapshots[key];
    final now = _now;
    if (number == 1 || snapshot == null || now.difference(snapshot.fetchedAt) >= _snapshotLifetime) {
      final fresh = _TwitchSnapshot(now)..add(await fetch(null));
      _snapshots
        ..remove(key)
        ..[key] = fresh;
      if (_snapshots.length > _snapshotLimit) {
        _snapshots.remove(_snapshots.keys.first);
      }
      snapshot = fresh;
    }
    final start = number == 1 ? 0 : snapshot.starts[number] ?? (number - 1) * _pageSize;
    while (start >= snapshot.rooms.length && snapshot.cursor != null) {
      snapshot.add(await fetch(snapshot.cursor));
    }
    final rooms = snapshot.rooms;
    if (start >= rooms.length) {
      return const LivePage<LiveRoom>(items: []);
    }
    final end = min(start + _pageSize, rooms.length);
    snapshot.starts[number + 1] = end;
    final hasMore = end < rooms.length || snapshot.cursor != null;
    return LivePage<LiveRoom>(
      items: List.unmodifiable(rooms.sublist(start, end)),
      hasMore: hasMore,
      nextPage: hasMore ? number + 1 : null,
    );
  }

  DateTime get _now => DateTime.now();

  /// The list snapshots, by key.
  final Map<String, _TwitchSnapshot> _snapshots = {};

  static const int _pageSize = 30;
  static const int _snapshotLimit = 16;
  static const Duration _snapshotLifetime = Duration(seconds: 30);

  /// Channels matching [keyword], live or offline: the `SearchResultsPage_`
  /// `SearchResults` query, one page of thirty; a later page continues the
  /// cursor the previous page reported (so it must have been asked), and a
  /// blank keyword gives nothing without a request.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    final text = keyword.trim();
    if (text.isEmpty) {
      return const LivePage<LiveRoom>(items: []);
    }
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    final key = 'search|$text';
    final cursor = page == 1 ? null : _cursors['$key|$page'];
    if (page > 1 && cursor == null) {
      return const LivePage<LiveRoom>(items: []);
    }
    final response = await http.send(
      LiveRequest.custom(
        url: TwitchParser.gqlUrl,
        method: 'POST',
        body: jsonEncode(TwitchParser.searchOperation(text, cursor: cursor)),
        headers: TwitchParser.gqlHeaders(deviceId: _deviceId),
        site: id,
      ),
    );
    final result = TwitchParser.searchPage(response.text, status: response.statusCode);
    if (result.cursor != null) {
      _cursors['$key|${page + 1}'] = result.cursor!;
    }
    final hasMore = result.cursor != null && result.rooms.isNotEmpty;
    return LivePage<LiveRoom>(items: result.rooms, hasMore: hasMore, nextPage: hasMore ? page + 1 : null);
  }

  /// The cursor of each search page after the first, by `search|keyword|page`.
  final Map<String, String> _cursors = {};

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _user(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    // Usher answers one master playlist for every quality; the line is the
    // master and the player picks the variant.
    return const [LivePlayQuality(label: 'source')];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final login = room.roomId.toLowerCase();
    final token = _tokens[login] ?? await _accessToken(login);
    return [
      LivePlayLine(
        url: TwitchParser.usherUrl(login, token: token).toString(),
        headers: TwitchParser.mediaHeaders(login),
        format: StreamFormat.hls,
        codec: 'avc',
        lineId: 'source',
      ),
    ];
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _user(room.roomId);
    return room.mergeFrom(fresh);
  }

  /// Opens the IRC chat for [room] as an anonymous guest (this tree stores no
  /// Twitch login, so the join always uses an anonymous nick).
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    return await TwitchDanmakuSession.connect(room.roomId);
  }

  Future<LiveRoom> _user(String login) async {
    final normalized = login.toLowerCase();
    final response = await http.send(
      LiveRequest.custom(
        url: TwitchParser.gqlUrl,
        method: 'POST',
        body: jsonEncode(TwitchParser.userOperation(normalized)),
        headers: TwitchParser.gqlHeaders(deviceId: _deviceId),
        site: id,
      ),
    );
    return TwitchParser.room(response.text, login: normalized, status: response.statusCode);
  }

  Future<({String value, String signature})> _accessToken(String login) async {
    final response = await http.send(
      LiveRequest.custom(
        url: TwitchParser.gqlUrl,
        method: 'POST',
        body: jsonEncode(TwitchParser.accessTokenOperation(login)),
        headers: TwitchParser.gqlHeaders(deviceId: _deviceId),
        site: id,
      ),
    );
    final token = TwitchParser.accessToken(response.text, status: response.statusCode);
    return _tokens[login] = token;
  }
}

/// One list's streams as fetched so far, paged locally: the rooms in the
/// server's order (each once), the cursor of the next chunk, when the first
/// chunk arrived and where each page served so far ended.
final class _TwitchSnapshot {
  new(this.fetchedAt);

  final DateTime fetchedAt;
  final List<LiveRoom> rooms = [];
  final Set<String> _ids = {};
  String? cursor;

  /// The first room of each page after one already served, by page number.
  final Map<int, int> starts = {};

  /// Adds a chunk; a chunk that brings no new room ends the list (a cursor
  /// that goes nowhere must not be followed forever).
  void add(({List<LiveRoom> rooms, String? cursor}) chunk) {
    var added = false;
    for (final room in chunk.rooms) {
      if (_ids.add(room.identity)) {
        rooms.add(room);
        added = true;
      }
    }
    cursor = added ? chunk.cursor : null;
  }
}
