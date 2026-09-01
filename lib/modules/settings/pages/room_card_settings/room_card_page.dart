import 'room_card_renderer.dart';
import 'room_card_controller.dart';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_model.dart';

class RoomCardPage extends StatelessWidget {
  const RoomCardPage({
    super.key,
    required this.room,
    this.config = const RoomCardModel(cardMargin: EdgeInsets.zero),
    this.dense = false,
    this.statusPending = false,
    this.statusPendingLabel,
    this.showDelete = false,
    this.debug = false,
    this.onDelete,
  });

  final LiveRoom room;
  final RoomCardModel config;
  final bool dense;
  final bool debug;
  final bool statusPending;
  final String? statusPendingLabel;
  final bool showDelete;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final controller = RoomCardController(room: room);

    return RoomCardRenderer(
      room: room,
      config: config,
      dense: dense,
      debug: debug,
      statusPending: statusPending,
      statusPendingLabel: statusPendingLabel,
      showDelete: showDelete,
      onDelete: onDelete,
      onTap: () => controller.onTap(context),
      onLongPress: () => controller.onLongPress(context),
    ).build(context);
  }
}
