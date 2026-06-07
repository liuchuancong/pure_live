import 'dart:async';
import 'package:pure_live/common/index.dart';

abstract class LocalReactivePageController<T> extends BasePageScrollAndStateBone<T> {
  final List<T> _localRawPool = [];

  void Function()? onExternalRefresh;

  void updateLocalReactivePool(List<T> freshData) {
    _localRawPool.clear();
    _localRawPool.addAll(freshData);
    currentPage = 1;
    _processDataDistribution();
  }

  @override
  Future<void> refreshData() async {
    onExternalRefresh?.call();
    currentPage = 1;
    _processDataDistribution();
  }

  @override
  Future<void> goToPage(int page) async {
    if (loadding.value || page < 1) return;
    if (Get.width <= 680) return;

    final maxPage = (_localRawPool.length / pageSize.value).ceil();
    if (page > maxPage) return;
    currentPage = page;
    _processDataDistribution();
  }

  @override
  void setPageSize(int? newSize) {
    if (newSize == null || pageSize.value == newSize) return;
    if (Get.width <= 680) {
      pageSize.value = newSize;
      return;
    }

    final int currentFirstItemIndex = (currentPage - 1) * pageSize.value;
    pageSize.value = newSize;
    currentPage = (currentFirstItemIndex ~/ newSize) + 1;
    _processDataDistribution();
  }

  @override
  Future<void> loadData() async {
    _processDataDistribution();
  }

  void _processDataDistribution() {
    totalCount.value = _localRawPool.length;

    if (Get.width > 680) {
      _processDesktopSlicing();
    } else {
      _processMobileDisplayAll();
    }
  }

  void _processDesktopSlicing() {
    int startIndex = (currentPage - 1) * pageSize.value;
    if (startIndex >= _localRawPool.length) {
      if (_localRawPool.isEmpty) {
        list.clear();
        canLoadMore.value = false;
        pageEmpty.value = true;
        finishRefreshControllers(IndicatorResult.noMore);
        return;
      }
      currentPage = (_localRawPool.length / pageSize.value).ceil();
      startIndex = (currentPage - 1) * pageSize.value;
    }

    int endIndex = startIndex + pageSize.value;
    if (endIndex > _localRawPool.length) endIndex = _localRawPool.length;

    list.assignAll(_localRawPool.sublist(startIndex, endIndex));
    canLoadMore.value = endIndex < _localRawPool.length;
    pageEmpty.value = list.isEmpty;
    finishRefreshControllers(canLoadMore.value ? IndicatorResult.success : IndicatorResult.noMore);
    scrollToTopImmediate();
  }

  void _processMobileDisplayAll() {
    if (_localRawPool.isEmpty) {
      list.clear();
      canLoadMore.value = false;
      pageEmpty.value = true;
      finishRefreshControllers(IndicatorResult.noMore);
      return;
    }

    pageEmpty.value = false;
    list.assignAll(_localRawPool);
    canLoadMore.value = false;
    finishRefreshControllers(IndicatorResult.noMore);
  }
}
