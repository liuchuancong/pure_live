import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/core/site/looklive/look_live_api.dart';
import 'package:pure_live/core/site/looklive/look_live_link.dart';
import 'package:pure_live/core/site/looklive/look_live_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/modules/search/web_search_room_parser.dart';

void main() {
  test('official LOOK links retain only exact live-room identities', () async {
    expect(LookLiveLink.parseRoomId('21623631'), '21623631');
    expect(LookLiveLink.parseRoomId('https://look.163.com/live?id=21623631&position=3'), '21623631');
    expect(LiveUrlTool.containsSupportedLink('LOOK https://look.163.com/live?id=21623631'), isTrue);
    final parsed = await LiveUrlTool.parseLiveUrl('LOOK https://look.163.com/live?id=21623631');
    expect(parsed, ['21623631', Sites.lookLiveSite]);
    final target = WebSearchRoomParser.parse('https://look.163.com/live?id=21623631');
    expect(target?.platform, Sites.lookLiveSite);
    expect(target?.roomId, '21623631');
    for (final value in [
      'https://look.163.com/hot?id=21623631',
      'https://look.163.com/live?id=21623631&id=2',
      'https://look.163.com.evil.test/live?id=21623631',
      'https://user@look.163.com/live?id=21623631',
      'ftp://look.163.com/live?id=21623631',
      'https://look.163.com/%FF?id=21623631',
      '1',
    ]) {
      expect(LookLiveLink.parseRoomId(value), isNull, reason: value);
    }
  });

  test('public browser envelope stays byte compatible with the official web codec', () {
    expect(LookLiveApi.encryptPayload({'liveRoomNo': '21623631'}), {
      'params': '1Tj+rp0BPunszj2VG7qpfM1E6qoUixjO7CPI+6CKGQxt6zJT23WuolhlA7I/no6V',
      'encSecKey': '35701388baf89fed412e11269b9c76625d095ecaf17f03fa018abe19ea2d38b949debf242ee39a71ca1f6cda71b1b86a45aa909ee27f7e78e267d34e732f0de948206c3340a788d0003372183e2f753c1f78b66ac23d134ac1fc9b993156520ea826b8aa89a962d4491b4b8d7e08738e1da9b07aa39bf4a7ef0b1c210728cd52',
    });
  });

  test('official video and voice pages preserve separate metrics and media', () async {
    final api = LookLiveApi(
      request: (uri, form, cancel) async {
        expect(form.keys, unorderedEquals(['params', 'encSecKey']));
        return (status: 200, body: uri.path.contains('/listen/') ? _audioDirectoryJson : _videoDirectoryJson);
      },
    );
    final video = await api.directory(kind: LookLiveKind.video, page: 1);
    expect(video.hasMore, isFalse);
    expect(video.rooms.single.roomId, '21623631');
    expect(video.rooms.single.kind, LookLiveKind.video);
    expect(video.rooms.single.popularity, 320);
    expect(video.rooms.single.currentViewers, 1);
    expect(video.rooms.single.variants.map((item) => item.id), ['hls:source', 'flv:source']);

    final audio = await api.directory(kind: LookLiveKind.audio, page: 1);
    expect(audio.hasMore, isTrue);
    expect(audio.rooms.single.roomId, '180655199');
    expect(audio.rooms.single.kind, LookLiveKind.audio);
    expect(audio.rooms.single.currentViewers, 8);
    expect(audio.rooms.single.variants.every((item) => item.uri.scheme == 'https'), isTrue);
  });

  test('room contract distinguishes live, offline and app-only sessions', () async {
    late String response;
    final api = LookLiveApi(request: (_, _, _) async => (status: 200, body: response));
    response = _videoRoomJson;
    final video = await api.room('21623631');
    expect(video.state, LookLiveState.live);
    expect(video.kind, LookLiveKind.video);
    expect(video.variants, hasLength(2));

    response = _offlineRoomJson;
    final offline = await api.room('65108820');
    expect(offline.state, LookLiveState.offline);
    expect(offline.variants, isEmpty);

    response = _appOnlyRoomJson;
    final appOnly = await api.room('645235480');
    expect(appOnly.state, LookLiveState.live);
    expect(appOnly.isAppOnly, isTrue);
    expect(appOnly.variants, isEmpty);

    final appOnlySameSession = LookLiveRoom(
      roomId: video.roomId,
      userId: video.userId,
      sessionId: video.sessionId,
      title: video.title,
      nick: video.nick,
      avatar: video.avatar,
      cover: video.cover,
      kind: video.kind,
      streamType: 50,
      state: LookLiveState.live,
      popularity: null,
      currentViewers: null,
      variants: const [],
    ).enrich(video);
    expect(appOnlySameSession.isAppOnly, isTrue);
    expect(appOnlySameSession.variants, isEmpty);
  });

  test('media allow-list accepts only official session-bound HLS and FLV shapes', () {
    expect(
      LookLiveApi.mediaUri(
        'http://pull0583d674.live.126.net/live/800897349fe246e994f36976011de4d5/playlist.m3u8',
        protocol: 'hls',
      ).toString(),
      startsWith('https://pull0583d674.live.126.net/'),
    );
    for (final value in [
      'https://pull0583d674.live.126.net.evil.test/live/800897349fe246e994f36976011de4d5.flv',
      'https://pull0583d674.live.126.net:444/live/800897349fe246e994f36976011de4d5.flv',
      'https://pull0583d674.live.126.net/live/not-a-session.flv',
    ]) {
      expect(() => LookLiveApi.mediaUri(value, protocol: 'flv'), throwsA(isA<LookLiveException>()), reason: value);
    }
  });

  test('site combines directories, resolves exact search and recovers the same source', () async {
    final api = _FixtureApi();
    final site = LookLiveSite(api: api);
    final categories = await site.getCategores(1, 20);
    expect(categories.single.children, hasLength(2));

    final directory = await site.getDirectoryPage(page: 1);
    expect(directory.rooms, hasLength(2));
    expect(directory.hasMore, isTrue);
    expect(await site.getRecommendRooms(pageSize: 1), hasLength(1));
    expect(directory.rooms.first.onlineViewers, '1');
    expect(directory.rooms.first.popularity, '320');
    expect(directory.rooms.first.audienceMetricType, AudienceMetricType.onlineViewers);

    final audio = await site.getCategoryRooms(
      LiveArea(platform: Sites.lookLiveSite, areaType: 'official', areaId: 'audio', areaName: 'Voice'),
    );
    expect(audio.single.roomId, '180655199');
    expect(await site.searchRooms('not present'), isEmpty);
    expect((await site.searchRooms('Armin')).single.roomId, '21623631');
    expect((await site.searchRooms('https://look.163.com/live?id=21623631')).single.roomId, '21623631');

    final detail = await site.getRoomDetail(roomId: '21623631', platform: Sites.lookLiveSite);
    expect(detail.onlineViewers, '1');
    final qualities = await site.getPlayQualites(detail: detail);
    expect(qualities.map((item) => item.selectionId), ['hls:source', 'flv:source']);
    final hls = qualities.first;
    expect((await site.resolvePlayUrlsRaw(detail: detail, quality: hls)).urls.single, endsWith('/playlist.m3u8'));
    expect((await site.resolvePlayUrlsForRecoveryRaw(detail: detail, quality: hls)).appliedQualityData, 'hls:source');
    expect(api.roomCalls, 3);

    expect(Sites.supportedSiteIds, contains(Sites.lookLiveSite));
    expect(Sites.of(Sites.lookLiveSite).liveSite, isA<LookLiveSite>());
    expect(Sites.supportSites.where((entry) => entry.id == Sites.lookLiveSite), hasLength(1));
  });
}

