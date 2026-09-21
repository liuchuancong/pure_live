import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/core/site/baidulive/baidu_live_api.dart';
import 'package:pure_live/core/site/baidulive/baidu_live_link.dart';
import 'package:pure_live/core/site/baidulive/baidu_live_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/modules/search/web_search_room_parser.dart';

void main() {
  test('Baidu links retain exact room identities on official room routes', () {
    expect(BaiduLiveLink.parseRoomId('11572411040'), '11572411040');
    expect(BaiduLiveLink.parseRoomId('https://live.baidu.com/m/room/11572411040?source=anchorrooms'), '11572411040');
    expect(
      BaiduLiveLink.parseRoomId(
        'https://live.baidu.com/m/media/pclive/pchome/live.html?room_id=11572411040&source=h5pre',
      ),
      '11572411040',
    );
    expect(
      BaiduLiveLink.parseRoomId('https://live.baidu.com/m/media/multipage/liveshow/index/cadm?room_id=11572411040'),
      '11572411040',
    );
    expect(LiveUrlTool.containsSupportedLink('百度 https://live.baidu.com/m/room/11572411040'), isTrue);
    expect(WebSearchRoomParser.parse('https://live.baidu.com/m/room/11572411040')?.platform, Sites.baiduLiveSite);
    for (final value in [
      'https://live.baidu.com/search?room_id=11572411040',
      'https://live.baidu.com.evil.test/m/room/11572411040',
      'https://user@live.baidu.com/m/room/11572411040',
      'http://live.baidu.com/m/room/11572411040',
      '12',
    ]) {
      expect(BaiduLiveLink.parseRoomId(value), isNull, reason: value);
    }
  });

  test('PC feed signature is sorted and directory keeps current viewers', () {
    expect(BaiduLiveApi.signFeedParameters({'b': '2', 'a': '1'}), '6ccb27769bec11fe1c1db46f74b97f15');
    final page = BaiduLiveApi.parseDirectoryJson(_directoryJson);
    expect(page.rooms, hasLength(10));
    expect(page.rooms.first.roomId, '11572411040');
    expect(page.rooms.first.currentViewers, 43);
    expect(page.rooms.first.state, BaiduLiveState.live);
    expect(page.categories.map((item) => item.id), ['rec', 'health']);
    expect(page.sessionId, 'fixture-session');
    expect(page.refreshIndex, 1);
    expect(page.hasMore, isTrue);
  });

  test('room detail keeps official FLV and HLS variants bound to the requested room', () {
    final room = BaiduLiveApi.parseRoomJson(_roomJson, expectedRoomId: '11572411040');
    expect(room.state, BaiduLiveState.live);
    expect(room.currentViewers, 43);
    expect(room.followers, 91);
    expect(room.variants.map((item) => item.id), containsAll(['flv:1080:avc', 'hls:720:avc']));
    expect(room.variants.expand((item) => item.urls).every((uri) => uri.scheme == 'https'), isTrue);
    expect(
      BaiduLiveApi.validateMediaUri(
        'https://hls-live.bdstatic.com/live/stream_bduid_1_99999999999.flv',
        expectedRoomId: '11572411040',
        protocol: 'flv',
      ),
      isNull,
    );
    expect(
      BaiduLiveApi.validateMediaUri(
        'https://hls.liveshow.lss-user.baidubce.com/live/stream_bduid_1_11572411040.m3u8',
        expectedRoomId: '11572411040',
        protocol: 'hls',
      ),
      isNull,
    );
  });

  test('site exposes directory, exact lookup, stable qualities and recovery', () async {
    final api = _FixtureApi();
    final site = BaiduLiveSite(api: api);
    final categories = await site.getCategores(1, 20);
    expect(categories.single.children, hasLength(7));

    final directory = await site.getDirectoryPage(page: 1);
    expect(directory.hasMore, isTrue);
    expect(directory.rooms.first.onlineViewers, '43');
    expect(directory.rooms.first.audienceMetricType, AudienceMetricType.onlineViewers);
    expect(await site.searchRooms('主播昵称'), isEmpty);
    final exact = await site.searchRooms('https://live.baidu.com/m/room/11572411040');
    expect(exact.single.roomId, '11572411040');

    final detail = await site.getRoomDetail(roomId: '11572411040', platform: Sites.baiduLiveSite);
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.map((quality) => quality.selectionId), containsAll(['flv:1080:avc', 'hls:720:avc']));
    final selected = qualities.firstWhere((quality) => quality.selectionId == 'flv:1080:avc');
    final first = await site.resolvePlayUrlsRaw(detail: detail, quality: selected);
    expect(first.urls.single, startsWith('https://hls-live.bdstatic.com/live/'));
    final recovered = await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: selected);
    expect(recovered.appliedQualityData, 'flv:1080:avc');
    expect(api.roomCalls, 3);

    expect(Sites.supportedSiteIds, contains(Sites.baiduLiveSite));
    expect(Sites.of(Sites.baiduLiveSite).liveSite, isA<BaiduLiveSite>());
    expect(Sites.supportSites.where((entry) => entry.id == Sites.baiduLiveSite), hasLength(1));
  });
}

