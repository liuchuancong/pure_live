import 'package:pure_live/core/widgets/refresh_indicators.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/pagination/base_controller.dart';
import 'package:pure_live/core/platform/platform_utils.dart';

class BasePageView<C extends BasePageScrollAndStateBone<T>, T> extends StatelessWidget {
  final C controller;
  final Widget Function(BuildContext context, List<T> list, ScrollController scrollController) contentBuilder;
  final bool enableRefresh;
  final bool enableLoadMore;

  /// Lets a nested tab page own the mobile refresh indicator directly.
  ///
  /// A refresh wrapper outside a horizontal [PageView] does not reliably
  /// receive overscroll notifications from its active vertical child.
  final bool wrapMobileRefresh;

  /// Keeps [contentBuilder] mounted after an empty snapshot has been
  /// published. Tabbed pages use this so landing on one empty tab does not
  /// dispose the surrounding TabBarView and strand the horizontal gesture.
  /// Later failures use the bounded notice region, retaining both the cached
  /// navigation and the caller's recovery actions. Initial failures still
  /// use the full-page status until a snapshot has been published.
  final bool preserveContentWhenEmpty;
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
    this.wrapMobileRefresh = true,
    this.preserveContentWhenEmpty = false,
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
    final bool isDesktop = currentWidth > 680 && !PlatformUtils.isMobile;

    double bottomPadding = isDesktop ? (customDesktopBottomPadding ?? 70) : (customMobileBottomPadding ?? 20);

    return LayoutBuilder(
      builder: (context, pageConstraints) => Stack(
        children: [
          Column(
            children: [
              // The caller may own a tabbed/nested scroll view. Keep its
              // controller and refresh boundary intact, while reserving at
              // least half the viewport for content when notices grow.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: pageConstraints.maxHeight / 2),
                child: SingleChildScrollView(
                  key: const ValueKey('base-page-notices'),
                  primary: false,
                  physics: const PureLiveBoundedScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.pageNotice case final notice?)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Text(notice, style: Theme.of(context).textTheme.bodySmall),
                        ),
                      _buildCellularBanner(context),
                      if (preserveContentWhenEmpty)
                        Obx(() {
                          if (controller.list.isNotEmpty || controller.totalCount.value == null) {
                            return const SizedBox.shrink();
                          }
                          final Widget status;
                          if (controller.notLogin.value) {
                            status = _buildLoginStatus(context);
                          } else if (controller.pageError.value) {
                            status = _buildErrorStatus(context);
                          } else {
                            return const SizedBox.shrink();
                          }
                          return Semantics(
                            key: const ValueKey('base-page-retained-recovery'),
                            liveRegion: true,
                            child: status,
                          );
                        }),
                      if (controller.showInlineError)
                        Obx(() {
                          if (controller.list.isEmpty ||
                              !controller.pageError.value ||
                              controller.errorMsg.value.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final colors = Theme.of(context).colorScheme;
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: Semantics(
                              liveRegion: true,
                              child: MaterialBanner(
                                backgroundColor: colors.errorContainer,
                                leading: Icon(Icons.info_outline_rounded, color: colors.onErrorContainer),
                                content: Text(
                                  controller.errorMsg.value,
                                  style: TextStyle(color: colors.onErrorContainer),
                                ),
                                forceActionsBelow: true,
                                actions: [
                                  TextButton(
                                    onPressed: controller.loadding.value ? null : () => controller.retryData(),
                                    child: Text(controller.retryActionLabel),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraint) {
                    controller.checkAndNotifyLayoutChange(isDesktop);
                    return Obx(() {
                      if (controller.list.isEmpty) {
                        if (preserveContentWhenEmpty && controller.totalCount.value != null) {
                          return buildActualContent(context, isDesktop);
                        }
                        if (controller.notLogin.value) {
                          return _buildScrollableStatus(
                            context,
                            isDesktop,
                            constraint,
                            controller,
                            _buildLoginStatus(context),
                          );
                        }
                        if (controller.pageError.value) {
                          return _buildScrollableStatus(
                            context,
                            isDesktop,
                            constraint,
                            controller,
                            _buildErrorStatus(context),
                          );
                        }
                        if (controller.pageEmpty.value && !preserveContentWhenEmpty) {
                          final view = emptyBuilder != null
                              ? emptyBuilder!(context)
                              : AppStatusView(type: AppStatusType.empty, title: i18n('no_data'), subtitle: '');
                          return _buildScrollableStatus(context, isDesktop, constraint, controller, view);
                        }
                        return AppStatusView(type: AppStatusType.loading, title: i18n('refresh_loading'), subtitle: '');
                      }
                      return buildActualContent(context, isDesktop);
                    });
                  },
                ),
              ),
            ],
          ),
          if (showBtn) Positioned(right: 16, bottom: bottomPadding, child: buildFloatingButtons(context)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Obx(() {
              final hasVisibleContent =
                  controller.list.isNotEmpty || (preserveContentWhenEmpty && controller.totalCount.value != null);
              if (hasVisibleContent && controller.loadding.value) {
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
      ),
    );
  }

  Widget _buildLoginStatus(BuildContext context) =>
      notLoginBuilder?.call(context) ??
      AppStatusView(
        type: AppStatusType.error,
        icon: Icons.account_circle_outlined,
        title: i18n("login_required_title"),
        subtitle: i18n("login_required_subtitle"),
        buttonText: i18n("go_to_login"),
        onButtonPressed: () => Get.toNamed(RoutePath.kSettingsAccount),
      );

  Widget _buildErrorStatus(BuildContext context) =>
      errorBuilder?.call(context, controller.errorMsg.value) ??
      AppStatusView(
        type: AppStatusType.error,
        icon: Icons.wifi_off_rounded,
        title: i18n("network_error_title"),
        subtitle: controller.errorMsg.value,
        buttonText: controller.retryActionLabel,
        onButtonPressed: () => controller.retryData(),
      );

  Widget _buildScrollableStatus(
    BuildContext context,
    bool isDesktop,
    BoxConstraints constraint,
    C controller,
    Widget statusView,
  ) {
    Widget buildScrollable(ScrollPhysics physics) => SingleChildScrollView(
      key: const ValueKey('base-page-status'),
      primary: false,
      physics: physics,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraint.maxHeight * (isDesktop || !enableRefresh ? 1 : 0.8)),
        child: Center(child: statusView),
      ),
    );
    if (isDesktop || !enableRefresh) {
      return buildScrollable(const PureLiveScrollPhysics(parent: AlwaysScrollableScrollPhysics()));
    }
    final indicators = appRefreshIndicators(context, maxWidth: constraint.maxWidth);
    return EasyRefresh.builder(
      header: indicators.header,
      footer: indicators.footer,
      controller: controller.easyRefreshController,
      triggerAxis: Axis.vertical,
      onRefresh: () => controller.refreshData(),
      // This scrollable must use the refresh owner's physics; otherwise its
      // explicit overscroll policy consumes the drag before refresh is armed.
      childBuilder: (context, physics) => buildScrollable(physics),
    );
  }

  Widget _buildCellularBanner(BuildContext context) {
    return Obx(() {
      if (!controller.showCellularBanner.value || controller.list.isEmpty) return const SizedBox.shrink();
      final colors = Theme.of(context).colorScheme;
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.signal_cellular_alt_rounded, color: colors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    i18n('cellular_warning_msg'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                BaseController.neverShowCellularBanner = true;
                controller.showCellularBanner.value = false;
              },
              child: Text(i18n('never_show'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
  }
}

enum PagingMode {
  serverRemote,
  serverFixedSize,
  serverAll,
  localReactive,
}
