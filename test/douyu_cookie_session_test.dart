import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/douyu/douyu_utils.dart';

/// A Douyu session cookie, as a browser hands it over.
///
/// `exp` is what the whole feature turns on: the token is a JWT, so the cookie
/// itself says when the login ends instead of the app guessing from its age.
String sessionCookie({
  required int expiresAtSeconds,
  String? longTermToken = 'lt0-token',
  String deviceId = 'did-from-login',
  String tokenName = 'acf_jwt_token',
  Map<String, String> extra = const <String, String>{},
}) {
  final payload = base64Url.encode(utf8.encode(jsonEncode(<String, Object?>{'exp': expiresAtSeconds}))).replaceAll('=', '');
  final token = 'header.$payload.signature';
  final fields = <String>[
    'dy_did=$deviceId',
    if (longTermToken != null) 'LTP0=$longTermToken',
    '$tokenName=$token',
    ...extra.entries.map((entry) => '${entry.key}=${entry.value}'),
  ];
  return fields.join('; ');
}

int _secondsFromNow(Duration offset) => DateTime.now().add(offset).millisecondsSinceEpoch ~/ 1000;

/// The web flavour, as `www.douyu.com` hands it over: the login lives in
/// `dy_auth`, there is no JWT to read an expiry from and no `LTP0` to renew with.
/// Taken from a real browser cookie (account id redacted), because the shape is
/// the whole point: the H5-only logic read this as a guest cookie.
const String webCookie =
    'dy_did=73d91171ec9e4614d1f5532c00011701; game_did=gL7j2IBs-CT8WuCJX2I8l5W6f1VB0BsNfOe; '
    '_ga=GA1.1.1870208202.1780155809; HMACCOUNT=498D2F764FF3F7F0; dy_accounts_main=1; '
    'dy_auth=f5f68VIwO8XE68TA8Wv%2BzAqYdKePRNY3n85g7ScIQOpJdvSJvpqs4N%2F%2BD0bkst0rg323moxICzq8LC5me8VYiawFBilvyYPL3xs9vazn8XqRoD0JEKtxVvc; '
    'mantine-color-scheme-value=light; dy_teen_mode=%7B%22uid%22%3A%22349384914%22%2C%22status%22%3A0%7D; msgUnread=waiting';

