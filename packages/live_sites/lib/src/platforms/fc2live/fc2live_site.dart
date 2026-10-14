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
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/fc2live/api/fc2live_endpoints.dart';
import 'package:live_sites/src/platforms/fc2live/api/fc2live_http.dart';
import 'package:live_sites/src/platforms/fc2live/capabilities/fc2live_area_provider.dart';
import 'package:live_sites/src/platforms/fc2live/capabilities/fc2live_discovery_provider.dart';
import 'package:live_sites/src/platforms/fc2live/capabilities/fc2live_link_resolver.dart';
import 'package:live_sites/src/platforms/fc2live/capabilities/fc2live_playback_provider.dart';
import 'package:live_sites/src/platforms/fc2live/capabilities/fc2live_room_provider.dart';
import 'package:live_sites/src/platforms/fc2live/capabilities/fc2live_search_provider.dart';
import 'package:live_sites/src/platforms/fc2live/danmaku/fc2live_control.dart';
import 'package:live_sites/src/platforms/fc2live/danmaku/fc2live_danmaku_session.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_manifest.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_failure.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_play_parser.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One page of the directory: its cards, how many rooms the snapshot holds, and
/// whether a later page of it would have more.
typedef Fc2LiveListing = ({List<LiveRoom> rooms, int totalCount, bool hasMore});

/// A control this adapter is holding for one channel, with the grant's own
/// clock: when it was taken (what a line's lease counts from) and when holding
/// it stops being worth it.
typedef Fc2LiveHeld = ({Fc2LiveControl control, DateTime issuedAt, DateTime until});

