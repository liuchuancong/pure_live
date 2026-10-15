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
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_endpoints.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_http.dart';
import 'package:live_sites/src/platforms/looklive/capabilities/looklive_area_provider.dart';
import 'package:live_sites/src/platforms/looklive/capabilities/looklive_discovery_provider.dart';
import 'package:live_sites/src/platforms/looklive/capabilities/looklive_link_resolver.dart';
import 'package:live_sites/src/platforms/looklive/capabilities/looklive_playback_provider.dart';
import 'package:live_sites/src/platforms/looklive/capabilities/looklive_room_provider.dart';
import 'package:live_sites/src/platforms/looklive/capabilities/looklive_search_provider.dart';
import 'package:live_sites/src/platforms/looklive/danmaku/looklive_danmaku_session.dart';
import 'package:live_sites/src/platforms/looklive/looklive_manifest.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How many rooms are kept to complete later answers (3.x kept every room it
/// saw).
const _knownLimit = 2000;

/// The LOOK Live (NetEase) adapter (parsing in `parsers/`, the chat in
/// `danmaku/`): manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2).
///
/// Anonymous, like the website: no cookie and no account. Every API request
/// is a form POST of NetEase's `weapi` envelope with the website's headers
/// and goes as `looklive` (so the app routes the platform through its proxy
/// setting). The requests are the website's:
/// - the video and voice recommendation lists, twenty rooms a page, paged
///   natively. The recommendations and the search ask both lists for the
///   same page and merge them (video first); an area asks its own list. The
///   merged pages remember which list has ended and no longer ask it; page 1
///   starts over;
/// - a room is `room/get/v3` (one request), whose answer also holds the
///   streams and the chatroom of a live room.
///
/// Rooms seen in the lists complete later answers of the same broadcast
/// (heat and viewers, which the room answer lacks, while it is live). Rooms
/// are identified by the room number asked for. Failures are
/// [LookliveFailure]s; nothing is disguised as an offline room.
final class LookliveSite implements LiveSite {
  /// Creates the adapter over [http]. [connect] makes the chat's socket
  /// (default [webSocketConnect]); [deadline] bounds each request (the
  /// website's 20 s).
  LookliveSite({required this.http, this.connect = webSocketConnect, this.deadline = const Duration(seconds: 20)});

  /// Transport.
  final LookliveHttp http;

  /// How the chat's socket is connected.
  final SocketConnector connect;

  /// Longest request.
  final Duration deadline;

  /// The last card or answer of each room, oldest first.
  final Map<String, LookliveRoom> _known = {};

  /// The page at which each list answered "no more" in the merged pages;
  /// cleared by the next merged page 1.
  final Map<LookliveKind, int> _ended = {};

