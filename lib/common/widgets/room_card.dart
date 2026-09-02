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
      // 👉 修复1：使用视口宽度判断，不是自定义模式标记
      final isMobileViewport = controller.isMobileViewport;
      late RoomCardModel config;

      if (isMobileViewport) {
        // 👉 必须直接读取 Rx 变量，让 Obx 捕获依赖
        final json = controller.mobileConfigJson.value;
        config = json.isNotEmpty
            ? RoomCardModel.fromJson(json)
            : RoomCardModel.fromPreset(RoomCardPreset.fromKey(controller.mobilePreset.value));

        if (isDark) {
          config = config.copyWith(
            cardBackground: controller.mobileDarkCardColor,
            titleColor: controller.mobileDarkTitleColor,
            subtitleColor: controller.mobileDarkSubtitleColor,
            platformBackgroundColor: controller.mobilePlatformBackgroundDark,
            platformTextColor: controller.mobilePlatformTextDark,
          );
        } else {
          config = config.copyWith(
            cardBackground: controller.mobileLightCardColor,
            titleColor: controller.mobileLightTitleColor,
            subtitleColor: controller.mobileLightSubtitleColor,
            platformBackgroundColor: controller.mobilePlatformBackgroundLight,
            platformTextColor: controller.mobilePlatformTextLight,
          );
        }
      } else {
        final json = controller.desktopConfigJson.value;
        config = json.isNotEmpty
            ? RoomCardModel.fromJson(json)
            : RoomCardModel.fromPreset(RoomCardPreset.fromKey(controller.desktopPreset.value));

        if (isDark) {
          config = config.copyWith(
            cardBackground: controller.desktopDarkCardColor,
            titleColor: controller.desktopDarkTitleColor,
            subtitleColor: controller.desktopDarkSubtitleColor,
            platformBackgroundColor: controller.desktopPlatformBackgroundDark,
            platformTextColor: controller.desktopPlatformTextDark,
          );
        } else {
          config = config.copyWith(
            cardBackground: controller.desktopLightCardColor,
            titleColor: controller.desktopLightTitleColor,
            subtitleColor: controller.desktopLightSubtitleColor,
            platformBackgroundColor: controller.desktopPlatformBackgroundLight,
            platformTextColor: controller.desktopPlatformTextLight,
          );
        }
      }

      return RoomCardPage(
        room: room,
        config: config,
        dense: config.denseMode || dense,
        showDelete: showDelete && config.showDelete,
        statusPending: statusPending,
        statusPendingLabel: statusPendingLabel,
        onDelete: onDelete,
        debug: false,
      );
    });
  }
}
