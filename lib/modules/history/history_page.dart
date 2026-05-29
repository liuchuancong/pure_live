import 'package:pure_live/common/index.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class HistoryPage extends GetView {
  HistoryPage({super.key});

  final refreshController = EasyRefreshController(controlFinishRefresh: true, controlFinishLoad: true);

  Future onRefresh() async {
    bool result = true;
    final list = List<LiveRoom>.from(SettingsService.to.history.historyRooms.v);

    for (int i = 0; i < list.length; i++) {
      final room = list[i];
      try {
        var newRoom = await Sites.of(
          room.platform!,
        ).liveSite.getRoomDetail(roomId: room.roomId!, platform: room.platform!);
        list[i] = newRoom;
      } catch (e) {
        result = false;
      }
    }

    SettingsService.to.history.historyRooms.v = list;

    if (result) {
      refreshController.finishRefresh(IndicatorResult.success);
      refreshController.resetFooter();
    } else {
      refreshController.finishRefresh(IndicatorResult.fail);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Obx(() => Text('${i18n("history")}(${SettingsService.to.history.historyRooms.v.length}/50)')),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () {
              SettingsService.to.history.historyRooms.v = [];
            },
          ),
        ],
      ),
      body: Obx(() {
        const dense = true;
        final rooms = SettingsService.to.history.historyRooms.v;
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      controller: ScrollController(),
                      gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                        lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: SettingsService.to.theme.crossAxisSpacing.v,
                        mainAxisSpacing: SettingsService.to.theme.mainAxisSpacing.v,
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
