import 'dart:async';

// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/jdlive/api/jdlive_endpoints.dart';
import 'package:live_sites/src/platforms/jdlive/api/jdlive_http.dart';
import 'package:live_sites/src/platforms/jdlive/capabilities/jdlive_area_provider.dart';
import 'package:live_sites/src/platforms/jdlive/capabilities/jdlive_discovery_provider.dart';
import 'package:live_sites/src/platforms/jdlive/capabilities/jdlive_link_resolver.dart';
import 'package:live_sites/src/platforms/jdlive/capabilities/jdlive_playback_provider.dart';
import 'package:live_sites/src/platforms/jdlive/capabilities/jdlive_room_provider.dart';
import 'package:live_sites/src/platforms/jdlive/capabilities/jdlive_room_refresh.dart';
import 'package:live_sites/src/platforms/jdlive/capabilities/jdlive_search_provider.dart';
import 'package:live_sites/src/platforms/jdlive/capabilities/jdlive_status_check.dart';
import 'package:live_sites/src/platforms/jdlive/danmaku/jdlive_danmaku_session.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_manifest.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_failure.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One page of a list sequence: its broadcasts, the `currentCount` the next
/// page sends, and whether another page may follow.
typedef JdliveListing = ({List<JdliveBroadcast> rooms, int nextCount, bool hasMore});

/// How many list cards are kept to complete play answers.
const _knownLimit = 2000;

/// How many keyword searches keep their page sequence.
const _searchLimit = 32;

