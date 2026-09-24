import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/popkontv/popkontv_api.dart';
import 'package:pure_live/core/site/popkontv/popkontv_link.dart';
import 'package:pure_live/core/site/popkontv/popkontv_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test('official room links retain channel and partner identity', () {
    final current = PopkonLink.parse('https://www.popkontv.com/live/view?castId=fixture_101&partnerCode=P-00117');
    expect(current?.storageKey, 'fixture_101@P-00117');
    final legacy = PopkonLink.parse('https://www.popkontv.com/channel/notices?mcid=fixture_101&mcPartnerCode=P-00117');
    expect(legacy?.storageKey, 'fixture_101@P-00117');
    expect(PopkonLink.parseKey('fixture_101@P-00117')?.signId, 'fixture_101');
    expect(
      PopkonLink.url('fixture_101@P-00117'),
      'https://www.popkontv.com/live/view?castId=fixture_101&partnerCode=P-00117',
    );
    for (final invalid in [
      'https://www.popkontv.com/live-more',
      'https://www.popkontv.com/search?castId=fixture_101',
      'https://www.popkontv.com.evil.test/live/view?castId=fixture_101',
      'https://www.popkontv.com:444/live/view?castId=fixture_101',
      'https://user@www.popkontv.com/live/view?castId=fixture_101',
      'https://www.popkontv.com/live/view?castId=fixture_101&partnerCode=wrong',
    ]) {
      expect(PopkonLink.parse(invalid), isNull);
    }
  });

  test('directory preserves official paging and audience fields', () async {
    late Map<String, dynamic> sent;
    final api = PopkonApi(
      request: (method, uri, data, referer, cancel) async {
        expect(method, 'POST');
        expect(uri.path, '/api/proxy/broadcast/v3.1/livelist');
        expect(referer, '${PopkonApi.origin}/live-more');
        sent = data! as Map<String, dynamic>;
        return (
          status: 200,
          body: jsonEncode({
            'statusCd': 'S2000',
            'statusMsg': 'SUCCESS',
            'data': {
              'list': [_directoryCard()],
              'topCnt': 0,
              'totalCnt': 61,
              'totalPage': 3,
              'pageNum': 2,
              'pageSize': 30,
            },
          }),
        );
      },
    );
    final result = await api.directory(page: 2, sortType: 4);
    expect(sent, containsPair('pageNum', 2));
    expect(sent, containsPair('sortType', 4));
    expect(result.hasMore, isTrue);
    expect(result.rooms.single.onlineViewers, 127);
    expect(result.rooms.single.totalViewers, 901);
    expect(result.rooms.single.followers, 9371);
  });

  test('native keyword search merges live and offline creators', () async {
    final api = PopkonApi(
      request: (method, uri, data, referer, cancel) async {
        expect(uri.path, '/api/proxy/broadcast/v1.1/search/all');
        expect(data, containsPair('searchKeyword', 'Fixture'));
        return (status: 200, body: jsonEncode(_search(live: true, includeOffline: true)));
      },
    );
    final results = await PopkonSite(api: api).searchRooms('Fixture');
    expect(results, hasLength(2));
    expect(results.first.effectiveLiveStatus, LiveStatus.live);
    expect(results.first.onlineViewers, '127');
    expect(results.first.totalViewers, '901');
    expect(results.last.effectiveLiveStatus, LiveStatus.offline);
    expect(results.last.roomId, 'offline_202@P-00001');
  });

  test('live room obtains a guest session and parses HLS qualities', () async {
    var watchRequests = 0;
    var manifestRequests = 0;
    final api = PopkonApi(
      request: (method, uri, data, referer, cancel) async {
        if (uri.path.endsWith('/search/all')) {
          return (status: 200, body: jsonEncode(_search(live: true)));
        }
        if (uri.path.endsWith('/castwatchonoffguest')) {
          watchRequests++;
          expect(data, containsPair('castCode', 'fixture_101-20260921100224'));
          expect(data, containsPair('castPartnerCode', 'P-00117'));
          return (
            status: 200,
            body: jsonEncode({
              'statusCd': 'L0000',
              'statusMsg': 'SUCCESS',
              'data': {'castHlsUrl': 'https://fixture.hscdn.com/pop_cast27/fixture/index.m3u8?token=fixture'},
            }),
          );
        }
        manifestRequests++;
        expect(method, 'GET');
        expect(referer, PopkonLink.url('fixture_101@P-00117'));
        return (status: 200, body: _manifest);
      },
    );
    final room = await api.room('fixture_101@P-00117');
    expect(room.state, PopkonState.live);
    expect(room.access, PopkonAccess.public);
    expect(room.streams.map((stream) => stream.id), ['1080p', '720p']);

    final site = PopkonSite(api: api);
    final detail = await site.getRoomDetail(roomId: room.roomId, platform: Sites.popkonSite);
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.map((quality) => quality.selectionId), ['1080p', '720p']);
    final resolution = await site.resolvePlayUrlsRaw(detail: detail, quality: qualities.last);
    expect(Uri.parse(resolution.urls.single).path, endsWith('/chunklist_720.m3u8'));
    await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: qualities.last);
    expect(watchRequests, 3, reason: 'API room, detail, and recovery each obtain a new watch session');
    expect(manifestRequests, 3);
  });

  test('adult and password rooms preserve live state without requesting media', () async {
    var mediaRequests = 0;
    final api = PopkonApi(
      request: (method, uri, data, referer, cancel) async {
        if (!uri.path.endsWith('/search/all')) mediaRequests++;
        return (status: 200, body: jsonEncode(_search(live: true, adult: true)));
      },
    );
    final room = await api.room('fixture_101@P-00117');
    expect(room.state, PopkonState.live);
    expect(room.access, PopkonAccess.adult);
    expect(room.streams, isEmpty);
    expect(mediaRequests, 0);
  });

  test('an adult broadcast hidden from guest search stays live via the public directory', () async {
    // Production (2026-09-25): guest search/all returns the profile but omits
    // adult broadcasts from liveList, while livelist still lists them.
    var directoryRequests = 0;
    var mediaRequests = 0;
    final api = PopkonApi(
      request: (method, uri, data, referer, cancel) async {
        if (uri.path.endsWith('/search/all')) return (status: 200, body: jsonEncode(_search(live: false)));
        if (uri.path.endsWith('/livelist')) {
          directoryRequests++;
          return (
            status: 200,
            body: jsonEncode(
              _directoryPage([
                {..._directoryCard(), 'isAdult': 1},
              ]),
            ),
          );
        }
        mediaRequests++;
        return (status: 500, body: '');
      },
    );
    final room = await api.room('fixture_101@P-00117');
    expect(room.state, PopkonState.live);
    expect(room.access, PopkonAccess.adult);
    expect(room.onlineViewers, 127);
    expect(mediaRequests, 0);

    // A second detail inside the snapshot window reuses the directory.
    await api.room('fixture_101@P-00117');
    expect(directoryRequests, 1);
  });

  test('a channel absent from search and directory is offline', () async {
    final api = PopkonApi(
      request: (method, uri, data, referer, cancel) async => (
        status: 200,
        body: jsonEncode(uri.path.endsWith('/livelist') ? _directoryPage(const []) : _search(live: false)),
      ),
    );
    final room = await api.room('fixture_101@P-00117');
    expect(room.state, PopkonState.offline);
  });

  test('manifest parser rejects media-host lookalikes', () {
    final master = Uri.parse('https://fixture.hscdn.com/master.m3u8');
    expect(
      () => PopkonApi.parseManifest(
        master,
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=1280x720\nhttps://hscdn.com.evil.test/720.m3u8\n',
      ),
      _failure(PopkonFailure.schema),
    );
  });

  test('registry exposes one PopkonTV adapter with recording support', () {
    expect(Sites.supportedSiteIds, contains(Sites.popkonSite));
    expect(Sites.of(Sites.popkonSite).liveSite, isA<PopkonSite>());
    expect(Sites.supportSites.where((site) => site.id == Sites.popkonSite), hasLength(1));
  });

  test('caller cancellation is classified before transport', () async {
    final api = PopkonApi(request: (_, _, _, _, _) async => throw StateError('unused'));
    await expectLater(
      api.room('fixture_101@P-00117', cancel: CancelToken()..cancel()),
      _failure(PopkonFailure.cancelled),
    );
  });
}

