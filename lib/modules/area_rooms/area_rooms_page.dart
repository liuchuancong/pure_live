import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/keep_alive_wrapper.dart';
import 'package:pure_live/modules/area_rooms/area_rooms_controller.dart';
import 'package:pure_live/plugins/cache_network.dart';

import '../../common/widgets/refresh_grid_util.dart';

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
        body: RefreshGridUtil.buildRoomCard(controller),
        floatingActionButton: FavoriteAreaFloatingButton(key: UniqueKey(), area: controller.subCategory),
      ),
    );
  }
}

class FavoriteAreaFloatingButton extends StatefulWidget {
  const FavoriteAreaFloatingButton({
    super.key,
    required this.area,
  });

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
      key: UniqueKey(),
      heroTag: UniqueKey(),
      elevation: 2,
      backgroundColor: Theme
          .of(context)
          .cardColor,
      tooltip: S.current.unfollow,
      onPressed: () {
        Get.dialog(
          AlertDialog(
            title: Text(S.current.unfollow),
            content: Text(S.current.unfollow_message(widget.area.areaName!)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(Get.context!).pop(false),
                child: Text(S.current.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(Get.context!).pop(true),
                child: Text(S.current.confirm),
              ),
            ],
          ),
        ).then((value) {
          if (value == true) {
            setState(() => isFavorite = !isFavorite);
            settings.removeArea(widget.area);
          }
        });
      },
      child: CacheNetWorkUtils.getCircleAvatar(widget.area.areaPic, radius: 18),
    )
        : FloatingActionButton.extended(
      key: UniqueKey(),
      elevation: 2,
      backgroundColor: Theme
          .of(context)
          .cardColor,
      onPressed: () {
        setState(() => isFavorite = !isFavorite);
        settings.addArea(widget.area);
      },
      icon: CacheNetWorkUtils.getCircleAvatar(widget.area.areaPic, radius: 18),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.current.follow,
            style: Theme
                .of(context)
                .textTheme
                .bodySmall,
          ),
          Text(
            widget.area.areaName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
