// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'dart:async';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
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
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_endpoints.dart';
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_http.dart';
import 'package:live_sites/src/platforms/xiaohongshu/capabilities/xiaohongshu_area_provider.dart';
import 'package:live_sites/src/platforms/xiaohongshu/capabilities/xiaohongshu_danmaku_provider.dart';
import 'package:live_sites/src/platforms/xiaohongshu/capabilities/xiaohongshu_discovery_provider.dart';
import 'package:live_sites/src/platforms/xiaohongshu/capabilities/xiaohongshu_link_resolver.dart';
import 'package:live_sites/src/platforms/xiaohongshu/capabilities/xiaohongshu_play_recovery.dart';
import 'package:live_sites/src/platforms/xiaohongshu/capabilities/xiaohongshu_playback_provider.dart';
import 'package:live_sites/src/platforms/xiaohongshu/capabilities/xiaohongshu_room_provider.dart';
import 'package:live_sites/src/platforms/xiaohongshu/capabilities/xiaohongshu_room_refresh.dart';
import 'package:live_sites/src/platforms/xiaohongshu/capabilities/xiaohongshu_search_provider.dart';
import 'package:live_sites/src/platforms/xiaohongshu/capabilities/xiaohongshu_status_check.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_directory_parser.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_link.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_room_parser.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_guest.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How many room entries keep their stream data.
const _entryLimit = 512;

/// The Xiaohongshu adapter (3.x's `XiaohongshuSite`, `XiaohongshuApi` and
/// `XiaohongshuLink`; parsing in `parsers/`): manifest + capability
/// discovery + lifecycle (ARCHITECTURE.md §7.2).
///
/// Without a [guest] the adapter is link-only, as in 3.x: the website's
/// live list needs a signed login request, so the directory is always empty
/// and search looks up the one room a room id, share link, short link or
/// app deep link names. A room is its public share page, read anonymously
/// as `xiaohongshu` with [XiaohongshuEndpoints.headers]; the page also
/// holds the pull addresses (one quality per `quality_type`, its H.264 and
/// H.265 addresses as lines). Room ids are the broadcast rooms asked for:
/// following the streamer across broadcasts is blocked, see
/// [XiaohongshuRoomParser]. There is no danmaku (3.x's `EmptyDanmaku`), no
/// account and no start time.
///
/// A shell that injects a [XiaohongshuGuest] — its short-lived browser
/// bootstrap — also exposes the platform's own categories, the caller-owned
/// cursor feed behind them, and non-secret room chat arguments
/// (the reference's E02.16); the chat itself is the RWP socket in
/// `danmaku/`, whose credentials are obtained only on connection. A follow
/// still identifies this broadcast, not the streamer's next room. Failures
/// are [XiaohongshuFailure]s; nothing is disguised as an offline room, and
/// bootstrap refusals are never disguised as empty pages.
final class XiaohongshuSite implements LiveSite {
  /// Creates the adapter over [http]. [guest] is the anonymous web session,
  /// injected only where a browser backend exists.
  XiaohongshuSite({required this.http, this.guest});

  /// Transport.
  final XiaohongshuHttp http;

  /// Anonymous web session, injected only where the browser backend exists.
  final XiaohongshuGuest? guest;

  /// The stream data of the room whose entry was read last, by room id: the
  /// pull addresses the capabilities hand out until the next entry. A
  /// searched room is a card without stream data, as in 3.x, so playback
  /// reads the page again.
  final Map<String, XiaohongshuRoomData> _entries = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => xiaohongshuManifest;

  /// The directory notice's key, as 3.x switched it: the link-only scope
  /// without a visitor bootstrap, the guest scope with one (text:
  /// [XiaohongshuEndpoints.directoryScope] / [XiaohongshuEndpoints.guestDirectoryScope]).
  String get directoryNoticeKey =>
      guest == null ? XiaohongshuEndpoints.directoryNoticeKey : XiaohongshuEndpoints.guestDirectoryNoticeKey;

  /// The directory notice's user-facing text of [directoryNoticeKey]; the
  /// application shows it beside the directory.
  String get directoryNotice =>
      guest == null ? XiaohongshuEndpoints.directoryScope : XiaohongshuEndpoints.guestDirectoryScope;

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

