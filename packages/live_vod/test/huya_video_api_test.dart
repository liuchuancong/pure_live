// The station's pages and answers, pinned against canned ones: the SSR
// envelope's metadata functions and bare literals are read without being
// evaluated, every list shape comes back as the model the app renders, and
// the rendition ladder opens at the app's own ceiling rather than the
// station's.
import 'package:live_vod/live_vod.dart';
import 'package:test/test.dart';

/// One page carrying every shape the reader meets: a prototype function with
/// a brace inside a string, a nested metadata function, wrapped lists, a bare
/// `undefined`, an int uid beside a string one, and an escaped title.
const String _page = r'''
<!doctype html><html><body><script>
window.HNF_GLOBAL_INIT = {
  "aggregationList": [{
    "recommendItem": {
      "title": "王者荣耀",
      "cover": "http:\u002F\u002Fv-huya-pic.huya.com\u002Fa.png",
      "setId": 15,
      "channelItemList": {
        "_proto": function() {
          this.id = "";
          this.name = "a}b";
          this._classname = "HUYAVIDEO.ChannelItem";
        },
        "_bValue": 0,
        "value": [{"id": "vhuyawzry", "name": "王者荣耀"}],
        "_classname": "list<HUYAVIDEO.ChannelItem>"
      },
      "_classname": "HUYAVIDEO.RecommendItem"
    },
    "videoInfoList": {
      "_bValue": 0,
      "value": [{
        "vid": 1131637106,
        "videoTitle": "决赛 &amp; 高光",
        "duration": "39:10",
        "cover": "https://v-huya-img2.msstatic.com/screenshot/a.jpg",
        "playNums": 30057,
        "userInfo": {"uid": 1571877666, "userNick": "赛事", "avatar": "https://huyaimg.msstatic.com/avatar/a_180_135.jpg"}
      }]
    }
  }],
  "channelList": [
    {"setId": 3, "title": "手机游戏", "channelItemList": {"_bValue": 0, "value": [
      {"id": "all", "name": "全部视频"}, {"id": "vhuyawzry", "name": "王者荣耀"}
    ]}},
    {"setId": 0, "title": "全部", "channelItemList": {"_classname": "list<HUYAVIDEO.ChannelItem>", "value": [
      {"id": "all", "name": "全部视频"}, {"id": "bad id!", "name": "坏"}
    ]}}
  ],
  "channelInfo": {"channelId": "all", "setId": 3, "orderType": 1, "pageIndex": 2, "channelName": "全部视频", "categoryTitle": "手机游戏"},
  "videoData": {
    "respHeader": {"code": 0, "msg": ""},
    "videoDataList": {"_bValue": 0, "value": [{
      "vid": 1132205036,
      "videoTitle": "2026 全球总决赛\n\n 采访",
      "duration": "02:13",
      "rawDuration": 133.6,
      "covers": {
        "cover": "https://v-huya-img2.msstatic.com/screenshot/b.jpg",
        "cover640": "https://v-huya-img2.msstatic.com/screenshot/b640.jpg"
      },
      "playNums": 1107,
      "danmuNums": 12,
      "publishTime": 1794193455,
      "channelId": "valorant",
      "channelName": "无畏契约",
      "userInfo": {"uid": "1239539066562", "userNick": "英雄联盟赛事菌", "avatar": "https://huyaimg.msstatic.com/avatar/b.jpg"},
      "brief": "赛后的第一句话"
    }]},
    "total": 45
  },
  "relateVideoRsp": {"videoDataList": {"_bValue": 0, "value": [{
    "vid": 1131757974,
    "videoTitle": "隔壁",
    "duration": "28:21",
    "covers": {"cover320": "https://v-huya-img2.msstatic.com/c.jpg"},
    "userInfo": {"uid": 1, "userNick": "x"}
  }]}},
  "channelItemList": {"_bValue": 0, "value": [{"id": "all", "name": "全部视频"}, {"id": "cs:go", "name": "CS2"}]},
  "rankData": {
    "respHeader": {"code": 0},
    "list": {"_bValue": 0, "value": [{"score": 9, "videoData": {
      "vid": 1132056694, "videoTitle": "榜首", "duration": "1:02:03",
      "userInfo": {"uid": 2, "userNick": "y"}
    }}]},
    "updateTime": "2026-11-09 01:40:03",
    "total": 120
  },
  "page": 2,
  "userInfoRsp": {"userInfo": {
    "uid": "1239539066562", "nick": "英雄联盟赛事菌",
    "avatar": "https://huyaimg.msstatic.com/avatar/u.jpg", "intro": "官方",
    "videoNum": 785, "videoPlayNum": 5115881, "subscribedNum": 2895,
    "isLiving": 1, "roomId": 88
  }},
  "userPageVideoLisRsp": {"videoDataList": {"_bValue": 0, "value": [{
    "vid": 1132205037, "videoTitle": "页内",
    "userInfo": {"uid": 1239539066562, "userNick": "英雄联盟赛事菌"}
  }]}, "total": 785},
  "userPageLiveRecordVideoRsp": {"respHeader": {"code": 0}, "videoDataList": {"_bValue": 0, "value": [{
    "videoData": {
      "vid": 1131962968, "videoTitle": "回放 &amp; 一", "duration": "01:02:03",
      "covers": {"cover320": "https://v-huya-img2.msstatic.com/x.jpg"},
      "userInfo": {"uid": 1239539066562, "userNick": "主播"}
    },
    "date": "2026-11-01"
  }]}, "total": 30},
  "userPageLiveRecordVideoRspB": undefined
}
</script></body></html>
''';

