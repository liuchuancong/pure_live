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
    final episode = detail.episodes.single;
    expect(episode.id, 7001);
    expect(episode.cid, 9001);
    expect(episode.aid, 8001);
    expect(episode.index, '2');
    expect(episode.title, '第二话');
    expect(episode.duration, const Duration(minutes: 24));
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
}

/// A transport that answers canned JSON per path.
final class _FakeHttp implements LiveHttp {
  new(this.answers);

  final Map<String, Object?> answers;
  final List<Uri> asked = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url);
    final answer = answers[request.url.path];
    if (answer == null) {
      return LiveResponse(statusCode: 404, headers: const {}, bodyBytes: Uint8List(0));
    }
    return LiveResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      bodyBytes: Uint8List.fromList(utf8.encode(jsonEncode(answer))),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}
