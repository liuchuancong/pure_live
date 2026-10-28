import 'dart:math';

// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_auth_capability.dart';
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
import 'package:live_sites/src/platforms/douyu/api/douyu_endpoints.dart';
import 'package:live_sites/src/platforms/douyu/api/douyu_http.dart';
import 'package:live_sites/src/platforms/douyu/capabilities/douyu_area_provider.dart';
import 'package:live_sites/src/platforms/douyu/capabilities/douyu_auth_provider.dart';
import 'package:live_sites/src/platforms/douyu/capabilities/douyu_discovery_provider.dart';
import 'package:live_sites/src/platforms/douyu/capabilities/douyu_link_resolver.dart';
import 'package:live_sites/src/platforms/douyu/capabilities/douyu_play_recovery.dart';
import 'package:live_sites/src/platforms/douyu/capabilities/douyu_playback_provider.dart';
import 'package:live_sites/src/platforms/douyu/capabilities/douyu_room_provider.dart';
import 'package:live_sites/src/platforms/douyu/capabilities/douyu_room_refresh.dart';
import 'package:live_sites/src/platforms/douyu/capabilities/douyu_search_provider.dart';
import 'package:live_sites/src/platforms/douyu/capabilities/douyu_status_check.dart';
import 'package:live_sites/src/platforms/douyu/danmaku/douyu_danmaku_session.dart';
import 'package:live_sites/src/platforms/douyu/douyu_login_store.dart';
import 'package:live_sites/src/platforms/douyu/douyu_manifest.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_account.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_failure.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_gift_parser.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_play_parser.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The canonical rid a room's signing, stream and danmaku requests use (a
/// room asked for by its 靓号 or alias keeps that address as its identity).
final class DouyuRoomData {
  /// Wraps the canonical rid.
  const DouyuRoomData(this.rid);

  /// Canonical numeric room id (`room.room_id`).
  final String rid;

  @override
  String toString() => 'DouyuRoomData($rid)';
}

/// What a danmaku session needs for one room: the canonical rid and the
/// gift catalogues its `dgb` packets are priced from.
final class DouyuDanmakuArgs {
  /// Wraps the rid and the gifts known so far.
  const DouyuDanmakuArgs(this.roomId, this.gifts);

  /// Canonical numeric room id.
  final String roomId;

  /// The gifts known so far (`betard`'s, with the fetched lists merged).
  final DouyuGiftCatalog gifts;

  @override
  String toString() => 'DouyuDanmakuArgs($roomId, ${gifts.length} gifts)';
}

/// Where the adapter reads what renewing a douyu login needs beside the
/// cookie lives in `douyu_login_store.dart` (the seam the application
/// implements; null means every request goes out as a guest).

/// The douyu adapter: manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2); requests in `api/`, parsing in `parsers/`,
/// features in `capabilities/`. Every request carries one device id: the
/// login cookie's `dy_did`, else a random one per adapter.
final class DouyuSite implements LiveSite {
  /// Creates the adapter over [http]; [login] supplies the account cookie
  /// (null: every request goes out as a guest); [now] and [random] are
  /// injectable for tests.
  DouyuSite({
    required this.http,
    this.login,
    this.filterSuspectedAutomated,
    this.forceRenew,
    DateTime Function()? now,
    Random? random,
  }) : now = now ?? DateTime.now,
       processDid = DouyuAccountDevice.generate(random ?? Random.secure());

  /// Transport.
  final DouyuHttp http;

  /// The account cookie source, when the viewer is signed in.
  final DouyuLoginStore? login;

  /// The 过滤斗鱼疑似机器人弹幕 seam, read for every suspected chat so a
  /// changed setting applies at once; null keeps those chats (the setting's
  /// own default is off).
  final bool Function()? filterSuspectedAutomated;

  /// The 每 5 分钟自动续期 seam: true asks for a renewal even before the
  /// stored login is near its end, rate-limited to one per five minutes.
  final bool Function()? forceRenew;

  /// Injectable clock.
  final DateTime Function() now;

  /// This adapter's random device id.
  final String processDid;

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => douyuManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O already).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  /// GETs [url] with [headers] (the capabilities' transport).
  Future<({String text, int status})> httpGet(Uri url, {Map<String, String> headers = const {}}) =>
      http.get(url, headers: headers);

  /// POSTs [fields] as a form body (the capabilities' transport).
  Future<({String text, int status})> httpPostForm(
    Uri url, {
    required Map<String, String> fields,
    Map<String, String> headers = const {},
  }) => http.postForm(url, fields: fields, headers: headers);

  // Identity ------------------------------------------------------------------

  /// The credential applied through [applyLoginCredential], overriding the
  /// login store's cookie until [clearLoginCredential] (in-memory only, like
  /// every capability-carrying value).
  String? _appliedCookie;

  /// The account cookie of every request: the applied credential when there
  /// is one, else what the login store supplied at construction.
  String accountCookie() => _appliedCookie ?? DouyuAccount.normalizeCookie(login?.cookie ?? '');

  /// Applies [cookie] as the account cookie every request carries from now
  /// on. In-memory only — persistence is the application's business — and it
  /// survives until [clearLoginCredential].
  void applyLoginCredential(String cookie) {
    final normalized = DouyuAccount.normalizeCookie(cookie);
    _appliedCookie = normalized.isEmpty ? null : normalized;
  }

  /// Removes the applied credential; requests carry the login store's cookie
  /// again.
  void clearLoginCredential() {
    _appliedCookie = null;
  }

  /// The device id of the next request: the account cookie's `dy_did`, else
  /// this adapter's random one.
  String get deviceId {
    final account = DouyuAccount.normalizeCookie(accountCookie());
    return DouyuAccount.deviceId(account, processDid);
  }

  /// The request cookie and the device id it carries, read together.
  ({String cookie, String did}) identity() {
    final account = DouyuAccount.normalizeCookie(accountCookie());
    final did = DouyuAccount.deviceId(account, processDid);
    return (cookie: DouyuAccount.cookieHeader(account: account, did: did), did: did);
  }

  /// API request headers; the referer is room [roomId]'s page, or the home
  /// page without one.
  Map<String, String> apiHeaders(String cookie, {String? roomId}) => {
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'zh-CN,zh;q=0.9,en;q=0.7',
    'origin': DouyuEndpoints.origin,
    'referer': roomId == null || roomId.isEmpty ? 'https://www.douyu.com/' : 'https://www.douyu.com/$roomId',
    'user-agent': DouyuEndpoints.userAgent,
    if (cookie.isNotEmpty) 'cookie': cookie,
  };

  // Signing descriptor --------------------------------------------------------

  ({String did, DouyuDescriptor descriptor, DateTime at})? _descriptor;
  ({String did, Future<DouyuDescriptor> future})? _descriptorFlight;

  /// The descriptor for [did]: reused while younger than five minutes and
  /// usable, fetched through [fetch] otherwise. Two callers that miss together
  /// share one fetch (the descriptor is signed per device, so it is not refetched
  /// twice for the same did).
  Future<DouyuDescriptor> descriptorFor(String did, Future<DouyuDescriptor> Function() fetch) async {
    final cached = _descriptor;
    final at = now();
    if (cached != null &&
        cached.did == did &&
        at.difference(cached.at) < const Duration(minutes: 5) &&
        cached.descriptor.usableAt(at)) {
      return cached.descriptor;
    }
    final running = _descriptorFlight;
    if (running != null && running.did == did) return await running.future;
    final flight = () async {
      final descriptor = await fetch();
      _descriptor = (did: did, descriptor: descriptor, at: now());
      return descriptor;
    }();
    _descriptorFlight = (did: did, future: flight);
    try {
      return await flight;
    } finally {
      if (_descriptorFlight?.future == flight) _descriptorFlight = null;
    }
  }

  // Rid mapping ---------------------------------------------------------------

  final Map<String, String> _rids = {};

  /// Remembers the canonical rid [requested] resolved to.
  void rememberRid(String requested, String rid) {
    _rids.remove(requested);
    _rids[requested] = rid;
    if (_rids.length > 512) _rids.remove(_rids.keys.first);
  }

  /// The canonical rid of [address]: a remembered mapping, a numeric rid as
  /// it is, else the room page — an alias page redirects to `/<rid>` and a
  /// 靓号 page names its rid in `window.room_id`, so the page live_net lands
  /// on answers for both. Null when the page names none.
  Future<String?> ridFor(String address) async {
    final id = address.trim();
    final remembered = _rids[id];
    if (remembered != null) return remembered;
    if (DouyuRoomParser.isNumericRid(id)) return id;
    if (!DouyuRoomParser.isRoomKey(id)) return null;
    final response = await http.get(DouyuEndpoints.roomPage(id), headers: {'user-agent': DouyuEndpoints.userAgent});
    if (response.status >= 500) {
      throw DouyuFailure(DouyuFailureKind.network, 'room page: HTTP ${response.status}');
    }
    return response.status >= 200 && response.status < 300 ? DouyuRoomParser.roomIdInPage(response.text) : null;
  }

  // Gifts ---------------------------------------------------------------------

  /// How long a room's gift list is reused.
  static const Duration giftListLifetime = Duration(minutes: 30);

  /// How long the prop table is reused.
  static const Duration propTableLifetime = Duration(hours: 6);

  final Map<String, ({DouyuGiftCatalog gifts, DateTime at})> _giftLists = {};
  ({DouyuGiftCatalog gifts, DateTime at})? _propTable;

  /// The room's `betard` gifts with the fetched lists over them. Never
  /// throws: no catalogue is the danmaku as before.
  Future<DouyuGiftCatalog> giftCatalog(String rid, {DouyuGiftCatalog betard = DouyuGiftCatalog.empty}) async {
    var gifts = betard;
    final cached = _giftLists[rid];
    final list = cached != null && now().difference(cached.at) < giftListLifetime
        ? cached.gifts
        : await () async {
            try {
              final response = await http.get(
                DouyuEndpoints.giftList(rid),
                headers: {'user-agent': DouyuEndpoints.userAgent, 'referer': 'https://www.douyu.com/$rid'},
              );
              final gifts = DouyuGiftParser.giftList(response.text, status: response.status);
              _giftLists[rid] = (gifts: gifts, at: now());
              return gifts;
            } on DouyuFailure {
              return DouyuGiftCatalog.empty;
            }
          }();
    gifts = gifts.merge(list);
    return gifts.merge(await props());
  }

  /// The platform's prop table, fetched and cached once.
  Future<DouyuGiftCatalog> props() async {
    final cached = _propTable;
    if (cached != null && now().difference(cached.at) < propTableLifetime) return cached.gifts;
    try {
      final response = await http.get(
        DouyuEndpoints.propGiftList,
        headers: {'user-agent': DouyuEndpoints.userAgent, 'referer': 'https://www.douyu.com/'},
      );
      final gifts = DouyuGiftParser.propGifts(response.text, status: response.status);
      _propTable = (gifts: gifts, at: now());
      return gifts;
    } on DouyuFailure {
      return DouyuGiftCatalog.empty;
    }
  }

  /// Gifts known for [rid] without any request (the cache).
  DouyuGiftCatalog cachedGifts(String rid) => _giftLists[rid]?.gifts ?? DouyuGiftCatalog.empty;

  // Login renewal -------------------------------------------------------------

  Future<void>? _renewal;
  DateTime? _lastForcedRenew;

  /// With a login store, a stored login that has LTP0 and its device id is
  /// renewed when it is within a day of its end (or has no token). Never
  /// throws: a failed renewal leaves the request to go out with the
  /// current cookie. Concurrent callers share one renewal. The applied
  /// credential (see [applyLoginCredential]) renews in the store's place when
  /// there is one. [force] (the cookie page's 立即续期) asks for the renewal
  /// now even when the session is nowhere near its end.
  Future<void> renewLogin({bool force = false}) async {
    final store = login;
    if (store == null) return;
    final cookie = accountCookie();
    if (cookie.isEmpty) return;
    final credentials = DouyuAccount.renewalCredentials(
      cookie,
      storedLtp0: store.longTermKey,
      storedDid: store.deviceId,
    );
    final ltp0 = credentials.ltp0;
    final did = credentials.did;
    if (ltp0 == null || did == null) return;
    final forced = force || (forceRenew?.call() ?? false);
    final due = DouyuAccount.shouldRenew(cookie, now: now(), savedAt: store.savedAt);
    if (!forced && !due) return;
    if (forced && !force) {
      final last = _lastForcedRenew;
      if (!due && last != null && now().difference(last) < const Duration(minutes: 5)) return;
    }
    final running = _renewal;
    if (running != null) {
      await running;
      return;
    }
    final renewal = () async {
      try {
        final stamp = '${now().millisecondsSinceEpoch}';
        final base = DouyuEndpoints.passportRenewal();
        final url = base.replace(
          queryParameters: {...base.queryParameters, 't': stamp, '_': stamp, 'callback': 'axiosJsonpCallback'},
        );
        final lines = await http.passportSetCookies(url, {
          ...apiHeaders(''),
          'cookie': '${DouyuAccount.deviceIdName}=$did;${DouyuAccount.longTermKeyName}=$ltp0',
        });
        final renewed = DouyuAccount.renewedCookie(cookie, lines);
        if (renewed != null) {
          await store.saveRenewed(renewed, now());
          // The renewed cookie leads from now on, in memory as in the store.
          applyLoginCredential(renewed);
          if (forced) _lastForcedRenew = now();
        }
      } on DouyuFailure {
        // Keep the current cookie; the request may go out as a guest.
      } finally {
        _renewal = null;
      }
    }();
    _renewal = renewal;
    await renewal;
  }

  // Capability wiring ---------------------------------------------------------

  DouyuRoomProvider? _room;
  DouyuAreaProvider? _area;
  DouyuDiscoveryProvider? _discovery;
  DouyuSearchProvider? _search;
  DouyuPlaybackProvider? _playback;
  DouyuDanmakuProvider? _danmaku;
  DouyuLinkResolver? _link;
  DouyuAuthProvider? _auth;
  DouyuRoomRefresh? _refresh;
  DouyuStatusCheck? _status;
  DouyuPlayRecovery? _recovery;

  /// The capability of type [T], or null when douyu does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= DouyuRoomProvider(site: this);
    final area = _area ??= DouyuAreaProvider(site: this);
    final discovery = _discovery ??= DouyuDiscoveryProvider(site: this);
    final search = _search ??= DouyuSearchProvider(site: this);
    final playback = _playback ??= DouyuPlaybackProvider(site: this);
    final danmaku = _danmaku ??= DouyuDanmakuProvider(site: this, filterSuspectedAutomated: filterSuspectedAutomated);
    final link = _link ??= DouyuLinkResolver(site: this);
    final auth = _auth ??= DouyuAuthProvider(site: this);
    final refresh = _refresh ??= DouyuRoomRefresh(rooms: room);
    final status = _status ??= DouyuStatusCheck(rooms: room);
    final recovery = _recovery ??= DouyuPlayRecovery(playback: playback);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => area as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LiveDanmakuProvider) => danmaku as T,
      const (LiveLinkResolver) => link as T,
      const (LiveAuthCapability) => auth as T,
      const (LiveRoomRefresh) => refresh as T,
      const (LiveStatusCheck) => status as T,
      const (LivePlayRecovery) => recovery as T,
      _ => null,
    };
  }
}

/// A per-process browser device id: 32 lower-case hex digits.
abstract final class DouyuAccountDevice {
  /// Generates one from [random].
  static String generate(Random random) => [for (var i = 0; i < 32; i++) random.nextInt(16).toRadixString(16)].join();
}
