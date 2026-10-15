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
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_endpoints.dart';
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_http.dart';
import 'package:live_sites/src/platforms/xiaohongshu/capabilities/xiaohongshu_discovery_provider.dart';
import 'package:live_sites/src/platforms/xiaohongshu/capabilities/xiaohongshu_link_resolver.dart';
import 'package:live_sites/src/platforms/xiaohongshu/capabilities/xiaohongshu_playback_provider.dart';
import 'package:live_sites/src/platforms/xiaohongshu/capabilities/xiaohongshu_room_provider.dart';
import 'package:live_sites/src/platforms/xiaohongshu/capabilities/xiaohongshu_search_provider.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_link.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_room_parser.dart';
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
/// Link-only, as in 3.x: the website's live list needs a signed login
/// request, so the directory is always empty and search looks up the one
/// room a room id, share link, short link or app deep link names. A room is
/// its public share page, read anonymously as `xiaohongshu` with
/// [XiaohongshuEndpoints.headers]; the page also holds the pull addresses
/// (one quality per `quality_type`, its H.264 and H.265 addresses as
/// lines). Room ids are the broadcast rooms asked for: following the
/// streamer across broadcasts is blocked, see
/// [XiaohongshuRoomParser]. There is no danmaku (3.x's `EmptyDanmaku`), no
/// account and no start time. Failures are [XiaohongshuFailure]s; nothing
/// is disguised as an offline room.
final class XiaohongshuSite implements LiveSite {
  /// Creates the adapter over [http].
  XiaohongshuSite({required this.http});

  /// Transport.
  final XiaohongshuHttp http;

  /// The stream data of the room whose entry was read last, by room id: the
  /// pull addresses the capabilities hand out until the next entry. A
  /// searched room is a card without stream data, as in 3.x, so playback
  /// reads the page again.
  final Map<String, XiaohongshuRoomData> _entries = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => xiaohongshuManifest;

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

  /// Always empty: no public directory is reachable anonymously (3.x shows
  /// its directory notice instead). A page below 1 is a caller error, as 3.x
  /// refused it. Nothing is requested.
  Future<({List<LiveRoom> rooms, bool hasMore})> directory(int page) async {
    if (page < 1) throw XiaohongshuFailure(XiaohongshuFailureKind.invalidArgument, 'page $page is below 1');
    return (rooms: const <LiveRoom>[], hasMore: false);
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
  /// capabilities.
  Future<LiveRoom> detail(String roomId) async {
    final page = await _read(roomId);
    _remember(page.data);
    return page.room.copyWith(runtime: RoomRuntime(streamHandle: page.data));
  }

  // Streams -------------------------------------------------------------------

  /// The stream data of [roomId]: the one its room entry brought, or the
  /// page's now — the capabilities are asked by room id alone. An entered
  /// room that has ended says so without a request.
  Future<XiaohongshuRoomData> _stream(String roomId) async {
    final id = roomId.trim();
    final entry = _entries[id];
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
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async =>
      XiaohongshuRoomParser.lines(await _stream(roomId), quality);

  // Capability wiring ---------------------------------------------------------

  XiaohongshuRoomProvider? _room;
  XiaohongshuDiscoveryProvider? _discovery;
  XiaohongshuSearchProvider? _search;
  XiaohongshuPlaybackProvider? _playback;
  XiaohongshuLinkResolver? _link;

  /// The capability of type [T], or null when Xiaohongshu does not support
  /// it (ARCHITECTURE.md §4.1): no areas (the share page knows no
  /// category), and no danmaku (3.x's `EmptyDanmaku`). Capabilities are
  /// singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= XiaohongshuRoomProvider(site: this);
    final discovery = _discovery ??= XiaohongshuDiscoveryProvider(site: this);
    final search = _search ??= XiaohongshuSearchProvider(site: this);
    final playback = _playback ??= XiaohongshuPlaybackProvider(site: this);
    final link = _link ??= XiaohongshuLinkResolver(site: this);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => null,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LiveDanmakuProvider) => null,
      const (LiveLinkResolver) => link as T,
      _ => null,
    };
  }
}
