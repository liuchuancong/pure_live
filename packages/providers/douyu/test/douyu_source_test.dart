// Module: test/douyu_source_test.dart
// Purpose: Verify the Douyu source decodes its three row shapes and produces a ticket with a real deadline.
// Author: liuchuancong
// Created: 2026-10-10
//
// The bodies are shaped from the field names the v1-maintained line reads (rl / relateShow / room); they are
// not captured traffic. What they pin is this package's decoding, not Douyu's current answers - see the
// package README's 未验证 list for what still needs a real recording.

import 'package:pure_live_douyu/pure_live_douyu.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

import 'support/canned_http.dart';

const String _feedUrl = 'https://www.douyu.com/japi/weblist/apinc/allpage/6';
const String _directoryUrl = 'https://www.douyu.com/gapi/rkc/directory/mixList';
const String _categoryUrl = 'https://m.douyu.com/api/cate/list';
const String _profileUrl = 'https://www.douyu.com/betard';
const String _searchUrl = 'https://www.douyu.com/japi/search/api/searchShow';
const String _playUrl = 'https://www.douyu.com/lapi/live/getH5PlayV1';

final DateTime _clockNow = DateTime.utc(2026, 10, 10, 12);

/// The room list document: one live room, one directory filler row, and no paging statement of its own.
String _listBody({int? page, int? totalPage}) {
  final paging = page == null ? '' : ',"page":$page,"totalpage":$totalPage';
  return '{"error":0,"data":{"rl":['
      '{"type":1,"rid":123,"rn":"房间一","nn":"主播一","c2name":"星球","ol":"1024","rs16":"https://p.douyucdn.cn/1.jpg"},'
      '{"type":3,"rid":999,"rn":"目录位"}'
      ']$paging}}';
}

String _encryptionBody(int nowSeconds) =>
    '{"data":{"key":"k3y","rand_str":"rnd","enc_time":3,"enc_data":"EDATA",'
    '"expire_at":${nowSeconds + 600},"is_special":0}}';

/// The path-plus-CDN shape, with the `&amp;` a real answer carries.
String _playBodySplit() =>
    '{"error":0,"data":{"rtmp_cdn":"hs","rtmp_url":"https://d1.live.com/","rtmp_live":'
    '"live/room123.flv?wsSecret=abc&amp;expire=300"}}';

/// The current shape, where rtmp_live is already the whole signed url.
String _playBodyComplete() =>
    '{"error":0,"data":{"rtmp_cdn":"ali","rtmp_url":"https://d1.live.com/","rtmp_live":'
    '"https://d2.live.com/live/room999.flv?wsSecret=zz&expire=60"}}';

