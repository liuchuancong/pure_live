import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/kilakila/kilakila_api.dart';
import 'package:pure_live/core/site/kilakila/kilakila_link.dart';

void main() {
  final vectors = (jsonDecode(File('test/fixtures/kilakila/share-vectors.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  for (final vector in vectors) {
    test('independent fixture: ${vector['name']}', () {
      final link = KilakilaLink.parse(vector['url'] as String);
      if (vector['valid'] == true) {
        expect(link, isNotNull);
        expect(link!.id, vector['id']);
        expect(link.kind.name, vector['kind']);
      } else {
        expect(link, isNull);
      }
    });
  }

  test('plain numeric links preserve owner versus broadcast identity', () {
    for (final host in ['live.kilakila.cn', 'www.hongdoufm.com']) {
      for (final scheme in ['http', 'https']) {
        expect(KilakilaLink.parse('$scheme://$host/room/123')!.id, '123');
        expect(KilakilaLink.parse('$scheme://$host/PcLive/index/detail?id=123')!.kind, KilakilaLinkKind.broadcast);
      }
    }
    final owner = KilakilaLink.parse('https://live.hongrenshuo.com.cn/index/roomuser/uid/123')!;
    expect(owner.id, '123');
    expect(owner.kind, KilakilaLinkKind.owner);
    final publicProfile = KilakilaLink.parse('https://live.kilakila.cn/zhubo/123')!;
    expect(publicProfile.id, '123');
    expect(publicProfile.kind, KilakilaLinkKind.owner);
  });

  for (final url in [
    'https://live.kilakila.cn.evil.test/room/123',
    'https://user@live.kilakila.cn/room/123',
    'https://live.kilakila.cn:8787/room/123',
    'file:///room/123',
    'https://live.kilakila.cn/room/123#',
    'https://live.kilakila.cn/room/123/extra',
    'https://live.kilakila.cn/%72oom/123',
    'https://live.kilakila.cn/room/0',
    'https://live.kilakila.cn/room/00123',
    'https://live.kilakila.cn/room/123?id=456',
    'https://live.kilakila.cn/room/123?_specific_parameter=bad',
    'https://live.kilakila.cn/PcLive/index/detail?id=123&id=456',
    'https://live.kilakila.cn/PcLive/index/detail?id=123&_specific_parameter=bad',
    'https://live.kilakila.cn/PcLive/index/detail?_specific_parameter=bad&sign=bad',
    'https://live.kilakila.cn/PcLive/index/detail?_specific_parameter=bad&_specific_parameter=bad',
    'https://live.kilakila.cn/PcLive/index/detail?_specific_parameter=%FF',
    'https://live.kilakila.cn/PcLive/index/detail?_specific_parameter=%GG',
    'https://live.kilakila.cn/PcLive/index/detail?_specific_parameter=',
    'https://live.kilakila.cn/index/roomuser/uid/123',
    'https://live.hongrenshuo.com.cn/room/123',
    'https://live.hongrenshuo.com.cn/index/roomuser/uid/123?uid=456',
    'https://live.kilakila.cn/room/123 456',
    'https://live.kilakila.cn/zhubo/123?uid=456',
    'https://live.kilakila.cn/zhubo/123/extra',
    'https://live.kilakila.cn/%7Ahubo/123',
    'https://live.kilakila.cn/zhubo/00123',
  ]) {
    test('reject malformed or ambiguous URL: $url', () => expect(KilakilaLink.parse(url), isNull));
  }

  test('raw, escaped and unpadded URL-safe query payloads agree', () {
    final url = vectors.first['url'] as String;
    final payload = Uri.parse(url).queryParameters['_specific_parameter']!;
    final prefix = 'https://live.kilakila.cn/PcLive/index/detail?_specific_parameter=';
    for (final encoded in [payload, payload.replaceAll('=', ''), Uri.encodeQueryComponent(payload)]) {
      expect(KilakilaLink.parse('$prefix$encoded')!.id, vectors.first['id']);
    }
    final standard = payload.replaceAll('-', '+').replaceAll('_', '/');
    expect(KilakilaLink.parse('$prefix${Uri.encodeQueryComponent(standard)}')!.id, vectors.first['id']);
  });
  test('tracking query does not replace the signed ID', () {
    final url = vectors.first['url'] as String;
    expect(KilakilaLink.parse('$url&from=share')!.id, vectors.first['id']);
    expect(KilakilaLink.parse('$url&id=123'), isNull);
  });
  test('signature binds exact scheme and detail path', () {
    final url = vectors.first['url'] as String;
    expect(KilakilaLink.parse(url.replaceFirst('https:', 'http:')), isNull);
    expect(KilakilaLink.parse(url.replaceFirst('/detail?', '/detail/?')), isNull);
    expect(KilakilaLink.parse(url.replaceFirst('/PcLive/', '/%50cLive/')), isNull);
    final pathUrl = vectors.firstWhere((v) => v['name'] == 'new-live.kilakila.cn-room')['url'] as String;
    expect(KilakilaLink.parse(pathUrl.replaceFirst('/room/', '/%72oom/')), isNull);
  });
  test('bounded arbitrary ciphertext fails without throwing or resolving an ID', () {
    for (var i = 0; i < 256; i++) {
      final data = List.generate(32, (index) => (i + index) % 256);
      expect(KilakilaLink.parse('https://live.kilakila.cn/room/${base64Url.encode(data)}'), isNull);
    }
    expect(KilakilaLink.parse('https://live.kilakila.cn/room/${'a' * 9000}'), isNull);
    expect(KilakilaLink.parse('https://live.kilakila.cn/room/${'a' * 4097}'), isNull);
  });

  Map<String, dynamic> profile() => {
    'code': 200,
    'data': {
      'userResp': {'nickname': 'Fixture'},
      'liveCard': <String, dynamic>{},
    },
  };
  Map<String, dynamic> detail(String id) => {
    'h': {'code': 200, 'success': true},
    'b': {
      'roomIdStr': id,
      'uid': 100,
      'userInfo': {'id': 100, 'nickname': 'Fixture'},
      'title': 'Fixture broadcast',
      'status': 4,
      'goldPrice': 0,
    },
  };
  test('signed broadcast resolves metadata first and returns an anchor identity', () async {
    final paths = <Uri>[];
    final api = KilakilaApi(
      request: (uri, _) async {
        paths.add(uri);
        return (
          status: 200,
          body: jsonEncode(uri.path == '/LiveRoom/getRoomInfo' ? detail(uri.queryParameters['roomId']!) : profile()),
        );
      },
    );
    final owner = await api.ownerFromLink(vectors.first['url'] as String);
    expect(owner.userId, '100');
    expect(paths.map((u) => u.path), ['/LiveRoom/getRoomInfo', '/Tg/personalH5']);
    expect(paths.last.queryParameters, {'uid': '100'});
  });
  test('numeric owner bypasses single-broadcast resolution', () async {
    final api = KilakilaApi(
      request: (uri, _) async {
        expect(uri.path, '/Tg/personalH5');
        expect(uri.queryParameters, {'uid': '100'});
        return (status: 200, body: jsonEncode(profile()));
      },
    );
    expect((await api.ownerFromLink('https://live.hongrenshuo.com.cn/index/roomuser/uid/100')).userId, '100');
  });
  test('historical broadcast error is not promoted to guessed UID or offline', () async {
    final api = KilakilaApi(
      request: (uri, _) async {
        expect(uri.path, '/LiveRoom/getRoomInfo');
        return (
          status: 200,
          body: jsonEncode({
            'h': {'code': 5966, 'success': false},
          }),
        );
      },
    );
    await expectLater(
      api.ownerFromLink(vectors.first['url'] as String),
      throwsA(isA<KilakilaException>().having((e) => e.kind, 'kind', KilakilaFailure.historicalReplay)),
    );
  });
  test('invalid signed link makes no HTTP request', () async {
    final api = KilakilaApi(
      request: (_, _) async {
        fail('Unexpected network request');
      },
    );
    await expectLater(api.ownerFromLink(vectors[1]['url'] as String), throwsA(isA<KilakilaException>()));
  });
}
