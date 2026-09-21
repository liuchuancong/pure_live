import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/bigo/bigo_api.dart';
import 'package:pure_live/core/site/bigo/bigo_hls_protection.dart';
import 'package:pure_live/core/site/bigo/bigo_token.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/bigo/$name.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('web token codec matches OpenSSL salted AES-256-CBC fixture', () {
    final encoded = BigoTokenCodec.buildData(
      '1723456789',
      salt: Uint8List.fromList(const [0, 1, 2, 3, 4, 5, 6, 7]),
      randomHex: '0123456789abcdef0123456789abcdef',
    );
    expect(
      encoded,
      'U2FsdGVkX18AAQIDBAUGBw9CExflNpp/+hw4FEvQ48pkY9f2hYxzYBNOjHbCB45L1kMM+njoY+ywzq8/nIukZdvMK///nfADHW0eTrVT7LFdOBDiydMHD1bQXb8LIIH6FSRtElvqM7EhdCvLpZW9RzGf9qNU4yDT2LciUoRF/Dz6pDiEIxTYPaEri+1At/i8',
    );
    expect(() => BigoTokenCodec.buildData('bad'), throwsFormatException);
    expect(
      () => BigoTokenCodec.buildData('1723456789', salt: Uint8List(7), randomHex: '0123456789abcdef0123456789abcdef'),
      throwsFormatException,
    );
  });

  test('protected HLS seed and first two TS packet masks match the browser codec', () {
    const seed = 1234567890;
    expect(BigoHlsProtection.seedFromManifest('#EXTM3U\n#EXT-X-BIGO-WEB-PROTECTION:SEED=$seed\n'), seed);
    expect(BigoHlsProtection.seedFromManifest('#EXTM3U\n'), isNull);
    final plain = Uint8List(376)
      ..[0] = 0x47
      ..[188] = 0x47;
    final encrypted = BigoHlsProtection.transformSegment(plain, seed);
    expect(encrypted.sublist(0, 16), [234, 135, 48, 195, 159, 46, 166, 121, 202, 86, 133, 106, 116, 255, 43, 34]);
    expect(encrypted.sublist(188, 204), [193, 228, 20, 96, 237, 165, 183, 210, 218, 210, 88, 211, 198, 10, 131, 204]);
    final decrypted = BigoHlsProtection.transformSegment(encrypted, seed);
    expect(decrypted, plain);
    expect(() => BigoHlsProtection.transformSegment(Uint8List(375), seed), throwsFormatException);
    expect(
      () => BigoHlsProtection.seedFromManifest('#EXT-X-BIGO-WEB-PROTECTION:SEED=999999999999999999999'),
      throwsFormatException,
    );
  });

  test('authenticated studio flow keeps token in query and returns verified public media', () async {
    final invalidCallbacks = ['jsonpcallback_time'].iterator;
    final calls = <({String method, Uri uri, Map<String, String>? form})>[];
    final studio = _fixture('studio-login');
    studio['data'] = <String, dynamic>{
      ...(studio['data'] as Map<String, dynamic>),
      'needLogin': false,
      'alive': 1,
      'roomId': '7000000000000000001',
      'nick_name': 'Fixture owner',
      'roomTopic': 'Fixture live',
      'gameTitle': 'Music',
      'avatar': 'https://image.example/avatar.jpg',
      'hls_src': 'https://media.example:1453/live/fixture.m3u8?token=redacted',
    };
    final api = BigoApi(
      callbackFactory: () {
        expect(invalidCallbacks.moveNext(), isTrue);
        return invalidCallbacks.current;
      },
      tokenDataBuilder: (timestamp) {
        expect(timestamp, '1723456789');
        return 'fixture-ciphertext';
      },
      request: (method, uri, form, _) async {
        calls.add((method: method, uri: uri, form: form));
        if (uri.path.endsWith('/t')) {
          return (status: 200, body: 'jsonpCallback_wrong({});');
        }
        throw StateError('unreached');
      },
    );
    await expectLater(
      api.studioRoom(siteId: 'fixture_101', expectedOwnerId: 101),
      throwsA(isA<BigoException>().having((error) => error.kind, 'kind', BigoFailure.schema)),
    );
    expect(calls, hasLength(1));

    final callbacks = ['jsonpcallback_time', 'jsonpcallback_status'].iterator;
    final successful = BigoApi(
      callbackFactory: () {
        expect(callbacks.moveNext(), isTrue);
        return callbacks.current;
      },
      tokenDataBuilder: (timestamp) {
        expect(timestamp, '1723456789');
        return 'fixture-ciphertext';
      },
      request: (method, uri, form, _) async {
        calls.add((method: method, uri: uri, form: form));
        if (uri.path.endsWith('/t')) {
          return (status: 200, body: '${uri.queryParameters['callback']}({"code":0,"time":"1723456789"});');
        }
        if (uri.path.endsWith('/status')) {
          expect(uri.queryParameters['data'], 'fixture-ciphertext');
          return (status: 200, body: '${uri.queryParameters['callback']}({"token":"fixture-token"});');
        }
        expect(method, 'POST');
        expect(form, isNull);
        expect(uri.queryParameters, {'siteId': 'fixture_101', 'verify': '', 'token': 'fixture-token'});
        return (status: 200, body: jsonEncode(studio));
      },
    );
    final room = await successful.studioRoom(siteId: 'fixture_101', expectedOwnerId: 101);
    expect(room.status.access, BigoAccess.public);
    expect(room.status.reportedAlive, isTrue);
    expect(room.roomId, '7000000000000000001');
    expect(room.nickname, 'Fixture owner');
    expect(room.title, 'Fixture live');
    expect(room.category, 'Music');
    expect(room.hls.toString(), 'https://media.example:1453/live/fixture.m3u8?token=redacted');
  });

  test('studio media parser preserves gated and offline absence without a fake URL', () {
    final gated = BigoApi.parseStudioRoom(_fixture('studio-login'), siteId: 'fixture_101', expectedOwnerId: 101);
    expect(gated.status.access, BigoAccess.loginRequired);
    expect(gated.status.reportedAlive, isNull);
    expect(gated.hls, isNull);
    expect(gated.roomId, isNull);

    final conflicting = _fixture('studio-login');
    conflicting['data']['hls_src'] = 'https://media.example/live/fixture.m3u8';
    expect(
      () => BigoApi.parseStudioRoom(conflicting, siteId: 'fixture_101', expectedOwnerId: 101),
      throwsA(isA<BigoException>().having((error) => error.kind, 'kind', BigoFailure.schema)),
    );
  });
}
