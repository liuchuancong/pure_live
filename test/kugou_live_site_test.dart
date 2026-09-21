import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/core/site/kugoulive/kugou_live_api.dart';
import 'package:pure_live/core/site/kugoulive/kugou_live_link.dart';
import 'package:pure_live/core/site/kugoulive/kugou_live_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/modules/search/web_search_room_parser.dart';

void main() {
  test('Kugou links retain canonical room IDs and official room routes', () {
    expect(KugouLiveLink.parseRoomId('5085706'), '5085706');
    expect(KugouLiveLink.parseRoomId('https://fanxing.kugou.com/5085706?refer=2177'), '5085706');
    expect(KugouLiveLink.parseRoomId('https://mfanxing.kugou.com/?roomId=5085706'), '5085706');
    expect(LiveUrlTool.containsSupportedLink('酷狗 https://fanxing.kugou.com/5085706'), isTrue);
    expect(WebSearchRoomParser.parse('https://fanxing.kugou.com/5085706')?.platform, Sites.kugouLiveSite);
    for (final value in [
      'https://fanxing.kugou.com/channel/5085706',
      'https://fanxing.kugou.com.evil.test/5085706',
      'https://user@fanxing.kugou.com/5085706',
      '12',
    ]) {
      expect(KugouLiveLink.parseRoomId(value), isNull, reason: value);
    }
  });

  test('native cards preserve viewers, popularity and followers separately', () {
    final page = KugouLiveApi.parseDirectoryJson(_directoryJson);
    expect(page.hasMore, isTrue);
    expect(page.rooms, hasLength(2));
    expect(page.rooms.first.currentViewers, 79);
    expect(page.rooms.first.popularity, 11266);
    expect(page.rooms.first.followers, 6539);
    expect(page.rooms.last.currentViewers, 8);
    expect(page.rooms.last.state, KugouLiveState.live);
  });

  test('homepage category parser excludes account-only routes', () {
    final categories = KugouLiveApi.parseCategoriesHtml('''
      <a href="/pcindex/category/3001" title="关注">关注</a>
      <a href="/pcindex/category/8000" title="推荐">推荐</a>
      <a href="/pcindex/category/7024" title="舞蹈">舞蹈</a>
    ''');
    expect(categories.map((item) => item.id), ['8000', '7024']);
  });

  test('search JSONP retains offline broadcasters', () {
    final rooms = KugouLiveApi.parseSearchJsonp('fixtureCallback($_searchJson);', callback: 'fixtureCallback');
    expect(rooms, hasLength(2));
    expect(rooms.first.state, KugouLiveState.live);
    expect(rooms.last.state, KugouLiveState.offline);
    expect(
      () => KugouLiveApi.parseSearchJsonp('other($_searchJson);', callback: 'fixtureCallback'),
      throwsA(isA<KugouLiveException>()),
    );
  });

  test('media lines are room-bound, deduplicated and expose lease timestamps', () {
    final variants = KugouLiveApi.parseMediaJson(_mediaJson, expectedRoomId: '5085706');
    expect(variants, hasLength(1));
    expect(variants.single.id, 'flv:4:1:1');
    expect(variants.single.urls, hasLength(2));
    expect(
      KugouLiveApi.validateMediaUri(_signedUrl('other.live.kugou.com'), expectedRoomId: '5085706', protocol: 'flv'),
      isNull,
    );
    expect(
      KugouLiveApi.validateMediaUri(
        _signedUrl('tx105.liveplay.live.kugou.com').replaceFirst('0-5085706-', '0-9999999-'),
        expectedRoomId: '5085706',
        protocol: 'flv',
      ),
      isNull,
    );
    final invalid = KugouLiveApi.mediaInvalidAt(_signedUrl('tx105.liveplay.live.kugou.com'));
    expect(invalid, DateTime.fromMillisecondsSinceEpoch(int.parse('6AB1DA15', radix: 16) * 1000));
  });

  test('site exposes directory, exact search, stable quality and refreshed recovery', () async {
    final api = _FixtureApi();
    final site = KugouLiveSite(api: api);
    final directory = await site.getDirectoryPage(page: 1);
    expect(directory.hasMore, isTrue);
    expect(directory.rooms.first.onlineViewers, '79');
    expect(directory.rooms.first.popularity, '11266');
    expect(directory.rooms.first.audienceMetricType, AudienceMetricType.onlineViewers);

    final offline = await site.searchRooms('offline anchor');
    expect(offline.single.liveStatus, LiveStatus.offline);
    final exact = await site.searchRooms('https://fanxing.kugou.com/5085706');
    expect(exact.single.roomId, '5085706');

    final detail = await site.getRoomDetail(roomId: '5085706', platform: Sites.kugouLiveSite);
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.single.selectionId, 'flv:4:1:1');
    final first = await site.resolvePlayUrlsRaw(detail: detail, quality: qualities.single);
    expect(first.urls, hasLength(2));
    final recovered = await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: qualities.single);
    expect(recovered.appliedQualityData, 'flv:4:1:1');
    expect(api.roomCalls, 3);

    expect(Sites.supportedSiteIds, contains(Sites.kugouLiveSite));
    expect(Sites.of(Sites.kugouLiveSite).liveSite, isA<KugouLiveSite>());
    expect(Sites.supportSites.where((entry) => entry.id == Sites.kugouLiveSite), hasLength(1));
  });
}

