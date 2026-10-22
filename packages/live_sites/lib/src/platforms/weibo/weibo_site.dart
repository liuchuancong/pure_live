// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'package:live_sites/src/capabilities/live_area_provider.dart';
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
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/weibo/api/weibo_endpoints.dart';
import 'package:live_sites/src/platforms/weibo/api/weibo_http.dart';
import 'package:live_sites/src/platforms/weibo/capabilities/weibo_area_provider.dart';
import 'package:live_sites/src/platforms/weibo/capabilities/weibo_discovery_provider.dart';
import 'package:live_sites/src/platforms/weibo/capabilities/weibo_link_resolver.dart';
import 'package:live_sites/src/platforms/weibo/capabilities/weibo_playback_provider.dart';
import 'package:live_sites/src/platforms/weibo/capabilities/weibo_room_provider.dart';
import 'package:live_sites/src/platforms/weibo/capabilities/weibo_search_provider.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_failure.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_json.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_room_parser.dart';
import 'package:live_sites/src/platforms/weibo/weibo_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The Weibo Live (微博直播) adapter (parsing in `parsers/`): manifest +
/// capability discovery + lifecycle (ARCHITECTURE.md §7.2).
///
/// Anonymous, like the reference: no cookie, no account and no danmaku — the
/// platform has no chat the adapter could join, so no `LiveDanmakuProvider`
/// is offered. Every request carries [WeiboEndpoints.headers] and goes as
/// `weibo`. The requests are:
/// - the catalog is the one static area, without a request; the
///   recommendations, the area's rooms and the room directory are the
///   snapshot `pc_recommend/list.json?count=100` (one page; page 2 and later
///   are empty without a request, and callers' page sizes are not applied,
///   as in the reference);
/// - a nickname search filters that snapshot; a broadcast id or room link
///   finds that room; a `t.cn` short link is asked where it leads (18-9);
/// - room entry and every live playback read `room/show_pc_live.json`
///   (one request each) and play its FLV; there is no signed URL to reuse.
///   A replay plays its recording (18-5), from the room's last detail when
///   the site still holds it.
///
/// A room is one broadcast, not the anchor (see [WeiboEndpoints]). The data
/// of the room's last detail is kept per broadcast (see [detail]) as the
/// handle the playback reads. Failures are [WeiboFailure]s; nothing is
/// disguised as an offline room.
final class WeiboSite implements LiveSite {
  /// Creates the adapter over [http].
  WeiboSite({required this.http});

  /// Transport.
  final WeiboHttp http;

  /// How many broadcasts' detail data is kept; the oldest entry is dropped.
  static const int _detailLimit = 64;

  /// The data of the broadcast whose detail was read last, by broadcast id:
  /// the handle the playback gates read before asking the site again.
  final Map<String, WeiboRoomData> _details = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => weiboManifest;

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

  /// The one area, 公开推荐 under the platform itself, without a request.
  Future<List<LiveArea>> areas() => Future.value([WeiboEndpoints.area]);

  /// The snapshot, for the recommendations, the area and the directory alike:
  /// one page. A page after the first is empty, without a request; a page
  /// below 1 is a caller error. The request's page size is not applied, as in
  /// the reference: the snapshot answers whole.
  Future<({List<LiveRoom> rooms, bool hasMore})> snapshot({int page = 1}) async {
    _checkPage(page);
    if (page > 1) return (rooms: const <LiveRoom>[], hasMore: false);
    final response = await http.get(WeiboEndpoints.recommendUrl);
    return (rooms: WeiboRoomParser.snapshot(response.text, status: response.status), hasMore: false);
  }

  /// The rooms of area [areaId]: the snapshot. Another area id is a caller
  /// error, without a request, as in the reference (which knew one area).
  Future<({List<LiveRoom> rooms, bool hasMore})> areaRooms(String areaId, {int page = 1}) async {
    _checkPage(page);
    if (areaId != WeiboEndpoints.areaId) {
      throw WeiboFailure(WeiboFailureKind.invalidArgument, 'area "$areaId" is not the Weibo recommendation');
    }
    return await snapshot(page: page);
  }

  // Search --------------------------------------------------------------------

