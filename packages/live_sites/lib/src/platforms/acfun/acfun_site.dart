import 'dart:async';
import 'dart:math';

import 'package:live_net/live_net.dart';

// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

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
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/acfun/acfun_manifest.dart';
import 'package:live_sites/src/platforms/acfun/api/acfun_endpoints.dart';
import 'package:live_sites/src/platforms/acfun/api/acfun_http.dart';
import 'package:live_sites/src/platforms/acfun/capabilities/acfun_area_provider.dart';
import 'package:live_sites/src/platforms/acfun/capabilities/acfun_discovery_provider.dart';
import 'package:live_sites/src/platforms/acfun/capabilities/acfun_link_resolver.dart';
import 'package:live_sites/src/platforms/acfun/capabilities/acfun_playback_provider.dart';
import 'package:live_sites/src/platforms/acfun/capabilities/acfun_room_provider.dart';
import 'package:live_sites/src/platforms/acfun/capabilities/acfun_search_provider.dart';
import 'package:live_sites/src/platforms/acfun/danmaku/acfun_danmaku_codec.dart';
import 'package:live_sites/src/platforms/acfun/danmaku/acfun_danmaku_session.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_failure.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_play_parser.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How long a visitor session is reused.
const Duration _visitorLifetime = Duration(minutes: 5);

/// The budget of one search page, every server page it reads included.
const Duration _defaultSearchTimeout = Duration(seconds: 8);

/// Server pages one search page may read before the answer counts as broken.
const int _maxSearchRequests = 4;

/// Listings (a page size and filter), cursors per listing and searches kept.
const int _maxListings = 12;
const int _maxCursors = 64;
const int _maxSearches = 8;

/// Where a page of a listing starts: its cursor and the rooms the pages before
/// it listed.
typedef _PageStart = ({String cursor, Set<String> listed});

/// One listing (a page size and filter): where the pages read so far lead, the
/// page that said "no more", and the pages being read.
final class _Listing {
  final Map<int, _PageStart> next = {};
  final Map<int, Future<List<LiveRoom>>> pending = {};
  int? lastPage;

  _PageStart? startOf(int page) => page <= 1 ? (cursor: '', listed: const <String>{}) : next[page];
}

/// One author search (a keyword and page size): the rows of the last server
/// page not served yet, the next pages, and the page being read.
final class _Search {
  /// A search whose next page is [page] of [size]: the page's first row is
  /// found assuming full server pages (a new search starts at page 1).
  _Search.at(int page, int size)
    : nextPage = page,
      nextServerPage = (page - 1) * size ~/ AcfunEndpoints.searchPageSize + 1,
      skip = (page - 1) * size % AcfunEndpoints.searchPageSize;

  List<LiveRoom> remaining = const [];
  int nextPage;
  int nextServerPage;

  /// Rows of [nextServerPage] already served before this search started.
  int skip;
  bool finished = false;
  Future<List<LiveRoom>>? inFlight;
  int? inFlightPage;
  CancelToken? cancel;
}

/// The AcFun adapter: manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2).
///
/// Everything is anonymous. Lists, details and search need no session; streams
/// come from `startPlay`, asked with a visitor session kept in memory for five
/// minutes and shared by concurrent callers, logged in with a random `web_…`
/// device id. The directory and the author search are cursor-paged by the site
/// and served here by page number. A live paid show stays live, marked
/// [LiveRestriction.paid], and its streams are unavailable — the anonymous
/// visitor can never hold a ticket. Failures are [AcfunFailure]s; nothing is
/// disguised as an offline room.
final class AcfunSite implements LiveSite {
  /// Creates the adapter over [http]. [now], [random] (the visitor's device id,
  /// the payloads' IVs) and [searchTimeout] are injectable for tests.
  factory AcfunSite({required AcfunHttp http, DateTime Function()? now, Random? random, Duration? searchTimeout}) {
    final source = random ?? Random.secure();
    return AcfunSite._(http, now ?? DateTime.now, source, searchTimeout ?? _defaultSearchTimeout);
  }

