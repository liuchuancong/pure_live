import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_page.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_model.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_config_controller.dart';

class RoomCardSettingsPage extends GetView<RoomCardConfigController> {
  const RoomCardSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = Get.width > 680;

    return Scaffold(
      appBar: AppBar(title: Text(i18n('room_card_settings'))),
      body: Row(
        children: [
          Expanded(flex: isLargeScreen ? 3 : 1, child: _buildSettingsList(context)),
          if (isLargeScreen) Expanded(flex: 2, child: _buildPreview(context)),
        ],
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return Obx(
      () => ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildPresetSection(context),
          const SizedBox(height: 20),
          if (controller.isCustomMode) ...[
            _buildCardStyleSection(context),
            const SizedBox(height: 20),
            _buildCoverSection(context),
            const SizedBox(height: 20),
            _buildContentSection(context),
            const SizedBox(height: 20),
            _buildTypographySection(context),
            const SizedBox(height: 20),
            _buildPlatformSection(context),
            const SizedBox(height: 20),
            _buildBadgeSection(context),
            const SizedBox(height: 20),
            _buildMetricSection(context),
            const SizedBox(height: 20),
            _buildDeleteSection(context),
            const SizedBox(height: 20),
            _buildResetSection(context),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i18n('preview'), style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            i18n('preview_subtitle'),
            style: AppTextStyles.t12.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 360,
                child: GetBuilder<RoomCardConfigController>(builder: (_) => _buildPreviewCard(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final room = LiveRoom(
        roomId: '100001',
        userId: '10001',
        platform: 'bilibili',
        title: '深夜直播｜今天来聊点有意思的',
        nick: '小明同学',
        avatar: 'assets/images/avatar.jpg',
        area: '生活',
        watching: '128.6万',
        popularity: '128.6万',
        onlineViewers: '',
        totalViewers: '5200000',
        followers: '86.5万',
        audienceMetricType: AudienceMetricType.popularity,
        liveStatus: LiveStatus.live,
        status: true,
        isRecord: false,
        introduction: '欢迎来到直播间，今天一起聊天。',
        notice: '晚上 8 点准时开始',
        tagIds: ['推荐', '聊天', '热门'],
        cover: 'assets/images/banner.png',
      );

      final config = RoomCardModel(
        // ===== 卡片样式 =====
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
        denseMode: controller.denseMode.value,

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
        showDelete: controller.showDelete.value,
        deleteButtonBackgroundColor: controller.deleteButtonBackgroundColorValue,
        deleteButtonPadding: controller.deleteButtonPadding.value,
        deleteButtonSize: controller.deleteButtonSize.value,
        denseDeleteButtonSize: controller.deleteButtonSize.value * 0.85,
        deleteButtonIconColor: controller.deleteButtonIconColorValue,
        deleteButtonBorderRadius: controller.deleteButtonBorderRadius.value,

        // ===== 显示选项 =====
        showAsListTile: controller.showAsListTile.value,
      );

      return RoomCardPage(
        room: room,
        config: config,
        dense: controller.denseMode.value,
        debug: true,
        key: ValueKey('preview_${DateTime.now().millisecondsSinceEpoch}'),
      );
    });
  }

  // ============================================================
  // 1. 预设选择
  // ============================================================
  Widget _buildPresetSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        context.buildGroupTitle(i18n('preset_style')),
        context.buildModernCard([
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.layout_line,
              title: i18n('preset_style'),
              subtitle: i18n('preset_style_subtitle'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    controller.presetValue.label,
                    style: AppTextStyles.t13.copyWith(color: Theme.of(context).colorScheme.outline),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
              onTap: () => _showPresetDialog(context),
            ),
          ),
        ]),
      ],
    );
  }

  // ============================================================
  // 2. 卡片样式
  // ============================================================
  Widget _buildCardStyleSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        context.buildGroupTitle(i18n('card_style')),
        context.buildModernCard([
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSwitchTile(
              title: i18n('show_as_list_tile'),
              subtitle: i18n('show_as_list_tile_subtitle'),
              value: controller.showAsListTile,
              icon: Remix.list_settings_line,
              onChanged: (val) {
                controller.switchToCustom();
                controller.showAsListTile.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.rounded_corner,
              title: i18n('card_radius'),
              value: controller.cardRadius.v,
              min: 0,
              max: 40,
              displayValue: '${controller.cardRadius.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.cardRadius.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.shadow_line,
              title: i18n('card_elevation'),
              value: controller.cardElevation.v,
              min: 0,
              max: 12,
              displayValue: controller.cardElevation.v.toStringAsFixed(1),
              onChanged: (val) {
                controller.switchToCustom();
                controller.cardElevation.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSwitchTile(
              title: i18n('enable_shadow'),
              subtitle: i18n('enable_shadow_subtitle'),
              value: controller.enableShadow,
              icon: Remix.shadow_line,
              onChanged: (val) {
                controller.switchToCustom();
                controller.enableShadow.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('card_background_light'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('card_background_light'),
                currentColor: controller.lightCardColorValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.lightCardColor.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.lightCardColorValue,
                onSelectFocus: false,
              ),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('card_background_dark'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('card_background_dark'),
                currentColor: controller.darkCardColorValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.darkCardColor.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.darkCardColorValue,
                onSelectFocus: false,
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ============================================================
  // 3. 封面设置
  // ============================================================
  Widget _buildCoverSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        context.buildGroupTitle(i18n('cover_settings')),
        context.buildModernCard([
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.rounded_corner,
              title: i18n('cover_radius'),
              value: controller.coverRadius.v,
              min: 0,
              max: 40,
              displayValue: '${controller.coverRadius.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.coverRadius.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.aspect_ratio_line,
              title: i18n('cover_aspect_ratio'),
              value: controller.coverAspectRatio.v,
              min: 1.0,
              max: 2.5,
              step: 0.1,
              displayValue: controller.coverAspectRatio.v.toStringAsFixed(1),
              onChanged: (val) {
                controller.switchToCustom();
                controller.coverAspectRatio.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.rounded_corner,
              title: i18n('cover_position_padding'),
              value: controller.coverPositionPadding.v,
              min: 0,
              max: 24,
              displayValue: '${controller.coverPositionPadding.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.coverPositionPadding.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSwitchTile(
              title: i18n('cache_cover'),
              subtitle: i18n('cache_cover_subtitle'),
              value: controller.cacheCover,
              icon: Remix.database_line,
              onChanged: (val) {
                controller.switchToCustom();
                controller.cacheCover.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.image_line,
              title: i18n('cover_fit'),
              subtitle: _getBoxFitName(controller.coverFitIndex.v),
              onTap: () => _showBoxFitDialog(
                context,
                currentIndex: controller.coverFitIndex.v,
                onSelected: (index) {
                  controller.switchToCustom();
                  controller.coverFitIndex.v = index;
                  controller.update();
                },
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.outline),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('cover_placeholder_color'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('cover_placeholder_color'),
                currentColor: controller.coverPlaceholderColorValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.coverPlaceholderColor.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.coverPlaceholderColorValue,
                onSelectFocus: false,
              ),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('cover_fallback_color'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('cover_fallback_color'),
                currentColor: controller.coverFallbackColorValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.coverFallbackColor.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.coverFallbackColorValue,
                onSelectFocus: false,
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ============================================================
  // 4. 内容布局
  // ============================================================
  Widget _buildContentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        context.buildGroupTitle(i18n('content_layout')),
        context.buildModernCard([
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.arrow_left_right_line,
              title: i18n('horizontal_padding'),
              value: controller.horizontalPadding.v,
              min: 0,
              max: 24,
              displayValue: '${controller.horizontalPadding.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.horizontalPadding.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.arrow_up_down_line,
              title: i18n('vertical_padding'),
              value: controller.verticalPadding.v,
              min: 0,
              max: 16,
              displayValue: '${controller.verticalPadding.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.verticalPadding.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.text_spacing,
              title: i18n('title_gap'),
              value: controller.horizontalTitleGap.v,
              min: 0,
              max: 24,
              displayValue: '${controller.horizontalTitleGap.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.horizontalTitleGap.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.user_line,
              title: i18n('avatar_size'),
              value: controller.avatarSize.v,
              min: 20,
              max: 64,
              displayValue: '${controller.avatarSize.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.avatarSize.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSwitchTile(
              title: i18n('show_avatar'),
              subtitle: i18n('show_avatar_subtitle'),
              value: controller.showAvatar,
              icon: Remix.user_line,
              onChanged: (val) {
                controller.switchToCustom();
                controller.showAvatar.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSwitchTile(
              title: i18n('show_subtitle'),
              subtitle: i18n('show_subtitle_subtitle'),
              value: controller.showSubtitle,
              icon: Remix.pencil_line,
              onChanged: (val) {
                controller.switchToCustom();
                controller.showSubtitle.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSwitchTile(
              title: i18n('dense_mode'),
              subtitle: i18n('dense_mode_subtitle'),
              value: controller.denseMode,
              icon: Remix.layout_grid_line,
              onChanged: (val) {
                controller.switchToCustom();
                controller.denseMode.v = val;
                controller.update();
              },
            ),
          ),
        ]),
      ],
    );
  }

  // ============================================================
  // 5. 文字排版
  // ============================================================
  Widget _buildTypographySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        context.buildGroupTitle(i18n('typography')),
        context.buildModernCard([
          // 标题
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.font_size,
              title: i18n('title_font_size'),
              value: controller.titleFontSize.v,
              min: 10,
              max: 24,
              displayValue: '${controller.titleFontSize.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.titleFontSize.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.font_size_2,
              title: i18n('title_font_weight'),
              subtitle: _getFontWeightName(controller.titleFontWeightIndex.v),
              onTap: () => _showFontWeightDialog(
                context,
                title: i18n('title_font_weight'),
                currentIndex: controller.titleFontWeightIndex.v,
                onSelected: (index) {
                  controller.switchToCustom();
                  controller.titleFontWeightIndex.v = index;
                  controller.update();
                },
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.outline),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.text_spacing,
              title: i18n('title_line_height'),
              value: controller.titleLineHeight.v,
              min: 0.8,
              max: 2.0,
              step: 0.1,
              displayValue: controller.titleLineHeight.v.toStringAsFixed(1),
              onChanged: (val) {
                controller.switchToCustom();
                controller.titleLineHeight.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('title_color_light'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('title_color_light'),
                currentColor: controller.lightTitleColorValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.lightTitleColor.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.lightTitleColorValue,
                onSelectFocus: false,
              ),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('title_color_dark'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('title_color_dark'),
                currentColor: controller.darkTitleColorValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.darkTitleColor.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.darkTitleColorValue,
                onSelectFocus: false,
              ),
            ),
          ),
          const Divider(height: 1),
          // 副标题
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.font_size,
              title: i18n('subtitle_font_size'),
              value: controller.subtitleFontSize.v,
              min: 8,
              max: 20,
              displayValue: '${controller.subtitleFontSize.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.subtitleFontSize.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.font_size_2,
              title: i18n('subtitle_font_weight'),
              subtitle: _getFontWeightName(controller.subtitleFontWeightIndex.v),
              onTap: () => _showFontWeightDialog(
                context,
                title: i18n('subtitle_font_weight'),
                currentIndex: controller.subtitleFontWeightIndex.v,
                onSelected: (index) {
                  controller.switchToCustom();
                  controller.subtitleFontWeightIndex.v = index;
                  controller.update();
                },
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.outline),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.text_spacing,
              title: i18n('subtitle_line_height'),
              value: controller.subtitleLineHeight.v,
              min: 0.8,
              max: 2.0,
              step: 0.1,
              displayValue: controller.subtitleLineHeight.v.toStringAsFixed(1),
              onChanged: (val) {
                controller.switchToCustom();
                controller.subtitleLineHeight.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('subtitle_color_light'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('subtitle_color_light'),
                currentColor: controller.lightSubtitleColorValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.lightSubtitleColor.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.lightSubtitleColorValue,
                onSelectFocus: false,
              ),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('subtitle_color_dark'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('subtitle_color_dark'),
                currentColor: controller.darkSubtitleColorValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.darkSubtitleColor.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.darkSubtitleColorValue,
                onSelectFocus: false,
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ============================================================
  // 6. 平台标签
  // ============================================================
  Widget _buildPlatformSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        context.buildGroupTitle(i18n('platform_tag')),
        context.buildModernCard([
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSwitchTile(
              title: i18n('show_platform'),
              subtitle: i18n('show_platform_subtitle'),
              value: controller.showPlatform,
              icon: Remix.global_line,
              onChanged: (val) {
                controller.switchToCustom();
                controller.showPlatform.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.font_size,
              title: i18n('platform_font_size'),
              value: controller.platformFontSize.v,
              min: 8,
              max: 16,
              displayValue: '${controller.platformFontSize.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.platformFontSize.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.font_size_2,
              title: i18n('platform_font_weight'),
              subtitle: _getFontWeightName(controller.platformFontWeightIndex.v),
              onTap: () => _showFontWeightDialog(
                context,
                title: i18n('platform_font_weight'),
                currentIndex: controller.platformFontWeightIndex.v,
                onSelected: (index) {
                  controller.switchToCustom();
                  controller.platformFontWeightIndex.v = index;
                  controller.update();
                },
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.outline),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.rounded_corner,
              title: i18n('platform_border_radius'),
              value: controller.platformBorderRadius.v,
              min: 0,
              max: 20,
              displayValue: '${controller.platformBorderRadius.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.platformBorderRadius.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('platform_background_light'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('platform_background_light'),
                currentColor: controller.platformBackgroundLightValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.platformBackgroundLight.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.platformBackgroundLightValue,
                onSelectFocus: false,
              ),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('platform_background_dark'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('platform_background_dark'),
                currentColor: controller.platformBackgroundDarkValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.platformBackgroundDark.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.platformBackgroundDarkValue,
                onSelectFocus: false,
              ),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('platform_text_light'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('platform_text_light'),
                currentColor: controller.platformTextLightValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.platformTextLight.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.platformTextLightValue,
                onSelectFocus: false,
              ),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('platform_text_dark'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('platform_text_dark'),
                currentColor: controller.platformTextDarkValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.platformTextDark.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.platformTextDarkValue,
                onSelectFocus: false,
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ============================================================
  // 7. 徽章设置
  // ============================================================
  Widget _buildBadgeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        context.buildGroupTitle(i18n('badge_settings')),
        context.buildModernCard([
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSwitchTile(
              title: i18n('show_live_badge'),
              subtitle: i18n('show_live_badge_subtitle'),
              value: controller.showLiveBadge,
              icon: Remix.live_line,
              onChanged: (val) {
                controller.switchToCustom();
                controller.showLiveBadge.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSwitchTile(
              title: i18n('show_record_badge'),
              subtitle: i18n('show_record_badge_subtitle'),
              value: controller.showRecordBadge,
              icon: Remix.vidicon_line,
              onChanged: (val) {
                controller.switchToCustom();
                controller.showRecordBadge.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSwitchTile(
              title: i18n('show_audience'),
              subtitle: i18n('show_audience_subtitle'),
              value: controller.showAudience,
              icon: Remix.eye_line,
              onChanged: (val) {
                controller.switchToCustom();
                controller.showAudience.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.font_size,
              title: i18n('chip_font_size'),
              value: controller.chipFontSize.v,
              min: 8,
              max: 18,
              displayValue: '${controller.chipFontSize.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.chipFontSize.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.font_size_2,
              title: i18n('chip_font_weight'),
              subtitle: _getFontWeightName(controller.chipFontWeightIndex.v),
              onTap: () => _showFontWeightDialog(
                context,
                title: i18n('chip_font_weight'),
                currentIndex: controller.chipFontWeightIndex.v,
                onSelected: (index) {
                  controller.switchToCustom();
                  controller.chipFontWeightIndex.v = index;
                  controller.update();
                },
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.outline),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.rounded_corner,
              title: i18n('chip_border_radius'),
              value: controller.chipBorderRadius.v,
              min: 0,
              max: 30,
              displayValue: '${controller.chipBorderRadius.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.chipBorderRadius.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('chip_background'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('chip_background'),
                currentColor: controller.chipBackgroundColorValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.chipBackground.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.chipBackgroundColorValue,
                onSelectFocus: false,
              ),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('chip_text'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('chip_text'),
                currentColor: controller.chipTextColorValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.chipText.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.chipTextColorValue,
                onSelectFocus: false,
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ============================================================
  // 8. 观众指标
  // ============================================================
  Widget _buildMetricSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        context.buildGroupTitle(i18n('metric_badge')),
        context.buildModernCard([
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.font_size,
              title: i18n('metric_font_size'),
              value: controller.metricFontSize.v,
              min: 8,
              max: 16,
              displayValue: '${controller.metricFontSize.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.metricFontSize.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.font_size_2,
              title: i18n('metric_font_weight'),
              subtitle: _getFontWeightName(controller.metricFontWeightIndex.v),
              onTap: () => _showFontWeightDialog(
                context,
                title: i18n('metric_font_weight'),
                currentIndex: controller.metricFontWeightIndex.v,
                onSelected: (index) {
                  controller.switchToCustom();
                  controller.metricFontWeightIndex.v = index;
                  controller.update();
                },
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.outline),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.rounded_corner,
              title: i18n('metric_border_radius'),
              value: controller.badgeRadius.v,
              min: 4,
              max: 24,
              displayValue: '${controller.badgeRadius.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.badgeRadius.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.contrast_2_line,
              title: i18n('metric_opacity'),
              value: controller.badgeOpacity.v,
              min: 0.1,
              max: 1.0,
              step: 0.05,
              displayValue: controller.badgeOpacity.v.toStringAsFixed(2),
              onChanged: (val) {
                controller.switchToCustom();
                controller.badgeOpacity.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('metric_background'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('metric_background'),
                currentColor: controller.badgeBackgroundValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.badgeBackground.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.badgeBackgroundValue,
                onSelectFocus: false,
              ),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('metric_text'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('metric_text'),
                currentColor: controller.badgeForegroundValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.badgeForeground.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.badgeForegroundValue,
                onSelectFocus: false,
              ),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('metric_border_color'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('metric_border_color'),
                currentColor: controller.metricBorderColorValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.metricBorderColor.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.metricBorderColorValue,
                onSelectFocus: false,
              ),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.drag_move_line,
              title: i18n('metric_border_width'),
              value: controller.metricBorderWidth.v,
              min: 0,
              max: 3,
              step: 0.1,
              displayValue: controller.metricBorderWidth.v.toStringAsFixed(1),
              onChanged: (val) {
                controller.switchToCustom();
                controller.metricBorderWidth.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.arrow_left_right_line,
              title: i18n('metric_horizontal_padding'),
              value: controller.metricHorizontalPadding.v,
              min: 2,
              max: 16,
              displayValue: '${controller.metricHorizontalPadding.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.metricHorizontalPadding.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.arrow_up_down_line,
              title: i18n('metric_vertical_padding'),
              value: controller.metricVerticalPadding.v,
              min: 1,
              max: 12,
              displayValue: '${controller.metricVerticalPadding.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.metricVerticalPadding.v = val;
                controller.update();
              },
            ),
          ),
        ]),
      ],
    );
  }

  // ============================================================
  // 9. 删除按钮
  // ============================================================
  Widget _buildDeleteSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        context.buildGroupTitle(i18n('delete_button')),
        context.buildModernCard([
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSwitchTile(
              title: i18n('show_delete'),
              subtitle: i18n('show_delete_subtitle'),
              value: controller.showDelete,
              icon: Remix.delete_bin_line,
              onChanged: (val) {
                controller.switchToCustom();
                controller.showDelete.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.rounded_corner,
              title: i18n('delete_button_radius'),
              value: controller.deleteButtonBorderRadius.v,
              min: 0,
              max: 999,
              displayValue: controller.deleteButtonBorderRadius.v >= 999
                  ? '∞'
                  : '${controller.deleteButtonBorderRadius.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.deleteButtonBorderRadius.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.arrow_left_right_line,
              title: i18n('delete_button_size'),
              value: controller.deleteButtonSize.v,
              min: 12,
              max: 32,
              displayValue: '${controller.deleteButtonSize.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.deleteButtonSize.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildSliderTile(
              context,
              icon: Remix.arrow_up_down_line,
              title: i18n('delete_button_padding'),
              value: controller.deleteButtonPadding.v,
              min: 2,
              max: 16,
              displayValue: '${controller.deleteButtonPadding.v.round()} px',
              onChanged: (val) {
                controller.switchToCustom();
                controller.deleteButtonPadding.v = val;
                controller.update();
              },
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('delete_button_background'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('delete_button_background'),
                currentColor: controller.deleteButtonBackgroundColorValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.deleteButtonBackground.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.deleteButtonBackgroundColorValue,
                onSelectFocus: false,
              ),
            ),
          ),
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.palette_line,
              title: i18n('delete_button_icon'),
              onTap: () => _showColorPickerDialog(
                context,
                title: i18n('delete_button_icon'),
                currentColor: controller.deleteButtonIconColorValue,
                onColorSelected: (color) {
                  controller.switchToCustom();
                  controller.deleteButtonIcon.v = color.hex;
                  controller.update();
                },
              ),
              trailing: ColorIndicator(
                width: 28,
                height: 28,
                borderRadius: 6,
                color: controller.deleteButtonIconColorValue,
                onSelectFocus: false,
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ============================================================
  // 10. 重置
  // ============================================================
  Widget _buildResetSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        context.buildGroupTitle(i18n('reset')),
        context.buildModernCard([
          GetBuilder<RoomCardConfigController>(
            builder: (_) => context.buildTile(
              icon: Remix.refresh_line,
              title: i18n('reset_all_settings'),
              subtitle: i18n('reset_all_settings_subtitle'),
              onTap: () => _showResetDialog(context),
              trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ]),
      ],
    );
  }

  // ============================================================
  // 对话框方法
  // ============================================================

  void _showPresetDialog(BuildContext context) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(i18n('preset_style')),
          content: GetBuilder<RoomCardConfigController>(
            builder: (_) {
              return RadioGroup<RoomCardPreset>(
                groupValue: controller.presetValue,
                onChanged: (value) {
                  if (value != null) {
                    controller.applyPreset(value);
                    Navigator.pop(context);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: RoomCardPreset.values.map((preset) {
                    return RadioListTile<RoomCardPreset>(
                      title: Text(preset.label),
                      subtitle: preset != RoomCardPreset.custom
                          ? Text(
                              _getPresetDescription(preset),
                              style: AppTextStyles.t12.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            )
                          : null,
                      value: preset,
                      selected: controller.presetValue == preset,
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n('close')))],
        );
      },
    );
  }

  String _getPresetDescription(RoomCardPreset preset) {
    switch (preset) {
      case RoomCardPreset.compact:
        return i18n('preset_compact_desc');
      case RoomCardPreset.normal:
        return i18n('preset_normal_desc');
      case RoomCardPreset.rich:
        return i18n('preset_rich_desc');
      case RoomCardPreset.custom:
        return '';
    }
  }

  void _showFontWeightDialog(
    BuildContext context, {
    required String title,
    required int currentIndex,
    required ValueChanged<int> onSelected,
  }) {
    final fontWeightNames = ['100', '200', '300', '400', '500', '600', '700', '800', '900'];

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title),
          content: SizedBox(
            width: 280,
            child: RadioGroup<int>(
              groupValue: currentIndex,
              onChanged: (value) {
                if (value != null) {
                  onSelected(value);
                  Navigator.pop(context);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: fontWeightNames.asMap().entries.map((entry) {
                  final index = entry.key;
                  final name = entry.value;

                  return RadioListTile<int>(
                    title: Text('$name (${_getFontWeightDisplay(index)})'),
                    value: index,
                    selected: index == currentIndex,
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n('close')))],
        );
      },
    );
  }

  String _getFontWeightName(int index) {
    const names = ['100', '200', '300', '400', '500', '600', '700', '800', '900'];
    if (index < 0 || index >= names.length) return '400';
    return names[index];
  }

  String _getFontWeightDisplay(int index) {
    const displays = ['Thin', 'ExtraLight', 'Light', 'Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black'];
    if (index < 0 || index >= displays.length) return 'Regular';
    return displays[index];
  }

  String _getBoxFitName(int index) {
    const names = ['fill', 'contain', 'cover', 'fitWidth', 'fitHeight', 'none', 'scaleDown'];
    if (index < 0 || index >= names.length) return 'cover';
    return names[index];
  }

  void _showBoxFitDialog(BuildContext context, {required int currentIndex, required ValueChanged<int> onSelected}) {
    const names = ['fill', 'contain', 'cover', 'fitWidth', 'fitHeight', 'none', 'scaleDown'];

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(i18n('cover_fit')),
          content: SizedBox(
            width: 280,
            child: RadioGroup<int>(
              groupValue: currentIndex,
              onChanged: (value) {
                if (value != null) {
                  onSelected(value);
                  Navigator.pop(context);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: names.asMap().entries.map((entry) {
                  final index = entry.key;
                  final name = entry.value;

                  return RadioListTile<int>(title: Text(name), value: index, selected: index == currentIndex);
                }).toList(),
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n('close')))],
        );
      },
    );
  }

  void _showColorPickerDialog(
    BuildContext context, {
    required String title,
    required Color currentColor,
    required ValueChanged<Color> onColorSelected,
  }) {
    final isZh = Get.locale?.languageCode == 'zh';

    ColorPicker(
      color: currentColor,
      onColorChanged: onColorSelected,
      width: 40,
      height: 40,
      borderRadius: 4,
      spacing: 5,
      runSpacing: 5,
      wheelDiameter: 155,
      heading: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subheading: Text(i18n('select_opacity'), style: Theme.of(context).textTheme.titleMedium),
      wheelSubheading: Text(i18n('theme_color_opacity'), style: Theme.of(context).textTheme.titleMedium),
      showMaterialName: false,
      showColorName: false,
      showColorCode: true,
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(longPressMenu: true),
      materialNameTextStyle: Theme.of(context).textTheme.bodySmall,
      colorNameTextStyle: Theme.of(context).textTheme.bodySmall,
      colorCodeTextStyle: Theme.of(context).textTheme.bodyMedium,
      colorCodePrefixStyle: Theme.of(context).textTheme.bodySmall,
      selectedPickerTypeColor: Theme.of(context).colorScheme.primary,
      pickerTypeLabels: <ColorPickerType, String>{
        ColorPickerType.primary: isZh ? '常用色' : 'Primary',
        ColorPickerType.accent: isZh ? '鲜艳色' : 'Accent',
        ColorPickerType.custom: isZh ? '自定义' : 'Custom',
        ColorPickerType.wheel: isZh ? '调色盘' : 'Wheel',
      },
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
        ColorPickerType.bw: false,
        ColorPickerType.custom: true,
        ColorPickerType.wheel: true,
      },
    ).showPickerDialog(
      context,
      actionsPadding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 480, minWidth: 375, maxWidth: 420),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(i18n('reset_all_settings')),
          content: Text(i18n('reset_all_settings_confirm')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n('cancel'))),
            FilledButton(
              onPressed: () {
                controller.reset();
                Navigator.pop(context);
                SmartDialog.showToast(i18n('reset_success'));
              },
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              child: Text(i18n('confirm')),
            ),
          ],
        );
      },
    );
  }
}
