import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/shopeelive/shopeelive_api.dart';
import 'package:pure_live/core/site/shopeelive/shopeelive_browser.dart';
import 'package:pure_live/core/site/shopeelive/shopeelive_link.dart';
import 'package:pure_live/core/site/shopeelive/shopeelive_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test('official share links retain region and session identity', () {
    expect(
      ShopeeLiveLink.parse('https://live.shopee.co.id/share?from=live&session=225239358')?.storageKey,
      'id:225239358',
    );
    expect(
      ShopeeLiveLink.parse('https://live.shopee.co.id/middle-page?type=live&id=225239358')?.storageKey,
      'id:225239358',
    );
    expect(ShopeeLiveLink.parseKey('225239358')?.storageKey, 'id:225239358');
    expect(ShopeeLiveLink.parseKey('id:225239358')?.sessionId, '225239358');
    expect(ShopeeLiveLink.url('id:225239358'), 'https://live.shopee.co.id/share?from=live&session=225239358');
    for (final invalid in [
      'https://live.shopee.co.id/guide-download?session=225239358',
      'https://live.shopee.co.id/middle-page?type=lp&id=225239358',
      'https://live.shopee.co.id.evil.test/share?session=225239358',
      'https://user@live.shopee.co.id/share?session=225239358',
      'https://live.shopee.co.id:444/share?session=225239358',
      'vn:225239358',
    ]) {
      expect(ShopeeLiveLink.parseKey(invalid), isNull, reason: invalid);
    }
  });

  test('finite homepage directory preserves current viewer metric', () async {
    final api = ShopeeLiveApi(
      request: (uri, headers, cancel) async {
        expect(uri, ShopeeLiveApi.directoryUri);
        expect(headers['Referer'], '${ShopeeLiveApi.marketplaceOrigin}/');
        return (status: 200, body: jsonEncode(_directory()));
      },
      sessionResolver: _FixtureSessionResolver(),
    );
    final page = await api.directory();
    expect(page.rooms, hasLength(1));
    expect(page.rooms.single.storageKey, 'id:225239358');
    expect(page.rooms.single.viewerCount, 1125);
    expect(page.rooms.single.cover, contains('/file/sg-fixture-cover'));

    final directory = await ShopeeLiveSite(api: api).getDirectoryPage();
    expect(directory.hasMore, isFalse);
    expect(directory.rooms.single.onlineViewers, '1125');
    expect(directory.rooms.single.audienceMetricType, AudienceMetricType.onlineViewers);
  });

  test('session access response enters official browser resolver and groups FLV lines', () async {
    final resolver = _FixtureSessionResolver();
    final api = ShopeeLiveApi(
      request: (uri, headers, cancel) async {
        expect(uri.path, '/api/v1/session/225239358');
        expect(headers['Client-Info'], 'os=2;platform=9');
        return (status: 403, body: '');
      },
      sessionResolver: resolver,
    );
    final site = ShopeeLiveSite(api: api);
    final detail = await site.getRoomDetail(roomId: 'id:225239358', platform: Sites.shopeeLiveSite);
    expect(detail.effectiveLiveStatus, LiveStatus.live);
    expect(detail.nick, 'Fixture shop');
    expect(detail.onlineViewers, '601');
    expect(detail.httpHeaders['Referer'], ShopeeLiveLink.url('id:225239358'));
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.map((quality) => quality.selectionId), ['720x1280']);
    expect(qualities.single.quality, '720p · FLV');
    final first = await site.resolvePlayUrlsRaw(detail: detail, quality: qualities.single);
    expect(first.urls, hasLength(2));
    expect(first.urls.every((url) => url.startsWith('https://play-')), isTrue);
    final recovered = await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: qualities.single);
    expect(recovered.urls.every((url) => url.contains('generation=2')), isTrue);
    expect(resolver.calls, 2);
  });

  test('exact ID search resolves a room while keyword search filters the public snapshot', () async {
    final resolver = _FixtureSessionResolver();
    final api = ShopeeLiveApi(
      request: (uri, headers, cancel) async =>
          uri.host == 'shopee.co.id' ? (status: 200, body: jsonEncode(_directory())) : (status: 403, body: ''),
      sessionResolver: resolver,
    );
    final site = ShopeeLiveSite(api: api);
    final keyword = await site.searchRooms('SUPER SALE');
    expect(keyword.single.roomId, 'id:225239358');
    final exact = await site.searchRooms('225239358');
    expect(exact.single.nick, 'Fixture shop');
    expect(resolver.calls, 1);
  });

  test('short-lived media lease is derived from expire_ts', () {
    const url =
        'https://play-hw-las.livetech.shopee.co.id/live/id-live-fixture.flv?expire_ts=1800000000&resolution=720x1280';
    expect(ShopeeLiveApi.mediaInvalidAt(url), DateTime.utc(2027, 1, 15, 7, 59, 50));
    expect(ShopeeLiveApi.mediaRefreshAt(url), DateTime.utc(2027, 1, 15, 7, 57, 50));
  });

  test('browser script discovers the official API module without embedding session tokens', () {
    final script = ShopeeLiveBrowserSessionResolver.buildSessionScript('225239358');
    expect(script, contains('getSessionInfoWithId'));
    expect(script, contains('Object.values(require.c || {})'));
    expect(script, isNot(contains('X-LS-SZ-TOKEN')));
    expect(script, isNot(contains('expire_ts=')));
  });

  test('registry exposes one Shopee Live adapter with recording recovery', () {
    expect(Sites.supportedSiteIds, contains(Sites.shopeeLiveSite));
    expect(Sites.of(Sites.shopeeLiveSite).liveSite, isA<ShopeeLiveSite>());
    expect(Sites.supportSites.where((site) => site.id == Sites.shopeeLiveSite), hasLength(1));
  });

  test('caller cancellation is classified before transport', () async {
    final api = ShopeeLiveApi(
      request: (_, _, _) async => throw StateError('unused'),
      sessionResolver: _FixtureSessionResolver(),
    );
    await expectLater(
      api.session('id:225239358', cancel: CancelToken()..cancel()),
      throwsA(isA<ShopeeLiveException>().having((error) => error.kind, 'kind', ShopeeLiveFailure.cancelled)),
    );
  });
}

