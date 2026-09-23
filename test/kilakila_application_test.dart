import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/base/live_directory_controller.dart';
import 'package:pure_live/common/base/base_page_scroll_bone.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/core/interface/live_search.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/kilakila/kilakila_api.dart';
import 'package:pure_live/core/site/kilakila/kilakila_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/modules/live_play/services/room_external_opener.dart';
import 'package:pure_live/modules/popular/popular_controller.dart';
import 'package:pure_live/modules/area_rooms/area_rooms_binding.dart';
import 'package:pure_live/modules/multiview/danmaku/multiview_danmaku_session.dart';
import 'package:pure_live/modules/search/search_capability.dart';
import 'package:pure_live/modules/search/web_search_room_parser.dart';
import 'package:pure_live/player/core/playback_header_resolver.dart';
import 'package:pure_live/plugins/share_command_handler.dart';
import 'package:pure_live/recorder/services/ffmpeg_header_factory.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';

const uid = '100';
const first = '9007199254740993123';
const second = '9007199254740993456';
String media(String room, [String protocol = 'flv']) =>
    'https://pull.live.hongrenshuo.com.cn/hrs/$room.${protocol == 'flv' ? 'flv' : 'm3u8'}?auth_key=fixture';
Map<String, dynamic> user([String owner = uid]) => {'id': owner, 'nickname': 'Fixture'};
Map<String, dynamic> card([String room = first, String owner = uid]) => {
  'roomIdStr': room,
  'uid': owner,
  'title': 'Fixture live',
  'goldPrice': 0,
  'status': 4,
  'watchNumber': 1234,
  'flvPlayUrl': media(room),
  'hlsPlayUrl': media(room, 'hls'),
};
({int status, String body}) ok(Object data) => (status: 200, body: jsonEncode(data));
Object profile(Object current) => {
  'code': 200,
  'data': {'userResp': user(), 'liveCard': current},
};
Object detail(String room, {Map<String, dynamic> changes = const {}}) => {
  'h': {'code': 200, 'success': true},
  'b': {...card(room), 'userInfo': user(), ...changes},
};
Object directory(Uri uri, List<Map<String, dynamic>> cards, {bool more = false}) => {
  'code': 200,
  'data': {
    'body': {
      'h': {'code': 200, 'success': true},
      'b': {
        'pageNo': int.parse(uri.queryParameters['pageNo']!),
        'pageSize': int.parse(uri.queryParameters['pageSize']!),
        'isLastPage': !more,
        'data': [
          for (final c in cards) {'dataType': 8, 'roomResq': c, 'userResp': user(c['uid'] as String)},
        ],
      },
    },
  },
};
KilakilaApi api({
  String Function()? current,
  Object Function()? advertised,
  void Function(Uri)? called,
  Map<String, dynamic> changes = const {},
}) => KilakilaApi(
  request: (uri, _) async {
    called?.call(uri);
    final room = current?.call() ?? first;
    if (uri.path == '/Tg/personalH5') return ok(profile(advertised?.call() ?? card(room)));
    if (uri.path == '/LiveRoom/getRoomInfo') return ok(detail(uri.queryParameters['roomId']!, changes: changes));
    return ok(directory(uri, [card(room)]));
  },
);

class _Controller extends LiveDirectoryController {
  _Controller(KilakilaSite source) : super(directory: source);
  @override
  bool get usesDesktopPagination => true;
  @override
  Future<bool> checkNetworkBeforeRequest() async => true;
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

