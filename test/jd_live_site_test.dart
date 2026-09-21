import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/jdlive/jd_live_api.dart';
import 'package:pure_live/core/site/jdlive/jd_live_link.dart';
import 'package:pure_live/core/site/jdlive/jd_live_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test('JD Live links retain only canonical live IDs and official hash routes', () {
    expect(JdLiveLink.parseLiveId('48266468'), '48266468');
    expect(JdLiveLink.parseLiveId('https://lives.jd.com/#/48266468?origin=0'), '48266468');
    expect(JdLiveLink.parseLiveId('https://lives.jd.com/#/48266468/live?origin=0'), '48266468');
    for (final value in [
      'https://lives.jd.com/#/channel',
      'https://lives.jd.com.evil.test/#/48266468',
      'https://m.jd.com/product/48266468.html',
      '1234',
    ]) {
      expect(JdLiveLink.parseLiveId(value), isNull, reason: value);
    }
  });

  test('official directory keeps live cards, cumulative views and native page cursor', () {
    final page = JdLiveApi.parseDirectoryJson(_directoryJson(30), page: 1);
    expect(page.rooms, hasLength(30));
    expect(page.nextCount, 37);
    expect(page.hasMore, isTrue);
    final room = page.rooms.first;
    expect(room.liveId, '48266468');
    expect(room.authorId, '29007128');
    expect(room.nick, '云南健康生活店');
    expect(room.title, '云南健康生活，呵护你的每一天');
    expect(room.totalViews, 70);
    expect(room.state, JdLiveState.live);
    expect(room.cover, startsWith('https://m.360buyimg.com/livecms/'));
  });

  test('play response and HLS children remain bound to one JD Cloud stream', () {
    final room = JdLiveApi.parseRoomJson(_roomJson, expectedLiveId: '48266468');
    expect(room.state, JdLiveState.live);
    expect(room.hls?.host, 'zt-pull-ai.jdcloud.com');
    expect(room.flv?.path, endsWith('_fhd.flv'));
    expect(() => JdLiveApi.validatePlaylist(_playlist, expected: room.hls!), returnsNormally);
    expect(
      () => JdLiveApi.validatePlaylist(
        _playlist.replaceFirst('B9A8E49148019EC0ECD72A1B18A6A7C8', 'OTHER'),
        expected: room.hls!,
      ),
      throwsA(isA<JdLiveException>()),
    );
    expect(
      () => JdLiveApi.parseRoomJson({
        ..._roomJson,
        'data': {...(_roomJson['data']! as Map<String, dynamic>), 'h5VideoUrl': 'https://example.com/live/x.m3u8'},
      }, expectedLiveId: '48266468'),
      throwsA(isA<JdLiveException>()),
    );
  });

  test('site reuses the native cursor and refreshes media for recovery', () async {
    final api = _FixtureApi();
    final site = JdLiveSite(api: api);
    final firstPage = await site.getDirectoryPage(page: 1);
    expect(firstPage.hasMore, isTrue);
    expect(firstPage.rooms.single.totalViewers, '70');
    expect(firstPage.rooms.single.audienceMetricType, AudienceMetricType.totalViewers);
    await site.getDirectoryPage(page: 2);
    expect(api.directoryCounts, [0, 37]);
    expect(api.directoryTimestamps.toSet(), hasLength(1));

    final exact = await site.searchRooms('https://lives.jd.com/#/48266468?origin=0');
    expect(exact.single.roomId, '48266468');
    final detail = await site.getRoomDetail(roomId: '48266468', platform: Sites.jdLiveSite);
    expect(detail.title, '云南健康生活，呵护你的每一天');
    expect(detail.data, isA<JdLiveRoom>());
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.map((quality) => quality.selectionId), ['hls', 'flv']);
    final first = await site.resolvePlayUrlsRaw(detail: detail, quality: qualities.first);
    expect(first.urls.single, endsWith('_fhd.m3u8'));
    final recovered = await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: qualities.first);
    expect(recovered.urls.single, first.urls.single);
    expect(api.roomCalls, 3);

    expect(Sites.supportedSiteIds, contains(Sites.jdLiveSite));
    expect(Sites.of(Sites.jdLiveSite).liveSite, isA<JdLiveSite>());
    expect(Sites.supportSites.where((site) => site.id == Sites.jdLiveSite), hasLength(1));
  });
}

final class _FixtureApi extends JdLiveApi {
  _FixtureApi() : super(request: (_, _, _) async => throw StateError('unused'));

  final List<int> directoryCounts = [];
  final List<int> directoryTimestamps = [];
  int roomCalls = 0;

  JdLiveRoom get _directoryRoom => JdLiveApi.parseDirectoryJson(_directoryJson(1), page: 1).rooms.single;

  @override
  Future<JdLivePage> directory({
    required int page,
    required int currentCount,
    required int timestamp,
    CancelToken? cancel,
  }) async {
    directoryCounts.add(currentCount);
    directoryTimestamps.add(timestamp);
    return JdLivePage(rooms: [_directoryRoom], nextCount: page == 1 ? 37 : 67, hasMore: page == 1);
  }

  @override
  Future<JdLiveRoom> room(String rawLiveId, {bool includeMedia = false, CancelToken? cancel}) async {
    roomCalls++;
    return JdLiveApi.parseRoomJson(_roomJson, expectedLiveId: JdLiveLink.requireLiveId(rawLiveId));
  }
}

Map<String, dynamic> _directoryJson(int count) => {
  'code': '0',
  'subCode': '0',
  'data': {
    'currentCount': 37,
    'list': [
      {'templateType': -100, 'cardId': '28'},
      for (var index = 0; index < count; index++)
        {
          'templateType': 1,
          'cardId': '${48266468 + index}',
          'data': {
            'id': 48266468 + index,
            'liveId': '${48266468 + index}',
            'authorId': '29007128',
            'userName': '云南健康生活店',
            'title': '云南健康生活，呵护你的每一天',
            'status': 1,
            'pv': 70 + index,
            'userPic': 'https://img30.360buyimg.com/popshop/avatar.png',
            'indexImage': 'https://m.360buyimg.com/livecms/cover.png',
          },
        },
    ],
  },
};

final Map<String, dynamic> _roomJson = {
  'code': '0',
  'subCode': '0',
  'data': {
    'liveId': 48266468,
    'videoUrl': 'https://zt-pull-ai.jdcloud.com/live/B9A8E49148019EC0ECD72A1B18A6A7C8_fhd.flv',
    'h5VideoUrl': 'https://zt-pull-ai.jdcloud.com/live/B9A8E49148019EC0ECD72A1B18A6A7C8_fhd.m3u8',
    'status': 1,
    'secret': 0,
    'blurredImg': 'https://m.360buyimg.com/live/blurred.jpg!q70.jpg',
  },
};

const _playlist = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:2
#EXT-X-MEDIA-SEQUENCE:1789989773
#EXTINF:2.000,
B9A8E49148019EC0ECD72A1B18A6A7C8_fhd-ss-1422278604-1789989773.ts?volcDst=fixture
''';