  AcfunSite._(this.http, this.now, this._random, this._searchTimeout);

  /// Transport (the catalog, the room, the search page and the gift table).
  final AcfunHttp http;

  /// Injectable clock (the visitor session's expiry, the URLs' leases).
  final DateTime Function() now;

  final Random _random;
  final Duration _searchTimeout;

  ({AcfunVisitor visitor, DateTime expiresAt})? _visitor;
  Future<AcfunVisitor>? _login;
  final Map<String, _Listing> _listings = {};
  final Map<(String, int), _Search> _searches = {};
  final Map<String, ({Future<AcfunGiftCatalog> gifts, DateTime at, bool failed})> _giftLists = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => acfunManifest;

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

  /// The headers of every API request.
  Map<String, String> apiHeaders() => const {'user-agent': AcfunEndpoints.userAgent, 'referer': AcfunEndpoints.referer};

  /// The headers of author search; without a browser UA the site answers 403.
  Map<String, String> searchHeaders() => const {
    'user-agent': AcfunEndpoints.userAgent,
    'referer': 'https://www.acfun.cn/search',
  };

  /// The author id of a room id; anything else is not-found without a request.
  static String authorId(String roomId) {
    final id = roomId.trim();
    if (!AcfunEndpoints.isAuthorId(id)) {
      throw AcfunFailure(AcfunFailureKind.notFound, 'room id "$id" is not an AcFun author id');
    }
    return id;
  }

  // Visitor session -----------------------------------------------------------

  /// The visitor session, reused for five minutes; concurrent callers share one
  /// login. [fresh] logs in again (a new device id), which is what a refused
  /// session needs.
  Future<AcfunVisitor> session({bool fresh = false}) async {
    final cached = _visitor;
    if (!fresh && cached != null && now().isBefore(cached.expiresAt)) return cached.visitor;
    final pending = _login;
    if (pending != null) return await pending;
    final login = _loginOnce();
    _login = login;
    try {
      return await login;
    } finally {
      _login = null;
    }
  }

  Future<AcfunVisitor> _loginOnce() async {
    final deviceId = AcfunEndpoints.deviceId(_random);
    final response = await http.postForm(
      AcfunEndpoints.visitorLogin(),
      fields: const {'sid': AcfunEndpoints.visitorSid},
      headers: {...apiHeaders(), 'cookie': '_did=$deviceId;'},
    );
    final visitor = AcfunRoomParser.visitor(response.text, deviceId: deviceId, status: response.status);
    _visitor = (visitor: visitor, expiresAt: now().add(_visitorLifetime));
    return visitor;
  }

  /// `startPlay` for [id]. A refused session is dropped and the request made
  /// once more with a new one; a second refusal reports it. An ended broadcast
  /// is stream-unavailable and a paid show has no broadcast data; both keep the
  /// session.
  Future<({AcfunPlayResult result, AcfunVisitor visitor})> startPlay(String id) async {
    for (var attempt = 0; ; attempt++) {
      final visitor = await session(fresh: attempt > 0);
      final response = await http.postForm(
        AcfunEndpoints.startPlay(visitor),
        fields: {'authorId': id, 'pullStreamType': 'FLV'},
        headers: apiHeaders(),
      );
      try {
        return (
          result: AcfunRoomParser.startPlay(response.text, issuedAt: now(), status: response.status),
          visitor: visitor,
        );
      } on AcfunFailure catch (failure) {
        if (failure.kind != AcfunFailureKind.riskControl) rethrow;
        if (identical(_visitor?.visitor, visitor)) _visitor = null;
        if (attempt > 0) rethrow;
      }
    }
  }

  // Rooms ---------------------------------------------------------------------

