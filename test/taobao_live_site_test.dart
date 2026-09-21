import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/core/site/taobaolive/taobao_live_api.dart';
import 'package:pure_live/core/site/taobaolive/taobao_live_link.dart';
import 'package:pure_live/core/site/taobaolive/taobao_live_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test('Taobao identities retain exact live and creator ownership', () {
    expect(TaobaoLiveLink.parseStorageKey(_liveId)?.storageKey, 'live:$_liveId');
    expect(TaobaoLiveLink.parseStorageKey('creator:$_creatorId')?.storageKey, 'creator:$_creatorId');
    expect(TaobaoLiveLink.parse('https://h5.m.taobao.com/taolive/video.html?id=$_liveId')?.storageKey, 'live:$_liveId');
    expect(TaobaoLiveLink.parse('https://tbzb.taobao.com/live?liveId=$_liveId')?.storageKey, 'live:$_liveId');
    expect(
      TaobaoLiveLink.parse('https://huodong.m.taobao.com/act/talent/live.html?userId=$_creatorId')?.storageKey,
      'creator:$_creatorId',
    );
    expect(
      TaobaoLiveLink.parseLandingPage(
        r'''<script>var url = 'https:\/\/h5.m.taobao.com\/taolive\/video.html?id=12345678901\u0026x=1';</script>''',
      )?.storageKey,
      'live:$_liveId',
    );
    expect(TaobaoLiveLink.shortUri('https://m.tb.cn/h.fixture_1'), isNotNull);
    expect(TaobaoLiveLink.parse('https://h5.m.taobao.com.evil.test/taolive/video.html?id=$_liveId'), isNull);
    expect(TaobaoLiveLink.parse('https://h5.m.taobao.com/taolive/main.html?id=$_liveId'), isNull);
  });

  test('anonymous MTop bootstrap signs the second request and validates HLS', () async {
    final requests = <Uri>[];
    final headers = <Map<String, String>>[];
    final api = TaobaoLiveApi(
      clock: () => 1800000000000,
      request: (uri, requestHeaders, _) async {
        requests.add(uri);
        headers.add(requestHeaders);
        if (uri.host == 'liveng.alicdn.com') {
          return const TaobaoLiveHttpResponse(status: 200, body: _playlist);
        }
        if (requests.length == 1) {
          expect(uri.queryParameters['sign'], isEmpty);
          return const TaobaoLiveHttpResponse(
            status: 200,
            body: '{"ret":["FAIL_SYS_TOKEN_EMPTY::令牌为空"]}',
            setCookies: [
              '_m_h5_tk=0123456789abcdef0123456789abcdef_1900000000000; Path=/',
              '_m_h5_tk_enc=fixture; Path=/',
            ],
          );
        }
        expect(uri.queryParameters['sign'], matches(RegExp(r'^[a-f0-9]{32}$')));
        return TaobaoLiveHttpResponse(status: 200, body: jsonEncode(_liveResponse));
      },
    );

    final room = await api.room(TaobaoLiveIdentity.creator(_creatorId), includeMedia: true);
    expect(requests, hasLength(3));
    expect(headers[1]['Cookie'], contains('_m_h5_tk='));
    expect(headers.last, isNot(contains('Cookie')));
    expect(room.state, TaobaoLiveState.live);
    expect(room.liveId, _liveId);
    expect(room.creatorId, _creatorId);
    expect(room.totalViews, 8668468);
    expect(room.followers, 95268239);
    expect(room.variants.map((variant) => variant.id), ['ud', 'ld']);
  });

  test('media, child playlist and lease contracts reject unrelated sources', () {
    final room = TaobaoLiveApi.parseRoomJson(_liveResponse, identity: TaobaoLiveIdentity.live(_liveId));
    expect(room.variants, hasLength(2));
    expect(() => TaobaoLiveApi.validatePlaylist(_playlist, expected: room.variants.first.hls!), returnsNormally);
    expect(
      () => TaobaoLiveApi.validatePlaylist(
        _playlist.replaceFirst('stream-main-001.ts', 'other-stream-001.ts'),
        expected: room.variants.first.hls!,
      ),
      throwsA(isA<TaobaoLiveException>()),
    );
    final invalidAt = TaobaoLiveApi.mediaInvalidAt(room.variants.first.hls.toString());
    expect(invalidAt, DateTime.fromMillisecondsSinceEpoch(1900000000 * 1000, isUtc: true));
    expect(
      TaobaoLiveApi.mediaRefreshAt(
        room.variants.first.hls.toString(),
        now: DateTime.fromMillisecondsSinceEpoch(1899990000 * 1000, isUtc: true),
      ),
      invalidAt!.subtract(const Duration(minutes: 5)),
    );

    final poisoned = <String, dynamic>{
      ..._liveResponse,
      'data': {
        ...(_liveResponse['data']! as Map<String, dynamic>),
        'liveUrlList': [
          {
            'definition': 'hd',
            'hlsUrl': 'https://example.com/liveplatform/stream-main.m3u8?auth_key=1900000000-0-0-fixture',
          },
        ],
      },
    };
    final rejected = TaobaoLiveApi.parseRoomJson(poisoned, identity: TaobaoLiveIdentity.live(_liveId));
    expect(rejected.variants, isEmpty);
  });

  test('site keeps creator identity stable across detail and recovery', () async {
    final api = _FixtureApi();
    final site = TaobaoLiveSite(api: api);
    final directory = await site.getDirectoryPage();
    expect(directory.rooms, isEmpty);
    final search = await site.searchRooms('https://m.tb.cn/h.fixture_1');
    expect(search.single.roomId, 'creator:$_creatorId');
    expect(search.single.totalViewers, '8668468');
    expect(search.single.followers, '95268239');
    expect(search.single.audienceMetricType, AudienceMetricType.totalViewers);

    final detail = await site.getRoomDetail(roomId: 'creator:$_creatorId', platform: Sites.taobaoLiveSite);
    expect(detail.liveStatus, LiveStatus.live);
    expect(detail.httpHeaders, isNot(contains('Cookie')));
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.map((quality) => quality.selectionId), ['ud', 'ld']);
    final resolved = await site.resolvePlayUrlsRaw(detail: detail, quality: qualities.first);
    expect(resolved.urls, hasLength(2));
    expect(resolved.urls.first, contains('stream-main.m3u8'));
    final recovered = await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: qualities.first);
    expect(recovered.appliedQualityData, 'ud');
    expect(api.roomCalls, 3);

    final serialized = jsonEncode(detail.toJson());
    expect(serialized, isNot(contains('auth_key')));
    expect(serialized, isNot(contains('_m_h5_tk')));
    expect(Sites.supportedSiteIds, contains(Sites.taobaoLiveSite));
    expect(Sites.of(Sites.taobaoLiveSite).liveSite, isA<TaobaoLiveSite>());
    expect(Sites.supportSites.where((entry) => entry.id == Sites.taobaoLiveSite), hasLength(1));
  });

  test('global link parser delegates Taobao share links to the bounded resolver', () async {
    final result = await LiveUrlTool.parseLiveUrl('淘宝直播 https://m.tb.cn/h.fixture_1', taobaoLiveApi: _FixtureApi());
    expect(result, ['creator:$_creatorId', Sites.taobaoLiveSite]);
  });
}

