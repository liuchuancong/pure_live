import 'dart:async';
import 'dart:math';

// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_auth_capability.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_play_lease_lookup.dart';
import 'package:live_sites/src/capabilities/live_playback_plan_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/capabilities/live_super_chat_feed.dart';
import 'package:live_sites/src/core/live_site.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_http.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_wbi.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_manifest.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_area_provider.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_auth_provider.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_discovery_provider.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_link_resolver.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_play_lease_lookup.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_playback_provider.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_room_provider.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_room_refresh.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_search_provider.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_status_check.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_super_chat_feed_provider.dart';
import 'package:live_sites/src/platforms/bilibili/danmaku/bilibili_danmaku_session.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_auth_parser.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F]');

/// What the room's stream needs besides its identity: the canonical long room
/// id every play, danmaku and super-chat request uses while the card keeps the
/// id the user asked for (a short id must not change when the platform's
/// canonical one is longer).
final class BilibiliRoomData {
  /// Wraps the long id.
  const BilibiliRoomData(this.longId);

  /// Canonical long room id.
  final String longId;

  @override
  String toString() => 'BilibiliRoomData($longId)';
}

/// What the danmaku connection needs to join one room: the auth packet's long
/// room id, uid, token and buvid, the endpoints in the order to try, and the
/// WebSocket headers carrying the cookie the token was issued to.
final class BilibiliDanmakuArgs {
  /// Creates the arguments.
  const BilibiliDanmakuArgs({
    required this.longId,
    required this.uid,
    required this.token,
    required this.servers,
    required this.buvid,
    required this.headers,
  });

  /// The canonical long room id (the auth packet's `roomid`).
  final String longId;

  /// 0 for a guest; the logged-in user's uid from the same cookie.
  final int uid;

  /// The auth token; empty when discovery failed.
  final String token;

  /// The general gateway first, then the regional `host_list` nodes.
  final List<Uri> servers;

  /// The `buvid3` of the cookie.
  final String buvid;

  /// UA, Origin, Referer (long id) and the cookie.
  final Map<String, String> headers;

  /// The auth packet's `roomid` as the number the protocol asks for; 0 when
  /// the id is not a number (a guest-only fallback).
  int get roomId => int.tryParse(longId) ?? 0;

  @override
  String toString() =>
      'BilibiliDanmakuArgs($longId, uid $uid, ${servers.length} server(s), ${token.isEmpty ? 'no token' : '<redacted>'})';
}

/// The Bilibili adapter: manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2); requests in `api/`, parsing in `parsers/`, features
/// in `capabilities/`.
///
/// One anonymous session is kept per login cookie and shared by concurrent
/// callers: a cold start asks for the guest buvid, the WBI keys and the
/// `w_webid` access id once each, and reuses them for
/// [BilibiliEndpoints.sessionLifetime]. A changed cookie starts a new session.
/// Every WBI-signed request answers `-352` (risk control) with one retry that
/// renews all three, [BilibiliEndpoints.retryDelay] later.
final class BilibiliSite implements LiveSite {
  /// Creates the adapter over [http]. [loginCookie] supplies the user's cookie
  /// (null: every request goes out as a guest); [storedUid] is the uid saved
  /// with it, used for the danmaku when the cookie carries no `DedeUserID`.
  /// [now] and [sleep] are injectable for tests.
  factory BilibiliSite({
    required BilibiliHttp http,
    String Function()? loginCookie,
    int Function()? storedUid,
    DateTime Function()? now,
    Future<void> Function(Duration)? sleep,
    Random? random,
  }) {
    return BilibiliSite._(
      http,
      loginCookie ?? _guest,
      storedUid ?? _noUid,
      now ?? DateTime.now,
      sleep ?? Future<void>.delayed,
      random ?? Random.secure(),
    );
  }

  BilibiliSite._(this.http, this.loginCookie, this.storedUid, this.now, this.sleep, this.random);

  static String _guest() => '';

  static int _noUid() => 0;

  /// Transport.
  final BilibiliHttp http;

  /// The user's login cookie, read per request so a changed login applies at
  /// once.
  final String Function() loginCookie;

  /// The uid stored with the login cookie, used only when the cookie itself
  /// names no `DedeUserID`.
  final int Function() storedUid;

  /// Injectable clock (the WBI `wts`, session and gift-table caches).
  final DateTime Function() now;

  /// Injectable pause (the risk-control retry and the recommendation retry).
  final Future<void> Function(Duration) sleep;