  /// `api/live/info` only: what a refresh needs, and never a visitor session.
  Future<LiveRoom> info(String roomId) async {
    final id = authorId(roomId);
    final response = await http.get(AcfunEndpoints.roomInfo(id), headers: apiHeaders());
    return AcfunRoomParser.roomDetail(response.text, authorId: id, status: response.status);
  }

  /// The room with its broadcast and danmaku arguments: `live/info`, then
  /// `startPlay` when it says live. `startPlay` decides the restriction, and
  /// the start time comes from `live/info` else from it.
  Future<LiveRoom> detail(String roomId) async {
    final room = await info(roomId);
    if (!room.broadcast.isLiveNow) return room;
    final play = await startPlay(room.roomId);
    final data = play.result.data;
    if (data == null)
      return room.rebuild(
        (b) => b..broadcast.replace(room.broadcast.rebuild((b) => b..restriction = play.result.restriction)),
      );
    return room.rebuild(
      (b) => b
        ..runtime = RoomRuntime.of(
          streamHandle: data,
          danmakuHandle: danmakuArgs(room.roomId, data, play.result, play.visitor),
        ).toBuilder()
        ..broadcast.replace(
          room.broadcast.rebuild(
            (b) => b
              ..startedAt = room.broadcast.startedAt ?? data.startedAt
              ..restriction = play.result.restriction,
          ),
        ),
    );
  }

  /// The danmaku arguments of one `startPlay` answer, with the callbacks a
  /// dead session uses to ask for a new one.
  AcfunDanmakuArgs danmakuArgs(String authorId, AcfunRoomData data, AcfunPlayResult play, AcfunVisitor visitor) =>
      AcfunDanmakuArgs(
        authorId: authorId,
        liveId: data.liveId,
        visitor: visitor,
        tickets: play.tickets,
        enterRoomAttach: play.enterRoomAttach,
        refresh: () => danmakuArgsFromSession(authorId),
        gifts: () => giftCatalog(authorId, liveId: data.liveId),
      );

  /// Danmaku arguments from a new visitor session and a new `startPlay`
  /// (tickets are per session). A broadcast that ended, or a paid show with no
  /// tickets, is stream-unavailable.
  Future<AcfunDanmakuArgs> danmakuArgsFromSession(String authorId) async {
    final id = authorId.trim();
    final play = await startPlay(id);
    final data = play.result.data;
    if (data == null) {
      throw AcfunFailure(AcfunFailureKind.streamUnavailable, '$id: restricted room (${play.result.restriction.name})');
    }
    return danmakuArgs(id, data, play.result, play.visitor);
  }

  // Catalog -------------------------------------------------------------------

  /// How long the listed areas are reused, so paging an area does not re-read
  /// the catalog every page.
  static const Duration areasLifetime = Duration(minutes: 5);

  ({List<LiveArea> areas, DateTime at})? _areas;

  /// The areas of a one-room list answer, under the site's own display name,
  /// reused for [areasLifetime]; no listing's cursors are touched.
  Future<List<LiveArea>> areas() async {
    final cached = _areas;
    if (cached != null && now().difference(cached.at) < areasLifetime) return cached.areas;
    final response = await http.get(AcfunEndpoints.channelList(count: 1), headers: apiHeaders());
    final areas = AcfunRoomParser.areas(response.text, typeName: 'AcFun 直播', status: response.status);
    _areas = (areas: areas, at: now());
    return areas;
  }

  /// The `filters` query of the area id [areaId]: its filter type and id, as
  /// [areas] wrote them into the id. An empty id asks for nothing (the
  /// recommendations), a stored `全部` area is the recommendations too (3.x
  /// listed it), and an id that does not name a filter pair is not-found.
  String? filtersFor(String areaId) {
    final id = areaId.trim();
    if (id.isEmpty) return null;
    final parts = id.split(':');
    final type = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final filter = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (type == null || filter == null) {
      throw AcfunFailure(AcfunFailureKind.notFound, 'area $areaId is not an AcFun area id');
    }
    return filter == AcfunEndpoints.allFilterId ? null : AcfunEndpoints.filterQuery(type: type, id: filter);
  }

