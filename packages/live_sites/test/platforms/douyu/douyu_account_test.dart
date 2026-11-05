import 'dart:convert';

import 'package:live_sites/src/platforms/douyu/parsers/douyu_account.dart';
import 'package:test/test.dart';

/// A JWT whose payload is [claims], as the H5 login writes one.
String _jwt(Map<String, Object?> claims) {
  String part(String text) => base64Url.encode(utf8.encode(text)).replaceAll('=', '');
  return '${part('{"alg":"HS256"}')}.${part(jsonEncode(claims))}.${part('signature')}';
}

/// A cookie carrying a session token that ends at [exp] (Unix seconds).
String _h5Cookie(int exp) => 'acf_jwt_token=${_jwt({'exp': exp})}; dy_did=DID; LTP0=LTP';

/// Unix seconds of [at].
int _epoch(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

final DateTime _now = DateTime.utc(2026, 10, 1, 12);

void main() {
  group('reading a typed-in cookie', () {
    test('the paste is cleaned, not reinterpreted', () {
      expect(DouyuAccount.normalizeCookie('  Cookie: a=1; b=2  '), 'a=1; b=2');
      expect(DouyuAccount.normalizeCookie('cookie:a=1'), 'a=1');
      expect(DouyuAccount.normalizeCookie('a=1\u0000\u001f\u007f; b=2'), 'a=1; b=2');
      expect(DouyuAccount.normalizeCookie('   '), isEmpty);
    });

    test('fields keep their order, and a later one replaces the earlier name', () {
      expect(DouyuAccount.cookieFields('b=2; a=1; b=3').entries.map((e) => '${e.key}=${e.value}'), [
        'b=3',
        'a=1',
      ], reason: 'the map holds one value per name but keeps the first position');
      expect(DouyuAccount.cookieFields(' x = y '), {'x': 'y'});
      expect(DouyuAccount.cookieFields('novalue; =x; a=1'), {'a': '1'}, reason: 'a field needs a name before the =');
      expect(DouyuAccount.cookieFields('a space=1; b=2'), {'b': '2'}, reason: 'a name with a space is malformed');
      expect(DouyuAccount.cookieFields('a=1=2'), {'a': '1=2'}, reason: 'only the first = splits');
      expect(DouyuAccount.cookieFields(''), isEmpty);
    });

    test('a field is found whatever case the name is in, and blank is absent', () {
      expect(DouyuAccount.cookieField('DY_DID=7', 'dy_did'), '7');
      expect(DouyuAccount.cookieField('dy_did=7', 'DY_DID'), '7');
      expect(DouyuAccount.cookieField('dy_did=  ', 'dy_did'), isNull);
      expect(DouyuAccount.cookieField('other=1', 'dy_did'), isNull);
    });

    test("the device id is the login's own, never another process's", () {
      expect(DouyuAccount.deviceId('dy_did=MINE', 'process'), 'MINE');
      expect(DouyuAccount.deviceId('acf_jwt_token=x', 'process'), 'process');
      expect(DouyuAccount.deviceId('', 'process'), 'process');
    });

    test('the request cookie leads with the device id and never carries LTP0', () {
      final header = DouyuAccount.cookieHeader(
        account: 'dy_did=OLD; acf_did=OLD; ltp0=secret; acf_auth=T; other=1',
        did: 'NEW',
      );
      expect(header, 'dy_did=NEW; acf_did=NEW; acf_auth=T; other=1');
      expect(header, isNot(contains('secret')), reason: 'the play edge answers 403 to the passport key');
      expect(DouyuAccount.cookieHeader(account: '', did: 'D'), 'dy_did=D; acf_did=D');
    });
  });

  group('what the cookie is worth', () {
    test('the session token is the H5 one first, then the web one', () {
      expect(DouyuAccount.sessionToken('dy_auth=W; acf_auth=H; acf_jwt_token=J'), 'J');
      expect(DouyuAccount.sessionToken('dy_auth=W; acf_auth=H'), 'H');
      expect(DouyuAccount.sessionToken('dy_auth=W'), 'W');
      expect(DouyuAccount.sessionToken('dy_auth=; acf_auth=H'), 'H', reason: 'a blank token is no token');
      expect(DouyuAccount.sessionToken('other=1'), isNull);
    });

    test('a JWT payload is read with or without its padding, and nothing else is', () {
      final claims = DouyuAccount.jwtPayload(_jwt({'exp': 100, 'sub': 'a'}));
      expect(claims?['exp'], 100);
      expect(claims?['sub'], 'a');
      expect(DouyuAccount.jwtPayload('a.b'), isNull);
      expect(DouyuAccount.jwtPayload('a.b.c.d'), isNull);
      expect(DouyuAccount.jwtPayload('a!!!.b.c'), isNull);
      expect(DouyuAccount.jwtPayload('${'a'}.${base64Url.encode(utf8.encode('[1,2]'))}.c'), isNull);
      expect(DouyuAccount.jwtPayload(''), isNull);
    });

    test('the end of a session is what the answer said, never a guess', () {
      final inHour = _now.add(const Duration(hours: 1));
      expect(DouyuAccount.sessionExpiry(_h5Cookie(_epoch(inHour))), inHour);
      expect(
        DouyuAccount.sessionExpiry('dy_auth=opaque', savedAt: _now),
        _now.add(DouyuAccount.webCookieLifetime),
        reason: 'the web token lasts seven days from when it was saved',
      );
      expect(DouyuAccount.sessionExpiry('dy_auth=opaque'), isNull, reason: 'no saved time, no claim about the end');
      expect(DouyuAccount.sessionExpiry('other=1', savedAt: _now), isNull);
      expect(
        DouyuAccount.sessionExpiry('acf_jwt_token=${_jwt({'exp': 0})}', savedAt: _now),
        _now.add(DouyuAccount.webCookieLifetime),
        reason: 'an exp of zero says nothing, so the web rule answers',
      );
    });

    test('the state says what a request with this cookie would be', () {
      DouyuSessionState of(String cookie, {String? ltp0, String? did, DateTime? savedAt}) =>
          DouyuAccount.sessionState(cookie, now: _now, savedAt: savedAt, ltp0: ltp0, did: did);

      expect(of(''), DouyuSessionState.none);
      expect(of('   '), DouyuSessionState.none);
      expect(of('dy_did=D'), DouyuSessionState.guest, reason: 'a cookie without a session token is a guest');
      expect(of(_h5Cookie(_epoch(_now.add(const Duration(hours: 1))))), DouyuSessionState.valid);
      expect(of('dy_auth=opaque', savedAt: _now), DouyuSessionState.valid, reason: 'seven days from now');
      expect(of('dy_auth=opaque'), DouyuSessionState.valid, reason: 'an unknown end is not read as an expired one');
      final past = _h5Cookie(_epoch(_now.subtract(const Duration(minutes: 1))));
      expect(of(past), DouyuSessionState.expired);
      expect(of(past, ltp0: 'L', did: 'D'), DouyuSessionState.expiredRefreshable);
      expect(of(past, ltp0: 'L'), DouyuSessionState.expired, reason: 'a renewal needs the device id too');
      expect(of(past, did: 'D'), DouyuSessionState.expired);
    });

    test('a session is renewed inside the last day, and an unknown end is left alone', () {
      bool renew(String cookie, {DateTime? savedAt}) => DouyuAccount.shouldRenew(cookie, now: _now, savedAt: savedAt);

      expect(renew('other=1'), isTrue, reason: 'no token at all, so ask before playing');
      expect(renew(_h5Cookie(_epoch(_now.add(const Duration(days: 2))))), isFalse);
      expect(renew(_h5Cookie(_epoch(_now.add(const Duration(hours: 12))))), isTrue);
      expect(renew(_h5Cookie(_epoch(_now.subtract(const Duration(seconds: 1))))), isTrue);
      expect(
        renew(_h5Cookie(_epoch(_now.add(DouyuAccount.renewalMargin)))),
        isTrue,
        reason: 'the margin is inclusive at its edge',
      );
      expect(renew('dy_auth=opaque'), isFalse, reason: 'nothing says when it ends');
      expect(renew('dy_auth=opaque', savedAt: _now.subtract(const Duration(days: 8))), isTrue);
    });

    test('the renewal credentials prefer what the user typed, and never a stranger device', () {
      final credentials = DouyuAccount.renewalCredentials(_h5Cookie(1), typedLtp0: '', storedLtp0: 'STORED');
      expect(credentials.ltp0, 'LTP', reason: 'a blank typed value is no value, so the cookie answers');
      expect(credentials.did, 'DID');
      expect(DouyuAccount.renewalCredentials('acf_auth=T', typedLtp0: 'T1', typedDid: 'D1').ltp0, 'T1');
      expect(DouyuAccount.renewalCredentials('acf_auth=T', storedLtp0: 'S', storedDid: 'P'), (
        ltp0: 'S',
        did: 'P',
      ), reason: 'the separately stored pair answers only when the cookie has neither');
      expect(
        DouyuAccount.renewalCredentials('acf_auth=T').did,
        isNull,
        reason: 'the process did is never a substitute',
      );
      expect(DouyuAccount.renewalCredentials('acf_auth=T', typedDid: 'd\u00001').did, 'd1');
    });

    test('a passport cookie is not a login and must not reach the play edge', () {
      expect(DouyuAccount.isPassportCookie('LTP0=x; acf_ccn=1'), isTrue);
      expect(DouyuAccount.isPassportCookie('ltp0=x'), isTrue, reason: 'the field is matched by any case');
      expect(DouyuAccount.isPassportCookie('acf_stk=x'), isTrue);
      expect(DouyuAccount.isPassportCookie(_h5Cookie(1)), isFalse, reason: 'it has a session token');
      expect(DouyuAccount.isPassportCookie('other=1'), isFalse);
      expect(DouyuAccount.isPassportCookie(''), isFalse);
    });
  });

  group('a renewal answer merged back in', () {
    test('what the answer did not mention stays, what it emptied goes', () {
      final merged = DouyuAccount.mergeSetCookie('LTP0=keep; acf_auth=OLD; dy_did=DID; gone=1', [
        'acf_auth=NEW; Path=/; Domain=.douyu.com; Secure; HttpOnly',
        'gone=; Path=/',
        'dy_auth=x',
        'Path=/ignore',
        'novalue',
      ]);
      final fields = DouyuAccount.cookieFields(merged);
      expect(fields['LTP0'], 'keep', reason: 'without it the next renewal has nothing to ask with');
      expect(fields['acf_auth'], 'NEW');
      expect(fields['dy_did'], 'DID');
      expect(fields.containsKey('gone'), isFalse, reason: 'an emptied field is dropped, not kept blank');
      expect(fields['Path'], isNull, reason: 'an attribute name is never a cookie field');
      expect(fields['dy_auth'], 'x');
      expect(merged, isNot(contains('Secure')));
    });

    test('the renewed login is kept only when it can actually play', () {
      expect(DouyuAccount.renewedCookie('acf_auth=OLD', const []), isNull, reason: 'nothing was renewed');
      expect(
        DouyuAccount.renewedCookie('LTP0=x; dy_did=D', const ['acf_ccn=1']),
        isNull,
        reason: 'a merge with no session token keeps the old cookie instead of saving a guest',
      );
      final renewed = DouyuAccount.renewedCookie(_h5Cookie(1), const ['acf_auth=NEW']);
      expect(DouyuAccount.cookieFields(renewed!)['acf_auth'], 'NEW');
      expect(renewed, contains('LTP0=LTP'));
    });
  });
}
