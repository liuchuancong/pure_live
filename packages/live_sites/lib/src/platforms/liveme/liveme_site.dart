import 'dart:math' as math;

// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'package:live_net/live_net.dart';
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
import 'package:live_sites/src/platforms/liveme/api/liveme_endpoints.dart';
import 'package:live_sites/src/platforms/liveme/api/liveme_http.dart';
import 'package:live_sites/src/platforms/liveme/api/liveme_signer.dart';
import 'package:live_sites/src/platforms/liveme/capabilities/liveme_discovery_provider.dart';
import 'package:live_sites/src/platforms/liveme/capabilities/liveme_link_resolver.dart';
import 'package:live_sites/src/platforms/liveme/capabilities/liveme_playback_provider.dart';
import 'package:live_sites/src/platforms/liveme/capabilities/liveme_room_provider.dart';
import 'package:live_sites/src/platforms/liveme/capabilities/liveme_search_provider.dart';
import 'package:live_sites/src/platforms/liveme/liveme_manifest.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_failure.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_link.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How many rooms keep their stream data for the playback capability.
const _streamLimit = 64;

/// The LiveMe adapter (parsing in `parsers/`; no chat: the reference has no
/// danmaku): manifest + capability discovery + lifecycle (ARCHITECTURE.md
/// §7.2).
///
/// A room is an anchor's short id, so stored follows keep matching; the user
/// id and the current broadcast's video id live in [LivemeRoomData]. Anonymous,
/// like the reference: no cookie, no account; every request carries
/// [LivemeEndpoints.headers] and goes as `liveme`. The requests are the
/// website's:
/// - recommendations and the directory are `featurelist` pages;
/// - search is `searchKeyword`, or a room lookup for a short id or a link;
/// - a room (entry) is the short id's `uid_vid_by_short_id`, then the
///   anchor's `getinfo` and, while broadcasting, the signed
///   `queryinfosimple`, in parallel;
/// - fresh media (a playback asked without a room entry) is
///   `uid_vid_by_short_id` and `queryinfosimple` only.
///
/// A private or paid broadcast is live and marked with its restriction; its
/// stream says why it is not played. There are no categories and no chat: the
/// area and danmaku capabilities answer null. Failures are [LivemeFailure]s;
/// nothing is disguised as an offline room.
final class LivemeSite implements LiveSite {
  /// Creates the adapter over [http]. [now] (the `_time` and signature
  /// clock) and [random] (the signature's `vali`) are injectable for tests.
  LivemeSite({required this.http, DateTime Function()? now, math.Random? random})
    : _now = now ?? DateTime.now,
      _signer = LivemeSigner(random: random);

  /// Transport.
  final LivemeHttp http;

  final DateTime Function() _now;
  final LivemeSigner _signer;

  /// The stream data of the room whose entry is latest, by short id: the
  /// playback capability hands it out until the next entry.
  final Map<String, LivemeRoomData> _streams = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => livemeManifest;

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

  Future<({String userId, String videoId})> _mapping(String shortId) async {
    final response = await http.get(LivemeEndpoints.mappingUrl(shortId, now: _now()), shortId: shortId);
    return LivemeRoomParser.mapping(response.text, status: response.status);
  }

  Future<LivemeProfile> _profile(String userId) async {
    final response = await http.get(LivemeEndpoints.profileUrl(userId, now: _now()));
    return LivemeRoomParser.profile(response.text, userId: userId, status: response.status);
  }

  Future<LivemeSnapshot> _video(String videoId, {String? shortId, bool media = false}) async {
    final response = await http.send(_videoRequest(videoId, shortId: shortId));
    return LivemeRoomParser.video(
      response.text,
      videoId: videoId,
      shortId: shortId,
      media: media,
      status: response.status,
    );
  }