  /// Page [page] of the directory filtered by [filters] (null: every live room
  /// by popularity, the recommendations).
  Future<({List<LiveRoom> rooms, bool hasMore, String? nextCursor})> listing({
    required int page,
    required int pageSize,
    String? filters,
  }) async {
    final number = page < 1 ? 1 : page;
    final count = pageSize.clamp(1, 60);
    final listing = _listing(count, filters);
    final rooms = await _page(listing, number, count, filters);
    final last = listing.lastPage;
    return (rooms: rooms, hasMore: last == null || number < last, nextCursor: listing.next[number + 1]?.cursor);
  }

  /// The listing of [count] and [filters] a page is read from: a new chain for
  /// a first-page read, unless the first page is loading.
  _Listing _listing(int count, String? filters) {
    final key = '$count ${filters ?? ''}';
    final listing = _listings.remove(key) ?? _Listing();
    _listings[key] = listing;
    while (_listings.length > _maxListings) {
      _listings.remove(_listings.keys.first);
    }
    return listing;
  }

  /// Page [page] of [listing]. A first-page read starts a new chain of cursors;
  /// a page after the last one is empty without a request. When the chain lost
  /// this page's cursor (a refresh by another list, an evicted listing) the
  /// pages before it are read again rather than failing.
  Future<List<LiveRoom>> _page(_Listing listing, int page, int count, String? filters) {
    final pending = listing.pending[page];
    if (pending != null) return pending;
    final last = listing.lastPage;
    if (last != null && page > last) return Future<List<LiveRoom>>.value(const []);
    final start = listing.startOf(page);
    if (start == null) {
      return _page(listing, page - 1, count, filters).then((_) => _page(listing, page, count, filters));
    }
    return listing.pending[page] = _load(listing, page, start, count, filters);
  }

  /// Reads page [page] from [start]. A room an earlier page of this chain
  /// listed, or one repeated on this page, is left out: the ranking shifts
  /// between reads. The same answer read again gives the same page.
  Future<List<LiveRoom>> _load(_Listing listing, int page, _PageStart start, int count, String? filters) async {
    try {
      final response = await http.get(
        AcfunEndpoints.channelList(count: count, cursor: start.cursor, filters: filters),
        headers: apiHeaders(),
      );
      final result = AcfunRoomParser.directory(response.text, status: response.status);
      final listed = {...start.listed};
      final rooms = [
        for (final room in result.rooms)
          if (listed.add(room.roomId)) room,
      ];
      final next = result.next;
      if (next == null) {
        listing.lastPage = page;
      } else {
        // A cursor this chain already used cannot lead anywhere new.
        for (var earlier = 1; earlier <= page; earlier++) {
          if (listing.startOf(earlier)?.cursor == next) {
            throw AcfunFailure(
              AcfunFailureKind.apiChanged,
              'channel/list: page $page repeats the cursor of page $earlier',
            );
          }
        }
        if (listing.lastPage == page) listing.lastPage = null;
        listing.next[page + 1] = (cursor: next, listed: Set.unmodifiable(listed));
        while (listing.next.length > _maxCursors) {
          listing.next.remove(listing.next.keys.reduce(min));
        }
      }
      return rooms;
    } finally {
      // The removal hands back the page's own future, which this caller is
      // already returning to its caller.
      unawaited(listing.pending.remove(page));
    }
  }

  // Search --------------------------------------------------------------------