const String _detail = '''
{"status":200,"msg":"","data":{"moment":{"videoInfo":{
  "uid": 1571877666,
  "avatarUrl": "https://huyaimg.msstatic.com/avatar/a.jpg",
  "nickName": "王者荣耀赛事",
  "vid": 1131757974,
  "videoTitle": "杭州LGD.NBW vs 上海EDG.M-2",
  "videoCover": "https://v-huya-img2.msstatic.com/screenshot/c.jpg",
  "videoPlayNum": 11183,
  "videoCommentNum": 4,
  "videoDuration": "28:21",
  "videoUploadTime": "2026-11-05 18:46:18",
  "videoChannel": "vhuyawzry",
  "category": "王者荣耀",
  "briefIntroduction": "KPL 年度总决赛",
  "tags": ["KPL", "王者荣耀"],
  "definitions": [
    {"size":"98089668","width":"800","height":"450","definition":"350","defName":"360P",
     "url":"http://videoal-platform.cdn.huya.com/leaf/350_264_360_1_ai.mp4?vid=1131757974",
     "m3u8":"http://videoal-platform.cdn.huya.com/leaf/350_264_360_1_ai.m3u8?vid=1131757974"},
    {"size":"1550024374","width":"2560","height":"1440","definition":"14100","defName":"2K HDR",
     "url":"https://videoal-platform.cdn.huya.com/leaf/14100_264.mp4?vid=1131757974",
     "m3u8":"https://videoal-platform.cdn.huya.com/leaf/14100_264.m3u8?vid=1131757974"},
    {"size":"865864294","width":"1920","height":"1080","definition":"4000","defName":"1080P",
     "url":"https://videoal-platform.cdn.huya.com/leaf/4000_264.mp4?vid=1131757974",
     "m3u8":"https://videoal-platform.cdn.huya.com/leaf/4000_264.m3u8?vid=1131757974"},
    {"size":"1225833458","width":"1920","height":"1080","definition":"4100","defName":"1080P HDR",
     "url":"https://videoal-platform.cdn.huya.com/leaf/4100_264.mp4?vid=1131757974",
     "m3u8":"https://videoal-platform.cdn.huya.com/leaf/4100_264.m3u8?vid=1131757974"},
    {"size":"1","width":"1920","height":"1080","definition":"9999","defName":"远处",
     "url":"https://evil.example.com/leaf/9999_264.mp4?vid=1131757974",
     "m3u8":"https://evil.example.com/leaf/9999_264.m3u8?vid=1131757974"}
  ]
}}}}
''';