void main() {
  final clock = FixedClock(_clockNow).call;
  final nowSeconds = _clockNow.millisecondsSinceEpoch ~/ 1000;

  /// A source over the canned routes, plus the adapter so a test can count what was asked for.
  (DouyuSource, CannedHttp) source(Map<String, String> routes) {
    final adapter = CannedHttp(<String, String>{kDouyuEncryptionEndpoint: _encryptionBody(nowSeconds), ...routes});
    final device = DouyuDevice(deviceId: 'did');
    return (
      DouyuSource(
        client: NetworkClient(adapter: adapter),
        device: device,
        clock: clock,
      ),
      adapter,
    );
  }

  group('feed and browse', () {
    test('test_feed_dropsTheRowsThatAreNotLiveRooms', () async {
      final (douyu, adapter) = source(<String, String>{'$_feedUrl/1': _listBody()});

      final result = await douyu.feed(const PageRequest(page: 1, pageSize: 20));

      expect(adapter.urls.first, '$_feedUrl/1');
      expect(result.items.map((item) => item.ref.contentId), <String>['123']);
      expect(result.items.single.title, '房间一');
      expect(result.items.single.subtitle, '主播一 · 星球');
      expect(result.items.single.metadata.popularity, 1024);
      expect(result.hasMore, isFalse);
    });

    test('test_browse_withACategory_readsTheDirectorysOwnPaging', () async {
      final (douyu, adapter) = source(<String, String>{'$_directoryUrl/2_11/2': _listBody(page: 2, totalPage: 5)});

      final result = await douyu.browse(const ContentQuery(category: '11', page: PageRequest(page: 2, pageSize: 20)));

      expect(adapter.urls.single, '$_directoryUrl/2_11/2');
      expect(result.hasMore, isTrue);
    });

    test('test_browse_withoutACategory_isTheRecommendFeed', () async {
      final (douyu, adapter) = source(<String, String>{'$_feedUrl/1': _listBody()});

      await douyu.browse(const ContentQuery());

      expect(adapter.urls.single, '$_feedUrl/1');
    });

    test('test_browse_listError_reportsTheSourcesOwnCode', () async {
      final (douyu, _) = source(<String, String>{'$_directoryUrl/2_11/1': '{"error":5,"msg":"gone"}'});

      await expectLater(
        douyu.browse(const ContentQuery(category: '11')),
        throwsA(isA<DouyuApiException>().having((error) => error.errorCode, 'errorCode', 5)),
      );
    });

    test('test_browse_missingRl_isNamedNotCast', () async {
      final (douyu, _) = source(<String, String>{'$_directoryUrl/2_11/1': '{"error":0,"data":{}}'});

      await expectLater(
        douyu.browse(const ContentQuery(category: '11')),
        throwsA(isA<DouyuApiException>().having((error) => error.message, 'message', contains('data.rl'))),
      );
    });

    test('test_categories_joinsTheTwoArraysAndKeepsSourceOrder', () async {
      final (douyu, _) = source(<String, String>{
        _categoryUrl:
            '{"data":{"cate1Info":[{"cate1Id":1,"cate1Name":"网游"},{"cate1Id":3,"cate1Name":"手游"}],'
            '"cate2Info":[{"cate1Id":1,"cate2Id":11,"cate2Name":"LOL","icon":"https://i/11.png"},'
            '{"cate1Id":3,"cate2Id":31,"cate2Name":"王者","pic":"//i/31.png"}]}}',
      });

      final tree = await douyu.categories();

      expect(tree.map((node) => node.id), <String>['1', '11', '3', '31']);
      expect(tree[1].parentId, '1');
      expect(tree[1].icon, 'https://i/11.png');
      // The second child has only `pic`, and it is protocol-relative.
      expect(tree[3].icon, 'https://i/31.png');
    });

    test('test_categories_secondCallIsServedFromCache', () async {
      final (douyu, adapter) = source(<String, String>{
        _categoryUrl: '{"data":{"cate1Info":[{"cate1Id":1,"cate1Name":"网游"}],"cate2Info":[]}}',
      });

      await douyu.categories();
      await douyu.categories();

      expect(adapter.callsMatching(_categoryUrl), 1);
    });
  });

  group('detail', () {
    test('test_detail_profileStatesLiveStatus', () async {
      final (douyu, _) = source(<String, String>{
        '$_profileUrl/123':
            '{"room":{"room_id":123,"room_name":"房间一","owner_name":"主播一","second_lvl_name":"星球",'
            '"room_pic":"https://p/1.jpg","show_details":"简介","show_status":1,"videoLoop":0,'
            '"room_biz_all":{"hot":2048}}}',
      });

      final detail = await douyu.detail(
        const ContentRef(sourceId: douyuSourceId, contentId: '123', kind: ContentKind.liveRoom),
      );

      expect(detail.summary.title, '房间一');
      expect(detail.summary.metadata.extra['isLive'], isTrue);
      expect(detail.description, '简介');
    });

    test('test_detail_replayRoom_isNotLive', () async {
      final (douyu, _) = source(<String, String>{
        '$_profileUrl/123':
            '{"room":{"room_id":123,"room_name":"【回放】房间一","show_status":1,"videoLoop":0,"room_biz_all":{}}}',
      });

      final detail = await douyu.detail(
        const ContentRef(sourceId: douyuSourceId, contentId: '123', kind: ContentKind.liveRoom),
      );

      expect(detail.summary.metadata.extra['isLive'], isFalse);
    });

    test('test_detail_withoutRoomObject_isNamed', () async {
      final (douyu, _) = source(<String, String>{'$_profileUrl/123': '{"error":0}'});

      await expectLater(
        douyu.detail(const ContentRef(sourceId: douyuSourceId, contentId: '123', kind: ContentKind.liveRoom)),
        throwsA(isA<DouyuApiException>().having((error) => error.message, 'message', contains('room object'))),
      );
    });
  });

  group('search', () {
    test('test_search_keepsOfflineRowsAndSaysSo', () async {
      final (douyu, adapter) = source(<String, String>{
        _searchUrl:
            '{"error":0,"data":{"relateShow":[{"rid":"555","roomName":"直播间A","roomSrc":"//js.douyucdn.cn/a.jpg",'
            '"cateName":"品类","nickName":"N","hot":"2048","isLive":1,"roomType":0},'
            '{"rid":"556","roomName":"回放间","isLive":1,"roomType":1,"hot":"7"}]}}',
      });

      final result = await douyu.search(const SearchQuery(keyword: '关键词', page: PageRequest(page: 1, pageSize: 20)));

      expect(adapter.urls.single, startsWith('$_searchUrl?kw='));
      expect(result.items.length, 2);
      expect(result.items.first.cover, 'https://js.douyucdn.cn/a.jpg');
      expect(result.items.first.metadata.extra['isLive'], isTrue);
      expect(result.items.last.metadata.extra['isLive'], isFalse);
    });

    test('test_search_pageSizeIsClampedToWhatTheEndpointAccepts', () async {
      final (douyu, adapter) = source(<String, String>{_searchUrl: '{"error":0,"data":{"relateShow":[]}}'});

      final result = await douyu.search(const SearchQuery(keyword: 'x', page: PageRequest(page: 1, pageSize: 500)));

      expect(result.pageSize, 50);
      expect(adapter.urls.single, contains('pageSize=50'));
      expect(result.hasMore, isFalse);
    });

    test('test_search_apiError_isNamedWithItsCode', () async {
      final (douyu, _) = source(<String, String>{_searchUrl: '{"error":1,"msg":"bad keyword"}'});

      await expectLater(
        douyu.search(const SearchQuery(keyword: 'x')),
        throwsA(isA<DouyuApiException>().having((error) => error.message, 'message', contains('bad keyword'))),
      );
    });
  });

  group('resolve', () {
    test('test_resolve_joinsCdnBaseToSignedPathAndUnescapesTheQuery', () async {
      final (douyu, adapter) = source(<String, String>{'$_playUrl/123': _playBodySplit()});

      final ticket = await douyu.resolve(
        const ContentRef(sourceId: douyuSourceId, contentId: '123', kind: ContentKind.liveRoom),
      );

      expect(ticket.id, 'douyu.live/123');
      expect(ticket.uri.toString(), 'https://d1.live.com/live/room123.flv?wsSecret=abc&expire=300');
      expect(ticket.protocol, MediaProtocol.https);
      expect(ticket.metadata.extra['container'], 'flv');
      expect(ticket.metadata.extra['cdn'], 'hs');
      expect(ticket.headers['referer'], 'https://www.douyu.com/123');
      // The form body, not a JSON object: the endpoint reads x-www-form-urlencoded.
      expect(adapter.lastBody, allOf(contains('enc_data=EDATA'), contains('auth='), contains('rate=-1')));
      expect(adapter.requests.last.headers['content-type'], 'application/x-www-form-urlencoded');
    });

    test('test_resolve_leaseFromTheUrlSetsTheDeadline', () async {
      final (douyu, _) = source(<String, String>{'$_playUrl/123': _playBodySplit()});

      final ticket = await douyu.resolve(
        const ContentRef(sourceId: douyuSourceId, contentId: '123', kind: ContentKind.liveRoom),
      );

      expect(ticket.createdAt, _clockNow);
      expect(ticket.expiresAt, _clockNow.add(const Duration(seconds: 300)));
      // A 300s lease takes the 45s lead; a shorter one would take its own quarter instead.
      expect(ticket.refresh?.refreshBefore, const Duration(seconds: 45));
      expect(ticket.isExpiredAt(_clockNow.add(const Duration(seconds: 299))), isFalse);
      expect(ticket.isExpiredAt(_clockNow.add(const Duration(seconds: 301))), isTrue);
    });

    test('test_resolve_shortLeaseRefreshesAtItsOwnQuarter', () async {
      final (douyu, _) = source(<String, String>{
        '$_playUrl/123':
            '{"error":0,"data":{"rtmp_url":"https://d1.live.com/","rtmp_live":"live/room123.flv?expire=40"}}',
      });

      final ticket = await douyu.resolve(
        const ContentRef(sourceId: douyuSourceId, contentId: '123', kind: ContentKind.liveRoom),
      );

      expect(ticket.refresh?.refreshBefore, const Duration(seconds: 10));
    });

    test('test_resolve_completeUrlInRtmpLive_winsOverTheCdnBase', () async {
      final (douyu, _) = source(<String, String>{'$_playUrl/999': _playBodyComplete()});

      final ticket = await douyu.resolve(
        const ContentRef(sourceId: douyuSourceId, contentId: '999', kind: ContentKind.liveRoom),
      );

      // Prefixing the base onto an absolute path yields a url that looks valid and opens nothing.
      expect(ticket.uri.host, 'd2.live.com');
      expect(ticket.uri.path, '/live/room999.flv');
      expect(ticket.metadata.extra['cdn'], 'ali');
    });

    test('test_resolve_directoryOnlyAnswer_hasNoPlayableUrl', () async {
      final (douyu, _) = source(<String, String>{
        '$_playUrl/123': '{"error":0,"data":{"rtmp_url":"https://d1.live.com/","rtmp_live":""}}',
      });

      await expectLater(
        douyu.resolve(const ContentRef(sourceId: douyuSourceId, contentId: '123', kind: ContentKind.liveRoom)),
        throwsA(isA<DouyuApiException>().having((error) => error.message, 'message', contains('no playable URL'))),
      );
    });

    test('test_resolve_apiError_retriesOnceWithAFreshDescriptor', () async {
      final (douyu, adapter) = source(<String, String>{'$_playUrl/123': '{"error":2002,"msg":"room not living"}'});

      await expectLater(
        douyu.resolve(const ContentRef(sourceId: douyuSourceId, contentId: '123', kind: ContentKind.liveRoom)),
        throwsA(isA<DouyuApiException>().having((error) => error.errorCode, 'errorCode', 2002)),
      );
      // Two attempts, and the second one re-fetches the signing material rather than reusing the stale one.
      expect(adapter.callsMatching(_playUrl), 2);
      expect(adapter.callsMatching(kDouyuEncryptionEndpoint), 2);
    });

    test('test_resolve_nonJsonAnswer_isNamed', () async {
      final (douyu, _) = source(<String, String>{'$_playUrl/123': '<html>blocked</html>'});

      await expectLater(
        douyu.resolve(const ContentRef(sourceId: douyuSourceId, contentId: '123', kind: ContentKind.liveRoom)),
        throwsA(isA<DouyuApiException>()),
      );
    });

    test('test_refresh_reissuesTheTicketForTheRoomTheOldOneNamed', () async {
      final (douyu, adapter) = source(<String, String>{'$_playUrl/123': _playBodySplit()});
      final first = await douyu.resolve(
        const ContentRef(sourceId: douyuSourceId, contentId: '123', kind: ContentKind.liveRoom),
      );

      final second = await douyu.refresh(first, RefreshReason.expiring);

      expect(adapter.callsMatching(_playUrl), 2);
      expect(second.id, first.id);
      expect(second.uri, first.uri);
    });

    test('test_refresh_ticketFromAnotherSource_isRefused', () async {
      final (douyu, _) = source(<String, String>{'$_playUrl/123': _playBodySplit()});
      final foreign = MediaTicket(
        id: 'other.live/1',
        uri: Uri.parse('https://other/live.flv'),
        kind: MediaKind.live,
        protocol: MediaProtocol.https,
        createdAt: _clockNow,
      );

      await expectLater(douyu.refresh(foreign, RefreshReason.manual), throwsA(isA<DouyuApiException>()));
    });

    test('test_resolve_emptyRoomId_failsBeforeTheNetwork', () async {
      final (douyu, adapter) = source(<String, String>{'$_playUrl/': _playBodySplit()});

      await expectLater(
        douyu.resolve(const ContentRef(sourceId: douyuSourceId, contentId: '  ', kind: ContentKind.liveRoom)),
        throwsA(isA<DouyuApiException>()),
      );
      expect(adapter.requests, isEmpty);
    });
  });

  group('disposal', () {
    test('test_dispose_borrowedClient_stillAnswersAfterwards', () async {
      // The source cannot close a client it did not create: the same one serves other callers, and a dispose
      // that took it down would break them rather than this source.
      final adapter = CannedHttp(<String, String>{'$_feedUrl/1': _listBody()});
      final client = NetworkClient(adapter: adapter);
      DouyuSource(
        client: client,
        device: DouyuDevice(deviceId: 'did'),
      ).dispose();

      final result = await DouyuSource(
        client: client,
        device: DouyuDevice(deviceId: 'did'),
      ).feed(const PageRequest());

      expect(result.items.single.ref.contentId, '123');
    });

    test('test_dispose_createdClient_doesNotThrow', () {
      // No client was passed, so the source owns one and dispose() closes it; there is nothing left to ask it.
      DouyuSource(device: DouyuDevice(deviceId: 'did')).dispose();
    });
  });
}
