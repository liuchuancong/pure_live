import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/base/base_page_scroll_bone.dart';
import 'package:pure_live/common/base/live_directory_controller.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/core/interface/live_directory.dart';
import 'package:pure_live/core/interface/live_search.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/huajiao/huajiao_api.dart';
import 'package:pure_live/core/site/huajiao/huajiao_link.dart';
import 'package:pure_live/core/site/huajiao/huajiao_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/modules/area_rooms/area_rooms_binding.dart';
import 'package:pure_live/modules/live_play/services/room_external_opener.dart';
import 'package:pure_live/modules/popular/popular_controller.dart';
import 'package:pure_live/modules/search/search_capability.dart';
import 'package:pure_live/modules/search/web_search_room_parser.dart';
import 'package:pure_live/player/core/playback_header_resolver.dart';
import 'package:pure_live/recorder/services/ffmpeg_header_factory.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';

Map<String, dynamic> _broadcast({int bid = 200, int uid = 100}) {
  final data =
      jsonDecode(File('test/fixtures/huajiao/broadcast.json').readAsStringSync())['data'] as Map<String, dynamic>;
  data['feed']['feed']['relateid'] = bid;
  data['feed']['author']['uid'] = uid;
  for (final key in ['main', 'pull_m3u8', 'h264_url']) {
    data['live'][key] = (data['live'][key] as String).replaceAll('fixture-h265', '$bid');
  }
  return data;
}

Object _owner(int living) => {
  'base': {'uid': 100, 'nickname': 'Fixture'},
  'living': living,
};
Object _page(List<int> owners, {int next = 30, bool more = true}) => {
  'offset': '$next',
  'more': more,
  'sections': [
    {
      'feeds': [for (final uid in owners) _broadcast(uid: uid, bid: uid + 1000)['feed']],
    },
  ],
  'feeds': [],
};
({int status, String body}) _ok(Object? data) => (status: 200, body: jsonEncode({'errno': 0, 'data': data}));
HuajiaoApi _api({int Function()? living, void Function(Uri)? called}) => HuajiaoApi(
  request: (uri, _) async {
    called?.call(uri);
    final bid = living?.call() ?? 200;
    if (uri.path == '/Web/UserInfo/full') return _ok(_owner(bid));
    if (uri.path == '/api/getFeedInfo') return _ok(_broadcast(bid: int.parse(uri.queryParameters['liveid']!)));
    return _ok(_page([100], more: false));
  },
);
Matcher _failure(HuajiaoFailure kind) => throwsA(isA<HuajiaoException>().having((e) => e.kind, 'kind', kind));

class _Controller extends LiveDirectoryController {
  _Controller(LiveSiteDirectoryPager source, {this.desktop = true, super.maxRequestsPerLoad, super.maxBufferedItems})
    : super(directory: source);
  final bool desktop;
  @override
  bool get usesDesktopPagination => desktop;
  @override
  Future<bool> checkNetworkBeforeRequest() async => true;
  @override
  void handleError(Object error, {bool showPageError = false}) {
    errorMsg.value = error.toString();
    pageError.value = true;
  }
}

class _Cursor extends LiveSite implements LiveSiteCursorDirectoryPager {
  _Cursor(this.fetch);
  final Future<LiveDirectoryPage> Function(int, String?) fetch;
  @override
  Future<LiveDirectoryPage> getDirectoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) =>
      throw StateError('Legacy cursor path used');
  @override
  Future<LiveDirectoryPage> getDirectoryPageAtCursor({
    required int page,
    String? cursor,
    LiveArea? category,
    CancelToken? cancel,
  }) => fetch(page, cursor);
}

