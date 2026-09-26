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

  /// Test seam for storing a renewed cookie; production writes it to settings.
  @visibleForTesting
  static void Function(String cookie)? debugCookiePersister;

  static Map<String, dynamic> _encKey = <String, dynamic>{};
  static Future<void>? _encKeyRefresh;
  static int? _encKeyFetchedAtSeconds;
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
    final response = await HttpClient.instance.getJson(
      _apiDouyuEnc,
      queryParameters: {'did': deviceId},
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

  /// When the stored session ends, or `null` when the cookie carries no
  /// decodable session token.
  static DateTime? sessionExpiry(String cookie, {DateTime? now}) {
    final token = sessionToken(cookie);
    if (token == null || token.isEmpty) return null;
    final expiresAt = _asInt(decodeJwtPayload(token)?['exp']);
    if (expiresAt == null || expiresAt <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
  }

  /// Whether the cookie can no longer be used as a login.
  ///
  /// A missing token counts as expired: without one the request is a guest
  /// request whatever the cookie length says, and treating it as a session is
  /// what makes a stale cookie look like a successful login.
  ///
  /// A token whose expiry cannot be read (the web `dy_auth`) is not expired:
  /// the app cannot know when it ends, and guessing "expired" would refuse a
  /// login that still works.
  static bool isSessionExpired(String cookie) {
    if (sessionToken(cookie) == null) return true;
    final expiry = sessionExpiry(cookie);
    return expiry != null && !expiry.isAfter(DateTime.now());
  }

  /// Whether [cookie] carries everything the passport endpoint needs to renew
  /// an expired session without asking the viewer to sign in again.
  static bool canRefreshSession(String cookie) {
    final longTerm = cookieField(cookie, longTermTokenName);
    final did = cookieField(cookie, deviceIdName);
    return longTerm != null && longTerm.isNotEmpty && did != null && did.isNotEmpty;
  }

  /// What the stored cookie is worth, for the account UI.
  static DouyuSessionState sessionState(String cookie, {DateTime? now}) {
    final normalized = normalizeAccountCookie(cookie);
    if (normalized.isEmpty) return DouyuSessionState.none;

    final at = now ?? DateTime.now();
    final expiry = sessionExpiry(normalized, now: at);
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
  static Future<String?> refreshSession({String? accountCookie}) async {
    final stored = normalizeAccountCookie(accountCookie ?? _configuredAccountCookie());
    if (stored.isEmpty || !canRefreshSession(stored) || !isSessionExpired(stored)) return null;

    final did = cookieField(stored, deviceIdName)!;
    final longTerm = cookieField(stored, longTermTokenName)!;
    final milliseconds = DateTime.now().millisecondsSinceEpoch.toString();
    final url = Uri.parse(_apiDouyuPassport).replace(
      queryParameters: <String, String>{
        'client_id': '1',
        't': milliseconds,
        '_': milliseconds,
        'callback': 'axiosJsonpCallback',
      },
    );

    final setCookies = await _fetchSetCookies(url, <String, String>{
      ...requestHeaders(),
      'cookie': '$deviceIdName=$did;$longTermTokenName=$longTerm',
    });

    final renewed = mergeSetCookieLines(stored, setCookies);
    if (renewed.isEmpty || renewed == stored) return null;

    await _persistCookie(renewed);
    return renewed;
  }

  /// Renews the stored session when it has expired, before a request that needs
  /// it.
  ///
  /// Never throws: a failed renewal means the request goes out as a guest, which
  /// is strictly better than failing the playback the viewer asked for.
  static Future<void> ensureFreshSession({String? accountCookie}) async {
    try {
      final stored = normalizeAccountCookie(accountCookie ?? _configuredAccountCookie());
      if (stored.isEmpty || !canRefreshSession(stored) || !isSessionExpired(stored)) return;
      await refreshSession(accountCookie: stored);
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

  static Future<void> _persistCookie(String cookie) async {
    final injected = debugCookiePersister;
    if (injected != null) {
      injected(cookie);
      return;
    }
    try {
      SettingsService.to.cookieManager.douyuCookie.v = cookie;
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
      fields.add('$name=${piece.substring(separator + 1).trim()}');
    }
    return fields.join('; ');
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
