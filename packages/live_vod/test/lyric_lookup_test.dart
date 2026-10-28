// The lyric lookup, pinned against canned LRCLIB answers: a synced lyric wins
// over plain text and the closest length wins among synced ones, and a query
// with no structured hits asks once more as free text.
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_vod/live_vod.dart';
import 'package:test/test.dart';

void main() {
  test('a synced lyric beats plain text and the closest length wins', () async {
    final http = _AnsweringHttp((uri) {
      expect(uri.path, '/api/search');
      expect(uri.queryParameters['track_name'], '晴天');
      expect(uri.queryParameters['artist_name'], '周杰伦');
      return [
        {'trackName': '晴天', 'duration': 240, 'plainLyrics': '无时间标签', 'syncedLyrics': null},
        {'trackName': '晴天', 'duration': 200, 'syncedLyrics': '[00:01.00]远'},
        {'trackName': '晴天', 'duration': 269, 'syncedLyrics': '[00:01.00]近'},
      ];
    });

    final lyric = await LyricLookup(http).search(
      const LyricQuery(title: '晴天', artist: '周杰伦'),
      duration: const Duration(minutes: 4, seconds: 29),
    );

    expect(lyric?.lyric, '[00:01.00]近');
  });

  test('plain text answers when no synced lyric exists', () async {
    final http = _AnsweringHttp((uri) {
      return [
        {'plainLyrics': '第一行\n第二行', 'syncedLyrics': ''},
      ];
    });

    final lyric = await LyricLookup(http).search(const LyricQuery(title: '某歌', artist: '某人'));

    expect(lyric?.lyric, '第一行\n第二行');
  });

  test('an empty structured answer asks once more as free text', () async {
    final http = _AnsweringHttp((uri) {
      if (uri.queryParameters.containsKey('track_name')) return const [];
      return [
        {'plainLyrics': '自由查询命中', 'syncedLyrics': ''},
      ];
    });

    final lyric = await LyricLookup(http).search(const LyricQuery(title: '某歌', artist: '某人'));

    expect(lyric?.lyric, '自由查询命中');
    expect(http.asked.length, 2);
    expect(http.asked.last.queryParameters['q'], '某歌 某人');
  });

  test('a lookup failure leaves the track without a lyric', () async {
    final http = _AnsweringHttp((uri) => null);

    final lyric = await LyricLookup(http).search(const LyricQuery(title: '某歌', artist: '某人'));

    expect(lyric, isNull);
  });
}

/// A transport that answers a search with a list, or 500 when the handler
/// returns null.
final class _AnsweringHttp implements LiveHttp {
  new(this.handler);

  final List<Object?>? Function(Uri) handler;
  final List<Uri> asked = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request.url);
    final answer = handler(request.url);
    if (answer == null) {
      return LiveResponse(statusCode: 500, headers: const {}, bodyBytes: Uint8List(0));
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