final class _FixtureApi extends BaiduLiveApi {
  _FixtureApi() : super(request: (_, _, _, _) async => throw StateError('unused'));

  int roomCalls = 0;

  @override
  Future<BaiduLivePage> directory({
    required int page,
    required String tab,
    required int channelId,
    required String sessionId,
    required int refreshIndex,
    required String deviceId,
    CancelToken? cancel,
  }) async => BaiduLiveApi.parseDirectoryJson(_directoryJson);

  @override
  Future<BaiduLiveRoom> room(String rawRoomId, {bool includeMedia = false, CancelToken? cancel}) async {
    roomCalls++;
    return BaiduLiveApi.parseRoomJson(_roomJson, expectedRoomId: BaiduLiveLink.requireRoomId(rawRoomId));
  }
}

final Map<String, Object?> _directoryJson = {
  'errno': 0,
  'data': {
    'feed': {
      'inner_errno': 0,
      'session_id': 'fixture-session',
      'refresh_index': 1,
      'items': List.generate(
        10,
        (index) => {
          'room_id': 11572411040 + index,
          'title': index == 0 ? '长江新闻号正在播出' : '直播 $index',
          'cover': 'https://pic.rmb.bdstatic.com/bjh/fixture-$index.jpeg',
          'live_status': 1,
          'audience_count': 43 + index,
          'live_tag': '新闻',
          'host': {
            'uk': 'fixture-$index',
            'name': index == 0 ? '长江新闻号' : '主播 $index',
            'avatar': 'https://avatar.bdstatic.com/it/u=$index&size=b200,200',
          },
        },
      ),
    },
    'tab': {
      'inner_errno': 0,
      'items': [
        {'name': '推荐', 'type': 'rec', 'channel_id': 570},
        {'name': '健康', 'type': 'health', 'channel_id': 612},
      ],
    },
  },
};

final Map<String, Object?> _roomJson = {
  'errno': 0,
  'data': {
    '371': {
      'error_code': '0',
      'status': '0',
      'share_url': 'https://live.baidu.com/m/media/multipage/liveshow/index/news?room_id=11572411040',
      'online_users': '43',
      'real_fans_num': 91,
      'category': '新闻',
      'has_pay_service': 0,
      'is_forbidden_url': 0,
      'ban_status': 0,
      'host': {
        'uk': 'fixture-host',
        'nick_name': '长江新闻号',
        'fans': '90',
        'image': {'image_33': 'https://avatar.bdstatic.com/it/u=1&size=b200,200'},
      },
      'video': {
        'title': '长江新闻号正在播出',
        'cover': {'cover_100': 'https://pic.rmb.bdstatic.com/bjh/fixture.jpeg'},
        'live_hls_url': 'http://hls.liveshow.bdstatic.com/live/stream_bduid_836143438_11572411040-mid-LV720.m3u8',
        'live_flv_url': 'https://hls-live.bdstatic.com/live/stream_bduid_836143438_11572411040-L1.flv',
        'live_flv_url_origin': 'https://flv-live.bdstatic.com/live/stream_bduid_836143438_11572411040.flv',
        'url_clarity_list': [
          {
            'resolution': 1080,
            'urls': {
              'avc_flv': 'https://hls-live.bdstatic.com/live/stream_bduid_836143438_11572411040-LV1080.flv?logid=1',
            },
          },
        ],
        'url_list': [
          {
            'resolution': 720,
            'urls': [
              {
                'hls':
                    'http://hls.liveshow.lss-user.baidubce.com/live/stream_bduid_836143438_11572411040-mid-LV720.m3u8',
              },
            ],
          },
        ],
      },
    },
  },
};
