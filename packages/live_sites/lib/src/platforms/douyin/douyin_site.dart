import 'dart:async';
import 'dart:math';

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
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_endpoints.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_http.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_sign.dart';
import 'package:live_sites/src/platforms/douyin/capabilities/douyin_area_provider.dart';
import 'package:live_sites/src/platforms/douyin/capabilities/douyin_discovery_provider.dart';
import 'package:live_sites/src/platforms/douyin/capabilities/douyin_link_resolver.dart';
import 'package:live_sites/src/platforms/douyin/capabilities/douyin_playback_provider.dart';
import 'package:live_sites/src/platforms/douyin/capabilities/douyin_room_provider.dart';
import 'package:live_sites/src/platforms/douyin/capabilities/douyin_search_provider.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_danmaku_session.dart';
import 'package:live_sites/src/platforms/douyin/douyin_manifest.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_failure.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F]');

/// What a room's streams need besides its identity: the lasting web_rid,
/// this broadcast's room_id, the stream description (`room.stream_url` while
/// live) and when the detail was received (the leases count from then).
final class DouyinRoomData {
  /// Wraps the room's stream handle.
  const DouyinRoomData({required this.webRid, required this.issuedAt, this.roomId, this.streamUrl});

  /// The room's lasting id (its identity).
  final String webRid;

  /// This broadcast's room_id; every broadcast gets a new one.
  final String? roomId;

  /// `room.stream_url` while live, else null.
  final Map<String, dynamic>? streamUrl;

  /// When the detail was received.
  final DateTime issuedAt;

  @override
  String toString() => 'DouyinRoomData($webRid, ${roomId ?? '-'})';
}

/// What the danmaku connection needs to join one broadcast: the room page id
/// (the Referer of the handshake), this broadcast's room_id, the visitor's
/// 19-digit id and the cookie to shake hands with.
final class DouyinDanmakuArgs {
  /// Wraps the connection's arguments.
  const DouyinDanmakuArgs({required this.webRid, required this.roomId, required this.userId, required this.cookie});

  /// The room page id (`referer` of the handshake).
  final String webRid;

  /// This broadcast's room_id; every broadcast gets a new one.
  final String roomId;

  /// The 19-digit visitor id (`user_unique_id`), the same for every room.
  final String userId;

  /// The cookie of the API requests (the user's, else the anonymous ttwid);
  /// empty when there is none.
  final String cookie;

  @override
  String toString() => 'DouyinDanmakuArgs($webRid, $roomId, $userId, ${cookie.isEmpty ? 'guest' : '<redacted>'})';
}

/// One room answer with the request context the streams and the danmaku
/// connection need.
typedef DouyinFetched = ({DouyinRoomParse room, DateTime issuedAt, String cookie});

/// The Douyin adapter: manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2); requests in `api/`, parsing in `parsers/`, features
/// in `capabilities/`. Requests carry the login cookie, else an anonymous
/// `ttwid` fetched once per cookie and shared by concurrent callers; a
/// changed cookie starts a new session at once.
final class DouyinSite implements LiveSite {
  /// Creates the adapter over [http]. [loginCookie] supplies the user's
  /// cookie (null: every request goes out as a guest); [now] and [random]
  /// (visitor id, msToken, `a_bogus`) are injectable for tests.
  factory DouyinSite({
    required DouyinHttp http,
    String Function()? loginCookie,
    DateTime Function()? now,
    Random? random,
  }) {
    final source = random ?? Random.secure();
    final clock = now ?? DateTime.now;
    return DouyinSite._(
      http,
      loginCookie ?? _guest,
      clock,
      DouyinSigner.visitorId(source),
      DouyinSigner(userAgent: DouyinEndpoints.userAgent, now: clock, random: source),
    );
  }

  DouyinSite._(this.http, this.loginCookie, this.now, this.visitorId, this.signer);

  static String _guest() => '';

  /// Transport.
  final DouyinHttp http;

