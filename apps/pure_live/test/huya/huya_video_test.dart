import 'dart:async' show unawaited;
import 'dart:convert' show jsonEncode, utf8;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveResponse;
import 'package:live_storage/live_storage.dart';
import 'package:live_vod/live_vod.dart' show HuyaArchiveApi, HuyaChannel, HuyaChannelGroup, HuyaVideoApi;
import 'package:pure_live/modules/huya/controller/huya_video.dart';

import 'stub_http.dart' show StubHttp;

/// The huya video station's controllers, argued over a stub transport: a
/// board switch that lands while the old board's page is still in flight
/// must load the board it landed on (and the stale answer may not leave
/// the wall's flag on), a replay page whose first read failed must answer
/// the tab's retry ask again, and the search history and the information
/// column keep their words.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  group('the ranking surface', () {
    test('a switch while a board page is in flight still loads the board it landed on', () async {
      final http = StubHttp()
        ..route('rank/all.html', (url) async {
          return _ok(
            _ssr({
              'channelItemList': [
                {'id': '2168', 'name': '英雄'},
                {'id': '1', 'name': '一起看'},
              ],
            }),
          );
        })
        ..route('rank/1.html', (url) async {
          return _ok(
            _ssr({
              'rankData': {'list': <Object?>[], 'total': 0},
            }),
          );
        });
      final firstBoard = http.hold('rank/2168.html');

      final container = ProviderContainer(overrides: [huyaVideoApiProvider.overrideWith((ref) => HuyaVideoApi(http))]);
      addTearDown(container.dispose);
      container.listen(huyaRankProvider, (_, _) {});
      final controller = container.read(huyaRankProvider.notifier);

      unawaited(controller.open());
      await pumpEventQueue();
      var state = container.read(huyaRankProvider);
      expect(state.boardId, '2168'); // the boards named their first
      expect(state.loading, isTrue); // its page is the one in flight

      await controller.select('1');
      await pumpEventQueue();

      // The landed board asked its own page, and the answer settled the
      // loading flag for the board now on screen.
      expect(http.calls.where((uri) => uri.path.contains('rank/1.html')), isNotEmpty);
      state = container.read(huyaRankProvider);
      expect(state.boardId, '1');
      expect(state.loading, isFalse);

      firstBoard.complete(); // the stale page answers at last
      await pumpEventQueue();
      state = container.read(huyaRankProvider);
      expect(state.boardId, '1'); // it landed nowhere
      expect(state.loading, isFalse);
    });

    test('a board page that failed keeps the failure, and refresh asks again', () async {
      final http = StubHttp()
        ..route('rank/all.html', (url) async {
          return _ok(
            _ssr({
              'channelItemList': [
                {'id': '2168', 'name': '英雄'},
              ],
            }),
          );
        })
        ..route('rank/2168.html', (url) async {
          return _fail();
        });
      final container = ProviderContainer(overrides: [huyaVideoApiProvider.overrideWith((ref) => HuyaVideoApi(http))]);
      addTearDown(container.dispose);
      container.listen(huyaRankProvider, (_, _) {});
      final controller = container.read(huyaRankProvider.notifier);

      await controller.open();
      var state = container.read(huyaRankProvider);
      expect(state.loading, isFalse);
      expect(state.error, isNotNull);

      await controller.refresh();
      expect(http.calls.where((uri) => uri.path.contains('rank/2168.html')), hasLength(2));
      state = container.read(huyaRankProvider);
      expect(state.loading, isFalse);
    });
  });

  group('the replay tab', () {
    test('a first page that failed answers the retry ask again', () async {
      final http = StubHttp()
        ..route('video/u/', (url) async {
          return _fail();
        });
      final container = ProviderContainer(
        overrides: [huyaArchiveApiProvider.overrideWith((ref) => HuyaArchiveApi(http))],
      );
      addTearDown(container.dispose);
      container.listen(huyaReplayProvider, (_, _) {});
      final controller = container.read(huyaReplayProvider.notifier);

      await controller.open('123456');
      var state = container.read(huyaReplayProvider);
      expect(state.error, isNotNull);
      expect(state.loaded, isTrue);
      expect(state.loading, isFalse);

      await controller.open('123456'); // the tab's retry ask
      expect(http.calls, hasLength(2)); // the ask went out again
      state = container.read(huyaReplayProvider);
      expect(state.error, isNotNull); // and the failure still shows
    });

    test('a replay page that answered is not asked again', () async {
      final http = StubHttp()
        ..route('video/u/', (url) async {
          return _ok(
            _ssr({
              'userPageLiveRecordVideoRsp': {
                'respHeader': {'code': 0},
                'videoDataList': <Object?>[],
              },
            }),
          );
        });
      final container = ProviderContainer(
        overrides: [huyaArchiveApiProvider.overrideWith((ref) => HuyaArchiveApi(http))],
      );
      addTearDown(container.dispose);
      container.listen(huyaReplayProvider, (_, _) {});
      final controller = container.read(huyaReplayProvider.notifier);

      await controller.open('123456');
      final state = container.read(huyaReplayProvider);
      expect(state.loaded, isTrue);
      expect(state.error, isNull);

      await controller.open('123456'); // the tab's re-entry
      expect(http.calls, hasLength(1)); // the answer still stands
    });
  });

  group('the search history', () {
    test('one copy of a word, newest first, twenty deep, restored from the prefs', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(huyaSearchHistoryProvider, (_, _) {});
      final controller = container.read(huyaSearchHistoryProvider.notifier);

      await controller.record('abc');
      await controller.record('XYZ');
      expect(container.read(huyaSearchHistoryProvider), ['XYZ', 'abc']); // the newest leads

      await controller.record('abc'); // a re-ask moves the word back to the top
      expect(container.read(huyaSearchHistoryProvider), ['abc', 'XYZ']);

      await controller.record('Abc '); // the top word again, spelled differently: nothing moves
      expect(container.read(huyaSearchHistoryProvider), ['abc', 'XYZ']);

      await controller.remove('XYZ');
      expect(container.read(huyaSearchHistoryProvider), ['abc']);

      for (var i = 0; i < 25; i++) {
        await controller.record('word $i');
      }
      final full = container.read(huyaSearchHistoryProvider);
      expect(full, hasLength(20)); // the station keeps twenty
      expect(full.first, 'word 24'); // the newest leads

      final restored = ProviderContainer();
      addTearDown(restored.dispose);
      restored.listen(huyaSearchHistoryProvider, (_, _) {});
      expect(restored.read(huyaSearchHistoryProvider), full); // the list survives a restart

      await controller.clear();
      expect(container.read(huyaSearchHistoryProvider), isEmpty);
      await pumpEventQueue();
      expect(StoragePrefs.getString(kHuyaSearchHistoryKey), '[]');
    });
  });

  group('the browse surface', () {
    test('the groups and the first page load, and a second page appends its new rows only', () async {
      final http = StubHttp()
        ..route(r'g/all$', (url) async {
          return _ok(_ssr(_groupsFixture()));
        })
        ..route('all_hot_0', (url) async {
          final page = int.parse(url.queryParameters['page'] ?? '1');
          return _ok(_ssr(_listPage(pageIndex: page, total: 45, ids: page == 1 ? ['11', '12'] : ['12', '13'])));
        });
      final container = ProviderContainer(overrides: [huyaVideoApiProvider.overrideWith((ref) => HuyaVideoApi(http))]);
      addTearDown(container.dispose);
      container.listen(huyaBrowseProvider, (_, _) {});
      final controller = container.read(huyaBrowseProvider.notifier);

      await controller.open();
      var state = container.read(huyaBrowseProvider);
      expect(state.groups, hasLength(2)); // the strip carries both groups
      expect(state.current.videos.map((video) => video.id), ['11', '12']);
      expect(state.current.hasMore, isTrue); // twenty read, forty-five on the shelf

      await controller.loadMore();
      state = container.read(huyaBrowseProvider);
      expect(state.current.videos.map((video) => video.id), ['11', '12', '13']); // the repeat dropped
      expect(state.current.hasMore, isTrue);
    });

    test('a listing that ignores its page stops the walk after two unchanged pages', () async {
      final http = StubHttp()
        ..route(r'g/all$', (url) async {
          return _ok(_ssr(_groupsFixture()));
        })
        ..route('all_hot_0', (url) async {
          return _ok(_ssr(_listPage(pageIndex: 1, total: 100, ids: ['11', '12'])));
        });
      final container = ProviderContainer(overrides: [huyaVideoApiProvider.overrideWith((ref) => HuyaVideoApi(http))]);
      addTearDown(container.dispose);
      container.listen(huyaBrowseProvider, (_, _) {});
      final controller = container.read(huyaBrowseProvider.notifier);

      await controller.open();
      expect(container.read(huyaBrowseProvider).current.hasMore, isTrue);

      await controller.loadMore(); // the station answered page one again
      var state = container.read(huyaBrowseProvider);
      expect(state.current.videos, hasLength(2)); // nothing new came
      expect(state.current.hasMore, isTrue); // one unchanged page is forgiven

      await controller.loadMore(); // and a second one ends the walk
      state = container.read(huyaBrowseProvider);
      expect(state.current.hasMore, isFalse);

      await controller.loadMore(); // the walk is over: nothing asks again
      expect(http.calls.where((uri) => uri.path.contains('all_hot_0')), hasLength(3));
    });

    test('each listing keeps its own walked pages, and returning to one asks nothing', () async {
      final http = StubHttp()
        ..route(r'g/all$', (url) async {
          return _ok(_ssr(_groupsFixture()));
        })
        ..route('all_hot_0', (url) async {
          return _ok(_ssr(_listPage(pageIndex: 1, total: 2, ids: ['11', '12'])));
        })
        ..route('all_hot_2', (url) async {
          return _ok(_ssr(_listPage(pageIndex: 1, total: 1, ids: ['21'])));
        })
        ..route('2168_hot_0', (url) async {
          return _ok(_ssr(_listPage(pageIndex: 1, total: 1, ids: ['31'])));
        });
      final container = ProviderContainer(overrides: [huyaVideoApiProvider.overrideWith((ref) => HuyaVideoApi(http))]);
      addTearDown(container.dispose);
      container.listen(huyaBrowseProvider, (_, _) {});
      final controller = container.read(huyaBrowseProvider.notifier);
      await controller.open(); // the whole site, ungrouped
      expect(container.read(huyaBrowseProvider).current.videos, hasLength(2));

      await controller.selectChannel(_groupOf(container, 2), const HuyaChannel(id: 'all', name: '全部'));
      expect(container.read(huyaBrowseProvider).current.videos.map((video) => video.id), ['21']);

      await controller.selectChannel(_groupOf(container, 1), const HuyaChannel(id: '2168', name: '英雄'));
      expect(container.read(huyaBrowseProvider).current.videos.map((video) => video.id), ['31']);

      await controller.selectChannel(_groupOf(container, 2), const HuyaChannel(id: 'all', name: '全部'));
      expect(container.read(huyaBrowseProvider).current.videos.map((video) => video.id), ['21']); // walked pages stand
      expect(http.calls.where((uri) => uri.path.contains('video/g/')), hasLength(4)); // groups + three pages
    });

    test('walking into a channel from a shelf lands in the group that holds it', () async {
      final http = StubHttp()
        ..route(r'g/all$', (url) async {
          return _ok(_ssr(_groupsFixture()));
        })
        ..route('all_hot_0', (url) async {
          return _ok(_ssr(_listPage(pageIndex: 1, total: 2, ids: ['11', '12'])));
        })
        ..route('135_hot_0', (url) async {
          return _ok(_ssr(_listPage(pageIndex: 1, total: 1, ids: ['41'])));
        });
      final container = ProviderContainer(overrides: [huyaVideoApiProvider.overrideWith((ref) => HuyaVideoApi(http))]);
      addTearDown(container.dispose);
      container.listen(huyaBrowseProvider, (_, _) {});
      final controller = container.read(huyaBrowseProvider.notifier);

      await controller.open();
      await controller.walkInto('135'); // the shelf's channel
      final state = container.read(huyaBrowseProvider);
      expect(state.groupId, 2); // the group that holds it leads the strip
      expect(state.channelId, '135');
      expect(state.current.videos.map((video) => video.id), ['41']);
    });
  });

  group('the home shelves', () {
    test('the home opens once, and a failed first open retries', () async {
      final failing = StubHttp()
        ..route('video/', (url) async {
          return _fail();
        });
      final container = ProviderContainer(
        overrides: [huyaVideoApiProvider.overrideWith((ref) => HuyaVideoApi(failing))],
      );
      addTearDown(container.dispose);
      container.listen(huyaVideoHomeProvider, (_, _) {});
      final controller = container.read(huyaVideoHomeProvider.notifier);

      await controller.open();
      var state = container.read(huyaVideoHomeProvider);
      expect(state.home, isNull);
      expect(state.error, isNotNull);
      expect(failing.calls, hasLength(1));

      await controller.open(); // the page's re-entry after the failure
      expect(failing.calls, hasLength(2)); // the ask went out again

      failing.route('video/', (url) async {
        return _ok(
          _ssr({
            'aggregationList': [
              {
                'recommendItem': {
                  'title': '热门推荐',
                  'setId': 1,
                  'channelItemList': [
                    {'id': '2168', 'name': '英雄'},
                  ],
                },
                'videoInfoList': [
                  {'vid': '11', 'videoTitle': '第一条'},
                ],
              },
            ],
          }),
        );
      });
      await controller.refresh();
      state = container.read(huyaVideoHomeProvider);
      expect(state.error, isNull);
      expect(state.home!.shelves, hasLength(1));
      expect(state.home!.shelves.first.videos.single.id, '11');

      await controller.open(); // the shelves stand: the re-entry asks nothing
      expect(failing.calls, hasLength(3));
    });
  });

  group('the home batch', () {
    test('exchanging walks the channel pages, wraps to the first, and a channel restarts', () async {
      final http = StubHttp()
        ..route('2168_hot_0', (url) async {
          final page = int.parse(url.queryParameters['page'] ?? '1');
          return _ok(
            _ssr(
              _listPage(
                pageIndex: page,
                total: 40,
                ids: page == 1
                    ? ['11']
                    : page == 2
                    ? ['21']
                    : const [],
              ),
            ),
          );
        })
        ..route('712_hot_0', (url) async {
          return _ok(_ssr(_listPage(pageIndex: 1, total: 40, ids: ['71'])));
        });
      final container = ProviderContainer(overrides: [huyaVideoApiProvider.overrideWith((ref) => HuyaVideoApi(http))]);
      addTearDown(container.dispose);
      container.listen(huyaBatchProvider, (_, _) {});
      final controller = container.read(huyaBatchProvider.notifier);

      await controller.exchange(channelId: '2168', setId: 0);
      expect(container.read(huyaBatchProvider).videos.single.id, '11');
      expect(container.read(huyaBatchProvider).page, 1);

      await controller.exchange(channelId: '2168', setId: 0);
      expect(container.read(huyaBatchProvider).videos.single.id, '21');
      expect(container.read(huyaBatchProvider).page, 2);

      await controller.exchange(channelId: '2168', setId: 0); // the shelf ran out: back to page one
      expect(container.read(huyaBatchProvider).videos.single.id, '11');
      expect(container.read(huyaBatchProvider).page, 1);

      await controller.exchange(channelId: '712', setId: 0); // another channel starts over
      expect(container.read(huyaBatchProvider).videos.single.id, '71');
      expect(container.read(huyaBatchProvider).page, 1);
    });
  });

  group('the information column', () {
    test('the width a drag ended on is shown, stored and restored', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(huyaVideoColumnWidthProvider, (_, _) {});
      expect(container.read(huyaVideoColumnWidthProvider), kHuyaVideoColumnDefault);

      final controller = container.read(huyaVideoColumnWidthProvider.notifier)
        ..preview(9999); // a drag past the seam's end
      expect(container.read(huyaVideoColumnWidthProvider), kHuyaVideoColumnMax);
      controller.preview(-5);
      expect(container.read(huyaVideoColumnWidthProvider), kHuyaVideoColumnMin);

      await controller.set(410);
      expect(container.read(huyaVideoColumnWidthProvider), 410);
      await pumpEventQueue();

      final restored = ProviderContainer();
      addTearDown(restored.dispose);
      restored.listen(huyaVideoColumnWidthProvider, (_, _) {});
      expect(restored.read(huyaVideoColumnWidthProvider), 410);
    });
  });
}