  /// The signed `queryinfosimple` POST of [videoId]: the form and
  /// `lm-s-sign` of [LivemeSigner], the referer of [shortId]'s room when
  /// known, the site's plain form content type.
  LiveRequest _videoRequest(String videoId, {String? shortId}) {
    final now = _now();
    final signed = _signer.sign(
      query: LivemeEndpoints.videoQuery,
      form: {
        '_time': '${now.millisecondsSinceEpoch}',
        'thirdchannel': '6',
        'videoid': videoId,
        'area': 'en',
        'vali': _signer.vali(),
      },
      now: now,
    );
    final url = LivemeEndpoints.videoUrl;
    return LiveRequest.custom(
      method: 'POST',
      site: livemeSiteId,
      url: url,
      headers: {
        ...LivemeEndpoints.headers(shortId: shortId),
        'lm-s-sign': signed.signature,
        'content-type': 'application/x-www-form-urlencoded',
      },
      body: LiveRequest.form(url, fields: signed.fields, site: livemeSiteId).body,
    );
  }

  // Featured list -------------------------------------------------------------

  /// The featured page [page] of [pageSize] rooms (sent, kept within
  /// 1–50). A page below 1 is a caller error, refused before any request.
  Future<({List<LiveRoom> rooms, bool hasMore})> featured({required int page, required int pageSize}) async {
    if (page < 1) throw LivemeFailure(LivemeFailureKind.invalidArgument, 'page $page is below 1');
    final response = await http.get(
      LivemeEndpoints.featuredUrl(page: page, pageSize: pageSize.clamp(1, LivemeEndpoints.maxRecommendSize)),
    );
    return LivemeRoomParser.featuredPage(response.text, status: response.status);
  }

  // Search --------------------------------------------------------------------

