import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class HistoryPage extends GetView {
  HistoryPage({super.key});

  final refreshController = EasyRefreshController(controlFinishRefresh: true, controlFinishLoad: true);

  Future onRefresh() async {
    bool result = true;
    final SettingsService settings = Get.find<SettingsService>();

    for (final room in settings.historyRooms) {
      try {
        var newRoom = await Sites.of(
          room.platform!,
        ).liveSite.getRoomDetail(roomId: room.roomId!, platform: room.platform!);
        settings.updateRoomInHistory(newRoom);
      } catch (e) {
        result = false;
      }
    }
    if (result) {
      refreshController.finishRefresh(IndicatorResult.success);
      refreshController.resetFooter();
    } else {
      refreshController.finishRefresh(IndicatorResult.fail);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SettingsService settings = Get.find<SettingsService>();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        title: Text('${i18n("history")}(${settings.historyRooms.length}/20)'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_forever),
            onPressed: () {
              settings.historyRooms.clear();
              onRefresh();
            },
          ),
        ],
      ),
      body: Obx(() {
        const dense = true;
        final rooms = settings.historyRooms.toList();
        return LayoutBuilder(
          builder: (context, constraint) {
            final width = constraint.maxWidth;
            int crossAxisCount = width > 1280 ? 4 : (width > 960 ? 3 : (width > 640 ? 2 : 1));
            if (dense) {
              crossAxisCount = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));
            }
            return EasyRefresh(
              controller: refreshController,
              onRefresh: onRefresh,
              onLoad: () {
                refreshController.finishLoad(IndicatorResult.noMore);
              },
              child: rooms.isEmpty
                  ? EmptyView(icon: Icons.history_rounded, title: i18n("empty_history"), subtitle: '')
                  : WaterfallFlow.builder(
                      padding: const EdgeInsets.all(0),
                      controller: ScrollController(),
                      gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 3,
                        mainAxisSpacing: 3,
                      ),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) => RoomCard(room: rooms[index], dense: dense),
                    ),
            );
          },
        );
      }),
    );
  }
}
