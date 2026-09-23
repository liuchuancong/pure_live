import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/kilakila/kilakila_api.dart';

const _rid = '9007199254740993123';
const _flv = 'https://pull.live.hongrenshuo.com.cn/hrs/$_rid.flv?auth_key=fixture%2Bonly&extra=one%2Ftwo';
const _hls = 'https://pull.live.hongrenshuo.com.cn/hrs/$_rid.m3u8?auth_key=fixture%2Bonly';
Map<String, dynamic> _owner() => {
  'id': 100,
  'nickname': 'Fixture',
  'headPortraitUrl': 'https://img.example/avatar.png',
};
Map<String, dynamic> _info() => {
  'roomIdStr': _rid,
  'uid': 100,
  'userInfo': _owner(),
  'title': 'Music',
  'status': 4,
  'goldPrice': 0,
  'watchNumber': 9,
  'likeCount': 9000,
  'diamonds': 99999,
  'defaultBackgroundPicUrl': 'https://img.example/cover.png',
  'flvPlayUrl': _flv,
  'hlsPlayUrl': _hls,
  'pushFlow': 'rtmp://push.example/SECRET_NOT_A_PLAY_URL',
};
Map<String, dynamic> _row({String rid = _rid}) => {
  'dataType': 8,
  'roomResq': _info()..['roomIdStr'] = rid,
  'userResp': _owner(),
};
Map<String, dynamic> _body(Object? b, {int code = 200}) => {
  'h': {'code': code, 'success': code == 200},
  'b': b,
};
({int status, String body}) _ok(Object? b, {bool wrapped = false, int code = 200}) {
  final envelope = _body(b, code: code);
  return (
    status: 200,
    body: jsonEncode(
      wrapped
          ? {
              'code': 200,
              'data': {'body': envelope},
            }
          : envelope,
    ),
  );
}

({int status, String body}) _page({List<Object>? rows, int page = 1, int size = 10, Object last = false}) => _ok({
  'pageNo': page,
  'pageSize': size,
  'isLastPage': last,
  'data': rows ?? [_row()],
}, wrapped: true);
Matcher _failure(KilakilaFailure kind) => throwsA(isA<KilakilaException>().having((e) => e.kind, 'kind', kind));