  /// The source of the auth packet's `queue_uuid`.
  final Random random;

  _Session? _session;
  String? _appliedLogin;
  int _appliedUid = 0;
  final Map<String, String> _longIds = {};
  ({BilibiliGiftCatalog catalog, DateTime at})? _gifts;
  Future<BilibiliGiftCatalog>? _giftsFetch;

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => bilibiliManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Session -------------------------------------------------------------------

  /// The login cookie, control characters and a pasted `Cookie:` prefix
  /// stripped: the credential applied through [applyLoginCredential] when
  /// there is one, else what the application supplied at construction.
  String login() => _sanitizeCookie(_appliedLogin ?? loginCookie());

  /// Sanitizes a cookie header the way [login] hands it out: control
  /// characters and a pasted `Cookie:` prefix gone.
  static String _sanitizeCookie(String raw) {
    final value = raw.replaceAll(_controlCharacters, '').trim();
    return value.replaceFirst(RegExp(r'^Cookie:\s*', caseSensitive: false), '').trim();
  }

  /// Applies [cookie] as the login every request of this site carries from
  /// now on, with [uid] for the danmaku when the cookie itself names no
  /// `DedeUserID`. In-memory only — persistence is the application's business
  /// — and it survives until [clearLoginCredential].
  void applyLoginCredential({required String cookie, int? uid}) {
    final sanitized = _sanitizeCookie(cookie);
    _appliedLogin = sanitized.isEmpty ? null : sanitized;
    _appliedUid = uid ?? 0;
  }

  /// Removes the applied credential; requests carry the construction-time
  /// login again.
  void clearLoginCredential() {
    _appliedLogin = null;
    _appliedUid = 0;
  }

  /// The session of the current cookie; a changed cookie starts a new one
  /// (fetches that finish afterwards land in the discarded session).
  _Session _current() {
    final value = login();
    final session = _session;
    if (session != null && session.login == value) return session;
    return _session = _Session(value);
  }

  /// GETs [url] with [headers] (the capabilities' transport).
  Future<BilibiliResponse> httpGet(Uri url, {Map<String, String> headers = const {}}) =>
      http.get(url, headers: headers);

  /// API request headers for [cookie].
  Map<String, String> apiHeaders(String cookie) => BilibiliEndpoints.apiHeaders(cookie);