/// The JD Live adapter (parsing in `parsers/`, the chat in `danmaku/`):
/// manifest + capability discovery + lifecycle (ARCHITECTURE.md §7.2).
///
/// Anonymous, like the website: no cookie and no account. Every request
/// carries [JdliveEndpoints.apiHeaders] and goes as `jdlive`, so the app
/// routes the platform through its proxy setting. The requests are the
/// website's:
/// - the featured list `liveListWithTabToM` (the one area, the directory,
///   the recommendations and the search filter), paged natively: page 1
///   starts a sequence at the clock's time, and each next page sends the
///   previous `currentCount` with that time, while the previous page had new
///   broadcasts; a broadcast already listed in the sequence is not listed
///   again. The directory, the recommendations (and the one area) and each
///   search keyword keep their own sequence;
/// - a room is the play answer `getImmediatePlayToM` (one request); room
///   entry of a live broadcast with a playlist also downloads and checks it
///   (two requests). Each call has one [deadline].
///
/// The play answer has no title, shop name, avatar, cover or views; they
/// come from the list cards seen in this session, else they stay empty, so a
/// follow keeps what it stored. Rooms are identified by the broadcast id
/// (`liveId`). Failures are [JdliveFailure]s; nothing is disguised as an
/// offline room.
final class JdliveSite implements LiveSite {
  /// Creates the adapter over [http]. [connect] makes the chat's socket
  /// (default [webSocketConnect]); [deadline] bounds a list page, or a play
  /// answer with its playlist; [now] (the requests' clock and the list
  /// sequences') is injectable for tests.
  JdliveSite({
    required this.http,
    this.connect = webSocketConnect,
    this.deadline = const Duration(seconds: 20),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Transport.
  final JdliveHttp http;

  /// How the chat's socket is connected.
  final SocketConnector connect;

  /// Longest list page, or play answer and playlist together.
  final Duration deadline;

  final DateTime Function() _now;

  /// The last card or play answer of each broadcast, oldest first.
  final Map<String, JdliveBroadcast> _known = {};

  /// Page sequences: `directory`, `recommend` and `search:<keyword>`.
  final Map<String, _Sequence> _sequences = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => jdliveManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Requests ------------------------------------------------------------------

  /// [work] under its own cancellation, ended when [deadline] passes: the
  /// deadline is a network failure, a caller's own cancellation rethrows.
  Future<T> _scoped<T>(Future<T> Function(CancelToken token) work) async {
    final token = CancelToken();
    var expired = false;
    final timer = Timer(deadline, () {
      expired = true;
      token.cancel();
    });
    try {
      return await work(token);
    } on CancelledFailure catch (failure) {
      if (!expired) rethrow;
      throw JdliveFailure(JdliveFailureKind.network, 'no answer within ${deadline.inSeconds} s', cause: failure);
    } finally {
      timer.cancel();
    }
  }

  /// Keeps [room] as the latest of its broadcast, dropping the oldest past
  /// [_knownLimit].
  void _remember(JdliveBroadcast room) {
    _known
      ..remove(room.liveId)
      ..[room.liveId] = room;
    if (_known.length > _knownLimit) _known.remove(_known.keys.first);
  }

  // Featured list -------------------------------------------------------------

  /// Page [page] of sequence [key]: page 1 starts the sequence; a later page
  /// needs the previous page of the same sequence to have asked for it, else
  /// it is empty without a request, as is a page below 1. A broadcast an
  /// earlier page of the sequence listed is left out, and a page without new
  /// broadcasts is the last. The cards are remembered for the play answers.
  Future<JdliveListing> _page(String key, int page) async {
    if (page < 1) return (rooms: const <JdliveBroadcast>[], nextCount: 0, hasMore: false);
    if (page == 1) _start(key);
    final sequence = _sequences[key];
    final count = sequence?.counts[page];
    if (sequence == null || count == null) {
      return (rooms: const <JdliveBroadcast>[], nextCount: 0, hasMore: false);
    }
    if (page > JdliveEndpoints.maxPage) {
      throw JdliveFailure(JdliveFailureKind.invalidArgument, 'page $page is past ${JdliveEndpoints.maxPage}');
    }
    final result = await _scoped((token) async {
      final response = await http.get(
        JdliveEndpoints.listUrl(page: page, count: count, timestamp: sequence.timestamp, now: _now()),
        cancel: token,
      );
      return JdliveRoomParser.directory(response.text, after: count, status: response.status);
    });
    result.rooms.forEach(_remember);
    final fresh = [
      for (final room in result.rooms)
        if (sequence.listed.add(room.liveId)) room,
    ];
    final hasMore = result.hasMore && fresh.isNotEmpty;
    if (hasMore) {
      sequence.counts[page + 1] = result.nextCount;
    } else {
      sequence.counts.remove(page + 1);
    }
    return (rooms: fresh, nextCount: result.nextCount, hasMore: hasMore);
  }

  /// A new sequence for [key] at the clock's time; searches beyond
  /// [_searchLimit] drop the oldest.
  void _start(String key) {
    _sequences
      ..remove(key)
      ..[key] = _Sequence(_now().millisecondsSinceEpoch);
    final searches = [
      for (final name in _sequences.keys)
        if (name.startsWith('search:')) name,
    ];
    if (searches.length > _searchLimit) _sequences.remove(searches.first);
  }

  /// Page [page] of the featured list: its broadcasts, and whether another
  /// page may follow.
  Future<({List<LiveRoom> rooms, bool hasMore})> directory(int page) async {
    final result = await _page('directory', page);
    return (rooms: [for (final room in result.rooms) JdliveRoomParser.room(room)], hasMore: result.hasMore);
  }

  /// A slice [page] of [pageSize] of the featured list (a page or size below
  /// 1 gives nothing without a request), from its own sequence, and whether
  /// the sequence may have more.
  Future<({List<LiveRoom> rooms, bool hasMore})> recommend(int page, int pageSize) async {
    if (page < 1 || pageSize < 1) return (rooms: const <LiveRoom>[], hasMore: false);
    final result = await _page('recommend', page);
    final cut = pageSize.clamp(1, JdliveEndpoints.maxRecommendSize);
    return (rooms: [for (final room in result.rooms.take(cut)) JdliveRoomParser.room(room)], hasMore: result.hasMore);
  }

  // Search --------------------------------------------------------------------

  /// The search: a broadcast id or room link finds that room (page 1 only; a
  /// broadcast the site does not know is no result); another keyword filters
  /// page [page] of the featured list (its own sequence per keyword) by id,
  /// account, shop name and title, case ignored, up to [pageSize]. A blank
  /// keyword, a page below 1, a page size below 1 or over 100, or a link of
  /// another site gives nothing without a request. Whether the list has more
  /// is the sequence's own answer (whether a later page matches is not known
  /// here), and an exact hit says nothing about pages.
  Future<({List<LiveRoom> rooms, bool? hasMore})> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final raw = keyword.trim();
    if (raw.isEmpty || page < 1 || pageSize < 1 || pageSize > JdliveEndpoints.maxSearchSize) {
      return (rooms: const <LiveRoom>[], hasMore: null);
    }
    final liveId = JdliveEndpoints.liveIdOf(raw);
    if (liveId != null) {
      if (page != 1) return (rooms: const <LiveRoom>[], hasMore: null);
      try {
        return (rooms: [await detail(liveId, withMedia: false)], hasMore: null);
      } on JdliveFailure catch (failure) {
        if (failure.kind != JdliveFailureKind.notFound) rethrow;
        return (rooms: const <LiveRoom>[], hasMore: null);
      }
    }
    if (_isLink(raw)) return (rooms: const <LiveRoom>[], hasMore: null);
    final query = raw.toLowerCase();
    final result = await _page('search:$query', page);
    final matches = result.rooms.where((room) => _matches(room, query)).take(pageSize);
    return (
      rooms: [for (final room in matches) JdliveRoomParser.room(room)],
      hasMore: result.rooms.isNotEmpty && result.hasMore, // a page that read nothing ends the keyword
    );
  }

  /// Whether [input] is a link (`scheme://…`) rather than a keyword.
  static bool _isLink(String input) {
    final uri = Uri.tryParse(input);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  /// Whether [room] matches the lower-case [query]: in its id, the shop's
  /// account, name or title (the names case ignored).
  static bool _matches(JdliveBroadcast room, String query) =>
      room.liveId.contains(query) ||
      room.authorId.contains(query) ||
      room.nick.toLowerCase().contains(query) ||
      room.title.toLowerCase().contains(query);

  // Rooms ---------------------------------------------------------------------

  /// [roomId] as a broadcast id (a room link is read too); anything else is
  /// not-found without a request.
  String _liveId(String roomId) =>
      JdliveEndpoints.liveIdOf(roomId) ??
      (throw JdliveFailure(JdliveFailureKind.notFound, 'room id "${roomId.trim()}" is not a broadcast id'));

  /// The play answer of [liveId]; with [withMedia], a live broadcast's
  /// playlist is downloaded and checked too, within the same deadline. A
  /// live broadcast with only an FLV stream has nothing to check, an
  /// app-only one is not played (one request); a replay's recording is not
  /// downloaded (JD records whole broadcasts).
  Future<JdliveBroadcast> _play(String liveId, {required bool withMedia}) => _scoped((token) async {
    final response = await http.get(JdliveEndpoints.playUrl(liveId, now: _now()), cancel: token);
    final room = JdliveRoomParser.play(response.text, liveId: liveId, status: response.status);
    final hls = room.hls;
    if (withMedia && room.state == JdliveState.live && !room.appOnly && hls != null) {
      final playlist = await http.get(hls, headers: JdliveEndpoints.mediaHeaders(liveId), cancel: token);
      JdliveRoomParser.checkPlaylist(playlist.text, expected: hls, status: playlist.status);
    }
    return room;
  });

  /// The room of [roomId]: the play answer completed from the last card of
  /// the broadcast, which it then replaces. A live broadcast that is not
  /// app-only carries its chat arguments without another request. [withMedia]
  /// (a room entry) also downloads and checks a live broadcast's playlist; a
  /// search hit takes the play answer alone.
  Future<LiveRoom> detail(String roomId, {bool withMedia = true}) async {
    final liveId = _liveId(roomId);
    var room = await _play(liveId, withMedia: withMedia);
    final known = _known[liveId];
    if (known != null) room = room.enrich(known);
    _remember(room);
    return JdliveRoomParser.room(room, withData: withMedia);
  }

  // Streams -------------------------------------------------------------------

  /// The play answer a room's streams come from: the one of its room read
  /// when the session has seen it (no request), else a fresh one with the
  /// playlist check — the capabilities are asked by room id alone, so the
  /// adapter takes the room's answer itself when no entry is kept. A kept
  /// answer that cannot be played says why, without a request.
  Future<JdliveBroadcast> _playable(String roomId) async {
    final liveId = _liveId(roomId);
    final known = _known[liveId];
    if (known != null && known.hasPlayAnswer) {
      final error = known.streamError;
      if (error == null) return known;
      throw error;
    }
    final fresh = await _play(liveId, withMedia: true);
    final enriched = known == null ? fresh : fresh.enrich(known);
    _remember(enriched);
    final error = enriched.streamError;
    if (error != null) throw error;
    return enriched;
  }

  /// The qualities [roomId] offers now.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async => JdliveRoomParser.qualities(await _playable(roomId));

  /// The one line of [roomId] at [quality] (the HLS playlist for a live
  /// broadcast, the recording for a replay, when it is null).
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async {
    final room = await _playable(roomId);
    final id =
        quality?.qualityId ?? (room.state == JdliveState.replay ? JdliveEndpoints.replayId : JdliveEndpoints.hlsId);
    return [JdliveRoomParser.line(room, id)];
  }

  // Capability wiring ---------------------------------------------------------

  JdliveRoomProvider? _room;
  JdliveAreaProvider? _area;
  JdliveDiscoveryProvider? _discovery;
  JdliveSearchProvider? _search;
  JdlivePlaybackProvider? _playback;
  JdliveDanmakuProvider? _danmaku;
  JdliveLinkResolver? _link;
  JdliveRoomRefresh? _refresh;
  JdliveStatusCheck? _status;

  /// The capability of type [T], or null when JD Live does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= JdliveRoomProvider(site: this);
    final area = _area ??= JdliveAreaProvider(site: this);
    final discovery = _discovery ??= JdliveDiscoveryProvider(site: this);
    final search = _search ??= JdliveSearchProvider(site: this);
    final playback = _playback ??= JdlivePlaybackProvider(site: this);
    final danmaku = _danmaku ??= JdliveDanmakuProvider(site: this);
    final link = _link ??= JdliveLinkResolver(site: this);
    final refresh = _refresh ??= JdliveRoomRefresh(site: this);
    final status = _status ??= JdliveStatusCheck(refresh: refresh);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => area as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LiveDanmakuProvider) => danmaku as T,
      const (LiveLinkResolver) => link as T,
      const (LiveRoomRefresh) => refresh as T,
      const (LiveStatusCheck) => status as T,
      _ => null,
    };
  }
}

/// One page sequence: the time of its first page, the `currentCount` to send
/// for each page it may ask for, and the broadcasts it listed.
final class _Sequence {
  _Sequence(this.timestamp);

  final int timestamp;
  final Map<int, int> counts = {1: 0};
  final Set<String> listed = {};
}