LiveDirectoryPage _cursorPage(int page, String? next, List<String> ids, {bool more = true}) => LiveDirectoryPage(
  page: page,
  nextCursor: next,
  hasMore: more,
  rooms: ids.map((id) => LiveRoom(platform: 'fixture', roomId: id, status: true)),
);

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

  test('Huajiao registration, scope and real popular/category factories', () async {
    final site = Sites.of(' HUAJIAO ');
    expect(site.liveSite, isA<HuajiaoSite>());
    expect(Sites.supportSites.where((s) => s.id == 'huajiao'), hasLength(1));
    expect(Sites.supportSites.map((s) => s.id).toSet(), Sites.supportedSiteIds);
    expect(LiveSearchCapabilities.forPlatform('huajiao').supportsWebSearch, isFalse);
    expect(LiveSearchCapabilities.forPlatform('huajiao').coverage, NativeSearchCoverage.showcaseSnapshot);
    expect(LiveSearchCapabilities.forPlatform('huajiao').supportsPagination, isTrue);
    expect(LiveSearchCapabilities.forPlatform('huajiao').supportsNativeSearch, isTrue);
    expect(site.liveSite, isA<LiveCancellableSearch>());
    expect(LiveRoom.audienceCapabilityFor('huajiao').supportsConcurrentOnline, isFalse);
    final popular = PopularController();
    addTearDown(popular.onClose);
    popular.initControllers([site]);
    expect(Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: 'huajiao'), isA<LiveDirectoryController>());
    final area = (await site.liveSite.getCategores(1, 30)).single.children.single;
    final controller = AreaRoomsBinding.createController(site, area);
    addTearDown(controller.onClose);
    expect(controller, isA<LiveDirectoryController>());
    expect((controller as LiveDirectoryController).pageNotice, 'huajiao_directory_scope');
  });

  test('server cursor is neither displayed row count nor page-size multiplication', () async {
    final offsets = <String>[];
    final source = HuajiaoSite(
      api: HuajiaoApi(
        request: (uri, _) async {
          final offset = uri.queryParameters['offset']!;
          offsets.add(offset);
          return _ok(switch (offset) {
            '0' => _page([], next: 73),
            '73' => _page([100, 100], next: 91),
            _ => _page([101], next: 111, more: false),
          });
        },
      ),
    );
    final controller = _Controller(source);
    addTearDown(controller.onClose);
    controller.pageSize.value = 2;
    await controller.loadData();
    expect(offsets, ['0', '73', '91']);
    expect(controller.list.map((r) => r.roomId), ['100', '101']);
    expect(controller.canLoadMore.value, isFalse);
    expect(controller.totalCount.value, 2);
    expect(controller.list.first.popularity, '1828');
    expect(controller.list.first.onlineViewers, isEmpty);
  });

  test('separate controllers on one site have independent cursor generations', () async {
    final offsets = <String>[];
    final source = HuajiaoSite(
      api: HuajiaoApi(
        request: (uri, _) async {
          final offset = uri.queryParameters['offset']!;
          offsets.add(offset);
          return _ok(_page([offset == '0' ? 100 : 101], next: offset == '0' ? 73 : 91));
        },
      ),
    );
    final a = _Controller(source);
    final b = _Controller(source);
    addTearDown(a.onClose);
    addTearDown(b.onClose);
    a.pageSize.value = 1;
    b.pageSize.value = 1;
    await a.loadData();
    await a.goToPage(2);
    await b.loadData();
    await b.goToPage(2);
    expect(offsets, ['0', '73', '0', '73']);
  });

  test('mobile load-more appends cursor pages without repeating or dropping cards', () async {
    final cursors = <String?>[];
    final source = _Cursor((page, cursor) async {
      cursors.add(cursor);
      return _cursorPage(page, 'next', page == 1 ? ['A', 'B'] : ['C', 'D'], more: page == 1);
    });
    final c = _Controller(source, desktop: false);
    addTearDown(c.onClose);
    c.pageSize.value = 2;
    await c.loadData();
    expect(c.list.map((r) => r.roomId), ['A', 'B']);
    await c.loadMoreData();
    expect(c.list.map((r) => r.roomId), ['A', 'B', 'C', 'D']);
    expect(cursors, [null, 'next']);
    expect(c.canLoadMore.value, isFalse);
  });

  test('capacity failure does not commit a partial native page or its cursor', () async {
    final cursors = <String?>[];
    var smaller = false;
    final source = _Cursor((page, cursor) async {
      cursors.add(cursor);
      return _cursorPage(page, 'uncommitted', smaller ? ['A'] : ['A', 'B'], more: !smaller);
    });
    final c = _Controller(source, maxBufferedItems: 1);
    addTearDown(c.onClose);
    c.pageSize.value = 1;
    await c.loadData();
    expect(c.list, isEmpty);
    expect(c.pageError.value, isTrue);
    smaller = true;
    await c.retryData();
    expect(cursors, [null, null]);
    expect(c.list.single.roomId, 'A');
  });

  test('partial refresh retry resumes its own cursor rather than the old catalogue', () async {
    var failRefresh = false;
    var firstCalls = 0;
    final requests = <String?>[];
    final source = _Cursor((page, cursor) async {
      requests.add(cursor);
      if (cursor == null) {
        firstCalls++;
        return _cursorPage(page, firstCalls == 1 ? 'old-1' : 'new-1', [firstCalls == 1 ? 'oldA' : 'newA']);
      }
      if (cursor == 'new-1' && failRefresh) throw StateError('fixture');
      return _cursorPage(page, '$cursor-next', ['$cursor-row']);
    });
    final c = _Controller(source);
    addTearDown(c.onClose);
    c.pageSize.value = 2;
    await c.loadData();
    expect(c.list.map((r) => r.roomId), ['oldA', 'old-1-row']);
    failRefresh = true;
    await c.refreshData();
    expect(c.pageError.value, isTrue);
    expect(c.list.map((r) => r.roomId), ['newA']);
    failRefresh = false;
    await c.retryData();
    expect(c.list.map((r) => r.roomId), ['newA', 'new-1-row']);
    expect(requests, [null, 'old-1', null, 'new-1', 'new-1']);
  });

  test('empty failed refresh retains old visible rows and its exact cursor', () async {
    var initial = true;
    final cursors = <String?>[];
    final source = _Cursor((page, cursor) async {
      cursors.add(cursor);
      if (cursor == null) {
        final old = initial;
        initial = false;
        return _cursorPage(page, old ? 'old' : 'fresh', old ? ['A'] : []);
      }
      if (cursor == 'fresh') throw StateError('fixture');
      return _cursorPage(page, 'old-next', ['B']);
    });
    final c = _Controller(source);
    addTearDown(c.onClose);
    c.pageSize.value = 1;
    await c.loadData();
    await c.refreshData();
    expect(c.list.single.roomId, 'A');
    await c.goToPage(2);
    expect(c.list.single.roomId, 'B');
    expect(cursors, [null, null, 'fresh', 'old']);
  });

  test('empty cursor pages respect per-load budget and retry continues committed cursor', () async {
    final cursors = <String?>[];
    final source = _Cursor((page, cursor) async {
      cursors.add(cursor);
      return _cursorPage(page, 'cursor-$page', page < 4 ? [] : ['A'], more: page < 4);
    });
    final c = _Controller(source, maxRequestsPerLoad: 2);
    addTearDown(c.onClose);
    c.pageSize.value = 1;
    await c.loadData();
    expect(c.pageError.value, isTrue);
    expect(c.pageEmpty.value, isFalse);
    await c.retryData();
    expect(c.list.single.roomId, 'A');
    expect(cursors, [null, 'cursor-1', 'cursor-2', 'cursor-3']);
  });

  test('nonadvancing cursor does not commit its rows and retries the same input', () async {
    final cursors = <String?>[];
    final source = _Cursor((page, cursor) async {
      cursors.add(cursor);
      return _cursorPage(page, cursor, ['bad']);
    });
    final c = _Controller(source);
    addTearDown(c.onClose);
    c.pageSize.value = 1;
    await c.loadData();
    await c.retryData();
    expect(c.list, isEmpty);
    expect(cursors, [null, null]);
    expect(c.pageError.value, isTrue);
  });

  test('metadata refresh and serialisation keep UID, never broadcast or signed media', () async {
    final paths = <Uri>[];
    final source = HuajiaoSite(api: _api(called: paths.add));
    final meta = await source.getRoomDetailForRefresh(roomId: '100', platform: 'huajiao');
    expect(paths.map((u) => u.path), ['/Web/UserInfo/full']);
    expect(meta.roomId, '100');
    expect(meta.data, isNull);
    final full = await source.getRoomDetail(roomId: '100', platform: 'huajiao');
    final json = full.toJson();
    expect(json['roomId'], '100');
    expect(jsonEncode(json), isNot(contains('fixture%2Bonly')));
    expect(json.containsKey('data'), isFalse);
    expect(full.link, HuajiaoLink.ownerUrl('100'));
    expect(RoomExternalOpener.resolve('huajiao', LiveRoom.fromJson(json))!.web, HuajiaoLink.ownerUrl('100'));
  });

  test('exact Huajiao ID and verified profile link search include offline owners without media', () async {
    final calls = <Uri>[];
    final source = HuajiaoSite(
      api: _api(living: () => 0, called: calls.add),
    );
    for (final query in ['100', 'https://h.huajiao.com/site/profile_100.html']) {
      final room = (await source.searchRooms(query)).single;
      expect(room.roomId, '100');
      expect(room.nick, 'Fixture');
      expect(room.link, 'https://h.huajiao.com/site/profile_100.html');
      expect(room.isExplicitlyOfflineNow, isTrue);
      expect(room.watching, isEmpty);
      expect(room.onlineViewers, isEmpty);
    }
    expect(calls.map((uri) => uri.path), ['/Web/UserInfo/full', '/Web/UserInfo/full']);
    expect(calls.map((uri) => uri.queryParameters['uid']), ['100', '100']);
  });

  test('search has one bounded identity request and ignores malformed identities and broadcast links', () async {
    final calls = <Uri>[];
    final source = HuajiaoSite(api: _api(called: calls.add));
    for (final query in ['000100', 'https://h.huajiao.com/l/index?liveid=200', 'https://evil.test/user/100']) {
      expect(await source.searchRooms(query), isEmpty);
    }
    expect(await source.searchRooms('100', page: 2), isEmpty);
    expect(calls, isEmpty);
    final room = (await source.searchRooms('100')).single;
    expect(room.isLiveNow, isTrue);
    expect(room.status, isTrue);
    expect(room.audienceMetricType, AudienceMetricType.unknown);
    expect(calls.map((uri) => uri.path), ['/Web/UserInfo/full']);
  });

  test('keyword search filters only three public recommendation pages and paginates stable matches', () async {
    final calls = <int>[];
    final source = HuajiaoSite(
      api: HuajiaoApi(
        request: (uri, _) async {
          expect(uri.path, '/feed/getLives4H5');
          final offset = int.parse(uri.queryParameters['offset']!);
          calls.add(offset);
          final owners = switch (offset) {
            0 => [100],
            30 => [200, 201],
            60 => [201, 202],
            _ => throw StateError('search scanned beyond its public window'),
          };
          final data = _page(owners, next: offset + 30) as Map<String, dynamic>;
          final feeds = (data['sections'] as List).single['feeds'] as List;
          for (final row in feeds) {
            final uid = (row['author']['uid'] as int);
            row['author']['nickname'] = uid == 100 ? 'Other' : 'Key $uid';
            row['feed']['title'] = uid == 100 ? 'Other title' : 'Public $uid';
          }
          return _ok(data);
        },
      ),
    );
    expect(source.supportsSearchPaginationFor('Key'), isTrue);
    expect(source.supportsSearchPaginationFor('100'), isFalse);
    expect(source.supportsSearchPaginationFor('https://h.huajiao.com/site/profile_100.html'), isFalse);
    expect((await source.searchRooms('Key', pageSize: 1)).map((room) => room.roomId), ['200']);
    expect((await source.searchRooms('Key', page: 2, pageSize: 1)).map((room) => room.roomId), ['201']);
    expect((await source.searchRooms('Key', page: 3, pageSize: 1)).map((room) => room.roomId), ['202']);
    expect(await source.searchRooms('Key', page: 91, pageSize: 1), isEmpty);
    expect(calls, [0, 30, 0, 30, 0, 30, 60]);
  });

  test('keyword search forwards cancellation and does not advance its cursor after cancellation', () async {
    final calls = <int>[];
    final token = CancelToken();
    final source = HuajiaoSite(
      api: HuajiaoApi(
        request: (uri, cancel) async {
          expect(cancel, same(token));
          calls.add(int.parse(uri.queryParameters['offset']!));
          token.cancel();
          return _ok(_page([100], next: 30));
        },
      ),
    );
    await expectLater(source.searchRoomsCancellable('Fixture', cancel: token), _failure(HuajiaoFailure.cancelled));
    expect(calls, [0]);
  });

  test('unknown Huajiao UID is empty search while schema and cancellation stay errors', () async {
    final missing = HuajiaoSite(api: HuajiaoApi(request: (_, _) async => _ok({'base': [], 'living': 0})));
    expect(await missing.searchRooms('9999999999999999'), isEmpty);
    final malformed = HuajiaoSite(api: HuajiaoApi(request: (_, _) async => _ok({'base': null, 'living': 0})));
    await expectLater(malformed.searchRooms('100'), _failure(HuajiaoFailure.schema));
    final token = CancelToken();
    final cancelled = HuajiaoSite(
      api: HuajiaoApi(
        request: (_, cancel) async {
          expect(cancel, same(token));
          return _ok(_owner(0));
        },
      ),
    );
    expect((await cancelled.searchRoomsCancellable('100', cancel: token)).single.roomId, '100');
    token.cancel();
    await expectLater(cancelled.searchRoomsCancellable('100', cancel: token), _failure(HuajiaoFailure.cancelled));
  });

  test('legacy pages replay server offsets; invalid cursor/category do not send requests', () async {
    final offsets = <String>[];
    final source = HuajiaoSite(
      api: HuajiaoApi(
        request: (uri, _) async {
          final offset = uri.queryParameters['offset']!;
          offsets.add(offset);
          return _ok(_page([offset == '0' ? 100 : 101], next: offset == '0' ? 73 : 91));
        },
      ),
    );
    expect((await source.getDirectoryPage(page: 2)).rooms.single.roomId, '101');
    expect(offsets, ['0', '73']);
    for (final area in [
      LiveArea(platform: 'other', areaType: 'h5', areaId: 'live5'),
      LiveArea(platform: 'huajiao', areaType: 'h5', areaId: 'unknown'),
    ]) {
      await expectLater(source.getDirectoryPageAtCursor(page: 1, category: area), _failure(HuajiaoFailure.schema));
    }
    await expectLater(source.getDirectoryPageAtCursor(page: 2), _failure(HuajiaoFailure.schema));
    await expectLater(source.getDirectoryPageAtCursor(page: 1, cursor: '73'), _failure(HuajiaoFailure.schema));
    await expectLater(
      source.getDirectoryPageAtCursor(page: 2, cursor: '73&name=other'),
      _failure(HuajiaoFailure.schema),
    );
    expect(offsets, ['0', '73']);
  });

  test('late pre-refresh response cannot publish cards or cursor into new generation', () async {
    final late = Completer<LiveDirectoryPage>();
    var calls = 0;
    final cursors = <String?>[];
    final source = _Cursor((page, cursor) {
      cursors.add(cursor);
      calls++;
      if (calls == 1) return late.future;
      return Future.value(_cursorPage(page, 'new-cursor', ['new'], more: false));
    });
    final c = _Controller(source);
    addTearDown(c.onClose);
    c.pageSize.value = 1;
    final oldLoad = c.loadData();
    await Future<void>.delayed(Duration.zero);
    final refresh = c.refreshData();
    late.complete(_cursorPage(1, 'stale-cursor', ['stale']));
    await oldLoad;
    await refresh;
    expect(c.list.single.roomId, 'new');
    expect(cursors, [null, null]);
  });

  test('broadcast identity mismatch and missing author do not become saved owner IDs', () async {
    final mismatch = HuajiaoApi(request: (_, _) async => _ok(_broadcast(bid: 201)));
    await expectLater(
      LiveUrlTool.parseLiveUrl('https://www.huajiao.com/l/200', huajiaoApi: mismatch),
      _failure(HuajiaoFailure.identity),
    );
    final missing = HuajiaoApi(
      request: (_, _) async => _ok({
        'feed': {
          'feed': {'point': ''},
        },
        'live': null,
      }),
    );
    await expectLater(
      LiveUrlTool.parseLiveUrl('https://www.huajiao.com/l/200', huajiaoApi: missing),
      _failure(HuajiaoFailure.mediaUnavailable),
    );
  });

  test('playback, recording and recovery reacquire current broadcast and stable format choices', () async {
    var current = 200;
    final source = HuajiaoSite(api: _api(living: () => current));
    final detail = await source.getRoomDetail(roomId: '100', platform: 'huajiao');
    final qualities = await source.getPlayQualites(detail: detail);
    expect(qualities.map((q) => q.selectionId), ['hls', 'flv']);
    final flv = qualities.last;
    expect((await source.getPlayUrls(detail: detail, quality: flv)).single, contains('/200.flv'));
    final recorder = StreamResolverService(siteResolver: (_) => source);
    expect(
      (await recorder.resolveStream(roomId: '100', platform: 'huajiao', preferredQuality: 'flv')).url,
      contains('/200.flv'),
    );
    current = 201;
    expect((await source.resolvePlayUrlsForRecovery(detail: detail, quality: flv)).urls.single, contains('/201.flv'));
    expect(
      (await recorder.resolveStream(roomId: '100', platform: 'huajiao', preferredQuality: 'flv')).url,
      contains('/201.flv'),
    );
    await expectLater(
      source.getPlayUrls(
        detail: detail,
        quality: LivePlayQuality(id: '4k', quality: '4K'),
      ),
      _failure(HuajiaoFailure.mediaUnavailable),
    );
  });

  test('only explicit owner zero is offline; access failure remains an error', () async {
    final offline = HuajiaoSite(api: _api(living: () => 0));
    final detail = await offline.getRoomDetail(roomId: '100', platform: 'huajiao');
    expect(detail.isExplicitlyOfflineNow, isTrue);
    expect(await offline.getPlayQualites(detail: detail), isEmpty);
    final unavailable = HuajiaoSite(api: HuajiaoApi(request: (_, _) async => (status: 403, body: '')));
    await expectLater(
      unavailable.getRoomDetailForRefresh(roomId: '100', platform: 'huajiao'),
      _failure(HuajiaoFailure.access),
    );
    await expectLater(
      unavailable.getRoomDetailForRecording(roomId: '100', platform: 'huajiao'),
      _failure(HuajiaoFailure.access),
    );
  });

  test('shared media headers are identical for playback and FFmpeg', () async {
    final playback = await PlaybackHeaderResolver.resolve(platform: 'huajiao', roomId: '100');
    expect(await FFmpegHeaderFactory.build(platform: 'huajiao', roomId: '100'), playback);
    expect(playback['referer'], 'https://h.huajiao.com/');
    expect(playback.containsKey('cookie'), isFalse);
  });

  for (final url in [
    'https://h.huajiao.com/site/profile_100.html',
    'https://www.huajiao.com/user/100',
    'http://huajiao.com/user/100/',
  ]) {
    test('owner link maps to persistent UID: $url', () async {
      expect(HuajiaoLink.parse(url)!.kind, HuajiaoLinkKind.owner);
      expect(LiveUrlTool.containsSupportedLink(url), isTrue);
      expect(await LiveUrlTool.parseLiveUrl(url), ['100', 'huajiao']);
      expect(WebSearchRoomParser.parse(url)!.roomId, '100');
    });
  }
  for (final url in ['https://h.huajiao.com/l/index?liveid=200', 'https://www.huajiao.com/l/200']) {
    test('broadcast link resolves author instead of saving broadcast: $url', () async {
      final api = HuajiaoApi(
        request: (_, _) async {
          final data = _broadcast();
          data['live'] = null;
          data['feed']['feed']['origin_status'] = 0;
          return _ok(data);
        },
      );
      expect(await LiveUrlTool.parseLiveUrl(url, huajiaoApi: api), ['100', 'huajiao']);
      expect(WebSearchRoomParser.parse(url), isNull);
    });
  }
  for (final url in [
    'https://h.huajiao.com.evil.test/site/profile_100.html',
    'https://x@h.huajiao.com/site/profile_100.html',
    'https://h.huajiao.com:8787/site/profile_100.html',
    'file:///site/profile_100.html',
    'https://h.huajiao.com/site/profile_0.html',
    'https://h.huajiao.com/site/profile_100.html/extra',
    'https://h.huajiao.com/l/index?liveid=200&liveid=201',
    'https://h.huajiao.com/l/index?liveid=200%26uid%3D100',
    'https://www.huajiao.com/search/100',
  ]) {
    test('unrelated or ambiguous link rejected: $url', () {
      expect(HuajiaoLink.parse(url), isNull);
      expect(LiveUrlTool.containsSupportedLink(url), isFalse);
    });
  }

  test('broadcast share timeout and cancellation discard late identity results', () async {
    for (final cancelEarly in [false, true]) {
      final response = Completer<({int status, String body})>();
      CancelToken? owned;
      final api = HuajiaoApi(
        request: (_, token) {
          owned = token;
          return response.future;
        },
      );
      final caller = CancelToken();
      final future = LiveUrlTool.parseLiveUrl(
        'https://h.huajiao.com/l/index?liveid=200',
        huajiaoApi: api,
        cancelToken: caller,
        timeout: const Duration(milliseconds: 30),
      );
      if (cancelEarly) caller.cancel();
      expect(await future, isEmpty);
      expect(owned!.isCancelled, isTrue);
      response.complete(_ok(_broadcast()));
      await Future<void>.delayed(Duration.zero);
    }
  });
}
