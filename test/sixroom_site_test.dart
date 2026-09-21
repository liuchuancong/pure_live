import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/core/site/sixroom/sixroom_api.dart';
import 'package:pure_live/core/site/sixroom/sixroom_link.dart';
import 'package:pure_live/core/site/sixroom/sixroom_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/modules/search/web_search_room_parser.dart';

void main() {
  test('official Six Rooms links preserve only durable room identities', () {
    expect(SixRoomLink.parseRoomId('8838'), '8838');
    expect(SixRoomLink.parseRoomId('https://v.6.cn/8838?from=home'), '8838');
    expect(SixRoomLink.parseRoomId('https://m.6.cn/profile/243126861'), '243126861');
    expect(LiveUrlTool.containsSupportedLink('直播 https://v.6.cn/8838'), isTrue);
    final target = WebSearchRoomParser.parse('https://m.6.cn/profile/243126861');
    expect(target?.platform, Sites.sixRoomSite);
    expect(target?.roomId, '243126861');
    for (final value in [
      'https://v.6.cn/search.php?key=8838',
      'https://m.v.6.cn/redian/8838',
      'https://v.6.cn.evil.test/8838',
      'https://user@v.6.cn/8838',
      'ftp://v.6.cn/8838',
      '1',
    ]) {
      expect(SixRoomLink.parseRoomId(value), isNull, reason: value);
    }
  });

  test('server-rendered lobby keeps official ordering, categories and popularity semantics', () {
    final rooms = SixRoomApi.parseDirectoryHtml(_directoryHtml);
    expect(rooms, hasLength(3));
    expect(rooms.map((room) => room.roomId), ['8838', '1890', '578888']);
    expect(rooms.first.userId, '56182128');
    expect(rooms.first.popularity, 23104);
    expect(rooms.first.category, '歌区');
    expect(rooms.first.state, SixRoomState.live);
    expect(rooms.last.category, '脱口秀');
  });

  test('category switches reuse the bounded lobby snapshot while an all refresh replaces it', () async {
    var requests = 0;
    final api = SixRoomApi(
      request: (_, _, _, _) async {
        requests++;
        return (status: 200, body: _directoryHtml);
      },
      clock: () => DateTime.utc(2026, 9, 21),
    );
    expect((await api.directory(page: 1, pageSize: 1)).rooms.single.roomId, '8838');
    expect((await api.directory(page: 1, pageSize: 10, categoryId: 'song')).rooms, hasLength(2));
    expect((await api.directory(page: 2, pageSize: 1)).rooms.single.roomId, '1890');
    expect(requests, 1);
    await api.directory(page: 1, pageSize: 1);
    expect(requests, 2);
  });

  test('official nickname search retains live and offline author identities', () {
    final rooms = SixRoomApi.parseSearchHtml(_searchHtml);
    expect(rooms, hasLength(2));
    expect(rooms.first.roomId, '1890');
    expect(rooms.first.userId, '31648937');
    expect(rooms.first.nick, '小荷叶~加油');
    expect(rooms.first.state, SixRoomState.unknown);
    expect(rooms.last.roomId, '243126861');
    expect(rooms.last.avatar, startsWith('https://vi1.6rooms.com/'));
  });

  test('room bootstrap binds UID, room, live session and FLV media identity', () {
    expect(SixRoomApi.parseRoomUserIdHtml(_roomHtml, '8838'), '56182128');
    final room = SixRoomApi.parseRoomJson(_liveRoomJson, expectedRoomId: '8838', expectedUserId: '56182128');
    expect(room.state, SixRoomState.live);
    expect(room.followers, 425585);
    expect(room.variants.single.id, 'flv:source');
    expect(room.variants.single.resolution, '1024x768');
    expect(room.variants.single.bitrate, 2653);
    expect(room.variants.single.urls.single.toString(), endsWith('/v56182128-222415076.flv'));
    expect(SixRoomApi.mediaUri(userId: '56182128', liveId: '222415076', flvTitle: 'v99999999-222415076'), isNull);
    final offline = SixRoomApi.parseRoomJson(_offlineRoomJson, expectedRoomId: '243126861', expectedUserId: '98073893');
    expect(offline.state, SixRoomState.offline);
    expect(offline.variants, isEmpty);
  });

  test('site pages the lobby, searches authors and refreshes stable playback input', () async {
    final api = _FixtureApi();
    final site = SixRoomSite(api: api);
    final categories = await site.getCategores(1, 20);
    expect(categories.single.children, hasLength(6));

    final first = await site.getDirectoryPage(page: 1);
    expect(first.rooms, hasLength(3));
    expect(first.rooms.first.audienceMetricType, AudienceMetricType.popularity);
    expect(first.rooms.first.popularity, '23104');
    final song = await site.getCategoryRooms(
      LiveArea(platform: Sites.sixRoomSite, areaType: 'official', areaId: 'song', areaName: '歌区'),
      pageSize: 10,
    );
    expect(song.map((room) => room.roomId), ['8838', '1890']);

    final search = await site.searchRooms('小荷叶');
    expect(search, hasLength(2));
    expect(search.first.roomId, '1890');
    final detail = await site.getRoomDetail(roomId: '8838', platform: Sites.sixRoomSite);
    expect(detail.followers, '425585');
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.single.selectionId, 'flv:source');
    final resolved = await site.resolvePlayUrlsRaw(detail: detail, quality: qualities.single);
    expect(resolved.urls.single, contains('/httpflv/v56182128-222415076.flv'));
    final recovered = await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: qualities.single);
    expect(recovered.appliedQualityData, 'flv:source');
    expect(api.roomCalls, 2);

    expect(Sites.supportedSiteIds, contains(Sites.sixRoomSite));
    expect(Sites.of(Sites.sixRoomSite).liveSite, isA<SixRoomSite>());
    expect(Sites.supportSites.where((entry) => entry.id == Sites.sixRoomSite), hasLength(1));
  });
}

