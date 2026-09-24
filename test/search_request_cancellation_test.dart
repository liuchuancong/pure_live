import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/interface/live_search.dart';
import 'package:pure_live/core/site/niconico/niconico_api.dart';
import 'package:pure_live/core/site/niconico/niconico_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/search/search_controller.dart' as search;

import 'niconico_directory_test.dart' as fixture;

typedef _Search = Future<List<LiveRoom>> Function(String keyword, int page);
typedef _OwnedSearch = Future<List<LiveRoom>> Function(String keyword, int page, CancelToken token);

class _Legacy extends LiveSite {
  _Legacy(this.search);
  final _Search search;
  @override
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1, int pageSize = 30}) => search(keyword, page);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Owned extends _Legacy implements LiveCancellableSearch {
  _Owned(this.owned) : super((_, _) => throw StateError('legacy path'));
  final _OwnedSearch owned;
  @override
  Future<List<LiveRoom>> searchRoomsCancellable(
    String keyword, {
    int page = 1,
    int pageSize = 30,
    CancelToken? cancel,
  }) => owned(keyword, page, cancel!);
}

Site _site(LiveSite adapter, [String id = 'niconico']) => Site(id: id, name: id, logo: '', liveSite: adapter);
LiveRoom _room(String id, [String platform = 'niconico']) =>
    LiveRoom(roomId: id, platform: platform, title: id, nick: id, liveStatus: LiveStatus.live);
search.SearchController _controller(List<Site> sites, {Duration timeout = const Duration(seconds: 12)}) {
  final c = search.SearchController(searchSites: sites, requestTimeout: timeout);
  c.searchController.text = 'old';
  addTearDown(c.onClose);
  return c;
}

