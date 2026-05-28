import 'package:pure_live/common/index.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
import 'package:pure_live/common/widgets/keep_alive_wrapper.dart';
import 'package:pure_live/modules/area_rooms/area_rooms_controller.dart';

class AreasRoomPage extends StatefulWidget {
  const AreasRoomPage({super.key});

  @override
  State<AreasRoomPage> createState() => _AreasRoomPageState();
}

class _AreasRoomPageState extends State<AreasRoomPage> {
  AreaRoomsController get controller => Get.find<AreaRoomsController>();

  @override
  void initState() {
    super.initState();
    controller.loadData();
  }

  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: Scaffold(
        appBar: AppBar(title: Text(controller.subCategory.areaName!)),
        body: LayoutBuilder(
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
                child: WaterfallFlow.builder(
                  gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                    lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: controller.settings.crossAxisSpacing.value,
                    mainAxisSpacing: controller.settings.mainAxisSpacing.value,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  controller: controller.scrollController,
                  itemCount: controller.list.length,
                  itemBuilder: (context, index) => RoomCard(room: controller.list[index], dense: true),
                ),
              );
            });
          },
        ),
        floatingActionButton: FavoriteAreaFloatingButton(area: controller.subCategory),
      ),
    );
  }
}

class FavoriteAreaFloatingButton extends StatefulWidget {
  const FavoriteAreaFloatingButton({super.key, required this.area});

  final LiveArea area;

  @override
  State<FavoriteAreaFloatingButton> createState() => _FavoriteAreaFloatingButtonState();
}

class _FavoriteAreaFloatingButtonState extends State<FavoriteAreaFloatingButton> {
  final settings = Get.find<SettingsService>();

  late bool isFavorite = settings.isFavoriteArea(widget.area);

  @override
  Widget build(BuildContext context) {
    return isFavorite
        ? FloatingActionButton(
            elevation: 2,
            backgroundColor: Theme.of(context).cardColor,
            tooltip: i18n("unfollow"),
            onPressed: () {
              Get.dialog(
                AlertDialog(
                  title: Text(i18n("unfollow")),
                  content: Text(i18n("unfollow_message", args: {"name": widget.area.areaName!})),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(Get.context!).pop(false), child: Text(i18n("cancel"))),
                    ElevatedButton(onPressed: () => Navigator.of(Get.context!).pop(true), child: Text(i18n("confirm"))),
                  ],
                ),
              ).then((value) {
                if (value) {
                  setState(() => isFavorite = !isFavorite);
                  settings.removeArea(widget.area);
                }
              });
            },
            child: CircleAvatar(
              foregroundImage: (widget.area.areaPic == '') ? null : NetworkImage(widget.area.areaPic!),
              radius: 18,
              backgroundColor: Theme.of(context).disabledColor,
            ),
          )
        : FloatingActionButton.extended(
            elevation: 2,
            backgroundColor: Theme.of(context).cardColor,
            onPressed: () {
              setState(() => isFavorite = !isFavorite);
              settings.addArea(widget.area);
            },
            icon: CircleAvatar(
              foregroundImage: (widget.area.areaPic == '') ? null : NetworkImage(widget.area.areaPic!),
              radius: 18,
              backgroundColor: Theme.of(context).disabledColor,
            ),
            label: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i18n("follow"), style: Theme.of(context).textTheme.bodySmall),
                Text(widget.area.areaName!, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          );
  }
}