  /// The share page of [roomId]: a room id that is not one is not-found
  /// without a request; the page is read with the platform's headers.
  Future<XiaohongshuPage> _read(String roomId) async {
    final id = roomId.trim();
    if (!XiaohongshuEndpoints.isRoomId(id)) {
      throw XiaohongshuFailure(XiaohongshuFailureKind.notFound, 'room id "$id" is not a Xiaohongshu room');
    }
    final response = await http.get(XiaohongshuEndpoints.roomUrl(id));
    return XiaohongshuRoomParser.room(response.text, requestedId: id, status: response.status);
  }

  /// Keeps [data] as the entry of its room, dropping the oldest past
  /// [_entryLimit].
  void _remember(XiaohongshuRoomData data) {
    _entries
      ..remove(data.roomId)
      ..[data.roomId] = data;
    if (_entries.length > _entryLimit) _entries.remove(_entries.keys.first);
  }

  // Directory -----------------------------------------------------------------

  /// The platform's categories, or an empty list without a guest (3.x shows
  /// its directory notice instead). Parsing in [XiaohongshuDirectoryParser].
  Future<List<LiveArea>> categories() async {
    final session = guest;
    if (session == null) return const [];
    return XiaohongshuDirectoryParser.categories(await session.categories());
  }

  /// The category id a feed page asks with: the "all" listing asks with `0`,
  /// anything else must be one of the platform's own categories (see
  /// [XiaohongshuEndpoints.isCategoryId]).
  String _categoryId(LiveArea? area) {
    if (area == null) return XiaohongshuEndpoints.firstCursor;
    if (area.platform != xiaohongshuSiteId || !XiaohongshuEndpoints.isCategoryId(area.areaId)) {
      throw XiaohongshuFailure(
        XiaohongshuFailureKind.invalidArgument,
        'category ${area.identityKey} is not a Xiaohongshu category',
      );
    }
    return area.areaId;
  }

  /// One feed page by caller-owned cursor, so refreshing or switching tabs
  /// cannot reuse another listing's cursor (the reference's
  /// `getDirectoryPageAtCursor`). Page 1 names no cursor, any later page
  /// names the one the page before it handed out; [category] null is the
  /// unfiltered listing. Without a guest the unfiltered listing is empty and
  /// a category is a caller error — the link-only adapter stays usable.
  Future<XiaohongshuFeedPage> directoryAtCursor({
    required int page,
    String? cursor,
    LiveArea? category,
    CancelToken? cancel,
  }) async {
    if (page < 1) throw XiaohongshuFailure(XiaohongshuFailureKind.invalidArgument, 'page $page is below 1');
    if ((page == 1) != (cursor == null)) {
      throw const XiaohongshuFailure(
        XiaohongshuFailureKind.invalidArgument,
        'cursor does not match page: page 1 asks without one, later pages with',
      );
    }
    final session = guest;
    if (session == null) {
      if (category != null) {
        throw const XiaohongshuFailure(
          XiaohongshuFailureKind.invalidArgument,
          'directory is unavailable in this shell',
        );
      }
      return (rooms: const <LiveRoom>[], hasMore: false, nextCursor: null);
    }
    final score = cursor ?? XiaohongshuEndpoints.firstCursor;
    if (score.isEmpty || score.length > XiaohongshuEndpoints.maxCursorLength) {
      throw const XiaohongshuFailure(XiaohongshuFailureKind.invalidArgument, 'cursor is not a feed score');
    }
    final body = await session.directory(category: _categoryId(category), cursor: score, cancel: cancel);
    return XiaohongshuDirectoryParser.page(body, cursor: score);
  }

