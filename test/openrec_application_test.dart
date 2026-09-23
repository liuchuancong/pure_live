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
import 'package:pure_live/core/site/openrec/openrec_api.dart';
import 'package:pure_live/core/site/openrec/openrec_site.dart';
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

const _key = 'Fixture_Owner@100';
Map<String, dynamic> _json(String name) =>
    jsonDecode(File('test/fixtures/openrec/$name.json').readAsStringSync()) as Map<String, dynamic>;
String _master([String name = 'master']) => File('test/fixtures/openrec/$name.m3u8').readAsStringSync();
({int status, String body}) _ok(Object value) => (status: 200, body: jsonEncode(value));
Map<String, dynamic> _movie(String generation) {
  final movie = _json('movie')..['id'] = 'fixture$generation';
  for (final entry in (movie['media'] as Map).entries.toList()) {
    if (entry.value is String) {
      movie['media'][entry.key] = (entry.value as String).replaceAll('/fixture/', '/session$generation/');
    }
  }
  return movie;
}

OpenrecApi _api({String Function()? generation, void Function(Uri)? called, int? failedMasterStatus}) => OpenrecApi(
  request: (uri, _) async {
    called?.call(uri);
    final current = generation?.call() ?? '1234';
    if (uri.path.contains('/channels/')) {
      final owner = _json('channel-live');
      owner['onair_broadcast_movies'] = [_movie(current)];
      return _ok(owner);
    }
    if (uri.path.contains('/movies/')) return _ok(_movie(current));
    if (uri.path.endsWith('/movies')) return _ok([_movie(current)]);
    if (failedMasterStatus != null && uri.path.endsWith('playlist-ull.m3u8')) {
      return (status: failedMasterStatus, body: '');
    }
    return (
      status: 200,
      body: _master(
        uri.path.endsWith('playlist-ull.m3u8')
            ? 'low-latency-master'
            : uri.path.endsWith('live-public.m3u8')
            ? 'public-master'
            : 'master',
      ).replaceAll('/fixture-stream/', '/session$current/'),
    );
  },
);
Matcher _failure(OpenrecFailure kind) => throwsA(isA<OpenrecException>().having((e) => e.kind, 'kind', kind));

class _Directory extends LiveDirectoryController {
  _Directory(LiveSiteDirectoryPager source) : super(directory: source);
  @override
  bool get usesDesktopPagination => true;
  @override
  Future<bool> checkNetworkBeforeRequest() async => true;
  @override
  void handleError(Object error, {bool showPageError = false}) {
    errorMsg.value = error.toString();
    pageError.value = true;
  }
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

