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
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_endpoints.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_http.dart';
import 'package:live_sites/src/platforms/pandalive/capabilities/pandalive_area_provider.dart';
import 'package:live_sites/src/platforms/pandalive/capabilities/pandalive_discovery_provider.dart';
import 'package:live_sites/src/platforms/pandalive/capabilities/pandalive_link_resolver.dart';
import 'package:live_sites/src/platforms/pandalive/capabilities/pandalive_playback_provider.dart';
import 'package:live_sites/src/platforms/pandalive/capabilities/pandalive_room_provider.dart';
import 'package:live_sites/src/platforms/pandalive/capabilities/pandalive_search_provider.dart';
import 'package:live_sites/src/platforms/pandalive/danmaku/pandalive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/pandalive/danmaku/pandalive_danmaku_session.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_manifest.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_failure.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_link.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The PandaTV (팬더티비) adapter (parsing in `parsers/`, the chat in
/// `danmaku/`): manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2).
///
/// A room is a broadcaster, its id the login id as asked for (`daisy00`;
/// social logins carry a suffix, `1506087545@ka`). Anonymous: no cookie, no
/// account; every request carries [PandaliveEndpoints.headers] and goes as
/// `pandalive`, so the app routes the platform through its proxy setting.
/// The requests are the website's:
/// - the catalog is two fixed areas, the public directory and the new
///   broadcasters, without a request; a directory page is one `live/index`
///   POST, 30 rows by popularity;
/// - search is one `member/bj` for a room link; else the BJ search
///   (`live/bj_list`) and then the LIVE search (`live/index` by viewers),
///   one after the other, each with half the page; on page 1 a keyword that
///   is a broadcaster id puts that broadcaster first, with a `member/bj`
///   only when the searches did not list it;
/// - room entry is `member/bj`; while the broadcaster is listed as live,
///   `live/play` and the IVS master (read once, its token single use, its
///   variants handed out as the qualities' lines).
///
/// Failures are [PandaliveFailure]s; nothing is disguised as an offline
/// room.
final class PandaliveSite implements LiveSite {
  /// Creates the adapter over [http]. [connect] makes the chat's socket
  /// (default [webSocketConnect]); [now] (when `live/play` issued the
  /// variants) is injectable for tests.
  PandaliveSite({required this.http, this.connect = webSocketConnect, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Transport.
  final PandaliveHttp http;

  /// How the chat's socket is connected.
  final SocketConnector connect;

  final DateTime Function() _now;

  /// The stream data of the room entered last, by broadcaster id
  /// (lower-case), with when `live/play` issued its variants: what the
  /// playback capability hands out. A set whose variants have passed their
  /// lease ([PandaliveEndpoints.variantRefresh]) is dropped, so the next
  /// line request enters the room again.
  final Map<String, ({PandaliveStreamData data, DateTime issuedAt})> _streams = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => pandaliveManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Catalog and directory ------------------------------------------------------

  /// [areaId] as one of the two directories (the public one when null);
  /// anything else is a caller error, refused before any request.
  static String _areaIdOf(String? areaId) {
    final id = areaId ?? PandaliveEndpoints.publicAreaId;
    if (PandaliveEndpoints.areas.containsKey(id)) return id;
    throw PandaliveFailure(PandaliveFailureKind.invalidArgument, 'area "$areaId" is not a PandaTV directory');
  }

  /// Page [page] of [pageSize] rows of the directory [areaId] names (the
  /// public one when it is null): one `live/index` POST by popularity. A
  /// page out of 1-[PandaliveEndpoints.maxPage] or a page size out of
  /// 1-[PandaliveEndpoints.maxRows] is a caller error, refused before any
  /// request.
  Future<({List<LiveRoom> rooms, bool hasMore})> directory(int page, int pageSize, {String? areaId}) async {
    if (page < 1 || page > PandaliveEndpoints.maxPage) {
      throw PandaliveFailure(
        PandaliveFailureKind.invalidArgument,
        'page $page is out of 1-${PandaliveEndpoints.maxPage}',
      );
    }
    if (pageSize < 1 || pageSize > PandaliveEndpoints.maxRows) {
      throw PandaliveFailure(
        PandaliveFailureKind.invalidArgument,
        'page size $pageSize is out of 1-${PandaliveEndpoints.maxRows}',
      );
    }
    final area = _areaIdOf(areaId);
    final response = await http.post(
      PandaliveEndpoints.directoryPath,
      PandaliveEndpoints.directoryForm(page, pageSize, areaId: area),
      referer: '${PandaliveEndpoints.origin}/live',
    );
    final result = PandaliveRoomParser.livePage(response.text, page: page, size: pageSize, status: response.status);
    return (rooms: result.rooms, hasMore: result.hasMore);
  }

  // Search ---------------------------------------------------------------------

  /// The search: a room link finds that broadcaster, live or not, on page 1
  /// (one `member/bj`; no such broadcaster finds nothing); another URL, a
  /// keyword shorter than 2 or longer than 100 characters, a page below 1 or
  /// a page size below 1 find nothing, without a request. Any other keyword
  /// runs the BJ search and then the LIVE search, each with its own offset:
  /// `ceil(pageSize / 2)` live rows (none for a page of one) and the rest
  /// broadcasters, at most 50 each; live cards come first, a broadcaster
  /// once, and one source failing leaves the other's rows (both failing, or
  /// no row and a failure, is the failure). On page 1 a keyword that is a
  /// broadcaster id is put first, with a `member/bj` asked only when the
  /// searches did not list it (an unknown one adds nothing). A page over
  /// [PandaliveEndpoints.maxPage] or a keyword with a control character is a
  /// caller error.
  Future<({List<LiveRoom> rooms, bool? hasMore})> search(String keyword, {int page = 1, int pageSize = 30}) async {
    if (page < 1 || pageSize < 1) return (rooms: const <LiveRoom>[], hasMore: null);
    final query = keyword.trim();
    final linked = PandaliveLink.roomIdFromUrl(query);
    if (linked != null) {
      if (page > 1) return (rooms: const <LiveRoom>[], hasMore: null);
      try {
        return (rooms: [await refresh(linked)], hasMore: null);
      } on PandaliveFailure catch (failure) {
        if (failure.kind != PandaliveFailureKind.notFound) rethrow;
        return (rooms: const <LiveRoom>[], hasMore: null);
      }
    }
    if (Uri.tryParse(query)?.hasScheme ?? false) return (rooms: const <LiveRoom>[], hasMore: null);
    if (query.length < PandaliveEndpoints.minKeywordLength || query.length > PandaliveEndpoints.maxKeywordLength) {
      return (rooms: const <LiveRoom>[], hasMore: null);
    }
    if (page > PandaliveEndpoints.maxPage) {
      throw PandaliveFailure(
        PandaliveFailureKind.invalidArgument,
        'page $page is out of 1-${PandaliveEndpoints.maxPage}',
      );
    }
    if (RegExp(r'[\x00-\x1f]').hasMatch(query)) {
      throw const PandaliveFailure(PandaliveFailureKind.invalidArgument, 'keyword contains a control character');
    }
    final exact = page == 1 ? PandaliveEndpoints.normalizeUserId(query) : null;
    final liveSize = pageSize > 1 ? (pageSize + 1) ~/ 2 : 0;
    final broadcasterSize = (pageSize - liveSize).clamp(1, PandaliveEndpoints.maxSourceSize);
    List<LiveRoom>? broadcasters;
    List<LiveRoom>? live;
    PandaliveFailure? broadcasterError;
    PandaliveFailure? liveError;
    try {
      final response = await http.post(
        PandaliveEndpoints.broadcasterSearchPath,
        PandaliveEndpoints.broadcasterSearchForm(query, page: page, size: broadcasterSize),
        referer: PandaliveEndpoints.searchReferer('bj', query),
      );
      broadcasters = PandaliveRoomParser.broadcasterPage(
        response.text,
        page: page,
        size: broadcasterSize,
        status: response.status,
      ).rooms;
    } on PandaliveFailure catch (failure) {
      broadcasterError = failure;
    }
    if (liveSize > 0) {
      final size = liveSize.clamp(1, PandaliveEndpoints.maxSourceSize);
      try {
        final response = await http.post(
          PandaliveEndpoints.directoryPath,
          PandaliveEndpoints.liveSearchForm(query, page: page, size: size),
          referer: PandaliveEndpoints.searchReferer('live', query),
        );
        live = PandaliveRoomParser.livePage(response.text, page: page, size: size, status: response.status).rooms;
      } on PandaliveFailure catch (failure) {
        liveError = failure;
      }
    }
    var failure = liveError ?? broadcasterError;
    final seen = <String>{};
    final rooms = [
      for (final room in [...?live, ...?broadcasters])
        if (seen.add(room.roomId.toLowerCase())) room,
    ];
    if (exact != null) {
      final index = rooms.indexWhere((room) => room.roomId.toLowerCase() == exact.toLowerCase());
      if (index >= 0) {
        rooms.insert(0, rooms.removeAt(index));
      } else {
        try {
          rooms.insert(0, await refresh(exact));
        } on PandaliveFailure catch (error) {
          if (error.kind != PandaliveFailureKind.notFound) failure ??= error;
        }
      }
    }
    if (rooms.isEmpty && failure != null) throw failure;
    return (rooms: rooms, hasMore: null);
  }

  // Rooms ----------------------------------------------------------------------

  /// [roomId] as a broadcaster id; anything else is not-found without a
  /// request.
  String _checkedId(String roomId) =>
      PandaliveEndpoints.normalizeUserId(roomId.trim()) ??
      (throw PandaliveFailure(PandaliveFailureKind.notFound, 'not a broadcaster id: $roomId'));

  Future<PandaliveMember> _member(String userId) async {
    final response = await http.post(
      PandaliveEndpoints.memberPath,
      PandaliveEndpoints.memberForm(userId),
      referer: PandaliveEndpoints.roomUrl(userId),
    );
    return PandaliveRoomParser.member(response.text, userId: userId, status: response.status);
  }

  /// The follow-refresh room of [userId]: one `member/bj`, live or not.
  Future<LiveRoom> refresh(String userId) async => PandaliveRoomParser.refreshRoom(await _member(_checkedId(userId)));

  /// Room entry: `member/bj`; while the broadcaster is listed as live,
  /// `live/play` and the IVS master, read once and turned into qualities
  /// whose lines are the variant playlists. A broadcast that cannot be
  /// played (ended, adult, password, fans only, no HLS, no video, a master
  /// gone) is still entered; its stream says why and a live one is marked
  /// with its restriction (unplayable for no HLS, no video or a master
  /// gone). The chat grant of an accepted live broadcast rides on the
  /// room's danmaku handle.
  Future<LiveRoom> detail(String roomId) async {
    final userId = _checkedId(roomId);
    final member = await _member(userId);
    final key = userId.toLowerCase();
    void keep(PandaliveStreamData data, DateTime issuedAt) {
      _streams
        ..remove(key)
        ..[key] = (data: data, issuedAt: issuedAt);
    }

    if (!PandaliveRoomParser.listedLive(member)) {
      final data = PandaliveStreamData(
        userId: userId,
        userIndex: member.userIndex,
        unavailable: const PandaliveFailure(PandaliveFailureKind.streamUnavailable, 'member/bj: not live'),
      );
      keep(data, _now());
      return PandaliveRoomParser.profileRoom(member)
          .rebuild((b) => b..runtime = RoomRuntime.of(streamHandle: data).toBuilder());
    }
    final referer = PandaliveEndpoints.roomUrl(userId);
    final answer = await http.post(PandaliveEndpoints.playPath, PandaliveEndpoints.playForm(userId), referer: referer);
    final play = PandaliveRoomParser.play(answer.text, member: member, status: answer.status);
    final (:room, :unavailable) = PandaliveRoomParser.playRoom(member, play);
    final grant = PandaliveRoomParser.chatGrantOf(member, play);
    final danmaku = grant == null
        ? null
        : PandaliveDanmakuArgs(userId: userId, channel: grant.channel, token: grant.token);
    LiveRoom entered(PandaliveStreamData data) =>
        room.rebuild((b) => b..runtime = RoomRuntime.of(streamHandle: data, danmakuHandle: danmaku).toBuilder());
    if (unavailable != null) {
      final data = PandaliveStreamData(userId: userId, userIndex: member.userIndex, unavailable: unavailable);
      keep(data, _now());
      return entered(data);
    }
    final issuedAt = _now();
    final master = play.master!;
    final response = await http.get(master, headers: PandaliveEndpoints.headers(referer));
    try {
      final entries = PandaliveRoomParser.qualities(
        PandaliveRoomParser.master(response.text, status: response.status),
        master: master,
        userId: userId,
        issuedAt: issuedAt,
      );
      final data = PandaliveStreamData(userId: userId, userIndex: member.userIndex, entries: entries);
      keep(data, issuedAt);
      return entered(data);
    } on PandaliveFailure catch (failure) {
      if (failure.kind != PandaliveFailureKind.streamUnavailable) rethrow;
      final data = PandaliveStreamData(userId: userId, userIndex: member.userIndex, unavailable: failure);
      keep(data, issuedAt);
      return entered(data).rebuild(
        (b) => b..broadcast.replace(room.broadcast.rebuild((b) => b..restriction = LiveRestriction.unplayable)),
      );
    }
  }

  // Streams --------------------------------------------------------------------

  /// The stream data of [roomId]: the one its room entry brought, until its
  /// variants' lease runs out — after that, and when nothing is kept, a
  /// fresh entry. A broadcaster the platform called offline has no stream,
  /// without a request while the kept data is young.
  Future<PandaliveStreamData> _stream(String roomId) async {
    final userId = _checkedId(roomId);
    final kept = _streams[userId.toLowerCase()];
    if (kept != null &&
        kept.data.userId.toLowerCase() == userId.toLowerCase() &&
        _now().isBefore(kept.issuedAt.add(PandaliveEndpoints.variantRefresh))) {
      return kept.data;
    }
    await detail(userId);
    return _streams[userId.toLowerCase()]!.data;
  }

  /// The qualities [roomId]'s broadcast offers, best first, from the stream
  /// data its room entry brought. A room with nothing to play says why.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async {
    final data = await _stream(roomId);
    if (data.entries.isEmpty) {
      throw data.unavailable ?? const PandaliveFailure(PandaliveFailureKind.streamUnavailable, 'no quality');
    }
    return data.qualities;
  }

  /// The variant playlist of [quality] (the best one when it is null; an
  /// older `<height>p30` id is read as the new one), with the media headers
  /// and its lease.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async {
    final data = await _stream(roomId);
    final wanted = quality ?? (data.entries.isEmpty ? const LivePlayQuality(label: '') : data.entries.first.quality);
    return [PandaliveRoomParser.line(data, wanted)];
  }