  /// Compatibility paging, replaying cursors locally within
  /// [XiaohongshuEndpoints.directoryDeadline] and at most
  /// [XiaohongshuEndpoints.maxDirectoryPage] pages: a caller that names only
  /// a page number is walked there, one that carries [cursor] (the previous
  /// page's `nextCursor`) costs a single request, so refreshing or switching
  /// tabs cannot reuse another listing's cursor. [category] null is the
  /// unfiltered listing. Without a guest this stays the empty answer the
  /// link-only adapter always gave; nothing is requested.
  Future<XiaohongshuFeedPage> directory(int page, {String? cursor, LiveArea? category, CancelToken? cancel}) async {
    if (page < 1) throw XiaohongshuFailure(XiaohongshuFailureKind.invalidArgument, 'page $page is below 1');
    if (guest == null) {
      if (category != null) {
        throw const XiaohongshuFailure(
          XiaohongshuFailureKind.invalidArgument,
          'directory is unavailable in this shell',
        );
      }
      return (rooms: const <LiveRoom>[], hasMore: false, nextCursor: null);
    }
    if (cursor != null) {
      return await directoryAtCursor(page: page, cursor: cursor, category: category, cancel: cancel);
    }
    if (page > XiaohongshuEndpoints.maxDirectoryPage) {
      throw XiaohongshuFailure(
        XiaohongshuFailureKind.invalidArgument,
        'page $page is outside 1–${XiaohongshuEndpoints.maxDirectoryPage}',
      );
    }
    final owned = CancelToken();
    if (cancel != null) unawaited(cancel.whenCancel.then((_) => owned.cancel()));
    Future<XiaohongshuFeedPage> replay() async {
      String? walked;
      final shown = <String>{};
      for (var current = 1; ; current++) {
        final result = await directoryAtCursor(page: current, cursor: walked, category: category, cancel: owned);
        if (current == page) {
          return (
            rooms: [
              for (final room in result.rooms)
                if (!shown.contains(room.roomId)) room,
            ],
            hasMore: result.hasMore,
            nextCursor: result.nextCursor,
          );
        }
        if (!result.hasMore) return (rooms: const <LiveRoom>[], hasMore: false, nextCursor: null);
        shown.addAll(result.rooms.map((room) => room.roomId));
        walked = result.nextCursor;
      }
    }

    try {
      return await replay().timeout(XiaohongshuEndpoints.directoryDeadline);
    } on TimeoutException {
      throw const XiaohongshuFailure(XiaohongshuFailureKind.network, 'directory page took too long to walk to');
    } finally {
      owned.cancel();
    }
  }

  // Search --------------------------------------------------------------------

  /// The one room [keyword] names (3.x's exact lookup): a room id, a share
  /// page, an app deep link, or a short link followed within
  /// [XiaohongshuEndpoints.shortLinkTimeout]. Other keywords, and pages
  /// after the first, give nothing without a request. The room is the card
  /// alone (no stream data). A room that does not exist (HTTP 404, or the
  /// page's "未找到直播间") gives nothing; every other failure is thrown,
  /// as in 3.x.
  Future<({List<LiveRoom> rooms, bool? hasMore})> search(String keyword, {int page = 1}) async {
    if (page != 1) return (rooms: const <LiveRoom>[], hasMore: null);
    final text = keyword.trim();
    final roomId = XiaohongshuLink.roomIdFrom(text) ?? await shortLinkRoom(text);
    if (roomId == null) return (rooms: const <LiveRoom>[], hasMore: null);
    final answer = await http.get(XiaohongshuEndpoints.roomUrl(roomId));
    try {
      return (
        rooms: [XiaohongshuRoomParser.room(answer.text, requestedId: roomId, status: answer.status).room],
        hasMore: null,
      );
    } on XiaohongshuFailure catch (failure) {
      if (failure.kind != XiaohongshuFailureKind.notFound) rethrow;
      return (rooms: const <LiveRoom>[], hasMore: null);
    }
  }

  /// The room a short link [text] leads to, or null: the transport follows
  /// the redirect chain (3.x followed it hop by hop), so the room is read
  /// out of the answer it lands on — its `Location`, when the answer still
  /// names one, else the landing page's own state. A short link that cannot
  /// be followed within [XiaohongshuEndpoints.shortLinkTimeout] is no room,
  /// as 3.x's session timeout was.
  Future<String?> shortLinkRoom(String text) async {
    final start = XiaohongshuLink.shortLink(text);
    if (start == null) return null;
    final XiaohongshuResponse response;
    try {
      response = await http.get(start, timeout: XiaohongshuEndpoints.shortLinkTimeout);
    } on XiaohongshuFailure catch (failure) {
      if (failure.kind != XiaohongshuFailureKind.network) rethrow;
      return null;
    }
    final location = response.headers['location'];
    if (location != null) {
      final target = Uri.tryParse(location.trim());
      if (target != null) {
        final Uri resolved;
        try {
          resolved = start.resolveUri(target);
        } on FormatException {
          return XiaohongshuRoomParser.roomIdInPage(response.text);
        }
        final roomId = XiaohongshuLink.roomIdFrom('$resolved');
        if (roomId != null) return roomId;
      }
    }
    return XiaohongshuRoomParser.roomIdInPage(response.text);
  }