  /// Rooms for [keyword] (the reference's rules), on page 1 only (later pages
  /// are empty, without a request):
  /// - a page below 1 or a page size outside 1-1000 is a caller error,
  ///   without a request;
  /// - a broadcast id or room link ([WeiboEndpoints.exactRoom]) finds that
  ///   room, or nothing when the site says it does not exist;
  /// - a `t.cn` short link ([WeiboEndpoints.shortLink], 18-9) is asked where
  ///   it leads (one request, the redirect not fetched further); a Weibo room
  ///   link there finds that room as above, anything else nothing;
  /// - another link (a URL with a scheme and host) or a blank keyword finds
  ///   nothing, without a request;
  /// - anything else filters the snapshot's nicknames.
  Future<({List<LiveRoom> rooms, bool hasMore})> search(String keyword, {int page = 1, int pageSize = 20}) async {
    _checkPage(page, pageSize);
    if (page > 1) return (rooms: const <LiveRoom>[], hasMore: false);
    final input = keyword.trim();
    final short = WeiboEndpoints.shortLink(input);
    final exact = short != null ? await shortLinkRoom(input) : WeiboEndpoints.exactRoom(input);
    if (exact != null) {
      try {
        return (rooms: [await detail(exact)], hasMore: false);
      } on WeiboFailure catch (failure) {
        if (failure.kind != WeiboFailureKind.notFound) rethrow;
        return (rooms: const <LiveRoom>[], hasMore: false);
      }
    }
    if (input.isEmpty || _isLink(input)) return (rooms: const <LiveRoom>[], hasMore: false);
    final page1 = await snapshot();
    return (rooms: WeiboRoomParser.searchSnapshot(input, page1.rooms, pageSize: pageSize), hasMore: false);
  }

  /// The broadcast a `t.cn` short link [text] leads to, or null: one request,
  /// its redirect not fetched (the transport would follow it, so the room is
  /// read off the `Location` of an answer that still names one). A redirect
  /// to a Weibo room link gives its broadcast; a redirect elsewhere (another
  /// platform, `weibo.com/sorry` for an unknown code), an answer without a
  /// redirect and HTTP 404 give null; other statuses fail as the status gate
  /// says.
  Future<String?> shortLinkRoom(String text) async {
    final start = WeiboEndpoints.shortLink(text);
    if (start == null) return null;
    final response = await http.get(start);
    final status = response.status;
    if (WeiboEndpoints.redirectStatuses.contains(status)) {
      final target = WeiboEndpoints.redirectTarget(start, response.headers);
      return target == null ? null : WeiboEndpoints.liveIdFromUrl('$target');
    }
    if ((status >= 200 && status < 300) || status == 404) return null;
    WeiboJson.checkStatus(status, 't.cn');
    return null;
  }

  /// The room link [uri] names without any request: its web page, or null
  /// when the link names no room (see [WeiboEndpoints.liveIdFromUrl]).
  Uri? canonicalRoomUrl(Uri uri) {
    final id = WeiboEndpoints.liveIdFromUrl('$uri');
    return id == null ? null : Uri.parse(WeiboEndpoints.roomUrl(id));
  }

  /// Whether [uri] is a `t.cn` short link that needs a request.
  bool isShortLink(Uri uri) => WeiboEndpoints.shortLink('$uri') != null;

  // Rooms ---------------------------------------------------------------------

  /// `show_pc_live` as the room [roomId] (see [WeiboRoomParser.detail]), of
  /// [ownerId] when given; an id that is no broadcast id is not-found without
  /// a request. The answer is kept as the broadcast's playback handle.
  Future<LiveRoom> detail(String roomId, {int? ownerId}) async {
    final id = _broadcastId(roomId);
    final response = await http.get(WeiboEndpoints.detailUrl(id));
    final room = WeiboRoomParser.detail(response.text, liveId: id, ownerId: ownerId, status: response.status);
    _remember(id, room.runtime.streamHandle! as WeiboRoomData);
    return room;
  }

  /// [roomId] trimmed as a broadcast id; anything else is not-found without a
  /// request.
  String _broadcastId(String roomId) {
    final id = roomId.trim();
    if (!WeiboEndpoints.isLiveId(id)) throw WeiboFailure(WeiboFailureKind.notFound, 'not a broadcast id: $id');
    return id;
  }

  /// Keeps [data] as the handle of broadcast [id], dropping the oldest past
  /// [_detailLimit].
  void _remember(String id, WeiboRoomData data) {
    _details
      ..remove(id)
      ..[id] = data;
    while (_details.length > _detailLimit) {
      _details.remove(_details.keys.first);
    }
  }

  // Streams -------------------------------------------------------------------