  // Chat -----------------------------------------------------------------------

  /// A fresh chat grant of [userId]: one `live/play`, as the website sends
  /// on every visit. A refusal (the broadcast ended, adult, password, fans
  /// only, not live) throws [PandaliveChatRefusal]; anything else its
  /// [PandaliveFailure].
  Future<({String channel, String token})> chatGrant(String userId) async {
    final id = _checkedId(userId);
    final response = await http.post(
      PandaliveEndpoints.playPath,
      PandaliveEndpoints.playForm(id),
      referer: PandaliveEndpoints.roomUrl(id),
    );
    return PandaliveDanmakuCodec.grant(response);
  }

  // Capability wiring ----------------------------------------------------------

  PandaliveRoomProvider? _room;
  PandaliveAreaProvider? _area;
  PandaliveDiscoveryProvider? _discovery;
  PandaliveSearchProvider? _search;
  PandalivePlaybackProvider? _playback;
  PandaliveDanmakuProvider? _danmaku;
  PandaliveLinkResolver? _link;

  /// The capability of type [T], or null when PandaTV does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= PandaliveRoomProvider(site: this);
    final area = _area ??= PandaliveAreaProvider(site: this);
    final discovery = _discovery ??= PandaliveDiscoveryProvider(site: this);
    final search = _search ??= PandaliveSearchProvider(site: this);
    final playback = _playback ??= PandalivePlaybackProvider(site: this);
    final danmaku = _danmaku ??= PandaliveDanmakuProvider(site: this);
    final link = _link ??= PandaliveLinkResolver(site: this);
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