  /// Anchors for [keyword]:
  /// - a short id (5–12 digits) or a room, anchor or share link finds that
  ///   room on page 1 only (its refresh detail; an anchor or share link first
  ///   asks for the short id); an unknown room finds nothing;
  /// - a blank keyword, a page or a page size below 1 finds nothing, without
  ///   a request;
  /// - anything else is a keyword of `searchKeyword`, the page size sent
  ///   within 1–40 (the site answers 20 a page whatever is asked); a keyword
  ///   over 256 characters is refused before any request.
  ///
  /// Whether more pages follow is not known here (the site does not say).
  Future<({List<LiveRoom> rooms, bool? hasMore})> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final reference = LivemeLink.parseOrShortId(keyword);
    if (reference != null) {
      if (page != 1) return (rooms: const <LiveRoom>[], hasMore: null);
      try {
        final shortId = await resolveLink(reference);
        return (rooms: [await detail(shortId, media: false)], hasMore: null);
      } on LivemeFailure catch (failure) {
        if (failure.kind != LivemeFailureKind.notFound) rethrow;
        return (rooms: const <LiveRoom>[], hasMore: null);
      }
    }
    final query = keyword.trim();
    if (query.isEmpty || page < 1 || pageSize < 1) return (rooms: const <LiveRoom>[], hasMore: null);
    if (query.length > LivemeEndpoints.keywordLimit) {
      throw const LivemeFailure(LivemeFailureKind.invalidArgument, 'keyword is over 256 characters');
    }
    final response = await http.get(
      LivemeEndpoints.searchUrl(
        query,
        page: page,
        pageSize: pageSize.clamp(1, LivemeEndpoints.maxSearchSize),
        now: _now(),
      ),
    );
    return (rooms: LivemeRoomParser.searchPage(response.text, status: response.status), hasMore: null);
  }

  /// The short id [link] names (the search's exact find and the link
  /// resolver's share pages): as written, or asked of the anchor's profile or
  /// the broadcast.
  Future<String> resolveLink(LivemeLink link) async => switch (link.kind) {
    LivemeLinkKind.shortId => link.id,
    LivemeLinkKind.userId => (await _profile(link.id)).shortId,
    LivemeLinkKind.videoId => (await _video(link.id)).shortId,
  };

  // Rooms ---------------------------------------------------------------------

  /// Room [roomId]: the short id's user and broadcast, then the anchor's
  /// profile and, when broadcasting, the broadcast, in parallel; both must be
  /// this room's and this anchor's. A room id that is not a short id is
  /// not-found without a request. With [media] the stream data comes along
  /// and is kept for the playback capability; a broadcast that cannot be
  /// played (private or paid, not live, no media) is still returned, a
  /// private or paid one live and marked, and its stream says why.
  Future<LiveRoom> detail(String roomId, {bool media = true}) async {
    final shortId = LivemeEndpoints.normalizeShortId(roomId);
    if (shortId == null) throw LivemeFailure(LivemeFailureKind.notFound, 'not a short id: $roomId');
    final mapping = await _mapping(shortId);
    final profileAnswer = _profile(mapping.userId);
    final LivemeSnapshot snapshot;
    final LivemeProfile profile;
    if (mapping.videoId.isEmpty) {
      profile = await profileAnswer;
      snapshot = LivemeRoomParser.offline(profile);
    } else {
      final answers = await Future.wait<Object?>([
        profileAnswer,
        _video(mapping.videoId, shortId: shortId, media: media),
      ]);
      profile = answers[0]! as LivemeProfile;
      final video = answers[1]! as LivemeSnapshot;
      if (video.userId != mapping.userId) {
        throw LivemeFailure(LivemeFailureKind.apiChanged, 'queryinfosimple: not the anchor of $shortId');
      }
      snapshot = LivemeRoomParser.withProfile(video, profile);
    }
    if (profile.shortId != shortId) {
      throw LivemeFailure(LivemeFailureKind.apiChanged, 'getinfo: ${profile.shortId} for $shortId');
    }
    final data = media ? LivemeRoomParser.roomData(snapshot) : null;
    if (data != null) _remember(data);
    return LivemeRoomParser.room(snapshot, data: data);
  }

  // Streams -------------------------------------------------------------------

  /// The stream data of [roomId]: the one its room entry brought, or a fresh
  /// broadcast lookup — the capabilities are asked by room id alone. A room
  /// id that is not a short id is not-found without a request.
  Future<LivemeRoomData> _stream(String roomId) async {
    final shortId = LivemeEndpoints.normalizeShortId(roomId);
    if (shortId == null) throw LivemeFailure(LivemeFailureKind.notFound, 'not a short id: $roomId');
    final kept = _streams[shortId];
    if (kept != null) return kept;
    final data = await _media(shortId);
    return _streams[shortId] = data;
  }

  /// The stream data of room [shortId]'s current broadcast: the short id's
  /// user and broadcast, then the broadcast (two requests; the profile adds
  /// nothing to a stream). No broadcast is stream-unavailable.
  Future<LivemeRoomData> _media(String shortId) async {
    final mapping = await _mapping(shortId);
    if (mapping.videoId.isEmpty) {
      throw LivemeFailure(LivemeFailureKind.streamUnavailable, '$shortId is not broadcasting');
    }
    final video = await _video(mapping.videoId, shortId: shortId, media: true);
    if (video.userId != mapping.userId) {
      throw LivemeFailure(LivemeFailureKind.apiChanged, 'queryinfosimple: not the anchor of $shortId');
    }
    return LivemeRoomParser.roomData(video);
  }

  /// The qualities [roomId] offers now.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async => LivemeRoomParser.qualities(await _stream(roomId));

  /// The lines of [roomId] at [quality] (the source quality when it is null;
  /// the reference's stored ids are read as the new ones): FLV then HLS, each
  /// with the media headers.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async {
    final id = quality?.qualityId ?? LivemeEndpoints.sourceQualityId;
    return LivemeRoomParser.lines(await _stream(roomId), id);
  }

  /// Keeps [data] as the latest of its room, dropping the oldest past
  /// [_streamLimit].
  void _remember(LivemeRoomData data) {
    _streams
      ..remove(data.shortId)
      ..[data.shortId] = data;
    if (_streams.length > _streamLimit) _streams.remove(_streams.keys.first);
  }

  // Capability wiring ---------------------------------------------------------

  LivemeRoomProvider? _room;
  LivemeDiscoveryProvider? _discovery;
  LivemeSearchProvider? _search;
  LivemePlaybackProvider? _playback;
  LivemeLinkResolver? _link;

  /// The capability of type [T], or null when LiveMe does not support it
  /// (ARCHITECTURE.md §4.1). There is no category catalog (the featured list
  /// is the one listing) and no chat, so the area and danmaku capabilities
  /// answer null. Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= LivemeRoomProvider(site: this);
    final discovery = _discovery ??= LivemeDiscoveryProvider(site: this);
    final search = _search ??= LivemeSearchProvider(site: this);
    final playback = _playback ??= LivemePlaybackProvider(site: this);
    final link = _link ??= LivemeLinkResolver(site: this);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LiveLinkResolver) => link as T,
      _ => null,
    };
  }
}
