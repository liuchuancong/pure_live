import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/base/base_page_scroll_bone.dart';
import 'package:pure_live/common/base/live_directory_controller.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_directory.dart';
import 'package:pure_live/core/interface/live_search.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/weibo/weibo_api.dart';
import 'package:pure_live/core/site/weibo/weibo_link.dart';
import 'package:pure_live/core/site/weibo/weibo_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/area_rooms/area_rooms_binding.dart';
import 'package:pure_live/modules/live_play/services/room_external_opener.dart';
import 'package:pure_live/modules/multiview/danmaku/multiview_danmaku_session.dart';
import 'package:pure_live/modules/multiview/multiview_controller.dart';
import 'package:pure_live/modules/popular/popular_controller.dart';
import 'package:pure_live/modules/search/search_capability.dart';
import 'package:pure_live/modules/search/search_controller.dart' as search;
import 'package:pure_live/modules/search/web_search_room_parser.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';

import 'support/weibo_application_fixture.dart';

class _Directory extends LiveDirectoryController {
  _Directory(WeiboSite site) : super(directory: site);
  @override
  Future<bool> checkNetworkBeforeRequest() async => true;
  @override
  bool get usesDesktopPagination => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
  });
  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
    Get.put(SettingsService());
  });
  tearDown(Get.reset);
  tearDownAll(Hive.close);

  test('registered Weibo advertises only implemented directory, search and media contracts', () {
    final site = Sites.of(' WEIBO ');
    expect(Sites.isSupported(' WEIBO '), isTrue);
    expect(site.liveSite, isA<WeiboSite>());
    expect(site.liveSite, isA<LiveSiteDirectoryPager>());
    expect(site.liveSite, isA<LiveCancellableSearch>());
    expect(site.liveSite, isA<LiveSiteRecordRoomResolver>());
    expect(site.liveSite, isA<LiveSiteRoomRefresher>());
    expect(site.liveSite, isA<LivePlayUrlResolver>());
    expect(site.liveSite, isA<LivePlayRecoveryResolver>());
    expect(site.liveSite.getDanmaku(), isA<EmptyDanmaku>());
    expect(Sites.supportSites.where((s) => s.id == site.id), hasLength(1));
    final capability = LiveSearchCapabilities.forPlatform(site.id);
    expect(capability.coverage, NativeSearchCoverage.roomLookup);
    expect(capability.supportsNativeSearch, isTrue);
    expect(capability.supportsPagination, isFalse);
    expect(capability.supportsWebSearch, isFalse);
    expect(capability.mayIncludeOffline, isTrue);
    expect(MultiviewDanmakuSession.isSupportedPlatform(site.id), isFalse);
  });

  test('popular and category use the finite directory with an explicit scope notice', () async {
    final f = WeiboApplicationFixture();
    final popular = PopularController();
    addTearDown(popular.onClose);
    popular.initControllers([f.site]);
    final controller = Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: 'weibo');
    expect(controller, isA<LiveDirectoryController>());
    expect(controller.pageNotice, 'weibo_directory_scope');
    final area = (await f.adapter.getCategores(1, 30)).single.children.single;
    final category = AreaRoomsBinding.createController(f.site, area);
    addTearDown(category.onClose);
    expect(category, isA<LiveDirectoryController>());
    expect((category as LiveDirectoryController).category?.areaId, 'live');
    expect(f.requests, isEmpty);
  });

  test('actual directory does not invent live/audience state or refetch an exhausted page', () async {
    final f = WeiboApplicationFixture();
    final c = _Directory(f.adapter);
    addTearDown(c.onClose);
    await c.loadData();
    expect(c.list.map((r) => r.roomId), [weiboFixtureId, '1022:2321325000000000000001']);
    expect(c.list.every((r) => r.liveStatus == LiveStatus.unknown && !r.hasRealOnlineCount), isTrue);
    expect(c.canLoadMore.value, isFalse);
    await c.loadMoreData();
    expect(f.directoryCalls, 1);
    f.failDirectory = true;
    await c.refreshData();
    expect(c.list, hasLength(2));
    expect(c.errorMsg.value, isNotEmpty);
    f.failDirectory = false;
    await c.retryData();
    expect(c.list, hasLength(2));
    expect(f.directoryCalls, 3);
    expect(c.errorMsg.value, isEmpty);
  });

  test('closing the actual directory cancels I/O and discards a late recommendation', () async {
    final started = Completer<CancelToken>();
    final response = Completer<({int status, String body})>();
    final c = _Directory(
      WeiboSite(
        api: WeiboApi(
          request: (_, _, _, token) {
            started.complete(token);
            return response.future;
          },
        ),
      ),
    );
    final pending = c.loadData();
    final token = await started.future;
    c.onClose();
    response.complete((status: 200, body: jsonEncode(weiboFixture('recommend'))));
    await pending;
    expect(token.isCancelled, isTrue);
    expect(c.list, isEmpty);
  });

  test('actual search performs one exact lookup and never offers web search or another page', () async {
    final f = WeiboApplicationFixture();
    final c = search.SearchController(searchSites: [f.site]);
    addTearDown(c.onClose);
    c.index.value = 1;
    expect(c.canSearchNatively, isTrue);
    expect(c.canOpenWebSearch, isFalse);
    expect(() => c.buildSearchUrl('weibo', 'nickname'), throwsStateError);
    c.searchController.text = weiboFixtureWatch;
    await c.doSearch();
    expect(c.results.single.roomId, weiboFixtureId);
    expect(c.results.single.userId, '101');
    expect(c.results.single.liveStatus, LiveStatus.live);
    expect(c.hasMore.value, isFalse);
    await c.loadMore();
    expect(f.detailCalls, 1);
    c.searchController.text = 'nickname';
    await c.doSearch();
    expect(c.results, isEmpty);
    expect(f.detailCalls, 1);
    expect(f.directoryCalls, 1);
    c.searchController.text = '样本 1';
    await c.doSearch();
    expect(c.results.single.userId, '102');
    expect(c.results.single.liveStatus, LiveStatus.unknown);
    expect(c.hasMore.value, isFalse);
    expect(f.directoryCalls, 2);
    expect(f.detailCalls, 1);
  });

  test('actual search retains replay identity but allows the live-only filter to hide it', () async {
    final f = WeiboApplicationFixture()..status = 3;
    final c = search.SearchController(searchSites: [f.site]);
    addTearDown(c.onClose);
    c.searchController.text = weiboFixtureId;
    await c.doSearch();
    expect(c.results.single.liveStatus, LiveStatus.replay);
    c.setIncludeOffline(false);
    expect(c.results, isEmpty);
    expect(c.hasFilteredOfflineResults, isTrue);
    c.setIncludeOffline(true);
    expect(c.results.single.roomId, weiboFixtureId);
    expect(f.detailCalls, 1);
  });

  test('closing actual search cancels nested adapter I/O and suppresses late results', () async {
    final started = Completer<CancelToken>();
    final response = Completer<({int status, String body})>();
    final adapter = WeiboSite(
      api: WeiboApi(
        request: (_, _, _, token) {
          started.complete(token);
          return response.future;
        },
      ),
    );
    final c = search.SearchController(
      searchSites: [Site(id: 'weibo', name: 'Weibo', logo: '', liveSite: adapter)],
    );
    c.searchController.text = weiboFixtureId;
    final pending = c.doSearch();
    final token = await started.future;
    c.onClose();
    response.complete((status: 200, body: jsonEncode(weiboFixture('live-detail'))));
    await pending;
    expect(token.isCancelled, isTrue);
    expect(c.results, isEmpty);
  });

  for (final raw in [
    weiboFixtureWatch,
    '$weiboFixtureWatch?from=share#live',
    weiboFixtureWatch.replaceFirst('https://weibo.com', 'http://www.weibo.com:80'),
    weiboFixtureWatch.replaceFirst('/p/', '/m/').replaceFirst('1022:', '1022%3a'),
    '  $weiboFixtureWatch  ',
  ]) {
    test('official watch enters both web and shared routes without redirect I/O: $raw', () async {
      expect(WebSearchRoomParser.parse(raw)?.key, 'weibo:$weiboFixtureId');
      expect(LiveUrlTool.containsSupportedLink('直播 $raw'), isTrue);
      expect(await LiveUrlTool.parseLiveUrl('直播 $raw', clientFactory: () => throw StateError('No network')), [
        weiboFixtureId,
        'weibo',
      ]);
    });
  }
  test('Chinese share body is removed before routing the exact broadcast identity', () async {
    final text = '分享 $weiboFixtureWatch。打开应用观看';
    expect(LiveUrlTool.containsSupportedLink(text), isTrue);
    expect(await LiveUrlTool.parseLiveUrl(text, clientFactory: () => throw StateError('No network')), [
      weiboFixtureId,
      'weibo',
    ]);
  });
  for (final raw in [
    weiboFixtureId,
    'https://weibo.com/u/101',
    'https://weibo.com.evil.test/l/wblive/p/show/$weiboFixtureId',
    'https://user@weibo.com/l/wblive/p/show/$weiboFixtureId',
    'https://weibo.com:444/l/wblive/p/show/$weiboFixtureId',
    'ftp://weibo.com/l/wblive/p/show/$weiboFixtureId',
    '$weiboFixtureWatch/.',
    '$weiboFixtureWatch/..',
    '$weiboFixtureWatch/.。继续观看',
    '$weiboFixtureWatch/..)',
    weiboFixtureWatch.replaceFirst('/p/show/', '/p/x/../show/'),
    weiboFixtureWatch.replaceFirst('1022:', '1022%253a'),
    'https://t.cn/fixture',
    'https://weibo.com/l/wblive/app/h5_compatible?live_id=$weiboFixtureId',
  ]) {
    test('non-watch input is not salvaged into a web/share room: $raw', () async {
      expect(WebSearchRoomParser.parse(raw), isNull);
      expect(LiveUrlTool.containsSupportedLink(raw), isFalse);
      expect(await LiveUrlTool.parseLiveUrl(raw, clientFactory: () => throw StateError('No network')), isEmpty);
    });
  }

  for (final android in [false, true]) {
    test('external action uses canonical broadcast URL on android=$android', () async {
      final room = LiveRoom(platform: 'weibo', roomId: weiboFixtureId, userId: '101', link: 'https://evil.test');
      final target = RoomExternalOpener.resolve('weibo', room)!;
      expect(target.web, WeiboLink.url(weiboFixtureId));
      expect(target.native, isNull);
      final launched = <String>[];
      expect(
        await RoomExternalOpener.open(
          site: 'weibo',
          room: room,
          android: android,
          launch: (url) async {
            launched.add(url);
            return true;
          },
        ),
        RoomExternalOpenResult.opened,
      );
      expect(launched, [weiboFixtureWatch]);
      expect(
        await RoomExternalOpener.open(
          site: 'weibo',
          room: LiveRoom(roomId: '101'),
          android: android,
          launch: (_) async => throw StateError('Invalid identity must not reach launcher'),
        ),
        RoomExternalOpenResult.unavailable,
      );
    });
  }

  test('recording and multiview use fresh same-broadcast media rather than cached details', () async {
    final f = WeiboApplicationFixture();
    final recorder = StreamResolverService(siteResolver: (_) => f.adapter);
    final record = await recorder.resolveStream(
      roomId: ' $weiboFixtureId ',
      platform: ' WEIBO ',
      preferredQuality: 'highest',
    );
    expect(record.url, 'https://media.example.test/source-2.flv?token=fixture2');
    expect(record.candidateUrls, [record.url]);
    expect(record.qualityCursorId, 'original');
    expect(record.refreshAt, isNull);
    expect(record.invalidAt, isNull);
    final source = await MultiviewController.resolveStreamForSite(
      LiveRoom(platform: 'weibo', roomId: weiboFixtureId),
      site: f.site,
      preferLowest: false,
    );
    expect(source.url, 'https://media.example.test/source-4.flv?token=fixture4');
    expect(source.lines, [source.url]);
    expect(f.requests.every((uri) => uri.queryParameters['live_id'] == weiboFixtureId), isTrue);
    expect(f.detailCalls, 4);
  });

  for (final restricted in [false, true]) {
    test('recorder surfaces unknown/access metadata without selecting an input: restricted=$restricted', () async {
      final f = WeiboApplicationFixture();
      f.status = restricted ? 1 : 0;
      f.watchLimit = restricted ? 1 : 0;
      final recorder = StreamResolverService(siteResolver: (_) => f.adapter);
      await expectLater(
        recorder.resolveStream(roomId: weiboFixtureId, platform: 'weibo', preferredQuality: 'highest'),
        throwsA(isA<StreamException>().having((e) => e.type, 'type', StreamErrorType.networkError)),
      );
      expect(f.detailCalls, 1);
    });
  }
}
