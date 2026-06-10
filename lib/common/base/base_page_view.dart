import 'package:flutter/gestures.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/base/base_controller.dart';

class BasePageView<C extends BasePageScrollAndStateBone<T>, T> extends StatelessWidget {
  final C controller;
  final Widget Function(BuildContext context, List<T> list, ScrollController scrollController) contentBuilder;
  final bool enableRefresh;
  final bool enableLoadMore;
  final bool? showScrollToTopBtn;
  final bool showPageSizeSelector;
  final List<int> pageSizeOptions;
  final double? customMobileBottomPadding;
  final double? customDesktopBottomPadding;

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
    this.customMobileBottomPadding,
    this.customDesktopBottomPadding,
    this.notLoginBuilder,
    this.errorBuilder,
    this.emptyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final bool showBtn = showScrollToTopBtn ?? true;
    final double currentWidth = context.width;
    final bool isDesktop = currentWidth > 680;

    double bottomPadding = isDesktop ? (customDesktopBottomPadding ?? 70) : (customMobileBottomPadding ?? 20);

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
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.signal_cellular_alt_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  i18n("cellular_warning_msg"),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  BaseController.neverShowCellularBanner = true;
                                  controller.showCellularBanner.value = false;
                                },
                                child: Text(
                                  i18n("never_show"),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraint) {
                      return Obx(() {
                        controller.checkAndNotifyLayoutChange(isDesktop);

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
                            return _buildScrollableStatus(isDesktop, constraint, controller, view);
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
                            return _buildScrollableStatus(isDesktop, constraint, controller, view);
                          }
                          if (controller.pageEmpty.value) {
                            final view = emptyBuilder != null
                                ? emptyBuilder!(context)
                                : AppStatusView(type: AppStatusType.empty, title: i18n('no_data'), subtitle: '');
                            return _buildScrollableStatus(isDesktop, constraint, controller, view);
                          }
                          return AppStatusView(
                            type: AppStatusType.loading,
                            title: i18n('refresh_loading'),
                            subtitle: '',
                          );
                        }
                        return buildActualContent(context, isDesktop);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showBtn) Positioned(right: 16, bottom: bottomPadding, child: buildFloatingButtons(context)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Obx(() {
            if (controller.list.isNotEmpty && controller.loadding.value && isDesktop) {
              return SizedBox(
                height: 2.5,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ),
      ],
    );
  }

  Widget _buildScrollableStatus(bool isDesktop, BoxConstraints constraint, C controller, Widget statusView) {
    if (isDesktop || !enableRefresh) {
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
