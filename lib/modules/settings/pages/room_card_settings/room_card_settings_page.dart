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
    return Scaffold(
      appBar: AppBar(title: Text(i18n('room_card_settings'))),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth >= 680;

          if (isLargeScreen) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _buildSettingsList(context)),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(flex: 2, child: _buildPreview(context, compact: false)),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 260, child: _buildPreview(context, compact: true)),
              const Divider(height: 1),
              Expanded(child: _buildSettingsList(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPreview(BuildContext context, {bool compact = false}) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(left: compact ? BorderSide.none : BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i18n('preview'), style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w700)),
          if (!compact) ...[
            Text(i18n('preview_subtitle'), style: AppTextStyles.t12.copyWith(color: theme.colorScheme.outline)),
          ],
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 280 : 360, maxHeight: compact ? 220 : double.infinity),
                child: GetBuilder<RoomCardConfigController>(builder: (_) => _buildPreviewCard(context)),
              ),
            ),
          ),
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
            _buildResetSection(context),
          ],
          const SizedBox(height: 32),
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
          showAsListTile: controller.showAsListTile.value,
        );
      }

      return RoomCardPage(
        room: room,
        config: config,
        dense: controller.denseMode.value,
        debug: true,
        key: ValueKey('preview_${DateTime.now().millisecondsSinceEpoch}'),
      );
    });
  }

  Widget _buildPresetSection(BuildContext context) {
    return _section(context, i18n('preset_style'), [
      _tile(
        context,
        icon: Remix.layout_masonry_line,
        title: i18n('preset_style'),
        subtitle: i18n('preset_style_subtitle'),
        trailing: _arrowValue(context, controller.presetValue.label),
        onTap: () => _showPresetDialog(context),
      ),
    ]);
  }

  Widget _buildCardStyleSection(BuildContext context) {
    return _section(context, i18n('card_style'), [
      _switchTile(
        context,
        icon: Remix.list_settings_line,
        title: i18n('show_as_list_tile'),
        subtitle: i18n('show_as_list_tile_subtitle'),
        value: controller.showAsListTile,
      ),
      _sliderTile(
        context,
        icon: Remix.rounded_corner,
        title: i18n('card_radius'),
        value: controller.cardRadius.value,
        min: 0,
        max: 40,
        displayValue: '${controller.cardRadius.value.round()} px',
        onChanged: (value) {
          controller.cardRadius.value = value;
        },
      ),
      _sliderTile(
        context,
        icon: Remix.shadow_line,
        title: i18n('card_elevation'),
        value: controller.cardElevation.value,
        min: 0,
        max: 12,
        displayValue: controller.cardElevation.value.toStringAsFixed(1),
        onChanged: (value) {
          controller.cardElevation.value = value;
        },
      ),
      _switchTile(
        context,
        icon: Remix.contrast_2_line,
        title: i18n('enable_shadow'),
        subtitle: i18n('enable_shadow_subtitle'),
        value: controller.enableShadow,
      ),
      _colorTile(
        context,
        icon: Remix.paint_brush_line,
        title: i18n('card_background_light'),
        color: () => controller.lightCardColorValue,
        onColorSelected: (color) {
          controller.lightCardColor.value = color.hex;
        },
      ),
      _colorTile(
        context,
        icon: Remix.moon_line,
        title: i18n('card_background_dark'),
        color: () => controller.darkCardColorValue,
        onColorSelected: (color) {
          controller.darkCardColor.value = color.hex;
        },
      ),
    ]);
  }

  Widget _buildCoverSection(BuildContext context) {
    return _section(context, i18n('cover_settings'), [
      _sliderTile(
        context,
        icon: Remix.crop_2_line,
        title: i18n('cover_radius'),
        value: controller.coverRadius.value,
        min: 0,
        max: 40,
        displayValue: '${controller.coverRadius.value.round()} px',
        onChanged: (value) {
          controller.coverRadius.value = value;
        },
      ),
      _sliderTile(
        context,
        icon: Remix.aspect_ratio_line,
        title: i18n('cover_aspect_ratio'),
        value: controller.coverAspectRatio.value,
        min: 1.0,
        max: 2.5,
        step: 0.1,
        displayValue: controller.coverAspectRatio.value.toStringAsFixed(1),
        onChanged: (value) {
          controller.coverAspectRatio.value = value;
        },
      ),
      _sliderTile(
        context,
        icon: Remix.expand_left_right_line,
        title: i18n('cover_position_padding'),
        value: controller.coverPositionPadding.value,
        min: 0,
        max: 24,
        displayValue: '${controller.coverPositionPadding.value.round()} px',
        onChanged: (value) {
          controller.coverPositionPadding.value = value;
        },
      ),
      _switchTile(
        context,
        icon: Remix.database_2_line,
        title: i18n('cache_cover'),
        subtitle: i18n('cache_cover_subtitle'),
        value: controller.cacheCover,
      ),
      _tile(
        context,
        icon: Remix.image_2_line,
        title: i18n('cover_fit'),
        subtitle: _getBoxFitName(controller.coverFitIndex.value),
        trailing: _arrow(context),
        onTap: () => _showBoxFitDialog(
          context,
          currentIndex: controller.coverFitIndex.value,
          onSelected: (index) {
            controller.coverFitIndex.value = index;
          },
        ),
      ),
      _colorTile(
        context,
        icon: Remix.image_add_line,
        title: i18n('cover_placeholder_color'),
        color: () => controller.coverPlaceholderColorValue,
        onColorSelected: (color) {
          controller.coverPlaceholderColor.value = color.hex;
        },
      ),
      _colorTile(
        context,
        icon: Remix.image_edit_line,
        title: i18n('cover_fallback_color'),
        color: () => controller.coverFallbackColorValue,
        onColorSelected: (color) {
          controller.coverFallbackColor.value = color.hex;
        },
      ),
    ]);
  }

  Widget _buildContentSection(BuildContext context) {
    return _section(context, i18n('content_layout'), [
      _sliderTile(
        context,
        icon: Remix.expand_left_right_line,
        title: i18n('horizontal_padding'),
        value: controller.horizontalPadding.value,
        min: 0,
        max: 24,
        displayValue: '${controller.horizontalPadding.value.round()} px',
        onChanged: (value) {
          controller.horizontalPadding.value = value;
        },
      ),
      _sliderTile(
        context,
        icon: Remix.expand_up_down_line,
        title: i18n('vertical_padding'),
        value: controller.verticalPadding.value,
        min: 0,
        max: 16,
        displayValue: '${controller.verticalPadding.value.round()} px',
        onChanged: (value) {
          controller.verticalPadding.value = value;
        },
      ),
      _sliderTile(
        context,
        icon: Remix.space,
        title: i18n('title_gap'),
        value: controller.horizontalTitleGap.value,
        min: 0,
        max: 24,
        displayValue: '${controller.horizontalTitleGap.value.round()} px',
        onChanged: (value) {
          controller.horizontalTitleGap.value = value;
        },
      ),
      _switchTile(
        context,
        icon: Remix.user_smile_line,
        title: i18n('show_avatar'),
        subtitle: i18n('show_avatar_subtitle'),
        value: controller.showAvatar,
      ),
      _sliderTile(
        context,
        icon: Remix.user_3_line,
        title: i18n('avatar_size'),
        value: controller.avatarSize.value,
        min: 20,
        max: 64,
        displayValue: '${controller.avatarSize.value.round()} px',
        onChanged: (value) {
          controller.avatarSize.value = value;
        },
      ),
      _switchTile(
        context,
        icon: Remix.text,
        title: i18n('show_subtitle'),
        subtitle: i18n('show_subtitle_subtitle'),
        value: controller.showSubtitle,
      ),
      _switchTile(
        context,
        icon: Remix.layout_grid_2_line,
        title: i18n('dense_mode'),
        subtitle: i18n('dense_mode_subtitle'),
        value: controller.denseMode,
      ),
    ]);
  }

  Widget _buildTypographySection(BuildContext context) {
    return _section(context, i18n('typography'), [
      _sliderTile(
        context,
        icon: Remix.font_size,
        title: i18n('title_font_size'),
        value: controller.titleFontSize.value,
        min: 10,
        max: 24,
        displayValue: '${controller.titleFontSize.value.round()} px',
        onChanged: (value) {
          controller.titleFontSize.value = value;
        },
      ),
      _fontWeightTile(
        context,
        title: i18n('title_font_weight'),
        currentIndex: controller.titleFontWeightIndex.value,
        onSelected: (index) {
          controller.titleFontWeightIndex.value = index;
        },
      ),
      _sliderTile(
        context,
        icon: Remix.line_height,
        title: i18n('title_line_height'),
        value: controller.titleLineHeight.value,
        min: 0.8,
        max: 2.0,
        step: 0.1,
        displayValue: controller.titleLineHeight.value.toStringAsFixed(1),
        onChanged: (value) {
          controller.titleLineHeight.value = value;
        },
      ),
      _colorTile(
        context,
        icon: Remix.palette_line,
        title: i18n('title_color_light'),
        color: () => controller.lightTitleColorValue,
        onColorSelected: (color) {
          controller.lightTitleColor.value = color.hex;
        },
      ),
      _colorTile(
        context,
        icon: Remix.palette_line,
        title: i18n('title_color_dark'),
        color: () => controller.darkTitleColorValue,
        onColorSelected: (color) {
          controller.darkTitleColor.value = color.hex;
        },
      ),
      const Divider(height: 1),
      _sliderTile(
        context,
        icon: Remix.font_size,
        title: i18n('subtitle_font_size'),
        value: controller.subtitleFontSize.value,
        min: 8,
        max: 20,
        displayValue: '${controller.subtitleFontSize.value.round()} px',
        onChanged: (value) {
          controller.subtitleFontSize.value = value;
        },
      ),
      _fontWeightTile(
        context,
        title: i18n('subtitle_font_weight'),
        currentIndex: controller.subtitleFontWeightIndex.value,
        onSelected: (index) {
          controller.subtitleFontWeightIndex.value = index;
        },
      ),
      _sliderTile(
        context,
        icon: Remix.line_height,
        title: i18n('subtitle_line_height'),
        value: controller.subtitleLineHeight.value,
        min: 0.8,
        max: 2.0,
        step: 0.1,
        displayValue: controller.subtitleLineHeight.value.toStringAsFixed(1),
        onChanged: (value) {
          controller.subtitleLineHeight.value = value;
        },
      ),
      _colorTile(
        context,
        icon: Remix.palette_line,
        title: i18n('subtitle_color_light'),
        color: () => controller.lightSubtitleColorValue,
        onColorSelected: (color) {
          controller.lightSubtitleColor.value = color.hex;
        },
      ),
      _colorTile(
        context,
        icon: Remix.palette_line,
        title: i18n('subtitle_color_dark'),
        color: () => controller.darkSubtitleColorValue,
        onColorSelected: (color) {
          controller.darkSubtitleColor.value = color.hex;
        },
      ),
    ]);
  }

  Widget _buildPlatformSection(BuildContext context) {
    return _section(context, i18n('platform_tag'), [
      _switchTile(
        context,
        icon: Remix.global_line,
        title: i18n('show_platform'),
        subtitle: i18n('show_platform_subtitle'),
        value: controller.showPlatform,
      ),
      _sliderTile(
        context,
        icon: Remix.font_size,
        title: i18n('platform_font_size'),
        value: controller.platformFontSize.value,
        min: 8,
        max: 16,
        displayValue: '${controller.platformFontSize.value.round()} px',
        onChanged: (value) {
          controller.platformFontSize.value = value;
        },
      ),
      _fontWeightTile(
        context,
        title: i18n('platform_font_weight'),
        currentIndex: controller.platformFontWeightIndex.value,
        onSelected: (index) {
          controller.platformFontWeightIndex.value = index;
        },
      ),
      _sliderTile(
        context,
        icon: Remix.shape_line,
        title: i18n('platform_border_radius'),
        value: controller.platformBorderRadius.value,
        min: 0,
        max: 20,
        displayValue: '${controller.platformBorderRadius.value.round()} px',
        onChanged: (value) {
          controller.platformBorderRadius.value = value;
        },
      ),
      _colorTile(
        context,
        icon: Remix.paint_brush_line,
        title: i18n('platform_background_light'),
        color: () => controller.platformBackgroundLightValue,
        onColorSelected: (color) {
          controller.platformBackgroundLight.value = color.hex;
        },
      ),
      _colorTile(
        context,
        icon: Remix.moon_clear_line,
        title: i18n('platform_background_dark'),
        color: () => controller.platformBackgroundDarkValue,
        onColorSelected: (color) {
          controller.platformBackgroundDark.value = color.hex;
        },
      ),
      _colorTile(
        context,
        icon: Remix.font_color,
        title: i18n('platform_text_light'),
        color: () => controller.platformTextLightValue,
        onColorSelected: (color) {
          controller.platformTextLight.value = color.hex;
        },
      ),
      _colorTile(
        context,
        icon: Remix.font_color,
        title: i18n('platform_text_dark'),
        color: () => controller.platformTextDarkValue,
        onColorSelected: (color) {
          controller.platformTextDark.value = color.hex;
        },
      ),
    ]);
  }

  Widget _buildBadgeSection(BuildContext context) {
    return _section(context, i18n('badge_settings'), [
      _switchTile(
        context,
        icon: Remix.live_line,
        title: i18n('show_live_badge'),
        subtitle: i18n('show_live_badge_subtitle'),
        value: controller.showLiveBadge,
      ),
      _switchTile(
        context,
        icon: Remix.record_circle_line,
        title: i18n('show_record_badge'),
        subtitle: i18n('show_record_badge_subtitle'),
        value: controller.showRecordBadge,
      ),
      _switchTile(
        context,
        icon: Remix.eye_line,
        title: i18n('show_audience'),
        subtitle: i18n('show_audience_subtitle'),
        value: controller.showAudience,
      ),
      _sliderTile(
        context,
        icon: Remix.font_size,
        title: i18n('chip_font_size'),
        value: controller.chipFontSize.value,
        min: 8,
        max: 18,
        displayValue: '${controller.chipFontSize.value.round()} px',
        onChanged: (value) {
          controller.chipFontSize.value = value;
        },
      ),
      _fontWeightTile(
        context,
        title: i18n('chip_font_weight'),
        currentIndex: controller.chipFontWeightIndex.value,
        onSelected: (index) {
          controller.chipFontWeightIndex.value = index;
        },
      ),
      _sliderTile(
        context,
        icon: Remix.shape_line,
        title: i18n('chip_border_radius'),
        value: controller.chipBorderRadius.value,
        min: 0,
        max: 30,
        displayValue: '${controller.chipBorderRadius.value.round()} px',
        onChanged: (value) {
          controller.chipBorderRadius.value = value;
        },
      ),
      _colorTile(
        context,
        icon: Remix.price_tag_3_line,
        title: i18n('chip_background'),
        color: () => controller.chipBackgroundColorValue,
        onColorSelected: (color) {
          controller.chipBackground.value = color.hex;
        },
      ),
      _colorTile(
        context,
        icon: Remix.font_color,
        title: i18n('chip_text'),
        color: () => controller.chipTextColorValue,
        onColorSelected: (color) {
          controller.chipText.value = color.hex;
        },
      ),
    ]);
  }

  Widget _buildMetricSection(BuildContext context) {
    return _section(context, i18n('metric_badge'), [
      _sliderTile(
        context,
        icon: Remix.font_size,
        title: i18n('metric_font_size'),
        value: controller.metricFontSize.value,
        min: 8,
        max: 16,
        displayValue: '${controller.metricFontSize.value.round()} px',
        onChanged: (value) {
          controller.metricFontSize.value = value;
        },
      ),
      _fontWeightTile(
        context,
        title: i18n('metric_font_weight'),
        currentIndex: controller.metricFontWeightIndex.value,
        onSelected: (index) {
          controller.metricFontWeightIndex.value = index;
        },
      ),
      _sliderTile(
        context,
        icon: Remix.shape_line,
        title: i18n('metric_border_radius'),
        value: controller.badgeRadius.value,
        min: 4,
        max: 24,
        displayValue: '${controller.badgeRadius.value.round()} px',
        onChanged: (value) {
          controller.badgeRadius.value = value;
        },
      ),
      _sliderTile(
        context,
        icon: Remix.eye_line,
        title: i18n('metric_opacity'),
        value: controller.badgeOpacity.value,
        min: 0.1,
        max: 1.0,
        step: 0.05,
        displayValue: controller.badgeOpacity.value.toStringAsFixed(2),
        onChanged: (value) {
          controller.badgeOpacity.value = value;
        },
      ),
      _colorTile(
        context,
        icon: Remix.paint_brush_line,
        title: i18n('metric_background'),
        color: () => controller.badgeBackgroundValue,
        onColorSelected: (color) {
          controller.badgeBackground.value = color.hex;
        },
      ),
      _colorTile(
        context,
        icon: Remix.font_color,
        title: i18n('metric_text'),
        color: () => controller.badgeForegroundValue,
        onColorSelected: (color) {
          controller.badgeForeground.value = color.hex;
        },
      ),
      _colorTile(
        context,
        icon: Remix.focus_line,
        title: i18n('metric_border_color'),
        color: () => controller.metricBorderColorValue,
        onColorSelected: (color) {
          controller.metricBorderColor.value = color.hex;
        },
      ),
      _sliderTile(
        context,
        icon: Remix.crop_line,
        title: i18n('metric_border_width'),
        value: controller.metricBorderWidth.value,
        min: 0,
        max: 3,
        step: 0.1,
        displayValue: controller.metricBorderWidth.value.toStringAsFixed(1),
        onChanged: (value) {
          controller.metricBorderWidth.value = value;
        },
      ),
      _sliderTile(
        context,
        icon: Remix.expand_left_right_line,
        title: i18n('metric_horizontal_padding'),
        value: controller.metricHorizontalPadding.value,
        min: 2,
        max: 16,
        displayValue: '${controller.metricHorizontalPadding.value.round()} px',
        onChanged: (value) {
          controller.metricHorizontalPadding.value = value;
        },
      ),
      _sliderTile(
        context,
        icon: Remix.expand_up_down_line,
        title: i18n('metric_vertical_padding'),
        value: controller.metricVerticalPadding.value,
        min: 1,
        max: 12,
        displayValue: '${controller.metricVerticalPadding.value.round()} px',
        onChanged: (value) {
          controller.metricVerticalPadding.value = value;
        },
      ),
    ]);
  }

  Widget _buildResetSection(BuildContext context) {
    return _section(context, i18n('reset'), [
      _tile(
        context,
        icon: Remix.restart_line,
        title: i18n('reset_all_settings'),
        subtitle: i18n('reset_all_settings_subtitle'),
        trailing: _arrow(context),
        onTap: () => _showResetDialog(context),
      ),
    ]);
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [context.buildGroupTitle(title), context.buildModernCard(children)],
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GetBuilder<RoomCardConfigController>(
      builder: (_) => context.buildTile(icon: icon, title: title, subtitle: subtitle, trailing: trailing, onTap: onTap),
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required RxBool value,
  }) {
    return context.buildSwitchTile(icon: icon, title: title, subtitle: subtitle, value: value);
  }

  Widget _sliderTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    double? step,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return GetBuilder<RoomCardConfigController>(
      builder: (_) => context.buildSliderTile(
        context,
        icon: icon,
        title: title,
        value: value,
        min: min,
        max: max,
        step: step,
        displayValue: displayValue,
        onChanged: (value) {
          controller.switchToCustom();
          onChanged(value);
          controller.update();
        },
      ),
    );
  }

  Widget _colorTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color Function() color,
    required ValueChanged<Color> onColorSelected,
  }) {
    return GetBuilder<RoomCardConfigController>(
      builder: (_) => context.buildTile(
        icon: icon,
        title: title,
        trailing: ColorIndicator(width: 28, height: 28, borderRadius: 6, color: color(), onSelectFocus: false),
        onTap: () => _showColorPickerDialog(
          context,
          title: title,
          currentColor: color(),
          onColorSelected: (newColor) {
            controller.switchToCustom();
            onColorSelected(newColor);
            controller.update();
          },
        ),
      ),
    );
  }

  Widget _fontWeightTile(
    BuildContext context, {
    required String title,
    required int currentIndex,
    required ValueChanged<int> onSelected,
  }) {
    return _tile(
      context,
      icon: Remix.bold,
      title: title,
      subtitle: _getFontWeightName(currentIndex),
      trailing: _arrow(context),
      onTap: () => _showFontWeightDialog(
        context,
        title: title,
        currentIndex: currentIndex,
        onSelected: (index) {
          controller.switchToCustom();
          onSelected(index);
          controller.update();
        },
      ),
    );
  }

  Widget _arrow(BuildContext context) {
    return Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.outline);
  }

  Widget _arrowValue(BuildContext context, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppTextStyles.t13.copyWith(color: Theme.of(context).colorScheme.outline)),
        const SizedBox(width: 2),
        _arrow(context),
      ],
    );
  }

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
    const names = ['100', '200', '300', '400', '500', '600', '700', '800', '900'];

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
                children: names.asMap().entries.map((entry) {
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

    if (index < 0 || index >= names.length) {
      return '400';
    }

    return names[index];
  }

  String _getFontWeightDisplay(int index) {
    const displays = ['Thin', 'ExtraLight', 'Light', 'Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black'];

    if (index < 0 || index >= displays.length) {
      return 'Regular';
    }

    return displays[index];
  }

  String _getBoxFitName(int index) {
    const names = ['fill', 'contain', 'cover', 'fitWidth', 'fitHeight', 'none', 'scaleDown'];

    if (index < 0 || index >= names.length) {
      return 'cover';
    }

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
