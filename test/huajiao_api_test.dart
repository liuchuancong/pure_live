import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/common/http_client.dart' as shared;
import 'package:pure_live/core/site/huajiao/huajiao_api.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/huajiao/$name.json').readAsStringSync()) as Map<String, dynamic>;
Map<String, dynamic> _broadcast() => _fixture('broadcast')['data'] as Map<String, dynamic>;
Map<String, dynamic> _row() {
  final row = _broadcast()['feed'] as Map<String, dynamic>;
  row['feed']['title'] = 'Fixture title';
  return row;
}

Map<String, dynamic> _owner({Object? living = 200}) => {
  'base': {'uid': 100, 'nickname': 'Fixture owner', 'avatar': 'https://img.huajiao.com/avatar.jpg'},
  'living': living,
  'counter': {'followers': 9000, 'praises': 8000},
};
Map<String, dynamic> _page({List<Object?>? rows, Object offset = '30', Object more = true}) => {
  'sections': [
    {
      'feeds': rows ?? [_row()],
    },
  ],
  'feeds': <Object>[],
  'offset': offset,
  'more': more,
};
({int status, String body}) _ok(Object? data) => (status: 200, body: jsonEncode({'errno': 0, 'data': data}));
HuajiaoApi _api(Object? data) => HuajiaoApi(request: (_, _) async => _ok(data));
Matcher _failure(HuajiaoFailure kind) => throwsA(isA<HuajiaoException>().having((e) => e.kind, 'kind', kind));

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      respond(options);
  @override
  void close({bool force = false}) {}
}