  /// The one quality the broadcast plays: the reference's 原始流
  /// ([WeiboEndpoints.original]) live, 原画 ([WeiboEndpoints.replay]) for its
  /// recording (18-5). The room's kept detail answers when there is one; else
  /// the detail is read once. A broadcast whose detail does not play is
  /// refused with its reason.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async {
    final id = _broadcastId(roomId);
    final data = _details[id] ?? await _read(id);
    final error = WeiboRoomParser.unplayable(data);
    if (error != null) throw error;
    return [WeiboRoomParser.qualityOf(data)!];
  }

  /// The lines of the broadcast:
  /// - [WeiboEndpoints.original] (or the default when [quality] is null and
  ///   the kept detail is live): as the site answers now. The detail is read
  ///   again (one request), must still be the same anchor's, live and
  ///   playable; a broadcast that ended meanwhile is stream-unavailable,
  ///   never its replay.
  /// - [WeiboEndpoints.replay]: the recording of the room's kept detail,
  ///   without a request (an unsigned VOD); without a kept detail the detail
  ///   is read once.
  ///
  /// Another quality, a kept detail that does not play it, or a broadcast
  /// that has switched off or is restricted is refused, with the reason.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async {
    final id = _broadcastId(roomId);
    final asked = quality?.qualityId?.trim();
    const replayId = WeiboEndpoints.replayQualityId;
    const originalId = WeiboEndpoints.originalQualityId;
    if (asked != null && asked != originalId && asked != replayId) {
      throw WeiboFailure(WeiboFailureKind.streamUnavailable, 'quality $asked is not offered');
    }
    final known = _details[id];
    var want = asked;
    if (want == null) {
      final data = known ?? await _read(id);
      _gate(data, null);
      want = WeiboRoomParser.qualityOf(data)!.qualityId!;
      if (data.status == WeiboEndpoints.replayStatusCode) return WeiboRoomParser.replayLines(data.replayUrl!);
      // A fresh read above already answers for the live case.
      if (known == null) return WeiboRoomParser.lines(data.mediaUrls);
    } else if (known != null && want == replayId) {
      _gate(known, want);
      return WeiboRoomParser.replayLines(known.replayUrl!);
    } else if (known != null) {
      _gate(known, want);
    }
    // The live quality plays as the site answers now: read the detail again
    // (one request; a replay asked without a kept detail also comes here).
    final fresh = await _read(id, ownerId: known?.ownerId);
    _gate(fresh, want);
    final offered = WeiboRoomParser.qualityOf(fresh)!.qualityId!;
    if (offered != want) {
      throw WeiboFailure(
        WeiboFailureKind.streamUnavailable,
        offered == replayId ? 'the broadcast has ended; its replay is quality replay' : 'not a replay',
      );
    }
    return offered == replayId ? WeiboRoomParser.replayLines(fresh.replayUrl!) : WeiboRoomParser.lines(fresh.mediaUrls);
  }

  /// The detail of broadcast [id] (kept afterwards), with its owner checked
  /// when [ownerId] is given.
  Future<WeiboRoomData> _read(String id, {int? ownerId}) async {
    await detail(id, ownerId: ownerId);
    return _details[id]!;
  }

  /// Why [data] does not play quality [asked] (either when null): ended or
  /// unknown states, restrictions, switched-off playback, missing URLs — and
  /// the mismatch between a broadcast's one quality and what was asked.
  void _gate(WeiboRoomData data, String? asked) {
    final error = WeiboRoomParser.unplayable(data);
    if (error != null) throw error;
    if (asked == null) return;
    final offered = WeiboRoomParser.qualityOf(data)!.qualityId!;
    if (offered != asked) {
      throw WeiboFailure(
        WeiboFailureKind.streamUnavailable,
        offered == WeiboEndpoints.replay.qualityId
            ? 'the broadcast has ended; its replay is quality ${WeiboEndpoints.replay.qualityId}'
            : 'not a replay',
      );
    }
  }

  /// The bounds the reference checked before any request: a page from 1, a
  /// page size from 1 to 1000; out of bounds is a caller error.
  static void _checkPage(int page, [int pageSize = 30]) {
    if (page < 1) throw WeiboFailure(WeiboFailureKind.invalidArgument, 'page $page is below 1');
    if (pageSize < WeiboEndpoints.minPageSize || pageSize > WeiboEndpoints.maxPageSize) {
      throw WeiboFailure(WeiboFailureKind.invalidArgument, 'page size $pageSize is outside 1-1000');
    }
  }

  /// Whether [input] is a link (`scheme://…`) rather than a keyword. The
  /// reference took any text with a scheme for one, so keywords such as
  /// `Re:Zero` find nothing.
  static bool _isLink(String input) {
    final uri = Uri.tryParse(input);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  // Capability wiring ---------------------------------------------------------

  WeiboRoomProvider? _room;
  WeiboAreaProvider? _area;
  WeiboDiscoveryProvider? _discovery;
  WeiboSearchProvider? _search;
  WeiboPlaybackProvider? _playback;
  WeiboLinkResolver? _link;

  /// The capability of type [T], or null when Weibo does not support it
  /// (ARCHITECTURE.md §4.1) — the platform has no chat, so no
  /// `LiveDanmakuProvider` exists here. Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= WeiboRoomProvider(site: this);
    final area = _area ??= WeiboAreaProvider(site: this);
    final discovery = _discovery ??= WeiboDiscoveryProvider(site: this);
    final search = _search ??= WeiboSearchProvider(site: this);
    final playback = _playback ??= WeiboPlaybackProvider(site: this);
    final link = _link ??= WeiboLinkResolver(site: this);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => area as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LiveLinkResolver) => link as T,
      _ => null,
    };
  }
}
