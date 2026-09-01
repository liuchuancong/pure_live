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
      late RoomCardModel config;
      if (controller.presetValue != RoomCardPreset.custom) {
        config = RoomCardModel.fromPreset(controller.presetValue);
        if (isDark) {
          config = config.copyWith(
            cardBackground: controller.darkCardColorValue,
            titleColor: controller.darkTitleColorValue,
            subtitleColor: controller.darkSubtitleColorValue,
            platformBackgroundColor: controller.platformBackgroundDarkValue,
            platformTextColor: controller.platformTextDarkValue,
          );
        }
      } else {
        config = RoomCardModel(
          cardBackground: isDark ? controller.darkCardColorValue : controller.lightCardColorValue,
          cardBorderRadius: controller.cardRadius.value,
          cardElevation: controller.cardElevation.value,
          enableShadow: controller.enableShadow.value,
          cardMargin: const EdgeInsets.all(0),
          // ===== 封面设置 =====
          coverAspectRatio: controller.coverAspectRatio.value,
          coverBorderRadius: controller.coverRadius.value,
          coverPlaceholderColor: controller.coverPlaceholderColorValue,
          coverFallbackColor: controller.coverFallbackColorValue,
          coverFit: controller.coverFit,
          coverFilterQuality: controller.coverFilterQuality,
          coverCacheMinWidth: controller.coverCacheMinWidth.value,
          coverCacheMaxWidth: controller.coverCacheMaxWidth.value,
          cacheCover: controller.cacheCover.value,
          coverPositionPadding: controller.coverPositionPadding.value,
          // ===== 内容布局 =====
          avatarSize: controller.avatarSize.value,
          denseAvatarSize: controller.avatarSize.value * 0.8,
          showAvatar: controller.showAvatar.value,
          contentHorizontalPadding: controller.horizontalPadding.value,
          denseContentHorizontalPadding: controller.horizontalPadding.value * 0.8,
          contentVerticalPadding: controller.verticalPadding.value,
          denseContentVerticalPadding: controller.verticalPadding.value * 0.7,
          horizontalTitleGap: controller.horizontalTitleGap.value,
          denseHorizontalTitleGap: controller.horizontalTitleGap.value * 0.7,
          showSubtitle: controller.showSubtitle.value,
          denseMode: controller.denseMode.value || dense,
          // ===== 文字排版 =====
          titleFontSize: controller.titleFontSize.value,
          denseTitleFontSize: controller.titleFontSize.value * 0.85,
          titleFontWeight: controller.titleFontWeight,
          titleLineHeight: controller.titleLineHeight.value,
          titleColor: isDark ? controller.darkTitleColorValue : controller.lightTitleColorValue,
          subtitleFontSize: controller.subtitleFontSize.value,
          denseSubtitleFontSize: controller.subtitleFontSize.value * 0.85,
          subtitleFontWeight: controller.subtitleFontWeight,
          subtitleLineHeight: controller.subtitleLineHeight.value,
          subtitleColor: isDark ? controller.darkSubtitleColorValue : controller.lightSubtitleColorValue,
          // ===== 平台标签 =====
          showPlatform: controller.showPlatform.value,
          platformFontSize: controller.platformFontSize.value,
          densePlatformFontSize: controller.platformFontSize.value * 0.9,
          platformFontWeight: controller.platformFontWeight,
          platformBackgroundColor: isDark
              ? controller.platformBackgroundDarkValue
              : controller.platformBackgroundLightValue,
          platformTextColor: isDark ? controller.platformTextDarkValue : controller.platformTextLightValue,
          platformBorderRadius: controller.platformBorderRadius.value,
          platformHorizontalPadding: controller.platformHorizontalPadding.value,
          platformVerticalPadding: controller.platformVerticalPadding.value,
          // ===== 徽章设置 =====
          showLiveBadge: controller.showLiveBadge.value,
          showRecordBadge: controller.showRecordBadge.value,
          showAudience: controller.showAudience.value,
          chipFontSize: controller.chipFontSize.value,
          denseChipFontSize: controller.chipFontSize.value * 0.85,
          chipFontWeight: controller.chipFontWeight,
          chipBorderRadius: controller.chipBorderRadius.value,
          chipHorizontalPadding: controller.chipHorizontalPadding.value,
          denseChipHorizontalPadding: controller.chipHorizontalPadding.value * 0.8,
          chipVerticalPadding: controller.chipVerticalPadding.value,
          denseChipVerticalPadding: controller.chipVerticalPadding.value * 0.7,
          chipBackgroundColor: controller.chipBackgroundColorValue,
          chipTextColor: controller.chipTextColorValue,
          // ===== 观众指标 =====
          metricFontSize: controller.metricFontSize.value,
          denseMetricFontSize: controller.metricFontSize.value * 0.85,
          metricFontWeight: controller.metricFontWeight,
          metricBorderRadius: controller.badgeRadius.value,
          denseMetricBorderRadius: controller.badgeRadius.value * 0.8,
          badgeOpacity: controller.badgeOpacity.value,
          metricBackgroundColor: controller.badgeBackgroundValue,
          metricTextColor: controller.badgeForegroundValue,
          metricBorderColor: controller.metricBorderColorValue,
          metricBorderWidth: controller.metricBorderWidth.value,
          metricHorizontalPadding: controller.metricHorizontalPadding.value,
          denseMetricHorizontalPadding: controller.metricHorizontalPadding.value * 0.8,
          metricVerticalPadding: controller.metricVerticalPadding.value,
          denseMetricVerticalPadding: controller.metricVerticalPadding.value * 0.7,
          // ===== 删除按钮 =====
          showDelete: controller.showDelete.value && showDelete,
          deleteButtonBackgroundColor: controller.deleteButtonBackgroundColorValue,
          deleteButtonPadding: controller.deleteButtonPadding.value,
          deleteButtonSize: controller.deleteButtonSize.value,
          denseDeleteButtonSize: controller.deleteButtonSize.value * 0.85,
          deleteButtonIconColor: controller.deleteButtonIconColorValue,
          deleteButtonBorderRadius: controller.deleteButtonBorderRadius.value,
          showAsListTile: controller.showAsListTile.value,
        );
      }

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