/// The FC2 Live adapter (parsing in `parsers/`, the control socket in
/// [Fc2LiveControl]): manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2).
///
/// Anonymous, like 3.x: no cookie and no account for any request — the only
/// cookie anywhere is the session token of a control's handshake. All three
/// requests are form POSTs to `live.fc2.com` with the page's own XHR headers:
/// - the directory, an area's rooms, the recommendations and a keyword search
///   are all the one `allchannellist.php` snapshot of every channel on air,
///   paged and filtered locally; page 1 asks anew and every later page comes
///   from a snapshot younger than [Fc2LiveEndpoints.snapshotLifetime], so a
///   room neither repeats between pages nor drops out of them (3.x fetched
///   anew per page, which is what made rooms shuffle between them);
/// - a room is one `memberApi.php`: a channel not on air is offline, a
///   restricted one is live and marked with its restriction, and a channel that
///   never existed is not-found rather than an offline room;
/// - a stream has no address: `getControlServer.php` grants one control socket,
///   whose HLS answer names the playlists (see [Fc2LiveSite.heldOf]), and
///   the media server answers them only while that socket is open.
///
/// Rooms are identified by the channel number. Failures are [Fc2LiveFailure]s;
/// nothing is disguised as an offline room.
final class Fc2LiveSite implements LiveSite {
  /// Creates the adapter over [http]. [connect] makes a control's socket
  /// (default [Fc2LiveControl.io]) through the same proxy route the app
  /// gives [http]; [controlStartupTimeout] bounds a control's handshake and HLS
  /// answer together; [now] (a snapshot's age, and a grant's) is injectable for
  /// tests.
  Fc2LiveSite({
    required this.http,
    this.connect = Fc2LiveControl.io,
    this.controlStartupTimeout = Fc2LiveEndpoints.requestTimeout,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Transport.
  final Fc2LiveHttp http;

  /// How a control's socket is connected.
  final Fc2LiveSocketConnect connect;

  /// Longest wait for a control's handshake and HLS answer together (3.x's 20 s
  /// for both).
  final Duration controlStartupTimeout;

  final DateTime Function() _now;

  /// The `allchannellist` snapshot, and when it arrived. A fetch under way is
  /// shared, so that the page a caller comes back for is the page its first
  /// request was served from.
  Future<List<Fc2LiveChannel>>? _snapshot;
  DateTime? _snapshotAt;

  /// The control held per channel: the socket whose session authorizes the
  /// playlists handed out from it, kept until its grant is nearly due.
  final Map<String, Fc2LiveHeld> _controls = {};

  LiveSiteCapability? _room;
  LiveSiteCapability? _area;
  LiveSiteCapability? _discovery;
  LiveSiteCapability? _search;
  LiveSiteCapability? _playback;
  LiveSiteCapability? _danmaku;
  LiveSiteCapability? _link;

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => fc2LiveManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the held controls and the pooled transports.
  @override
  Future<void> dispose() async {
    final held = _controls.values.toList();
    _controls.clear();
    for (final entry in held) {
      await entry.control.close();
    }
    http.close();
  }

  // Requests ------------------------------------------------------------------

  /// The form POST of [fields] to [path], bounded by
  /// [Fc2LiveEndpoints.requestTimeout].
  Future<Fc2LiveResponse> post(String path, Map<String, String> fields, {CancelToken? cancel}) =>
      http.post(path, fields, cancel: cancel);

  // Snapshot ------------------------------------------------------------------

  /// Every public channel on air, in the site's order.
  ///
  /// [fresh] (page 1 of a list, the pull to refresh) always asks anew. A fetch
  /// under way is shared with every caller, and the latest successful one is
  /// reused until [Fc2LiveEndpoints.snapshotLifetime] after it arrived; a
  /// failed one is forgotten, so a breakdown is never served as an empty
  /// directory. A clock that went backwards reuses nothing.
  Future<List<Fc2LiveChannel>> snapshot({bool fresh = false}) async {
    if (!fresh) {
      final cached = _snapshot;
      // An arrived snapshot is reused while it is young; one still under way is
      // shared with whoever started it, so a later page comes from the same one.
      if (cached != null && (_snapshotAt == null || _young(_snapshotAt))) return await cached;
    }
    late final Future<List<Fc2LiveChannel>> fetch;
    fetch = () async {
      final response = await post(Fc2LiveEndpoints.directoryPath, const {});
      try {
        final channels = Fc2LiveRoomParser.directory(response.text, status: response.status);
        if (identical(_snapshot, fetch)) _snapshotAt = _now();
        return channels;
      } on Object {
        // A failed snapshot is forgotten, so a breakdown is never served as an
        // empty directory and the next caller asks anew.
        if (identical(_snapshot, fetch)) {
          _snapshot = null;
          _snapshotAt = null;
        }
        rethrow;
      }
    }();
    _snapshot = fetch;
    _snapshotAt = null;
    return await fetch;
  }

  bool _young(DateTime? at) {
    if (at == null) return false;
    final age = _now().difference(at);
    return age >= Duration.zero && age < Fc2LiveEndpoints.snapshotLifetime;
  }

  // Catalog and directory -----------------------------------------------------

  /// The platform's areas: no request (FC2 has no area list).
  List<LiveArea> areas() => Fc2LiveRoomParser.areas();

  /// Page [page] of [pageSize] of the channels on air, of those of one area
  /// when [areaId] names one.
  ///
  /// Page 1 asks for a new snapshot; a later page comes from the last one while
  /// it holds, which is what keeps the pages from repeating and dropping rooms
  /// between them. An area that is not the platform's is a caller error, and a
  /// page or size the platform never served is an empty list — both without a
  /// request.
  Future<Fc2LiveListing> listing({
    String? areaId,
    int page = 1,
    int pageSize = Fc2LiveEndpoints.directoryPageSize,
  }) async {
    final filter = areaId == null ? null : Fc2LiveRoomParser.areaFilter(areaId);
    if (!Fc2LiveRoomParser.validSlice(page: page, pageSize: pageSize)) {
      return (rooms: const <LiveRoom>[], totalCount: 0, hasMore: false);
    }
    final channels = await snapshot(fresh: page == 1);
    final inArea = [
      for (final channel in channels)
        if (Fc2LiveRoomParser.inArea(channel, filter)) channel,
    ];
    return _page(inArea, page: page, pageSize: pageSize);
  }

  /// Page [page] of [pageSize] of the channels [keyword] matches (see
  /// [Fc2LiveRoomParser.search]) — or, for a keyword that is a channel number or
  /// link, that one channel, found even when it is offline. Only the first page
  /// gives an exact channel, as 3.x did.
  Future<Fc2LiveListing> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final query = keyword.trim();
    if (query.isEmpty || !Fc2LiveRoomParser.validSlice(page: page, pageSize: pageSize)) {
      return (rooms: const <LiveRoom>[], totalCount: 0, hasMore: false);
    }
    if (Fc2LiveRoomParser.channel(query) case final exact?) {
      if (page != 1) return (rooms: const <LiveRoom>[], totalCount: 0, hasMore: false);
      try {
        return (rooms: [Fc2LiveRoomParser.room((await member(exact)).channel)], totalCount: 1, hasMore: false);
      } on Fc2LiveFailure catch (failure) {
        // A channel that does not exist is simply not a result.
        if (failure.kind != Fc2LiveFailureKind.notFound) rethrow;
        return (rooms: const <LiveRoom>[], totalCount: 0, hasMore: false);
      }
    }
    final matched = Fc2LiveRoomParser.search(await snapshot(fresh: page == 1), query);
    return _page(matched, page: page, pageSize: pageSize);
  }

  Fc2LiveListing _page(List<Fc2LiveChannel> channels, {required int page, required int pageSize}) => (
    rooms: [
      for (final channel in Fc2LiveRoomParser.slice(channels, page: page, pageSize: pageSize))
        Fc2LiveRoomParser.room(channel),
    ],
    totalCount: channels.length,
    hasMore: page * pageSize < channels.length,
  );

  // Rooms ---------------------------------------------------------------------

  /// The channel [roomId] names: a channel number, or a channel link. Anything
  /// else is a caller error the capabilities report as not-found, without a
  /// request.
  String channelOf(String roomId) => Fc2LiveRoomParser.requiredChannel(roomId);

  /// The channel's member answer: one request.
  Future<Fc2LiveMember> member(String roomId) async {
    final id = channelOf(roomId);
    final response = await post(Fc2LiveEndpoints.memberPath, Fc2LiveEndpoints.memberFields(id));
    return Fc2LiveRoomParser.member(response.text, channelId: id, status: response.status);
  }

  /// The room of [roomId]: its entry, with what playback and chat need to know
  /// (the state and flags behind its notice, and the channel for the comment
  /// connection).
  Future<LiveRoom> detail(String roomId) async => Fc2LiveRoomParser.room((await member(roomId)).channel, danmaku: true);

  // Control -------------------------------------------------------------------

  /// A fresh grant for [roomId]'s channel: its member answer, then
  /// `getControlServer.php` with the channel's version.
  ///
  /// A channel that is not on air, and one whose restriction keeps this viewer
  /// out, are refused before the second request. A live channel that answers no
  /// version is api-changed: the grant cannot be made without it.
  Future<Fc2LiveGrant> controlGrant(String roomId) async {
    final id = channelOf(roomId);
    final (:channel, :version) = await member(id);
    if (channel.state == Fc2LiveState.offline) {
      throw Fc2LiveFailure(Fc2LiveFailureKind.streamUnavailable, 'channel $id is not on air');
    }
    if (Fc2LiveRoomParser.refusal(channel.restriction, id) case final refusal?) throw refusal;
    if (version == null) {
      throw Fc2LiveFailure(Fc2LiveFailureKind.apiChanged, 'memberApi: channel $id is live without a version');
    }
    final response = await post(
      Fc2LiveEndpoints.controlPath,
      Fc2LiveEndpoints.controlFields(channelId: id, version: version),
    );
    return Fc2LivePlayParser.grant(response.text, channelId: id, status: response.status);
  }

  /// The open control of [roomId]'s channel, with when its grant was taken.
  ///
  /// A playlist address is only worth asking for while the control that
  /// announced it is open, so the adapter holds one control per channel and
  /// hands out its playlists until that grant is nearly due — which is what a
  /// line's [LivePlayLease] tells the player to come back for. A channel with a
  /// live control is served from it without a request; otherwise this takes a
  /// fresh grant (the member answer and the grant request), opens its socket and
  /// reads its HLS answer, and closes the control it replaces. A control the
  /// site ends — an expired grant, a dropped socket — is forgotten at once, so
  /// the next caller resolves again instead of being handed a dead address.
  Future<Fc2LiveHeld> heldOf(String roomId) async {
    final id = channelOf(roomId);
    if (_controls[id] case final held? when !held.control.isClosed && _now().isBefore(held.until)) {
      return held;
    }
    final control = await Fc2LiveControl.open(
      await controlGrant(id),
      connect: connect,
      startupTimeout: controlStartupTimeout,
    );
    final issuedAt = _now();
    final entry = (control: control, issuedAt: issuedAt, until: _holdUntil(issuedAt));
    final replaced = _controls[id];
    _controls[id] = entry;
    if (replaced != null) unawaited(replaced.control.close());
    unawaited(
      control.done.then((_) {
        if (_controls[id]?.control == control) _controls.remove(id);
      }),
    );
    return entry;
  }

  /// The qualities [roomId]'s channel offers now, from its control's HLS answer.
  ///
  /// Only that answer tells which tiers a channel has (3.x listed `auto` alone,
  /// without a request of its own), so this is the two requests and the socket
  /// of [heldOf] — and the control it opens is held for the lines that come
  /// after it.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async {
    final held = await heldOf(roomId);
    return Fc2LivePlayParser.qualitiesOf(held.control.playlists);
  }