const String _search = '''
{"responseHeader":{"status":0},"response":{"122":{"numFound":647,"start":0,"docs":[
  {"cover":"https://v-huya-img2.msstatic.com/99.jpg","play_sum":35168,
   "title":"【速看】第2局 BLG vs T1","uptime":"2026-11-09 08:16","url":"",
   "user_avatar":"https://huyaimg.msstatic.com/avatar/a.jpg","user_id":1239539066562,
   "user_nickname":"英雄联盟赛事菌","vid":1132194782},
  {"vid":"bad","title":"坏"}
]}}}
''';

void main() {
  final root = HuyaSsr.parse(_page);

  test('the envelope drops its metadata functions and bare literals, not data', () {
    expect(root['userPageLiveRecordVideoRspB'], isNull);
    final aggregation = root['aggregationList']! as List;
    expect(aggregation, hasLength(1));
    final item = HuyaSsr.record((aggregation.first as Map)['recommendItem'])!;
    expect(item['setId'], 15);
    final items = HuyaSsr.rows(item['channelItemList']);
    expect(items.single['id'], 'vhuyawzry');
  });

  test('a page without the assignment refuses', () {
    expect(() => HuyaSsr.parse('<html>nothing</html>'), throwsA(isA<VodFailure>()));
    expect(() => HuyaSsr.parse('window.HNF_GLOBAL_INIT = {"a":1'), throwsA(isA<VodFailure>()));
  });

  test('the home keeps the shelves that carry videos', () {
    final home = HuyaVideoApi.parseHome(root);
    final shelf = home.shelves.single;
    expect(shelf.title, '王者荣耀');
    expect(shelf.channelId, 'vhuyawzry');
    expect(shelf.setId, 15);
    expect(shelf.cover, 'http://v-huya-pic.huya.com/a.png');
    final video = shelf.videos.single;
    expect(video.id, '1131637106');
    expect(video.title, '决赛 & 高光');
    expect(video.duration, const Duration(minutes: 39, seconds: 10));
    expect(video.playCount, 30057);
    expect(video.uploaderId, '1571877666');
    expect(video.uploaderName, '赛事');
  });

  test('the groups keep the station order and drop channel ids its paths reject', () {
    final groups = HuyaVideoApi.parseGroups(root);
    expect(groups.map((group) => group.setId), [3, 0]);
    expect(groups.first.channels.map((channel) => channel.id), ['all', 'vhuyawzry']);
    expect(groups.last.channels.map((channel) => channel.id), ['all']);
  });

  test('a listing page folds its titles, prefers the wide cover and reads both uid shapes', () {
    final page = HuyaVideoApi.parseList(root, page: 2);
    expect(page.page, 2);
    expect(page.total, 45);
    expect(page.hasMore, isTrue);
    final video = page.videos.single;
    expect(video.title, '2026 全球总决赛 采访');
    expect(video.duration, const Duration(minutes: 2, seconds: 13));
    expect(video.cover, 'https://v-huya-img2.msstatic.com/screenshot/b640.jpg');
    expect(video.uploaderId, '1239539066562');
    expect(video.danmakuCount, 12);
    expect(video.brief, '赛后的第一句话');
    expect(video.publishedAt!.toUtc().year, 2026);
  });

  test('a board keeps its stands, its update clock and its own page', () {
    final rank = HuyaVideoApi.parseRank(root, page: 2);
    expect(rank.page, 2);
    expect(rank.total, 120);
    expect(rank.hasMore, isTrue);
    expect(rank.videos.single.title, '榜首');
    expect(rank.updatedAt, DateTime(2026, 11, 9, 1, 40, 3));
  });

  test('the boards keep the station order', () {
    final boards = HuyaVideoApi.parseBoards(root);
    expect(boards.map((board) => board.id), ['all', 'cs:go']);
  });

  test('the videos beside one keep their own covers', () {
    final related = HuyaVideoApi.parseRelated(root);
    expect(related.single.id, '1131757974');
    expect(related.single.cover, 'https://v-huya-img2.msstatic.com/c.jpg');
  });

  test('an uploader page carries its owner, its count and its rows', () {
    final page = HuyaVideoApi.parseUploader(root, page: 1);
    expect(page.uploader.id, '1239539066562');
    expect(page.uploader.name, '英雄联盟赛事菌');
    expect(page.uploader.videoCount, 785);
    expect(page.uploader.isLiving, isTrue);
    expect(page.uploader.roomId, 88);
    expect(page.videos.single.id, '1132205037');
    expect(page.hasMore, isTrue);
  });

  test('the search answer reads its own bucket and ignores a foreign id', () {
    final page = HuyaVideoApi.parseSearch(_search);
    expect(page.total, 647);
    expect(page.videos.single.id, '1132194782');
    expect(page.videos.single.title, '【速看】第2局 BLG vs T1');
    expect(page.videos.single.playCount, 35168);
    expect(page.videos.single.uploaderName, '英雄联盟赛事菌');
    expect(page.videos.single.publishedAt, DateTime(2026, 11, 9, 8, 16));
    expect(page.videos.single.duration, Duration.zero);
  });

  test('a refused search index is a failure, not an empty answer', () {
    expect(
      () => HuyaVideoApi.parseSearch('{"responseHeader":{"status":-1},"response":{}}'),
      throwsA(isA<VodFailure>()),
    );
    expect(() => HuyaVideoApi.parseSearch('not json'), throwsA(isA<VodFailure>()));
  });

  test('the ladder is best first, drops a foreign host and opens at 1080P plain', () {
    final detail = HuyaVideoApi.parseDetail(_detail);
    expect(detail.video.id, '1131757974');
    expect(detail.video.title, '杭州LGD.NBW vs 上海EDG.M-2');
    expect(detail.video.duration, const Duration(minutes: 28, seconds: 21));
    expect(detail.video.uploaderName, '王者荣耀赛事');
    expect(detail.video.channelName, '王者荣耀');
    expect(detail.video.brief, 'KPL 年度总决赛');
    expect(detail.tags, ['KPL', '王者荣耀']);
    expect(detail.qualities.map((quality) => quality.label), ['2K HDR', '1080P HDR', '1080P', '360P']);
    expect(detail.qualities.every((quality) => quality.format == 'mp4'), isTrue);
    expect(detail.qualities.first.url.startsWith('https://'), isTrue);
    expect(detail.qualities.last.url, contains('/350_264_360_1_ai.mp4'));
    expect(HuyaVideoApi.openingQuality(detail.qualities)!.label, '1080P');
  });

  test('a refused detail answer is a failure', () {
    expect(() => HuyaVideoApi.parseDetail('{"status":500}'), throwsA(isA<VodFailure>()));
    expect(() => HuyaVideoApi.parseDetail('{}'), throwsA(isA<VodFailure>()));
  });

  test('the archive list reads the live-record answer and keeps its own uid', () {
    final list = HuyaArchiveApi.parseList(_page, uid: '1239539066562', page: 1);
    final video = list.videos.single;
    expect(video.id, '1131962968');
    expect(video.title, '回放 & 一');
    expect(video.duration, const Duration(hours: 1, minutes: 2, seconds: 3));
    expect(video.date, '2026-11-01');
    expect(list.hasMore, isTrue);
  });

  test('another presenter never lands under the requested uid', () {
    final other = _page.replaceFirst('"uid": 1239539066562, "userNick": "主播"', '"uid": 999, "userNick": "别人"');
    final list = HuyaArchiveApi.parseList(other, uid: '1239539066562', page: 1);
    expect(list.videos, isEmpty);
    expect(list.hasMore, isFalse);
  });

  test('an uploader with no live records answers empty rather than refusing', () {
    final none = _page.replaceFirst(
      '"userPageLiveRecordVideoRsp": {"respHeader": {"code": 0}',
      '"userPageLiveRecordVideoRsp": {"respHeader": {"code": 5}',
    );
    final list = HuyaArchiveApi.parseList(none, uid: '1239539066562', page: 1);
    expect(list.videos, isEmpty);
  });

  test('the rendition answer keeps m3u8 playlists only', () {
    final qualities = HuyaArchiveApi.parseQualities(_detail);
    expect(qualities, isNotEmpty);
    expect(qualities.every((quality) => quality.url.endsWith('.m3u8') || quality.url.contains('.m3u8?')), isTrue);
    expect(qualities.first.label, '2K HDR');
  });

  test('a JSON body that is not an object refuses', () {
    expect(() => HuyaArchiveApi.parseQualities('[]'), throwsA(isA<VodFailure>()));
    expect(HuyaArchiveApi.parseQualities('{"status":200}'), isEmpty);
  });
}
