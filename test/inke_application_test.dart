import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/base/base_page_view.dart';
import 'package:pure_live/common/base/live_directory_controller.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/inke/inke_api.dart';
import 'package:pure_live/core/site/inke/inke_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/multiview/danmaku/multiview_danmaku_session.dart';
import 'package:pure_live/modules/search/search_capability.dart';
import 'package:pure_live/modules/search/web_search_room_parser.dart';
import 'package:pure_live/player/core/playback_header_resolver.dart';
import 'package:pure_live/recorder/services/ffmpeg_header_factory.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';

const _url = 'https://live-pull-ws.ikstatic.cn/live/200_t.flv?wsSecret=fixture';
Map<String, dynamic> _row(int uid) => {'uid': uid, 'live_id': '200', 'nick': 'Fixture', 'stream_addr': _url};
Map<String, dynamic> _info() => {
  'live_uid': '100',
  'liveid': '200',
  'status': 1,
  'media_info': {'inke_id': 100, 'nick': 'Fixture'},
  'live_name': 'Test',
};
({int status, String body}) _ok(Object data) => (status: 200, body: jsonEncode({'error_code': 0, 'data': data}));
InkeSite _site({void Function(String)? called}) => InkeSite(
  api: InkeApi(
    request: (uri, _) async {
      called?.call(uri.path);
      return uri.path.endsWith('live_share_pc')
          ? _ok(_info())
          : _ok({
              'list': [_row(100), _row(101), _row(102)],
            });
    },
  ),
);

const _notice =
    '官网精选目录，非全站列表。部分在播间暂无公开播放地址；支持精确 UID 或官网房间链接查询，昵称搜索与弹幕暂未接入。 '
    'Website showcases, not a full directory. Some live rooms lack a public playback source.';

