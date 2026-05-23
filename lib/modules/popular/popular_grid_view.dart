import 'package:pure_live/common/index.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
import 'package:pure_live/modules/popular/popular_grid_controller.dart';

class PopularGridView extends StatefulWidget {
  final String tag;

  const PopularGridView(this.tag, {super.key});

  @override
  State<PopularGridView> createState() => _PopularGridViewState();
}

class _PopularGridViewState extends State<PopularGridView> {
  PopularGridController get controller => Get.find<PopularGridController>(tag: widget.tag);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraint) {
        final width = constraint.maxWidth;
        final crossAxisCount = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));

        return Obx(() {
          if (controller.list.isEmpty) {
            if (controller.isLoginRequiredError.value) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: constraint.maxHeight * 0.8,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_circle_outlined, size: 48, color: theme.hintColor.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            i18n("login_required_title"),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.titleMedium?.color,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(i18n("login_required_subtitle"), style: TextStyle(fontSize: 13, color: theme.hintColor)),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () => Get.toNamed(RoutePath.kSettingsAccount),
                            icon: const Icon(Icons.login_rounded, size: 18),
                            label: Text(i18n("go_to_login")),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            if (controller.isNetworkError.value) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: constraint.maxHeight * 0.8,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 48, color: theme.hintColor.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            i18n("network_error_title"),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.titleMedium?.color,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(i18n("network_error_subtitle"), style: TextStyle(fontSize: 13, color: theme.hintColor)),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () => controller.easyRefreshController.callRefresh(),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(i18n("retry")),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            // 🎯 ✨【核心修正】：如果不是断网，也不是需要登录，且数据列表为空
            // 这说明此时必然正处于“网络请求正在路上”的【初始首屏加载状态】，直接常驻转圈，不给它滑入 EmptyView 的机会！
            return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary, strokeWidth: 3));
          }

          return EasyRefresh(
            controller: controller.easyRefreshController,
            onRefresh: controller.refreshData,
            onLoad: controller.loadData,
            child: WaterfallFlow.builder(
              padding: const EdgeInsets.all(0),
              controller: controller.scrollController,
              gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
              ),
              itemCount: controller.list.length,
              itemBuilder: (context, index) => RoomCard(room: controller.list[index], dense: true),
            ),
          );
        });
      },
    );
  }
}