Future<void> _flush() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _manyNativeIds = [
  Sites.bilibiliSite,
  Sites.douyuSite,
  Sites.huyaSite,
  Sites.douyinSite,
  Sites.ccSite,
  Sites.twitchSite,
  Sites.soopSite,
  Sites.yySite,
  Sites.acfunSite,
  Sites.picartoSite,
  Sites.twitcastingSite,
  Sites.niconicoSite,
  Sites.missevanSite,
  Sites.inkeSite,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
  });
  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
    Get.put(SettingsService());
  });
  tearDown(Get.reset);
  tearDownAll(Hive.close);

  test('pre-cancelled search allocates neither legacy nor owned request', () async {
    var calls = 0;
    final token = CancelToken()..cancel();
    for (final site in <LiveSite>[
      _Legacy((_, _) async {
        calls++;
        return [];
      }),
      _Owned((_, _, _) async {
        calls++;
        return [];
      }),
    ]) {
      await expectLater(site.searchRoomsWithCancellation('x', cancel: token), throwsA(isA<DioException>()));
    }
    expect(calls, 0);
  });

  for (final action in ['close', 'replace', 'switch']) {
    test('actual Nico search transport cancels on $action without stale results', () async {
      final started = Completer<CancelToken>();
      final api = NiconicoApi(
        request: (uri, token) async {
          if (uri.queryParameters['keyword'] != 'old') {
            return (status: 200, body: jsonEncode(fixture.envelope(search: true)));
          }
          started.complete(token);
          await token.whenCancel;
          // A successful but late transport completion is still fenced.
          return (
            status: 200,
            body: jsonEncode(fixture.envelope(search: true, rows: [fixture.row(search: true, id: 999)])),
          );
        },
      );
      final c = _controller([_site(NiconicoSite(api: api)), _site(_Legacy((_, _) async => []), 'bilibili')]);
      c.index.value = 1;
      final old = c.doSearch();
      final token = await started.future;
      if (action == 'close') {
        c.onClose();
      } else if (action == 'replace') {
        c.searchController.text = 'new';
        await c.doSearch();
      } else {
        c.selectPlatform(2);
      }
      await old.timeout(const Duration(seconds: 1));
      await _flush();
      expect(token.isCancelled, isTrue);
      expect(c.results.any((r) => r.roomId == 'lv999'), isFalse);
      if (action == 'replace') expect(c.results.single.roomId, 'lv100');
      if (action == 'switch') expect(c.results, isEmpty);
    });
  }

  test('empty draft platform switch clears old state and cancels pending request', () async {
    final started = Completer<CancelToken>();
    final c = _controller([
      _site(
        _Owned((_, _, token) async {
          started.complete(token);
          await token.whenCancel;
          return [_room('late')];
        }),
      ),
      _site(_Legacy((_, _) async => []), 'bilibili'),
    ]);
    c.index.value = 1;
    final old = c.doSearch();
    final token = await started.future;
    c.results.add(_room('already-visible'));
    c.searchController.text = '  ';
    c.selectPlatform(2);
    await old;
    expect(token.isCancelled, isTrue);
    expect(c.index.value, 2);
    expect(c.results, isEmpty);
    expect(c.searched.value, isFalse);
    expect(c.loading.value, isFalse);
    expect(c.loadingMore.value, isFalse);
    expect(c.pendingSiteCount.value, 0);
    expect(c.hasMore.value, isFalse);
    await c.loadMore();
  });

  test('fast provider renders while slow provider is pending; page boundaries and dedup survive', () async {
    final slow = Completer<List<LiveRoom>>();
    final fastCalls = <int>[];
    final slowCalls = <int>[];
    final c = _controller([
      _site(
        _Legacy((_, page) async {
          fastCalls.add(page);
          return [_room('same')];
        }),
      ),
      _site(
        _Legacy((_, page) async {
          slowCalls.add(page);
          return page == 1 ? slow.future : [];
        }),
        'bilibili',
      ),
    ]);
    final first = c.doSearch();
    await _flush();
    expect(c.results.single.roomId, 'same');
    expect(c.loading.value, isFalse);
    expect(c.pendingSiteCount.value, 1);
    await c.loadMore();
    expect(fastCalls, [1]);
    slow.complete([_room('b', 'bilibili')]);
    await first;
    expect(c.results, hasLength(2));
    expect(c.hasMore.value, isTrue);
    await c.loadMore();
    expect(fastCalls, [1, 2]);
    expect(slowCalls, [1, 2]);
    expect(c.results, hasLength(2));
    expect(c.hasMore.value, isTrue);
    await c.loadMore();
    expect(fastCalls, [1, 2, 3]);
    expect(slowCalls, [1, 2]);
    expect(c.results, hasLength(2));
    expect(c.hasMore.value, isFalse);
    expect(c.loadingMore.value, isFalse);
  });

  test('aggregate search caps active providers and refills as results arrive', () async {
    expect(_manyNativeIds.length, greaterThan(search.maxConcurrentNativeSearchSites));
    final gates = List.generate(_manyNativeIds.length, (_) => Completer<void>());
    final started = <int>[];
    final c = _controller([
      for (var i = 0; i < _manyNativeIds.length; i++)
        _site(
          _Owned((_, _, _) async {
            started.add(i);
            await gates[i].future;
            return [_room('result-$i', _manyNativeIds[i])];
          }),
          _manyNativeIds[i],
        ),
    ]);

    final run = c.doSearch();
    await _flush();
    expect(started, List.generate(search.maxConcurrentNativeSearchSites, (i) => i));
    expect(c.pendingSiteCount.value, _manyNativeIds.length);

    gates.first.complete();
    await _flush();
    expect(c.results.single.roomId, 'result-0');
    expect(started, hasLength(search.maxConcurrentNativeSearchSites + 1));

    for (var i = 1; i < gates.length; i++) {
      gates[i].complete();
    }
    await run;
    expect(started, hasLength(_manyNativeIds.length));
    expect(c.results, hasLength(_manyNativeIds.length));
    expect(c.pendingSiteCount.value, 0);
  });

  test('retiring aggregate search drains active providers without starting queued sites', () async {
    final gates = List.generate(_manyNativeIds.length, (_) => Completer<void>());
    final started = <int>[];
    final c = _controller([
      for (var i = 0; i < _manyNativeIds.length; i++)
        _site(
          _Owned((_, _, _) async {
            started.add(i);
            await gates[i].future;
            return [_room('result-$i', _manyNativeIds[i])];
          }),
          _manyNativeIds[i],
        ),
    ]);

    final run = c.doSearch();
    await _flush();
    expect(started, hasLength(search.maxConcurrentNativeSearchSites));
    c.onClose();
    for (final gate in gates) {
      gate.complete();
    }
    await run;
    expect(started, hasLength(search.maxConcurrentNativeSearchSites));
    expect(c.results, isEmpty);
  });

  test('owned deadline cancels transport and waits for provider settlement', () async {
    final cancelled = Completer<void>();
    final cleanup = Completer<void>();
    late CancelToken token;
    final c = _controller([
      _site(
        _Owned((_, _, t) async {
          token = t;
          await token.whenCancel;
          cancelled.complete();
          await cleanup.future;
          return [_room('expired')];
        }),
      ),
    ], timeout: const Duration(milliseconds: 20));
    var settled = false;
    final run = c.doSearch().whenComplete(() => settled = true);
    await cancelled.future;
    await _flush();
    expect(token.isCancelled, isTrue);
    expect(settled, isFalse);
    cleanup.complete();
    await run;
    expect(c.results, isEmpty);
    expect(c.errorMessage.value, isNotEmpty);
    expect(c.loading.value, isFalse);
  });

  test('successful provider does not cancel pending sibling; closing drains both owned operations', () async {
    final tokens = <CancelToken>[];
    final gate = Completer<void>();
    final c = _controller([
      _site(
        _Owned((_, _, t) async {
          tokens.add(t);
          return [_room('fast')];
        }),
      ),
      _site(
        _Owned((_, _, t) async {
          tokens.add(t);
          await t.whenCancel;
          await gate.future;
          return [];
        }),
        'bilibili',
      ),
    ]);
    var settled = false;
    final run = c.doSearch().whenComplete(() => settled = true);
    await _flush();
    expect(tokens, hasLength(2));
    expect(tokens[0].isCancelled, isTrue); // normal child cleanup
    expect(tokens[1].isCancelled, isFalse);
    expect(c.results.single.roomId, 'fast');
    c.onClose();
    await _flush();
    expect(tokens[1].isCancelled, isTrue);
    expect(settled, isFalse);
    gate.complete();
    await run;
  });

  for (final action in ['close', 'replace', 'timeout']) {
    test('legacy $action stops UI wait and consumes late failure', () async {
      final late = Completer<List<LiveRoom>>();
      final started = Completer<void>();
      final c = _controller([
        _site(
          _Legacy((keyword, _) async {
            if (keyword != 'old') return [_room('new')];
            started.complete();
            return late.future;
          }),
        ),
      ], timeout: action == 'timeout' ? const Duration(milliseconds: 20) : const Duration(seconds: 12));
      final old = c.doSearch();
      await started.future;
      if (action == 'close') c.onClose();
      if (action == 'replace') {
        c.searchController.text = 'new';
        await c.doSearch();
      }
      await old.timeout(const Duration(seconds: 1));
      late.completeError(StateError('late legacy transport error'));
      await _flush();
      if (action == 'replace') expect(c.results.single.roomId, 'new');
      if (action == 'timeout') expect(c.errorMessage.value, isNotEmpty);
    });
  }

  test('new keyword retires pending page two and preserves the new first page', () async {
    final pageTwo = Completer<CancelToken>();
    final c = _controller([
      _site(
        _Owned((keyword, page, token) async {
          if (page == 2) {
            pageTwo.complete(token);
            await token.whenCancel;
            return [_room('stale-page-two')];
          }
          return [_room(keyword)];
        }),
      ),
    ]);
    await c.doSearch();
    final old = c.loadMore();
    final token = await pageTwo.future;
    c.searchController.text = 'new';
    await c.doSearch();
    await old;
    expect(token.isCancelled, isTrue);
    expect(c.results.single.roomId, 'new');
    expect(c.loadingMore.value, isFalse);
  });

  test('one overlapping page does not hide a later unique search page', () async {
    final calls = <int>[];
    final c = _controller([
      _site(
        _Legacy((_, page) async {
          calls.add(page);
          return switch (page) {
            1 => [_room('one'), _room('two')],
            2 => [_room('two')],
            3 => [_room('three')],
            _ => [],
          };
        }),
      ),
    ]);
    c.index.value = 1;

    await c.doSearch();
    await c.loadMore();
    expect(calls, [1, 2]);
    expect(c.results.map((room) => room.roomId), containsAll(['one', 'two']));
    expect(c.hasMore.value, isTrue);

    await c.loadMore();
    expect(calls, [1, 2, 3]);
    expect(c.results.map((room) => room.roomId), containsAll(['one', 'two', 'three']));
    expect(c.hasMore.value, isTrue);

    await c.loadMore();
    expect(calls, [1, 2, 3, 4]);
    expect(c.hasMore.value, isFalse);
  });

  test('two consecutive stagnant pages stop a sticky pagination endpoint', () async {
    final calls = <int>[];
    final c = _controller([
      _site(
        _Legacy((_, page) async {
          calls.add(page);
          return [_room('sticky')];
        }),
      ),
    ]);
    c.index.value = 1;

    await c.doSearch();
    await c.loadMore();
    expect(c.hasMore.value, isTrue);
    await c.loadMore();
    expect(c.hasMore.value, isFalse);
    await c.loadMore();

    expect(calls, [1, 2, 3]);
    expect(c.results.single.roomId, 'sticky');
  });

  test('a replacement keyword receives a fresh stagnant-page budget', () async {
    final calls = <String>[];
    final c = _controller([
      _site(
        _Legacy((keyword, page) async {
          calls.add('$keyword:$page');
          return [_room('$keyword-result')];
        }),
      ),
    ]);
    c.index.value = 1;

    await c.doSearch();
    await c.loadMore();
    await c.loadMore();
    expect(c.hasMore.value, isFalse);

    c.searchController.text = 'new';
    await c.doSearch();
    await c.loadMore();

    expect(calls, ['old:1', 'old:2', 'old:3', 'new:1', 'new:2']);
    expect(c.hasMore.value, isTrue);
    expect(c.results.single.roomId, 'new-result');
  });

  test('duplicate initial submits share one in-flight search transaction', () async {
    var calls = 0;
    final started = Completer<CancelToken>();
    final release = Completer<void>();
    final c = _controller([
      _site(
        _Owned((_, _, token) async {
          calls++;
          if (!started.isCompleted) started.complete(token);
          await release.future;
          return [_room('shared')];
        }),
      ),
    ]);
    c.index.value = 1;

    final first = c.doSearch();
    final token = await started.future;
    final duplicate = c.doSearch();
    await _flush();

    expect(calls, 1);
    expect(token.isCancelled, isFalse);
    expect(identical(first, duplicate), isTrue);

    release.complete();
    await Future.wait([first, duplicate]);
    expect(c.results.single.roomId, 'shared');
  });

  test('duplicate submit keeps a partially rendered aggregate search alive', () async {
    var fastCalls = 0;
    var slowCalls = 0;
    final slowStarted = Completer<CancelToken>();
    final releaseSlow = Completer<void>();
    final c = _controller([
      _site(
        _Owned((_, _, _) async {
          fastCalls++;
          return [_room('fast')];
        }),
      ),
      _site(
        _Owned((_, _, token) async {
          slowCalls++;
          if (!slowStarted.isCompleted) slowStarted.complete(token);
          await releaseSlow.future;
          return [_room('slow', 'bilibili')];
        }),
        'bilibili',
      ),
    ]);

    final first = c.doSearch();
    final slowToken = await slowStarted.future;
    await _flush();
    expect(c.results.single.roomId, 'fast');
    expect(c.loading.value, isFalse);
    expect(c.pendingSiteCount.value, 1);

    final duplicate = c.doSearch();
    await _flush();
    expect(identical(first, duplicate), isTrue);
    expect(fastCalls, 1);
    expect(slowCalls, 1);
    expect(slowToken.isCancelled, isFalse);

    releaseSlow.complete();
    await Future.wait([first, duplicate]);
    expect(c.results.map((room) => room.roomId), containsAll(['fast', 'slow']));
  });

  test('same keyword starts a fresh transaction after the prior search settles', () async {
    var calls = 0;
    final c = _controller([
      _site(
        _Legacy((_, _) async {
          calls++;
          return [_room('refresh-$calls')];
        }),
      ),
    ]);
    c.index.value = 1;

    await c.doSearch();
    await c.doSearch();

    expect(calls, 2);
    expect(c.results.single.roomId, 'refresh-2');
  });

  test('closed controller actions allocate nothing and close is idempotent', () async {
    var calls = 0;
    final c = _controller([
      _site(
        _Legacy((_, _) async {
          calls++;
          return [];
        }),
      ),
    ]);
    c.onClose();
    c.onClose();
    await c.doSearch();
    await c.loadMore();
    await c.openWebSearch();
    c.selectPlatform(1);
    c.setIncludeOffline(false);
    expect(calls, 0);
    expect(c.index.value, 0);
    expect(c.includeOffline.value, isTrue);
  });
}
