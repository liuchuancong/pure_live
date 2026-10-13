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
import 'package:live_sites/src/platforms/huya/api/huya_endpoints.dart';
import 'package:live_sites/src/platforms/huya/api/huya_http.dart';
import 'package:live_sites/src/platforms/huya/capabilities/huya_area_provider.dart';
import 'package:live_sites/src/platforms/huya/capabilities/huya_discovery_provider.dart';
import 'package:live_sites/src/platforms/huya/capabilities/huya_link_resolver.dart';
import 'package:live_sites/src/platforms/huya/capabilities/huya_playback_provider.dart';
import 'package:live_sites/src/platforms/huya/capabilities/huya_room_provider.dart';
import 'package:live_sites/src/platforms/huya/capabilities/huya_search_provider.dart';
import 'package:live_sites/src/platforms/huya/danmaku/huya_danmaku_session.dart';
import 'package:live_sites/src/platforms/huya/huya_manifest.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_play_parser.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F]');
final RegExp _yyuid = RegExp(r'(?:^|;\s*)yyuid=(\d+)(?:;|$)');

/// The canonical rid a room's streams and danmaku requests use, riding in the
/// room's transient stream handle.
final class HuyaRoomData {
  /// Wraps the canonical rid.
  const HuyaRoomData(this.rid);

  /// Canonical numeric room id.
  final String rid;

  @override
  String toString() => 'HuyaRoomData($rid)';
}

/// What a danmaku connection needs for one room: the streamer uid whose
/// `live:`/`chat:` groups are registered, and the channel ids.
final class HuyaDanmakuArgs {
  /// Wraps the uid and the channel ids.
  const HuyaDanmakuArgs({required this.uid, required this.topSid, required this.subSid});

  /// Streamer uid (`profileInfo.uid`).
  final int uid;

  /// Top channel id; 0 when the room has none.
  final int topSid;

  /// Sub channel id; 0 when the room has none.
  final int subSid;

  @override
  String toString() => 'HuyaDanmakuArgs($uid, $topSid, $subSid)';
}

/// The Huya adapter: manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2); requests in `api/`, parsing in `parsers/`, features
/// in `capabilities/`. A single anonymous viewer uid (the login cookie's
/// `yyuid`, else an anonymous login, else a temporary one) signs every web
/// play line. [loginCookie] supplies the viewer cookie (null: a guest); the
/// clock ([now]) and randomness are injectable for tests.
final class HuyaSite implements LiveSite {
  /// Creates the adapter over [http].
  HuyaSite({required this.http, String Function()? loginCookie, DateTime Function()? now, Random? random})
    : loginCookie = loginCookie ?? _guest,
      now = now ?? DateTime.now,
      _random = random ?? Random.secure() {
    guid = _generateGuid(_random);
    fallbackUid = _generateFallbackUid(_random);
  }

  static String _guest() => '';

  /// Transport.
  final HuyaHttp http;

  /// The viewer login cookie (its `yyuid` is the signing uid), read per
  /// request so a changed login applies at once.
  final String Function() loginCookie;

  /// Injectable clock.
  final DateTime Function() now;

  final Random _random;

  /// This adapter's signing clock (a strictly increasing `seqid`).
  final HuyaSignClock clock = HuyaSignClock();

  /// This instance's GUID for the WUP token's `tId` (the deferred path).
  late final String guid;

  /// The temporary viewer uid while anonymous login fails; never cached as an
  /// official identity.
  late final int fallbackUid;

  int? _anonymousUid;
  final Map<String, int> _uids = {};
  final Map<String, String> _rids = {};
  Future<int?>? _anonymousLogin;

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => huyaManifest;

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
  Future<({String text, int status})> httpGet(Uri url, {Map<String, String> headers = const {}}) =>
      http.get(url, headers: headers);

  /// POSTs [json] as a JSON body.
  Future<({String text, int status})> httpPostJson(
    Uri url, {
    required Object? json,
    Map<String, String> headers = const {},
  }) => http.postJson(url, json: json, headers: headers);

  // Identity ------------------------------------------------------------------

  /// The login cookie, control characters and a pasted `Cookie:` prefix
  /// stripped.
  String cookie() {
    final raw = loginCookie().replaceAll(_controlCharacters, '').trim();
    return raw.replaceFirst(RegExp(r'^Cookie:\s*', caseSensitive: false), '').trim();
  }

  /// The viewer uid signing web play lines: the cookie's `yyuid`, else the
  /// cached anonymous uid, else one shared anonymous login; when that fails,
  /// the temporary uid and the next open asks again.
  Future<int> viewerUid() async {
    final account = _uidFromCookie(cookie());
    if (account != null) return account;
    if (_anonymousUid case final uid?) return uid;
    final login = _anonymousLogin ??= _requestAnonymousUid();
    try {
      final uid = await login;
      if (uid != null) {
        _anonymousUid = uid;
        return uid;
      }
    } finally {
      if (identical(_anonymousLogin, login)) _anonymousLogin = null;
    }
    return fallbackUid;
  }

