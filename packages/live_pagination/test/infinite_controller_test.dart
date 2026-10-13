import 'dart:async';

import 'package:live_pagination/live_pagination.dart';
import 'package:test/test.dart';

void main() {
  group('InfiniteController', () {
    test('first refresh and appends accumulate in order', () async {
      final requests = <int>[];
      Future<PageResult<int>> loader(PageRequest request) async {
        requests.add(request.page);
        return PageResult<int>(
          items: List.generate(request.pageSize, (i) => (request.page - 1) * request.pageSize + i),
          totalCount: 100,
        );
      }

      final controller = InfiniteController<int>(loader: loader);

      await controller.initialize();
      expect(controller.state.page, 1);
      expect(controller.state.items, hasLength(20));

      await controller.loadNext();
      expect(controller.state.page, 2);
      expect(controller.state.items, hasLength(40));
      expect(controller.state.items[39], 39);
      expect(controller.state.hasMore, isTrue, reason: '5 pages in total');
      expect(requests, [1, 2]);
    });

    test('hasMore follows the explicit loader answer', () async {
      var serverHasMore = true;
      Future<PageResult<int>> loader(PageRequest request) async =>
          PageResult<int>(items: List.generate(20, (i) => i), hasMore: serverHasMore);
      final controller = InfiniteController<int>(loader: loader);

      await controller.initialize();
      await controller.loadNext();
      expect(controller.state.hasMore, isTrue);

      serverHasMore = false;
      await controller.loadNext();
      expect(controller.state.hasMore, isFalse);

      final again = await controller.loadNext();
      expect(again, isFalse, reason: 'no more pages');
    });

    test('an empty page without signals ends the list', () async {
      Future<PageResult<int>> loader(PageRequest request) async =>
          PageResult<int>(items: request.page == 1 ? List.generate(20, (i) => i) : <int>[]);
      final controller = InfiniteController<int>(loader: loader);

      await controller.initialize();
      await controller.loadNext();

      expect(controller.state.hasMore, isFalse);
    });

    test('a failed append keeps the accumulated list and retry refetches the same page', () async {
      var failPage = 3;
      Future<PageResult<int>> loader(PageRequest request) async {
        if (failPage == request.page) {
          throw StateError('append boom');
        }
        return PageResult<int>(
          items: List.generate(20, (i) => (request.page - 1) * request.pageSize + i),
          hasMore: true,
        );
      }

      final controller = InfiniteController<int>(loader: loader);
      await controller.initialize();
      await controller.loadNext();

      await controller.loadNext();
      expect(controller.state.page, 2, reason: 'page 3 never arrived');
      expect(controller.state.items, hasLength(40));
      expect(controller.state.error, isA<StateError>());

      failPage = 0;
      await controller.retry();

      expect(controller.state.page, 3, reason: 'retry resumed at page 3, not 4');
      expect(controller.state.items, hasLength(60));
      expect(controller.state.items[40], 40);
      expect(controller.state.error, isNull);
    });

    test('refresh rebuilds the list and drops a late append', () async {
      var gate = Completer<void>();
      final requests = <int>[];
      Future<PageResult<String>> loader(PageRequest request) async {
        requests.add(request.page);
        await gate.future;
        return PageResult<String>(items: List.generate(request.pageSize, (i) => '${request.page}-$i'), hasMore: true);
      }

      final controller = InfiniteController<String>(loader: loader);
      final init = controller.initialize();
      gate.complete();
      await init;

      // The append is in flight when the refresh starts; the refresh
      // invalidates its generation so the stale page never lands.
      gate = Completer<void>();
      final append = controller.loadNext();
      final refresh = controller.refresh();
      gate.complete();
      await Future.wait([append, refresh]);

      expect(controller.state.page, 1);
      expect(controller.state.items, hasLength(20), reason: 'the stale append was dropped');
      expect(controller.state.items.first, '1-0', reason: 'fresh first page, not the old list');
      expect(requests, [1, 2, 1]);
    });

    test('a failed refresh keeps the old list and retry re-runs it', () async {
      var failRefresh = true;
      Future<PageResult<int>> loader(PageRequest request) async {
        if (failRefresh) {
          throw StateError('refresh boom');
        }
        return PageResult<int>(items: List.generate(20, (i) => i));
      }

      final controller = InfiniteController<int>(loader: loader);
      await controller.initialize();
      expect(controller.state.items, isEmpty, reason: 'first refresh failed');

      failRefresh = false;
      await controller.retry();

      expect(controller.state.items, hasLength(20));
    });

    test('duplicate appends while loading are ignored', () async {
      final requests = <int>[];
      final gate = Completer<void>();
      Future<PageResult<int>> loader(PageRequest request) async {
        requests.add(request.page);
        await gate.future;
        return PageResult<int>(items: List.generate(20, (i) => i), hasMore: true);
      }

      final controller = InfiniteController<int>(loader: loader);
      final init = controller.initialize();
      gate.complete();
      await init;

      await Future.wait([controller.loadNext(), controller.loadNext(), controller.loadNext()]);

      expect(requests, [1, 2], reason: 'the second and third calls backed off');
    });

    test('dataRefresher runs before the pagination refresh', () async {
      final order = <String>[];
      Future<PageResult<int>> loader(PageRequest request) async {
        order.add('load');
        return PageResult<int>(items: List.generate(20, (i) => i));
      }

      final controller = InfiniteController<int>(loader: loader, dataRefresher: () async => order.add('data'));

      await controller.initialize();

      expect(order, ['data', 'load']);
    });

    test('batch aggregation lives in the loader, invisible to the core', () async {
      // IPTV-style source: the server only yields 20 items per call, the
      // UI shows 100 per page. The loader aggregates five batches; the
      // controller sees one ordinary logical page and stays unchanged.
      var serverCursor = 0;
      Future<PageResult<int>> loader(PageRequest request) {
        final aggregated = List.generate(request.pageSize, (i) => serverCursor + i);
        serverCursor += request.pageSize;
        return Future.value(PageResult<int>(items: aggregated));
      }

      final controller = InfiniteController<int>(loader: loader, pageSize: 100);

      await controller.initialize();

      expect(controller.state.items, hasLength(100));
      expect(controller.state.page, 1);
      expect(controller.state.items.last, 99);
    });
  });
}
