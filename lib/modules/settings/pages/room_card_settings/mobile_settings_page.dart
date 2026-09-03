import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_page.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_model.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_config_controller.dart';

class MobileSettingsPage extends GetView<RoomCardConfigController> {
  const MobileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n('mobile_card_settings'))),
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

  // ========== Preview ==========
  Widget _buildPreview(BuildContext context, {bool compact = false}) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(
          left: compact
              ? BorderSide.none
              : BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(i18n('preview'), style: AppTextStyles.t16.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
            ],
          ),
          if (!compact) ...[
            Text(
              i18n('preview_subtitle'),
              style: AppTextStyles.t12.copyWith(color: theme.colorScheme.outline),
            ),
          ],
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: compact ? 280 : 360,
                  maxHeight: compact ? 220 : double.infinity,
                ),
                child: GetBuilder<RoomCardConfigController>(
                  builder: (_) => _buildPreviewCard(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
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

    return Obx(() {
      final config = controller.getMobileConfig();
      return RoomCardPage(
        room: room,
        config: config,
        dense: config.denseMode,
        debug: true,
        key: ValueKey('mobile_preview_${controller.mobilePreset.value}_${config.hashCode}'),
      );
    });
  }

  // ========== Settings List ==========
  Widget _buildSettingsList(BuildContext context) {
    return Obx(
      () => ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildPresetSection(context),
          const SizedBox(height: 20),
          if (controller.isMobileCustomMode) ...[
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
            _buildDeleteButtonSection(context),
            const SizedBox(height: 20),
            _buildResetSection(context),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ========== Preset Section ==========
  String _getPresetLabel(String presetKey) {
    switch (presetKey) {
      case 'compact':
        return i18n('preset_compact');
      case 'normal':
        return i18n('preset_normal');
      case 'rich':
        return i18n('preset_rich');
      case 'custom':
        return i18n('preset_custom');
      default:
        return i18n('preset_normal');
    }
  }

  // ========== Preset Section ==========
  Widget _buildPresetSection(BuildContext context) {
    return _section(context, i18n('preset_style'), [
      _tile(
        context,
        icon: Remix.layout_masonry_line,
        title: i18n('preset_style'),
        subtitle: _getPresetLabel(controller.desktopPreset.value),
        trailing: _arrowValue(context, _getPresetLabel(controller.desktopPreset.value)),
        onTap: () => _showPresetDialog(context, isMobile: true),
      ),
    ]);
  }

  // ========== Card Style Section ==========
  Widget _buildCardStyleSection(BuildContext context) {
    return _section(context, i18n('card_style'), [
      _switchTile(
        context,
        icon: Remix.list_settings_line,
        title: i18n('show_as_list_tile'),
        subtitle: i18n('show_as_list_tile_subtitle'),
        value: controller.mobileShowAsListTile,
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(showAsListTile: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.rounded_corner,
        title: i18n('card_radius'),
        value: controller.mobileCardRadius,
        min: 0,
        max: 40,
        displayValue: '${controller.mobileCardRadius.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(cardBorderRadius: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.shadow_line,
        title: i18n('card_elevation'),
        value: controller.mobileCardElevation,
        min: 0,
        max: 12,
        displayValue: controller.mobileCardElevation.toStringAsFixed(1),
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(cardElevation: v)),
      ),
      _switchTile(
        context,
        icon: Remix.contrast_2_line,
        title: i18n('enable_shadow'),
        subtitle: i18n('enable_shadow_subtitle'),
        value: controller.mobileEnableShadow,
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(enableShadow: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_left_right_line,
        title: i18n('card_margin'),
        value: controller.mobileCardMargin,
        min: 0,
        max: 24,
        displayValue: '${controller.mobileCardMargin.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(cardMargin: EdgeInsets.all(v))),
      ),
      _colorTile(
        context,
        icon: Remix.paint_brush_line,
        title: i18n('card_background_light'),
        color: () => controller.mobileLightCardColor,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(cardBackground: color)),
      ),
      _colorTile(
        context,
        icon: Remix.moon_line,
        title: i18n('card_background_dark'),
        color: () => controller.mobileDarkCardColor,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(cardBackground: color)),
      ),
    ]);
  }

  // ========== Cover Section ==========
  Widget _buildCoverSection(BuildContext context) {
    return _section(context, i18n('cover_settings'), [
      _sliderTile(
        context,
        icon: Remix.crop_2_line,
        title: i18n('cover_radius'),
        value: controller.mobileCoverRadius,
        min: 0,
        max: 40,
        displayValue: '${controller.mobileCoverRadius.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(coverBorderRadius: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.aspect_ratio_line,
        title: i18n('cover_aspect_ratio'),
        value: controller.mobileCoverAspectRatio,
        min: 1.0,
        max: 2.5,
        step: 0.1,
        displayValue: controller.mobileCoverAspectRatio.toStringAsFixed(1),
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(coverAspectRatio: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_left_right_line,
        title: i18n('cover_position_padding'),
        value: controller.mobileCoverPositionPadding,
        min: 0,
        max: 24,
        displayValue: '${controller.mobileCoverPositionPadding.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(coverPositionPadding: v)),
      ),
      _switchTile(
        context,
        icon: Remix.database_2_line,
        title: i18n('cache_cover'),
        subtitle: i18n('cache_cover_subtitle'),
        value: controller.mobileCacheCover,
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(cacheCover: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.image_edit_line,
        title: i18n('cover_cache_min_width'),
        value: controller.mobileCoverCacheMinWidth.toDouble(),
        min: 120,
        max: 480,
        step: 10,
        displayValue: '${controller.mobileCoverCacheMinWidth} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(coverCacheMinWidth: v.round())),
      ),
      _sliderTile(
        context,
        icon: Remix.image_edit_line,
        title: i18n('cover_cache_max_width'),
        value: controller.mobileCoverCacheMaxWidth.toDouble(),
        min: 360,
        max: 1200,
        step: 10,
        displayValue: '${controller.mobileCoverCacheMaxWidth} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(coverCacheMaxWidth: v.round())),
      ),
      _tile(
        context,
        icon: Remix.image_2_line,
        title: i18n('cover_fit'),
        subtitle: i18n(_getBoxFitName(controller.mobileCoverFit)),
        trailing: _arrow(context),
        onTap: () => _showBoxFitDialog(
          context,
          currentFit: controller.mobileCoverFit,
          onSelected: (fit) => controller.updateMobile((m) => m.copyWith(coverFit: fit)),
        ),
      ),
      _tile(
        context,
        icon: Remix.image_edit_line,
        title: i18n('cover_filter_quality'),
        subtitle: i18n(_getFilterQualityName(controller.desktopCoverFilterQuality)),
        trailing: _arrow(context),
        onTap: () => _showFilterQualityDialog(
          context,
          currentQuality: controller.mobileCoverFilterQuality,
          onSelected: (quality) =>
              controller.updateMobile((m) => m.copyWith(coverFilterQuality: quality)),
        ),
      ),
      _colorTile(
        context,
        icon: Remix.image_add_line,
        title: i18n('cover_placeholder_color'),
        color: () => controller.mobileCoverPlaceholderColor,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(coverPlaceholderColor: color)),
      ),
      _colorTile(
        context,
        icon: Remix.image_edit_line,
        title: i18n('cover_fallback_color'),
        color: () => controller.mobileCoverFallbackColor,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(coverFallbackColor: color)),
      ),
    ]);
  }

  // ========== Content Section ==========
  Widget _buildContentSection(BuildContext context) {
    return _section(context, i18n('content_layout'), [
      _switchTile(
        context,
        icon: Remix.layout_grid_2_line,
        title: i18n('dense_mode'),
        subtitle: i18n('dense_mode_subtitle'),
        value: controller.mobileDenseMode,
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(denseMode: v)),
      ),
      const Divider(height: 1),
      _sliderTile(
        context,
        icon: Remix.arrow_left_right_line,
        title: i18n('horizontal_padding'),
        value: controller.mobileHorizontalPadding,
        min: 0,
        max: 24,
        displayValue: '${controller.mobileHorizontalPadding.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(contentHorizontalPadding: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_up_down_line,
        title: i18n('vertical_padding'),
        value: controller.mobileVerticalPadding,
        min: 0,
        max: 16,
        displayValue: '${controller.mobileVerticalPadding.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(contentVerticalPadding: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.space,
        title: i18n('title_gap'),
        value: controller.mobileHorizontalTitleGap,
        min: 0,
        max: 24,
        displayValue: '${controller.mobileHorizontalTitleGap.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(horizontalTitleGap: v)),
      ),
      _switchTile(
        context,
        icon: Remix.user_smile_line,
        title: i18n('show_avatar'),
        subtitle: i18n('show_avatar_subtitle'),
        value: controller.mobileShowAvatar,
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(showAvatar: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.user_3_line,
        title: i18n('avatar_size'),
        value: controller.mobileAvatarSize,
        min: 20,
        max: 64,
        displayValue: '${controller.mobileAvatarSize.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(avatarSize: v)),
      ),
      const Divider(height: 1),
      Text(
        i18n('dense_mode_settings'),
        style: AppTextStyles.t13.copyWith(
          color: Theme.of(context).colorScheme.outline,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      _sliderTile(
        context,
        icon: Remix.user_3_line,
        title: i18n('dense_avatar_size'),
        value: controller.mobileDenseAvatarSize,
        min: 16,
        max: 52,
        displayValue: '${controller.mobileDenseAvatarSize.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(denseAvatarSize: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_left_right_line,
        title: i18n('dense_horizontal_padding'),
        value: controller.mobileDenseContentHorizontalPadding,
        min: 0,
        max: 20,
        displayValue: '${controller.mobileDenseContentHorizontalPadding.round()} px',
        onChanged: (v) =>
            controller.updateMobile((m) => m.copyWith(denseContentHorizontalPadding: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_up_down_line,
        title: i18n('dense_vertical_padding'),
        value: controller.mobileDenseContentVerticalPadding,
        min: 0,
        max: 12,
        displayValue: '${controller.mobileDenseContentVerticalPadding.round()} px',
        onChanged: (v) =>
            controller.updateMobile((m) => m.copyWith(denseContentVerticalPadding: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.space,
        title: i18n('dense_title_gap'),
        value: controller.mobileDenseHorizontalTitleGap,
        min: 0,
        max: 20,
        displayValue: '${controller.mobileDenseHorizontalTitleGap.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(denseHorizontalTitleGap: v)),
      ),
      _switchTile(
        context,
        icon: Remix.text,
        title: i18n('show_subtitle'),
        subtitle: i18n('show_subtitle_subtitle'),
        value: controller.mobileShowSubtitle,
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(showSubtitle: v)),
      ),
    ]);
  }

  // ========== Typography Section ==========
  Widget _buildTypographySection(BuildContext context) {
    return _section(context, i18n('typography'), [
      Text(
        i18n('title_typography'),
        style: AppTextStyles.t13.copyWith(
          color: Theme.of(context).colorScheme.outline,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      _sliderTile(
        context,
        icon: Remix.font_size,
        title: i18n('title_font_size'),
        value: controller.mobileTitleFontSize,
        min: 10,
        max: 24,
        displayValue: '${controller.mobileTitleFontSize.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(titleFontSize: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.font_size,
        title: i18n('dense_title_font_size'),
        value: controller.mobileDenseTitleFontSize,
        min: 8,
        max: 20,
        displayValue: '${controller.mobileDenseTitleFontSize.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(denseTitleFontSize: v)),
      ),
      _fontWeightTile(
        context,
        title: i18n('title_font_weight'),
        currentWeight: controller.mobileTitleFontWeight,
        onSelected: (weight) => controller.updateMobile((m) => m.copyWith(titleFontWeight: weight)),
      ),
      _sliderTile(
        context,
        icon: Remix.line_height,
        title: i18n('title_line_height'),
        value: controller.mobileTitleLineHeight,
        min: 0.8,
        max: 2.0,
        step: 0.1,
        displayValue: controller.mobileTitleLineHeight.toStringAsFixed(1),
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(titleLineHeight: v)),
      ),
      _colorTile(
        context,
        icon: Remix.palette_line,
        title: i18n('title_color_light'),
        color: () => controller.mobileLightTitleColor,
        onColorSelected: (color) => controller.updateMobile((m) => m.copyWith(titleColor: color)),
      ),
      _colorTile(
        context,
        icon: Remix.palette_line,
        title: i18n('title_color_dark'),
        color: () => controller.mobileDarkTitleColor,
        onColorSelected: (color) => controller.updateMobile((m) => m.copyWith(titleColor: color)),
      ),
      const Divider(height: 1),
      Text(
        i18n('subtitle_typography'),
        style: AppTextStyles.t13.copyWith(
          color: Theme.of(context).colorScheme.outline,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      _sliderTile(
        context,
        icon: Remix.font_size,
        title: i18n('subtitle_font_size'),
        value: controller.mobileSubtitleFontSize,
        min: 8,
        max: 20,
        displayValue: '${controller.mobileSubtitleFontSize.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(subtitleFontSize: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.font_size,
        title: i18n('dense_subtitle_font_size'),
        value: controller.mobileDenseSubtitleFontSize,
        min: 7,
        max: 17,
        displayValue: '${controller.mobileDenseSubtitleFontSize.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(denseSubtitleFontSize: v)),
      ),
      _fontWeightTile(
        context,
        title: i18n('subtitle_font_weight'),
        currentWeight: controller.mobileSubtitleFontWeight,
        onSelected: (weight) =>
            controller.updateMobile((m) => m.copyWith(subtitleFontWeight: weight)),
      ),
      _sliderTile(
        context,
        icon: Remix.line_height,
        title: i18n('subtitle_line_height'),
        value: controller.mobileSubtitleLineHeight,
        min: 0.8,
        max: 2.0,
        step: 0.1,
        displayValue: controller.mobileSubtitleLineHeight.toStringAsFixed(1),
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(subtitleLineHeight: v)),
      ),
      _colorTile(
        context,
        icon: Remix.palette_line,
        title: i18n('subtitle_color_light'),
        color: () => controller.mobileLightSubtitleColor,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(subtitleColor: color)),
      ),
      _colorTile(
        context,
        icon: Remix.palette_line,
        title: i18n('subtitle_color_dark'),
        color: () => controller.mobileDarkSubtitleColor,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(subtitleColor: color)),
      ),
    ]);
  }

  // ========== Platform Section ==========
  Widget _buildPlatformSection(BuildContext context) {
    return _section(context, i18n('platform_tag'), [
      _switchTile(
        context,
        icon: Remix.global_line,
        title: i18n('show_platform'),
        subtitle: i18n('show_platform_subtitle'),
        value: controller.mobileShowPlatform,
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(showPlatform: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.font_size,
        title: i18n('platform_font_size'),
        value: controller.mobilePlatformFontSize,
        min: 8,
        max: 16,
        displayValue: '${controller.mobilePlatformFontSize.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(platformFontSize: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.font_size,
        title: i18n('dense_platform_font_size'),
        value: controller.mobileDensePlatformFontSize,
        min: 6,
        max: 14,
        displayValue: '${controller.mobileDensePlatformFontSize.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(densePlatformFontSize: v)),
      ),
      _fontWeightTile(
        context,
        title: i18n('platform_font_weight'),
        currentWeight: controller.mobilePlatformFontWeight,
        onSelected: (weight) =>
            controller.updateMobile((m) => m.copyWith(platformFontWeight: weight)),
      ),
      _sliderTile(
        context,
        icon: Remix.shape_line,
        title: i18n('platform_border_radius'),
        value: controller.mobilePlatformBorderRadius,
        min: 0,
        max: 20,
        displayValue: '${controller.mobilePlatformBorderRadius.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(platformBorderRadius: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_left_right_line,
        title: i18n('platform_horizontal_padding'),
        value: controller.mobilePlatformHorizontalPadding,
        min: 0,
        max: 16,
        displayValue: '${controller.mobilePlatformHorizontalPadding.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(platformHorizontalPadding: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_up_down_line,
        title: i18n('platform_vertical_padding'),
        value: controller.mobilePlatformVerticalPadding,
        min: 0,
        max: 12,
        displayValue: '${controller.mobilePlatformVerticalPadding.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(platformVerticalPadding: v)),
      ),
      _colorTile(
        context,
        icon: Remix.paint_brush_line,
        title: i18n('platform_background_light'),
        color: () => controller.mobilePlatformBackgroundLight,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(platformBackgroundColor: color)),
      ),
      _colorTile(
        context,
        icon: Remix.moon_clear_line,
        title: i18n('platform_background_dark'),
        color: () => controller.mobilePlatformBackgroundDark,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(platformBackgroundColor: color)),
      ),
      _colorTile(
        context,
        icon: Remix.font_color,
        title: i18n('platform_text_light'),
        color: () => controller.mobilePlatformTextLight,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(platformTextColor: color)),
      ),
      _colorTile(
        context,
        icon: Remix.font_color,
        title: i18n('platform_text_dark'),
        color: () => controller.mobilePlatformTextDark,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(platformTextColor: color)),
      ),
    ]);
  }

  // ========== Badge Section ==========
  Widget _buildBadgeSection(BuildContext context) {
    return _section(context, i18n('badge_settings'), [
      _switchTile(
        context,
        icon: Remix.live_line,
        title: i18n('show_live_badge'),
        subtitle: i18n('show_live_badge_subtitle'),
        value: controller.mobileShowLiveBadge,
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(showLiveBadge: v)),
      ),
      _switchTile(
        context,
        icon: Remix.record_circle_line,
        title: i18n('show_record_badge'),
        subtitle: i18n('show_record_badge_subtitle'),
        value: controller.mobileShowRecordBadge,
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(showRecordBadge: v)),
      ),
      _switchTile(
        context,
        icon: Remix.eye_line,
        title: i18n('show_audience'),
        subtitle: i18n('show_audience_subtitle'),
        value: controller.mobileShowAudience,
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(showAudience: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.font_size,
        title: i18n('chip_font_size'),
        value: controller.mobileChipFontSize,
        min: 8,
        max: 18,
        displayValue: '${controller.mobileChipFontSize.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(chipFontSize: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.font_size,
        title: i18n('dense_chip_font_size'),
        value: controller.mobileDenseChipFontSize,
        min: 6,
        max: 15,
        displayValue: '${controller.mobileDenseChipFontSize.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(denseChipFontSize: v)),
      ),
      _fontWeightTile(
        context,
        title: i18n('chip_font_weight'),
        currentWeight: controller.mobileChipFontWeight,
        onSelected: (weight) => controller.updateMobile((m) => m.copyWith(chipFontWeight: weight)),
      ),
      _sliderTile(
        context,
        icon: Remix.shape_line,
        title: i18n('chip_border_radius'),
        value: controller.mobileChipBorderRadius,
        min: 0,
        max: 30,
        displayValue: '${controller.mobileChipBorderRadius.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(chipBorderRadius: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_left_right_line,
        title: i18n('chip_horizontal_padding'),
        value: controller.mobileChipHorizontalPadding,
        min: 0,
        max: 20,
        displayValue: '${controller.mobileChipHorizontalPadding.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(chipHorizontalPadding: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_up_down_line,
        title: i18n('chip_vertical_padding'),
        value: controller.mobileChipVerticalPadding,
        min: 0,
        max: 14,
        displayValue: '${controller.mobileChipVerticalPadding.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(chipVerticalPadding: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_left_right_line,
        title: i18n('dense_chip_horizontal_padding'),
        value: controller.mobileDenseChipHorizontalPadding,
        min: 0,
        max: 16,
        displayValue: '${controller.mobileDenseChipHorizontalPadding.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(denseChipHorizontalPadding: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_up_down_line,
        title: i18n('dense_chip_vertical_padding'),
        value: controller.mobileDenseChipVerticalPadding,
        min: 0,
        max: 10,
        displayValue: '${controller.mobileDenseChipVerticalPadding.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(denseChipVerticalPadding: v)),
      ),
      _colorTile(
        context,
        icon: Remix.price_tag_3_line,
        title: i18n('chip_background'),
        color: () => controller.mobileChipBackgroundColor,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(chipBackgroundColor: color)),
      ),
      _colorTile(
        context,
        icon: Remix.font_color,
        title: i18n('chip_text'),
        color: () => controller.mobileChipTextColor,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(chipTextColor: color)),
      ),
    ]);
  }

  // ========== Metric Section ==========
  Widget _buildMetricSection(BuildContext context) {
    return _section(context, i18n('metric_badge'), [
      _sliderTile(
        context,
        icon: Remix.font_size,
        title: i18n('metric_font_size'),
        value: controller.mobileMetricFontSize,
        min: 8,
        max: 16,
        displayValue: '${controller.mobileMetricFontSize.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(metricFontSize: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.font_size,
        title: i18n('dense_metric_font_size'),
        value: controller.mobileDenseMetricFontSize,
        min: 6,
        max: 14,
        displayValue: '${controller.mobileDenseMetricFontSize.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(denseMetricFontSize: v)),
      ),
      _fontWeightTile(
        context,
        title: i18n('metric_font_weight'),
        currentWeight: controller.mobileMetricFontWeight,
        onSelected: (weight) =>
            controller.updateMobile((m) => m.copyWith(metricFontWeight: weight)),
      ),
      _sliderTile(
        context,
        icon: Remix.shape_line,
        title: i18n('metric_border_radius'),
        value: controller.mobileBadgeRadius,
        min: 4,
        max: 24,
        displayValue: '${controller.mobileBadgeRadius.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(metricBorderRadius: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.shape_line,
        title: i18n('dense_metric_border_radius'),
        value: controller.mobileDenseMetricBorderRadius,
        min: 2,
        max: 20,
        displayValue: '${controller.mobileDenseMetricBorderRadius.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(denseMetricBorderRadius: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.eye_line,
        title: i18n('metric_opacity'),
        value: controller.mobileBadgeOpacity,
        min: 0.1,
        max: 1.0,
        step: 0.05,
        displayValue: controller.mobileBadgeOpacity.toStringAsFixed(2),
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(badgeOpacity: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_left_right_line,
        title: i18n('metric_horizontal_padding'),
        value: controller.mobileMetricHorizontalPadding,
        min: 2,
        max: 16,
        displayValue: '${controller.mobileMetricHorizontalPadding.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(metricHorizontalPadding: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_up_down_line,
        title: i18n('metric_vertical_padding'),
        value: controller.mobileMetricVerticalPadding,
        min: 1,
        max: 12,
        displayValue: '${controller.mobileMetricVerticalPadding.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(metricVerticalPadding: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_left_right_line,
        title: i18n('dense_metric_horizontal_padding'),
        value: controller.mobileDenseMetricHorizontalPadding,
        min: 1,
        max: 12,
        displayValue: '${controller.mobileDenseMetricHorizontalPadding.round()} px',
        onChanged: (v) =>
            controller.updateMobile((m) => m.copyWith(denseMetricHorizontalPadding: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_up_down_line,
        title: i18n('dense_metric_vertical_padding'),
        value: controller.mobileDenseMetricVerticalPadding,
        min: 1,
        max: 10,
        displayValue: '${controller.mobileDenseMetricVerticalPadding.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(denseMetricVerticalPadding: v)),
      ),
      _colorTile(
        context,
        icon: Remix.paint_brush_line,
        title: i18n('metric_background'),
        color: () => controller.mobileBadgeBackground,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(metricBackgroundColor: color)),
      ),
      _colorTile(
        context,
        icon: Remix.font_color,
        title: i18n('metric_text'),
        color: () => controller.mobileBadgeForeground,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(metricTextColor: color)),
      ),
      _colorTile(
        context,
        icon: Remix.focus_line,
        title: i18n('metric_border_color'),
        color: () => controller.mobileMetricBorderColor,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(metricBorderColor: color)),
      ),
      _sliderTile(
        context,
        icon: Remix.crop_line,
        title: i18n('metric_border_width'),
        value: controller.mobileMetricBorderWidth,
        min: 0,
        max: 3,
        step: 0.1,
        displayValue: controller.mobileMetricBorderWidth.toStringAsFixed(1),
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(metricBorderWidth: v)),
      ),
    ]);
  }

  // ========== Delete Button Section ==========
  Widget _buildDeleteButtonSection(BuildContext context) {
    return _section(context, i18n('delete_button'), [
      _switchTile(
        context,
        icon: Remix.close_circle_line,
        title: i18n('show_delete_button'),
        subtitle: i18n('show_delete_button_subtitle'),
        value: controller.mobileShowDelete,
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(showDelete: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.rounded_corner,
        title: i18n('delete_button_border_radius'),
        value: controller.mobileDeleteButtonBorderRadius,
        min: 0,
        max: 999,
        displayValue: controller.mobileDeleteButtonBorderRadius >= 999
            ? '∞'
            : '${controller.mobileDeleteButtonBorderRadius.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(deleteButtonBorderRadius: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_left_right_line,
        title: i18n('delete_button_size'),
        value: controller.mobileDeleteButtonSize,
        min: 12,
        max: 32,
        displayValue: '${controller.mobileDeleteButtonSize.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(deleteButtonSize: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.arrow_left_right_line,
        title: i18n('dense_delete_button_size'),
        value: controller.mobileDenseDeleteButtonSize,
        min: 10,
        max: 28,
        displayValue: '${controller.mobileDenseDeleteButtonSize.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(denseDeleteButtonSize: v)),
      ),
      _sliderTile(
        context,
        icon: Remix.drag_move_line,
        title: i18n('delete_button_padding'),
        value: controller.mobileDeleteButtonPadding,
        min: 0,
        max: 16,
        displayValue: '${controller.mobileDeleteButtonPadding.round()} px',
        onChanged: (v) => controller.updateMobile((m) => m.copyWith(deleteButtonPadding: v)),
      ),
      _colorTile(
        context,
        icon: Remix.paint_brush_line,
        title: i18n('delete_button_background'),
        color: () => controller.mobileDeleteButtonBackground,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(deleteButtonBackgroundColor: color)),
      ),
      _colorTile(
        context,
        icon: Remix.font_color,
        title: i18n('delete_button_icon_color'),
        color: () => controller.mobileDeleteButtonIconColor,
        onColorSelected: (color) =>
            controller.updateMobile((m) => m.copyWith(deleteButtonIconColor: color)),
      ),
    ]);
  }

  // ========== Reset Section ==========
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

  // ========== Helper Widgets ==========
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
      builder: (_) => context.buildTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return GetBuilder<RoomCardConfigController>(
      builder: (_) => SwitchListTile(
        secondary: Icon(icon, color: theme.colorScheme.primary, size: 22),
        title: Text(title, style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null && subtitle.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle,
                  style: AppTextStyles.t12.copyWith(color: theme.hintColor.withValues(alpha: 0.75)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : null,
        value: value,
        onChanged: (newValue) {
          controller.switchMobileToCustom();
          onChanged(newValue);
          controller.update();
        },
        contentPadding: const EdgeInsets.only(left: 16, top: 2, bottom: 2, right: 8),
      ),
    );
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
        onChanged: (v) {
          controller.switchMobileToCustom();
          onChanged(v);
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
        trailing: ColorIndicator(
          width: 28,
          height: 28,
          borderRadius: 6,
          color: color(),
          onSelectFocus: false,
        ),
        onTap: () => _showColorPickerDialog(
          context,
          title: title,
          currentColor: color(),
          onColorSelected: (newColor) {
            controller.switchMobileToCustom();
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
    required FontWeight currentWeight,
    required ValueChanged<FontWeight> onSelected,
  }) {
    return _tile(
      context,
      icon: Remix.bold,
      title: title,
      subtitle: _getFontWeightName(currentWeight),
      trailing: _arrow(context),
      onTap: () => _showFontWeightDialog(
        context,
        title: title,
        currentWeight: currentWeight,
        onSelected: (weight) {
          controller.switchMobileToCustom();
          onSelected(weight);
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
        Text(
          value,
          style: AppTextStyles.t13.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(width: 2),
        _arrow(context),
      ],
    );
  }

  // ========== Dialog Helpers ==========
  void _showPresetDialog(BuildContext context, {required bool isMobile}) {
    final theme = Theme.of(context);
    final deviceType = isMobile ? i18n('mobile') : i18n('desktop');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('${i18n('preset_style')} - $deviceType'),
          content: GetBuilder<RoomCardConfigController>(
            builder: (_) {
              final currentPreset = isMobile
                  ? controller.getMobileConfig().preset
                  : controller.getDesktopConfig().preset;

              return RadioGroup<RoomCardPreset>(
                groupValue: currentPreset,
                onChanged: (value) {
                  if (value != null) {
                    if (isMobile) {
                      controller.applyMobilePreset(value);
                    } else {
                      controller.applyDesktopPreset(value);
                    }
                    Navigator.pop(context);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: RoomCardPreset.values.map((preset) {
                    return RadioListTile<RoomCardPreset>(
                      title: Text(_getPresetLabel(preset.key)),
                      subtitle: preset != RoomCardPreset.custom
                          ? Text(
                              _getPresetDescription(preset),
                              style: AppTextStyles.t12.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          : Text(
                              i18n('preset_custom_description'),
                              style: AppTextStyles.t12.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                      value: preset,
                      selected: currentPreset == preset,
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n('close'))),
          ],
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
    required FontWeight currentWeight,
    required ValueChanged<FontWeight> onSelected,
  }) {
    final items = AppConsts.fontWeightType;
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
            child: RadioGroup<FontWeight>(
              groupValue: currentWeight,
              onChanged: (value) {
                if (value != null) {
                  onSelected(value);
                  Navigator.pop(context);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: items.map((item) {
                  final weight = item['attr'] as FontWeight;
                  return RadioListTile<FontWeight>(
                    title: Text('${weight.value} (${i18n(item['desc'])})'),
                    value: weight,
                    selected: weight == currentWeight,
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n('close'))),
          ],
        );
      },
    );
  }

  String _getFontWeightName(FontWeight weight) {
    final list = AppConsts.fontWeightType;
    for (final item in list) {
      if (item['attr'] == weight) {
        return '${weight.value} (${i18n(item['desc'])})';
      }
    }
    return '${weight.value} (${i18n('font_weight_default')})';
  }

  String _getBoxFitName(BoxFit fit) {
    final list = AppConsts.videoFitType;
    for (final item in list) {
      if (item['attr'] == fit) {
        return item['desc'] as String;
      }
    }
    return 'cover';
  }

  String _getFilterQualityName(FilterQuality quality) {
    final list = AppConsts.filterQualityType;
    for (final item in list) {
      if (item['attr'] == quality) {
        return item['desc'] as String;
      }
    }
    return 'low';
  }

  void _showBoxFitDialog(
    BuildContext context, {
    required BoxFit currentFit,
    required ValueChanged<BoxFit> onSelected,
  }) {
    final fitList = AppConsts.videoFitType;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(i18n('cover_fit')),
          content: SizedBox(
            width: 280,
            child: RadioGroup<BoxFit>(
              groupValue: currentFit,
              onChanged: (value) {
                if (value != null) {
                  onSelected(value);
                  Navigator.pop(context);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: fitList.map((item) {
                  final fit = item['attr'] as BoxFit;
                  return RadioListTile<BoxFit>(
                    title: Text(i18n(item['desc'])),
                    value: fit,
                    selected: fit == currentFit,
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n('close'))),
          ],
        );
      },
    );
  }

  void _showFilterQualityDialog(
    BuildContext context, {
    required FilterQuality currentQuality,
    required ValueChanged<FilterQuality> onSelected,
  }) {
    final items = AppConsts.filterQualityType;
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(i18n('cover_filter_quality')),
          content: SizedBox(
            width: 280,
            child: RadioGroup<FilterQuality>(
              groupValue: currentQuality,
              onChanged: (value) {
                if (value != null) {
                  onSelected(value);
                  Navigator.pop(context);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: items.map((item) {
                  final quality = item['attr'] as FilterQuality;
                  return RadioListTile<FilterQuality>(
                    title: Text(i18n(item['desc'])),
                    value: quality,
                    selected: quality == currentQuality,
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n('close'))),
          ],
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
      wheelSubheading: Text(
        i18n('theme_color_opacity'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(i18n('reset_all_settings')),
          content: Text(
            '${i18n('reset_all_settings_confirm')}\n\n${i18n('current_editing')}: 📱 移动端',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(i18n('cancel'))),
            FilledButton(
              onPressed: () {
                controller.resetMobile();
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