  /// The room answer each room was entered with, by room number: the streams
  /// the playback capability hands out until the next entry.
  final Map<String, LookliveRoom> _entries = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => lookliveManifest;

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
      throw LookliveFailure(LookliveFailureKind.network, 'no answer within ${deadline.inSeconds} s', cause: failure);
    } finally {
      timer.cancel();
    }
  }

  /// Keeps [room] as the latest of its room, completing it from what was
  /// seen before, and remembers the result (dropping the oldest past
  /// [_knownLimit]).
  LookliveRoom _keep(LookliveRoom room) {
    final known = _known.remove(room.roomId);
    final kept = known == null ? room : room.enrich(known);
    _known[room.roomId] = kept;
    if (_known.length > _knownLimit) _known.remove(_known.keys.first);
    return kept;
  }

  // Lists ---------------------------------------------------------------------

  /// Page [page] of the list of [kind]. A page past
  /// [LookliveEndpoints.maxPage] is a caller error.
  Future<({List<LookliveRoom> rooms, bool hasMore})> _list(LookliveKind kind, int page, CancelToken cancel) async {
    if (page > LookliveEndpoints.maxPage) {
      throw LookliveFailure(LookliveFailureKind.invalidArgument, 'page $page is past ${LookliveEndpoints.maxPage}');
    }
    final response = await http.post(
      LookliveRoomParser.listPath(kind),
      LookliveEndpoints.listPayload(page),
      cancel: cancel,
    );
    return LookliveRoomParser.directory(response.text, kind: kind, status: response.status);
  }

  /// Page [page] of [kind]'s list, or of both merged when null: the requests
  /// at once, video rooms first, each room once; another page when either
  /// list has one. A page below 1 is empty without a request.
  ///
  /// Merged, a list that answered "no more" on an earlier page is not asked
  /// again (the video list, a few rooms long, ends early). Page 1 always
  /// asks both and starts the record over, so pulling to refresh sees a list
  /// that has grown again.
  Future<({List<LookliveRoom> rooms, bool hasMore})> _page(int page, LookliveKind? kind, CancelToken cancel) async {
    if (page < 1) return (rooms: const <LookliveRoom>[], hasMore: false);
    if (kind != null) return await _list(kind, page, cancel);
    final asked = [
      for (final list in LookliveKind.values)
        if (_ended[list] case final end when end == null || page <= end) list,
    ];
    final results = await Future.wait([for (final list in asked) _list(list, page, cancel)]);
    if (page == 1) _ended.clear();
    for (final (index, list) in asked.indexed) {
      if (!results[index].hasMore) {
        _ended[list] = page;
      } else if (_ended[list] case final end? when end <= page) {
        _ended.remove(list);
      }
    }
    final rooms = <String, LookliveRoom>{};
    for (final result in results) {
      for (final room in result.rooms) {
        rooms.putIfAbsent(room.roomId, () => room);
      }
    }
    return (rooms: rooms.values.toList(), hasMore: results.any((result) => result.hasMore));
  }

  /// Page [page] of [areaId]'s list, or of both lists merged for the
  /// recommendations, completed from what was seen of each room before. A
  /// page below 1 gives nothing; an area that is not a LOOK Live area is a
  /// caller error; a page past [LookliveEndpoints.maxPage] too.
  Future<({List<LiveRoom> rooms, bool hasMore})> directory(int page, {String? areaId}) async {
    final kind = LookliveRoomParser.kindOfArea(areaId);
    final result = await _scoped((token) => _page(page, kind, token));
    return (
      rooms: [for (final room in result.rooms) LookliveRoomParser.liveRoom(_keep(room))],
      hasMore: result.hasMore,
    );
  }

  /// A slice [page] of [pageSize] of the merged recommendations (a page or
  /// size below 1 gives nothing without a request), and whether the merged
  /// pages may have more.
  Future<({List<LiveRoom> rooms, bool hasMore})> recommend(int page, int pageSize) async {
    if (page < 1 || pageSize < 1) return (rooms: const <LiveRoom>[], hasMore: false);
    final result = await directory(page);
    return (rooms: result.rooms.take(pageSize).toList(), hasMore: result.hasMore);
  }

  // Search --------------------------------------------------------------------

  /// The search (page 1 only): a room number or room link finds that room (a
  /// room the site does not know is no result); another keyword filters the
  /// first page of both lists by number, name and title, case ignored, up to
  /// [pageSize]. A blank keyword, another page, a page size below 1 or over
  /// [LookliveEndpoints.maxSearchSize], or a link of another site gives
  /// nothing without a request. Whether later pages would match is not known
  /// here.
  Future<({List<LiveRoom> rooms, bool? hasMore})> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final raw = keyword.trim();
    if (raw.isEmpty || page != 1 || pageSize < 1 || pageSize > LookliveEndpoints.maxSearchSize) {
      return (rooms: const <LiveRoom>[], hasMore: null);
    }
    final roomId = LookliveEndpoints.roomIdOf(raw);
    if (roomId != null) {
      try {
        return (rooms: [await detail(roomId, withMedia: false)], hasMore: null);
      } on LookliveFailure catch (failure) {
        if (failure.kind != LookliveFailureKind.notFound) rethrow;
        return (rooms: const <LiveRoom>[], hasMore: null);
      }
    }
    if (_isLink(raw)) return (rooms: const <LiveRoom>[], hasMore: null);
    final query = raw.toLowerCase();
    final result = await _scoped((token) => _page(1, null, token));
    final rooms = [for (final room in result.rooms) LookliveRoomParser.liveRoom(_keep(room))];
    return (rooms: rooms.where((room) => _matches(room, query)).take(pageSize).toList(), hasMore: null);
  }

  /// Whether [input] is a link (`scheme://…`) rather than a keyword.
  static bool _isLink(String input) {
    final uri = Uri.tryParse(input);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  /// Whether [room] matches the lower-case [query]: in its number, name or
  /// title.
  static bool _matches(LiveRoom room, String query) =>
      room.roomId.contains(query) ||
      (room.anchor?.name.toLowerCase().contains(query) ?? false) ||
      room.content.title.toLowerCase().contains(query);

  // Rooms ---------------------------------------------------------------------

  /// [roomId] as a room number (a room link is read too); anything else is
  /// not-found without a request.
  String _roomId(String roomId) =>
      LookliveEndpoints.roomIdOf(roomId) ??
      (throw LookliveFailure(LookliveFailureKind.notFound, 'room id "${roomId.trim()}" is not a room number'));

  /// The room answer of [roomId], with its streams when [withMedia] and live,
  /// completed from the last card or answer of the room, which it then
  /// replaces.
  Future<LookliveRoom> _answer(String roomId, {required bool withMedia}) async {
    final number = _roomId(roomId);
    final response = await _scoped(
      (token) => http.post(LookliveEndpoints.roomPath, LookliveEndpoints.roomPayload(number), cancel: token),
    );
    return _keep(LookliveRoomParser.room(response.text, roomId: number, withMedia: withMedia, status: response.status));
  }

  /// Room entry: the room answer with its streams and, for a live room with
  /// a chatroom, its chat arguments. The answer is kept as the streams the
  /// playback capability hands out.
  Future<LiveRoom> detail(String roomId, {bool withMedia = true}) async {
    final room = await _answer(roomId, withMedia: withMedia);
    if (withMedia) _entries[room.roomId] = room;
    return LookliveRoomParser.liveRoom(room, withData: withMedia);
  }

  // Streams -------------------------------------------------------------------

  /// The room answer [roomId]'s streams come from: the one its room entry
  /// brought (no request), else a fresh entry — the capabilities are asked by
  /// room id alone. An answer that cannot be played says why.
  Future<LookliveRoom> _playable(String roomId) async {
    final number = _roomId(roomId);
    var room = _entries[number];
    if (room == null) {
      await detail(number);
      room = _entries[number]!;
    }
    final error = room.streamError;
    if (error != null) throw error;
    return room;
  }

  /// The qualities [roomId] offers now, one per stream, HLS first.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async =>
      LookliveRoomParser.qualities(await _playable(roomId));

  /// The line of [roomId] at [quality] (the first stream the room offers
  /// when it is null).
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async {
    final room = await _playable(roomId);
    final id = quality?.qualityId ?? (room.variants.isEmpty ? '' : room.variants.first.id);
    return [LookliveRoomParser.line(room, id)];
  }

  // Capability wiring ---------------------------------------------------------

  LookliveRoomProvider? _room;
  LookliveAreaProvider? _area;
  LookliveDiscoveryProvider? _discovery;
  LookliveSearchProvider? _search;
  LooklivePlaybackProvider? _playback;
  LookliveDanmakuProvider? _danmaku;
  LookliveLinkResolver? _link;

  /// The capability of type [T], or null when LOOK Live does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= LookliveRoomProvider(site: this);
    final area = _area ??= LookliveAreaProvider(site: this);
    final discovery = _discovery ??= LookliveDiscoveryProvider(site: this);
    final search = _search ??= LookliveSearchProvider(site: this);
    final playback = _playback ??= LooklivePlaybackProvider(site: this);
    final danmaku = _danmaku ??= LookliveDanmakuProvider(site: this);
    final link = _link ??= LookliveLinkResolver(site: this);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => area as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LiveDanmakuProvider) => danmaku as T,
      const (LiveLinkResolver) => link as T,
      _ => null,
    };
  }
}