  test('registration is unique and precise search capabilities stay explicit', () {
    expect(Sites.of(' KILAKILA ').liveSite, isA<KilakilaSite>());
    expect(Sites.supportSites.map((s) => s.id).toSet(), Sites.supportedSiteIds);
    expect(Sites.supportSites.where((s) => s.id == 'kilakila'), hasLength(1));
    expect(LiveRoom.audienceCapabilityFor('kilakila').supportsConcurrentOnline, isFalse);
    expect(LiveSearchCapabilities.forPlatform('kilakila').coverage, NativeSearchCoverage.liveAndOffline);
    expect(LiveSearchCapabilities.forPlatform('kilakila').supportsNativeSearch, isTrue);
    expect(LiveSearchCapabilities.forPlatform('kilakila').supportsPagination, isTrue);
    expect(LiveSearchCapabilities.forPlatform('kilakila').supportsWebSearch, isTrue);
    expect(Sites.of('kilakila').liveSite, isA<LiveCancellableSearch>());
    expect(MultiviewDanmakuSession.isSupportedPlatform('kilakila'), isFalse);
    final controller = _Controller(KilakilaSite(api: api()));
    addTearDown(controller.onClose);
    expect(controller.pageNotice, 'kilakila_directory_scope');
  });
  test('actual popular and category factories select native paging for Kilakila', () async {
    final site = Sites.of('kilakila');
    final popular = PopularController();
    addTearDown(popular.onClose);
    popular.initControllers([site]);
    expect(Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: site.id), isA<LiveDirectoryController>());
    final area = (await site.liveSite.getCategores(1, 30)).single.children.last;
    final controller = AreaRoomsBinding.createController(site, area);
    addTearDown(controller.onClose);
    expect(controller, isA<LiveDirectoryController>());
    expect((controller as LiveDirectoryController).category, same(area));
  });
  test('categories use only verified live timelines and validate saved identity', () async {
    final calls = <Uri>[];
    final site = KilakilaSite(api: api(called: calls.add));
    final categories = (await site.getCategores(1, 30)).single.children;
    expect(categories.map((c) => c.areaId), ['0', '107']);
    expect(await site.getCategores(2, 30), isEmpty);
    await site.getCategoryRooms(categories.last, page: 2, pageSize: 7);
    expect(calls.single.queryParameters, containsPair('type', '107'));
    expect(calls.single.queryParameters, containsPair('pageNo', '2'));
    expect(calls.single.queryParameters, containsPair('pageSize', '7'));
    for (final bad in [
      LiveArea(platform: 'other', areaType: 'timeline', areaId: '0'),
      LiveArea(platform: 'kilakila', areaId: '0'),
      LiveArea(platform: 'kilakila', areaType: 'timeline', areaId: '99'),
    ]) {
      await expectLater(site.getDirectoryPage(category: bad), throwsA(isA<KilakilaException>()));
    }
    expect(calls, hasLength(1));
  });
  test('native page pools retain overflow and deduplicate durable UIDs across broadcasts', () async {
    final calls = <int>[];
    final source = KilakilaSite(
      api: KilakilaApi(
        request: (uri, _) async {
          final page = int.parse(uri.queryParameters['pageNo']!);
          calls.add(page);
          return ok(
            directory(
              uri,
              page == 1
                  ? [card(first), card(second), card('200', '101'), card('300', '102')]
                  : [card('400', '102'), card('500', '103')],
              more: page == 1,
            ),
          );
        },
      ),
    );
    final controller = _Controller(source)..pageSize.value = 2;
    addTearDown(controller.onClose);
    await controller.loadData();
    expect(controller.list.map((r) => r.roomId), ['100', '101']);
    expect(calls, [1]);
    await controller.goToPage(2);
    expect(controller.list.map((r) => r.roomId), ['102', '103']);
    expect(calls, [1, 2]);
    expect(controller.canLoadMore.value, isFalse);
    await controller.goToPage(1);
    expect(controller.list.map((r) => r.roomId), ['100', '101']);
    expect(calls, [1, 2]);
  });
  test('metadata refresh omits media; persistence and share commands retain UID', () async {
    final calls = <Uri>[];
    final site = KilakilaSite(api: api(called: calls.add));
    final room = await site.getRoomDetailForRefresh(roomId: uid, platform: 'kilakila');
    expect(calls.map((u) => u.path), ['/Tg/personalH5']);
    expect(room.roomId, uid);
    expect(room.userId, uid);
    expect(room.data, isNull);
    expect(room.isLiveNow, isTrue);
    expect(room.onlineViewers, anyOf(isNull, isEmpty));
    final saved = room.toJson();
    expect(jsonEncode(saved), isNot(contains(first)));
    final reopened = LiveRoom.fromJson(saved);
    expect(reopened.hasSameIdentity(room), isTrue);
    final command = ShareCommandCodec.decodeShort(ShareCommandCodec.encodeShort({...saved, 'link': room.link}))!;
    expect(command['roomId'], uid);
    expect(command['link'], KilakilaSite.ownerUrl(uid));
    expect(RoomExternalOpener.resolve('kilakila', reopened)?.web, KilakilaSite.ownerUrl(uid));
  });
  test('exact UID and official owner link search use one owner request with no media resolution', () async {
    final calls = <Uri>[];
    final source = KilakilaSite(api: api(called: calls.add));
    for (final query in [uid, KilakilaSite.ownerUrl(uid)]) {
      final room = (await source.searchRooms(query)).single;
      expect(room.roomId, uid);
      expect(room.nick, 'Fixture');
      expect(room.link, KilakilaSite.ownerUrl(uid));
      expect(room.isLiveNow, isTrue);
      expect(room.data, isNull);
      expect(room.watching, isEmpty);
      expect(room.onlineViewers, isEmpty);
      expect(room.audienceMetricType, AudienceMetricType.unknown);
    }
    expect(calls.map((uri) => uri.path), ['/Tg/personalH5', '/Tg/personalH5']);
    expect(calls.map((uri) => uri.queryParameters['uid']), [uid, uid]);
  });
  test('empty current card returns owner with unknown live state, not an invented offline result', () async {
    final calls = <Uri>[];
    final source = KilakilaSite(
      api: api(advertised: () => {'roomSourceType': 0, 'recommendSource': 0}, called: calls.add),
    );
    final room = (await source.searchRooms(uid)).single;
    expect(room.roomId, uid);
    expect(room.effectiveLiveStatus, LiveStatus.unknown);
    expect(room.isExplicitlyOfflineNow, isFalse);
    expect(room.status, isNull);
    expect(room.watching, isEmpty);
    expect(calls.map((uri) => uri.path), ['/Tg/personalH5']);
  });
  test('official keyword page returns paged broadcaster profiles without media requests', () async {
    final calls = <Uri>[];
    final source = KilakilaSite(
      api: KilakilaApi(
        request: (uri, _) async {
          calls.add(uri);
          expect(uri.pathSegments.take(4), ['aboutus', 'serach', 'kw', '音乐']);
          return (
            status: 200,
            body:
                '<html><div class="userList">'
                '<a href="/zhubo/100"><div class="anchorInfo">'
                '<div class="anchorHeaderImg"><img src="https://img.example/100.png"></div>'
                '<div class="anchor-name">音乐主播</div></div></a>'
                '<a href="/zhubo/101"><div class="anchorInfo">'
                '<div class="anchor-name">音乐电台</div></div></a>'
                '</div></html>',
          );
        },
      ),
    );
    final firstPage = await source.searchRooms('音乐', page: 1);
    expect(firstPage.map((room) => room.roomId), ['100', '101']);
    expect(firstPage.map((room) => room.nick), ['音乐主播', '音乐电台']);
    expect(firstPage.every((room) => room.effectiveLiveStatus == LiveStatus.unknown && room.data == null), isTrue);
    expect(calls.single.pathSegments, ['aboutus', 'serach', 'kw', '音乐']);
    await source.searchRooms('音乐', page: 2);
    expect(calls.last.pathSegments, ['aboutus', 'serach', 'kw', '音乐', 'p', '2']);
  });
  test('invalid IDs, broadcast links and later exact pages send no owner request', () async {
    final calls = <Uri>[];
    final source = KilakilaSite(api: api(called: calls.add));
    for (final query in ['00100', '${KilakilaApi.origin}/room/$first', 'https://evil.test/index/roomuser/uid/100']) {
      expect(await source.searchRooms(query), isEmpty);
    }
    expect(await source.searchRooms(uid, page: 2), isEmpty);
    expect(calls, isEmpty);
  });
  test('missing owner is empty search but service/schema/cancellation remain explicit', () async {
    final missing = KilakilaSite(api: KilakilaApi(request: (_, _) async => ok({'code': 1013, 'data': null})));
    expect(await missing.searchRooms('100'), isEmpty);
    final service = KilakilaSite(api: KilakilaApi(request: (_, _) async => ok({'code': 1, 'data': null})));
    await expectLater(
      service.searchRooms('100'),
      throwsA(isA<KilakilaException>().having((e) => e.kind, 'kind', KilakilaFailure.service)),
    );
    final malformed = KilakilaSite(api: KilakilaApi(request: (_, _) async => ok({'code': 200, 'data': {}})));
    await expectLater(
      malformed.searchRooms('100'),
      throwsA(isA<KilakilaException>().having((e) => e.kind, 'kind', KilakilaFailure.schema)),
    );
    final token = CancelToken()..cancel('fixture');
    final cancelled = KilakilaSite(api: api(called: (_) => fail('cancelled request reached network')));
    await expectLater(
      cancelled.searchRoomsCancellable('100', cancel: token),
      throwsA(isA<KilakilaException>().having((e) => e.kind, 'kind', KilakilaFailure.cancelled)),
    );
  });
  test('playback and recorder renewal follow a new broadcast with stable quality IDs', () async {
    var current = first;
    final source = KilakilaSite(api: api(current: () => current));
    final initial = await source.getRoomDetail(roomId: uid, platform: 'kilakila');
    final quality = (await source.getPlayQualites(detail: initial)).first;
    expect(quality.selectionId, 'flv');
    expect(jsonEncode(initial.toJson()), isNot(contains('auth_key')));
    expect(jsonEncode(initial.toJson()), isNot(contains(first)));
    final recorder = StreamResolverService(siteResolver: (_) => source);
    final recorded = await recorder.resolveStream(roomId: uid, platform: 'kilakila', preferredQuality: 'flv');
    expect(recorded.url, media(first));
    current = second;
    final recovered = await source.resolvePlayUrlsForRecovery(detail: initial, quality: quality);
    expect(recovered.urls, [media(second)]);
    expect(recovered.appliedQualityData, 'flv');
    final renewed = await recorder.resolveStream(
      roomId: uid,
      platform: 'kilakila',
      preferredQuality: 'flv',
      previousQualityId: recorded.qualityCursorId,
      previousLineIndex: recorded.lineIndex,
      renewCurrent: true,
    );
    expect(renewed.url, media(second));
    expect(renewed.qualityCursorId, 'flv');
    expect(renewed.invalidAt, isNull);
    expect(renewed.refreshAt, isNull);
    final headers = await PlaybackHeaderResolver.resolve(platform: 'kilakila', roomId: uid);
    expect(await FFmpegHeaderFactory.build(platform: 'kilakila', roomId: uid), headers);
    expect(headers, {'referer': '${KilakilaApi.origin}/', 'user-agent': 'Mozilla/5.0'});
  });
  test('missing quality on recovery never reuses old signed transport', () async {
    var current = first;
    final source = KilakilaSite(
      api: api(current: () => current, changes: {'hlsPlayUrl': ''}),
    );
    final room = await source.getRoomDetail(roomId: uid, platform: 'kilakila');
    current = second;
    await expectLater(
      source.resolvePlayUrlsForRecovery(
        detail: room,
        quality: LivePlayQuality(id: 'hls', quality: 'HLS', data: [media(first, 'hls')]),
      ),
      throwsA(isA<KilakilaException>()),
    );
  });
  for (final empty in [
    <String, dynamic>{},
    {'roomSourceType': 0, 'recommendSource': 0},
  ]) {
    test('empty owner card stays unknown and never fetches a stale broadcast: $empty', () async {
      final calls = <Uri>[];
      final source = KilakilaSite(
        api: api(advertised: () => empty, called: calls.add),
      );
      final room = await source.getRoomDetail(roomId: uid, platform: 'kilakila');
      expect(room.effectiveLiveStatus, LiveStatus.unknown);
      expect(room.isExplicitlyOfflineNow, isFalse);
      expect(calls.map((u) => u.path), ['/Tg/personalH5']);
      await expectLater(
        StreamResolverService(siteResolver: (_) => source)
            .resolveStream(roomId: uid, platform: 'kilakila', preferredQuality: 'flv'),
        throwsA(
          isA<StreamException>()
              .having((e) => e.type, 'type', StreamErrorType.networkError)
              .having((e) => e.retryable, 'retryable', isTrue),
        ),
      );
    });
  }
  for (final entry in <Map<String, dynamic>, KilakilaFailure>{
    {'goldPrice': 1}: KilakilaFailure.restricted,
    {'status': 77}: KilakilaFailure.stateUnsupported,
    {'flvPlayUrl': '', 'hlsPlayUrl': ''}: KilakilaFailure.mediaUnavailable,
    {'uid': '101'}: KilakilaFailure.schema,
  }.entries) {
    test('strict playback and recording preserve ${entry.value.name}', () async {
      final source = KilakilaSite(api: api(changes: entry.key));
      for (final resolve in [source.getRoomDetail, source.getRoomDetailForRecording]) {
        await expectLater(
          resolve(roomId: uid, platform: 'kilakila'),
          throwsA(isA<KilakilaException>().having((e) => e.kind, 'kind', entry.value)),
        );
      }
    });
  }
  test('unknown advertised status stays unknown during favorite refresh', () async {
    final source = KilakilaSite(api: api(advertised: () => {...card(), 'status': 77}));
    final room = await source.getRoomDetailForRefresh(roomId: uid, platform: 'kilakila');
    expect(room.effectiveLiveStatus, LiveStatus.unknown);
  });
  test('share import resolves broadcasts before returning UID; owner links remain network-free', () async {
    final calls = <Uri>[];
    final source = api(called: calls.add);
    final broadcast = '${KilakilaApi.origin}/room/$first';
    expect(WebSearchRoomParser.parse(broadcast), isNull);
    expect(LiveUrlTool.containsSupportedLink(broadcast), isTrue);
    expect(await LiveUrlTool.parseLiveUrl('share $broadcast', kilakilaApi: source), [uid, 'kilakila']);
    expect(calls.map((u) => u.path), ['/LiveRoom/getRoomInfo', '/Tg/personalH5']);
    final owner = KilakilaSite.ownerUrl(uid);
    expect(WebSearchRoomParser.parse(owner)?.key, 'kilakila:$uid');
    expect(await LiveUrlTool.parseLiveUrl(owner, kilakilaApi: source), [uid, 'kilakila']);
    final searchProfile = '${KilakilaApi.origin}/zhubo/$uid';
    expect(WebSearchRoomParser.parse(searchProfile)?.key, 'kilakila:$uid');
    expect(await LiveUrlTool.parseLiveUrl(searchProfile, kilakilaApi: source), [uid, 'kilakila']);
    expect(calls, hasLength(2));
    for (final bad in [
      broadcast.replaceFirst('/room/', '/%72oom/'),
      broadcast.replaceFirst('.cn', '.cn.evil.test'),
      '$owner?uid=200',
      '$owner#fragment',
    ]) {
      expect(LiveUrlTool.containsSupportedLink(bad), isFalse);
      expect(await LiveUrlTool.parseLiveUrl(bad, kilakilaApi: source), isEmpty);
    }
    expect(calls, hasLength(2));
  });
  final vectors = jsonDecode(File('test/fixtures/kilakila/share-vectors.json').readAsStringSync()) as List;
  for (final vector in vectors) {
    test('application importer verifies signed fixture ${vector['name']}', () async {
      final calls = <Uri>[];
      final raw = vector['url'] as String;
      final valid = vector['valid'] == true;
      final result = await LiveUrlTool.parseLiveUrl(raw, kilakilaApi: api(called: calls.add));
      if (!valid) {
        expect(result, isEmpty);
        expect(calls, isEmpty);
      } else if (vector['kind'] == 'owner') {
        expect(result, [vector['id'], 'kilakila']);
        expect(calls, isEmpty);
      } else {
        expect(result, [uid, 'kilakila']);
        expect(calls.first.queryParameters['roomId'], vector['id']);
      }
    });
  }
  test('historical broadcast and transport failures never yield an imported favorite', () async {
    for (final response in [
      (status: 503, body: ''),
      ok({
        'h': {'code': 5966, 'success': false},
      }),
    ]) {
      final source = KilakilaApi(request: (_, _) async => response);
      await expectLater(
        LiveUrlTool.parseLiveUrl('${KilakilaApi.origin}/room/$first', kilakilaApi: source),
        throwsA(isA<KilakilaException>()),
      );
    }
  });
  for (final timeout in [false, true]) {
    test('share import ${timeout ? 'deadline' : 'cancellation'} cancels only owned work', () async {
      final entered = Completer<void>();
      final token = CancelToken();
      CancelToken? owned;
      final source = KilakilaApi(
        request: (_, cancel) async {
          owned = cancel;
          entered.complete();
          await cancel!.whenCancel;
          return (status: 503, body: '');
        },
      );
      final result = LiveUrlTool.parseLiveUrl(
        '${KilakilaApi.origin}/room/$first',
        kilakilaApi: source,
        cancelToken: token,
        timeout: timeout ? const Duration(milliseconds: 50) : const Duration(seconds: 5),
      );
      await entered.future;
      if (!timeout) token.cancel();
      expect(await result, isEmpty);
      expect(owned!.isCancelled, isTrue);
      if (timeout) expect(token.isCancelled, isFalse);
      await Future<void>.delayed(Duration.zero);
    });
  }
}