final class _FixtureApi extends LookLiveApi {
  _FixtureApi() : super(request: (_, _, _) async => throw StateError('unused'));

  int roomCalls = 0;

  @override
  Future<LookLivePage> directory({required LookLiveKind kind, int page = 1, CancelToken? cancel}) async {
    final json = kind == LookLiveKind.audio ? _audioDirectoryJson : _videoDirectoryJson;
    final api = LookLiveApi(request: (_, _, _) async => (status: 200, body: json));
    return api.directory(kind: kind, page: page, cancel: cancel);
  }

  @override
  Future<LookLiveRoom> room(String input, {bool includeMedia = true, CancelToken? cancel}) async {
    roomCalls++;
    final api = LookLiveApi(request: (_, _, _) async => (status: 200, body: _videoRoomJson));
    return api.room(input, includeMedia: includeMedia, cancel: cancel);
  }
}

const String _videoDirectoryJson = '''
{"code":200,"data":{"itemList":[{"type":"1","liveData":{"popularity":320,"userInfo":{"userId":351218439,"nickname":"Armin van Buuren","avatarUrl":"http://p3.music.126.net/avatar.jpg","liveRoomNo":21623631},"liveId":134543183,"liveTitle":"ASOT 电音电台直播中","liveCoverUrl":"http://p3.music.126.net/cover.jpg","liveUrl":{"httpPullUrl":"http://pull0583d674.live.126.net/live/800897349fe246e994f36976011de4d5.flv?netease=pull0583d674.live.126.net","hlsPullUrl":"http://pull0583d674.live.126.net/live/800897349fe246e994f36976011de4d5/playlist.m3u8"},"onlineNumber":1,"liveType":1,"liveStreamType":1}}],"hasMore":false,"offset":20}}
''';

