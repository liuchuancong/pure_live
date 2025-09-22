import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/refresh_grid_util.dart';

import 'favorite_grid_controller.dart';

class FavoriteGridView extends StatefulWidget {
  final String tag;

  const FavoriteGridView(this.tag, {super.key});

  @override
  State<FavoriteGridView> createState() => _FavoriteGridViewState();
}

class _FavoriteGridViewState extends State<FavoriteGridView> {
  FavoriteGridController get controller => Get.find<FavoriteGridController>(tag: widget.tag);

  @override
  Widget build(BuildContext context) {
    return RefreshGridUtil.buildRoomCard(controller);
  }
}
