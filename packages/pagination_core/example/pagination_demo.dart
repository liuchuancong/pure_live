// A demo binary; stdout printing is the whole point.
// ignore_for_file: avoid_print
import 'dart:async';

import 'package:pagination_core/pagination_core.dart';

/// End-to-end demo of the pagination core, run with:
/// ```sh
/// dart run example/pagination_demo.dart
/// ```
///
/// Two controllers, one contract: both consume a [PageLoader] that hands
/// back ready-made logical pages. The batch-aggregating loader at the
/// bottom shows why that contract matters — the core never learns that
/// the server only serves 20 items per call.
Future<void> main() async {
  await _desktopPagedDemo();
  await _mobileInfiniteDemo();
  await _batchAggregationDemo();
  _configDemo();
}

/// Desktop numbered pagination: jump to any page, the loader answers
/// with exactly that page.
Future<void> _desktopPagedDemo() async {
  print('─── 1. PagedController (desktop) ───');
  final data = List.generate(95, (i) => 'item-${i + 1}');
  final controller =
      PagedController<String>(
        loader: (request) async {
          final start = (request.page - 1) * request.pageSize;
          final end = (start + request.pageSize).clamp(0, data.length);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return PageResult<String>(items: data.sublist(start, end), totalCount: data.length);
        },
      )..addListener((state) {
        if (state.items.isEmpty) {
          print('  loading page ${state.loadingPage} …');
          return;
        }
        print(
          '  page ${state.page}/${state.totalPages} '
          '(${state.items.first} … ${state.items.last})',
        );
      });

  await controller.initialize();
  await controller.loadPage(4);
  await controller.previous();
  await controller.refresh(); // desktop default: stay on the page
  controller.dispose();
}

/// Mobile infinite scrolling: refresh rebuilds, appends accumulate.
Future<void> _mobileInfiniteDemo() async {
  print('─── 2. InfiniteController (mobile) ───');
  final data = List.generate(57, (i) => 'item-${i + 1}');
  final controller =
      InfiniteController<String>(
        loader: (request) async {
          final start = (request.page - 1) * request.pageSize;
          final end = (start + request.pageSize).clamp(0, data.length);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return PageResult<String>(
            items: data.sublist(start, end),
            totalCount: data.length,
            hasMore: end < data.length,
          );
        },
      )..addListener((state) {
        print(
          '  ${state.items.length} items loaded (page ${state.page}, '
          'more: ${state.hasMore}, refreshing: ${state.isRefreshing})',
        );
      });

  await controller.initialize();
  await controller.loadNext();
  await controller.loadNext();
  await controller.refresh(); // rebuilds from page 1
  controller.dispose();
}

/// The IPTV case: the server serves 20 items per call, the UI wants 100
/// per page. The loader aggregates five batches; the controller sees one
/// ordinary logical page and never knows.
Future<void> _batchAggregationDemo() async {
  print('─── 3. Batch aggregation inside the loader ───');
  const serverPageSize = 20;
  var serverCursor = 0;
  var batchesServed = 0;

  Future<List<String>> fetchServerBatch() async {
    batchesServed++;
    final batch = List.generate(serverPageSize, (i) => 'raw-${serverCursor + i}');
    serverCursor += serverPageSize;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return batch;
  }

  final controller = InfiniteController<String>(
    loader: (request) async {
      // Aggregate until the logical page is full. A real loader would
      // honour the server's cursor and stop when it says so.
      final aggregated = <String>[];
      while (aggregated.length < request.pageSize) {
        aggregated.addAll(await fetchServerBatch());
      }
      return PageResult<String>(items: aggregated.take(request.pageSize));
    },
    pageSize: 100,
  );

  await controller.initialize();
  print(
    '  one logical page of ${controller.state.items.length} items '
    'assembled from $batchesServed server batches',
  );
  controller.dispose();
}

/// PaginationViewConfig: the numbers a paged UI needs, without widgets.
void _configDemo() {
  print('─── 4. PaginationViewConfig ───');
  const config = PaginationViewConfig.defaults;
  print(
    '  width 1200, not mobile  -> desktop layout: '
    '${config.isDesktopLayout(1200, isMobile: false)}',
  );
  print(
    '  offset 500              -> show back-to-top: '
    '${config.shouldShowBackToTop(500)}',
  );
  print(
    '  1200 px above bottom    -> show back-to-bottom: '
    '${config.shouldShowBackToBottom(800, 2000, atEdge: false)}',
  );
  print(
    '  jump 1600 px            -> animation: '
    '${config.jumpAnimationDuration(1600)}',
  );
}
