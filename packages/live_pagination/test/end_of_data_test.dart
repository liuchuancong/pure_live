import 'package:live_pagination/live_pagination.dart';
import 'package:test/test.dart';

/// Where "there is nothing after this page" is decided.
///
/// Three sources of that fact exist, and the contract says a controller must
/// consult them in this order: the loader's explicit [PageResult.hasMore], then a
/// known total, then whether the page came back full. These cases pin each one for
/// both controllers, because the failure mode is not an error — it is a "next"
/// button that keeps advancing through empty pages, and an infinite list that
/// never asks for page two.
void main() {
  group('PagedController and the end of the data', () {
    test('a loader saying hasMore: false stops next(), with no total to consult', () async {
      final requests = <PageRequest>[];
      final controller = PagedController<int>(
        loader: (request) async {
          requests.add(request);
          return PageResult<int>(
            items: List.generate(request.pageSize, (i) => (request.page - 1) * request.pageSize + i),
            // No total: hasMore is the only statement available. Page one says a
            // second page exists; page two says nothing does after it.
            hasMore: request.page == 1,
          );
        },
        pageSize: 5,
      );

      await controller.initialize();
      expect(await controller.next(), isTrue, reason: 'page 2 exists (hasMore was true on page 1)');

      // Page 2 answered hasMore:false, so a third step must refuse.
      expect(await controller.next(), isFalse, reason: 'the loader said there is nothing after page 2');
      expect(requests.map((r) => r.page), [1, 2], reason: 'no request may be issued past what the loader confirmed');
    });

    test('with no total the walk ends at an empty page, not at a short one', () async {
      final requests = <PageRequest>[];
      final controller = PagedController<int>(
        loader: (request) async {
          requests.add(request);
          // A cursor source: never states a total, never states hasMore. Page two
          // is short but real, so declaring the end there would hide nothing —
          // except that a source may legitimately return a partial page mid-walk.
          return PageResult<int>(
            items: switch (request.page) {
              1 => const [1, 2, 3, 4, 5],
              2 => const [6, 7],
              _ => const [],
            },
          );
        },
        pageSize: 5,
      );

      await controller.initialize();

      expect(await controller.next(), isTrue, reason: 'page two was not proven empty yet');
      expect(await controller.next(), isFalse, reason: 'page three came back empty: that is the end');
      expect(requests.map((r) => r.page), [1, 2, 3]);
      expect(await controller.next(), isFalse, reason: 'once ended, no further requests');
      expect(requests, hasLength(3));
    });

    test('a loader that answers an out-of-range page with content leaves the page number truthful', () async {
      final requests = <PageRequest>[];
      final controller = PagedController<int>(
        loader: (request) async {
          requests.add(request);
          // Page one says nothing about the total, so nothing can clamp the jump
          // below. Page 9 then reveals the dataset is two pages long and hands back
          // rows of its own instead of refusing.
          if (request.page == 1) {
            return PageResult<int>(items: const [1, 2, 3]);
          }
          if (request.page == 2) {
            return PageResult<int>(items: const [4, 5, 6], totalCount: 6);
          }
          return PageResult<int>(items: const [25, 26, 27], totalCount: 6);
        },
        pageSize: 3,
      );

      await controller.initialize();
      await controller.loadPage(9);

      expect(requests.map((r) => r.page), [1, 9, 2], reason: 'the newly-known last page must be re-requested');
      expect(controller.state.page, 2);
      expect(controller.state.items, [
        4,
        5,
        6,
      ], reason: 'page 2 must show page 2 rows, not the relabelled rows of page 9');
    });

    test('an empty dataset is requested as page one, never page zero', () async {
      final requests = <PageRequest>[];
      final controller = PagedController<int>(
        loader: (request) async {
          requests.add(request);
          return PageResult<int>(items: const [], totalCount: 0);
        },
      );

      await controller.initialize();

      expect(requests, hasLength(1));
      expect(requests.single.page, 1, reason: 'PageRequest is 1-based; totalPages(0,20) == 0 must not pull it to 0');
      expect(controller.state.page, 1);
    });

    test('changing the page size before the first load still asks for page one', () async {
      final requests = <PageRequest>[];
      final controller = PagedController<int>(
        loader: (request) async {
          requests.add(request);
          return PageResult<int>(items: const [1]);
        },
        pageSize: 50,
      );

      // Nothing is loaded yet, so the "keep the first visible item" anchor is
      // (0 - 1) * 50 = -50; converting that with integer division lands on page 0.
      await controller.changePageSize(30);

      expect(requests, isNotEmpty, reason: 'a size change while unloaded must still load something');
      expect(requests.first.page, 1, reason: 'the anchor must never leave the 1-based range');
      expect(controller.state.error, isNull, reason: 'a size change is not a failure');
    });

    test('the snapshot before the first load already carries the controller page size', () {
      final controller = PagedController<int>(loader: (_) async => PageResult<int>(items: const []), pageSize: 50);

      expect(
        controller.state.pageSize,
        50,
        reason: 'a view deriving "page 1 of N" pre-load must not use a different size',
      );
    });
  });

  group('InfiniteController and the first page', () {
    test('an unknown-total source with content still allows an append', () async {
      final requests = <PageRequest>[];
      final controller = InfiniteController<int>(
        loader: (request) async {
          requests.add(request);
          return PageResult<int>(items: request.page == 1 ? const [1, 2, 3, 4, 5] : const [6, 7]);
        },
        pageSize: 5,
      );

      await controller.initialize();
      expect(controller.state.hasMore, isTrue, reason: 'a full first page rules nothing out');

      final appended = await controller.loadNext();

      expect(appended, isTrue);
      expect(requests.map((r) => r.page), [1, 2]);
      expect(controller.state.items, hasLength(7));
    });
  });

  group('PageMath guards', () {
    test('an index outside the list maps to page one, never page zero', () {
      expect(
        PageMath.pageForIndex(-50, 30),
        1,
        reason: 'the guard is the only thing between a negative anchor and a negative slice offset in release',
      );
      expect(PageMath.pageForIndex(0, 30), 1);
      expect(PageMath.pageForIndex(29, 30), 1);
      expect(PageMath.pageForIndex(30, 30), 2);
    });

    test('clamping never leaves the 1-based range, whatever the total says', () {
      expect(PageMath.clampPage(1, 0), 1, reason: 'an empty dataset has no page 0');
      expect(PageMath.clampPage(-3, null), 1);
      expect(PageMath.clampPage(9, 4), 4);
    });

    test('a zero total has zero pages, and page one is then invalid', () {
      expect(PageMath.totalPages(0, 20), 0);
      expect(PageMath.isValidPage(1, 0), isFalse);
    });
  });
}