const String _audioDirectoryJson = '''
{"code":200,"data":{"itemList":[{"type":"1","liveData":{"popularity":40951,"userInfo":{"userId":1418067870,"nickname":"Young雅木茶_","avatarUrl":"http://p4.music.126.net/audio-avatar.jpg","liveRoomNo":180655199},"liveId":134593499,"liveTitle":"青年流行 旋律","liveCoverUrl":"http://p4.music.126.net/audio-cover.jpg","liveUrl":{"httpPullUrl":"http://pull0583d674.live.126.net/live/7fc31796b48645c8a1f8a73fd1f51fbc.flv?netease=pull0583d674.live.126.net","hlsPullUrl":"http://pull0583d674.live.126.net/live/7fc31796b48645c8a1f8a73fd1f51fbc/playlist.m3u8"},"onlineNumber":8,"liveType":2}}],"hasMore":true}}
''';

const String _videoRoomJson = '''
{"code":200,"data":{"roomInfo":{"id":134543183,"roomId":462192286,"title":"ASOT 电音电台直播中","liveCoverUrl":"https://p1.music.126.net/cover.jpg","liveStreamType":1,"liveUrl":{"httpPullUrl":"http://pull0583d674.live.126.net/live/800897349fe246e994f36976011de4d5.flv?netease=pull0583d674.live.126.net","hlsPullUrl":"http://pull0583d674.live.126.net/live/800897349fe246e994f36976011de4d5/playlist.m3u8"},"liveType":1},"liveStatus":1,"anchor":{"userId":351218439,"nickName":"Armin van Buuren","avatarUrl":"http://p2.music.126.net/avatar.jpg","liveRoomNo":"21623631"}}}
''';

const String _offlineRoomJson = '''
{"code":200,"data":{"roomInfo":{"id":109455389,"roomId":381668289,"title":"你喜欢的甜美声音","liveCoverUrl":"https://p1.music.126.net/offline.jpg","liveStreamType":6,"liveUrl":{"httpPullUrl":"http://pull0583d674.live.126.net/live/fa637558213447a8b7348074436426fe.flv","hlsPullUrl":"http://pull0583d674.live.126.net/live/fa637558213447a8b7348074436426fe/playlist.m3u8"},"liveType":2},"liveStatus":-1,"anchor":{"userId":419238969,"nickName":"Babe","avatarUrl":"http://p2.music.126.net/offline-avatar.jpg","liveRoomNo":"65108820"}}}
''';

const String _appOnlyRoomJson = '''
{"code":200,"data":{"roomInfo":{"id":134529157,"roomId":15148749147,"title":"在云村做主播是种什么体验","liveCoverUrl":"https://p1.music.126.net/app-only.jpg","liveStreamType":50,"liveUrl":null,"liveType":1},"liveStatus":1,"anchor":{"userId":17650321062,"nickName":"zy-晗辰男友-天使冠","avatarUrl":"http://p2.music.126.net/app-only-avatar.jpg","liveRoomNo":"645235480"}}}
''';
