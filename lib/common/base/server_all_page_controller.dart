import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/platform_utils.dart';

abstract class ServerAllPageController<T> extends BasePageScrollAndStateBone<T> {
  List<T>? _rawAllData;

  Future<List<T>> fetchAllServerData();

  @override
  Future<void> refreshData() async {
    _rawAllData = null;
    currentPage = 1;
    await loadData();
  }

  @override
  Future<void> goToPage(int page) async {
    if (loadding || page < 1 || _rawAllData == null) return;
    final maxPage = (_rawAllData!.length / pageSize.value).ceil();
    if (page > maxPage) return;
    currentPage = page;
    processLocalPaging();
  }

  @override
  void setPageSize(int? newSize) {
    if (newSize == null || pageSize.value == newSize || _rawAllData == null) return;
    final int currentFirstItemIndex = (currentPage - 1) * pageSize.value;
    pageSize.value = newSize;
    currentPage = (currentFirstItemIndex ~/ newSize) + 1;
    processLocalPaging();
  }

  @override
  Future<void> loadData() async {
    if (loadding) return;

    if (_rawAllData != null) {
      processLocalPaging();
      return;
    }

    final bool isNetworkSafe = await checkNetworkBeforeRequest();
    if (!isNetworkSafe) {
      finishRefreshControllers(IndicatorResult.fail);
      return;
    }

    try {
      loadding = true;
      pageError.value = false;
      pageEmpty.value = false;
      notLogin.value = false;
      pageLoadding.value = true;

      _rawAllData = await fetchAllServerData();
      processLocalPaging();
    } catch (e) {
      handleError(e, showPageError: list.isEmpty);
      finishRefreshControllers(IndicatorResult.fail);
    } finally {
      loadding = false;
      pageLoadding.value = false;
    }
  }

  void processLocalPaging() {
    if (_rawAllData == null) return;
    final allItems = _rawAllData!;
    totalCount.value = allItems.length;

    if (allItems.isEmpty) {
      list.clear();
      canLoadMore.value = false;
      pageEmpty.value = true;
      finishRefreshControllers(IndicatorResult.noMore);
      return;
    }

    int startIndex = (currentPage - 1) * pageSize.value;
    if (startIndex >= allItems.length) {
      currentPage = 1;
      startIndex = 0;
    }

    int endIndex = startIndex + pageSize.value;
    if (endIndex > allItems.length) endIndex = allItems.length;

    final newData = allItems.sublist(startIndex, endIndex);

    if (PlatformUtils.isDesktop) {
      list.assignAll(newData);
    } else {
      if (currentPage == 1) {
        list.assignAll(newData);
      } else {
        list.addAll(newData);
      }
    }

    canLoadMore.value = endIndex < allItems.length;
    pageEmpty.value = list.isEmpty;
    finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);

    if (currentPage == 1) {
      scrollToTopImmediate();
    }
  }
}
