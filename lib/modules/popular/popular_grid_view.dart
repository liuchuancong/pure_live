import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/refresh_grid_util.dart';
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
    return RefreshGridUtil.buildRoomCard(controller);
  }
}