  Future<int?> _requestAnonymousUid() async {
    try {
      final response = await http.postJson(
        HuyaEndpoints.anonymousLogin(),
        json: const {'appId': 5002, 'byPass': 3, 'context': '', 'version': '2.4', 'data': <String, Object?>{}},
        headers: webHeaders(),
      );
      return HuyaRoomParser.anonymousUid(response.text, status: response.status);
    } on HuyaFailure {
      return null;
    }
  }

  /// A 32-digit lower-case hexadecimal GUID.
  static String _generateGuid(Random random) =>
      [for (var i = 0; i < 32; i++) random.nextInt(16).toRadixString(16)].join();

  /// A temporary viewer uid: 1400000000000 plus a value below 10^11, composed
  /// from two `Random.nextInt` ranges (anonymous uids are above 2^32).
  static int _generateFallbackUid(Random random) =>
      1400000000000 + random.nextInt(1000000) * 100000 + random.nextInt(100000);

  // Headers -------------------------------------------------------------------

  /// The web API headers (profileRoom, anonymous login): accept, origin,
  /// referer, the sec-fetch trio, the UA and the cookie when there is one.
  Map<String, String> webHeaders() {
    final value = cookie();
    return {
      'accept': '*/*',
      'origin': HuyaEndpoints.origin,
      'referer': '${HuyaEndpoints.origin}/',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-site',
      'user-agent': HuyaEndpoints.userAgent,
      if (value.isNotEmpty) 'cookie': value,
    };
  }

  // Room detail ---------------------------------------------------------------

  /// The `profileRoom` of the numeric room [address] (past its public cache
  /// with a millisecond `_`). A non-numeric address is not-found without a
  /// request. The streamer uid is remembered for the danmaku connection.
  Future<HuyaProfile> detailRoom(String address) async {
    final id = address.trim();
    if (!HuyaRoomParser.isNumericId(id)) {
      throw HuyaFailure(HuyaFailureKind.notFound, 'room id "$id" is not a number');
    }
    final response = await http.get(
      HuyaEndpoints.profileRoom(id, now().millisecondsSinceEpoch),
      headers: {...webHeaders(), 'cache-control': 'no-cache', 'pragma': 'no-cache'},
    );
    final profile = HuyaRoomParser.profile(response.text, requestedId: id, status: response.status);
    if (profile.presenterUid > 0) _rememberUid(id, profile.presenterUid);
    return profile;
  }

  /// The streamer uid of room [roomId]: the remembered one, else a fresh
  /// `profileRoom`.
  Future<int> presenterUid(String roomId) async {
    final id = roomId.trim();
    final remembered = _uids[id];
    if (remembered != null) return remembered;
    return (await detailRoom(id)).presenterUid;
  }

  void _rememberUid(String rid, int uid) {
    _uids.remove(rid);
    _uids[rid] = uid;
    if (_uids.length > 512) _uids.remove(_uids.keys.first);
  }

  // Rid mapping (link resolution) ---------------------------------------------

  /// Remembers the canonical rid [requested] resolved to.
  void rememberRid(String requested, String rid) {
    _rids.remove(requested);
    _rids[requested] = rid;
    if (_rids.length > 512) _rids.remove(_rids.keys.first);
  }

  /// The canonical numeric rid of [address]: a remembered mapping, a numeric
  /// rid as it is, else the alias page (`TT_ROOM_DATA.profileRoom`). Null when
  /// the page names none.
  Future<String?> ridFor(String address) async {
    final id = address.trim();
    final remembered = _rids[id];
    if (remembered != null) return remembered;
    if (HuyaRoomParser.isNumericId(id)) return id;
    if (!HuyaRoomParser.isRoomKey(id)) return null;
    final response = await http.get(
      HuyaEndpoints.roomPage(id),
      headers: const {'user-agent': HuyaEndpoints.desktopUserAgent, 'accept': 'text/html,application/xhtml+xml'},
    );
    if (response.status >= 500) throw HuyaFailure(HuyaFailureKind.network, 'room page: HTTP ${response.status}');
    if (response.status < 200 || response.status >= 300) return null;
    return HuyaRoomParser.roomIdFromPage(response.text);
  }

  // Capability wiring ---------------------------------------------------------

  HuyaRoomProvider? _room;
  HuyaAreaProvider? _area;
  HuyaDiscoveryProvider? _discovery;
  HuyaSearchProvider? _search;
  HuyaPlaybackProvider? _playback;
  HuyaDanmakuProvider? _danmaku;
  HuyaLinkResolver? _link;

  /// The capability of type [T], or null when huya does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= HuyaRoomProvider(site: this);
    final area = _area ??= HuyaAreaProvider(site: this);
    final discovery = _discovery ??= HuyaDiscoveryProvider(site: this);
    final search = _search ??= HuyaSearchProvider(site: this);
    final playback = _playback ??= HuyaPlaybackProvider(site: this);
    final danmaku = _danmaku ??= HuyaDanmakuProvider(site: this);
    final link = _link ??= HuyaLinkResolver(site: this);
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

/// The account uid: an exact `yyuid=<digits>` cookie field above 0.
int? _uidFromCookie(String cookie) {
  final uid = int.tryParse(_yyuid.firstMatch(cookie)?.group(1) ?? '');
  return uid != null && uid > 0 ? uid : null;
}
