import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/core/site/xiaohongshu/xiaohongshu_api.dart';
import 'package:pure_live/core/site/xiaohongshu/xiaohongshu_link.dart';
import 'package:pure_live/core/site/xiaohongshu/xiaohongshu_site.dart';

import 'live_short_link_test.dart' as fixtures;

const id = '570341209400361612';
const dynamicRoom = 'https://www.xiaohongshu.com/livestream/dynpath9oMyTyTC/$id';

void main() {
  test('official XHS live-audience deep link imports only its room identity', () async {
    final link = 'xhsdiscover://live_audience?room_id=$id&source=share&flvUrl=http%3A%2F%2F127.0.0.1%2Fprivate';
    final f = fixtures.ShortLinkFixture((_) async => throw StateError('No network'));
    expect(XiaohongshuLink.parse(link), id);
    expect(LiveUrlTool.containsSupportedLink('直播入口：$link，复制'), true);
    expect(await f.parse('直播入口：$link，复制'), [id, 'xiaohongshu']);
    expect(f.created, 0);
  });
  for (final link in [
    'xhsdiscover://live_audience?room_id=$id',
    'xhsdiscover://live_audience?room_id=$id&room_id=42&source=share',
    'xhsdiscover://live_audience?room_id=0&source=share',
    'xhsdiscover://live_audience?room_id=$id&source=',
    'xhsdiscover://live_audience/path?room_id=$id&source=share',
    'xhsdiscover://live_audience?room_id=$id&source=share#fragment',
    'xhsdiscover://other?room_id=$id&source=share',
    'ftp://xhsdiscover://live_audience?room_id=$id&source=share',
    'https://example.com/?target=xhsdiscover://live_audience?room_id=$id&source=share',
  ]) {
    test('XHS deep link rejects non-room or ambiguous input: $link', () async {
      final f = fixtures.ShortLinkFixture((_) async => throw StateError('No network'));
      expect(XiaohongshuLink.parse(link), isNull);
      expect(LiveUrlTool.containsSupportedLink(link), false);
      expect(await f.parse(link), isEmpty);
      expect(f.created, 0);
    });
  }
  test('XHS share input accepts the observed dynamic room route', () async {
    final f = fixtures.ShortLinkFixture((_) async => throw StateError('No network'));
    expect(await f.parse(dynamicRoom), [id, 'xiaohongshu']);
    expect(f.created, 0);
  });
  test('XHS share input resolves a public short link without fetching its landing page', () async {
    final f = fixtures.ShortLinkFixture((_) async => fixtures.redirect(302, dynamicRoom));
    expect(await f.parse('分享 https://xhslink.com/m/4vYwu2cQpeP，'), [id, 'xiaohongshu']);
    expect(f.requests, hasLength(1));
    expect(f.closed, 1);
  });
  test('XHS share input rejects trailing dot segments before URI normalization', () {
    expect(XiaohongshuLink.parse('https://www.xiaohongshu.com/livestream/$id/.'), isNull);
  });
  for (final suffix in ['/.', '/..', '/.。复制', '/..)', '/.?share=fixture']) {
    test('share extraction preserves invalid terminal dot structure: $suffix', () async {
      final url = 'https://www.xiaohongshu.com/livestream/$id$suffix';
      final f = fixtures.ShortLinkFixture((_) async => throw StateError('No network'));
      expect(LiveUrlTool.containsSupportedLink(url), false);
      expect(await f.parse(url), isEmpty);
      expect(f.created, 0);
    });
  }

  for (final url in [
    'https://xiaohongshu.com/livestream/$id',
    'http://www.xiaohongshu.com:80/livestream/$id/',
    'https://www.xiaohongshu.com:443/hina/livestream/$id',
    'https://www.xiaohongshu.com/hina/livestream/$id/123?room_id=42',
    '$dynamicRoom?host_id=42&xsec_token=fixture%3D#ignored',
  ]) {
    test('verified alias retains room identity without HTTP: $url', () async {
      final f = fixtures.ShortLinkFixture((_) async => throw StateError('No network'));
      expect(XiaohongshuLink.parse(url), id);
      expect(LiveUrlTool.containsSupportedLink(url), true);
      expect(await f.parse(url), [id, 'xiaohongshu']);
      expect(f.created, 0);
    });
  }
  for (final status in [301, 302, 303, 307, 308]) {
    test('XHS bounded redirect accepts HTTP $status and cancels its client', () async {
      final f = fixtures.ShortLinkFixture((_) async => fixtures.redirect(status, dynamicRoom));
      expect(await f.parse('http://xhslink.com/zfknEQ'), [id, 'xiaohongshu']);
      expect(f.requests.single.followRedirects, false);
      expect(f.requests.single.headers['User-Agent'], XiaohongshuApi.headers['User-Agent']);
      expect(f.closed, 1);
      expect(f.requests.single.cancelToken?.isCancelled, true);
    });
  }
  test('actual share prose has a non-whitespace Chinese boundary', () async {
    final f = fixtures.ShortLinkFixture((_) async => fixtures.redirect(302, dynamicRoom));
    final text = '小红书，正在直播 😆 https://xhslink.com/m/abc123，复制本条信息，打开【小红书】，直接观看直播！';
    expect(LiveUrlTool.containsSupportedLink(text), true);
    expect(await f.parse(text), [id, 'xiaohongshu']);
    expect(f.requests.single.uri.path, '/m/abc123');
    expect(LiveUrlTool.sharedHttpUrls('https://xhslink.com/m/abc123?q=%EF%BC%8C，复制'), [
      'https://xhslink.com/m/abc123?q=%EF%BC%8C',
    ]);
  });
  for (final location in [
    'https://www.xiaohongshu.com/',
    'https://www.xiaohongshu.com/user/profile/$id',
    'https://www.xiaohongshu.com/explore/$id',
    'https://live.bilibili.com/123',
    'http://127.0.0.1/private',
    'http://192.168.1.2:8787/mcp',
    'https://xhslink.com.evil.test/m/abc',
    'https://www.xiaohongshu.com.evil.test/livestream/$id',
    'https://www.xiaohongshu.com:8787/livestream/$id',
    'https://user@www.xiaohongshu.com/livestream/$id',
    'ftp://www.xiaohongshu.com/livestream/$id',
    'https://www.xiaohongshu.com/livestream/$id/.',
    'https://www.xiaohongshu.com/livestream/42/../$id',
    'https://www.xiaohongshu.com/livestream/%35$id',
    'https://www.xiaohongshu.com/livestream/42\\../$id',
    '/m/first/../second',
    'https://www.xiaohongshu.com/livestream/dynpathBAD/$id',
    'https://www.xiaohongshu.com/livestream/arbitrary/$id',
    'https://www.xiaohongshu.com/hina/livestream/0/123',
    'https://www.xiaohongshu.com/hina/livestream/$id/123/extra',
    'https://[broken',
    '',
  ]) {
    test('XHS rejects untrusted or non-room landing without fetching it: $location', () async {
      final f = fixtures.ShortLinkFixture((_) async => fixtures.redirect(302, location));
      expect(await f.parse('https://xhslink.com/m/abc'), isEmpty);
      expect(f.requests, hasLength(1));
      expect(f.closed, 1);
    });
  }
  for (final status in [200, 204, 400, 404, 429, 500]) {
    test('XHS HTTP $status does not reinterpret a Location as a redirect', () async {
      final f = fixtures.ShortLinkFixture((_) async => fixtures.redirect(status, dynamicRoom));
      expect(await f.parse('https://xhslink.com/m/abc'), isEmpty);
      expect(f.requests, hasLength(1));
      expect(f.closed, 1);
    });
  }
  test('XHS duplicate Location values are ambiguous', () async {
    final f = fixtures.ShortLinkFixture(
      (_) async => ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [dynamicRoom, 'https://www.xiaohongshu.com/livestream/123'],
        },
      ),
    );
    expect(await f.parse('https://xhslink.com/m/abc'), isEmpty);
    expect(f.requests, hasLength(1));
  });
  test('XHS relative and protocol-relative hops share one client and budget', () async {
    final f = fixtures.ShortLinkFixture(
      (request) async => fixtures.redirect(302, switch (request.uri.path) {
        '/first' => '/m/second',
        '/m/second' => '//xhslink.com/m/third',
        _ => dynamicRoom,
      }),
    );
    expect(await f.parse('https://xhslink.com/first'), [id, 'xiaohongshu']);
    expect(f.requests.map((r) => r.uri.path), ['/first', '/m/second', '/m/third']);
    expect(f.created, 1);
    expect(f.closed, 1);
  });
  test('XHS fragments do not evade duplicate-request detection', () async {
    var next = 0;
    final f = fixtures.ShortLinkFixture((_) async => fixtures.redirect(302, 'https://xhslink.com/first#${++next}'));
    expect(await f.parse('https://xhslink.com/first'), isEmpty);
    expect(f.requests, hasLength(1));
  });
  test('XHS unique hops stop at the session ceiling', () async {
    var next = 0;
    final f = fixtures.ShortLinkFixture((_) async => fixtures.redirect(302, 'https://xhslink.com/m/next${++next}'));
    expect(await f.parse('https://xhslink.com/first'), isEmpty);
    expect(f.requests, hasLength(8));
    expect(f.closed, 1);
  });
  test('XHS failure preserves a later independently supplied supported room', () async {
    final f = fixtures.ShortLinkFixture((_) async => fixtures.redirect(307, 'https://www.xiaohongshu.com/'));
    expect(await f.parse('https://xhslink.com/expired https://www.huya.com/fixture'), ['fixture', 'huya']);
    expect(f.requests, hasLength(1));
  });
  for (final timeout in [false, true]) {
    test('XHS ${timeout ? 'deadline' : 'caller cancellation'} prevents a late hop', () async {
      final pending = Completer<ResponseBody>();
      final started = Completer<void>();
      final token = CancelToken();
      final f = fixtures.ShortLinkFixture((_) {
        started.complete();
        return pending.future;
      });
      final action = f.parse(
        'https://xhslink.com/first',
        cancelToken: token,
        timeout: timeout ? const Duration(milliseconds: 30) : const Duration(seconds: 1),
      );
      await started.future;
      if (!timeout) token.cancel();
      expect(await action, isEmpty);
      expect(f.closed, 1);
      pending.complete(fixtures.redirect(302, 'https://xhslink.com/m/late'));
      await Future<void>.delayed(Duration.zero);
      expect(f.requests, hasLength(1));
    });
  }
  test('XHS search resolves a short room, strips share metadata and skips page two', () async {
    final f = fixtures.ShortLinkFixture(
      (_) async => fixtures.redirect(302, '$dynamicRoom?host_id=42&xsec_token=fixture'),
    );
    final state = jsonDecode(
      File('test/fixtures/xiaohongshu/live.json').readAsStringSync().replaceAll('570429070963278308', id),
    ) as Map<String, dynamic>;
    state['roomData']['roomInfo']['roomId'] = id;
    final requests = <Uri>[];
    final site = XiaohongshuSite(
      shortLinkClientFactory: () {
        f.created++;
        return Dio()..httpClientAdapter = fixtures.FixtureAdapter(f);
      },
      api: XiaohongshuApi(
        request: (uri, _) async {
          requests.add(uri);
          return (status: 200, body: '<script>window.__INITIAL_STATE__=${jsonEncode({'liveStream': state})}</script>');
        },
      ),
    );
    final found = await site.searchRooms('https://xhslink.com/m/first');
    expect(found.single.roomId, id);
    expect(found.single.data, isNull);
    expect(found.single.userId, anyOf(isNull, isEmpty));
    expect(requests.single.toString(), XiaohongshuLink.url(id));
    expect(f.closed, 1);
    expect(await site.searchRooms('https://xhslink.com/m/first', page: 2), isEmpty);
    expect(f.requests, hasLength(1));
  });
}