  // Rooms ---------------------------------------------------------------------

  /// Room entry: the share page, whose card carries the room and whose
  /// state the stream comes from. The entry's data is kept for the
  /// capabilities; with a guest the room also carries its non-secret chat
  /// arguments ([XiaohongshuDanmakuArgs]) — the credentials themselves are
  /// obtained only when a session connects.
  Future<LiveRoom> detail(String roomId) async {
    final page = await _read(roomId);
    _remember(page.data);
    return page.room.rebuild(
      (b) => b
        ..runtime = RoomRuntime.of(
          streamHandle: page.data,
          danmakuHandle: guest == null ? null : XiaohongshuDanmakuArgs(roomId: page.room.roomId),
        ).toBuilder(),
    );
  }

  // Streams -------------------------------------------------------------------

  /// The stream data of [roomId]: the one its room entry brought, or the
  /// page's now — the capabilities are asked by room id alone. An entered
  /// room that has ended says so without a request.
  Future<XiaohongshuRoomData> _stream(String roomId, {bool fresh = false}) async {
    final id = roomId.trim();
    final entry = fresh ? null : _entries[id];
    if (entry != null) return entry;
    return (await _read(id)).data;
  }

  /// The qualities of [roomId]'s stream: one per `quality_type`. A room
  /// that cannot be played says why.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async =>
      XiaohongshuRoomParser.qualities(XiaohongshuRoomParser.playable(await _stream(roomId)));

  /// The lines of [quality] (the first quality when it is null) in
  /// [roomId]'s stream, with the media headers; a 3.x quality id
  /// (`h264:HD`) plays its quality now.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality, bool fresh = false}) async =>
      XiaohongshuRoomParser.lines(await _stream(roomId, fresh: fresh), quality);

  // Capability wiring ---------------------------------------------------------

  XiaohongshuRoomProvider? _room;
  XiaohongshuDiscoveryProvider? _discovery;
  XiaohongshuSearchProvider? _search;
  XiaohongshuPlaybackProvider? _playback;
  XiaohongshuLinkResolver? _link;
  XiaohongshuRoomRefresh? _refresh;
  XiaohongshuStatusCheck? _status;
  XiaohongshuPlayRecovery? _recovery;
  XiaohongshuAreaProvider? _area;
  XiaohongshuDanmakuProvider? _danmaku;

  /// The capability of type [T], or null when Xiaohongshu does not support
  /// it (ARCHITECTURE.md §4.1): no areas and no danmaku without a visitor
  /// bootstrap (the link-only adapter of 3.x's `EmptyDanmaku`), both once a
  /// [XiaohongshuGuest] is injected. Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= XiaohongshuRoomProvider(site: this);
    final discovery = _discovery ??= XiaohongshuDiscoveryProvider(site: this);
    final search = _search ??= XiaohongshuSearchProvider(site: this);
    final playback = _playback ??= XiaohongshuPlaybackProvider(site: this);
    final link = _link ??= XiaohongshuLinkResolver(site: this);
    final refresh = _refresh ??= XiaohongshuRoomRefresh(site: this);
    final status = _status ??= XiaohongshuStatusCheck(refresh: refresh);
    final recovery = _recovery ??= XiaohongshuPlayRecovery(playback: playback);
    final area = guest == null ? null : (_area ??= XiaohongshuAreaProvider(site: this));
    final danmaku = guest == null ? null : (_danmaku ??= XiaohongshuDanmakuProvider(site: this));
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => area as T?,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LiveDanmakuProvider) => danmaku as T?,
      const (LiveLinkResolver) => link as T,
      const (LiveRoomRefresh) => refresh as T,
      const (LiveStatusCheck) => status as T,
      const (LivePlayRecovery) => recovery as T,
      _ => null,
    };
  }
}
