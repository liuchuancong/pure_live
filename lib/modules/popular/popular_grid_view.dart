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
                    child: AppStatusView(
                      type: AppStatusType.error,
                      icon: Icons.account_circle_outlined,
                      title: i18n("login_required_title"),
                      subtitle: i18n("login_required_subtitle"),
                      buttonText: i18n("go_to_login"),
                      onButtonPressed: () => Get.toNamed(RoutePath.kSettingsAccount),
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
                    child: AppStatusView(
                      type: AppStatusType.error,
                      icon: Icons.wifi_off_rounded,
                      title: i18n("network_error_title"),
                      subtitle: i18n("network_error_subtitle"),
                      buttonText: i18n("retry"),
                      onButtonPressed: () => controller.easyRefreshController.callRefresh(),
                    ),
                  ),
                ],
              );
            }

            return AppStatusView(type: AppStatusType.loading, title: i18n('refresh_loading'), subtitle: '');
          }

          return EasyRefresh(
            controller: controller.easyRefreshController,
            onRefresh: controller.refreshData,
            onLoad: controller.loadData,
            child: controller.list.isNotEmpty
                ? WaterfallFlow.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    controller: controller.scrollController,
                    gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                      lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: controller.list.length,
                    itemBuilder: (context, index) => RoomCard(room: controller.list[index], dense: true),
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: constraint.maxHeight * 0.8,
                        child: AppStatusView(
                          type: AppStatusType.empty,
                          icon: Icons.live_tv_rounded,
                          title: i18n("empty_live_title"),
                          subtitle: i18n("empty_live_subtitle"),
                        ),
                      ),
                    ],
                  ),
          );
        });
      },
    );
  }
}
