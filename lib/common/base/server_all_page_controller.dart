import 'dart:async';
import 'package:pure_live/common/index.dart';

abstract class ServerAllPageController<T> extends BasePageScrollAndStateBone<T> {
  List<T>? _rawAllData;

  Future<List<T>> fetchAllServerData();

  @override
  Future<void> refreshData() async {
    _rawAllData = null;
    await loadData();
  }

  @override
  Future<void> goToPage(int page) async {
    if (loadding || page < 1 || _rawAllData == null) return;
    final maxPage = (_rawAllData!.length / pageSize.value).ceil();
    if (page > maxPage) return;
    currentPage = page;
    _processLocalPaging();
  }

  @override
  void setPageSize(int? newSize) {
    if (newSize == null || pageSize.value == newSize || _rawAllData == null) return;
    final int currentFirstItemIndex = (currentPage - 1) * pageSize.value;
    pageSize.value = newSize;
    currentPage = (currentFirstItemIndex ~/ newSize) + 1;
    _processLocalPaging();
  }

  @override
  Future<void> loadData() async {
    if (loadding) return;

    if (_rawAllData != null) {
      _processLocalPaging();
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
      if (list.isEmpty) pageLoadding.value = true;

      _rawAllData = await fetchAllServerData();
      _processLocalPaging();
    } catch (e) {
      handleError(e, showPageError: list.isEmpty);
      finishRefreshControllers(IndicatorResult.fail);
    } finally {
      loadding = false;
      pageLoadding.value = false;
    }
  }

  void _processLocalPaging() {
    if (_rawAllData == null) return;
    final allItems = _rawAllData!;
    totalCount.value = allItems.length;

    int startIndex = (currentPage - 1) * pageSize.value;
    if (startIndex >= allItems.length) {
      currentPage = 1;
      startIndex = 0;
    }

    int endIndex = startIndex + pageSize.value;
    if (endIndex > allItems.length) endIndex = allItems.length;

    list.assignAll(allItems.sublist(startIndex, endIndex));
    canLoadMore.value = endIndex < allItems.length;
    pageEmpty.value = list.isEmpty;
    finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);
    scrollToTopImmediate();
  }
}
