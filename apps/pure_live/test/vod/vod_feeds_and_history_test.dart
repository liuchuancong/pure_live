import 'dart:convert' show jsonEncode, utf8;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:live_storage/live_storage.dart';
import 'package:live_vod/live_vod.dart' show BilibiliVodClient;
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/modules/vod/controller/vod_controller.dart';

/// The video station's browse feeds and search history, argued over a stub
/// transport: a feed loads its first page once, a repeated video never
/// lands twice, two pages in a row without a fresh hit end the walk even
/// when the source claims more, a region's empty answer is its end, and a
/// failed page is the feed's own error. The history keeps the newest first
/// with a repeat read case-insensitively and a cap of twenty.
void main() {
  group('the pure names', () {
    test('a feed key names its channel, and only the video tab filters', () {
      expect(vodFeedKey(VodFeedKind.recommend), 'recommend');
      expect(vodFeedKey(VodFeedKind.popular), 'popular');
      expect(vodFeedKey(VodFeedKind.region, id: 1005), 'region:1005');
      expect(VodSearchKind.video.filterable, isTrue);
      expect(VodSearchKind.bangumi.filterable, isFalse);
      expect(VodSearchKind.cinema.filterable, isFalse);
      expect(VodSearchKind.user.filterable, isFalse);
    });
  });

  group('the search history', () {
    late StorageStores stores;

    setUp(() async {
      stores = await StorageStores.openInMemory();
      await StoragePrefs.init();
    });

    tearDown(() => stores.close());

    test('a repeat rides to the front, read case-insensitively', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(vodSearchHistoryProvider.notifier);

      await notifier.record('  晴天  ');
      await notifier.record('夜曲');
      await notifier.record('QING TIAN'); // a different case of a stored word? no — a different word
      await notifier.record('晴天'); // the stored word again: one search said twice
      expect(container.read(vodSearchHistoryProvider), ['晴天', 'QING TIAN', '夜曲']);

      await notifier.record('');
      await notifier.record('   ');
      expect(container.read(vodSearchHistoryProvider).first, '晴天'); // a blank is not a search
    });

    test('the list holds twenty, the oldest leaving first, and forgets on demand', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(vodSearchHistoryProvider.notifier);

      for (var i = 0; i < 25; i++) {
        await notifier.record('word$i');
      }
      final held = container.read(vodSearchHistoryProvider);
      expect(held, hasLength(20)); // the cap holds
      expect(held.first, 'word24');
      expect(held.last, 'word5'); // word0..4 left

      await notifier.remove('word24');
      expect(container.read(vodSearchHistoryProvider).contains('word24'), isFalse);

      await notifier.clear();
      expect(container.read(vodSearchHistoryProvider), isEmpty);

      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      expect(fresh.read(vodSearchHistoryProvider), isEmpty); // the clear reached the store
    });

    test('a stored list unreadable reads as none', () async {
      await StoragePrefs.setString(kVodSearchHistoryKey, 'not-json');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(vodSearchHistoryProvider), isEmpty);
    });
  });

  group('the browse feeds', () {
    late _StubHttp http;

    setUp(() {
      http = _StubHttp();
    });

    Map<String, Object?> videoRow(String bvid, String title) => {
      'bvid': bvid,
      'title': title,
      'author': 'UP主',
      'duration': 210,
      'stat': {'view': 100, 'danmaku': 7},
    };

    ProviderContainer containerWith() {
      final client = BilibiliVodClient(http, cookie: 'SESSDATA=abc', log: appLog.forCategory('vod.api'));
      final container = ProviderContainer(overrides: [vodClientProvider.overrideWithValue(client)])
        ..listen(vodFeedProvider, (_, _) {});
      addTearDown(container.dispose);
      return container;
    }

    test('a feed loads once, a repeat never lands twice, and a stale walk ends', () async {
      http.route('popular', (url) async {
        final page = url.queryParameters['pn'] ?? '1';
        return _ok(
          jsonEncode({
            'code': 0,
            'data': {
              'list': [videoRow('BV1', '第一条'), if (page != '1') videoRow('BV1', '第一条重复')],
              'no_more': false,
            },
          }),
        );
      });
      final container = containerWith();
      final notifier = container.read(vodFeedProvider.notifier);

      await notifier.open('popular');
      expect(container.read(vodFeedProvider.notifier).feedOf('popular').videos.map((video) => video.id), ['BV1']);
      expect(container.read(vodFeedProvider.notifier).feedOf('popular').hasMore, isTrue);

      await notifier.open('popular'); // already held: nothing flies again
      expect(http.calls, hasLength(1));

      await notifier.loadMore('popular'); // the twin drops, but the page brought nothing new
      expect(container.read(vodFeedProvider.notifier).feedOf('popular').videos, hasLength(1));
      expect(container.read(vodFeedProvider.notifier).feedOf('popular').hasMore, isTrue); // one stale page is a shrug

      await notifier.loadMore('popular'); // stale again: the walk ends
      expect(container.read(vodFeedProvider.notifier).feedOf('popular').hasMore, isFalse);

      final before = http.calls.length;
      await notifier.loadMore('popular'); // no more to ask for
      expect(http.calls.length, before);
    });

    test('a region feed reads its channel id, and an empty answer is its end', () async {
      http
        ..route(
          'region/feed/rcmd',
          _jsonFuture({
            'code': 0,
            'data': {
              'archives': [videoRow('BV9', '区视频')],
            },
          }),
        )
        ..route(
          'popular',
          _jsonFuture({
            'code': 0,
            'data': {'list': <Object?>[]},
          }),
        );
      final container = containerWith();
      final notifier = container.read(vodFeedProvider.notifier);

      await notifier.open('region:1005');
      final feed = container.read(vodFeedProvider.notifier).feedOf('region:1005');
      expect(feed.videos.single.id, 'BV9');
      expect(feed.videos.single.title, '区视频');
      expect(feed.hasMore, isTrue); // the feed carries no end flag; a row said continue
      expect(http.calls.last.path.contains('region/feed/rcmd'), isTrue);

      // An empty answer is the end, however the flagless feed left it.
      http.route(
        'region/feed/rcmd',
        _jsonFuture({
          'code': 0,
          'data': {'archives': <Object?>[]},
        }),
      );
      await notifier.refresh('region:1005');
      final empty = container.read(vodFeedProvider.notifier).feedOf('region:1005');
      expect(empty.videos, isEmpty); // a refresh replaces the list with the new page
      expect(empty.hasMore, isFalse); // and the feed's empty answer is its end
    });

    test("a failed page lands as the feed's own error, with more refused", () async {
      http.route('popular', (url) async => throw StateError('the site is down'));
      final container = containerWith();
      final notifier = container.read(vodFeedProvider.notifier);

      await notifier.open('popular');
      final feed = container.read(vodFeedProvider.notifier).feedOf('popular');
      expect(feed.loading, isFalse);
      expect(feed.hasMore, isFalse);
      expect(feed.error, isNotNull);
    });

    test('a blank search clears the page without asking the platform', () async {
      final container = containerWith();
      final notifier = container.read(vodProvider.notifier);
      container.listen(vodProvider, (_, _) {});

      await notifier.search('  ');
      final state = container.read(vodProvider);
      expect(state.query, isEmpty);
      expect(state.videos, isEmpty);
      expect(state.loading, isFalse);
      expect(http.calls, isEmpty); // nothing to ask for
    });
  });
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