final class _FixtureSessionResolver implements ShopeeLiveSessionResolver {
  int calls = 0;

  @override
  Future<Map<String, dynamic>> resolve(String sessionId) async {
    calls++;
    return _session(sessionId, generation: calls);
  }
}

Map<String, dynamic> _directory() => {
  'error': null,
  'error_msg': null,
  'data': {
    'sessions': [
      {
        'session_id': 225239358,
        'title': '9.9 SUPER SALE',
        'cover': 'sg-fixture-cover',
        'view_count': 1125,
        'shop_id': 1723034421,
        'status': 1,
        'user_id': 7156535642,
        'room_id': 3806999187866112,
      },
    ],
    'plans': [],
    'replays': [],
  },
};

Map<String, dynamic> _session(String sessionId, {required int generation}) => {
  'session': {
    'session_id': int.parse(sessionId),
    'uid': 7156535642,
    'username': 'fixture_shop',
    'room_id': 3806999187866112,
    'shop_id': 1723034421,
    'avatar': 'id-fixture-avatar',
    'nickname': 'Fixture shop',
    'title': 'Fixture live',
    'cover_pic': 'id-fixture-cover',
    'status': 1,
    'is_terminate': false,
    'viewer_count': 601,
    'play_url':
        'https://play-hw-las.livetech.shopee.co.id/live/id-live-fixture.flv?expire_ts=1800000000&resolution=720x1280&generation=$generation',
  },
  'play_urls': [
    'https://play-ws-las.livetech.shopee.co.id/livestreaming/id-live-fixture.flv?expire_ts=1800000000&resolution=720x1280&generation=$generation',
    'https://play-hw-las.livetech.shopee.co.id/live/id-live-fixture.flv?expire_ts=1800000000&resolution=720x1280&generation=$generation',
  ],
};
