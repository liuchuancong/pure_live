import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/base/base_controller.dart';
import 'package:pure_live/common/global/platform_utils.dart';

class BasePageView<C extends BasePageController<T>, T> extends StatelessWidget {
  final C controller;
  final Widget Function(BuildContext context, List<T> list, ScrollController scrollController) contentBuilder;
  final bool enableRefresh;
  final bool enableLoadMore;
  final bool? showScrollToTopBtn;
  final String? tag;

  const BasePageView({
    super.key,
    required this.contentBuilder,
    this.enableRefresh = true,
    this.enableLoadMore = true,
    this.showScrollToTopBtn,
    this.tag,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final bool showBtn = showScrollToTopBtn ?? (!PlatformUtils.isDesktop);

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            if (notification.metrics.axis == Axis.vertical) {
              final offset = notification.metrics.pixels;
              if (offset > 400 && !controller.showBackToTop.value) {
                controller.showBackToTop.value = true;
              } else if (offset <= 400 && controller.showBackToTop.value) {
                controller.showBackToTop.value = false;
              }
            }
            return false;
          },
          child: Column(
            children: [
              Obx(() {
                if (controller.showCellularBanner.value && controller.list.isNotEmpty) {
                  return Container(
                    color: Colors.amber.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.signal_cellular_alt_rounded, color: Colors.amber.shade900, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            i18n("cellular_warning_msg"),
                            style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            BaseController.neverShowCellularBanner = true;
                            controller.showCellularBanner.value = false;
                          },
                          child: Text(
                            i18n("never_show"),
                            style: TextStyle(color: Colors.amber.shade900, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraint) {
                    return Obx(() {
                      if (controller.list.isEmpty) {
                        if (controller.notLogin.value) {
                          return _buildScrollableStatus(
                            constraint,
                            controller,
                            AppStatusView(
                              type: AppStatusType.error,
                              icon: Icons.account_circle_outlined,
                              title: i18n("login_required_title"),
                              subtitle: i18n("login_required_subtitle"),
                              buttonText: i18n("go_to_login"),
                              onButtonPressed: () => Get.toNamed(RoutePath.kSettingsAccount),
                            ),
                          );
                        }
                        if (controller.pageError.value) {
                          return _buildScrollableStatus(
                            constraint,
                            controller,
                            AppStatusView(
                              type: AppStatusType.error,
                              icon: Icons.wifi_off_rounded,
                              title: i18n("network_error_title"),
                              subtitle: controller.errorMsg.value,
                              buttonText: i18n("retry"),
                              onButtonPressed: () {
                                if (PlatformUtils.isDesktop) {
                                  controller.refreshData();
                                } else {
                                  controller.easyRefreshController.callRefresh();
                                }
                              },
                            ),
                          );
                        }
                        if (controller.pageEmpty.value) {
                          return _buildScrollableStatus(
                            constraint,
                            controller,
                            AppStatusView(type: AppStatusType.empty, title: i18n('no_data'), subtitle: ''),
                          );
                        }
                        return AppStatusView(type: AppStatusType.loading, title: i18n('refresh_loading'), subtitle: '');
                      }
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
                                if (enableLoadMore) _DesktopPaginationBar(controller: controller),
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
                                  controller.currentPage++;
                                  await controller.loadData();
                                }
                              : null,
                          child: contentBuilder(context, controller.list, controller.scrollController),
                        );
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        if (showBtn)
          Obx(() {
            return Positioned(
              right: 16,
              bottom: PlatformUtils.isDesktop ? 70 : 20,
              child: Column(
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
              ),
            );
          }),
      ],
    );
  }

  Widget _buildScrollableStatus(BoxConstraints constraint, C controller, Widget statusView) {
    if (PlatformUtils.isDesktop || !enableRefresh) {
      return Center(child: statusView);
    }
    return EasyRefresh(
      controller: controller.easyRefreshController,
      onRefresh: () => controller.refreshData(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: constraint.maxHeight * 0.8, child: statusView)],
      ),
    );
  }
}

class _DesktopPaginationBar extends StatelessWidget {
  final BasePageController controller;
  final _inputController = TextEditingController();

  _DesktopPaginationBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int current = controller.currentPage;
      final bool hasPrev = current > 1;
      final bool hasNext = controller.canLoadMore.value;
      final int? total = controller.totalCount.value;
      final int maxPage = total != null ? (total / controller.pageSize).ceil() : 0;

      List<Widget> pageNodes = [];
      pageNodes.add(_buildNumBlock(context, 1, current == 1));

      if (current > 3) {
        pageNodes.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text("...", style: TextStyle(color: Colors.grey, fontSize: 13)),
          ),
        );
      }

      int start = current - 1;
      int end = current + 1;
      if (start <= 1) start = 2;
      if (total != null && end >= maxPage) end = maxPage - 1;

      for (int i = start; i <= end; i++) {
        if (total == null && !hasNext && i > current) break;
        if (i <= 1) continue;
        pageNodes.add(_buildNumBlock(context, i, current == i));
      }

      if (total != null && maxPage > 1) {
        if (end < maxPage - 1) {
          pageNodes.add(
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text("...", style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          );
        }
        pageNodes.add(_buildNumBlock(context, maxPage, current == maxPage));
      } else if (total == null && hasNext) {
        pageNodes.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text("...", style: TextStyle(color: Colors.grey, fontSize: 13)),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTextButton(
              context,
              icon: Icons.arrow_back_ios_new_rounded,
              label: i18n("prev_page"),
              onPressed: (hasPrev && !controller.loadding) ? () => controller.goToPage(current - 1) : null,
            ),
            const SizedBox(width: 8),
            ...pageNodes,
            const SizedBox(width: 8),
            _buildTextButton(
              context,
              icon: Icons.arrow_forward_ios_rounded,
              label: i18n("next_page"),
              isNext: true,
              onPressed: (hasNext && !controller.loadding) ? () => controller.goToPage(current + 1) : null,
            ),
            const SizedBox(width: 16),
            _buildJumpInput(context, current, maxPage, total != null),
          ],
        ),
      );
    });
  }

  Widget _buildNumBlock(BuildContext context, int pageNum, bool isCurrent) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: (isCurrent || controller.loadding) ? null : () => controller.goToPage(pageNum),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          constraints: const BoxConstraints(minWidth: 32),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCurrent ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isCurrent ? theme.colorScheme.primary : theme.dividerColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Text(
            "$pageNum",
            style: TextStyle(
              fontSize: 13,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJumpInput(BuildContext context, int current, int maxPage, bool isFixedMode) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(i18n("go_to"), style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: SizedBox(
            width: 50,
            height: 30,
            child: TextField(
              controller: _inputController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 13, height: 1.2),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
              onSubmitted: (value) {
                final targetPage = int.tryParse(value);
                if (targetPage != null && targetPage > 0 && targetPage != current && !controller.loadding) {
                  if (isFixedMode && targetPage > maxPage) {
                    _inputController.clear();
                    return;
                  }
                  controller.goToPage(targetPage);
                }
                _inputController.clear();
              },
            ),
          ),
        ),
        Text(i18n("page_unit"), style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTextButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isNext = false,
  }) {
    final bool showLoading = isNext && controller.loadding;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        disabledForegroundColor: Theme.of(context).disabledColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isNext) Icon(icon, size: 13),
          if (!isNext) const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          if (isNext) const SizedBox(width: 6),
          if (isNext && !showLoading) Icon(icon, size: 13),
          if (showLoading) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}