void main() {
  test('captured directory retains public rows with geographic point objects', () async {
    final page = await _api(_fixture('directory')['data']).directory(limit: 6);
    expect(page.feeds.single.userId, '100');
    expect(page.feeds.single.liveId, '200');
    expect(page.feeds.single.heat, 2673);
    expect(page.nextOffset, 30);
    expect(page.hasMore, isTrue);
    expect(() => page.feeds.clear(), throwsUnsupportedError);
  });

  test('captured broadcast accepts an untitled live feed and preserves signed URLs', () async {
    final result = await _api(_broadcast()).broadcast('200', expectedUserId: '100');
    expect(result.feed.title, 'Fixture owner');
    expect(result.media.map((e) => e.format), ['hls', 'flv']);
    expect(result.media.first.url, _broadcast()['live']['main']);
    expect(result.media.last.url, contains('sign=fixture%2Bonly&ts=123'));
    expect(() => result.media.clear(), throwsUnsupportedError);
  });

  test('captured point-only missing broadcast is media unavailable, not offline', () async {
    await expectLater(
      _api(_fixture('missing-broadcast')['data']).broadcast('200'),
      _failure(HuajiaoFailure.mediaUnavailable),
    );
  });

  test('captured empty page advances server cursor and retains more=true', () async {
    final page = await _api(_fixture('empty-page')['data']).directory(offset: 30, limit: 6);
    expect(page.feeds, isEmpty);
    expect(page.nextOffset, 36);
    expect(page.hasMore, isTrue);
  });

  test('owner living is a broadcast ID and explicit zero is offline', () async {
    for (final living in [200, '200']) {
      final owner = await _api(_owner(living: living)).owner('100');
      expect(owner.liveId, '200');
      expect(owner.isLive, isTrue);
      expect(owner.userId, '100');
    }
    for (final living in [0, '0']) {
      var calls = 0;
      final room = await HuajiaoApi(
        request: (_, _) async {
          calls++;
          return _ok(_owner(living: living));
        },
      ).room('100');
      expect(room.owner.isLive, isFalse);
      expect(room.broadcast, isNull);
      expect(calls, 1);
    }
  });

  test('owner rejects unknown status and mismatched identity', () async {
    for (final living in [null, true, -1, 2.5, '', 'false']) {
      await expectLater(_api(_owner(living: living)).owner('100'), _failure(HuajiaoFailure.schema));
    }
    final data = _owner();
    data['base']['uid'] = 101;
    await expectLater(_api(data).owner('100'), _failure(HuajiaoFailure.identity));
  });

  test('anonymous empty-base sentinel is an unknown UID, not a malformed owner', () async {
    await expectLater(_api({'base': <Object>[], 'living': 0}).owner('100'), _failure(HuajiaoFailure.notFound));
    await expectLater(
      _api({
        'base': [<String, Object>{}],
        'living': 0,
      }).owner('100'),
      _failure(HuajiaoFailure.schema),
    );
  });

  test('invalid IDs and pagination bounds send no requests', () async {
    var calls = 0;
    final api = HuajiaoApi(
      request: (_, _) async {
        calls++;
        return _ok(null);
      },
    );
    for (final id in ['', '0', '-1', '1&uid=2', '1/2', '0001', '10000000000000000']) {
      await expectLater(api.owner(id), _failure(HuajiaoFailure.schema));
      await expectLater(api.broadcast(id), _failure(HuajiaoFailure.schema));
    }
    for (final limit in [0, 31]) {
      await expectLater(api.directory(limit: limit), _failure(HuajiaoFailure.schema));
    }
    for (final offset in [-1, 1000001]) {
      await expectLater(api.directory(offset: offset), _failure(HuajiaoFailure.schema));
    }
    expect(calls, 0);
  });

  test('room reacquires owner and media on every refresh without feed-history guessing', () async {
    var round = 0;
    final paths = <String>[];
    final api = HuajiaoApi(
      request: (uri, _) async {
        paths.add(uri.path);
        if (uri.path == '/Web/UserInfo/full') {
          round++;
          expect(uri.queryParameters, {'uid': '100', 'with_living': '1', 'with_counter': '1'});
          return _ok(_owner(living: 199 + round));
        }
        expect(uri.host, 'h.huajiao.com');
        expect(uri.queryParameters['liveid'], '${199 + round}');
        expect(uri.queryParameters['stype'], 'm3u8');
        final data = _broadcast();
        data['feed']['feed']['relateid'] = 199 + round;
        data['feed']['feed']['title'] = 'Fixture';
        return _ok(data);
      },
    );
    expect((await api.room('100')).broadcast!.feed.liveId, '200');
    expect((await api.room('100')).broadcast!.feed.liveId, '201');
    expect(paths, ['/Web/UserInfo/full', '/api/getFeedInfo', '/Web/UserInfo/full', '/api/getFeedInfo']);
  });

  test('directory uses native cursor, flattens sections and top-level feeds, deduplicates broadcasts', () async {
    final row2 = _row();
    row2['feed']['relateid'] = 201;
    final data = _page(rows: [_row(), _row()]);
    data['sections'].add({
      'feeds': [row2],
    });
    data['feeds'] = [row2];
    final api = HuajiaoApi(
      request: (uri, _) async {
        expect(uri.queryParameters, {'name': 'live5', 'num': '6', 'offset': '12'});
        return _ok(data);
      },
    );
    expect((await api.directory(offset: 12, limit: 6)).feeds.map((e) => e.liveId), ['200', '201']);
  });

  test('directory refuses nonadvancing or malformed cursors instead of retry loops', () async {
    for (final data in [
      _page(offset: '0'),
      _page(offset: '-1'),
      _page(offset: 'x'),
      _page(more: 1),
      _page(offset: 1000001),
    ]) {
      await expectLater(_api(data).directory(), _failure(HuajiaoFailure.schema));
    }
    final finalPage = await _api(_page(rows: [], offset: 0, more: false)).directory();
    expect(finalPage.hasMore, isFalse);
  });

  test('directory rejects broken sections and conflicting owner identities', () async {
    for (final data in [
      _page()..['sections'] = {},
      _page()..['feeds'] = null,
      _page()
        ..['sections'] = [
          {'feeds': {}},
        ],
      _page(rows: [null]),
    ]) {
      await expectLater(_api(data).directory(), _failure(HuajiaoFailure.schema));
    }
    final other = _row();
    other['author']['uid'] = 101;
    await expectLater(_api(_page(rows: [_row(), other])).directory(), _failure(HuajiaoFailure.identity));
  });

  test('closed, private, special and unknown-mode rows are excluded without declaring owner offline', () async {
    for (final change in [
      {'origin_status': 0},
      {'is_privacy': 'Y'},
      {'special_room': 1},
      {'mode': 'audio'},
      {'mode': null},
    ]) {
      final row = _row();
      row['feed'].addAll(change);
      expect((await _api(_page(rows: [row])).directory()).feeds, isEmpty);
      final data = _broadcast();
      data['feed'] = row;
      await expectLater(_api(data).broadcast('200'), _failure(HuajiaoFailure.restricted));
    }
    expect(
      (await _api(
        _page(
          rows: [
            {'type': 2},
          ],
        ),
      ).directory()).feeds,
      isEmpty,
    );
  });

  test('broadcast validates broadcast ID, owner ID and stream serial', () async {
    for (final field in ['broadcast', 'owner', 'sn']) {
      final data = _broadcast();
      data['feed']['feed']['title'] = 'Fixture';
      switch (field) {
        case 'broadcast':
          data['feed']['feed']['relateid'] = 201;
        case 'owner':
          data['feed']['author']['uid'] = 101;
        case 'sn':
          data['live']['sn'] = 'different';
      }
      await expectLater(_api(data).broadcast('200', expectedUserId: '100'), _failure(HuajiaoFailure.identity));
    }
  });

  test('missing media and media service errors stay separate from offline', () async {
    for (final live in [
      null,
      false,
      {'errcode': 1},
    ]) {
      final data = _broadcast();
      data['feed']['feed']['title'] = 'Fixture';
      data['live'] = live;
      await expectLater(_api(data).broadcast('200'), _failure(HuajiaoFailure.mediaUnavailable));
    }
  });

  test('URL field name and encode hint do not invent codec or container', () async {
    final data = _broadcast();
    data['feed']['feed']['title'] = 'Fixture';
    data['live']['main'] = 'https://live-pull-2.huajiao.com/stream?format=flv';
    data['live']['pull_m3u8'] = '';
    data['live']['h264_url'] = '';
    final media = (await _api(data).broadcast('200')).media.single;
    expect(media.format, 'unknown');
    expect(media.url, data['live']['main']);
  });

  test('media rejects unrelated hosts, userinfo and non-HTTP schemes', () async {
    for (final url in [
      'https://huajiao.com.evil.test/x.flv',
      'https://fakehuajiao.com/x.flv',
      'https://user@live.huajiao.com/x.flv',
      'file:///x.flv',
      'javascript:alert(1)',
      '//live.huajiao.com/x.flv',
    ]) {
      final data = _broadcast();
      data['feed']['feed']['title'] = 'Fixture';
      for (final key in ['main', 'h264_url', 'pull_m3u8']) {
        data['live'][key] = url;
      }
      await expectLater(_api(data).broadcast('200'), _failure(HuajiaoFailure.mediaUnavailable));
    }
  });

  test('invalid optional heat or image does not become invented viewer count or URL', () async {
    final row = _row();
    row['feed']['current_heat'] = -1;
    row['feed']['image'] = 'javascript:bad';
    final feed = (await _api(_page(rows: [row])).directory()).feeds.single;
    expect(feed.heat, isNull);
    expect(feed.cover, isEmpty);
  });

  for (final pair in [
    (401, HuajiaoFailure.access),
    (403, HuajiaoFailure.access),
    (429, HuajiaoFailure.rateLimited),
    (503, HuajiaoFailure.service),
    (302, HuajiaoFailure.transport),
  ]) {
    test('HTTP ${pair.$1} is ${pair.$2.name}, never offline', () async {
      await expectLater(
        HuajiaoApi(request: (_, _) async => (status: pair.$1, body: '')).room('100'),
        _failure(pair.$2),
      );
    });
  }

  test('legacy login requirement and other service errors are preserved without raw messages', () async {
    for (final pair in [(111, HuajiaoFailure.access), (1005, HuajiaoFailure.service)]) {
      await expectLater(
        HuajiaoApi(
          request: (_, _) async => (status: 200, body: jsonEncode({'errno': pair.$1, 'errmsg': 'secret fixture'})),
        ).room('100'),
        _failure(pair.$2),
      );
    }
  });

  test('malformed JSON envelopes and data are schema failures', () async {
    for (final body in ['<html>login</html>', '[]', '{}', '{"errno":true}', '{"errno":0,"data":[]}']) {
      await expectLater(
        HuajiaoApi(request: (_, _) async => (status: 200, body: body)).owner('100'),
        _failure(HuajiaoFailure.schema),
      );
    }
  });

  test('cancellation before request, after response and during failure dominates publication', () async {
    var calls = 0;
    final cancelled = CancelToken()..cancel();
    await expectLater(
      HuajiaoApi(
        request: (_, _) async {
          calls++;
          return _ok(_owner());
        },
      ).room('100', cancel: cancelled),
      _failure(HuajiaoFailure.cancelled),
    );
    expect(calls, 0);
    for (final shouldThrow in [false, true]) {
      final token = CancelToken();
      await expectLater(
        HuajiaoApi(
          request: (_, passed) async {
            expect(identical(token, passed), isTrue);
            token.cancel();
            if (shouldThrow) throw StateError('fixture');
            return _ok(_owner());
          },
        ).room('100', cancel: token),
        _failure(HuajiaoFailure.cancelled),
      );
    }
  });

  test('transport exception text is sanitized and typed errors survive wrapping', () async {
    try {
      await HuajiaoApi(request: (_, _) async => throw StateError('SECRET_URL')).owner('100');
      fail('Expected error');
    } on HuajiaoException catch (error) {
      expect(error.toString(), 'Huajiao transport');
    }
    await expectLater(
      HuajiaoApi(request: (_, _) async => throw const HuajiaoException(HuajiaoFailure.schema)).owner('100'),
      _failure(HuajiaoFailure.schema),
    );
  });

  test('UTF8 byte cap also applies to injected responses', () async {
    final data = _owner();
    data['extra'] = List.filled(710000, '中').join();
    await expectLater(_api(data).owner('100'), _failure(HuajiaoFailure.schema));
  });

  test('response reader retains split UTF8 and rejects invalid UTF8', () async {
    final bytes = utf8.encode('中文');
    expect(await HuajiaoApi.readBody(Stream.fromIterable([bytes.sublist(0, 1), bytes.sublist(1)])), '中文');
    await expectLater(HuajiaoApi.readBody(Stream.value([255])), _failure(HuajiaoFailure.schema));
  });

  test('oversized body cancels its source immediately', () async {
    var cancelled = false;
    final stream = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
      },
    );
    final future = HuajiaoApi.readBody(stream.stream);
    stream.add(Uint8List(HuajiaoApi.responseLimit + 1));
    await expectLater(future, _failure(HuajiaoFailure.schema));
    expect(cancelled, isTrue);
    await stream.close();
  });

  test('absolute response deadline cancels a stalled source', () async {
    var cancelled = false;
    final stream = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
      },
    );
    await expectLater(
      HuajiaoApi.readBody(stream.stream, timeout: const Duration(milliseconds: 30)),
      throwsA(isA<TimeoutException>()),
    );
    expect(cancelled, isTrue);
    await stream.close();
  });

  test('production transport requests a bounded nonredirecting stream with H5 headers', () async {
    final original = shared.HttpClient.instance.dio;
    final dio = Dio()
      ..httpClientAdapter = _Adapter((options) async {
        expect(options.responseType, ResponseType.stream);
        expect(options.followRedirects, isFalse);
        expect(options.receiveTimeout, const Duration(seconds: 20));
        for (final header in HuajiaoApi.headers.entries) {
          expect(options.headers[header.key], header.value);
        }
        return ResponseBody.fromString(_ok(_owner()).body, 200);
      });
    shared.HttpClient.instance.dio = dio;
    try {
      expect((await HuajiaoApi().owner('100')).liveId, '200');
    } finally {
      shared.HttpClient.instance.dio = original;
      dio.close();
    }
  });

  test('production transport cancels an error response body without reading it', () async {
    var cancelled = false;
    final stream = StreamController<Uint8List>(
      onCancel: () {
        cancelled = true;
      },
    );
    final original = shared.HttpClient.instance.dio;
    final dio = Dio()..httpClientAdapter = _Adapter((_) async => ResponseBody(stream.stream, 403));
    shared.HttpClient.instance.dio = dio;
    try {
      await expectLater(HuajiaoApi().owner('100'), _failure(HuajiaoFailure.access));
      expect(cancelled, isTrue);
    } finally {
      shared.HttpClient.instance.dio = original;
      dio.close();
      await stream.close();
    }
  });

  test('production overflow closes upstream without cancelling the caller token', () async {
    var cancelled = false;
    late final StreamController<Uint8List> stream;
    stream = StreamController<Uint8List>(
      onListen: () {
        stream.add(Uint8List(HuajiaoApi.responseLimit + 1));
      },
      onCancel: () {
        cancelled = true;
      },
    );
    final caller = CancelToken();
    final original = shared.HttpClient.instance.dio;
    final dio = Dio()..httpClientAdapter = _Adapter((_) async => ResponseBody(stream.stream, 200));
    shared.HttpClient.instance.dio = dio;
    try {
      await expectLater(HuajiaoApi().owner('100', cancel: caller), _failure(HuajiaoFailure.schema));
      expect(cancelled, isTrue);
      expect(caller.isCancelled, isFalse);
    } finally {
      shared.HttpClient.instance.dio = original;
      dio.close();
      await stream.close();
    }
  });

  test('production caller cancellation closes a stalled body', () async {
    var cancelled = false;
    final listening = Completer<void>();
    final stream = StreamController<Uint8List>(
      onListen: () {
        listening.complete();
      },
      onCancel: () {
        cancelled = true;
      },
    );
    final caller = CancelToken();
    final original = shared.HttpClient.instance.dio;
    final dio = Dio()..httpClientAdapter = _Adapter((_) async => ResponseBody(stream.stream, 200));
    shared.HttpClient.instance.dio = dio;
    try {
      final future = HuajiaoApi().owner('100', cancel: caller);
      final check = expectLater(future, _failure(HuajiaoFailure.cancelled));
      await listening.future;
      caller.cancel();
      await check;
      expect(cancelled, isTrue);
    } finally {
      shared.HttpClient.instance.dio = original;
      dio.close();
      await stream.close();
    }
  });
}