final class _FixtureApi extends SixRoomApi {
  _FixtureApi() : super(request: (_, _, _, _) async => throw StateError('unused'));

  int roomCalls = 0;

  @override
  Future<SixRoomPage> directory({
    required int page,
    required int pageSize,
    String categoryId = 'all',
    CancelToken? cancel,
  }) async {
    final category = SixRoomApi.categories.firstWhere((item) => item.id == categoryId);
    final rooms = SixRoomApi.parseDirectoryHtml(_directoryHtml);
    final filtered = category.area == null ? rooms : rooms.where((room) => room.category == category.area).toList();
    final start = (page - 1) * pageSize;
    if (start >= filtered.length) return SixRoomPage(rooms: const [], hasMore: false);
    final end = (start + pageSize).clamp(0, filtered.length);
    return SixRoomPage(rooms: filtered.sublist(start, end), hasMore: end < filtered.length);
  }

  @override
  Future<List<SixRoomRoom>> search(String keyword, {CancelToken? cancel}) async =>
      SixRoomApi.parseSearchHtml(_searchHtml);

  @override
  Future<SixRoomRoom> room(
    String rawRoomId, {
    String? knownUserId,
    bool includeMedia = true,
    CancelToken? cancel,
  }) async {
    roomCalls++;
    expect(knownUserId, '56182128');
    return SixRoomApi.parseRoomJson(
      _liveRoomJson,
      expectedRoomId: SixRoomLink.requireRoomId(rawRoomId),
      expectedUserId: knownUserId!,
      includeMedia: includeMedia,
    );
  }
}

final String _directoryHtml = () {
  final rows = [
    {
      'rid': '8838',
      'uid': '56182128',
      'liveid': '222415076',
      'username': '唯一主播',
      'livetitle': '今晚唱歌',
      'count': '23104',
      'anchor_area': '歌区',
      'picuser': 'https://vi1.6rooms.com/live/avatar-1.jpg',
      'pospic': 'https://vi0.6rooms.com/live/cover-1.jpg',
    },
    {
      'rid': '1890',
      'uid': '31648937',
      'liveid': '222415100',
      'username': '小荷叶~加油',
      'userMood': '努力直播',
      'count': 3749,
      'anchor_area': '歌区',
      'picuser': 'https://vi0.6rooms.com/live/avatar-2.jpg',
      'pic': 'https://vi0.6rooms.com/live/cover-2.jpg',
    },
    {
      'rid': '578888',
      'uid': '82340792',
      'liveid': '222414543',
      'username': '户外主播',
      'livetitle': '清明上河图',
      'count': '15802',
      'anchor_area': '脱口秀',
      'picuser': 'https://vi2.6rooms.com/live/avatar-3.jpg',
      'pospic': 'https://vi1.6rooms.com/live/cover-3.jpg',
    },
  ];
  final root = jsonEncode({'typeList': jsonEncode(rows)});
  return '<html><script>window.__SMARTY_ALL_VARIABLES__ = $root;</script></html>';
}();

const String _searchHtml = '''
<html><body><div class="page-search page-search-user"><ul class="search-user">
<li data-uid="31648937"><a class="user-box" href="/profile/1890"><div class="pic"><img data-src="https://vi0.6rooms.com/live/a.jpg"></div><div class="alias">小荷叶~加油</div></a></li>
<li data-uid="98073893"><a class="user-box" href="/profile/243126861"><div class="pic"><img data-src="https://vi1.6rooms.com/live/b.jpg"></div><div class="alias">小荷叶～</div></a></li>
</ul></div></body></html>
''';

const String _roomHtml = '''
<html><head><link rel="canonical" href="https://v.6.cn/8838"></head><body><script>
var room = {rid: '56182128', roomid: '8838', liveid: '222415076'};
</script></body></html>
''';

final String _liveRoomJson = jsonEncode({
  'flag': '001',
  'content': {
    'roominfo': {
      'id': '56182128',
      'rid': '8838',
      'alias': '唯一主播',
      'headPicUrl': 'https://vi1.6rooms.com/live/avatar.jpg',
      'anchor_area': '歌区',
    },
    'liveinfo': {
      'id': '222415076',
      'title': '今晚唱歌',
      'flvtitle': 'v56182128-222415076',
      'spredPic': 'https://vi0.6rooms.com/live/cover.jpg',
      'content': {
        '1': {
          'streamInfo': {
            'v56182128-222415076': {'resolution': '1024x768', 'videoBitrate': 2653},
          },
        },
      },
    },
    'roomParamInfo': {'uid': '56182128', 'fans_num': 425585},
    'isPriveRoom': 0,
    'blackScreenInfo': {'msg': ''},
  },
});

final String _offlineRoomJson = jsonEncode({
  'flag': '001',
  'content': {
    'roominfo': {'id': '98073893', 'rid': '243126861', 'alias': '小荷叶～', 'anchor_area': ''},
    'liveinfo': {'id': '', 'title': '', 'flvtitle': ''},
    'roomParamInfo': {'uid': '98073893', 'fans_num': 36},
    'isPriveRoom': 0,
    'blackScreenInfo': {'msg': ''},
  },
});