LiveResponse _ok(String body) => LiveResponse(statusCode: 200, headers: const {}, bodyBytes: utf8.encode(body));

LiveResponse _fail() => LiveResponse(statusCode: 500, headers: const {}, bodyBytes: utf8.encode('no'));

/// The station's page answer: the official data assignment over any markup.
String _ssr(Object json) => '<html><script>window.HNF_GLOBAL_INIT = ${jsonEncode(json)}</script></html>';

/// The station's channel strip: two groups, two channels apiece.
Map<String, Object?> _groupsFixture() => {
  'channelList': [
    {
      'title': '网游',
      'setId': 1,
      'channelItemList': [
        {'id': '2168', 'name': '英雄'},
        {'id': '712', 'name': '主机'},
      ],
    },
    {
      'title': '一起看',
      'setId': 2,
      'channelItemList': [
        {'id': '135', 'name': '电影'},
      ],
    },
  ],
};

/// One listing page: [ids] are the rows' video ids, [total] drives hasMore.
Map<String, Object?> _listPage({required int pageIndex, required int total, required List<String> ids}) => {
  'channelInfo': {'pageIndex': pageIndex},
  'videoData': {
    'respHeader': {'code': 0},
    'videoDataList': [
      for (final id in ids) {'vid': id, 'videoTitle': '视频 $id'},
    ],
    'total': total,
  },
};

/// The group on screen whose setId is [setId].
HuyaChannelGroup _groupOf(ProviderContainer container, int setId) =>
    container.read(huyaBrowseProvider).groups.firstWhere((group) => group.setId == setId);
