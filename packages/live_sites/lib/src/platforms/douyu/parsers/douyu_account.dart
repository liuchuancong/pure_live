import 'dart:convert';

import 'package:live_sites/src/platforms/douyu/parsers/douyu_json.dart';

/// What a stored douyu login cookie is worth.
enum DouyuSessionState {
  /// No cookie.
  none,

  /// A cookie without a session token: requests go out as a guest.
  guest,

  /// A token that has not expired, or whose end is unknown.
  valid,

  /// Expired, but LTP0 and the login's device id can renew it.
  expiredRefreshable,

  /// Expired, with nothing to renew it with.
  expired,
}

/// Pure cookie/session logic of the douyu login (reference `DouyuApi`
/// session section; 3.x's `DouyuUtils`). All static, no I/O — renewal
/// requests belong to the adapter.
abstract final class DouyuAccount {
  /// The web `dy_auth` lasts seven days from when it was saved.
  static const Duration webCookieLifetime = Duration(days: 7);

  /// A session is renewed within the last day.
  static const Duration renewalMargin = Duration(days: 1);

  /// Session tokens in order of preference: the H5 JWTs, then the web
  /// token.
  static const List<String> sessionTokenNames = ['acf_jwt_token', 'acf_auth', 'dy_auth'];

  /// The long-term renewal key; it only ever goes to the passport.
  static const String longTermKeyName = 'LTP0';

  /// The device id a login belongs to.
  static const String deviceIdName = 'dy_did';

  static const List<String> _passportFields = ['LTP0', 'acf_stk', 'acf_ccn', 'acf_ltkid', 'acf_ssid'];

  static const Set<String> _setCookieAttributes = {
    'path',
    'domain',
    'expires',
    'max-age',
    'samesite',
    'secure',
    'httponly',
  };

  static final RegExp _controls = RegExp(r'[\u0000-\u001F\u007F]');
  static final RegExp _cookieName = RegExp(r"^[A-Za-z0-9_!#$%&'*+.^`|~-]+$");

  /// [cookie] without control characters, outer blanks or a pasted
  /// `Cookie:` prefix.
  static String normalizeCookie(String cookie) =>
      cookie.replaceAll(_controls, '').trim().replaceFirst(RegExp(r'^Cookie:\s*', caseSensitive: false), '').trim();

  /// The `name=value` fields of [cookie] in order; a malformed name is
  /// skipped and a later field replaces an earlier one of the same name.
  static Map<String, String> cookieFields(String cookie) {
    final fields = <String, String>{};
    for (final part in normalizeCookie(cookie).split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      final name = part.substring(0, separator).trim();
      if (!_cookieName.hasMatch(name)) continue;
      fields[name] = part.substring(separator + 1).trim();
    }
    return fields;
  }

  /// Field [name] of [cookie] (any case), or null when absent or blank.
  static String? cookieField(String cookie, String name) {
    final wanted = name.toLowerCase();
    for (final MapEntry(:key, :value) in cookieFields(cookie).entries) {
      if (key.toLowerCase() == wanted) return value.isEmpty ? null : value;
    }
    return null;
  }

  /// The device id of every request: the account cookie's `dy_did` (the
  /// login belongs to it; signing with another is answered as a guest),
  /// else [processDid].
  static String deviceId(String account, String processDid) => cookieField(account, deviceIdName) ?? processDid;

  /// The request cookie: `dy_did` and `acf_did` set to [did] first, then
  /// the account fields without their own device ids and without `LTP0`
  /// (passport only; the play edge answers 403 to it).
  static String cookieHeader({required String account, required String did}) => [
    'dy_did=$did',
    'acf_did=$did',
    for (final MapEntry(:key, :value) in cookieFields(account).entries)
      if (!const {'dy_did', 'acf_did', 'ltp0'}.contains(key.toLowerCase())) '$key=$value',
  ].join('; ');

  /// The session token: `acf_jwt_token`, else `acf_auth`, else `dy_auth`.
  static String? sessionToken(String cookie) {
    for (final name in sessionTokenNames) {
      final value = cookieField(cookie, name);
      if (value != null) return value;
    }
    return null;
  }

