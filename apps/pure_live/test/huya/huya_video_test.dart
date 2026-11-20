import 'dart:async' show Completer, unawaited;
import 'dart:convert' show jsonEncode, utf8;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:live_storage/live_storage.dart';
import 'package:live_vod/live_vod.dart' show HuyaArchiveApi, HuyaVideoApi;
import 'package:pure_live/modules/huya/controller/huya_video.dart';

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
      final http = _StubHttp()
        ..route('rank/all.html', () async {
          return _ok(
            _ssr({
              'channelItemList': [
                {'id': '2168', 'name': '英雄'},
                {'id': '1', 'name': '一起看'},
              ],
            }),
          );
        })
        ..route(
          'rank/1.html',
          () async => _ok(
            _ssr({
              'rankData': {'list': <Object?>[], 'total': 0},
            }),
          ),
        );
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
      final http = _StubHttp()
        ..route('rank/all.html', () async {
          return _ok(
            _ssr({
              'channelItemList': [
                {'id': '2168', 'name': '英雄'},
              ],
            }),
          );
        })
        ..route('rank/2168.html', () async => _fail());
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
      final http = _StubHttp()..route('video/u/', () => Future<LiveResponse>.value(_fail()));
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
      final http = _StubHttp()
        ..route('video/u/', () async {
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

/// The transport the tests code against: routes by a path fragment, holds
/// the calls a gate names until it is released, and remembers every ask.
final class _StubHttp implements LiveHttp {
  final calls = <Uri>[];
  final Map<String, Future<LiveResponse> Function()> _routes = {};
  final Map<String, Completer<void>> _gates = {};

  /// Answers every call whose path carries [fragment] with [answer].
  void route(String fragment, Future<LiveResponse> Function() answer) => _routes[fragment] = answer;

  /// Holds every call whose path carries [fragment] until it is completed.
  Completer<void> hold(String fragment) => _gates.putIfAbsent(fragment, Completer<void>.new);

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    calls.add(request.url);
    for (final gate in _gates.entries) {
      if (request.url.path.contains(gate.key)) await gate.value.future;
    }
    for (final route in _routes.entries) {
      if (request.url.path.contains(route.key)) return await route.value();
    }
    throw StateError('the stub holds no answer for ${request.url.path}');
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}
