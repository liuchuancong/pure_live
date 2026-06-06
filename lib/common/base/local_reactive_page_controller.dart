import 'dart:async';
import 'package:pure_live/common/index.dart';

abstract class LocalReactivePageController<T> extends BasePageScrollAndStateBone<T> {
  final List<T> _localRawPool = [];

  void Function()? onExternalRefresh;

  void updateLocalReactivePool(List<T> freshData) {
    _localRawPool.clear();
    _localRawPool.addAll(freshData);
    _processLocalReactiveSlicing();
  }

  @override
  Future<void> refreshData() async {
    onExternalRefresh?.call();
    _processLocalReactiveSlicing();
  }

  @override
  Future<void> goToPage(int page) async {
    if (loadding || page < 1) return;
    final maxPage = (_localRawPool.length / pageSize.value).ceil();
    if (page > maxPage) return;
    currentPage = page;
    _processLocalReactiveSlicing();
  }

  @override
  void setPageSize(int? newSize) {
    if (newSize == null || pageSize.value == newSize) return;
    final int currentFirstItemIndex = (currentPage - 1) * pageSize.value;
    pageSize.value = newSize;
    currentPage = (currentFirstItemIndex ~/ newSize) + 1;
    _processLocalReactiveSlicing();
  }

  @override
  Future<void> loadData() async {
    _processLocalReactiveSlicing();
  }

  void _processLocalReactiveSlicing() {
    totalCount.value = _localRawPool.length;

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
}