Matcher _failure(PopkonFailure kind) => throwsA(isA<PopkonException>().having((error) => error.kind, 'kind', kind));

Map<String, dynamic> _search({required bool live, bool includeOffline = false, bool adult = false}) => {
  'statusCd': 'S2000',
  'statusMsg': 'SUCCESS',
  'data': {
    'broadCastList': [
      _profile('fixture_101', 'P-00117', 'Fixture owner'),
      if (includeOffline) _profile('offline_202', 'P-00001', 'Offline owner'),
    ],
    'liveList': live ? [_searchLive(adult: adult)] : null,
    'replayList': null,
    'vodList': null,
    'vodSpecialList': null,
    'vodUccList': null,
  },
};

Map<String, dynamic> _profile(String signId, String partnerCode, String nickname) => {
  'mcSignId': signId,
  'mcPartnerCode': partnerCode,
  'mcPFileName': 'https://pic.popkontv.com/profile_thumb/$partnerCode/$signId.jpeg',
  'nickName': nickname,
  'lvl': '2',
  'classLvl': 'mc lv0139',
  'serviceCoinName': 'Popcorn',
  'defaultImg': false,
};

Map<String, dynamic> _searchLive({bool adult = false}) => {
  'mcSignId': 'fixture_101',
  'mcPartnerCode': 'P-00117',
  'mcPFileName': 'https://thumb.popcast.co.kr/P-00117/fixture_101_220.jpg',
  'watchCnt': 127,
  'bookmark': 9371,
  'recommend': 24,
  'castStartDateCode': '20260921100224',
  'castTitle': 'Fixture live',
  'castType': 0,
  'isPrivate': '0',
  'isAdult': adult ? 1 : 0,
  'imgUrl': '',
  'mcCategory': 13,
  'brdcShrngAlwdYn': 'Y',
  'mcNickName': 'Fixture owner',
  'onErrorImg': 'https://pic.popkontv.com/images/thumb/random.png',
  'totalWatchCnt': 901,
};

