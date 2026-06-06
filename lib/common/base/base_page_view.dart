import 'package:flutter/gestures.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/base/base_controller.dart';
import 'package:pure_live/common/global/platform_utils.dart';

class BasePageView<C extends BasePageScrollAndStateBone<T>, T> extends StatelessWidget {
  final C controller;
  final Widget Function(BuildContext context, List<T> list, ScrollController scrollController) contentBuilder;
  final bool enableRefresh;
  final bool enableLoadMore;
  final bool? showScrollToTopBtn;
  final bool showPageSizeSelector;
  final List<int> pageSizeOptions;

  final Widget Function(BuildContext context)? notLoginBuilder;
  final Widget Function(BuildContext context, String errorMsg)? errorBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;

  const BasePageView({
    super.key,
    required this.controller,
    required this.contentBuilder,
    this.enableRefresh = true,
    this.enableLoadMore = true,
    this.showScrollToTopBtn,
    this.showPageSizeSelector = false,
    this.pageSizeOptions = const [],
    this.notLoginBuilder,
    this.errorBuilder,
    this.emptyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final bool showBtn = showScrollToTopBtn ?? true;
    return Stack(
      children: [
        Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              if (controller.scrollController.hasClients) {
                final offset = controller.scrollController.offset;
                if (offset > 400 && !controller.showBackToTop.value) {
                  controller.showBackToTop.value = true;
                } else if (offset <= 400 && controller.showBackToTop.value) {
                  controller.showBackToTop.value = false;
                }
              }
            }
          },
          child: NotificationListener<ScrollNotification>(
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
                              style: AppTextStyles.t13Medium.copyWith(color: Colors.amber.shade900),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              BaseController.neverShowCellularBanner = true;
                              controller.showCellularBanner.value = false;
                            },
                            child: Text(
                              i18n("never_show"),
                              style: AppTextStyles.t13Bold.copyWith(color: Colors.amber.shade900),
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
                            final view = notLoginBuilder != null
                                ? notLoginBuilder!(context)
                                : AppStatusView(
                                    type: AppStatusType.error,
                                    icon: Icons.account_circle_outlined,
                                    title: i18n("login_required_title"),
                                    subtitle: i18n("login_required_subtitle"),
                                    buttonText: i18n("go_to_login"),
                                    onButtonPressed: () => Get.toNamed(RoutePath.kSettingsAccount),
                                  );
                            return _buildScrollableStatus(constraint, controller, view);
                          }
                          if (controller.pageError.value) {
                            final view = errorBuilder != null
                                ? errorBuilder!(context, controller.errorMsg.value)
                                : AppStatusView(
                                    type: AppStatusType.error,
                                    icon: Icons.wifi_off_rounded,
                                    title: i18n("network_error_title"),
                                    subtitle: controller.errorMsg.value,
                                    buttonText: i18n("retry"),
                                    onButtonPressed: () => controller.refreshData(),
                                  );
                            return _buildScrollableStatus(constraint, controller, view);
                          }
                          if (controller.pageEmpty.value) {
                            final view = emptyBuilder != null
                                ? emptyBuilder!(context)
                                : AppStatusView(type: AppStatusType.empty, title: i18n('no_data'), subtitle: '');
                            return _buildScrollableStatus(constraint, controller, view);
                          }
                          return AppStatusView(
                            type: AppStatusType.loading,
                            title: i18n('refresh_loading'),
                            subtitle: '',
                          );
                        }
                        return buildActualContent(context, showBtn);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showBtn)
          Positioned(right: 16, bottom: PlatformUtils.isDesktop ? 70 : 20, child: buildFloatingButtons(context)),
        Obx(() {
          if (controller.list.isNotEmpty && controller.loadding.value) {
            return Container(
              color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 1),
              child: AppStatusView(
                icon: Remix.loader_2_fill,
                type: AppStatusType.loading,
                title: i18n('refresh_loading'),
                subtitle: '',
              ),
            );
          }
          return const SizedBox.shrink();
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