  /// The one line of [roomId] at [quality] (the adaptive master when it is
  /// null), leased for the rest of its control's grant.
  ///
  /// The quality that plays is named by the line's label: a tier the channel no
  /// longer offers is played down the list, and the control knows better than
  /// the request does.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async {
    final asked = quality?.qualityId ?? Fc2LivePlayParser.autoQualityId;
    if (!Fc2LivePlayParser.qualityIds.contains(asked)) {
      throw Fc2LiveFailure(Fc2LiveFailureKind.invalidArgument, 'quality "$asked" is not an FC2 Live quality');
    }
    final id = channelOf(roomId);
    final held = await heldOf(id);
    final playlist = Fc2LivePlayParser.playlistFor(held.control.playlists, asked);
    if (playlist == null) {
      throw Fc2LiveFailure(Fc2LiveFailureKind.streamUnavailable, 'channel $id offers no playlist for $asked');
    }
    return Fc2LivePlayParser.lines(playlist, channelId: id, issuedAt: held.issuedAt);
  }

  DateTime _holdUntil(DateTime issuedAt) => issuedAt.add(Fc2LiveEndpoints.controlLife - Fc2LivePlayParser.renewLead);

  /// Capabilities.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= Fc2LiveRoomProvider(site: this);
    final area = _area ??= Fc2LiveAreaProvider(site: this);
    final discovery = _discovery ??= Fc2LiveDiscoveryProvider(site: this);
    final search = _search ??= Fc2LiveSearchProvider(site: this);
    final playback = _playback ??= Fc2LivePlaybackProvider(site: this);
    final danmaku = _danmaku ??= Fc2LiveDanmakuProvider(site: this);
    final link = _link ??= Fc2LiveLinkResolver(site: this);
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
