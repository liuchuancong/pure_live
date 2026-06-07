import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';

extension BasePageViewContentExtension<C extends BasePageScrollAndStateBone<T>, T> on BasePageView<C, T> {
  Widget buildActualContent(BuildContext context, bool isDesktop) {
    if (isDesktop) {
      return CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
            if (controller.currentPage > 1 && !controller.loadding.value) {
              controller.goToPage(controller.currentPage - 1);
            }
          },
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {
            if (controller.canLoadMore.value && !controller.loadding.value && enableLoadMore) {
              controller.goToPage(controller.currentPage + 1);
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              Expanded(child: contentBuilder(context, controller.list, controller.scrollController)),
              if (enableLoadMore)
                DesktopPaginationBar(
                  controller: controller,
                  showSelector: showPageSizeSelector,
                  options: pageSizeOptions,
                ),
            ],
          ),
        ),
      );
    } else {
      return EasyRefresh(
        controller: controller.easyRefreshController,
        onRefresh: enableRefresh ? controller.refreshData : null,
        onLoad: (enableLoadMore && controller.canLoadMore.value)
            ? () async {
                await controller.loadMoreData();
              }
            : null,
        child: contentBuilder(context, controller.list, controller.scrollController),
      );
    }
  }

  Widget buildFloatingButtons(BuildContext context) {
    return Obx(() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: controller.showBackToTop.value ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FloatingActionButton(
                heroTag: "base_page_view_to_top_${controller.hashCode}",
                mini: true,
                elevation: 3,
                backgroundColor: Theme.of(context).cardColor,
                onPressed: controller.scrollToTopOrRefresh,
                child: const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ),
          AnimatedScale(
            scale: controller.showBackToBottom.value ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: FloatingActionButton(
              heroTag: "base_page_view_to_bottom_${controller.hashCode}",
              mini: true,
              elevation: 3,
              backgroundColor: Theme.of(context).cardColor,
              onPressed: controller.scrollToBottom,
              child: const Icon(Icons.arrow_downward_rounded),
            ),
          ),
        ],
      );
    });
  }
}