  /// Authors matching [keyword], live or not, cut from the site's own 30-row
  /// server pages, so a short server page never ends the results early. A page
  /// takes at most [_searchTimeout] and [_maxSearchRequests] server pages; a
  /// first-page read restarts the search and cancels the previous one's
  /// requests. A blank keyword gives nothing without a request.
  Future<List<LiveRoom>> search(String keyword, int page, int pageSize) async {
    final text = keyword.trim();
    if (text.isEmpty) return const [];
    final number = page < 1 ? 1 : page;
    final size = pageSize.clamp(1, 60);
    final key = (text, size);
    var entry = _searches.remove(key);
    if (number == 1 && entry?.inFlightPage != 1) {
      entry?.cancel?.cancel('restarted');
      entry = null;
    }
    entry ??= _Search.at(number, size);
    _searches[key] = entry;
    while (_searches.length > _maxSearches) {
      _searches.remove(_searches.keys.first)?.cancel?.cancel('evicted');
    }
    final running = entry.inFlight;
    if (running != null) {
      if (entry.inFlightPage == number) return await running;
      // Another page is loading: wait for it and be served after it.
      try {
        await running;
      } on Object {
        // That page's caller sees its failure.
      }
      return await search(keyword, number, size);
    }
    if (entry.finished && entry.remaining.isEmpty && number >= entry.nextPage) return const [];
    if (number != entry.nextPage) {
      // Not the page after the last one served (the search was restarted or
      // evicted): start again at the page's position.
      entry = _searches[key] = _Search.at(number, size);
    }
    entry.inFlightPage = number;
    return await (entry.inFlight = _collect(key, entry));
  }

  Future<List<LiveRoom>> _collect((String, int) key, _Search search) async {
    final cancel = CancelToken();
    search.cancel = cancel;
    try {
      return await _fill(key, search, cancel);
    } finally {
      // A timeout alone would leave the request running.
      cancel.cancel('done');
      search
        ..cancel = null
        ..inFlight = null
        ..inFlightPage = null;
    }
  }

  /// One page from the rows left over and the next server pages. Only a whole
  /// page is committed: a failure leaves the search where it was, so the same
  /// page can be asked for again.
  Future<List<LiveRoom>> _fill((String, int) key, _Search search, CancelToken cancel) async {
    final (keyword, size) = key;
    var remaining = search.remaining;
    var serverPage = search.nextServerPage;
    var finished = search.finished;
    var skip = search.skip;
    var requests = 0;
    final result = <LiveRoom>[];
    while (result.length < size) {
      if (cancel.isCancelled) throw const AcfunFailure(AcfunFailureKind.network, 'search restarted');
      if (remaining.isEmpty) {
        if (finished) break;
        if (++requests > _maxSearchRequests) {
          throw const AcfunFailure(AcfunFailureKind.apiChanged, 'search: 4 server pages without authors');
        }
        final answer = await _searchPage(keyword, serverPage, cancel);
        remaining = answer.rooms.skip(skip).toList();
        skip = 0;
        finished = serverPage * AcfunEndpoints.searchPageSize >= answer.total;
        serverPage++;
      }
      final take = min(size - result.length, remaining.length);
      result.addAll(remaining.take(take));
      remaining = remaining.sublist(take);
    }
    if (cancel.isCancelled || !identical(_searches[key], search)) {
      throw const AcfunFailure(AcfunFailureKind.network, 'search restarted');
    }
    search
      ..remaining = remaining
      ..nextServerPage = serverPage
      ..finished = finished
      ..skip = 0
      ..nextPage += 1;
    return result;
  }

  Future<({List<LiveRoom> rooms, int total})> _searchPage(String keyword, int page, CancelToken cancel) async {
    final response = await http.get(
      AcfunEndpoints.search(keyword, page),
      headers: searchHeaders(),
      cancel: cancel,
      timeout: _searchTimeout,
    );
    return AcfunRoomParser.searchPage(response.text, page: page, status: response.status);
  }

  // Gifts ---------------------------------------------------------------------

  /// How long a room's gift table is reused.
  static const Duration giftListLifetime = Duration(minutes: 30);

  /// How long a failed gift table is not asked for again.
  static const Duration giftRetryAfter = Duration(minutes: 5);

  /// Rooms whose gift tables are kept; the least recent goes first.
  static const int giftListRooms = 16;