  /// The value of the cookie field [name], null when absent or empty.
  static String? cookieField(String cookie, String name) {
    final value = RegExp('(?:^|;)\\s*$name=([^;]*)').firstMatch(cookie)?.group(1)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// The buvid pair: the login cookie's own, else the guest pair from
  /// `finger/spi`, requested once for concurrent callers. A failed request
  /// gives none; the next request asks again.
  Future<({String buvid3, String buvid4})?> _buvid(_Session session) {
    final own = cookieField(session.login, 'buvid3');
    if (own != null) return Future.value((buvid3: own, buvid4: cookieField(session.login, 'buvid4') ?? ''));
    final guest = session.guest;
    if (guest != null) return Future.value(guest);
    return session.guestFetch ??= () async {
      try {
        final response = await http.get(BilibiliEndpoints.fingerSpi(), headers: apiHeaders(session.login));
        return session.guest = BilibiliRoomParser.buvid(response.text, status: response.status);
      } on BilibiliFailure {
        return null;
      } finally {
        session.guestFetch = null;
      }
    }();
  }

  /// The cookie of API and media requests: the login cookie, with the guest
  /// buvid pair appended when it carries no `buvid3`.
  Future<String> cookie() async {
    final session = _current();
    final pair = await _buvid(session);
    if (pair == null) return session.login;
    return BilibiliRoomParser.cookie(buvid3: pair.buvid3, buvid4: pair.buvid4, loginCookie: session.login);
  }

  /// The cookie known without a request (media and handshake headers).
  String knownCookie() {
    final session = _current();
    final guest = session.guest;
    if (guest != null) {
      return BilibiliRoomParser.cookie(buvid3: guest.buvid3, buvid4: guest.buvid4, loginCookie: session.login);
    }
    return session.login;
  }

  /// WBI keys from nav, reused for [BilibiliEndpoints.sessionLifetime];
  /// [renew] fetches new ones. A guest gets `-101` with the keys present, so
  /// the keys are read before the envelope is judged.
  Future<({String imgKey, String subKey})> _keys(_Session session, {bool renew = false}) {
    final cached = session.keys;
    if (!renew && cached != null && now().difference(cached.at) < BilibiliEndpoints.sessionLifetime) {
      return Future.value((imgKey: cached.imgKey, subKey: cached.subKey));
    }
    return session.keysFetch ??= () async {
      try {
        final response = await http.get(BilibiliEndpoints.nav(), headers: apiHeaders(await cookie()));
        final keys = BilibiliWbi.tryNavKeys(response.text);
        if (keys == null) {
          BilibiliRoomParser.checked(response.text, status: response.status, what: 'nav');
          throw const BilibiliFailure(BilibiliFailureKind.apiChanged, 'nav: no wbi_img keys');
        }
        session.keys = (imgKey: keys.imgKey, subKey: keys.subKey, at: now());
        return keys;
      } finally {
        session.keysFetch = null;
      }
    }();
  }

  /// `w_webid` from the `/lol` page, kept and renewed with the WBI keys.
  Future<String> _accessId(_Session session, {bool renew = false}) {
    final cached = session.accessId;
    if (!renew && cached != null && now().difference(cached.at) < BilibiliEndpoints.sessionLifetime) {
      return Future.value(cached.id);
    }
    return session.accessIdFetch ??= () async {
      try {
        final response = await http.get(BilibiliEndpoints.lol(), headers: apiHeaders(await cookie()));
        if (response.status == 412) throw const BilibiliFailure(BilibiliFailureKind.rateLimited, 'lol: HTTP 412');
        if (response.status >= 500) {
          throw BilibiliFailure(BilibiliFailureKind.network, 'lol: HTTP ${response.status}');
        }
        final id = BilibiliWbi.accessId(response.text);
        session.accessId = (id: id, at: now());
        return id;
      } finally {
        session.accessIdFetch = null;
      }
    }();
  }

  /// GETs [url] with the session cookie (the unsigned endpoints).
  Future<BilibiliResponse> unsignedGet(Uri url) async => await http.get(url, headers: apiHeaders(await cookie()));

  /// A WBI-signed GET of `api.live.bilibili.com` [path], parsed by [parse]. A
  /// `-352` answer renews the keys, the guest buvid and the access id and
  /// retries once after [BilibiliEndpoints.retryDelay]; a second `-352` is
  /// reported. [webId] adds the `w_webid` the second-area list demands.
  Future<({T value, String cookie})> signed<T>(
    String path,
    Map<String, String> params,
    T Function(BilibiliResponse response) parse, {
    bool webId = false,
  }) async {
    for (var attempt = 0; ; attempt++) {
      final renew = attempt > 0;
      final session = _current();
      if (renew) session.guest = null;
      final keys = await _keys(session, renew: renew);
      final cookie = await _cookieOf(session);
      final query = BilibiliWbi.sign(
        {...params, if (webId) 'w_webid': await _accessId(session, renew: renew)},
        imgKey: keys.imgKey,
        subKey: keys.subKey,
        wts: now().millisecondsSinceEpoch ~/ 1000,
      );
      final response = await http.get(
        Uri.parse('https://${BilibiliEndpoints.liveApiHost}$path?$query'),
        headers: apiHeaders(cookie),
      );
      try {
        return (value: parse(response), cookie: cookie);
      } on BilibiliFailure catch (failure) {
        if (renew || failure.kind != BilibiliFailureKind.riskControl) rethrow;
      }
      await sleep(BilibiliEndpoints.retryDelay);
    }
  }

  Future<String> _cookieOf(_Session session) async {
    final pair = await _buvid(session);
    if (pair == null) return session.login;
    return BilibiliRoomParser.cookie(buvid3: pair.buvid3, buvid4: pair.buvid4, loginCookie: session.login);
  }

  // Rooms ---------------------------------------------------------------------

  /// The long id requests for [requested] are answered with: the remembered
  /// one from the last detail, else [requested] itself (a number is its own
  /// canonical id).
  String longId(String requested) {
    final id = requested.trim();
    return _longIds[id] ?? id;
  }

  /// Remembers that the id the user asked for is the room [longId] (bounded,
  /// oldest entry dropped, so a long session cannot grow without end).
  void rememberLongId(String requested, String longId) {
    final id = requested.trim();
    _longIds.remove(id);
    _longIds[id] = longId;
    if (_longIds.length > 512) _longIds.remove(_longIds.keys.first);
  }

  /// The numeric room id a link or an address names, or null: Bilibili room
  /// ids are positive decimal integers of at most 18 digits, leading zeroes
  /// stripped.
  static String? roomNumber(String text) {
    if (!RegExp(r'^\d{1,18}$').hasMatch(text)) return null;
    final value = int.parse(text);
    return value > 0 ? '$value' : null;
  }

  /// The room id of a Bilibili address: `live.bilibili.com/{id}`,
  /// `/h5/{id}` and `/blanc/{id}`, and the old `www.bilibili.com/{id}` alias
  /// (a single path segment). Other bilibili hosts are not rooms
  /// (`space.bilibili.com/{uid}`), and neither is anything else.
  static String? roomIdFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    if (segments.isEmpty) return null;
    final host = uri.host.toLowerCase();
    if (host == BilibiliEndpoints.liveHost) {
      if (segments.length >= 2 && (segments.first == 'h5' || segments.first == 'blanc')) {
        return roomNumber(segments[1]);
      }
      return roomNumber(segments.first);
    }
    if ((host == 'www.bilibili.com' || host == 'bilibili.com') && segments.length == 1) {
      return roomNumber(segments.single);
    }
    return null;
  }