final class _FixtureApi extends TaobaoLiveApi {
  _FixtureApi() : super(request: (_, _, _) async => throw StateError('unused'));

  int roomCalls = 0;

  @override
  Future<TaobaoLiveIdentity> resolveReference(String raw, {CancelToken? cancel}) async =>
      TaobaoLiveIdentity.creator(_creatorId);

  @override
  Future<TaobaoLiveRoom> room(TaobaoLiveIdentity identity, {bool includeMedia = false, CancelToken? cancel}) async {
    roomCalls++;
    return TaobaoLiveApi.parseRoomJson(_liveResponse, identity: identity);
  }
}

const _liveId = '12345678901';
const _creatorId = '987654321';
const _hlsMain = 'http://liveng.alicdn.com/liveplatform/stream-main.m3u8?auth_key=1900000000-0-0-fixture&source=test';
const _flvMain = 'http://liveng.alicdn.com/liveplatform/stream-main.flv?auth_key=1900000000-0-0-fixture&source=test';
const _hlsLow = 'http://liveng.alicdn.com/mediaplatform/stream-low.m3u8?auth_key=1900000000-0-0-fixture&source=test';
const _flvLow = 'http://liveng.alicdn.com/mediaplatform/stream-low.flv?auth_key=1900000000-0-0-fixture&source=test';

final Map<String, dynamic> _liveResponse = {
  'ret': ['SUCCESS::调用成功'],
  'data': {
    'liveId': _liveId,
    'accountId': _creatorId,
    'streamStatus': 1,
    'roomStatus': 1,
    'taobaoLiveOnly': false,
    'title': 'Fixture live shopping',
    'coverImg': '//gw.alicdn.com/fixture-cover.jpg',
    'viewCount': 8668468,
    'broadCaster': {
      'accountId': _creatorId,
      'accountName': 'Fixture Creator',
      'fansNum': 95268239,
      'headImg': '//img.alicdn.com/fixture-avatar.jpg',
    },
    'liveUrlList': [
      {'definition': 'md', 'name': 'HD', 'hlsUrl': _hlsMain, 'flvUrl': _flvMain},
      {'newDefinition': 'ud', 'newName': 'Original', 'hlsUrl': _hlsMain, 'flvUrl': _flvMain},
      {'definition': 'ld', 'name': 'Smooth', 'hlsUrl': _hlsLow, 'flvUrl': _flvLow},
    ],
  },
};

const _playlist = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:8
#EXTINF:8.000,
stream-main-001.ts?auth_key=1900000000-0-0-child
''';