  test('registration enters real popular/category factories with honest capabilities', () async {
    final site = Sites.of(' OPENREC ');
    expect(site.liveSite, isA<OpenrecSite>());
    expect(Sites.supportSites.where((s) => s.id == 'openrec'), hasLength(1));
    expect(Sites.supportSites.map((s) => s.id).toSet(), Sites.supportedSiteIds);
    expect(LiveSearchCapabilities.forPlatform('openrec').coverage, NativeSearchCoverage.channelLookup);
    expect(LiveSearchCapabilities.forPlatform('openrec').supportsNativeSearch, isTrue);
    expect(LiveSearchCapabilities.forPlatform('openrec').supportsWebSearch, isFalse);
    expect(site.liveSite, isA<LiveCancellableSearch>());
    expect(LiveRoom.audienceCapabilityFor('openrec').onlineAvailableInRoomLists, isTrue);
    final popular = PopularController();
    addTearDown(popular.onClose);
    popular.initControllers([site]);
    expect(Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: 'openrec'), isA<LiveDirectoryController>());
    final category = (await site.liveSite.getCategores(1, 30)).single.children.single;
    final controller = AreaRoomsBinding.createController(site, category);
    addTearDown(controller.onClose);
    expect(controller, isA<LiveDirectoryController>());
    expect((controller as LiveDirectoryController).pageNotice, 'openrec_directory_scope');
  });
  test('actual directory controller consumes short pages until explicit empty and preserves identity', () async {
    final pages = <int>[];
    final api = OpenrecApi(
      request: (uri, _) async {
        final page = int.parse(uri.queryParameters['page']!);
        pages.add(page);
        return _ok(page == 1 ? [_movie('1234')] : []);
      },
    );
    final controller = _Directory(OpenrecSite(api: api));
    addTearDown(controller.onClose);
    await controller.loadData();
    expect(pages, [1, 2]);
    expect(controller.list.single.roomId, _key);
    expect(controller.canLoadMore.value, isFalse);
    expect(controller.list.single.onlineViewers, isNotEmpty);
    expect(controller.list.single.totalViewers, isEmpty);
  });
  test('exact channel ID and official root link search retain pinned identity without media', () async {
    final urls = <Uri>[];
    final site = OpenrecSite(api: _api(called: urls.add));
    for (final query in ['Fixture_Owner', 'https://www.mellow-fan.com/user/Fixture_Owner']) {
      final room = (await site.searchRooms(query)).single;
      expect(room.roomId, _key);
      expect(room.nick, '配信者 Fixture');
      expect(room.link, 'https://www.mellow-fan.com/user/Fixture_Owner');
      expect(room.isLiveNow, isTrue);
      expect(room.data, isNull);
      expect(room.watching, isEmpty);
      expect(room.onlineViewers, isEmpty);
      expect(room.audienceMetricType, AudienceMetricType.unknown);
    }
    expect(urls.map((uri) => uri.path), [
      '/external/api/v5/channels/Fixture_Owner',
      '/external/api/v5/channels/Fixture_Owner',
    ]);
  });
  test('exact channel search returns explicit offline and leaves multiple broadcasts unselected', () async {
    final offline = OpenrecSite(api: OpenrecApi(request: (_, _) async => _ok(_json('channel-offline'))));
    final owner = (await offline.searchRooms('Fixture_Owner')).single;
    expect(owner.roomId, _key);
    expect(owner.isExplicitlyOfflineNow, isTrue);
    expect(owner.watching, isEmpty);
    final multiple = _json('channel-live');
    multiple['onair_broadcast_movies'].add(_movie('5678'));
    final site = OpenrecSite(api: OpenrecApi(request: (_, _) async => _ok(multiple)));
    final room = (await site.searchRooms('Fixture_Owner')).single;
    expect(room.isLiveNow, isTrue);
    expect(room.notice, 'openrec_multiple_broadcasts');
    expect(room.data, isNull);
    expect(room.onlineViewers, isEmpty);
  });
  test('unsupported search terms, movie links and later pages send no request', () async {
    final urls = <Uri>[];
    final site = OpenrecSite(api: _api(called: urls.add));
    for (final query in [
      'Fixture Owner',
      'https://www.mellow-fan.com/live/fixture1234',
      'https://evil.test/user/Fixture_Owner',
      'https://www.mellow-fan.com/user/Fixture_Owner/playlist',
      'https://www.mellow-fan.com/user/Fixture_Owner?search_query=other',
      'https://www.mellow-fan.com/user/Fixture_Owner#other',
    ]) {
      expect(await site.searchRooms(query), isEmpty);
    }
    expect(await site.searchRooms('Fixture_Owner', page: 2), isEmpty);
    expect(urls, isEmpty);
  });
  test('missing channel is empty; access, schema and cancellation remain errors', () async {
    final missing = OpenrecSite(api: OpenrecApi(request: (_, _) async => (status: 404, body: '')));
    expect(await missing.searchRooms('Fixture_Owner'), isEmpty);
    final denied = OpenrecSite(api: OpenrecApi(request: (_, _) async => (status: 403, body: '')));
    await expectLater(denied.searchRooms('Fixture_Owner'), _failure(OpenrecFailure.access));
    final malformed = OpenrecSite(api: OpenrecApi(request: (_, _) async => _ok({'id': 'Fixture_Owner'})));
    await expectLater(malformed.searchRooms('Fixture_Owner'), _failure(OpenrecFailure.schema));
    final token = CancelToken()..cancel('fixture');
    final cancelled = OpenrecSite(api: OpenrecApi(request: (_, _) async => fail('cancelled request reached network')));
    await expectLater(
      cancelled.searchRoomsCancellable('Fixture_Owner', cancel: token),
      _failure(OpenrecFailure.cancelled),
    );
  });
  test('metadata refresh does not fetch media and keeps current title/audience', () async {
    final urls = <Uri>[];
    final site = OpenrecSite(api: _api(called: urls.add));
    final room = await site.getRoomDetailForRefresh(roomId: _key, platform: 'openrec');
    expect(room.title, '配信 Fixture');
    expect(room.data, isNull);
    expect(room.isLiveNow, isTrue);
    expect(urls, hasLength(2));
    expect(urls.every((u) => u.host == 'public.mellow-fan.com'), isTrue);
  });
  test('multi-broadcast directory card reports ambiguity rather than the first title/count', () async {
    final first = _movie('1234');
    final second = _movie('5678');
    final site = OpenrecSite(api: OpenrecApi(request: (_, _) async => _ok([first, second])));
    final page = await site.getDirectoryPage();
    expect(page.hasMore, isTrue);
    expect(page.rooms, hasLength(1));
    expect(page.rooms.single.title, page.rooms.single.nick);
    expect(page.rooms.single.onlineViewers, isNull);
    expect(page.rooms.single.notice, 'openrec_multiple_broadcasts');
    second['channel']['openrec_user_id'] = 999;
    await expectLater(site.getDirectoryPage(), _failure(OpenrecFailure.identity));
  });
  test('playback, recorder and renewal use parsed actual qualities and fresh URLs', () async {
    var current = '1234';
    final site = OpenrecSite(api: _api(generation: () => current));
    final room = await site.getRoomDetail(roomId: _key, platform: 'openrec');
    final qualities = await site.getPlayQualites(detail: room);
    expect(qualities, hasLength(7));
    final source = qualities.firstWhere((q) => q.quality == '720p 60fps');
    expect((await site.getPlayUrls(detail: room, quality: source)).single, contains('/session1234/'));
    final recorder = StreamResolverService(siteResolver: (_) => site);
    final recorded = await recorder.resolveStream(
      roomId: _key,
      platform: 'openrec',
      preferredQuality: source.selectionId.toString(),
    );
    expect(recorded.quality.selectionId, source.selectionId);
    expect(recorded.url, contains('/session1234/'));
    current = '5678';
    for (final quality in qualities) {
      final renewed = await site.resolvePlayUrlsForRecovery(detail: room, quality: quality);
      expect(renewed.urls.single, contains('/session5678/'));
      expect(renewed.appliedQualityData, quality.selectionId);
    }
    final forged = LivePlayQuality(id: source.selectionId, quality: 'fake', data: ['https://evil.test/stream']);
    expect(
      await site.getPlayUrls(detail: room, quality: forged),
      await site.getPlayUrls(detail: room, quality: source),
    );
    await expectLater(
      site.getPlayUrls(
        detail: room,
        quality: LivePlayQuality(id: 'fake4k', quality: '4K'),
      ),
      _failure(OpenrecFailure.mediaUnavailable),
    );
  });
  test('unavailable optional family leaves valid qualities and a notice', () async {
    final site = OpenrecSite(api: _api(failedMasterStatus: 403));
    final room = await site.getRoomDetail(roomId: _key, platform: 'openrec');
    expect(await site.getPlayQualites(detail: room), hasLength(6));
    expect(room.notice, 'openrec_partial_sources');
  });
  test('all media access errors are errors, not offline snapshots', () async {
    final site = OpenrecSite(
      api: OpenrecApi(
        request: (uri, token) async {
          if (uri.host != 'public.mellow-fan.com') return (status: 403, body: '');
          return _ok(uri.path.contains('/channels/') ? _json('channel-live') : _json('movie'));
        },
      ),
    );
    await expectLater(site.getRoomDetail(roomId: _key, platform: 'openrec'), _failure(OpenrecFailure.access));
  });
  test('fatal manifest error cancels sibling requests and consumes late transport errors', () async {
    final tokens = <CancelToken>[];
    final pending = <Completer<({int status, String body})>>[];
    final site = OpenrecSite(
      api: OpenrecApi(
        request: (uri, cancel) async {
          if (uri.host == 'public.mellow-fan.com') {
            return _ok(uri.path.contains('/channels/') ? _json('channel-live') : _json('movie'));
          }
          tokens.add(cancel!);
          if (uri.path.endsWith('live-playlist.m3u8')) {
            return (status: 200, body: 'malformed manifest');
          }
          final completer = Completer<({int status, String body})>();
          pending.add(completer);
          return completer.future;
        },
      ),
    );
    await expectLater(site.getRoomDetail(roomId: _key, platform: 'openrec'), _failure(OpenrecFailure.schema));
    expect(tokens, hasLength(3));
    expect(tokens.every((token) => token.isCancelled), isTrue);
    expect(pending, hasLength(2));
    for (final completer in pending) {
      completer.completeError(const SocketException('late fixture transport error'));
    }
    await Future<void>.delayed(Duration.zero);
  });
  test('numeric reassignment and wrong platform are rejected before saved identity can move', () async {
    final site = OpenrecSite(api: _api());
    await expectLater(
      site.getRoomDetail(roomId: 'Fixture_Owner@999', platform: 'openrec'),
      _failure(OpenrecFailure.identity),
    );
    await expectLater(site.getRoomDetail(roomId: _key, platform: 'other'), _failure(OpenrecFailure.identity));
    await expectLater(
      site.getRoomDetail(roomId: 'Fixture_Owner', platform: 'openrec'),
      _failure(OpenrecFailure.identity),
    );
  });
  test('explicit offline skips masters while multiple live broadcasts are not guessed', () async {
    final offline = OpenrecSite(api: OpenrecApi(request: (_, _) async => _ok(_json('channel-offline'))));
    final room = await offline.getRoomDetail(roomId: _key, platform: 'openrec');
    expect(room.isExplicitlyOfflineNow, isTrue);
    expect(await offline.getPlayQualites(detail: room), isEmpty);
    final owner = _json('channel-live');
    owner['onair_broadcast_movies'].add(_movie('5678'));
    final multi = OpenrecSite(api: OpenrecApi(request: (_, _) async => _ok(owner)));
    expect(
      (await multi.getRoomDetailForRefresh(roomId: _key, platform: 'openrec')).notice,
      'openrec_multiple_broadcasts',
    );
    await expectLater(multi.getRoomDetail(roomId: _key, platform: 'openrec'), _failure(OpenrecFailure.ambiguous));
  });
  test('media headers are shared with FFmpeg and never depend on a numeric room URL', () async {
    final headers = await PlaybackHeaderResolver.resolve(platform: 'openrec', roomId: _key);
    expect(headers, {
      'user-agent': 'Mozilla/5.0',
      'referer': 'https://www.mellow-fan.com/',
      'origin': 'https://www.mellow-fan.com',
    });
    expect(await FFmpegHeaderFactory.build(platform: 'openrec', roomId: _key), headers);
  });
  test('official external action decodes pinned identity and ignores stale room link', () {
    final room = LiveRoom(platform: 'openrec', roomId: _key, link: 'https://evil.test');
    expect(RoomExternalOpener.resolve('openrec', room)!.web, 'https://www.mellow-fan.com/user/Fixture_Owner');
    expect(RoomExternalOpener.resolve('openrec', LiveRoom(roomId: 'invalid')), isNull);
  });
  test('old/new channel and broadcast shares resolve to the same pinned owner', () async {
    for (final url in [
      'https://www.openrec.tv/user/Fixture_Owner',
      'https://www.mellow-fan.com/live/fixture1234',
      'https://www.openrec.tv/movie/fixture1234',
    ]) {
      expect(LiveUrlTool.containsSupportedLink(url), isTrue);
      expect(await LiveUrlTool.parseLiveUrl(url, openrecApi: _api()), [_key, 'openrec']);
      expect(
        WebSearchRoomParser.parse(url),
        isNull,
        reason: 'Synchronous web parser must not invent an unverified numeric identity',
      );
    }
  });
  test('share cancellation/timeout discard late numeric identity and cancel owned request', () async {
    for (final cancelEarly in [true, false]) {
      final pending = Completer<({int status, String body})>();
      CancelToken? owned;
      final api = OpenrecApi(
        request: (_, cancel) {
          owned = cancel;
          return pending.future;
        },
      );
      final cancel = CancelToken();
      final future = LiveUrlTool.parseLiveUrl(
        'https://www.mellow-fan.com/user/Fixture_Owner',
        openrecApi: api,
        cancelToken: cancel,
        timeout: const Duration(milliseconds: 30),
      );
      await Future<void>.delayed(Duration.zero);
      if (cancelEarly) cancel.cancel();
      expect(await future, isEmpty);
      expect(owned!.isCancelled, isTrue);
      pending.complete(_ok(_json('channel-live')));
      await Future<void>.delayed(Duration.zero);
    }
  });
  test('category guards do not issue unrelated requests', () async {
    var calls = 0;
    final site = OpenrecSite(
      api: _api(
        called: (_) {
          calls++;
        },
      ),
    );
    await expectLater(
      site.getDirectoryPage(
        category: LiveArea(platform: 'openrec', areaType: 'directory', areaId: 'unknown'),
      ),
      _failure(OpenrecFailure.schema),
    );
    expect(calls, 0);
  });
}
