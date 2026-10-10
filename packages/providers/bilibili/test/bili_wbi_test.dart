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
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:pure_live_bilibili/pure_live_bilibili.dart';
import 'package:pure_live_network/pure_live_network.dart';
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
      final transport = _RecordingTransport(<String>[_navBody()]);
      var now = DateTime.utc(2026, 10, 11);
      final signer = BiliWbiSigner(
        client: NetworkClient(adapter: transport),
        clock: () => now,
        keyLifetime: const Duration(hours: 1),
      );

      await signer.signedQuery(<String, String>{'keyword': 'a'});
      await signer.signedQuery(<String, String>{'keyword': 'b'});
      expect(transport.navRequests, 1, reason: 'the second call must not re-read nav');

      now = now.add(const Duration(hours: 2));
      await signer.signedQuery(<String, String>{'keyword': 'c'});
      expect(transport.navRequests, 2, reason: 'the site rotates keys on deploys; a forever-cache pins a dead key');
    });

    test('test_signedQuery_sitsOnAFailureInsteadOfRetryingPerRequest', () async {
      final transport = _RecordingTransport(<String>['{"code":-352,"message":"risk control"}']);
      var now = DateTime.utc(2026, 10, 11);
      final signer = BiliWbiSigner(
        client: NetworkClient(adapter: transport),
        clock: () => now,
        failureBackoff: const Duration(minutes: 5),
      );

      await expectLater(signer.signedQuery(<String, String>{'keyword': 'a'}), throwsA(anything));
      now = now.add(const Duration(seconds: 30));
      await expectLater(signer.signedQuery(<String, String>{'keyword': 'b'}), throwsA(isA<StateError>()));
      expect(transport.navRequests, 1, reason: 'an outage must not become a retry storm against nav');

      now = now.add(const Duration(minutes: 5));
      transport.bodies.add(_navBody());
      expect(await signer.signedQuery(<String, String>{'keyword': 'c'}), contains('w_rid='));
      expect(transport.navRequests, 2);
    });

    test('test_signedQuery_refusesAnAnswerWithoutWbiKeys', () async {
      final transport = _RecordingTransport(<String>['{"code":0,"data":{}}']);
      final signer = BiliWbiSigner(
        client: NetworkClient(adapter: transport),
        clock: () => DateTime.utc(2026),
      );

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

/// Answers nav from a script of bodies, counting the requests so caching is observable.
final class _RecordingTransport implements HttpClientAdapter {
  _RecordingTransport(this.bodies);

  final List<String> bodies;
  int navRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!options.uri.path.endsWith('/web-interface/nav')) {
      throw StateError('the signer asked something other than nav: ${options.uri}');
    }
    final index = navRequests.clamp(0, bodies.length - 1);
    navRequests++;
    return ResponseBody.fromString(
      bodies[index],
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