  /// Room [authorId]'s gift table (`gift/list`, asked with the visitor session
  /// and the broadcast's id): fetched once for concurrent callers and reused
  /// for [giftListLifetime]; one that fails counts as empty and is asked for
  /// again after [giftRetryAfter]. Never throws: no table leaves the danmaku
  /// without gift names and prices.
  Future<AcfunGiftCatalog> giftCatalog(String authorId, {required String liveId}) {
    final id = authorId.trim();
    final cached = _giftLists.remove(id);
    if (cached != null) {
      final age = now().difference(cached.at);
      if (age >= Duration.zero && age < (cached.failed ? giftRetryAfter : giftListLifetime)) {
        _giftLists[id] = cached;
        return cached.gifts;
      }
    }
    final at = now();
    late final Future<AcfunGiftCatalog> gifts;
    gifts = () async {
      try {
        final visitor = await session();
        final response = await http.postForm(
          AcfunEndpoints.giftList(visitor),
          fields: {'visitorId': visitor.userId, 'liveId': liveId},
          headers: apiHeaders(),
        );
        return AcfunRoomParser.giftList(response.text, status: response.status);
      } on Object {
        if (identical(_giftLists[id]?.gifts, gifts)) {
          _giftLists[id] = (gifts: Future.value(AcfunGiftCatalog.empty), at: now(), failed: true);
        }
        return AcfunGiftCatalog.empty;
      }
    }();
    _giftLists[id] = (gifts: gifts, at: at, failed: false);
    while (_giftLists.length > giftListRooms) {
      _giftLists.remove(_giftLists.keys.first);
    }
    return gifts;
  }

  // Streams -------------------------------------------------------------------

  /// The qualities of the broadcast the room carries; a room that is not
  /// playable, or is restricted, is stream-unavailable without a request, and
  /// a room that names no broadcast (a list card) gets a fresh `startPlay`.
  Future<List<AcfunQuality>> qualities(LiveRoom room, {bool fresh = false}) async {
    final data = await broadcast(room, fresh: fresh);
    return data.qualities;
  }

  /// The broadcast behind [room]: the stream handle it carries, else a new
  /// `startPlay` (a list card names no broadcast, and recovery needs new
  /// URLs).
  Future<AcfunRoomData> broadcast(LiveRoom room, {bool fresh = false}) async {
    if (!fresh) {
      if (room.runtime.streamHandle case final AcfunRoomData data) return data;
      if (room.broadcast.isExplicitlyOfflineNow) {
        throw AcfunFailure(
          AcfunFailureKind.streamUnavailable,
          '${room.roomId} is ${room.broadcast.effectiveLiveStatus.name}',
        );
      }
      if (room.broadcast.isRestricted) {
        throw AcfunFailure(
          AcfunFailureKind.streamUnavailable,
          '${room.roomId}: restricted room (${room.broadcast.effectiveRestriction.name})',
        );
      }
    }
    final play = await startPlay(authorId(room.roomId));
    return play.result.data ??
        (throw AcfunFailure(
          AcfunFailureKind.streamUnavailable,
          '${room.roomId}: restricted room (${play.result.restriction.name})',
        ));
  }

  // Capability wiring ---------------------------------------------------------

  AcfunRoomProvider? _room;
  AcfunAreaProvider? _area;
  AcfunDiscoveryProvider? _discovery;
  AcfunSearchProvider? _search;
  AcfunPlaybackProvider? _playback;
  AcfunDanmakuProvider? _danmaku;
  AcfunLinkResolver? _link;

  /// The capability of type [T], or null when acfun does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= AcfunRoomProvider(site: this);
    final area = _area ??= AcfunAreaProvider(site: this);
    final discovery = _discovery ??= AcfunDiscoveryProvider(site: this);
    final search = _search ??= AcfunSearchProvider(site: this);
    final playback = _playback ??= AcfunPlaybackProvider(site: this);
    final danmaku = _danmaku ??= AcfunDanmakuProvider(site: this);
    final link = _link ??= AcfunLinkResolver(site: this);
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
