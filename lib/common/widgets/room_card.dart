import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_page.dart';

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
    final controller = SettingsService.to.roomCardConfig;

    return Obx(() {
      final config = controller.resolveCurrentConfig(dense: dense, showDelete: showDelete);
      final isMobileViewport = controller.isMobileViewport;
      final key = isMobileViewport
          ? ValueKey('mobile_preview_${controller.mobilePreset.value}_${config.hashCode}')
          : ValueKey('desktop_preview_${controller.desktopPreset.value}_${config.hashCode}');
      return RoomCardPage(
        key: key,
        room: room,
        config: config,
        dense: config.denseMode,
        showDelete: config.showDelete,
        statusPending: statusPending,
        statusPendingLabel: statusPendingLabel,
        onDelete: onDelete,
        debug: false,
      );
    });
  }
}
