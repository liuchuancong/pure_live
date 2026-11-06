// The VOD client, pinned against canned answers: the search's markup is
// stripped and its relative cover addresses get a scheme, the first part's cid
// reaches the play call, and both address shapes (progressive mp4, DASH
// picture) come back as a VodPlayInfo — with the source's failures as
// VodFailure.
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_vod/live_vod.dart';
import 'package:test/test.dart';

void main() {
  test('a search hit loses its highlight markup and gains a scheme', () async {
    final http = _FakeHttp({
      '/x/web-interface/search/type': {
        'code': 0,
        'data': {
          'numResults': 42,
          'result': [
            {
              'bvid': 'BV1xx411c7mD',
              'aid': 1234,
              'title': '【<em class="keyword">王者</em>荣耀】教学',
              'pic': '//i0.hdslb.com/bfs/archive/a.jpg',
              'author': '主播',
              'duration': '1:02:03',
              'play': 99,
            },
          ],
        },
      },
    });

    final page = await BilibiliVodClient(http).search('王者');

    expect(page.hasMore, isTrue);
    final video = page.videos.single;
    expect(video.id, 'BV1xx411c7mD');
    expect(video.title, '【王者荣耀】教学');
    expect(video.coverUrl, 'https://i0.hdslb.com/bfs/archive/a.jpg');
    expect(video.duration, const Duration(hours: 1, minutes: 2, seconds: 3));
    expect(video.playCount, 99);
  });

  test('a progressive answer plays as mp4', () async {
    final http = _FakeHttp({
      '/x/player/pagelist': {
        'code': 0,
        'data': [
          {'cid': 888, 'page': 1, 'part': 'p1'},
        ],
      },
      '/x/player/playurl': {
        'code': 0,
        'data': {
          'quality': 64,
          'durl': [
            {'url': 'https://cdn/video.mp4'},
          ],
        },
      },
    });

    final info = await BilibiliVodClient(http).play(const VodVideo(id: 'BV1', title: 't'));

    expect(info.url, 'https://cdn/video.mp4');
    expect(info.format, 'mp4');
    expect(http.asked.last.queryParameters['cid'], '888');
  });

  test('a DASH-only answer returns its picture and says it is silent', () async {
    final http = _FakeHttp({
      '/x/player/pagelist': {
        'code': 0,
        'data': [
          {'cid': 7},
        ],
      },
      '/x/player/playurl': {
        'code': 0,
        'data': {
          'dash': {
            'video': [
              {'baseUrl': 'https://cdn/video.m4s'},
            ],
          },
        },
      },
    });

    final info = await BilibiliVodClient(http).play(const VodVideo(id: 'BV1', title: 't'));

    expect(info.url, 'https://cdn/video.m4s');
    expect(info.format, 'm4s');
    expect(info.silent, isTrue);
  });

  test('a DASH pair keeps its ladder and its audio, and asks fnval 4048', () async {
    final http = _FakeHttp({
      '/x/player/pagelist': {
        'code': 0,
        'data': [
          {'cid': 7},
        ],
      },
      '/x/player/playurl': {
        'code': 0,
        'data': {
          'quality': 80,
          'accept_quality': [80, 64],
          'support_formats': [
            {'quality': 80, 'new_description': '1080P 高清'},
            {'quality': 64, 'new_description': '720P 准高清'},
          ],
          'dash': {
            'video': [
              {'id': 64, 'baseUrl': 'https://cdn/64-avc.m4s', 'codecid': 7, 'codecs': 'avc1.640020', 'bandwidth': 900000},
              {'id': 80, 'baseUrl': 'https://cdn/80-avc.m4s', 'codecid': 7, 'codecs': 'avc1.640032', 'bandwidth': 1800000},
              {'id': 80, 'baseUrl': 'https://cdn/80-hevc.m4s', 'codecid': 12, 'codecs': 'hev1.1.6.L120', 'bandwidth': 1500000},
            ],
            'audio': [
              {'id': 30216, 'baseUrl': 'https://cdn/audio-low.m4s', 'bandwidth': 64000},
              {'id': 30280, 'baseUrl': 'https://cdn/audio-high.m4s', 'bandwidth': 192000},
            ],
            'flac': {'display': false},
            'dolby': {'type': 0, 'audio': null},
          },
        },
      },
    });

    final info = await BilibiliVodClient(http).play(const VodVideo(id: 'BV1', title: 't'));

    expect(http.asked.last.queryParameters['fnval'], '4048');
    expect(info.hasDash, isTrue);
    expect(info.silent, isFalse);
    // Best definition first, then bandwidth within it.
    expect(info.videos.first.quality, 80);
    expect(info.videos.first.codecId, 7);
    expect(info.videos.first.url, 'https://cdn/80-avc.m4s');
    expect(info.bestAudio?.id, 30280);
    expect(info.bestAudio?.url, 'https://cdn/audio-high.m4s');
  });

  test('the muxed fallback asks fnval 1', () async {
    final http = _FakeHttp({
      '/x/player/pagelist': {
        'code': 0,
        'data': [
          {'cid': 7},
        ],
      },
      '/x/player/playurl': {
        'code': 0,
        'data': {
          'quality': 64,
          'durl': [
            {'url': 'https://cdn/muxed.mp4'},
          ],
        },
      },
    });

    final info = await BilibiliVodClient(http).playPart(bvid: 'BV1', cid: 7, dash: false);

    expect(http.asked.last.queryParameters['fnval'], '1');
    expect(info.url, 'https://cdn/muxed.mp4');
  });

  test('the play ask names the whole ladder, not what will be watched', () async {
    final http = _FakeHttp({
      '/x/player/playurl': {
        'code': 0,
        'data': {
          'quality': 112,
          'dash': {
            'video': [
              {'id': 112, 'baseUrl': 'https://cdn/112.m4s', 'codecs': 'avc1.640032'},
              {'id': 80, 'baseUrl': 'https://cdn/80.m4s', 'codecs': 'avc1.640032'},
            ],
            'audio': [
              {'id': 30280, 'baseUrl': 'https://cdn/audio.m4s'},
            ],
          },
        },
      },
    });

    // Asking for the viewer's own tier would hide every higher definition
    // from the answer, and from the menu that reads the answer.
    final info = await BilibiliVodClient(http).playPart(bvid: 'BV1', cid: 7);

    expect(http.asked.last.queryParameters['qn'], '127');
    expect(http.asked.last.queryParameters['fourk'], '1');
    expect(info.servedQuality, 112);
    expect(info.videos.map((video) => video.quality), [112, 80]);
  });

  test("the play ask keeps the sign-in and leaves the device's fingerprints", () async {
    final http = _FakeHttp({
      '/x/player/playurl': {
        'code': 0,
        'data': {
          'quality': 80,
          'durl': [
            {'url': 'https://cdn/muxed.mp4'},
          ],
        },
      },
    });

    await BilibiliVodClient(http, cookie: 'buvid3=finger; SESSDATA=abc; DedeUserID=42; b_nut=1')
        .playPart(bvid: 'BV1', cid: 7);

    final sent = http.askedHeaders.last['cookie'] ?? '';
    expect(sent, contains('SESSDATA=abc'));
    expect(sent, contains('DedeUserID=42'));
    expect(sent, isNot(contains('buvid3')));
    expect(sent, isNot(contains('b_nut')));
  });

  test('a play answer that asks to prove itself is a risk-control failure', () async {
    final http = _FakeHttp({
      '/x/player/playurl': {
        'code': 0,
        'data': {'v_voucher': 'voucher_123'},
      },
    });

    await expectLater(
      BilibiliVodClient(http).playPart(bvid: 'BV1', cid: 7),
      throwsA(isA<VodFailure>().having((failure) => failure.message, 'message', contains('prove itself'))),
    );
  });

  test('a source failure is a VodFailure with its message', () async {
    final http = _FakeHttp({
      '/x/web-interface/search/type': {'code': -412, 'message': 'request blocked'},
    });

    expect(
      () => BilibiliVodClient(http).search('x'),
      throwsA(isA<VodFailure>().having((failure) => failure.message, 'message', 'request blocked')),
    );
  });

  test('the typed searches read their own shapes', () async {
    final http = _FakeHttp({
      '/x/web-interface/search/type': {
        'code': 0,
        'data': {
          'numPages': 3,
          'numResults': 41,
          'result': [
            {
              'season_id': 4242,
              'title': '某<em class="keyword">番</em>剧',
              'cover': '//i0.hdslb.com/season.jpg',
              'season_type_name': '番剧',
              'media_score': {'score': 9.1},
              'desc': '简介',
            },
            {'mid': 42, 'uname': '某UP', 'upic': '//i0.hdslb.com/face.jpg', 'usign': '签名', 'fans': 100, 'videos': 5},
            {'roomid': 9001, 'title': '某直播', 'cover': '//i0.hdslb.com/live.jpg', 'uname': '主播', 'online': 2000},
          ],
        },
      },
    });
    final client = BilibiliVodClient(http);

    final media = await client.searchMedia('x', bangumi: true);
    expect(http.asked.last.queryParameters['search_type'], 'media_bangumi');
    expect(media.hasMore, isTrue);
    final season = media.seasons.single;
    expect(season.seasonId, 4242);
    expect(season.title, '某番剧');
    expect(season.rating, '9.1');
    expect(season.subtitle, '番剧');

    final users = await client.searchUsers('x');
    expect(http.asked.last.queryParameters['search_type'], 'bili_user');
    expect(users.users.single.mid, 42);
    expect(users.users.single.name, '某UP');
    expect(users.users.single.fans, 100);

    final rooms = await client.searchLiveRooms('x');
    expect(http.asked.last.queryParameters['search_type'], 'live_room');
    expect(rooms.rooms.single.roomId, 9001);
    expect(rooms.rooms.single.online, 2000);
  });

  test('the recommendation feed is signed with the nav answer keys', () async {
    final http = _FakeHttp({
      '/x/web-interface/nav': {
        'code': -101,
        'data': {
          'isLogin': false,
          'wbi_img': {
            'img_url': 'https://i0.hdslb.com/bfs/wbi/7cd084941338484aae1ad9425b84077c.png',
            'sub_url': 'https://i0.hdslb.com/bfs/wbi/4932caff0ff746eab6f01bf08b70ac45.png',
          },
        },
      },
      '/x/web-interface/wbi/index/top/feed/rcmd': {
        'code': 0,
        'data': {
          'item': [
            {
              'bvid': 'BV1rcmd',
              'title': '推荐视频',
              'pic': '//i0.hdslb.com/rcmd.jpg',
              'owner': {'name': 'up'},
              'stat': {'view': 10},
              'duration': 300,
            },
          ],
        },
      },
    });

    final page = await BilibiliVodClient(http).recommend(page: 2);

    final rcmd = http.asked.firstWhere((uri) => uri.path == '/x/web-interface/wbi/index/top/feed/rcmd');
    expect(rcmd.queryParameters['w_rid'], isNotEmpty);
    expect(rcmd.queryParameters['wts'], isNotEmpty);
    expect(rcmd.queryParameters['fresh_idx'], '2');
    expect(page.page, 2);
    expect(page.videos.single.title, '推荐视频');
    expect(page.videos.single.duration, const Duration(minutes: 5));
  });

  test('a dynamics page reads its posts and its cursor', () async {
    final http = _FakeHttp({
      '/x/polymer/web-dynamic/v1/feed/all': {
        'code': 0,
        'data': {
          'has_more': true,
          'offset': 'next-cursor',
          'items': [
            {
              'id_str': '9001',
              'modules': {
                'module_author': {'name': '阿婆主', 'face': '//i0.hdslb.com/face.jpg', 'pub_ts': 1700000000},
                'module_dynamic': {
                  'desc': {'text': '今天的视频'},
                  'major': {
                    'archive': {'bvid': 'BV1dyn', 'cover': '//i0.hdslb.com/cover.jpg'},
                  },
                },
              },
            },
          ],
        },
      },
    });

    final page = await BilibiliVodClient(http).dynamics();

    expect(page.hasMore, isTrue);
    expect(page.offset, 'next-cursor');
    final post = page.items.single;
    expect(post.author, '阿婆主');
    expect(post.text, '今天的视频');
    expect(post.bvid, 'BV1dyn');
    expect(post.coverUrl, 'https://i0.hdslb.com/cover.jpg');
    expect(post.publishedAt, DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
  });

  test('a comment page reads replies and its total', () async {
    final http = _FakeHttp({
      '/x/v2/reply': {
        'code': 0,
        'data': {
          'page': {'count': 45},
          'replies': [
            {
              'rpid': 11,
              'like': 7,
              'rcount': 2,
              'ctime': 1700000000,
              'member': {'uname': '某观众', 'avatar': '//i0.hdslb.com/a.jpg'},
              'content': {'message': '好看'},
            },
          ],
        },
      },
    });

    final page = await BilibiliVodClient(http).comments(123, page: 2);

    expect(page.total, 45);
    expect(page.hasMore, isTrue);
    final comment = page.comments.single;
    expect(comment.author, '某观众');
    expect(comment.message, '好看');
    expect(comment.likeCount, 7);
    expect(comment.avatar, 'https://i0.hdslb.com/a.jpg');
  });

  test('a PGC feed flattens sub-items and carries its cursor', () async {
    final http = _FakeHttp({
      '/pgc/page/web/v3/feed': {
        'code': 0,
        'data': {
          'has_next': true,
          'coursor': 12,
          'items': [
            {
              'sub_items': [
                {
                  'season_id': 4242,
                  'title': '某番剧',
                  'cover': '//i0.hdslb.com/season.jpg',
                  'new_ep': {'index_show': '更新至第 3 话'},
                  'rating': {'score': 9.1},
                  'stat': {'views': 5000},
                  'follow_status': 2,
                },
              ],
            },
          ],
        },
      },
    });

    final page = await BilibiliVodClient(http).pgcFeed(type: 1, cursor: 4);

    expect(http.asked.single.queryParameters['coursor'], '4');
    expect(page.cursor, 12);
    expect(page.hasMore, isTrue);
    final season = page.seasons.single;
    expect(season.seasonId, 4242);
    expect(season.subtitle, '更新至第 3 话');
    expect(season.rating, '9.1');
    expect(season.followed, isTrue);
  });

  test('a season page reads its episodes and follow flag', () async {
    final http = _FakeHttp({
      '/pgc/view/web/season': {
        'code': 0,
        'data': {
          'season_id': 4242,
          'title': '某番剧',
          'cover': '//i0.hdslb.com/season.jpg',
          'evaluate': '简介',
          'rating': {'score': 9.0, 'count': 420},
          'stat': {'views': 5000, 'danmakus': 88},
          'areas': [
            {'id': 2, 'name': '日本'},
          ],
          'styles': ['漫画改', '推理', ''],
          'new_ep': {'desc': '每周六19:30更新'},
          'seasons': [
            {
              'season_id': 111,
              'new_ep': {'index_show': '全1话'},
            },
            {
              'season_id': 4242,
              'new_ep': {'index_show': '更新至第1278话'},
            },
          ],
          'publish': {'pub_time': '2024-01-05'},
          'user_status': {'follow': 1},
          'episodes': [
            {
              'id': 7001,
              'cid': 9001,
              'aid': 8001,
              'title': '2',
              'long_title': '第二话',
              'duration': 1440000,
              'cover': '//i0.hdslb.com/ep.jpg',
            },
          ],
        },
      },
    });

    final detail = await BilibiliVodClient(http).seasonDetail(seasonId: 4242);

    expect(detail.title, '某番剧');
    expect(detail.followed, isTrue);
    expect(detail.publishedAt, DateTime(2024, 1, 5));
    // The state comes from the sibling entry this season has in `seasons`,
    // not from the answer's own `new_ep`, which names the schedule instead.
    expect(detail.subtitle, '更新至第1278话');
    expect(detail.rating, '9');
    expect(detail.viewCount, 5000);
    expect(detail.danmakuCount, 88);
    expect(detail.area, '日本');
    expect(detail.styles, ['漫画改', '推理']);
    final episode = detail.episodes.single;
    expect(episode.id, 7001);
    expect(episode.cid, 9001);
    expect(episode.aid, 8001);
    expect(episode.index, '2');
    expect(episode.title, '第二话');
    expect(episode.duration, const Duration(minutes: 24));
  });

  test('a season page without a sibling entry falls back to its own new_ep', () async {
    final http = _FakeHttp({
      '/pgc/view/web/season': {
        'code': 0,
        'data': {
          'season_id': 44658,
          'title': '某电影',
          'rating': {'score': 0, 'count': 0},
          'new_ep': {'desc': '2023年03月31日上映'},
          'episodes': [
            {'id': 7002, 'title': '原版'},
          ],
        },
      },
    });

    final detail = await BilibiliVodClient(http).seasonDetail(seasonId: 44658);

    expect(detail.subtitle, '2023年03月31日上映');
    // A zero score is the source saying nothing rated it, not a rating.
    expect(detail.rating, isEmpty);
    expect(detail.viewCount, isNull);
    expect(detail.area, isEmpty);
    expect(detail.styles, isEmpty);
  });

  test('a PGC play answer resolves the progressive address', () async {
    final http = _FakeHttp({
      '/x/web-interface/nav': {
        'code': -101,
        'data': {
          'wbi_img': {
            'img_url': 'https://i0.hdslb.com/bfs/wbi/7cd084941338484aae1ad9425b84077c.png',
            'sub_url': 'https://i0.hdslb.com/bfs/wbi/4932caff0ff746eab6f01bf08b70ac45.png',
          },
        },
      },
      '/pgc/player/web/playurl': {
        'code': 0,
        'result': {
          'quality': 80,
          'accept_quality': [80, 64],
          'accept_description': ['1080P', '720P'],
          'durl': [
            {'url': 'https://cdn/episode.mp4'},
          ],
        },
      },
    });

    final info = await BilibiliVodClient(http).pgcPlay(episodeId: 7001, cid: 9001, aid: 8001);

    final asked = http.asked.firstWhere((uri) => uri.path == '/pgc/player/web/playurl');
    expect(asked.queryParameters['ep_id'], '7001');
    expect(asked.queryParameters['cid'], '9001');
    expect(asked.queryParameters['avid'], '8001');
    expect(asked.queryParameters['w_rid'], isNotEmpty);
    expect(info.url, 'https://cdn/episode.mp4');
    expect(info.quality, '1080P');
    expect(info.qualities, hasLength(2));
  });

  test('the audio ladder comes back best first', () async {
    final http = _FakeHttp({
      '/x/player/pagelist': {
        'code': 0,
        'data': [
          {'cid': 7},
        ],
      },
      '/x/player/playurl': {
        'code': 0,
        'data': {
          'dash': {
            'audio': [
              {'id': 30232, 'baseUrl': 'https://cdn/128.m4s', 'bandwidth': 132000},
              {'id': 30280, 'baseUrl': 'https://cdn/192.m4s', 'bandwidth': 192000},
            ],
            'flac': {
              'audio': {'id': 30251, 'baseUrl': 'https://cdn/flac.m4s', 'bandwidth': 999000, 'codecs': 'fLaC'},
            },
          },
        },
      },
    });

    final streams = await BilibiliVodClient(http).audioStreams(const VodVideo(id: 'BV1', title: 't'));

    expect([for (final stream in streams) stream.id], [30251, 30280, 30232]);
    expect(streams.first.url, 'https://cdn/flac.m4s');
  });

  test("a part's danmaku comes back as the platform's XML", () async {
    final http = _FakeHttp({
      '/x/v1/dm/list.so': '<?xml version="1.0" encoding="UTF-8"?><i><d p="1.500,1,25,16777215,0,0,0,0">first</d></i>',
    });

    final xml = await BilibiliVodClient(http).danmakuXml(618056187);

    expect(xml, contains('<d p="1.500,1,25,16777215,0,0,0,0">first</d>'));
    expect(http.asked.single.queryParameters['oid'], '618056187');
  });

  test('a danmaku ask that failed is a VodFailure', () async {
    final http = _FakeHttp({});

    await expectLater(BilibiliVodClient(http).danmakuXml(1), throwsA(isA<VodFailure>()));
  });

  test('the player answer carries its segments, its tracks and its filmstrip', () async {
    final http = _FakeHttp({
      '/x/web-interface/nav': _nav,
      '/x/player/wbi/v2': {
        'code': 0,
        'data': {
          'need_login_subtitle': true,
          'view_points': [
            {'type': 1, 'from': 729, 'content': '开始', 'imgUrl': '//i0.hdslb.com/bfs/vchapter/a.jpg'},
            {'type': 2, 'from': 947, 'content': '第一滴血'},
            {'type': 3, 'from': 0, 'content': ''},
          ],
          'subtitle': {
            'subtitles': [
              {
                'id': 1,
                'lan': 'ai-zh',
                'lan_doc': '中文（自动生成）',
                'subtitle_url': '//subs.bilibili.com/subtitles/1.json',
                'ai_type': 1,
              },
              {'id': 2, 'lan': 'en', 'lan_doc': 'English'},
            ],
          },
          'video_shot': {
            'img_url_template': 'https://s1.hdslb.com/bfs/spread/T%ST.jpg@m_0,10.00,160,90,0',
            'img_width': 160,
            'img_height': 90,
            'timespan': 10000,
            'x': 10,
            'y': 10,
          },
        },
      },
    });

    final extra = await BilibiliVodClient(http).playerExtra(bvid: 'BV1xx411c7mD', cid: 888);

    expect(extra.chapters.map((chapter) => chapter.title), ['开始', '第一滴血']);
    expect(extra.chapters.first.at, const Duration(seconds: 729));
    expect(extra.chapters.first.coverUrl, 'https://i0.hdslb.com/bfs/vchapter/a.jpg');
    expect(extra.subtitles.single.language, 'ai-zh');
    expect(extra.subtitles.single.auto, isTrue);
    expect(extra.needsLoginForSubtitles, isTrue);
    expect(extra.preview?.urlAt(const Duration(seconds: 35)), contains('T30.00.jpg'));
  });

  test('a guest player answer is empty extras, not a failure', () async {
    final http = _FakeHttp({
      '/x/web-interface/nav': _nav,
      '/x/player/wbi/v2': {'code': -403, 'message': 'invalid'},
    });

    final extra = await BilibiliVodClient(http).playerExtra(bvid: 'BV1xx411c7mD', cid: 888);

    expect(extra.chapters, isEmpty);
    expect(extra.subtitles, isEmpty);
    expect(extra.preview, isNull);
  });

  test('an unrecognised filmstrip shape stays out rather than guessing a grid', () async {
    final http = _FakeHttp({
      '/x/web-interface/nav': _nav,
      '/x/player/wbi/v2': {
        'code': 0,
        'data': {
          'video_shot': {'img_url_template': 'https://s1.hdslb.com/bfs/spread/other.jpg', 'img_width': 160},
        },
      },
    });

    final extra = await BilibiliVodClient(http).playerExtra(bvid: 'BV1xx411c7mD', cid: 888);

    expect(extra.preview, isNull);
  });

  test("a subtitle track's lines come back timed", () async {
    final http = _FakeHttp({
      '/subtitles/1.json': {
        'font_size': 1.0,
        'body': [
          {'from': 0.0, 'to': 2.5, 'content': ' first '},
          {'from': 2.5, 'to': 5.0, 'content': ''},
          {'from': '5.0', 'to': '7.5', 'content': 'second'},
        ],
      },
    });

    final lines = await BilibiliVodClient(http).subtitleLines('//subs.bilibili.com/subtitles/1.json');

    expect(lines.map((line) => line.text), ['first', 'second']);
    expect(lines.first.end, const Duration(milliseconds: 2500));
    expect(lines.last.start, const Duration(seconds: 5));
  });
}

/// The nav answer a signed request signs with.
final Map<String, Object?> _nav = {
  'code': 0,
  'data': {
    'wbi_img': {
      'img_url': 'https://i0.hdslb.com/bfs/wbi/7cd084941338484aae1ad9425b84077c.png',
      'sub_url': 'https://i0.hdslb.com/bfs/wbi/4932caff0ff746eab6f01bf08b70ac45.png',
    },
  },
};

/// A transport that answers canned JSON per path — a string answer is sent
/// as its own body, for the endpoints that serve XML.
final class _FakeHttp implements LiveHttp {
  new(this.answers);

  final Map<String, Object?> answers;
  final List<Uri> asked = [];
  final List<Map<String, String>> askedHeaders = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url);
    askedHeaders.add(request.headers);
    final answer = answers[request.url.path];
    if (answer == null) {
      return LiveResponse(statusCode: 404, headers: const {}, bodyBytes: Uint8List(0));
    }
    return LiveResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      bodyBytes: Uint8List.fromList(utf8.encode(answer is String ? answer : jsonEncode(answer))),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}
