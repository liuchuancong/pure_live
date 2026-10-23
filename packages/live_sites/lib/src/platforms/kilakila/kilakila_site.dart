import 'dart:async';

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
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/kilakila/api/kilakila_endpoints.dart';
import 'package:live_sites/src/platforms/kilakila/api/kilakila_http.dart';
import 'package:live_sites/src/platforms/kilakila/capabilities/kilakila_area_provider.dart';
import 'package:live_sites/src/platforms/kilakila/capabilities/kilakila_discovery_provider.dart';
import 'package:live_sites/src/platforms/kilakila/capabilities/kilakila_link_resolver.dart';
import 'package:live_sites/src/platforms/kilakila/capabilities/kilakila_playback_provider.dart';
import 'package:live_sites/src/platforms/kilakila/capabilities/kilakila_room_provider.dart';
import 'package:live_sites/src/platforms/kilakila/capabilities/kilakila_search_provider.dart';
import 'package:live_sites/src/platforms/kilakila/danmaku/kilakila_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kilakila/danmaku/kilakila_danmaku_session.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_manifest.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_failure.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_link.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The KilaKila (克拉克拉) adapter (parsing in `parsers/`, the chat in
/// `danmaku/`): manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2).
///
/// A room is an anchor: its id is the anchor's uid, never the id of one
/// broadcast, so follows keep matching. Anonymous: no cookie, no account;
/// every request carries [KilakilaEndpoints.headers] and goes as `kilakila`.
/// Requests:
/// - the catalog is two fixed timelines, without a request;
/// - recommendations and the timelines are `pcLive/timeline` pages, ten a
///   page, up to [KilakilaEndpoints.maxPages] or
///   [KilakilaEndpoints.maxPagesWithoutNew] pages without a new anchor, an
///   anchor listed on an earlier page left out;
/// - search is the website's user search page (one request, the anchors'
///   state unknown), one profile request for a uid or anchor link, or
///   `getRoomInfo` and the profile for a broadcast link;
/// - room entry reads the profile, then the current broadcast's
///   `getRoomInfo`, which also holds the pull URLs.
///
/// Failures are [KilakilaFailure]s; an anchor is offline only when the
/// platform says it has no broadcast or its broadcast ended.
final class KilakilaSite implements LiveSite {
  /// Creates the adapter over [http]. [connect] makes the chat's socket
  /// (default [webSocketConnect]); [now] (the pull URLs' issue time) is
  /// injectable for tests.
  KilakilaSite({required this.http, this.connect = webSocketConnect, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Transport.
  final KilakilaHttp http;

  /// How the chat's socket is connected.
  final SocketConnector connect;

  final DateTime Function() _now;

  /// Before a timeline page, by `<type>/<page size>/<page>`: the anchors
  /// listed on the pages before it since page 1 of that timeline was last
  /// read, and how many of those pages in a row brought no new one.
  final Map<String, ({Set<String> listed, int idle})> _before = {};

  /// The stream data of the anchor whose room was entered last, by uid: the
  /// pull URLs the capabilities hand out until the next entry.
  final Map<String, KilakilaRoomData> _streams = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => kilakilaManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Catalog and directory -----------------------------------------------------

  /// Page [page] of [pageSize] rows of the timeline [areaId] names (the hot
  /// one when it is null). A page out of 1–100000, a [pageSize] out of 1–100
  /// or an area that is not a KilaKila timeline is a caller error, refused
  /// before any request. A page after the platform's last is empty and the
  /// last, without a request.
  ///
  /// An anchor listed on an earlier page of the same timeline and page size,
  /// since its page 1 was last read, is left out, and three pages in a row
  /// without a new anchor end the timeline (the timelines repeat their
  /// anchors). The record goes with the page: reading a page again gives the
  /// same rooms, reading page 1 again (a pull to refresh) starts over, and a
  /// page reached without the ones before it is only deduplicated within
  /// itself. No request is added.
  Future<({List<LiveRoom> rooms, bool hasMore})> timeline(int page, int pageSize, {String? areaId}) async {
    if (page < 1 || page > 100000) {
      throw KilakilaFailure(KilakilaFailureKind.invalidArgument, 'page $page is out of 1–100000');
    }
    if (pageSize < 1 || pageSize > 100) {
      throw KilakilaFailure(KilakilaFailureKind.invalidArgument, 'page size $pageSize is out of 1–100');
    }
    final type = KilakilaEndpoints.timelineTypeOf(areaId);
    if (type == null) {
      throw KilakilaFailure(KilakilaFailureKind.invalidArgument, 'area "$areaId" is not a KilaKila timeline');
    }
    if (page > KilakilaEndpoints.maxPages) {
      return (rooms: const <LiveRoom>[], hasMore: false);
    }
    final response = await http.get(KilakilaEndpoints.timelineUrl(type: type, page: page, pageSize: pageSize));
    final result = KilakilaRoomParser.timelinePage(
      response.text,
      page: page,
      pageSize: pageSize,
      type: type,
      status: response.status,
    );
    final chain = '$type/$pageSize/';
    if (page == 1) _before.removeWhere((key, _) => key.startsWith(chain));
    final before = _before['$chain$page'];
    final listed = {...?before?.listed};
    final rooms = [
      for (final broadcast in result.rooms)
        if (listed.add(broadcast.uid)) KilakilaRoomParser.room(broadcast),
    ];
    final idle = rooms.isEmpty ? (before?.idle ?? 0) + 1 : 0;
    final hasMore = result.hasMore && idle < KilakilaEndpoints.maxPagesWithoutNew;
    final next = '$chain${page + 1}';
    _before.remove(next);
    if (hasMore) _before[next] = (listed: Set.unmodifiable(listed), idle: idle);
    while (_before.length > 64) {
      _before.remove(_before.keys.first);
    }
    return (rooms: rooms, hasMore: hasMore);
  }

  // Search --------------------------------------------------------------------

  /// Anchors for [keyword]:
  /// - a page or page size below 1 is a caller error;
  /// - a blank keyword finds nothing, without a request;
  /// - a uid or an anchor link finds that anchor on page 1 only (one profile
  ///   request): its current broadcast's room, else the anchor, offline; an
  ///   unknown anchor finds nothing;
  /// - a broadcast link (a live room's share link) finds its anchor the same
  ///   way on page 1 only, after one `getRoomInfo`: two requests. An unknown
  ///   broadcast or a historical replay finds nothing;
  /// - another link or a number with a leading zero finds nothing, without a
  ///   request;
  /// - anything else is a keyword of the website's user search, one page a
  ///   request; the anchors' state is unknown there. A keyword over the
  ///   platform's limit is cut there; a page over 10000 or a page size over
  ///   100 is refused, without a request.
  Future<({List<LiveRoom> rooms, bool? hasMore})> search(String keyword, {int page = 1, int pageSize = 30}) async {
    if (page < 1) throw KilakilaFailure(KilakilaFailureKind.invalidArgument, 'page $page is below 1');
    if (pageSize < 1) throw KilakilaFailure(KilakilaFailureKind.invalidArgument, 'page size $pageSize is below 1');
    final input = keyword.trim();
    final link = _searchLink(input);
    if (link == null) {
      if (!_pages(input)) return (rooms: const <LiveRoom>[], hasMore: null);
      if (page > 10000) {
        throw KilakilaFailure(KilakilaFailureKind.invalidArgument, 'page $page is out of 1–10000');
      }
      if (pageSize > 100) {
        throw KilakilaFailure(KilakilaFailureKind.invalidArgument, 'page size $pageSize is out of 1–100');
      }
      final response = await http.get(KilakilaEndpoints.searchUrl(input, page));
      return (rooms: KilakilaRoomParser.searchPage(response.text, status: response.status), hasMore: null);
    }
    if (page > 1) return (rooms: const <LiveRoom>[], hasMore: null);
    try {
      final uid = switch (link.kind) {
        KilakilaLinkKind.owner => link.id,
        KilakilaLinkKind.broadcast => await _anchorOf(link.id),
      };
      final owner = await profile(uid);
      final current = owner.current;
      return (
        rooms: [if (current != null) KilakilaRoomParser.room(current) else KilakilaRoomParser.profileRoom(owner)],
        hasMore: null,
      );
    } on KilakilaFailure catch (failure) {
      if (failure.kind != KilakilaFailureKind.notFound) rethrow;
      return (rooms: const <LiveRoom>[], hasMore: null);
    }
  }

  /// Whether a keyword [input] is paged: not blank, not a uid, not a link
  /// and not a bare number.
  static bool _pages(String input) =>
      input.isNotEmpty && _searchLink(input) == null && !RegExp(r'^[0-9]+$').hasMatch(input) && !_isLink(input);

  /// The anchor or broadcast [input] names exactly: a uid, or a link.
  static KilakilaLink? _searchLink(String input) =>
      KilakilaEndpoints.isId(input) ? KilakilaLink(KilakilaLinkKind.owner, input) : KilakilaLink.parse(input);

  /// Whether [input] is a link (`scheme://…`) rather than a keyword.
  static bool _isLink(String input) {
    final uri = Uri.tryParse(input);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  // Rooms ---------------------------------------------------------------------

  /// The profile of the anchor [uid]; an id that is not a uid is not-found
  /// without a request.
  Future<KilakilaProfile> profile(String uid) async {
    final id = uid.trim();
    if (!KilakilaEndpoints.isId(id)) {
      throw KilakilaFailure(KilakilaFailureKind.notFound, 'not a uid: $id');
    }
    final response = await http.get(KilakilaEndpoints.profileUrl(id));
    return KilakilaRoomParser.profile(response.text, uid: id, status: response.status);
  }

  /// The anchor of the broadcast [broadcastId], for a share link's
  /// resolver (one `getRoomInfo`).
  Future<String> resolveBroadcast(String broadcastId) => _anchorOf(broadcastId);

  /// The anchor of the broadcast [broadcastId] (one `getRoomInfo`); an
  /// unknown broadcast is not-found, and so is a historical replay (5966),
  /// whose answer names no anchor.
  Future<String> _anchorOf(String broadcastId) async {
    final response = await http.get(KilakilaEndpoints.roomInfoUrl(broadcastId));
    try {
      return KilakilaRoomParser.roomInfo(response.text, broadcastId: broadcastId, status: response.status).uid;
    } on KilakilaFailure catch (failure) {
      if (failure.kind != KilakilaFailureKind.streamUnavailable) rethrow;
      throw KilakilaFailure(KilakilaFailureKind.notFound, 'no anchor for $broadcastId (${failure.message})');
    }
  }

  /// Room entry: the profile, then the current broadcast's `getRoomInfo`
  /// (which must be this anchor's) with the pull URLs; the room keeps the
  /// card's start, listeners now and cover, and carries its stream data and
  /// the chat's broadcast. An anchor without a current broadcast is its
  /// profile, offline (one request). A broadcast that ended between the two
  /// requests cannot be played: stream-unavailable. A paid or not-live
  /// broadcast is still entered; its stream says why it cannot play.
  Future<LiveRoom> detail(String roomId) async {
    final profile = await this.profile(roomId);
    final current = profile.current;
    final data = KilakilaRoomData(issuedAt: _now());
    if (current == null) {
      _streams[profile.uid] = data;
      return KilakilaRoomParser.profileDetail(profile)
          .rebuild((b) => b..runtime = RoomRuntime.of(streamHandle: data).toBuilder());
    }
    final KilakilaBroadcast broadcast;
    try {
      final response = await http.get(KilakilaEndpoints.roomInfoUrl(current.broadcastId));
      broadcast = KilakilaRoomParser.roomInfo(
        response.text,
        broadcastId: current.broadcastId,
        uid: profile.uid,
        status: response.status,
      );
    } on KilakilaFailure catch (failure) {
      if (failure.kind != KilakilaFailureKind.notFound) rethrow;
      throw KilakilaFailure(
        KilakilaFailureKind.streamUnavailable,
        'the current broadcast is gone (${failure.message})',
      );
    }
    final entered = KilakilaRoomData(issuedAt: _now(), broadcast: broadcast);
    _streams[profile.uid] = entered;
    return KilakilaRoomParser.enteredRoom(profile, broadcast).rebuild(
      (b) => b
        ..runtime = RoomRuntime.of(
          streamHandle: entered,
          danmakuHandle: KilakilaDanmakuArgs(roomId: broadcast.broadcastId),
        ).toBuilder(),
    );
  }

  // Streams -------------------------------------------------------------------

  /// The stream data of [roomId]: the one its room entry brought, or a fresh
  /// entry — the capabilities are asked by room id alone. An anchor the
  /// platform called offline has no stream, without a request.
  Future<KilakilaRoomData> _stream(String roomId) async {
    final data = _streams[roomId];
    if (data != null) return data;
    await detail(roomId);
    return _streams[roomId]!;
  }

  /// The one quality 原画, from the stream data room entry brought: no
  /// request. An anchor without a broadcast, one that is over, a paid one or
  /// one without a pull URL says why.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async => KilakilaRoomParser.qualities(await _stream(roomId));

  /// The lines of [quality] (FLV, then HLS) with the media headers and their
  /// leases; the stored ids `flv` and `hls` name the same quality.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async {
    final id = quality?.qualityId ?? KilakilaEndpoints.qualityId;
    return KilakilaRoomParser.lines(await _stream(roomId), id);
  }

  // Capability wiring ---------------------------------------------------------

  KilakilaRoomProvider? _room;
  KilakilaAreaProvider? _area;
  KilakilaDiscoveryProvider? _discovery;
  KilakilaSearchProvider? _search;
  KilakilaPlaybackProvider? _playback;
  KilakilaDanmakuProvider? _danmaku;
  KilakilaLinkResolver? _link;

  /// The capability of type [T], or null when KilaKila does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= KilakilaRoomProvider(site: this);
    final area = _area ??= KilakilaAreaProvider(site: this);
    final discovery = _discovery ??= KilakilaDiscoveryProvider(site: this);
    final search = _search ??= KilakilaSearchProvider(site: this);
    final playback = _playback ??= KilakilaPlaybackProvider(site: this);
    final danmaku = _danmaku ??= KilakilaDanmakuProvider(site: this);
    final link = _link ??= KilakilaLinkResolver(site: this);
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
