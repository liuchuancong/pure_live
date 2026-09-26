import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/common/services/settings/cookie_value.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/common/services/settings_service.dart';

/// How much of a login a stored Douyu cookie actually carries.
///
/// A non-empty cookie is not the same as a signed-in session: a pasted browser
/// cookie that has already expired — or one captured before signing in — still
/// passes a length check, and Douyu then answers as a guest while the app shows
/// the account as signed in.
enum DouyuSessionState {
  /// No cookie stored at all.
  none,

  /// A cookie is stored, but it carries no session token.
  guest,

  /// A session token that has not expired yet.
  valid,

  /// Expired, with the long-term key needed to renew it present.
  expiredRefreshable,

  /// Expired, with nothing to renew it with.
  expired,
}

class DouyuUtils {
  static const String defaultDeviceId = '10000000000000000000000000001501';
  static const String _apiDouyuEnc = 'https://www.douyu.com/wgapi/livenc/liveweb/websec/getEncryption';
  static const int _expirySafetySeconds = 30;
  static const int _maximumCacheAgeSeconds = 5 * 60;
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/128.0.0.0 Safari/537.36';

  /// Cookie names a Douyu login is spread across.
  ///
  /// Douyu hands out two flavours and a pasted cookie is one of them:
  ///
  /// * **Web** (`www.douyu.com`): `dy_auth` is the session token. It is opaque
  ///   — not a JWT — so its expiry cannot be read, and the web flow offers no
  ///   `LTP0` to renew it with. `dy_accounts_main` and the `uid` inside
  ///   `dy_teen_mode` are bystanders, not session state.
  /// * **H5/app** (`m.douyu.com`): `acf_jwt_token` (or `acf_auth`) is the
  ///   session token and it *is* a JWT, so its payload says when it ends;
  ///   `LTP0` is the long-term key that lets the passport endpoint mint a fresh
  ///   one without asking the viewer to sign in again.
  ///
  /// `dy_did` is the device the login belongs to in both flavours.
  /// `dy_did` is the device the login belongs to in both flavours.
  ///
  /// The web `dy_auth` is good for seven days, and that lifetime lives in the
  /// `Set-Cookie` attributes a browser keeps — a pasted header string does not
  /// carry it, which is why the caller passes the time the cookie was saved.
  static const Duration webCookieLifetime = Duration(days: 7);

  /// How long before [webCookieLifetime] the cookie is renewed.
  ///
  /// Renewing a day early costs one request and keeps playback from discovering
  /// the expiry mid-session.
  static const Duration refreshMargin = Duration(days: 1);

  static const String jwtTokenName = 'acf_jwt_token';
  static const String authTokenName = 'acf_auth';
  static const String webAuthTokenName = 'dy_auth';
  static const String longTermTokenName = 'LTP0';
  static const String deviceIdName = 'dy_did';

  /// Passport endpoint that renews an expired session.
  static const String _apiDouyuPassport = 'https://passport.douyu.com/lapi/passport/iframe/safeAuth';

  /// `Set-Cookie` attribute names that are never cookie fields.
  static const Set<String> _setCookieAttributes = <String>{
    'path',
    'domain',
    'expires',
    'max-age',
    'samesite',
    'secure',
    'httponly',
  };

  /// Test seam for the renewal request; production uses the app's HTTP client.
  @visibleForTesting
  static Future<List<String>> Function(Uri url, Map<String, String> headers)? debugCookieFetcher;

  /// Test seam for storing a renewed cookie and its save time; production writes
  /// both to settings.
  @visibleForTesting
  static void Function(String cookie, DateTime savedAt)? debugCookiePersister;

  static Map<String, dynamic> _encKey = <String, dynamic>{};
  static Future<void>? _encKeyRefresh;
  static int? _encKeyFetchedAtSeconds;

  /// DID the cached encryption descriptor was issued for.
  ///
  /// Douyu issues the descriptor to a device and validates the signed request
  /// against the same one, so a descriptor fetched for another DID makes every
  /// signed request fail — and switching accounts (which changes the stored
  /// `dy_did`) has to invalidate it.
  static String? _encKeyDeviceId;
  static final String _sessionDeviceId = generateDeviceId();

  static String get deviceId => _sessionDeviceId;

