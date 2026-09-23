import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/weibo/weibo_api.dart';
import 'package:pure_live/core/site/weibo/weibo_link.dart';
import 'package:pure_live/core/site/weibo/weibo_site.dart';
import 'package:pure_live/model/live_play_quality.dart';

const id = '1022:2321325000000000000000';
const other = '1022:2321325000000000000001';
Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/weibo/$name.json').readAsStringSync()) as Map<String, dynamic>;
Matcher failure(WeiboFailure kind) => throwsA(isA<WeiboException>().having((e) => e.kind, 'kind', kind));
void main() {
  for (final input in [
    id,
    ' $id ',
    'https://weibo.com/l/wblive/p/show/$id',
    'http://www.weibo.com/l/wblive/m/show/$id/',
    'https://WEIBO.COM:443/l/wblive/p/show/${id.replaceAll(':', '%3A')}?from=share#live',
    'https://weibo.com/l/wblive/m/show/1042152%3a8e4d2f2900a81be5a8ece15da4dd443a',
  ]) {
    test('exact official watch input ${jsonEncode(input)}', () {
      final parsed = WeiboLink.parse(input);
      expect(parsed, isNotNull);
      expect(WeiboLink.parse(WeiboLink.url(parsed!)), parsed);
    });
  }
  for (final input in [
    '101',
    'nickname',
    'https://weibo.com/u/101',
    'https://weibo.com/123/post',
    'https://weibo.com.evil.test/l/wblive/p/show/$id',
    'https://weibo.com@evil.test/l/wblive/p/show/$id',
    'https://user@weibo.com/l/wblive/p/show/$id',
    'https://weibo.com:444/l/wblive/p/show/$id',
    'file:///l/wblive/p/show/$id',
    'https://weibo.com/l/wblive/p/show/$id/extra',
    'https://weibo.com/l/wblive/p/./show/$id',
    'https://weibo.com/l/wblive/p/x/../show/$id',
    'https://weibo.com/l/wblive/p/show/${id.replaceAll(':', '%253A')}',
    'https://weibo.com/l/wblive/p/show/${id.replaceAll(':', '%3A')}%2F',
    'https://weibo.com/l/wblive/p/show/$id/.',
    'https://weibo.com/l/wblive/p/show/$id/..',
    'https://t.cn/fixture',
    'https://weibo.com/l/wblive/app/h5_compatible?live_id=$id',
  ]) {
    test('rejects ambiguous or unobserved route ${jsonEncode(input)}', () {
      expect(WeiboLink.parse(input), isNull);
    });
  }
  late WeiboSite site;
  late Map<String, dynamic> data;
  late List<Uri> calls;
  int status = 200;
  setUp(() {
    data = fixture('live-detail');
    calls = [];
    status = 200;
    site = WeiboSite(
      api: WeiboApi(
        request: (m, u, f, c) async {
          calls.add(u);
          return (status: status, body: jsonEncode(u.path.contains('pc_recommend') ? fixture('recommend') : data));
        },
      ),
    );
  });
  Future<LiveRoom> room() => site.getRoomDetail(roomId: id, platform: 'weibo');
  test('finite directory does not invent live status, viewer metric or user-room identity', () async {
    final page = await site.getDirectoryPage();
    expect(page.hasMore, false);
    expect(page.rooms, hasLength(2));
    final card = page.rooms.first;
    expect(card.roomId, id);
    expect(card.userId, '101');
    expect(card.liveStatus, LiveStatus.unknown);
    expect(card.onlineViewers, isEmpty);
    expect(card.hasRealOnlineCount, isFalse);
    expect(card.audienceValue(preferRealOnline: false, platformEnabled: false), isEmpty);
    expect((await site.getDirectoryPage(page: 2)).rooms, isEmpty);
    expect(calls, hasLength(1));
  });
  test('category contract and invalid category stop before HTTP', () async {
    final categories = await site.getCategores(1, 30);
    expect(categories, hasLength(1));
    await expectLater(
      site.getDirectoryPage(
        category: LiveArea(platform: 'weibo', areaType: 'other', areaId: 'live'),
      ),
      failure(WeiboFailure.schema),
    );
    await expectLater(site.getDirectoryPage(page: 0), failure(WeiboFailure.schema));
    await expectLater(site.getRecommendRooms(pageSize: 0), failure(WeiboFailure.schema));
    expect(calls, isEmpty);
  });
  test('detail, refresh and recording retain typed source without coercing room identity', () async {
    for (final fn in [site.getRoomDetail, site.getRoomDetailForRefresh, site.getRoomDetailForRecording]) {
      final r = await fn(roomId: id, platform: 'weibo');
      expect(r.liveStatus, LiveStatus.live);
      expect(r.roomId, id);
      expect(r.userId, '101');
      expect(r.data, isA<WeiboLiveDetail>());
      expect(r.onlineViewers, isEmpty);
      expect(r.hasRealOnlineCount, isFalse);
      expect(r.audienceValue(preferRealOnline: false, platformEnabled: false), isEmpty);
    }
    expect(calls, hasLength(3));
  });
  test('exact search does not pretend nickname or UID lookup; API errors propagate', () async {
    expect(await site.searchRooms('nickname'), isEmpty);
    expect(await site.searchRooms('101'), isEmpty);
    expect(await site.searchRooms(id, page: 2), isEmpty);
    expect(calls, isEmpty);
    expect((await site.searchRooms(WeiboLink.url(id))).single.roomId, id);
    data = fixture('detail');
    await expectLater(site.searchRooms(id), failure(WeiboFailure.api));
  });
  test('pre-cancelled directory and exact search do not dispatch', () async {
    final c = CancelToken()..cancel();
    await expectLater(site.getDirectoryPage(cancel: c), failure(WeiboFailure.cancelled));
    await expectLater(site.searchRoomsCancellable(id, cancel: c), failure(WeiboFailure.cancelled));
    expect(calls, isEmpty);
  });
  test('exact search forwards cancellation to its owned HTTP request', () async {
    final c = CancelToken();
    final started = Completer<void>();
    final pending = Completer<({int status, String body})>();
    late CancelToken owned;
    final api = WeiboApi(
      request: (m, u, f, t) {
        owned = t;
        started.complete();
        return pending.future;
      },
    );
    final check = expectLater(
      WeiboSite(api: api).searchRoomsCancellable(id, cancel: c),
      failure(WeiboFailure.cancelled),
    );
    await started.future;
    c.cancel();
    await check;
    expect(owned.isCancelled, true);
    pending.complete((status: 200, body: jsonEncode(data)));
  });
  test(
    'original choice is immutable and every ordinary/recovery/recording resolution reacquires exact broadcast',
    () async {
      final r = await room();
      final qs = await site.getPlayQualites(detail: r);
      expect(qs, hasLength(1));
      expect(qs.single.selectionId, 'original');
      expect(() => qs.clear(), throwsUnsupportedError);
      for (var i = 0; i < 3; i++) {
        data['data']['live_origin_flv_url'] = 'https://media.example.test/fresh.flv?token=$i';
        data['data']['live_origin_hls_url'] = data['data']['live_origin_flv_url'];
        final resolved = i == 1
            ? await site.resolvePlayUrlsForRecovery(detail: r, quality: qs.single)
            : await site.resolvePlayUrls(detail: r, quality: qs.single);
        expect(resolved.urls, ['https://media.example.test/fresh.flv?token=$i']);
        expect(resolved.appliedQualityData, 'original');
      }
      expect(calls, hasLength(4));
      expect(calls.every((u) => u.queryParameters['live_id'] == id), true);
    },
  );
  test('freshness cannot cross owner identity', () async {
    final r = await room();
    final q = (await site.getPlayQualites(detail: r)).single;
    data['data']['user']['uid'] = 999;
    await expectLater(site.resolvePlayUrlsForRecovery(detail: r, quality: q), failure(WeiboFailure.identity));
  });
  test('foreign quality and serialized URL injection rejected before refresh', () async {
    final r = await room();
    final q = (await site.getPlayQualites(detail: r)).single;
    data['data']['liveId'] = other;
    final r2 = await site.getRoomDetail(roomId: other, platform: 'weibo');
    await expectLater(site.getPlayUrls(detail: r2, quality: q), failure(WeiboFailure.identity));
    await expectLater(
      site.getPlayUrls(
        detail: r,
        quality: LivePlayQuality(id: 'original', quality: 'fake', data: ['https://evil.test/a.flv']),
      ),
      failure(WeiboFailure.identity),
    );
    expect(calls, hasLength(2));
  });
  for (final mode in ['restricted', 'disabled', 'unknown', 'replay', 'empty-media']) {
    test('fresh $mode never falls back to old playable URL', () async {
      final r = await room();
      final q = (await site.getPlayQualites(detail: r)).single;
      switch (mode) {
        case 'restricted':
          data['data']['watch_limit'] = 8;
        case 'disabled':
          data['data']['play_switch'] = 0;
        case 'unknown':
          data['data']['status'] = 99;
        case 'replay':
          data['data']['status'] = 3;
        case 'empty-media':
          data['data']['live_origin_flv_url'] = '';
          data['data']['live_origin_hls_url'] = '';
      }
      await expectLater(site.getPlayUrls(detail: r, quality: q), throwsA(isA<WeiboException>()));
      final fresh = await room();
      if (mode == 'replay') {
        expect(fresh.liveStatus, LiveStatus.replay);
        expect(await site.getPlayQualites(detail: fresh), isEmpty);
        expect(await site.getLiveStatus(platform: 'weibo', roomId: id), false);
      }
      if (['restricted', 'disabled', 'unknown'].contains(mode)) {
        expect(fresh.liveStatus, LiveStatus.unknown);
        await expectLater(
          site.getLiveStatus(platform: 'weibo', roomId: id),
          failure(mode == 'unknown' ? WeiboFailure.unknownState : WeiboFailure.access),
        );
      }
    });
  }
  test('wrong platform and body-room identity fail before resolution', () async {
    await expectLater(site.getRoomDetail(roomId: id, platform: 'other'), failure(WeiboFailure.identity));
    expect(calls, isEmpty);
    final r = await room();
    r.userId = '999';
    await expectLater(site.getPlayQualites(detail: r), failure(WeiboFailure.identity));
  });
  test('transport error never produces an offline-looking detail', () async {
    status = 503;
    await expectLater(room(), failure(WeiboFailure.service));
    await expectLater(site.getLiveStatus(platform: 'weibo', roomId: id), failure(WeiboFailure.service));
  });
  test('new visible strings exist in both locale assets', () {
    for (final lang in ['zh', 'en']) {
      final map = jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map;
      for (final key in [
        'site_weibo',
        'weibo_public_directory',
        'weibo_directory_scope',
        'weibo_room_scope',
        'weibo_restricted',
        'weibo_original_stream',
      ]) {
        expect(map[key], isA<String>());
        expect((map[key] as String).trim(), isNotEmpty);
      }
    }
  });
}
