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
    expect(info.quality, 'silent');
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
