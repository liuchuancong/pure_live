import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/base/server_fixed_page_controller.dart';
import 'package:pure_live/common/base/server_remote_page_controller.dart';
import 'package:pure_live/get/get.dart';

class _FixedController extends ServerFixedPageController<int> {
  _FixedController() : super(fixedServerPageSize: 20);

  final requests = <Completer<List<int>>>[];

  @override
  bool get usesDesktopPagination => false;

  @override
  Future<List<int>> fetchFixedNetworkData(int bigPage, int fixedSize) {
    final request = Completer<List<int>>();
    requests.add(request);
    return request.future;
  }
}

class _RemoteController extends ServerRemotePageController<int> {
  final requests = <Completer<List<int>>>[];

  @override
  bool get usesDesktopPagination => false;

  @override
  Future<List<int>> fetchNetworkData(int page, int pageSize) {
    final request = Completer<List<int>>();
    requests.add(request);
    return request.future;
  }
}

Future<void> _waitForRequest(List<Object> requests, int count) async {
  while (requests.length < count) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('fixed-page refresh retains the old mobile grid until atomic replacement', () async {
    final controller = _FixedController()..list.assignAll([1, 2]);
    addTearDown(controller.onClose);

    final refresh = controller.refreshData();
    await _waitForRequest(controller.requests, 1);
    expect(controller.list, [1, 2]);

    controller.requests.single.complete([3, 4]);
    await refresh;

    expect(controller.list, [3, 4]);
  });

  test('remote-page refresh retains the old mobile grid until atomic replacement', () async {
    final controller = _RemoteController()..list.assignAll([1, 2]);
    addTearDown(controller.onClose);
    final fresh = List<int>.generate(20, (index) => index + 3);

    final refresh = controller.refreshData();
    await _waitForRequest(controller.requests, 1);
    expect(controller.list, [1, 2]);

    controller.requests.single.complete(fresh);
    await refresh;

    expect(controller.list, fresh);
  });

  test('refresh waits for an active page request and then replaces its snapshot', () async {
    final controller = _RemoteController();
    addTearDown(controller.onClose);

    final initial = controller.loadData();
    await _waitForRequest(controller.requests, 1);
    final refresh = controller.refreshData();
    final firstPage = List<int>.generate(20, (index) => index + 1);
    final refreshedPage = List<int>.generate(20, (index) => index + 101);
    controller.requests[0].complete(firstPage);
    await initial;

    await _waitForRequest(controller.requests, 2);
    expect(controller.list, firstPage);
    controller.requests[1].complete(refreshedPage);
    await refresh;

    expect(controller.list, refreshedPage);
  });

  test('tab pages can bind independent scroll controllers without transferring ownership', () {
    final controller = _RemoteController();
    final firstTab = ScrollController();
    final secondTab = ScrollController();

    controller.bindActiveScrollController(firstTab);
    expect(controller.scrollController, same(firstTab));
    controller.bindActiveScrollController(secondTab);
    expect(controller.scrollController, same(secondTab));
    controller.bindActiveScrollController(null);
    expect(controller.scrollController, isNot(anyOf(same(firstTab), same(secondTab))));

    controller.onClose();
    firstTab.dispose();
    secondTab.dispose();
  });
}
