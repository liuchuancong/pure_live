import 'dart:async';

import 'package:pagination_core/pagination_core.dart';
import 'package:test/test.dart';

/// Builds a server-page loader over a fixed dataset; records every
/// request for assertions.
(PageLoader<int>, List<PageRequest>) countingLoader(
  List<int> data, {
  int? reportTotalCount,
  bool Function(PageRequest)? hasMoreFor,
  List<int> failPages = const <int>[],
}) {
  final requests = <PageRequest>[];
  Future<PageResult<int>> loader(PageRequest request) async {
    requests.add(request);
    if (failPages.contains(request.page)) {
      throw StateError('page ${request.page} failed');
    }
    final start = (request.page - 1) * request.pageSize;
    final end = start + request.pageSize < data.length ? start + request.pageSize : data.length;
    final items = start < data.length ? data.sublist(start, end) : <int>[];
    return PageResult<int>(
      items: items,
      totalCount: reportTotalCount ?? data.length,
      hasMore: hasMoreFor == null ? null : hasMoreFor(request),
    );
  }

  return (loader, requests);
}

void main() {
  group('PagedController', () {
    test('first load fills page, total count and total pages', () async {
      final (loader, requests) = countingLoader(List.generate(45, (i) => i));
      final controller = PagedController<int>(loader: loader);

      await controller.initialize();

      expect(controller.state.page, 1);
      expect(controller.state.items, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]);
      expect(controller.state.totalCount, 45);
      expect(controller.state.totalPages, 3);
      expect(controller.state.isLoading, isFalse);
      expect(requests, hasLength(1));
    });

    test('next, previous and first walk the visible page', () async {
      final (loader, _) = countingLoader(List.generate(45, (i) => i));
      final controller = PagedController<int>(loader: loader);
      await controller.initialize();

      expect(await controller.next(), isTrue);
      expect(controller.state.page, 2);
      expect(controller.state.items.first, 20);

      expect(await controller.next(), isTrue);
      expect(await controller.next(), isFalse, reason: 'page 3 is the last');
      expect(controller.state.page, 3);

      expect(await controller.previous(), isTrue);
      expect(controller.state.page, 2);

      await controller.first();
      expect(controller.state.page, 1);
    });

    test('jump to an arbitrary page fetches exactly that page', () async {
      final (loader, requests) = countingLoader(List.generate(100, (i) => i));
      final controller = PagedController<int>(loader: loader);
      await controller.initialize();

      await controller.loadPage(4);

      expect(controller.state.page, 4);
      expect(controller.state.items.first, 60);
      // One request for page 1, one for page 4 — no gap filling.
      expect(requests.map((r) => r.page), [1, 4]);
    });

    test('a failed jump keeps the old page and retry refetches it', () async {
      var failPage = 3;
      Future<PageResult<int>> loader(PageRequest request) async {
        if (failPage == request.page) {
          throw StateError('boom');
        }
        return PageResult<int>(items: List.generate(20, (i) => (request.page - 1) * 20 + i), totalCount: 100);
      }

      final controller = PagedController<int>(loader: loader);
      await controller.initialize();

      await controller.loadPage(3);

      expect(controller.state.page, 1, reason: 'the old page stays visible');
      expect(controller.state.items, hasLength(20));
      expect(controller.state.error, isA<StateError>());

      failPage = 0; // stop failing
      await controller.retry();

      expect(controller.state.page, 3);
      expect(controller.state.error, isNull);
    });

    test('a shrinking dataset pulls an out-of-range jump back to the last page', () async {
      var totalCount = 100;
      Future<PageResult<int>> loader(PageRequest request) async {
        final start = (request.page - 1) * request.pageSize;
        final items = start < totalCount
            ? List.generate((totalCount - start).clamp(0, request.pageSize), (i) => start + i)
            : <int>[];
        return PageResult<int>(items: items, totalCount: totalCount);
      }

      final controller = PagedController<int>(loader: loader);
      await controller.initialize();
      await controller.loadPage(5);
      expect(controller.state.page, 5);

      totalCount = 45; // now only 3 pages
      await controller.loadPage(5);

      expect(controller.state.page, 3, reason: 'clamped to the last valid page');
      expect(controller.state.items, isNotEmpty);
    });

    test('refresh honours the policy and invalidates in-flight requests', () async {
      var gate = Completer<void>();
      final requests = <PageRequest>[];
      Future<PageResult<int>> loader(PageRequest request) async {
        requests.add(request);
        await gate.future;
        return PageResult<int>(items: List.generate(20, (i) => (request.page - 1) * 20 + i), totalCount: 100);
      }

      final controller = PagedController<int>(loader: loader);
      final init = controller.initialize();
      gate.complete();
      await init;
      await controller.loadPage(2); // current page: 2

      // A slow jump to page 3 is still in flight when the refresh starts;
      // the refresh invalidates it and re-fetches the preserved page.
      gate = Completer<void>();
      final jump = controller.loadPage(3);
      final refresh = controller.refresh();
      gate.complete();
      await Future.wait([jump, refresh]);

      expect(controller.state.page, 2, reason: 'desktop default preserves the page');
      expect(controller.state.items.first, 20);
      // Page 3 was requested but its result was dropped as stale; the
      // refresh re-requested the preserved page 2.
      expect(requests.map((r) => r.page), [1, 2, 3, 2]);
    });

    test('refreshFromStart rebuilds from page 1 regardless of policy', () async {
      final (loader, requests) = countingLoader(List.generate(100, (i) => i));
      final controller = PagedController<int>(loader: loader);
      await controller.initialize();
      await controller.loadPage(4);

      await controller.refreshFromStart();

      expect(controller.state.page, 1);
      expect(requests.last.page, 1);
    });

    test('duplicate requests while loading are ignored', () async {
      final (loader, requests) = countingLoader(List.generate(100, (i) => i));
      final controller = PagedController<int>(loader: loader);
      await controller.initialize();

      await Future.wait([controller.loadPage(2), controller.loadPage(3)]);

      expect(requests.map((r) => r.page), [1, 2], reason: 'page 3 arrived mid-flight');
    });

    test('changePageSize keeps the anchored item roughly in place', () async {
      final (loader, _) = countingLoader(List.generate(200, (i) => i));
      final controller = PagedController<int>(loader: loader);
      await controller.initialize();
      await controller.loadPage(3); // viewing items 40..59

      await controller.changePageSize(40);

      expect(controller.state.pageSize, 40);
      expect(controller.state.page, 2, reason: 'item 40 lives on page 2 of size 40');
      expect(controller.state.items.first, 40);
    });

    test('listeners receive every state transition', () async {
      final (loader, _) = countingLoader(List.generate(45, (i) => i));
      final controller = PagedController<int>(loader: loader);
      var notifications = 0;
      controller.addListener((_) => notifications++);

      await controller.initialize();

      // Loading marker + settled state.
      expect(notifications, greaterThanOrEqualTo(2));
      controller.dispose();
    });

    test('dispose stops further updates', () async {
      final (loader, _) = countingLoader(List.generate(45, (i) => i));
      final controller = PagedController<int>(loader: loader);
      await controller.initialize();
      controller.dispose();

      await controller.loadPage(2);

      expect(controller.state.page, 1);
    });
  });
}