  /// The user's login cookie, read per request so a changed login applies at
  /// once.
  final String Function() loginCookie;

  /// Injectable clock.
  final DateTime Function() now;

  /// The 19-digit anonymous visitor id of the danmaku connection, the same
  /// for every room (one per adapter).
  final String visitorId;

  /// The request signer (msToken, `a_bogus`, the danmaku signature).
  final DouyinSigner signer;

  _DouyinSession? _session;

  /// How long to go without an anonymous session after the home page set no
  /// ttwid before asking again (the page is about a megabyte).
  static const Duration bootstrapRetry = Duration(minutes: 5);

  /// Start-time lookups in flight, by broadcast room_id.
  final Map<String, Future<DateTime?>> _startLookups = {};

  /// Broadcasts whose start time a reflow answer already gave.
  final Map<String, DateTime> _startTimes = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => douyinManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  /// GETs [url] with [headers] (the capabilities' transport).
  Future<DouyinResponse> httpGet(Uri url, {Map<String, String> headers = const {}}) => http.get(url, headers: headers);

  // Session -------------------------------------------------------------------

  /// The login cookie, control characters and a pasted `Cookie:` prefix
  /// stripped.
  String login() {
    final raw = loginCookie().replaceAll(_controlCharacters, '').trim();
    return raw.replaceFirst(RegExp(r'^Cookie:\s*', caseSensitive: false), '').trim();
  }

  /// The session of the current cookie; a changed cookie starts a new one.
  _DouyinSession _current() {
    final login = this.login();
    final session = _session;
    if (session != null && session.login == login) return session;
    return _session = _DouyinSession(login);
  }

  /// The cookie of API requests: the user's, else the anonymous one; empty
  /// while a bootstrap is failing. A session whose cookie changed while its
  /// bootstrap ran is not used.
  Future<String> cookie() async {
    while (true) {
      final session = _current();
      final value = await _sessionCookie(session);
      if (identical(_current(), session)) return value;
    }
  }

  /// The cookie known without a request (media and handshake headers).
  String knownCookie() {
    final session = _current();
    return session.login.isNotEmpty ? session.login : session.anonymous ?? '';
  }

  Future<String> _sessionCookie(_DouyinSession session) async {
    if (session.login.isNotEmpty) return session.login;
    final anonymous = session.anonymous;
    if (anonymous != null) return anonymous;
    final missedAt = session.missedAt;
    if (missedAt != null && now().difference(missedAt) < bootstrapRetry) return '';
    return await (session.bootstrap ??= _bootstrap(session)) ?? '';
  }

  /// `GET live.douyin.com/?from_nav=1` keeps its `ttwid` and `UIFID_TEMP`. A
  /// failed request gives none and the next request asks again; a page
  /// without a ttwid is not asked for again for [bootstrapRetry].
  Future<String?> _bootstrap(_DouyinSession session) async {
    try {
      return _keep(session, await http.get(DouyinEndpoints.home(), headers: apiHeaders('')));
    } on DouyinFailure {
      return null;
    } finally {
      session.bootstrap = null;
    }
  }

  String? _keep(_DouyinSession session, DouyinResponse response) {
    if (response.status < 200 || response.status >= 300) return null;
    final cookie = DouyinRoomParser.anonymousCookie(response.headers);
    if (cookie == null) {
      session.missedAt = now();
      return null;
    }
    session.missedAt = null;
    return session.anonymous ??= cookie;
  }

  /// GETs the home page, starting the anonymous session from it when the
  /// current login has none yet (the same request answers the categories).
  Future<DouyinResponse> home() async {
    final session = _current();
    final response = await http.get(DouyinEndpoints.home(), headers: apiHeaders(knownCookie()));
    if (session.login.isEmpty && session.anonymous == null) _keep(session, response);
    return response;
  }

  // Headers -------------------------------------------------------------------