Map<String, dynamic> _directoryCard() => {
  'signId': 'fixture_101',
  'castStartDateCode': '20260921100224',
  'castTitle': 'Fixture live',
  'isAdult': 0,
  'isPrivate': 0,
  'limitNumber': 300,
  'category': 13,
  'castPath': 9,
  'partnerCode': 'P-00117',
  'castType': 0,
  'nickName': 'Fixture owner',
  'imgUrl': null,
  'watchCnt': 127,
  'onErrorImg': 'https://pic.popkontv.com/images/thumb/random.png',
  'pfileName': 'https://thumb.popcast.co.kr/P-00117/fixture_101_220.jpg',
  'bookmarkCnt': 9371,
  'totalWatchCnt': 901,
};

const _manifest = '''#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=3626896,CODECS="avc1.42c028,mp4a.40.2",RESOLUTION=1920x1080
chunklist_1080.m3u8?token=fixture
#EXT-X-STREAM-INF:BANDWIDTH=1813448,CODECS="avc1.42c01f,mp4a.40.2",RESOLUTION=1280x720
chunklist_720.m3u8?token=fixture
''';

Map<String, dynamic> _directoryPage(List<Map<String, dynamic>> cards) => {
  'statusCd': 'S2000',
  'statusMsg': 'SUCCESS',
  'data': {'list': cards, 'topCnt': 0, 'totalCnt': cards.length, 'pageNum': 1, 'totalPage': 1},
};
