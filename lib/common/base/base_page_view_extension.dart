import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/platform_utils.dart';

extension BasePageViewContentExtension<C extends BasePageScrollAndStateBone<T>, T> on BasePageView<C, T> {
  Widget buildActualContent(BuildContext context, bool showBtn) {
    if (PlatformUtils.isDesktop) {
      return CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
            if (controller.currentPage > 1 && !controller.loadding) {
              controller.goToPage(controller.currentPage - 1);
            }
          },
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {
            if (controller.canLoadMore.value && !controller.loadding && enableLoadMore) {
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
      return Column(
        children: [
          if (showPageSizeSelector &&
              (controller is ServerRemotePageController<T> || controller is ServerFixedPageController<T>))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${i18n("per_page")}: ', style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  CompactPageSizeSelector(controller: controller, options: pageSizeOptions),
                ],
              ),
            ),
          Expanded(
            child: EasyRefresh(
              controller: controller.easyRefreshController,
              onRefresh: enableRefresh ? controller.refreshData : null,
              onLoad: (enableLoadMore && controller.canLoadMore.value)
                  ? () async {
                      if (controller is ServerRemotePageController<T>) {
                        final remoteCtrl = controller as ServerRemotePageController<T>;
                        remoteCtrl.currentPage++;
                        await remoteCtrl.loadData();
                      } else {
                        controller.currentPage++;
                        await controller.loadData();
                      }
                    }
                  : null,
              child: contentBuilder(context, controller.list, controller.scrollController),
            ),
          ),
        ],
      );
    }
  }

  Widget buildFloatingButtons(BuildContext context) {
    return Obx(() {
      // 💡 彻底消灭 Positioned 降级隐患：此处的公开方法只输出纯净的 Column，将定位职责交还给主文件的 Stack 树
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
