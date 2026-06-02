import 'dart:async';
import 'package:pure_live/common/index.dart';

class BaseController extends GetxController {
  /// 加载中，更新页面
  var pageLoadding = false.obs;

  /// 加载中,不会更新页面
  var loadding = false;

  /// 空白页面
  var pageEmpty = false.obs;

  /// 页面错误
  var pageError = false.obs;

  /// 未登录
  var notLogin = false.obs;

  /// 错误信息
  var errorMsg = "".obs;

  void handleError(Object exception, {bool showPageError = false}) {
    var msg = exceptionToString(exception);

    if (showPageError) {
      pageError.value = true;
      errorMsg.value = msg;
    } else {
      ToastUtil.show(msg);
    }
  }

  String exceptionToString(Object exception) {
    return exception.toString().replaceAll("Exception:", "");
  }

  void onLogin() {}

  void onLogout() {}
}

class BasePageController<T> extends BaseController {
  final ScrollController scrollController = ScrollController();

  final EasyRefreshController easyRefreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );

  /// 当前页
  int currentPage = 1;

  /// 每页数量
  int pageSize = 30;

  /// 是否还能加载更多
  var canLoadMore = false.obs;

  /// 数据列表
  var list = <T>[].obs;

  @override
  void onClose() {
    scrollController.dispose();
    easyRefreshController.dispose();
    super.onClose();
  }

  /// 下拉刷新
  Future refreshData() async {
    currentPage = 1;
    await loadData();
  }

  /// 加载数据
  Future loadData() async {
    if (loadding) return;

    final bool isRefresh = currentPage == 1;

    try {
      loadding = true;

      pageError.value = false;
      pageEmpty.value = false;
      notLogin.value = false;

      if (isRefresh && list.isEmpty) {
        pageLoadding.value = true;
      }

      final result = await getData(currentPage, pageSize);

      /// 判断是否还有下一页
      final bool hasMore = result.length >= pageSize;

      if (isRefresh) {
        /// 刷新
        list.assignAll(result);

        if (easyRefreshController.controlFinishRefresh) {
          easyRefreshController.finishRefresh(IndicatorResult.success);
        }

        easyRefreshController.resetFooter();
      } else {
        /// 加载更多
        list.addAll(result);

        if (easyRefreshController.controlFinishLoad) {
          easyRefreshController.finishLoad(hasMore ? IndicatorResult.success : IndicatorResult.noMore);
        }
      }

      canLoadMore.value = hasMore;

      if (hasMore) {
        currentPage++;
      }

      pageEmpty.value = isRefresh && result.isEmpty;
    } catch (e) {
      handleError(e, showPageError: isRefresh && list.isEmpty);

      if (isRefresh) {
        if (easyRefreshController.controlFinishRefresh) {
          easyRefreshController.finishRefresh(IndicatorResult.fail);
        }
      } else {
        if (easyRefreshController.controlFinishLoad) {
          easyRefreshController.finishLoad(IndicatorResult.fail);
        }
      }
    } finally {
      loadding = false;
      pageLoadding.value = false;
    }
  }

  /// 子类实现
  Future<List<T>> getData(int page, int pageSize) async {
    return [];
  }

  /// 滚动到底部
  void scrollToBottom() {
    if (!scrollController.hasClients) return;

    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
  }

  /// 返回顶部或刷新
  void scrollToTopOrRefresh() {
    if (!scrollController.hasClients) return;

    if (scrollController.offset > 0) {
      scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.linear);
    } else {
      easyRefreshController.callRefresh();
    }
  }
}