final class _FixtureApi extends KugouLiveApi {
  _FixtureApi() : super(request: (_, _, _) async => throw StateError('unused'));

  int roomCalls = 0;

  @override
  Future<List<KugouLiveCategory>> categories({CancelToken? cancel}) async => KugouLiveApi.fallbackCategories;

  @override
  Future<KugouLivePage> directory({required int page, String categoryId = '8000', CancelToken? cancel}) async =>
      KugouLiveApi.parseDirectoryJson(_directoryJson);

  @override
  Future<List<KugouLiveRoom>> search(String keyword, {CancelToken? cancel}) async =>
      KugouLiveApi.parseSearchJsonp('fixtureCallback($_searchJson);', callback: 'fixtureCallback').skip(1).toList();

  @override
  Future<KugouLiveRoom> room(String rawRoomId, {bool includeMedia = false, CancelToken? cancel}) async {
    roomCalls++;
    final roomId = KugouLiveLink.requireRoomId(rawRoomId);
    final base = KugouLiveApi.parseRoomJson(_roomJson, expectedRoomId: roomId);
    if (!includeMedia) return base;
    return KugouLiveRoom(
      roomId: base.roomId,
      userId: base.userId,
      kugouId: base.kugouId,
      nick: base.nick,
      title: base.title,
      avatar: base.avatar,
      cover: base.cover,
      currentViewers: base.currentViewers,
      followers: base.followers,
      popularity: base.popularity,
      state: base.state,
      variants: KugouLiveApi.parseMediaJson(_mediaJson, expectedRoomId: roomId),
    );
  }
}

final Map<String, dynamic> _directoryJson = {
  'code': 0,
  'data': {
    'hasNextPage': 1,
    'list': [
      {
        'roomId': 5085706,
        'userId': 1826299225,
        'kugouId': 1826299225,
        'nickName': '小初CHU',
        'label': '一起看烟花',
        'imgPath': 'http://p3.fx.kgimg.com/v2/fxroomcover/cover.jpg',
        'userLogo': 'http://p3.fx.kgimg.com/v2/fxuserlogo/avatar.jpg',
        'viewerNum': 79,
        'hot': 11266,
        'fansCount': 6539,
        'liveStatus': 1,
      },
      {
        'uiType': 'star',
        'data': {
          'roomId': 3437578,
          'userId': 1454781559,
          'kugouId': 1454781559,
          'nickName': '圆周率zz',
          'label': '能吹能唱能跳',
          'getViewerNum': 8,
          'hot': 32895,
          'fansCount': 30283,
          'status': 1,
        },
      },
    ],
  },
};

const _searchJson = '''{
  "status": 1,
  "data": {
    "anchor": {
      "list": [
        {"roomId": 5085706, "userId": 1, "kugouId": 1, "nickName": "live anchor", "liveStatus": 1},
        {"roomId": 5085707, "userId": 2, "kugouId": 2, "nickName": "offline anchor", "liveStatus": 0}
      ]
    }
  }
}''';

final Map<String, dynamic> _roomJson = {
  'code': 0,
  'data': {
    'liveSessionId': 'fixture-session',
    'liveType': 0,
    'normalRoomInfo': {
      'fansCount': 9083,
      'imgPath': '/v2/fxroomcover/cover.jpg',
      'kugouId': 1797665793,
      'limitType': 0,
      'nickName': 'Q梦星冉',
      'publicMesg': '如果做人必须得有抱负',
      'userId': 1797665793,
      'userLogo': '/v2/fxuserlogo/avatar.jpg',
    },
  },
};

String _signedUrl(String host, {String line = '105'}) =>
    'https://$host/live/fx_hifi_1797665793.flv?cn=fx&txSecret=0123456789abcdef0123456789abcdef'
    '&txTime=6AB1DA15&token=0-5085706-0-1010-7-1000-fixture-$line';

final Map<String, dynamic> _mediaJson = {
  'code': 0,
  'data': {
    'status': 1,
    'roomId': 5085706,
    'lines': [
      {
        'sid': 5,
        'streamProfiles': [
          {
            'layout': 1,
            'codec': 1,
            'rate': 4,
            'httpsFlv': [_signedUrl('tx105.liveplay.live.kugou.com'), _signedUrl('tx105.liveplay.live.kugou.com')],
            'httpsHls': <String>[],
          },
        ],
      },
      {
        'sid': 40,
        'streamProfiles': [
          {
            'layout': 1,
            'codec': 1,
            'rate': 4,
            'httpsFlv': [_signedUrl('tx106.liveplay.live.kugou.com', line: '106')],
            'httpsHls': <String>[],
          },
        ],
      },
    ],
  },
};