void main() {
  tearDown(() {
    DouyuUtils.debugCookieFetcher = null;
    DouyuUtils.debugCookiePersister = null;
  });

  group('cookie parsing', () {
    test('splits fields and ignores blanks', () {
      final fields = DouyuUtils.parseCookieFields('a=1; ; b = 2 ; =3');

      expect(fields.map((field) => '${field.name}=${field.value}').toList(), <String>['a=1', 'b=2']);
    });

    test('reads a field case-insensitively', () {
      expect(DouyuUtils.cookieField('dy_did=abc; ACF_JWT_TOKEN=xyz', 'acf_jwt_token'), 'xyz');
      expect(DouyuUtils.cookieField('dy_did=abc', 'LTP0'), isNull);
    });

    test('prefers acf_jwt_token and falls back to acf_auth', () {
      expect(DouyuUtils.sessionToken('acf_auth=a.b.c'), 'a.b.c');
      expect(DouyuUtils.sessionToken('acf_jwt_token=j; acf_auth=a'), 'j');
      expect(DouyuUtils.sessionToken('dy_did=abc'), isNull);
    });
  });

  group('session expiry', () {
    test('reads exp out of the JWT payload', () {
      final expiresAt = _secondsFromNow(const Duration(hours: 2));
      final expiry = DouyuUtils.sessionExpiry(sessionCookie(expiresAtSeconds: expiresAt));

      expect(expiry, isNotNull);
      expect(expiry!.millisecondsSinceEpoch ~/ 1000, expiresAt);
    });

    test('a token that is not a JWT has no known expiry', () {
      expect(DouyuUtils.decodeJwtPayload('not-a-jwt'), isNull);
      expect(DouyuUtils.decodeJwtPayload('a.!!!not-base64!!!.c'), isNull);
      expect(DouyuUtils.sessionExpiry('acf_jwt_token=opaque'), isNull);
    });

    test('a cookie without a token counts as expired', () {
      expect(DouyuUtils.isSessionExpired('dy_did=abc; LTP0=lt'), isTrue);
      expect(DouyuUtils.isSessionExpired(''), isTrue);
    });

    test('expired and live tokens are distinguished', () {
      expect(DouyuUtils.isSessionExpired(sessionCookie(expiresAtSeconds: _secondsFromNow(const Duration(hours: 1)))), isFalse);
      expect(DouyuUtils.isSessionExpired(sessionCookie(expiresAtSeconds: _secondsFromNow(const Duration(hours: -1)))), isTrue);
    });

    test('renewal needs both LTP0 and the device id the login belongs to', () {
      final live = sessionCookie(expiresAtSeconds: _secondsFromNow(const Duration(hours: 1)));
      expect(DouyuUtils.canRefreshSession(live), isTrue);
      expect(DouyuUtils.canRefreshSession(sessionCookie(expiresAtSeconds: 1, longTermToken: null)), isFalse);
      expect(DouyuUtils.canRefreshSession('LTP0=lt; acf_jwt_token=opaque'), isFalse);
    });
  });

  group('session state', () {
    test('covers none, guest, valid, refreshable and expired', () {
      final now = DateTime.now();

      expect(DouyuUtils.sessionState('', now: now), DouyuSessionState.none);
      expect(DouyuUtils.sessionState('dy_did=abc', now: now), DouyuSessionState.guest);
      expect(
        DouyuUtils.sessionState(sessionCookie(expiresAtSeconds: _secondsFromNow(const Duration(hours: 3))), now: now),
        DouyuSessionState.valid,
      );
      expect(
        DouyuUtils.sessionState(sessionCookie(expiresAtSeconds: _secondsFromNow(const Duration(hours: -3))), now: now),
        DouyuSessionState.expiredRefreshable,
      );
      expect(
        DouyuUtils.sessionState(
          sessionCookie(expiresAtSeconds: _secondsFromNow(const Duration(hours: -3)), longTermToken: null),
          now: now,
        ),
        DouyuSessionState.expired,
      );
    });
  });

  group('web cookie (www.douyu.com)', () {
    test('a dy_auth cookie is a session, not a guest', () {
      expect(DouyuUtils.sessionToken(webCookie), isNotNull);
      expect(DouyuUtils.sessionState(webCookie), DouyuSessionState.valid);
    });

    test('its expiry is unknown rather than expired', () {
      expect(DouyuUtils.sessionExpiry(webCookie), isNull);
      expect(DouyuUtils.isSessionExpired(webCookie), isFalse);
    });

    test('it is not refreshable: the web flow issues no LTP0', () {
      expect(DouyuUtils.canRefreshSession(webCookie), isFalse);
    });

    test('requests present the did the login belongs to', () {
      final header = DouyuUtils.cookieHeader(accountCookie: webCookie);

      expect(header, startsWith('dy_did=73d91171ec9e4614d1f5532c00011701; acf_did=73d91171ec9e4614d1f5532c00011701'));
      expect(header, contains('dy_auth='), reason: 'the opaque token must be forwarded verbatim');
      expect(header, contains('%2B'), reason: 'the token is percent-encoded and must not be decoded in transit');
    });

    test('ensureFreshSession leaves it alone', () async {
      var called = false;
      DouyuUtils.debugCookieFetcher = (_, _) async {
        called = true;
        return const <String>[];
      };

      await DouyuUtils.ensureFreshSession(accountCookie: webCookie);

      expect(called, isFalse);
    });

    test('an H5 cookie without LTP0 is still a session with an unknown end', () {
      // No LTP0 and no readable JWT: a session we cannot date, not a guest.
      expect(DouyuUtils.sessionState('dy_did=abc; acf_auth=opaque-token'), DouyuSessionState.valid);
    });
  });

  group('Set-Cookie merging', () {
    test('keeps everything the response did not mention', () {
      final merged = DouyuUtils.mergeSetCookieLines(
        'dy_did=abc; LTP0=lt; acf_jwt_token=old',
        <String>['acf_jwt_token=new; Path=/; HttpOnly', 'acf_uid=42; Domain=.douyu.com'],
      );

      expect(merged, 'dy_did=abc; LTP0=lt; acf_jwt_token=new; acf_uid=42');
    });

    test('drops a field the server cleared instead of resurrecting it', () {
      final merged = DouyuUtils.mergeSetCookieLines('dy_did=abc; acf_jwt_token=old', <String>['acf_jwt_token=; Path=/']);

      expect(DouyuUtils.cookieField(merged, 'acf_jwt_token'), isNull);
      expect(DouyuUtils.cookieField(merged, 'dy_did'), 'abc');
    });

    test('ignores attribute-only and malformed lines', () {
      final merged = DouyuUtils.mergeSetCookieLines('dy_did=abc', <String>['Path=/', '=novalue', 'ok=1']);

      expect(merged, 'dy_did=abc; ok=1');
    });
  });

  group('device id coherence', () {
    test('uses the did the login was issued for, not the process did', () {
      final cookie = sessionCookie(expiresAtSeconds: _secondsFromNow(const Duration(hours: 1)), deviceId: 'did-from-login');

      expect(DouyuUtils.effectiveDeviceId(accountCookie: cookie), 'did-from-login');
      expect(DouyuUtils.cookieHeader(accountCookie: cookie), startsWith('dy_did=did-from-login; acf_did=did-from-login'));
    });

    test('falls back to the generated did when the cookie carries none', () {
      final header = DouyuUtils.cookieHeader(accountCookie: 'acf_jwt_token=a.b.c');

      expect(header, startsWith('dy_did=${DouyuUtils.deviceId}; acf_did=${DouyuUtils.deviceId}'));
    });

    test('keeps the account fields but never duplicates the did fields', () {
      final header = DouyuUtils.cookieHeader(
        accountCookie: 'dy_did=did-a; acf_did=did-b; acf_uid=42; acf_auth=a.b.c',
      );

      expect(header, 'dy_did=did-a; acf_did=did-a; acf_uid=42; acf_auth=a.b.c');
    });

    test('drops a pasted Cookie: prefix and control characters', () {
      final header = DouyuUtils.cookieHeader(accountCookie: 'Cookie: acf_uid=42\n');

      expect(header.contains('Cookie:'), isFalse);
      expect(header.contains('acf_uid=42'), isTrue);
    });
  });

  group('renewal', () {
    test('calls the passport endpoint with the login did and the long-term key', () async {
      Uri? seenUrl;
      Map<String, String>? seenHeaders;
      DouyuUtils.debugCookieFetcher = (url, headers) async {
        seenUrl = url;
        seenHeaders = headers;
        return <String>['acf_jwt_token=fresh; Path=/', 'acf_uid=42; Path=/'];
      };

      final cookie = sessionCookie(expiresAtSeconds: _secondsFromNow(const Duration(hours: -1)), deviceId: 'did-login');
      final renewed = await DouyuUtils.refreshSession(accountCookie: cookie);

      expect(seenUrl!.host, 'passport.douyu.com');
      expect(seenUrl!.queryParameters['client_id'], '1');
      expect(seenHeaders!['cookie'], 'dy_did=did-login;LTP0=lt0-token');
      expect(renewed, isNotNull);
      expect(DouyuUtils.cookieField(renewed!, 'acf_jwt_token'), 'fresh');
      expect(
        DouyuUtils.cookieField(renewed, 'LTP0'),
        'lt0-token',
        reason: 'the long-term key must survive, or the next renewal has nothing to use',
      );
    });

    test('stores the renewed cookie', () async {
      String? persisted;
      DouyuUtils.debugCookieFetcher = (_, _) async => <String>['acf_jwt_token=fresh'];
      DouyuUtils.debugCookiePersister = (cookie) => persisted = cookie;

      await DouyuUtils.refreshSession(accountCookie: sessionCookie(expiresAtSeconds: _secondsFromNow(const Duration(hours: -1))));

      expect(persisted, isNotNull);
      expect(DouyuUtils.cookieField(persisted!, 'acf_jwt_token'), 'fresh');
    });

    test('does nothing for a live session', () async {
      var called = false;
      DouyuUtils.debugCookieFetcher = (_, _) async {
        called = true;
        return const <String>[];
      };

      final renewed = await DouyuUtils.refreshSession(
        accountCookie: sessionCookie(expiresAtSeconds: _secondsFromNow(const Duration(hours: 2))),
      );

      expect(renewed, isNull);
      expect(called, isFalse, reason: 'a valid session must not spend a request');
    });

    test('does nothing when there is no long-term key', () async {
      var called = false;
      DouyuUtils.debugCookieFetcher = (_, _) async {
        called = true;
        return const <String>[];
      };

      final renewed = await DouyuUtils.refreshSession(
        accountCookie: sessionCookie(expiresAtSeconds: _secondsFromNow(const Duration(hours: -1)), longTermToken: null),
      );

      expect(renewed, isNull);
      expect(called, isFalse);
    });

    test('ensureFreshSession renews an expired cookie and swallows a failure', () async {
      String? persisted;
      DouyuUtils.debugCookiePersister = (cookie) => persisted = cookie;
      DouyuUtils.debugCookieFetcher = (_, _) async => <String>['acf_jwt_token=fresh'];

      await DouyuUtils.ensureFreshSession(accountCookie: sessionCookie(expiresAtSeconds: _secondsFromNow(const Duration(hours: -1))));
      expect(persisted, isNotNull);

      DouyuUtils.debugCookieFetcher = (_, _) async => throw StateError('offline');
      await DouyuUtils.ensureFreshSession(accountCookie: sessionCookie(expiresAtSeconds: _secondsFromNow(const Duration(hours: -1))));
      // Reaching here without an exception is the assertion: a failed renewal
      // must leave the request to go out as a guest.
    });

    test('an endpoint that answers without a cookie leaves the stored one alone', () async {
      var persisted = false;
      DouyuUtils.debugCookieFetcher = (_, _) async => const <String>[];
      DouyuUtils.debugCookiePersister = (_) => persisted = true;

      final renewed = await DouyuUtils.refreshSession(
        accountCookie: sessionCookie(expiresAtSeconds: _secondsFromNow(const Duration(hours: -1))),
      );

      expect(renewed, isNull);
      expect(persisted, isFalse);
    });
  });

  group('signing', () {
    test('builds the query from the descriptor with the given did', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final query = DouyuUtils.buildSignedData(
        encryptionKey: <String, dynamic>{
          'key': 'k',
          'rand_str': 'r',
          'enc_time': 1,
          'enc_data': 'enc',
          'is_special': 0,
          'expire_at': now + 60,
        },
        roomId: '9999',
        timestampSeconds: now,
        deviceId: 'did-x',
      );

      expect(query, contains('did=did-x'));
      expect(query, contains('enc_data=enc'));
      expect(query, contains('ver=Douyu_new'));
      expect(query, contains('tt=$now'));
    });
  });
}