class _NoticeController extends LiveDirectoryController {
  _NoticeController() : super(directory: _site());
  @override
  String get pageNotice => _notice;
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
  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 15));
  });

  test('registry, search and audience capabilities do not overstate support', () {
    expect(Sites.of(' INKE ').liveSite, isA<InkeSite>());
    expect(Sites.supportSites.where((s) => s.id == 'inke'), hasLength(1));
    expect(Sites.supportSites.map((s) => s.id).toSet(), Sites.supportedSiteIds);
    expect(LiveRoom.audienceCapabilityFor('inke').supportsConcurrentOnline, isFalse);
    expect(LiveSearchCapabilities.forPlatform('inke').coverage, NativeSearchCoverage.showcaseSnapshot);
    expect(LiveSearchCapabilities.forPlatform('inke').supportsPagination, isTrue);
    expect(LiveSearchCapabilities.forPlatform('inke').supportsNativeSearch, isTrue);
    expect(LiveSearchCapabilities.forPlatform('inke').supportsWebSearch, isFalse);
    expect(MultiviewDanmakuSession.isSupportedPlatform('inke'), isFalse);
    final controller = LiveDirectoryController(directory: _site());
    addTearDown(controller.onClose);
    expect(controller.pageNotice, 'inke_directory_scope');
  });

  test('bilingual directory notice describes exact lookup and remaining scope', () {
    final chinese = jsonDecode(File('assets/translations/zh.json').readAsStringSync()) as Map<String, dynamic>;
    final english = jsonDecode(File('assets/translations/en.json').readAsStringSync()) as Map<String, dynamic>;
    expect(chinese['inke_directory_scope'], contains('精确 UID'));
    expect(chinese['inke_directory_scope'], contains('昵称筛选'));
    expect(english['inke_directory_scope'], contains('Exact UID'));
    expect(english['inke_directory_scope'], contains('nickname filtering'));
  });

  test('exact UID and official link lookup use metadata only, including offline state', () async {
    final paths = <String>[];
    final site = _site(called: paths.add);
    final live = await site.searchRooms('100');
    expect(live.single.roomId, '100');
    expect(live.single.isLiveNow, isTrue);
    expect(live.single.data, isNull);
    expect(paths, ['/web/live_share_pc']);
    expect((await site.searchRooms('https://www.inke.cn/liveroom/index.html?uid=100&id=old')).single.roomId, '100');
    expect(paths, ['/web/live_share_pc', '/web/live_share_pc']);
    expect(await site.searchRooms('100', page: 2), isEmpty);
    for (final input in ['https://www.inke.cn/', 'https://www.inke.cn.evil.test/liveroom/index.html?uid=100']) {
      expect(await site.searchRooms(input), isEmpty);
    }
    expect(paths, hasLength(2));

    final offline = InkeSite(
      api: InkeApi(request: (uri, _) async => (status: 200, body: jsonEncode({'error_code': 1099999920, 'data': {}}))),
    );
    final room = (await offline.searchRooms('100')).single;
    expect(room.roomId, '100');
    expect(room.isExplicitlyOfflineNow, isTrue);
    expect(room.title, 'UID 100');
    expect(room.nick, 'UID 100');
  });

  test('nickname search matches only bounded public showcases without media lookup', () async {
    final paths = <String>[];
    final site = InkeSite(
      api: InkeApi(
        request: (uri, _) async {
          paths.add(uri.path);
          return switch (uri.path) {
            '/web/Live_top_pc' => _ok({
              'list': [
                {..._row(100), 'nick': '音乐主播'},
                {..._row(101), 'nick': '聊天主播'},
              ],
            }),
            '/web/Live_channel_pc' => _ok({
              'list': [
                {
                  'tab_key': 'MUSIC',
                  'channel_name': '音乐',
                  'list': [
                    {..._row(100), 'nick': '音乐主播'},
                    {..._row(102), 'nick': '音乐电台'},
                  ],
                },
              ],
            }),
            _ => throw StateError('unexpected ${uri.path}'),
          };
        },
      ),
    );
    expect((await site.searchRooms('音乐', pageSize: 1)).map((room) => room.roomId), ['100']);
    expect((await site.searchRooms('音乐', page: 2, pageSize: 1)).map((room) => room.roomId), ['102']);
    expect(paths, ['/web/Live_top_pc', '/web/Live_channel_pc', '/web/Live_top_pc', '/web/Live_channel_pc']);
    expect(await site.searchRooms('音乐', page: 3, pageSize: 1), isEmpty);
    expect(paths, hasLength(6));
  });

  test('exact lookup preserves access errors and forwards cancellation', () async {
    final token = CancelToken();
    final absent = InkeSite(
      api: InkeApi(
        request: (uri, cancel) async {
          expect(identical(cancel, token), isTrue);
          return (status: 404, body: '');
        },
      ),
    );
    expect(await absent.searchRoomsCancellable('100', cancel: token), isEmpty);
    final denied = InkeSite(api: InkeApi(request: (_, _) async => (status: 403, body: '')));
    await expectLater(
      denied.searchRooms('100'),
      throwsA(isA<InkeException>().having((error) => error.kind, 'kind', InkeFailure.access)),
    );
    final cancelled = CancelToken()..cancel();
    await expectLater(
      absent.searchRoomsCancellable('100', cancel: cancelled),
      throwsA(isA<InkeException>().having((error) => error.kind, 'kind', InkeFailure.cancelled)),
    );
  });

  test('real sharing entry points use stable UID without sending a request', () async {
    const link = 'https://www.inke.cn/liveroom/index.html?uid=100&id=199';
    expect(WebSearchRoomParser.parse(link)?.key, 'inke:100');
    expect(LiveUrlTool.containsSupportedLink('share $link'), isTrue);
    expect(await LiveUrlTool.parseLiveUrl(link, clientFactory: () => throw StateError('no network expected')), [
      '100',
      'inke',
    ]);
    for (final bad in [
      link.replaceAll('inke.cn', 'inke.cn.evil.test'),
      link.replaceAll('www.', 'user@www.'),
      '$link&uid=101',
    ]) {
      expect(LiveUrlTool.containsSupportedLink(bad), isFalse);
      expect(await LiveUrlTool.parseLiveUrl(bad), isEmpty);
    }
  });

  test('external room entry needs matching UID and a real broadcast ID', () {
    const valid = 'https://www.inke.cn/liveroom/index.html?uid=100&id=199';
    expect(
      InkeSite.externalRoomUrl(LiveRoom(platform: 'inke', link: 'https://example.test/?id=199')),
      '${InkeApi.origin}/',
    );
    final room = LiveRoom(platform: 'inke', roomId: '100', link: valid);
    expect(InkeSite.externalRoomUrl(room), valid);
    for (final link in <String?>[
      null,
      '',
      '  ',
      valid.split('&id=').first,
      '$valid&id=200',
      valid.replaceFirst('uid=100', 'uid=101'),
      valid.replaceFirst('id=199', 'id=abc'),
      valid.replaceFirst('inke.cn', 'inke.cn.evil.test'),
      'https://www.inke.cn/liveroom/index.html?uid=100&id=%FF',
    ]) {
      room.link = link;
      expect(InkeSite.externalRoomUrl(room), '${InkeApi.origin}/', reason: '$link');
    }
  });

  test('legacy slicing and native showcase preserve all rows at small page sizes', () async {
    final site = _site();
    expect((await site.getRecommendRooms(pageSize: 2)).map((r) => r.roomId), ['100', '101']);
    expect((await site.getRecommendRooms(page: 2, pageSize: 2)).single.roomId, '102');
    expect(await site.getRecommendRooms(page: 9223372036854775807, pageSize: 9223372036854775807), isEmpty);
    final page = await site.getDirectoryPage();
    expect(page.rooms, hasLength(3));
    expect(page.hasMore, isFalse);
  });

  test('card refresh is metadata-only and playback recovery renews current broadcast', () async {
    final calls = <String>[];
    final site = _site(called: calls.add);
    final card = await site.getRoomDetailForRefresh(roomId: '100', platform: 'inke');
    expect(card.data, isNull);
    expect(calls, ['/web/live_share_pc']);
    final detail = await site.getRoomDetail(roomId: '100', platform: 'inke');
    final quality = (await site.getPlayQualites(detail: detail)).single;
    final recovery = await site.resolvePlayUrlsForRecovery(detail: detail, quality: quality);
    expect(recovery.urls, [_url]);
    expect(recovery.appliedQualityData, 'flv');
    expect(calls.where((p) => p.endsWith('live_share_pc')), hasLength(3));
    expect(calls.where((p) => p.endsWith('Live_top_pc')), hasLength(2));
  });

  test('production recorder resolves and renews FLV with shared anonymous headers', () async {
    var calls = 0;
    final resolver = StreamResolverService(siteResolver: (_) => _site(called: (_) => calls++));
    final first = await resolver.resolveStream(roomId: '100', platform: 'inke', preferredQuality: 'flv');
    final next = await resolver.resolveStream(
      roomId: '100',
      platform: 'inke',
      preferredQuality: 'flv',
      previousQualityId: first.qualityCursorId,
      previousLineIndex: first.lineIndex,
      renewCurrent: true,
    );
    expect(first.url, _url);
    expect(next.qualityCursorId, 'flv');
    expect(calls, 4);
    expect(first.invalidAt, isNull, reason: 'no unverified lease timestamp promise');
    final playback = await PlaybackHeaderResolver.resolve(platform: 'inke', roomId: '100');
    expect(await FFmpegHeaderFactory.build(platform: 'inke', roomId: '100'), playback);
    expect(playback['referer'], '${InkeApi.origin}/');
    expect(playback, isNot(contains('cookie')));
  });

  test('recording preserves explicit offline versus retryable metadata failure', () async {
    for (final offline in [false, true]) {
      final site = InkeSite(
        api: InkeApi(
          request: (_, _) async =>
              offline ? (status: 200, body: '{"error_code":1099999920,"data":null}') : (status: 503, body: ''),
        ),
      );
      await expectLater(
        StreamResolverService(siteResolver: (_) => site)
            .resolveStream(roomId: '100', platform: 'inke', preferredQuality: 'flv'),
        throwsA(
          isA<StreamException>()
              .having((e) => e.type, 'type', offline ? StreamErrorType.notLive : StreamErrorType.networkError)
              .having((e) => e.retryable, 'retryable', !offline),
        ),
      );
    }
  });

  testWidgets('directory scope remains visible beside actual cards on a narrow large-text page', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _NoticeController();
    controller.list.assignAll([LiveRoom(platform: 'inke', roomId: '100')]);
    addTearDown(controller.onClose);
    await tester.pumpWidget(
      GetMaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: BasePageView<LiveDirectoryController, LiveRoom>(
            controller: controller,
            showScrollToTopBtn: false,
            contentBuilder: (_, rows, scroll) =>
                ListView(controller: scroll, children: [for (final r in rows) Text('room:${r.roomId}')]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_notice), findsOneWidget);
    expect(find.text('room:100'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    expect(tester.takeException(), isNull);
  });
}