  /// Whether [url] is a short link that has to be followed before its room is
  /// known.
  static bool isShortLink(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host == BilibiliEndpoints.shortLinkHost || host.endsWith('.${BilibiliEndpoints.shortLinkHost}');
  }

  // Danmaku -------------------------------------------------------------------

  /// Danmaku credentials for the long room id: signed `getDanmuInfo`, tried up
  /// to [maxAttempts] times, [BilibiliEndpoints.retryDelay] × attempt apart,
  /// renewing the WBI keys on the second and fourth attempts.
  Future<BilibiliDanmakuArgs> danmakuArgs(String longId, {int maxAttempts = 4}) async {
    final numeric = int.tryParse(longId.trim());
    if (numeric == null || numeric <= 0) {
      throw BilibiliFailure(BilibiliFailureKind.notFound, 'room id $longId is not a number');
    }
    BilibiliFailure? last;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt == 1 || attempt == 3) _current().keys = null;
      try {
        final result = await signed(BilibiliEndpoints.danmakuInfoPath, {
          'id': '$numeric',
          'type': '0',
        }, (response) => BilibiliRoomParser.danmakuInfo(response.text, status: response.status));
        return BilibiliDanmakuArgs(
          longId: '$numeric',
          uid: BilibiliRoomParser.danmakuUid(cookie: login(), storedUid: _verifiedUid()),
          token: result.value.token,
          servers: result.value.servers,
          buvid: cookieField(result.cookie, 'buvid3') ?? '',
          headers: BilibiliEndpoints.mediaHeaders('$numeric', cookie: result.cookie),
        );
      } on BilibiliFailure catch (failure) {
        last = failure;
      }
      if (attempt + 1 < maxAttempts) await sleep(BilibiliEndpoints.retryDelay * (attempt + 1));
    }
    throw last!;
  }

  /// Credentials for a room whose discovery failed: the general gateway and an
  /// empty token, which the session reports as content-unavailable rather than
  /// joining without a token.
  Future<BilibiliDanmakuArgs> emptyDanmakuArgs(String longId) async {
    final numeric = int.tryParse(longId.trim()) ?? 0;
    final cookie = await this.cookie();
    return BilibiliDanmakuArgs(
      longId: '$numeric',
      uid: BilibiliRoomParser.danmakuUid(cookie: login(), storedUid: _verifiedUid()),
      token: '',
      servers: [Uri.parse(BilibiliEndpoints.danmakuGateway)],
      buvid: cookieField(cookie, 'buvid3') ?? '',
      headers: BilibiliEndpoints.mediaHeaders('$numeric', cookie: cookie),
    );
  }

  int _verifiedUid() {
    final session = _current();
    if (session.verifiedUid > 0) return session.verifiedUid;
    if (_appliedUid > 0) return _appliedUid;
    return storedUid();
  }

  // Gifts ---------------------------------------------------------------------

  /// The gift table every room's danmaku connection reads pictures and prices
  /// from: asked for without a cookie (it is public), once for concurrent
  /// callers, reused for [BilibiliEndpoints.giftCatalogLifetime] across rooms.
  /// A failure gives [BilibiliGiftCatalog.empty] and is not kept: the next room
  /// asks again.
  Future<BilibiliGiftCatalog> giftCatalog() {
    final cached = _gifts;
    if (cached != null && now().difference(cached.at) < BilibiliEndpoints.giftCatalogLifetime) {
      return Future.value(cached.catalog);
    }
    return _giftsFetch ??= () async {
      try {
        final response = await http.get(BilibiliEndpoints.giftConfig(), headers: apiHeaders(''));
        final catalog = BilibiliRoomParser.giftCatalog(response.text, status: response.status);
        _gifts = (catalog: catalog, at: now());
        return catalog;
      } on BilibiliFailure {
        // Gifts then go without the table's pictures and prices.
        return BilibiliGiftCatalog.empty;
      } finally {
        _giftsFetch = null;
      }
    }();
  }

  // Account -------------------------------------------------------------------

  /// The signed-in account's uid and name (`x/member/web/account`); `-101` is
  /// [BilibiliFailureKind.needsLogin]. A verified stored cookie's uid becomes
  /// the danmaku uid when the cookie has no `DedeUserID`.
  Future<({int uid, String name})> account() async {
    final session = _current();
    if (session.login.isEmpty) throw const BilibiliFailure(BilibiliFailureKind.needsLogin, 'no cookie');
    final account = await accountOf(cookie: session.login);
    session.verifiedUid = account.uid;
    return (uid: account.uid, name: account.name);
  }

  /// The account behind [cookie], read without touching the session: only the
  /// applied login (see [applyLoginCredential]) feeds the verified uid back.
  Future<({int uid, String name, String face})> accountOf({required String cookie}) async {
    final response = await http.get(BilibiliEndpoints.account(), headers: {'cookie': cookie});
    return BilibiliAuthParser.account(response.text, status: response.status);
  }

  // Capability wiring ---------------------------------------------------------

  BilibiliRoomProvider? _room;
  BilibiliAreaProvider? _area;
  BilibiliDiscoveryProvider? _discovery;
  BilibiliSearchProvider? _search;
  BilibiliPlaybackProvider? _playback;
  BilibiliDanmakuProvider? _danmaku;
  BilibiliLinkResolver? _link;
  BilibiliAuthProvider? _auth;
  BilibiliSuperChatFeedProvider? _superChats;
  BilibiliStatusCheck? _status;
  BilibiliRoomRefresh? _refresh;
  BilibiliPlayLeaseLookup? _lease;

  /// The capability of type [T], or null when bilibili does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final discovery = _discovery ??= BilibiliDiscoveryProvider(site: this);
    final room = _room ??= BilibiliRoomProvider(site: this, discovery: discovery);
    final area = _area ??= BilibiliAreaProvider(site: this);
    final search = _search ??= BilibiliSearchProvider(site: this);
    final playback = _playback ??= BilibiliPlaybackProvider(site: this);
    final danmaku = _danmaku ??= BilibiliDanmakuProvider(site: this);
    final link = _link ??= BilibiliLinkResolver(site: this);
    final auth = _auth ??= BilibiliAuthProvider(site: this);
    final superChats = _superChats ??= BilibiliSuperChatFeedProvider(site: this, rooms: room);
    final status = _status ??= BilibiliStatusCheck(site: this, rooms: room);
    final refresh = _refresh ??= BilibiliRoomRefresh(site: this, rooms: room);
    final lease = _lease ??= BilibiliPlayLeaseLookup(now: now);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => area as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LivePlaybackPlanResolver) => playback as T,
      const (LiveDanmakuProvider) => danmaku as T,
      const (LiveLinkResolver) => link as T,
      const (LiveAuthCapability) => auth as T,
      const (LiveSuperChatFeed) => superChats as T,
      const (LiveStatusCheck) => status as T,
      const (LiveRoomRefresh) => refresh as T,
      const (LivePlayLeaseLookup) => lease as T,
      _ => null,
    };
  }
}

/// The anonymous session built for one login cookie: guest buvid pair, WBI
/// keys, access id and the verified uid.
final class _Session {
  _Session(this.login);

  /// The user's cookie ('' when signed out).
  final String login;

  ({String buvid3, String buvid4})? guest;
  Future<({String buvid3, String buvid4})?>? guestFetch;

  ({String imgKey, String subKey, DateTime at})? keys;
  Future<({String imgKey, String subKey})>? keysFetch;

  ({String id, DateTime at})? accessId;
  Future<String>? accessIdFetch;

  int verifiedUid = 0;
}
