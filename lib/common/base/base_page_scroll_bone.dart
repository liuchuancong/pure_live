import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/base/base_controller.dart';
import 'package:pure_live/common/global/platform_utils.dart';

abstract class BasePageScrollAndStateBone<T> extends BaseController {
  final ScrollController scrollController = ScrollController();
  final EasyRefreshController easyRefreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );

  int currentPage = 1;
  final pageSize = 30.obs;
  final canLoadMore = false.obs;
  final list = <T>[].obs;
  final totalCount = Rxn<int>();

  final showBackToTop = false.obs;
  final showBackToBottom = true.obs;

  BasePageScrollAndStateBone() {
    scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (!scrollController.hasClients) return;
    final offset = scrollController.offset;
    final position = scrollController.position;
    final maxScroll = position.maxScrollExtent;

    if (offset > 400 && !showBackToTop.value) {
      showBackToTop.value = true;
    } else if (offset <= 400 && showBackToTop.value) {
      showBackToTop.value = false;
    }

    if (position.atEdge && offset > 0) {
      showBackToBottom.value = false;
    } else {
      if (maxScroll - offset > 400) {
        if (!showBackToBottom.value) showBackToBottom.value = true;
      } else {
        if (showBackToBottom.value) showBackToBottom.value = false;
      }
    }
  }

  @override
  void onClose() {
    scrollController.removeListener(_scrollListener);
    scrollController.dispose();
    easyRefreshController.dispose();
    super.onClose();
  }

  void scrollToTopImmediate() {
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
  }

  void finishRefreshControllers(IndicatorResult result) {
    if (PlatformUtils.isDesktop) return;
    easyRefreshController.finishRefresh(
      result == IndicatorResult.fail ? IndicatorResult.fail : IndicatorResult.success,
    );
    easyRefreshController.finishLoad(result);
  }

  void scrollToBottom() {
    if (!scrollController.hasClients) return;
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
  }

  void scrollToTopOrRefresh() {
    if (!scrollController.hasClients) return;
    if (scrollController.offset > 0) {
      scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.linear);
    } else {
      if (PlatformUtils.isDesktop) {
        refreshData();
      } else {
        easyRefreshController.callRefresh();
      }
    }
  }

  Future<void> loadData();
  Future<void> refreshData();
  Future<void> goToPage(int page);
  void setPageSize(int? newSize);
}