  /// The payload of a JWT, or null when [token] is not one.
  static Map<String, Object?>? jwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final decoded = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// When the session ends: the JWT's `exp` (H5 tokens), else [savedAt]
  /// plus seven days (the opaque web `dy_auth`); null when nothing says,
  /// never guessed.
  static DateTime? sessionExpiry(String cookie, {DateTime? savedAt}) {
    final token = sessionToken(cookie);
    if (token == null) return null;
    final exp = jsonInt(jwtPayload(token)?['exp']);
    if (exp != null && exp > 0) return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    return savedAt?.add(webCookieLifetime);
  }

  /// What [cookie] is worth at [now]; [ltp0] and [did] are the renewal
  /// credentials.
  static DouyuSessionState sessionState(
    String cookie, {
    required DateTime now,
    DateTime? savedAt,
    String? ltp0,
    String? did,
  }) {
    if (normalizeCookie(cookie).isEmpty) return DouyuSessionState.none;
    if (sessionToken(cookie) == null) return DouyuSessionState.guest;
    final end = sessionExpiry(cookie, savedAt: savedAt);
    if (end == null || end.isAfter(now)) return DouyuSessionState.valid;
    return ltp0 != null && did != null ? DouyuSessionState.expiredRefreshable : DouyuSessionState.expired;
  }

  /// Whether to renew before a play request: no token, or within
  /// [renewalMargin] of the end. An unknown end is left alone.
  static bool shouldRenew(String cookie, {required DateTime now, DateTime? savedAt}) {
    if (sessionToken(cookie) == null) return true;
    final end = sessionExpiry(cookie, savedAt: savedAt);
    return end != null && !now.isBefore(end.subtract(renewalMargin));
  }

  /// LTP0 and the device id a renewal needs: typed, else the cookie's own
  /// fields, else the separately stored ones. The device id never falls
  /// back to the process DID (the passport refuses another device).
  static ({String? ltp0, String? did}) renewalCredentials(
    String cookie, {
    String? typedLtp0,
    String? typedDid,
    String? storedLtp0,
    String? storedDid,
  }) {
    String? clean(String? value) {
      final text = value?.replaceAll(_controls, '').trim();
      return text == null || text.isEmpty ? null : text;
    }

    return (
      ltp0: clean(typedLtp0) ?? cookieField(cookie, longTermKeyName) ?? clean(storedLtp0),
      did: clean(typedDid) ?? cookieField(cookie, deviceIdName) ?? clean(storedDid),
    );
  }

  /// A cookie copied from the passport request: renewal fields and no
  /// session token. It is no login and must not be sent to play endpoints.
  static bool isPassportCookie(String cookie) =>
      sessionToken(cookie) == null && _passportFields.any((name) => cookieField(cookie, name) != null);

  /// [cookie] with a renewal's `Set-Cookie` [lines] merged in: fields the
  /// answer did not mention stay (LTP0 among them, or the next renewal has
  /// nothing to use), emptied ones are removed, attributes are ignored.
  static String mergeSetCookie(String cookie, Iterable<String> lines) {
    final merged = cookieFields(cookie);
    for (final line in lines) {
      final pair = line.split(';').first.trim();
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      final name = pair.substring(0, separator).trim();
      if (!_cookieName.hasMatch(name) || _setCookieAttributes.contains(name.toLowerCase())) continue;
      final value = pair.substring(separator + 1).replaceAll(_controls, '').trim();
      if (value.isEmpty) {
        merged.remove(name);
      } else {
        merged[name] = value;
      }
    }
    return merged.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
  }

  /// The renewed login from a passport answer's `Set-Cookie` [lines]: null
  /// when there are none (nothing was renewed, and the save time must not
  /// move) or the merge left no session token (keep the old cookie).
  static String? renewedCookie(String cookie, List<String> lines) {
    if (lines.isEmpty) return null;
    final merged = mergeSetCookie(cookie, lines);
    return sessionToken(merged) == null ? null : merged;
  }
}