  /// Headers of the `live.douyin.com` API and pages.
  Map<String, String> apiHeaders(String cookie) => {
    'authority': DouyinEndpoints.liveHost,
    'referer': DouyinEndpoints.origin,
    'user-agent': DouyinEndpoints.userAgent,
    if (cookie.isNotEmpty) 'cookie': cookie,
  };

  /// Headers of the www search requests: the web client's search page as the
  /// Referer (an empty keyword for the partition rooms).
  Map<String, String> searchHeaders(String keyword, String cookie) => {
    'user-agent': DouyinEndpoints.userAgent,
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'zh-CN,zh;q=0.9',
    'referer': 'https://${DouyinEndpoints.webHost}/search/${Uri.encodeComponent(keyword)}?source=switch_tab&type=live',
    'origin': 'https://${DouyinEndpoints.webHost}',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'same-origin',
    if (cookie.isNotEmpty) 'cookie': cookie,
  };

  /// Headers of the short-link and reflow requests of link resolution.
  static const Map<String, String> shareHeaders = {
    'user-agent': DouyinEndpoints.shareUserAgent,
    'accept': '*/*',
    'origin': DouyinEndpoints.origin,
    'referer': '${DouyinEndpoints.origin}/',
  };

  // Rooms ---------------------------------------------------------------------

  /// A room by web_rid, or by a broadcast's room_id (17 digits or more; its
  /// identity becomes the owner's web_rid, and an ended broadcast is queried
  /// again by that web_rid).
  Future<DouyinFetched> fetch(String roomId) async {
    final id = roomId.trim();
    if (id.isEmpty) throw const DouyinFailure(DouyinFailureKind.notFound, 'empty room id');
    if (!DouyinRoomParser.isBroadcastId(id)) return await byWebRid(id);
    final reflowed = await reflowFetched(id);
    if (!reflowed.room.sessionEnded) return reflowed;
    return await byWebRid(reflowed.room.room.roomId);
  }

  /// Enter, then the room page when enter fails for any reason but
  /// not-found: a page without the room state reports enter's error.
  Future<DouyinFetched> byWebRid(String webRid) async {
    try {
      return await enter(webRid);
    } on DouyinFailure catch (failure) {
      if (failure.kind == DouyinFailureKind.notFound) rethrow;
      try {
        return await roomPage(webRid);
      } on DouyinFailure catch (pageFailure) {
        if (pageFailure.kind == DouyinFailureKind.apiChanged) throw failure;
        rethrow;
      }
    }
  }

  /// `room/web/enter/`, signed with `a_bogus`.
  Future<DouyinFetched> enter(String webRid) async {
    final cookie = await this.cookie();
    final response = await http.get(
      signer.signedUrl(DouyinEndpoints.enter(), DouyinEndpoints.enterParams(webRid)),
      headers: apiHeaders(cookie),
    );
    return (
      room: DouyinRoomParser.enter(response.text, webRid: webRid, status: response.status, headers: response.headers),
      issuedAt: now(),
      cookie: cookie,
    );
  }

  /// The room page `live.douyin.com/{web_rid}` with the session cookie.
  Future<DouyinFetched> roomPage(String webRid) async {
    final cookie = await this.cookie();
    final response = await http.get(DouyinEndpoints.roomPage(webRid), headers: apiHeaders(cookie));
    return (
      room: DouyinRoomParser.roomPage(
        response.text,
        webRid: webRid,
        status: response.status,
        headers: response.headers,
      ),
      issuedAt: now(),
      cookie: cookie,
    );
  }

  /// `room/reflow/info/` for a broadcast room_id (the only answer carrying
  /// its start time, and the one that says the broadcast ended).
  Future<DouyinFetched> reflowFetched(String roomId) async {
    final cookie = await this.cookie();
    final response = await http.get(DouyinEndpoints.reflow(roomId), headers: apiHeaders(cookie));
    return (
      room: DouyinRoomParser.reflow(response.text, status: response.status, headers: response.headers),
      issuedAt: now(),
      cookie: cookie,
    );
  }