  static int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// Validates the server encryption descriptor using second-based Unix time.
  static bool isEncryptionKeyUsable(
    Map<String, dynamic> value, {
    required int nowSeconds,
    int safetySeconds = _expirySafetySeconds,
  }) {
    final expiresAt = _asInt(value['expire_at']);
    final encTime = _asInt(value['enc_time']);
    return expiresAt != null &&
        expiresAt > nowSeconds + safetySeconds &&
        encTime != null &&
        encTime > 0 &&
        encTime <= 16 &&
        _nonEmpty(value['key']) &&
        _nonEmpty(value['rand_str']) &&
        _nonEmpty(value['enc_data']);
  }

  static bool _isCachedEncryptionKeyUsable(int nowSeconds) {
    final fetchedAt = _encKeyFetchedAtSeconds;
    return fetchedAt != null &&
        _encKeyDeviceId == effectiveDeviceId() &&
        nowSeconds - fetchedAt < _maximumCacheAgeSeconds &&
        isEncryptionKeyUsable(_encKey, nowSeconds: nowSeconds);
  }

  static Future<void> _encKeyUpdate({bool forceRefresh = false}) async {
    final nowSeconds = _nowSeconds();
    if (!forceRefresh && _isCachedEncryptionKeyUsable(nowSeconds)) return;

    final activeRefresh = _encKeyRefresh;
    if (activeRefresh != null) {
      await activeRefresh;
      if (_isCachedEncryptionKeyUsable(_nowSeconds())) return;
    }

    final refresh = _fetchEncryptionKey();
    _encKeyRefresh = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_encKeyRefresh, refresh)) _encKeyRefresh = null;
    }
  }

  static Future<void> _fetchEncryptionKey() async {
    // The same DID has to be used here, in the signed query and in the request
    // Cookie: Douyu issues the descriptor to a device and rejects a signature
    // presented by another one (a plain 403 from its edge, with no API error).
    final did = effectiveDeviceId();
    final response = await HttpClient.instance.getJson(
      _apiDouyuEnc,
      queryParameters: {'did': did},
      header: requestHeaders(),
    );
    final rawData = response is Map ? response['data'] : null;
    if (rawData is! Map) {
      throw const FormatException('Douyu encryption response is missing data');
    }
    final data = Map<String, dynamic>.from(rawData);
    if (!isEncryptionKeyUsable(data, nowSeconds: _nowSeconds())) {
      throw const FormatException('Douyu encryption descriptor is incomplete or expired');
    }
    _encKey = data;
    _encKeyFetchedAtSeconds = _nowSeconds();
    _encKeyDeviceId = did;
  }

  /// Creates the browser DID used by a single app process.
  static String generateDeviceId({Random? random}) {
    final source = random ?? Random.secure();
    return List<String>.generate(32, (_) => source.nextInt(16).toRadixString(16)).join();
  }

  // ---------------------------------------------------------------------------
  // Account session
  // ---------------------------------------------------------------------------

  /// Splits a Cookie header into its fields, in order, dropping blanks.
  static List<({String name, String value})> parseCookieFields(String cookie) {
    final fields = <({String name, String value})>[];
    for (final piece in cookie.split(';')) {
      final separator = piece.indexOf('=');
      if (separator <= 0) continue;
      final name = piece.substring(0, separator).trim();
      if (name.isEmpty) continue;
      fields.add((name: name, value: piece.substring(separator + 1).trim()));
    }
    return fields;
  }

  /// Value of one cookie field, or `null`. Names are matched case-insensitively.
  static String? cookieField(String cookie, String name) {
    final wanted = name.toLowerCase();
    for (final field in parseCookieFields(cookie)) {
      if (field.name.toLowerCase() == wanted) return field.value;
    }
    return null;
  }

  /// The session token the account cookie carries, if any.
  ///
  /// The web flavour's `dy_auth` counts: a pasted `www.douyu.com` cookie is a
  /// real login, and reading only the H5 JWTs would show a signed-in viewer as
  /// signed out.
  static String? sessionToken(String cookie) =>
      cookieField(cookie, jwtTokenName) ??
      cookieField(cookie, authTokenName) ??
      cookieField(cookie, webAuthTokenName);

  /// Decodes a JWT payload, or returns `null` when the token is not one.
  ///
  /// Douyu signs the session with a JWT and the expiry is the only thing this
  /// app needs from it, so a malformed token is reported as "no expiry known"
  /// rather than thrown: a cookie the user pasted by hand should never crash a
  /// request path.
  static Map<String, dynamic>? decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
        case 3:
          payload += '=';
      }
      final decoded = jsonDecode(utf8.decode(base64.decode(payload)));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  /// When the stored session ends, or `null` when nothing says.
  ///
  /// Two sources, in order: the JWT's own `exp` (the H5 flavour), and — for the
  /// opaque web `dy_auth` — the recorded save time plus Douyu's seven-day rule.
  /// Without a save time the end is unknown rather than guessed.
  static DateTime? sessionExpiry(String cookie, {DateTime? now, DateTime? savedAt}) {
    final token = sessionToken(cookie);
    if (token == null || token.isEmpty) return null;

    final expiresAt = _asInt(decodeJwtPayload(token)?['exp']);
    if (expiresAt != null && expiresAt > 0) {
      return DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    }

    return savedAt?.add(webCookieLifetime);
  }

  /// Whether the cookie can no longer be used as a login.
  ///
  /// A missing token counts as expired: without one the request is a guest
  /// request whatever the cookie length says, and treating it as a session is
  /// what makes a stale cookie look like a successful login.
  ///
  /// A token whose end is unknown is not expired either: guessing "expired"
  /// would refuse a login that still works.
  static bool isSessionExpired(String cookie, {DateTime? now, DateTime? savedAt}) {
    if (sessionToken(cookie) == null) return true;
    final expiry = sessionExpiry(cookie, now: now, savedAt: savedAt ?? storedSessionSavedAt());
    return expiry != null && !expiry.isAfter(now ?? DateTime.now());
  }

  /// Whether the cookie should be renewed now rather than when it breaks.
  ///
  /// True inside [refreshMargin] of the end, whether that end came from a JWT or
  /// from the recorded save time.
  static bool shouldRefreshSession(String cookie, {DateTime? now, DateTime? savedAt}) {
    if (sessionToken(cookie) == null) return true;
    final expiry = sessionExpiry(cookie, now: now, savedAt: savedAt ?? storedSessionSavedAt());
    if (expiry == null) return false;
    return !(now ?? DateTime.now()).isBefore(expiry.subtract(refreshMargin));
  }

  /// The long-term key and device id a renewal needs.
  ///
  /// Either source counts: a viewer who pasted everything into the cookie box,
  /// and one who filled the two passport fields separately (which is where they
  /// actually come from) must both work.
  static ({String? longTerm, String? did}) refreshCredentials(
    String cookie, {
    String? longTerm,
    String? did,
  }) {
    final resolvedLongTerm = _nonBlank(longTerm) ?? _nonBlank(cookieField(cookie, longTermTokenName)) ?? _storedLtp0();
    // No fallback to the process DID here: a renewal must present the device the
    // login was issued for, and inventing one would only make the passport
    // endpoint refuse it. Request headers keep that fallback; a renewal does not.
    final resolvedDid = _nonBlank(did) ?? _nonBlank(cookieField(cookie, deviceIdName)) ?? _storedDid();
    return (longTerm: resolvedLongTerm, did: resolvedDid);
  }

  /// Whether a renewal is possible at all: the passport endpoint needs both the
  /// long-term key and the device the login belongs to.
  static bool canRefreshSession(String cookie, {String? longTerm, String? did}) {
    final credentials = refreshCredentials(cookie, longTerm: longTerm, did: did);
    return credentials.longTerm != null && credentials.did != null;
  }

  static String? _nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _storedLtp0() {
    try {
      return _nonBlank(SettingsService.to.cookieManager.douyuLtp0.v);
    } catch (_) {
      return null;
    }
  }

  static String? _storedDid() {
    try {
      return _nonBlank(SettingsService.to.cookieManager.douyuDid.v);
    } catch (_) {
      return null;
    }
  }

  /// What the stored cookie is worth, for the account UI.
  static DouyuSessionState sessionState(String cookie, {DateTime? now, DateTime? savedAt}) {
    final normalized = normalizeAccountCookie(cookie);
    if (normalized.isEmpty) return DouyuSessionState.none;

    final at = now ?? DateTime.now();
    final expiry = sessionExpiry(normalized, now: at, savedAt: savedAt ?? storedSessionSavedAt());
    // A token with no readable expiry (the web `dy_auth`) is a valid session
    // with an unknown end — not a guest, and not an expired one.
    if (sessionToken(normalized) == null) return DouyuSessionState.guest;
    if (expiry == null || expiry.isAfter(at)) return DouyuSessionState.valid;
    return canRefreshSession(normalized) ? DouyuSessionState.expiredRefreshable : DouyuSessionState.expired;
  }

  /// DID used by both the Cookie header and the signed query.
  ///
  /// The two must agree, and a stored account cookie may carry the `dy_did` its
  /// login was issued for — signing with a different one than the cookie
  /// advertises is how a valid session gets answered as a guest. The generated
  /// process DID is only the fallback for cookies that carry none.
  static String effectiveDeviceId({String? accountCookie}) {
    final stored = accountCookie ?? _configuredAccountCookie();
    final did = cookieField(stored, deviceIdName);
    return did != null && did.isNotEmpty ? did : deviceId;
  }

  /// Merges `Set-Cookie` header lines into [cookie], keeping fields the response
  /// did not mention.
  ///
  /// Replacing the whole cookie with the response's fields would drop `LTP0` and
  /// everything else the browser session held, so the renewal would work once
  /// and then have nothing left to renew with.
  static String mergeSetCookieLines(String cookie, Iterable<String> setCookieLines) {
    final fields = <String, String>{for (final field in parseCookieFields(cookie)) field.name: field.value};

    for (final line in setCookieLines) {
      final pair = line.split(';').first.trim();
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      final name = pair.substring(0, separator).trim();
      final value = pair.substring(separator + 1).trim();
      if (name.isEmpty) continue;
      // `Set-Cookie` attributes look exactly like fields; storing them would put
      // `Path` and `Max-Age` into the Cookie header we send back.
      if (_setCookieAttributes.contains(name.toLowerCase())) continue;
      if (value.isEmpty) {
        // An emptied field is Douyu clearing it; keeping the old value would
        // resurrect a token it just revoked.
        fields.remove(name);
        continue;
      }
      fields[name] = value;
    }

    return fields.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
  }

  /// Renews the stored cookie with its long-term key.
  ///
  /// Returns the renewed cookie, or `null` when there was nothing to do or the
  /// passport endpoint answered without a usable cookie.
  static Future<String?> refreshSession({
    String? accountCookie,
    DateTime? savedAt,
    bool force = false,
    String? longTerm,
    String? did,
  }) async {
    final stored = normalizeAccountCookie(accountCookie ?? _configuredAccountCookie());
    if (stored.isEmpty) return null;

    final credentials = refreshCredentials(stored, longTerm: longTerm, did: did);
    if (credentials.longTerm == null || credentials.did == null) return null;
    if (!force && !shouldRefreshSession(stored, savedAt: savedAt)) return null;

    final resolvedDid = credentials.did!;
    final resolvedLongTerm = credentials.longTerm!;
    final milliseconds = DateTime.now().millisecondsSinceEpoch.toString();
    final url = Uri.parse(_apiDouyuPassport).replace(
      queryParameters: <String, String>{
        'client_id': '1',
        't': milliseconds,
        '_': milliseconds,
        'callback': 'axiosJsonpCallback',
      },
    );

    // This is the request the long-term key exists for: without it in the header
    // the passport endpoint has nothing to renew and answers as a guest.
    final setCookies = await _fetchSetCookies(url, <String, String>{
      ...requestHeaders(),
      'cookie': '$deviceIdName=$resolvedDid;$longTermTokenName=$resolvedLongTerm',
    });

    // No `Set-Cookie` at all means the endpoint did not renew anything. That has
    // to stay a no-op: recording a renewal time here would keep a cookie that is
    // about to die looking fresh for another seven days.
    if (setCookies.isEmpty) return null;

    final renewed = mergeSetCookieLines(stored, setCookies);
    if (renewed.isEmpty) return null;
    // A renewal that drops the session field is a downgrade to guest: keep the
    // cookie that at least still has a chance.
    if (sessionToken(renewed) == null) return null;

    // The response may hand back the same value it was given while extending it
    // server-side, so an unchanged string still counts as a renewal and the
    // recorded time follows the server's answer rather than the string.
    await _persistCookie(renewed, DateTime.now());
    return renewed;
  }

  /// Renews the stored session when it has expired, before a request that needs
  /// it.
  ///
  /// Never throws: a failed renewal means the request goes out as a guest, which
  /// is strictly better than failing the playback the viewer asked for.
  static Future<void> ensureFreshSession({
    String? accountCookie,
    DateTime? savedAt,
    bool force = false,
    String? longTerm,
    String? did,
  }) async {
    try {
      final stored = normalizeAccountCookie(accountCookie ?? _configuredAccountCookie());
      if (stored.isEmpty || !canRefreshSession(stored, longTerm: longTerm, did: did)) return;
      // `force` is the failure path: a request came back as a guest, which says
      // more about the cookie than any recorded timestamp can.
      // A failure path says more than any timestamp: a request came back as a
      // guest, so renew now regardless of how old the cookie looks.
      if (!force && !shouldRefreshSession(stored, savedAt: savedAt)) return;
      await refreshSession(accountCookie: stored, savedAt: savedAt, force: force, longTerm: longTerm, did: did);
    } catch (error) {
      CoreLog.w('Douyu session refresh failed: $error');
    }
  }

  static Future<List<String>> _fetchSetCookies(Uri url, Map<String, String> headers) async {
    final injected = debugCookieFetcher;
    if (injected != null) return injected(url, headers);

    final response = await HttpClient.instance.dio.get<dynamic>(
      url.toString(),
      options: Options(responseType: ResponseType.plain, headers: headers, validateStatus: (_) => true),
    );
    final raw = response.headers['set-cookie'];
    if (raw == null) return const <String>[];
    return List<String>.from(raw);
  }

  static Future<void> _persistCookie(String cookie, DateTime savedAt) async {
    final injected = debugCookiePersister;
    if (injected != null) {
      injected(cookie, savedAt);
      return;
    }
    try {
      final cookies = SettingsService.to.cookieManager;
      cookies.douyuCookie.v = cookie;
      // Remember when, or the seven-day rule has nothing to count from.
      cookies.douyuCookieSavedAt.v = savedAt.millisecondsSinceEpoch ~/ 1000;
    } catch (_) {
      // No settings store (a unit test, a headless run): the renewed cookie is
      // still returned to the caller, so this request benefits either way.
    }
  }

  static Map<String, String> requestHeaders([String roomId = '']) {
    final referer = roomId.isEmpty ? 'https://www.douyu.com/' : 'https://www.douyu.com/$roomId';
    return <String, String>{
      'accept': 'application/json, text/plain, */*',
      'accept-language': 'zh-CN,zh;q=0.9,en;q=0.7',
      'origin': 'https://www.douyu.com',
      'referer': referer,
      'user-agent': userAgent,
      'cookie': cookieHeader(),
    };
  }

  /// Keep the signer DID consistent with its request Cookie, while appending
  /// optional account session fields to Douyu request/playback headers.
  static String cookieHeader({String? accountCookie}) {
    final stored = accountCookie ?? _configuredAccountCookie();
    final normalized = normalizeAccountCookie(stored).replaceFirst(RegExp(r'^Cookie:\s*', caseSensitive: false), '');
    final did = effectiveDeviceId(accountCookie: normalized);
    final fields = <String>['dy_did=$did', 'acf_did=$did'];
    for (final piece in normalized.split(';')) {
      final separator = piece.indexOf('=');
      if (separator <= 0) continue;
      final name = piece.substring(0, separator).trim();
      if (!RegExp(r"^[A-Za-z0-9_!#$%&'*+.^`|~-]+$").hasMatch(name)) continue;
      if (name.toLowerCase() == 'dy_did' || name.toLowerCase() == 'acf_did') continue;
      // `LTP0` belongs to passport.douyu.com (it is the renewal key, not a
      // session field) and the bytes of a request are a place Douyu's edge
      // watches: sending it to the play endpoints is both unnecessary and a
      // reason for the edge to answer 403 without an API error.
      if (name.toLowerCase() == longTermTokenName.toLowerCase()) continue;
      fields.add('$name=${piece.substring(separator + 1).trim()}');
    }
    return fields.join('; ');
  }

  /// A secret-free description of the credential pairing a request will use.
  ///
  /// A Douyu 403 from the edge carries no API error, so the only way to tell
  /// "wrong device" from "bad cookie" afterwards is to record which fields were
  /// present and where the device id came from. Values are never included.
  static String requestShape(String roomId) {
    final cookie = _configuredAccountCookie();
    final fields = parseCookieFields(cookie).map((field) => field.name.toLowerCase()).toSet();
    final flags = <String>[
      if (fields.contains(jwtTokenName)) 'acf_jwt_token',
      if (fields.contains(authTokenName.toLowerCase())) 'acf_auth',
      if (fields.contains(webAuthTokenName)) webAuthTokenName,
      if (fields.contains(longTermTokenName.toLowerCase())) longTermTokenName,
      if (fields.contains(deviceIdName)) deviceIdName,
      if (fields.contains('acf_stk')) 'acf_stk',
      if (_storedLtp0() != null) 'LTP0(field)',
      if (_storedDid() != null) 'dy_did(field)',
    ];
    final didSource = cookieField(cookie, deviceIdName) != null
        ? 'cookie'
        : (_storedDid() != null ? 'field' : 'process');
    return 'did=$didSource/${effectiveDeviceId()} '
        'cookieFields=${fields.length}[${flags.join(',')}] '
        'len=${cookie.length}';
  }

  /// When the stored cookie was obtained, as recorded when it was saved.
  ///
  /// `null` when nothing recorded it — a cookie pasted before this existed, or a
  /// unit test with no settings store. The seven-day rule then has no start
  /// point, and the app says "unknown" instead of inventing one.
  static DateTime? storedSessionSavedAt({int? savedAtSeconds}) {
    try {
      final seconds = savedAtSeconds ?? SettingsService.to.cookieManager.douyuCookieSavedAt.v;
      return seconds > 0 ? DateTime.fromMillisecondsSinceEpoch(seconds * 1000) : null;
    } catch (_) {
      return null;
    }
  }

  static String _configuredAccountCookie() {
    try {
      return SettingsService.to.cookieManager.douyuCookie.value;
    } catch (_) {
      return '';
    }
  }

  static Map<String, String> playbackHeaders(String roomId) => <String, String>{
    'origin': 'https://www.douyu.com',
    'referer': 'https://www.douyu.com/$roomId',
    'user-agent': userAgent,
    'cookie': cookieHeader(),
  };

  /// Builds the form body from an already validated encryption descriptor.
  /// Exposed as a deterministic unit-test seam for the platform signing path.
  static String buildSignedData({
    required Map<String, dynamic> encryptionKey,
    required String roomId,
    required int timestampSeconds,
    int rate = -1,
    String cdn = '',
    String deviceId = defaultDeviceId,
  }) {
    if (!isEncryptionKeyUsable(encryptionKey, nowSeconds: timestampSeconds, safetySeconds: 0)) {
      throw const FormatException('Douyu encryption descriptor is incomplete or expired');
    }
    final key = encryptionKey['key'].toString();
    final randStr = encryptionKey['rand_str'].toString();
    final encTime = _asInt(encryptionKey['enc_time'])!;
    final salt = _asInt(encryptionKey['is_special']) == 1 ? '' : '$roomId$timestampSeconds';

    var secret = randStr;
    for (var index = 0; index < encTime; index++) {
      secret = md5.convert(utf8.encode('$secret$key')).toString();
    }
    final auth = md5.convert(utf8.encode('$secret$key$salt')).toString();
    return Uri(
      queryParameters: <String, String>{
        'enc_data': encryptionKey['enc_data'].toString(),
        'tt': timestampSeconds.toString(),
        'did': deviceId,
        'auth': auth,
        'cdn': cdn,
        'rate': rate.toString(),
        'hevc': '0',
        'fa': '0',
        'ive': '0',
        'ver': 'Douyu_new',
        'iar': '0',
      },
    ).query;
  }

  static Future<String> sign(String roomId, {int rate = -1, String cdn = '', bool forceRefresh = false}) async {
    await _encKeyUpdate(forceRefresh: forceRefresh);
    return buildSignedData(
      encryptionKey: _encKey,
      roomId: roomId,
      timestampSeconds: _nowSeconds(),
      rate: rate,
      cdn: cdn,
      deviceId: effectiveDeviceId(),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _nonEmpty(dynamic value) => value?.toString().trim().isNotEmpty == true;
}
