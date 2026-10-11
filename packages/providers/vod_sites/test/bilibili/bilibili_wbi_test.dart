// Module: test/bili_wbi_test.dart
// Purpose: Pin the WBI recipe against fixed vectors, and the key cache's expiry and refusal behaviour.
// Author: liuchuancong
// Created: 2026-10-11
//
// The vectors are regression pins derived from this implementation once, by hand, and written down as
// literals: they catch the recipe being edited (permutation table, key order, which characters are stripped,
// which encoder is used) - they are not an oracle from the site. The one assertion that *is* externally
// meaningful is the encoding of a space, because JavaScript's encodeURIComponent (what the server hashes
// against) yields %20 and Dart's encodeQueryComponent yields '+'.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_network/testing.dart';
import 'package:pure_live_vod_sites/pure_live_vod_sites.dart';
import 'package:test/test.dart';

const String _imgKey = '7cd08494133a40833e9ee1a137569020';
const String _subKey = '4932caff0ff746eab6f01bf08b0283d5';
const String _mixinKey = 'ea9db1143f300062674693fe098f4ff0';

/// A nav answer with the key urls the site serves.
String _navBody({String img = 'https://i0.hdslb.com/bfs/wfi/$_imgKey.png'}) => jsonEncode(<String, Object?>{
  'code': 0,
  'message': '0',
  'data': <String, Object?>{
    'wbi_img': <String, Object?>{'img_url': img, 'sub_url': 'https://i0.hdslb.com/bfs/wfi/$_subKey.png'},
  },
});

void main() {
  group('test_biliWbi_recipe', () {
    test('test_wbiMixinKey_permutesToThePinnedVector', () {
      expect(wbiMixinKey('$_imgKey$_subKey'), _mixinKey);
      expect(wbiMixinKey('$_imgKey$_subKey').length, 32);
    });

    test('test_wbiMixinKey_refusesASourceKeyTooShortToPermute', () {
      // Substringing whatever arrived would sign with a truncated key and every request would then fail with
      // a risk-control code that names neither the key nor this function.
      expect(() => wbiMixinKey('short'), throwsA(isA<FormatException>()));
    });

    test('test_wbiSignedQuery_matchesThePinnedVector', () {
      final at = DateTime.fromMillisecondsSinceEpoch(1700000000000);

      expect(
        wbiSignedQuery(<String, String>{'foo': 'bar', 'spam': 'a b!'}, mixinKey: _mixinKey, at: at),
        'foo=bar&spam=a%20b!&wts=1700000000&w_rid=ebd19142e92d4daf05df5959ec0c266f',
      );
    });

    test('test_wbiSignedQuery_encodesASpaceAsPercentTwentyNotPlus', () {
      // The defect this replaces: signing with Uri.encodeQueryComponent put `+` where the server's own client
      // puts `%20`, so any keyword with a space produced a signature that could not match.
      final at = DateTime.utc(2026, 10, 11);
      final query = wbiSignedQuery(<String, String>{'keyword': 'hello world'}, mixinKey: _mixinKey, at: at);

      expect(query, contains('keyword=hello%20world'));
      expect(query, isNot(contains('hello+world')));
    });

    test('test_wbiSignedQuery_stripsTheCharactersTheApiStripsButOnlyFromValues', () {
      final query = wbiSignedQuery(
        <String, String>{'a': "x'y(z)*w", 'b~c': 'd'},
        mixinKey: _mixinKey,
        at: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(query, contains('a=xyzw'));
      expect(query, contains('b~c=d'), reason: 'the key itself is not filtered of its tilde');
    });

    test('test_wbiSignedQuery_sortsKeysAndAppendsTheRidOverTheJoinedString', () {
      final query = wbiSignedQuery(
        <String, String>{'zeta': '1', 'alpha': '2'},
        mixinKey: _mixinKey,
        at: DateTime.fromMillisecondsSinceEpoch(1000000000000),
      );
      final expected = 'alpha=2&wts=1000000000&zeta=1';
      final rid = md5.convert(utf8.encode('$expected$_mixinKey')).toString();

      expect(query, '$expected&w_rid=$rid');
      expect(query.indexOf('wts'), lessThan(query.indexOf('zeta')));
    });
  });

  group('test_biliWbi_signer', () {
    test('test_signedQuery_fetchesOnceAndCachesUntilTheKeyLifetimePasses', () async {
      final transport = _recordingTransport(<String>[_navBody()]);
      var now = DateTime.utc(2026, 10, 11);
      final signer = BiliWbiSigner(
        client: _signerClient(transport),
        clock: () => now,
        keyLifetime: const Duration(hours: 1),
      );

      await signer.signedQuery(<String, String>{'keyword': 'a'});
      await signer.signedQuery(<String, String>{'keyword': 'b'});
      expect(transport.requestsTo(_navKey), 1, reason: 'the second call must not re-read nav');

      now = now.add(const Duration(hours: 2));
      await signer.signedQuery(<String, String>{'keyword': 'c'});
      expect(
        transport.requestsTo(_navKey),
        2,
        reason: 'the site rotates keys on deploys; a forever-cache pins a dead key',
      );
    });

    test('test_signedQuery_sitsOnAFailureInsteadOfRetryingPerRequest', () async {
      final transport = _recordingTransport(<String>['{"code":-352,"message":"risk control"}']);
      var now = DateTime.utc(2026, 10, 11);
      final signer = BiliWbiSigner(
        client: _signerClient(transport),
        clock: () => now,
        failureBackoff: const Duration(minutes: 5),
      );

      await expectLater(signer.signedQuery(<String, String>{'keyword': 'a'}), throwsA(anything));
      now = now.add(const Duration(seconds: 30));
      await expectLater(signer.signedQuery(<String, String>{'keyword': 'b'}), throwsA(isA<StateError>()));
      expect(transport.requestsTo(_navKey), 1, reason: 'an outage must not become a retry storm against nav');

      now = now.add(const Duration(minutes: 5));
      transport.script[_navKey]!.add(_navBody());
      expect(await signer.signedQuery(<String, String>{'keyword': 'c'}), contains('w_rid='));
      expect(transport.requestsTo(_navKey), 2);
    });

    test('test_signedQuery_refusesAnAnswerWithoutWbiKeys', () async {
      final transport = _recordingTransport(<String>['{"code":0,"data":{}}']);
      final signer = BiliWbiSigner(client: _signerClient(transport), clock: () => DateTime.utc(2026));

      await expectLater(signer.signedQuery(<String, String>{}), throwsA(isA<FormatException>()));
    });
  });

  group('test_biliWbi_buvid3', () {
    test('test_randomBuvid3_isTheShapeTheSiteIssues', () {
      final value = randomBuvid3();

      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}infoc$').hasMatch(value),
        isTrue,
        reason: 'the first version made a 16-character first field out of the clock',
      );
    });

    test('test_randomBuvid3_doesNotRepeatAndIsNotDerivableFromTheClock', () {
      final values = <String>{for (var i = 0; i < 200; i++) randomBuvid3()};

      expect(values, hasLength(200));
    });
  });
}

/// The scripted nav endpoint, from the published transport: this file used to implement its own
/// `HttpClientAdapter`, which meant depending on dio directly for one fake.
const String _navKey = '/x/web-interface/nav';

ScriptedTransport _recordingTransport(List<String> bodies) =>
    ScriptedTransport(<String, List<String>>{_navKey: bodies});

/// One attempt per request: the signer's own backoff is what these tests count, and the production retry
/// policy would otherwise add transport attempts on top.
NetworkClient _signerClient(ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);