  /// The owner's web_rid of a reflow link (the short-link path's `app_id`
  /// and `verifyFp`); null when the answer names none.
  Future<String?> reflowWebRid(String roomId) async {
    try {
      final response = await http.get(
        DouyinEndpoints.reflow(roomId, appId: DouyinEndpoints.shareAppId, verifyFp: true),
        headers: shareHeaders,
      );
      return response.status == 200 ? DouyinRoomParser.reflowWebRid(response.text) : null;
    } on DouyinFailure {
      return null;
    }
  }

  /// The broadcast's start time (M4.D): enter and the room page have none,
  /// so a live room without one asks reflow for its room_id, waiting at most
  /// [startLookupWait]. Best effort: a failure, a slow answer or another
  /// broadcast leaves the room as it is; a late answer is remembered for the
  /// next detail of the broadcast.
  Future<DateTime?> startTime(String broadcast, {required String webRid}) async {
    if (broadcast.isEmpty) return null;
    final remembered = _startTimes[broadcast];
    if (remembered != null) return remembered;
    final lookup = _startLookups.putIfAbsent(broadcast, () => _lookUpStart(broadcast, webRid));
    try {
      return await lookup;
    } finally {
      if (identical(_startLookups[broadcast], lookup)) {
        unawaited(_startLookups.remove(broadcast));
      }
    }
  }

  /// How long a detail waits for one start-time lookup.
  static const Duration startLookupWait = Duration(seconds: 3);

  Future<DateTime?> _lookUpStart(String broadcast, String webRid) async {
    try {
      final fetched = await reflowFetched(broadcast);
      final startedAt = fetched.room.room.broadcast.startedAt;
      if (startedAt == null || fetched.room.roomId != broadcast || fetched.room.room.roomId != webRid) return null;
      _startTimes.remove(broadcast);
      _startTimes[broadcast] = startedAt;
      if (_startTimes.length > 64) _startTimes.remove(_startTimes.keys.first);
      return startedAt;
    } on DouyinFailure {
      return null;
    }
  }

  /// The danmaku arguments of room [roomId]'s broadcast now (a new detail
  /// request), or null when the room is not live or names no broadcast.
  Future<DouyinDanmakuArgs?> danmakuArgs(String roomId) async {
    final fetched = await fetch(roomId);
    final room = fetched.room;
    if (!room.room.broadcast.isLiveNow) return null;
    final broadcast = room.roomId ?? '';
    if (broadcast.isEmpty) return null;
    return DouyinDanmakuArgs(
      webRid: room.room.roomId,
      roomId: broadcast,
      userId: room.userUniqueId ?? visitorId,
      cookie: fetched.cookie,
    );
  }

  // Capability wiring ---------------------------------------------------------

  DouyinRoomProvider? _room;
  DouyinAreaProvider? _area;
  DouyinDiscoveryProvider? _discovery;
  DouyinSearchProvider? _search;
  DouyinPlaybackProvider? _playback;
  DouyinDanmakuProvider? _danmaku;
  DouyinLinkResolver? _link;

  /// The capability of type [T], or null when douyin does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= DouyinRoomProvider(site: this);
    final area = _area ??= DouyinAreaProvider(site: this);
    final discovery = _discovery ??= DouyinDiscoveryProvider(site: this);
    final search = _search ??= DouyinSearchProvider(site: this);
    final playback = _playback ??= DouyinPlaybackProvider(site: this);
    final danmaku = _danmaku ??= DouyinDanmakuProvider(site: this);
    final link = _link ??= DouyinLinkResolver(site: this);
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

/// The anonymous session of one login cookie ('' when signed out).
final class _DouyinSession {
  _DouyinSession(this.login);

  /// The user's cookie.
  final String login;

  /// `ttwid=…; UIFID_TEMP=…` from the home page.
  String? anonymous;

  /// When the home page last set no ttwid.
  DateTime? missedAt;

  /// The bootstrap in flight.
  Future<String?>? bootstrap;
}
