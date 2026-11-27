import 'dart:async' show Completer;
import 'dart:convert' show jsonEncode, utf8;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:live_vod/live_vod.dart' show BilibiliVodClient;
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/modules/vod/controller/vod_controller.dart';
import 'package:pure_live/modules/vod/controller/vod_pgc.dart';

/// The video station's search walk and the cinema's catalogues, argued over
/// a stub transport: a search lands its tab's rows with the highlight
/// marks stripped, a newer query wins over one still flying, a failed page
/// lands as the error and the retry asks again, and a catalogue walks its
/// cursor until the answer repeats one. The playlist import link still
/// opens.
void main() {
  late _StubHttp http;

  setUp(() {
    http = _StubHttp();
  });

  Map<String, Object?> videoRow(String bvid, String title) => {'bvid': bvid, 'title': title, 'duration': '3:30'};

  ProviderContainer containerWith() {
    final client = BilibiliVodClient(http, cookie: 'SESSDATA=abc', log: appLog.forCategory('vod.api'));
    final container = ProviderContainer(overrides: [vodClientProvider.overrideWithValue(client)])
      ..listen(vodProvider, (_, _) {})
      ..listen(vodPgcProvider, (_, _) {});
    addTearDown(container.dispose);
    return container;
  }

  group('the search walk', () {
    test('a video ask lands its rows, the highlight marks stripped', () async {
      http.route('search/type', (url) async {
        expect(url.queryParameters['search_type'], 'video');
        return _ok(
          jsonEncode({
            'code': 0,
            'data': {
              'result': [videoRow('BV1', '<em class="keyword">晴天</em> MV')],
              'numResults': 45,
            },
          }),
        );
      });
      final container = containerWith();
      final notifier = container.read(vodProvider.notifier);

      await notifier.search('晴天');
      final state = container.read(vodProvider);
      expect(state.kind, VodSearchKind.video);
      expect(state.query, '晴天');
      expect(state.videos.single.bvid, 'BV1');
      expect(state.videos.single.title, '晴天 MV'); // the mark the search wrote came off
      expect(state.nextPage, 2);
      expect(state.hasMore, isTrue); // forty-five hits, twenty shown
      expect(state.loading, isFalse);
    });

    test('a newer query wins over one still flying', () async {
      final gate = Completer<void>();
      http.route('search/type', (url) async {
        final keyword = url.queryParameters['keyword'];
        if (keyword == '晴天') {
          await gate.future;
          return _ok(
            jsonEncode({
              'code': 0,
              'data': {
                'result': [videoRow('BV_A', '旧问的答案')],
                'numResults': 1,
              },
            }),
          );
        }
        return _ok(
          jsonEncode({
            'code': 0,
            'data': {
              'result': [videoRow('BV_B', '新问的答案')],
              'numResults': 1,
            },
          }),
        );
      });
      final container = containerWith();
      final notifier = container.read(vodProvider.notifier);

      final flying = notifier.search('晴天'); // in flight, held by the gate
      await notifier.search('夜曲'); // the newer ask lands
      expect(container.read(vodProvider).query, '夜曲');

      gate.complete(); // the old answer arrives late
      await flying;
      await _settle();
      final state = container.read(vodProvider);
      expect(state.query, '夜曲'); // the newer ask still holds the page
      expect(state.videos.single.bvid, 'BV_B'); // the late answer drained
    });

    test('a failed page lands as the error, and the retry asks the first page again', () async {
      var attempts = 0;
      http.route('search/type', (url) async {
        attempts += 1;
        if (attempts == 1) throw StateError('the site is down');
        return _ok(
          jsonEncode({
            'code': 0,
            'data': {
              'result': [videoRow('BV1', '恢复了')],
              'numResults': 1,
            },
          }),
        );
      });
      final container = containerWith();
      final notifier = container.read(vodProvider.notifier);

      await notifier.search('晴天');
      final failed = container.read(vodProvider);
      expect(failed.error, isNotNull);
      expect(failed.hasMore, isFalse);
      expect(failed.loading, isFalse);

      await notifier.retry();
      final retried = container.read(vodProvider);
      expect(retried.error, isNull);
      expect(retried.videos.single.title, '恢复了');
    });

    test('a failed later page retries itself without dropping earlier rows', () async {
      var attempts = 0;
      http.route('search/type', (url) async {
        final page = int.parse(url.queryParameters['page'] ?? '1');
        if (page == 2) {
          attempts += 1;
          if (attempts == 1) throw StateError('the second page is down');
        }
        return _ok(
          jsonEncode({
            'code': 0,
            'data': {
              'result': [videoRow('BV$page', '第 $page 页')],
              'numResults': 45,
            },
          }),
        );
      });
      final container = containerWith();
      final notifier = container.read(vodProvider.notifier);

      await notifier.search('晴天');
      await notifier.loadMore();
      expect(container.read(vodProvider).videos.single.bvid, 'BV1');
      expect(container.read(vodProvider).nextPage, 2);
      expect(container.read(vodProvider).error, isNotNull);

      await notifier.retry();
      final retried = container.read(vodProvider);
      expect(retried.videos.map((video) => video.bvid), ['BV1', 'BV2']);
      expect(retried.nextPage, 3);
      expect(retried.error, isNull);
      expect(attempts, 2);
    });

    test('an account change drains the previous account response', () async {
      final gate = Completer<void>();
      http.route('search/type', (url) async {
        await gate.future;
        return _ok(
          jsonEncode({
            'code': 0,
            'data': {
              'result': [videoRow('BV_old', '旧账号')],
              'numResults': 1,
            },
          }),
        );
      });
      final container = containerWith();
      final notifier = container.read(vodProvider.notifier);
      final flying = notifier.search('晴天');
      await _settle();

      container.updateOverrides([
        vodClientProvider.overrideWithValue(
          BilibiliVodClient(http, cookie: 'SESSDATA=new', log: appLog.forCategory('vod.api')),
        ),
      ]);
      await _settle();
      expect(container.read(vodProvider).query, isEmpty);

      gate.complete();
      await flying;
      await _settle();
      expect(container.read(vodProvider).videos, isEmpty);
      expect(container.read(vodProvider).query, isEmpty);
    });

    test('a blank query clears the page', () async {
      final container = containerWith();
      final notifier = container.read(vodProvider.notifier);

      await notifier.search('晴天');
      await notifier.search('   ');
      final state = container.read(vodProvider);
      expect(state.query, isEmpty);
      expect(state.videos, isEmpty);
      expect(state.kind, VodSearchKind.video); // the tab stayed
    });
  });

  group('the media and user tabs', () {
    test('a season ask routes its type and lands the seasons', () async {
      http.route('search/type', (url) async {
        expect(url.queryParameters['search_type'], 'media_bangumi');
        return _ok(
          jsonEncode({
            'code': 0,
            'data': {
              'result': [
                {'season_id': 9001, 'title': "天気の子 <em class='keyword'>劇場版</em>"},
              ],
            },
          }),
        );
      });
      final container = containerWith();
      final notifier = container.read(vodProvider.notifier);

      await notifier.search('天気', kind: VodSearchKind.bangumi);
      final state = container.read(vodProvider);
      expect(state.kind, VodSearchKind.bangumi);
      expect(state.seasons.single.seasonId, 9001);
      expect(state.seasons.single.title, '天気の子 劇場版'); // the search's mark came off
      expect(state.videos, isEmpty); // the other tabs' lists stay empty
    });

    test('a user ask lands the members', () async {
      http.route(
        'search/type',
        _jsonFuture({
          'code': 0,
          'data': {
            'result': [
              {'mid': 31, 'uname': '周杰伦'},
            ],
          },
        }),
      );
      final container = containerWith();
      final notifier = container.read(vodProvider.notifier);

      await notifier.search('周杰', kind: VodSearchKind.user);
      final state = container.read(vodProvider);
      expect(state.users.single.mid, 31);
      expect(state.users.single.name, '周杰伦');
    });
  });

  group('the cinema catalogues', () {
    test('a catalogue opens, walks its cursor and ends where the cursor repeats', () async {
      var call = 0;
      http.route('pgc/page/web', (url) async {
        expect(url.path.contains('v3'), isTrue); // anime rides the v3 feed
        call += 1;
        if (call == 1) {
          return _ok(
            jsonEncode({
              'code': 0,
              'data': {
                'items': [
                  {'season_id': 1, 'season_title': '第一部'},
                  {'season_id': 2, 'season_title': '第二部'},
                ],
                'coursor': 12,
                'has_next': true,
              },
            }),
          );
        }
        // The next cursor equals the one already asked with: the walk ends.
        return _ok(
          jsonEncode({
            'code': 0,
            'data': {
              'items': [
                {'season_id': 1, 'season_title': '第一部'}, // the repeat drops
                {'season_id': 3, 'season_title': '第三部'},
              ],
              'coursor': 12, // the same cursor as before
              'has_next': true, // the source still claims more
            },
          }),
        );
      });
      final container = containerWith();
      final notifier = container.read(vodPgcProvider.notifier);

      await notifier.open(1); // anime
      final first = notifier.of(1);
      expect(first.seasons.map((season) => season.seasonId), [1, 2]);
      expect(first.hasMore, isTrue);
      expect(first.loaded, isTrue);

      await notifier.loadMore(1);
      final second = notifier.of(1);
      expect(second.seasons.map((season) => season.seasonId), [1, 2, 3]); // the repeat dropped
      expect(second.hasMore, isFalse); // the cursor repeated: the walk ends
      expect(second.cursor, 12);
    });

    test("a failed page lands as the catalogue's error, and a refresh starts over", () async {
      var attempts = 0;
      http.route('pgc/page/web', (url) async {
        attempts += 1;
        if (attempts == 1) throw StateError('the feed is down');
        return _ok(
          jsonEncode({
            'code': 0,
            'data': {
              'items': [
                {'season_id': 7, 'season_title': '恢复后'},
              ],
              'coursor': 3,
              'has_next': false,
            },
          }),
        );
      });
      final container = containerWith();
      final notifier = container.read(vodPgcProvider.notifier);

      await notifier.open(1);
      expect(notifier.of(1).error, isNotNull);
      expect(notifier.of(1).hasMore, isFalse);

      await notifier.refresh(1);
      final refreshed = notifier.of(1);
      expect(refreshed.error, isNull);
      expect(refreshed.seasons.single.seasonId, 7);
      expect(refreshed.hasMore, isFalse);
    });
  });
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await pumpEventQueue();
  }
}

Future<LiveResponse> Function(Uri) _jsonFuture(Object json) =>
    (url) async => _ok(jsonEncode(json));

LiveResponse _ok(String body) => LiveResponse(statusCode: 200, headers: const {}, bodyBytes: utf8.encode(body));

/// The transport the station's tests code against: routes by a path
/// fragment and remembers every ask.
final class _StubHttp implements LiveHttp {
  final calls = <Uri>[];
  final Map<String, Future<LiveResponse> Function(Uri url)> _routes = {};

  /// Answers every call whose path carries [fragment] with [answer].
  void route(String fragment, Future<LiveResponse> Function(Uri url) answer) => _routes[fragment] = answer;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    calls.add(request.url);
    for (final route in _routes.entries) {
      if (request.url.path.contains(route.key)) return await route.value(request.url);
    }
    throw StateError('the stub holds no answer for ${request.url.path}');
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}
