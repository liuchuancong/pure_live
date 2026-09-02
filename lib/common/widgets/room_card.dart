import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_page.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_model.dart';

class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.room,
    this.dense = false,
    this.statusPending = false,
    this.statusPendingLabel,
    this.showDelete = false,
    this.onDelete,
  });

  final LiveRoom room;
  final bool dense;
  final bool statusPending;
  final String? statusPendingLabel;
  final bool showDelete;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = SettingsService.to.roomCardConfig;

    return Obx(() {
      final config = controller.presetValue != RoomCardPreset.custom
          ? RoomCardModel.fromPreset(controller.presetValue)
          : RoomCardModel.fromController(controller, isDark: isDark);

      return RoomCardPage(
        room: room,
        config: config,
        dense: controller.denseMode.value || dense,
        showDelete: showDelete,
        statusPending: statusPending,
        statusPendingLabel: statusPendingLabel,
        onDelete: onDelete,
        debug: false,
      );
    });
  }
}