void main() {
  test('official user search parses stable profile IDs and safely encodes page paths', () async {
    final calls = <Uri>[];
    final api = KilakilaApi(
      request: (uri, _) async {
        calls.add(uri);
        return (
          status: 200,
          body:
              '<html><div class="userList">'
              '<a href="/zhubo/100"><div class="anchor-name">音乐主播</div>'
              '<div class="anchorHeaderImg"><img src="https://img.example/avatar.png"></div></a>'
              '<a href="/zhubo/100"><div class="anchor-name">音乐主播</div></a>'
              '<a href="/zhubo/101"><div class="anchor-name">音乐电台</div></a>'
              '</div></html>',
        );
      },
    );
    final owners = await api.searchOwners(' 音乐/ASMR ', page: 2);
    expect(calls.single.pathSegments, ['aboutus', 'serach', 'kw', '音乐/ASMR', 'p', '2']);
    expect(owners.map((owner) => owner.userId), ['100', '101']);
    expect(owners.first.nick, '音乐主播');
    expect(owners.first.avatar, 'https://img.example/avatar.png');
    expect(owners.first.currentRoom, isNull);
    expect(() => owners.add(owners.first), throwsUnsupportedError);
  });

  test('empty user search differs from malformed profile markup and cancellation', () async {
    final empty = KilakilaApi(request: (_, _) async => (status: 200, body: '<div class="userList"></div>'));
    expect(await empty.searchOwners('missing'), isEmpty);
    final malformed = KilakilaApi(
      request: (_, _) async =>
          (status: 200, body: '<div class="userList"><a href="https://evil.test/zhubo/1">x</a></div>'),
    );
    await expectLater(malformed.searchOwners('keyword'), _failure(KilakilaFailure.schema));
    final cancelled = KilakilaApi(request: (_, _) async => throw StateError('unexpected request'));
    await expectLater(
      cancelled.searchOwners('keyword', cancel: CancelToken()..cancel('fixture')),
      _failure(KilakilaFailure.cancelled),
    );
  });
  test('numeric room links preserve large string IDs, not owner IDs or opaque payloads', () {
    for (final host in ['live.kilakila.cn', 'www.hongdoufm.com']) {
      expect(KilakilaApi.numericRoomFromUri(Uri.parse('https://$host/room/$_rid')), _rid);
      expect(KilakilaApi.numericRoomFromUri(Uri.parse('https://$host/PcLive/index/detail?id=$_rid')), _rid);
    }
    for (final value in [
      'https://live.kilakila.cn.evil.test/room/$_rid',
      'https://x@live.kilakila.cn/room/$_rid',
      'https://live.kilakila.cn:8787/room/$_rid',
      'file:///room/$_rid',
      'https://live.kilakila.cn/room/$_rid/extra',
      'https://live.kilakila.cn/room/$_rid?id=100',
      'https://live.kilakila.cn/room/OPAQUE==',
      'https://live.kilakila.cn/room/%FF',
      'https://live.kilakila.cn/room/$_rid#other',
      'https://live.kilakila.cn/PcLive/index/detail?id=$_rid&id=100',
      'https://live.kilakila.cn/PcLive/index/detail?id=$_rid&_specific_parameter=opaque',
      'https://live.kilakila.cn/PcLive/index/detail?_specific_parameter=opaque',
      'https://live.kilakila.cn/PcLive/index/detail/$_rid',
      'https://live.kilakila.cn/room/0',
      'https://live.kilakila.cn/room/001',
    ]) {
      expect(KilakilaApi.numericRoomFromUri(Uri.parse(value)), isNull, reason: value);
    }
  });

  test('timeline unwraps its own envelope, retains server paging, and deduplicates room identity', () async {
    final api = KilakilaApi(
      request: (uri, _) async {
        expect(uri.host, 'live.kilakila.cn');
        expect(uri.path, '/pcLive/timeline');
        expect(uri.queryParameters, {'tag': '0', 'type': '107', 'genderType': '0', 'pageNo': '2', 'pageSize': '12'});
        return _page(
          page: 2,
          size: 12,
          rows: [
            _row(),
            _row(),
            {'dataType': 9},
            _row(rid: '123'),
          ],
        );
      },
    );
    final page = await api.directory(page: 2, pageSize: 12, type: 107);
    expect(page.rooms.map((r) => r.roomId), [_rid, '123']);
    expect(page.rooms.every((r) => r.userId == '100'), isTrue);
    expect(page.hasMore, isTrue);
    expect(page.page, 2);
    expect(page.rooms.first.watchNumber, 9);
    expect(page.rooms.first.media, isEmpty);
    expect(() => page.rooms.clear(), throwsUnsupportedError);
  });

  test('empty and filtered pages still obey isLastPage instead of length', () async {
    for (final last in [true, false]) {
      final api = KilakilaApi(
        request: (_, _) async => _page(
          rows: [
            {'dataType': 7},
          ],
          last: last,
        ),
      );
      final page = await api.directory();
      expect(page.rooms, isEmpty);
      expect(page.hasMore, !last);
    }
  });

  test('mismatched page echoes and malformed terminal state do not publish a false end', () async {
    for (final response in [_page(page: 2), _page(size: 20), _page(last: 'false'), _ok(null, wrapped: true)]) {
      final api = KilakilaApi(request: (_, _) async => response);
      await expectLater(api.directory(), _failure(KilakilaFailure.schema));
    }
  });

  test('invalid caller paging and category types fail before network access', () async {
    final api = KilakilaApi(request: (_, _) async => throw StateError('unexpected network'));
    for (final request in [
      () => api.directory(page: 0),
      () => api.directory(page: 100001),
      () => api.directory(pageSize: 0),
      () => api.directory(pageSize: 101),
      () => api.directory(type: 1),
    ]) {
      await expectLater(request(), _failure(KilakilaFailure.schema));
    }
  });

  test('successful missing recommendation body is optional but not a room/offline response', () async {
    final api = KilakilaApi(
      request: (uri, _) async {
        expect(uri.path, '/pcLive/recommend');
        return (
          status: 200,
          body: jsonEncode({
            'code': 200,
            'data': {
              'body': {
                'h': {'code': 200, 'success': true},
              },
            },
          }),
        );
      },
    );
    final rows = await api.recommendations();
    expect(rows, isEmpty);
    expect(() => rows.clear(), throwsUnsupportedError);
    await expectLater(KilakilaApi(request: (_, _) async => _ok(null)).detail(_rid), _failure(KilakilaFailure.schema));
  });

  test('metadata uses distinct owner and room IDs and discards all raw playback/push fields', () async {
    final api = KilakilaApi(
      request: (uri, _) async {
        expect(uri.path, '/LiveRoom/getRoomInfo');
        expect(uri.queryParameters, {'roomId': _rid});
        return _ok(_info());
      },
    );
    final room = await api.detail(_rid, playback: false, expectedUserId: '100');
    expect(room.roomId, _rid);
    expect(room.userId, '100');
    expect(room.nick, 'Fixture');
    expect(room.title, 'Music');
    expect(room.cover, 'https://img.example/cover.png');
    expect(room.media, isEmpty);
    expect(room.watchNumber, 9);
    expect(room.isLive, isTrue);
    expect(room.link, '${KilakilaApi.origin}/room/$_rid');
  });

  test('playback uses only matching returned pull URLs and stable protocol IDs', () async {
    final room = await KilakilaApi(request: (_, _) async => _ok(_info())).detail(_rid);
    expect(room.media, {'flv': _flv, 'hls': _hls});
    expect(() => room.media['rtmp'] = 'other', throwsUnsupportedError);
    expect(KilakilaApi.playHeaders, {'Referer': 'https://live.kilakila.cn/', 'User-Agent': 'Mozilla/5.0'});
  });

  test('each detail lookup reacquires current media and preserves the query verbatim', () async {
    var calls = 0;
    final api = KilakilaApi(
      request: (_, _) async {
        calls++;
        return _ok(_info()..['flvPlayUrl'] = '$_flv&generation=$calls');
      },
    );
    final first = await api.detail(_rid);
    final second = await api.detail(_rid);
    expect(first.media['flv'], '$_flv&generation=1');
    expect(second.media['flv'], '$_flv&generation=2');
    expect(calls, 2);
  });

  test('missing FLV does not hide a valid independently returned HLS URL', () async {
    final room = await KilakilaApi(request: (_, _) async => _ok(_info()..remove('flvPlayUrl'))).detail(_rid);
    expect(room.media, {'hls': _hls});
  });

  test('push-only, wrong-room and wrong-host media are not converted into playable URLs', () async {
    for (final data in [
      _info()
        ..remove('flvPlayUrl')
        ..remove('hlsPlayUrl'),
      _info()
        ..['flvPlayUrl'] = _flv.replaceAll(_rid, '123')
        ..['hlsPlayUrl'] = '',
      _info()
        ..['flvPlayUrl'] = 'https://pull.live.hongrenshuo.com.cn.evil.test/hrs/$_rid.flv'
        ..['hlsPlayUrl'] = null,
    ]) {
      await expectLater(
        KilakilaApi(request: (_, _) async => _ok(data)).detail(_rid),
        _failure(KilakilaFailure.mediaUnavailable),
      );
    }
  });

  test('media validation rejects duplicate auth, unsafe ports, credentials, fragments and malformed encodings', () {
    for (final value in [
      '$_flv&auth_key=second',
      _flv.replaceFirst('https:', 'http:'),
      _flv.replaceFirst('https://', 'https://user@'),
      _flv.replaceFirst('.cn/', '.cn:8787/'),
      '$_flv#tail',
      _flv.split('?').first,
      '${_flv.split('?').first}?auth_key=',
      '${_flv.split('?').first}?auth_key=%FF',
      'rtmp://push.example/SECRET_NOT_A_PLAY_URL',
    ]) {
      expect(KilakilaApi.mediaUrl(value, roomId: _rid, protocol: 'flv'), isNull);
    }
    expect(KilakilaApi.mediaUrl(_flv, roomId: _rid, protocol: 'rtmp'), isNull);
  });

  test('paid live room metadata remains inspectable but no media is handed to playback', () async {
    final api = KilakilaApi(request: (_, _) async => _ok(_info()..['goldPrice'] = 10));
    final metadata = await api.detail(_rid, playback: false);
    expect(metadata.isLive, isTrue);
    expect(metadata.goldPrice, 10);
    expect(metadata.media, isEmpty);
    await expectLater(api.detail(_rid), _failure(KilakilaFailure.restricted));
  });

  test('unverified status stays raw metadata, not an invented offline or replay classification', () async {
    final api = KilakilaApi(request: (_, _) async => _ok(_info()..['status'] = 5));
    final metadata = await api.detail(_rid, playback: false);
    expect(metadata.statusCode, 5);
    expect(metadata.isLive, isFalse);
    await expectLater(api.detail(_rid), _failure(KilakilaFailure.stateUnsupported));
  });

  test('business 5966 is historical replay only at the exact room endpoint', () async {
    final api = KilakilaApi(request: (_, _) async => _ok({'userInfo': _owner()}, code: 5966));
    await expectLater(api.detail(_rid), _failure(KilakilaFailure.historicalReplay));
    await expectLater(
      KilakilaApi(request: (_, _) async => _ok(null, wrapped: true, code: 5966)).directory(),
      _failure(KilakilaFailure.service),
    );
  });

  test('owner business 1013 is missing identity, while other business errors remain service failures', () async {
    for (final code in [1013, 1]) {
      final api = KilakilaApi(
        request: (uri, _) async {
          expect(uri.host, 'live.hongrenshuo.com.cn');
          expect(uri.path, '/Tg/personalH5');
          expect(uri.queryParameters['uid'], '100');
          return (status: 200, body: jsonEncode({'code': code, 'msg': 'fixture', 'data': null}));
        },
      );
      await expectLater(api.owner('100'), _failure(code == 1013 ? KilakilaFailure.notFound : KilakilaFailure.service));
    }
  });

  for (final entry in {
    401: KilakilaFailure.access,
    403: KilakilaFailure.access,
    404: KilakilaFailure.notFound,
    429: KilakilaFailure.rateLimited,
    503: KilakilaFailure.service,
    302: KilakilaFailure.transport,
  }.entries) {
    test('HTTP ${entry.key} has its own failure and is not an offline room', () async {
      final api = KilakilaApi(request: (_, _) async => (status: entry.key, body: 'untrusted SECRET response'));
      await expectLater(api.detail(_rid), _failure(entry.value));
    });
  }

  test('room and owner identity mismatch fails even with plausible URLs', () async {
    for (final data in [
      _info()..['roomIdStr'] = '123',
      _info()..['uid'] = 101,
      _info()..['userInfo'] = (_owner()..['id'] = 101),
    ]) {
      await expectLater(KilakilaApi(request: (_, _) async => _ok(data)).detail(_rid), _failure(KilakilaFailure.schema));
    }
    await expectLater(
      KilakilaApi(request: (_, _) async => _ok(_info())).detail(_rid, expectedUserId: '101'),
      _failure(KilakilaFailure.schema),
    );
  });

  test(
    'large numeric IDs, float IDs, missing price and malformed identity never silently round or become free',
    () async {
      for (final data in [
        _info()..['roomIdStr'] = 9007199254740993123,
        _info()..['roomIdStr'] = 9007199254740992.0,
        _info()..['uid'] = true,
        _info()..remove('goldPrice'),
        _info()..['goldPrice'] = -1,
        _info()..['goldPrice'] = 0.0,
        _info()..['status'] = true,
      ]) {
        await expectLater(
          KilakilaApi(request: (_, _) async => _ok(data)).detail(_rid),
          _failure(KilakilaFailure.schema),
        );
      }
    },
  );

  test('bad optional pictures/counts remain empty or unknown rather than borrowing another metric', () async {
    final data = _info()
      ..['watchNumber'] = -1
      ..['defaultBackgroundPicUrl'] = 'javascript:bad'
      ..['userInfo'] = (_owner()..['headPortraitUrl'] = 'https://user@img.example/a');
    final room = await KilakilaApi(request: (_, _) async => _ok(data)).detail(_rid);
    expect(room.watchNumber, isNull);
    expect(room.cover, isEmpty);
    expect(room.avatar, isEmpty);
  });

  test('malformed envelope, success disagreement and unknown business failure are explicit', () async {
    for (final value in [
      [],
      {'h': {}},
      {
        'h': {'code': 200, 'success': false},
        'b': _info(),
      },
      {
        'h': {'code': true, 'success': true},
      },
    ]) {
      await expectLater(
        KilakilaApi(request: (_, _) async => (status: 200, body: jsonEncode(value))).detail(_rid),
        _failure(KilakilaFailure.schema),
      );
    }
    await expectLater(
      KilakilaApi(request: (_, _) async => _ok(null, code: 9999)).detail(_rid),
      _failure(KilakilaFailure.service),
    );
  });

  test('UTF8 response cap applies even when the character count is below the byte limit', () async {
    final data = _info()..['title'] = List.filled(400000, '中').join();
    await expectLater(KilakilaApi(request: (_, _) async => _ok(data)).detail(_rid), _failure(KilakilaFailure.schema));
  });

  test('directory row bounds and schema errors never turn into a successful empty directory', () async {
    for (final rows in [
      List<Object>.filled(1001, {'dataType': 9}),
      <Object>[{}],
      <Object>[_row()..['userResp'] = {}],
    ]) {
      await expectLater(
        KilakilaApi(request: (_, _) async => _page(rows: rows)).directory(),
        _failure(KilakilaFailure.schema),
      );
    }
  });

  test('caller cancellation before or after a response suppresses publication', () async {
    var calls = 0;
    final token = CancelToken()..cancel('fixture');
    final api = KilakilaApi(
      request: (_, _) async {
        calls++;
        return _ok(_info());
      },
    );
    await expectLater(api.detail(_rid, cancel: token), _failure(KilakilaFailure.cancelled));
    expect(calls, 0);
    final lateToken = CancelToken();
    final lateApi = KilakilaApi(
      request: (_, passed) async {
        expect(identical(passed, lateToken), isTrue);
        lateToken.cancel('late fixture');
        return _ok(_info());
      },
    );
    await expectLater(lateApi.detail(_rid, cancel: lateToken), _failure(KilakilaFailure.cancelled));
  });

  test('transport exceptions are sanitized instead of including raw URLs or account data', () async {
    try {
      await KilakilaApi(request: (_, _) async => throw StateError('SECRET_COOKIE $_flv')).detail(_rid);
      fail('Expected transport failure');
    } on KilakilaException catch (error) {
      expect(error.kind, KilakilaFailure.transport);
      expect(error.toString(), 'Kilakila transport');
    }
  });

  test('response reader keeps split UTF8 and closes a completed stream', () async {
    final bytes = utf8.encode('中');
    expect(await KilakilaApi.readBody(Stream.fromIterable([bytes.sublist(0, 1), bytes.sublist(1)])), '中');
  });

  test('response reader bounds bytes and cancels the source on overflow', () async {
    var cancelled = false;
    final stream = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
      },
    );
    final future = KilakilaApi.readBody(stream.stream);
    stream.add(List.filled(KilakilaApi.responseLimit + 1, 0));
    await expectLater(future, _failure(KilakilaFailure.schema));
    expect(cancelled, isTrue);
    await stream.close();
  });

  test('response deadline cancels a stalled stream, not just a single read retry', () async {
    var cancelled = false;
    final stream = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
      },
    );
    final future = KilakilaApi.readBody(stream.stream, timeout: const Duration(milliseconds: 30));
    await expectLater(future, throwsA(isA<TimeoutException>()));
    expect(cancelled, isTrue);
    await stream.close();
  });

  test('invalid UTF8 is a schema error rather than replacement-character identity', () async {
    await expectLater(KilakilaApi.readBody(Stream.value([0xff])), _failure(KilakilaFailure.schema));
  });
}
