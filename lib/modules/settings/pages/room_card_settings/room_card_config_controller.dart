import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_model.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_config.dart';

class RoomCardConfigController extends GetxController {
  static RoomCardConfigController get to => Get.find();

  // ===== 预设 【持久化】=====
  final RxString preset = hiveString('room_card_preset', RoomCardPreset.normal.key);

  // ===== 卡片样式 =====
  final RxDouble cardRadius = hiveDouble('room_card_radius', 20.0);
  final RxDouble cardElevation = hiveDouble('room_card_elevation', 0.0);
  final RxBool enableShadow = hiveBool('room_card_shadow', false);

  // ===== 封面设置 =====
  final RxDouble coverRadius = hiveDouble('room_card_cover_radius', 20.0);
  final RxDouble coverAspectRatio = hiveDouble('room_card_cover_ratio', 16 / 9);
  final RxDouble coverPositionPadding = hiveDouble('room_card_cover_padding', 8.0);
  final RxBool cacheCover = hiveBool('room_card_cache_cover', true);
  final RxInt coverCacheMinWidth = hiveInt('room_card_cover_min_w', 240);
  final RxInt coverCacheMaxWidth = hiveInt('room_card_cover_max_w', 720);
  final RxInt coverFitIndex = hiveInt('room_card_fit_index', 2);
  final RxInt coverFilterQualityIndex = hiveInt('room_card_filter_index', 0);

  // ===== 封面颜色 =====
  final RxString coverPlaceholderColor = hiveString('room_card_placeholder_color', '');
  final RxString coverFallbackColor = hiveString('room_card_fallback_color', '');

  // ===== 内容布局 =====
  final RxDouble horizontalPadding = hiveDouble('room_card_h_pad', 12.0);
  final RxDouble verticalPadding = hiveDouble('room_card_v_pad', 6.0);
  final RxDouble horizontalTitleGap = hiveDouble('room_card_title_gap', 12.0);
  final RxDouble avatarSize = hiveDouble('room_card_avatar_size', 40.0);
  final RxBool showAvatar = hiveBool('room_card_show_avatar', true);
  final RxBool showSubtitle = hiveBool('room_card_show_subtitle', true);
  final RxBool denseMode = hiveBool('room_card_dense', false);

  // ===== 文字排版 =====
  final RxDouble titleFontSize = hiveDouble('room_card_title_font', 15.0);
  final RxInt titleFontWeightIndex = hiveInt('room_card_title_weight', 5);
  final RxDouble titleLineHeight = hiveDouble('room_card_title_line', 1.2);
  final RxDouble subtitleFontSize = hiveDouble('room_card_sub_font', 13.0);
  final RxInt subtitleFontWeightIndex = hiveInt('room_card_sub_weight', 4);
  final RxDouble subtitleLineHeight = hiveDouble('room_card_sub_line', 1.2);

  // ===== 平台标签 =====
  final RxBool showPlatform = hiveBool('room_card_show_platform', true);
  final RxDouble platformFontSize = hiveDouble('room_card_platform_font', 11.0);
  final RxInt platformFontWeightIndex = hiveInt('room_card_platform_weight', 5);
  final RxDouble platformBorderRadius = hiveDouble('room_card_platform_radius', 8.0);
  final RxDouble platformHorizontalPadding = hiveDouble('room_card_platform_h', 8.0);
  final RxDouble platformVerticalPadding = hiveDouble('room_card_platform_v', 4.0);
  final RxString platformBackgroundLight = hiveString('room_card_platform_bg_light', '');
  final RxString platformBackgroundDark = hiveString('room_card_platform_bg_dark', '');
  final RxString platformTextLight = hiveString('room_card_platform_txt_light', '');
  final RxString platformTextDark = hiveString('room_card_platform_txt_dark', '');

  // ===== 观众 =====
  final RxBool showAudience = hiveBool('room_card_show_audience', true);

  // ===== 芯片/录播徽章 =====
  final RxBool showRecordBadge = hiveBool('room_card_show_record', true);
  final RxBool showLiveBadge = hiveBool('room_card_show_live', true);
  final RxDouble chipFontSize = hiveDouble('room_card_chip_font', 13.0);
  final RxInt chipFontWeightIndex = hiveInt('room_card_chip_weight', 5);
  final RxDouble chipBorderRadius = hiveDouble('room_card_chip_radius', 20.0);
  final RxDouble chipHorizontalPadding = hiveDouble('room_card_chip_h', 12.0);
  final RxDouble chipVerticalPadding = hiveDouble('room_card_chip_v', 6.0);
  final RxString chipBackground = hiveString('room_card_chip_bg', '');
  final RxString chipText = hiveString('room_card_chip_txt', '');

  // ===== 指标徽章（观众数） =====
  final RxDouble metricFontSize = hiveDouble('room_card_metric_font', 12.0);
  final RxInt metricFontWeightIndex = hiveInt('room_card_metric_weight', 6);
  final RxDouble metricHorizontalPadding = hiveDouble('room_card_metric_h', 8.0);
  final RxDouble metricVerticalPadding = hiveDouble('room_card_metric_v', 5.0);
  final RxDouble badgeRadius = hiveDouble('room_card_badge_radius', 12.0);
  final RxDouble badgeOpacity = hiveDouble('room_card_badge_opacity', 0.48);
  final RxDouble metricBorderWidth = hiveDouble('room_card_badge_border', 0.6);
  final RxString badgeBackground = hiveString('room_card_badge_bg', '');
  final RxString badgeForeground = hiveString('room_card_badge_fg', '');
  final RxString metricBorderColor = hiveString('room_card_metric_border_color', '');

  // ===== 删除按钮 =====
  final RxBool showDelete = hiveBool('room_card_show_delete', true);
  final RxDouble deleteButtonBorderRadius = hiveDouble('room_card_del_radius', 999.0);
  final RxDouble deleteButtonSize = hiveDouble('room_card_del_size', 18.0);
  final RxDouble deleteButtonPadding = hiveDouble('room_card_del_pad', 6.0);
  final RxString deleteButtonBackground = hiveString('room_card_del_bg', '');
  final RxString deleteButtonIcon = hiveString('room_card_del_icon', '');

  // ===== 显示选项 =====
  final RxBool showAsListTile = hiveBool('room_card_list_tile', false);

  // ===== 颜色 =====
  final RxString lightCardColor = hiveString('room_card_light_card', '');
  final RxString darkCardColor = hiveString('room_card_dark_card', '');
  final RxString lightTitleColor = hiveString('room_card_light_title', '');
  final RxString darkTitleColor = hiveString('room_card_dark_title', '');
  final RxString lightSubtitleColor = hiveString('room_card_light_sub', '');
  final RxString darkSubtitleColor = hiveString('room_card_dark_sub', '');

  // ===== 衍生 Getter（只读）=====
  RoomCardPreset get presetValue => RoomCardPreset.fromKey(preset.value);
  bool get isCustomMode => presetValue == RoomCardPreset.custom;

  BoxFit get coverFit => RoomCardConfig.coverFit(coverFitIndex.value);
  FilterQuality get coverFilterQuality => RoomCardConfig.coverFilterQuality(coverFilterQualityIndex.value);

  FontWeight get titleFontWeight => RoomCardConfig.getFontWeight(titleFontWeightIndex.value);
  FontWeight get subtitleFontWeight => RoomCardConfig.getFontWeight(subtitleFontWeightIndex.value);
  FontWeight get platformFontWeight => RoomCardConfig.getFontWeight(platformFontWeightIndex.value);
  FontWeight get chipFontWeight => RoomCardConfig.getFontWeight(chipFontWeightIndex.value);
  FontWeight get metricFontWeight => RoomCardConfig.getFontWeight(metricFontWeightIndex.value);

  // 颜色值计算
  Color get coverPlaceholderColorValue => RoomCardConfig.coverPlaceholderColorValue(coverPlaceholderColor.value);
  Color get coverFallbackColorValue => RoomCardConfig.coverFallbackColorValue(coverFallbackColor.value);

  Color get platformBackgroundLightValue => RoomCardConfig.platformBackgroundLightValue(platformBackgroundLight.value);
  Color get platformBackgroundDarkValue => RoomCardConfig.platformBackgroundDarkValue(platformBackgroundDark.value);
  Color get platformTextLightValue => RoomCardConfig.platformTextLightValue(platformTextLight.value);
  Color get platformTextDarkValue => RoomCardConfig.platformTextDarkValue(platformTextDark.value);

  Color get chipBackgroundColorValue => RoomCardConfig.chipBackgroundColorValue(chipBackground.value);
  Color get chipTextColorValue => RoomCardConfig.chipTextColorValue(chipText.value);

  Color get badgeBackgroundValue => RoomCardConfig.badgeBackgroundValue(badgeBackground.value);
  Color get badgeForegroundValue => RoomCardConfig.badgeForegroundValue(badgeForeground.value);
  Color get metricBorderColorValue => RoomCardConfig.metricBorderColorValue(metricBorderColor.value);

  Color get deleteButtonBackgroundColorValue =>
      RoomCardConfig.deleteButtonBackgroundColorValue(deleteButtonBackground.value);
  Color get deleteButtonIconColorValue => RoomCardConfig.deleteButtonIconColorValue(deleteButtonIcon.value);

  Color get lightCardColorValue => RoomCardConfig.lightCardColorValue(lightCardColor.value);
  Color get darkCardColorValue => RoomCardConfig.darkCardColorValue(darkCardColor.value);
  Color get lightTitleColorValue => RoomCardConfig.lightTitleColorValue(lightTitleColor.value);
  Color get darkTitleColorValue => RoomCardConfig.darkTitleColorValue(darkTitleColor.value);
  Color get lightSubtitleColorValue => RoomCardConfig.lightSubtitleColorValue(lightSubtitleColor.value);
  Color get darkSubtitleColorValue => RoomCardConfig.darkSubtitleColorValue(darkSubtitleColor.value);

  Color getCardColor(bool isDark) => isDark ? darkCardColorValue : lightCardColorValue;
  Color getTitleColor(bool isDark) => isDark ? darkTitleColorValue : lightTitleColorValue;
  Color getSubtitleColor(bool isDark) => isDark ? darkSubtitleColorValue : lightSubtitleColorValue;
  Color getPlatformBackground(bool isDark) => isDark ? platformBackgroundDarkValue : platformBackgroundLightValue;
  Color getPlatformText(bool isDark) => isDark ? platformTextDarkValue : platformTextLightValue;

  // ===== 生命周期初始化（缺失的初始化代码）=====
  @override
  void onInit() {
    super.onInit();
    // 页面打开：非自定义模式，加载预设刷新表单UI
    if (!isCustomMode) {
      _loadPresetValue(presetValue);
    }
  }

  // ===== 切换预设 =====
  void applyPreset(RoomCardPreset newPreset) {
    _loadPresetValue(newPreset);
    preset.value = newPreset.key;
    update();
  }

  // 从预设模板完整加载所有字段（补全之前漏掉的字段）
  void _loadPresetValue(RoomCardPreset newPreset) {
    final model = RoomCardModel.fromPreset(newPreset);

    cardRadius.value = model.cardBorderRadius;
    cardElevation.value = model.cardElevation;
    enableShadow.value = model.enableShadow;

    coverRadius.value = model.coverBorderRadius;
    coverAspectRatio.value = model.coverAspectRatio;
    coverPositionPadding.value = model.coverPositionPadding;
    cacheCover.value = model.cacheCover;
    coverCacheMinWidth.value = model.coverCacheMinWidth;
    coverCacheMaxWidth.value = model.coverCacheMaxWidth;

    horizontalPadding.value = model.contentHorizontalPadding;
    verticalPadding.value = model.contentVerticalPadding;
    horizontalTitleGap.value = model.horizontalTitleGap;
    avatarSize.value = model.avatarSize;
    showAvatar.value = model.showAvatar;
    showSubtitle.value = model.showSubtitle;
    denseMode.value = model.denseMode;

    titleFontSize.value = model.titleFontSize;
    titleLineHeight.value = model.titleLineHeight;
    subtitleFontSize.value = model.subtitleFontSize;
    subtitleLineHeight.value = model.subtitleLineHeight;
    titleFontWeightIndex.value = RoomCardConfig.getFontWeightIndex(model.titleFontWeight);
    subtitleFontWeightIndex.value = RoomCardConfig.getFontWeightIndex(model.subtitleFontWeight);

    showPlatform.value = model.showPlatform;
    platformFontSize.value = model.platformFontSize;
    platformBorderRadius.value = model.platformBorderRadius;
    platformHorizontalPadding.value = model.platformHorizontalPadding;
    platformVerticalPadding.value = model.platformVerticalPadding;

    showAudience.value = model.showAudience;
    showRecordBadge.value = model.showRecordBadge;
    showLiveBadge.value = model.showLiveBadge;

    chipFontSize.value = model.chipFontSize;
    chipBorderRadius.value = model.chipBorderRadius;
    chipHorizontalPadding.value = model.chipHorizontalPadding;
    chipVerticalPadding.value = model.chipVerticalPadding;

    metricFontSize.value = model.metricFontSize;
    badgeRadius.value = model.metricBorderRadius;
    badgeOpacity.value = model.badgeOpacity;
    metricHorizontalPadding.value = model.metricHorizontalPadding;
    metricVerticalPadding.value = model.metricVerticalPadding;
    metricBorderWidth.value = model.metricBorderWidth;

    showDelete.value = model.showDelete;
    deleteButtonBorderRadius.value = model.deleteButtonBorderRadius;
    deleteButtonSize.value = model.deleteButtonSize;
    deleteButtonPadding.value = model.deleteButtonPadding;

    showAsListTile.value = model.showAsListTile;
  }

  void switchToCustom() {
    if (presetValue != RoomCardPreset.custom) {
      preset.value = RoomCardPreset.custom.key;
    }
  }

  void setTitleFontWeight(FontWeight weight) {
    titleFontWeightIndex.value = RoomCardConfig.getFontWeightIndex(weight);
  }

  void setSubtitleFontWeight(FontWeight weight) {
    subtitleFontWeightIndex.value = RoomCardConfig.getFontWeightIndex(weight);
  }

  void setPlatformFontWeight(FontWeight weight) {
    platformFontWeightIndex.value = RoomCardConfig.getFontWeightIndex(weight);
  }

  void setChipFontWeight(FontWeight weight) {
    chipFontWeightIndex.value = RoomCardConfig.getFontWeightIndex(weight);
  }

  void setMetricFontWeight(FontWeight weight) {
    metricFontWeightIndex.value = RoomCardConfig.getFontWeightIndex(weight);
  }

  Future<void> reset() async {
    applyPreset(RoomCardPreset.custom);
    coverPlaceholderColor.value = '';
    coverFallbackColor.value = '';
    platformBackgroundLight.value = '';
    platformBackgroundDark.value = '';
    platformTextLight.value = '';
    platformTextDark.value = '';
    chipBackground.value = '';
    chipText.value = '';
    badgeBackground.value = '';
    badgeForeground.value = '';
    metricBorderColor.value = '';
    deleteButtonBackground.value = '';
    deleteButtonIcon.value = '';
    lightCardColor.value = '';
    darkCardColor.value = '';
    lightTitleColor.value = '';
    darkTitleColor.value = '';
    lightSubtitleColor.value = '';
    darkSubtitleColor.value = '';
  }

  void updateView() {
    update();
  }

  // ===== 序列化导出（和ThemeSettingsController保持一模一样风格）=====
  Map<String, dynamic> toJson() {
    return {
      'preset': preset.value,
      'cardRadius': cardRadius.value,
      'cardElevation': cardElevation.value,
      'enableShadow': enableShadow.value,
      'coverRadius': coverRadius.value,
      'coverAspectRatio': coverAspectRatio.value,
      'coverPositionPadding': coverPositionPadding.value,
      'cacheCover': cacheCover.value,
      'coverCacheMinWidth': coverCacheMinWidth.value,
      'coverCacheMaxWidth': coverCacheMaxWidth.value,
      'coverFitIndex': coverFitIndex.value,
      'coverFilterQualityIndex': coverFilterQualityIndex.value,
      'coverPlaceholderColor': coverPlaceholderColor.value,
      'coverFallbackColor': coverFallbackColor.value,
      'horizontalPadding': horizontalPadding.value,
      'verticalPadding': verticalPadding.value,
      'horizontalTitleGap': horizontalTitleGap.value,
      'avatarSize': avatarSize.value,
      'showAvatar': showAvatar.value,
      'showSubtitle': showSubtitle.value,
      'denseMode': denseMode.value,
      'titleFontSize': titleFontSize.value,
      'titleFontWeightIndex': titleFontWeightIndex.value,
      'titleLineHeight': titleLineHeight.value,
      'subtitleFontSize': subtitleFontSize.value,
      'subtitleFontWeightIndex': subtitleFontWeightIndex.value,
      'subtitleLineHeight': subtitleLineHeight.value,
      'showPlatform': showPlatform.value,
      'platformFontSize': platformFontSize.value,
      'platformFontWeightIndex': platformFontWeightIndex.value,
      'platformBorderRadius': platformBorderRadius.value,
      'platformHorizontalPadding': platformHorizontalPadding.value,
      'platformVerticalPadding': platformVerticalPadding.value,
      'platformBackgroundLight': platformBackgroundLight.value,
      'platformBackgroundDark': platformBackgroundDark.value,
      'platformTextLight': platformTextLight.value,
      'platformTextDark': platformTextDark.value,
      'showAudience': showAudience.value,
      'showRecordBadge': showRecordBadge.value,
      'showLiveBadge': showLiveBadge.value,
      'chipFontSize': chipFontSize.value,
      'chipFontWeightIndex': chipFontWeightIndex.value,
      'chipBorderRadius': chipBorderRadius.value,
      'chipHorizontalPadding': chipHorizontalPadding.value,
      'chipVerticalPadding': chipVerticalPadding.value,
      'chipBackground': chipBackground.value,
      'chipText': chipText.value,
      'metricFontSize': metricFontSize.value,
      'metricFontWeightIndex': metricFontWeightIndex.value,
      'metricHorizontalPadding': metricHorizontalPadding.value,
      'metricVerticalPadding': metricVerticalPadding.value,
      'badgeRadius': badgeRadius.value,
      'badgeOpacity': badgeOpacity.value,
      'metricBorderWidth': metricBorderWidth.value,
      'badgeBackground': badgeBackground.value,
      'badgeForeground': badgeForeground.value,
      'metricBorderColor': metricBorderColor.value,
      'showDelete': showDelete.value,
      'deleteButtonBorderRadius': deleteButtonBorderRadius.value,
      'deleteButtonSize': deleteButtonSize.value,
      'deleteButtonPadding': deleteButtonPadding.value,
      'deleteButtonBackground': deleteButtonBackground.value,
      'deleteButtonIcon': deleteButtonIcon.value,
      'showAsListTile': showAsListTile.value,
      'lightCardColor': lightCardColor.value,
      'darkCardColor': darkCardColor.value,
      'lightTitleColor': lightTitleColor.value,
      'darkTitleColor': darkTitleColor.value,
      'lightSubtitleColor': lightSubtitleColor.value,
      'darkSubtitleColor': darkSubtitleColor.value,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    preset.value = json['preset'] ?? RoomCardPreset.normal.key;
    cardRadius.value = (json['cardRadius'] ?? 20.0).toDouble();
    cardElevation.value = (json['cardElevation'] ?? 0.0).toDouble();
    enableShadow.value = json['enableShadow'] ?? false;
    coverRadius.value = (json['coverRadius'] ?? 20.0).toDouble();
    coverAspectRatio.value = (json['coverAspectRatio'] ?? 16 / 9).toDouble();
    coverPositionPadding.value = (json['coverPositionPadding'] ?? 8.0).toDouble();
    cacheCover.value = json['cacheCover'] ?? true;
    coverCacheMinWidth.value = json['coverCacheMinWidth'] ?? 240;
    coverCacheMaxWidth.value = json['coverCacheMaxWidth'] ?? 720;
    coverFitIndex.value = json['coverFitIndex'] ?? 2;
    coverFilterQualityIndex.value = json['coverFilterQualityIndex'] ?? 0;
    coverPlaceholderColor.value = json['coverPlaceholderColor'] ?? '';
    coverFallbackColor.value = json['coverFallbackColor'] ?? '';
    horizontalPadding.value = (json['horizontalPadding'] ?? 12.0).toDouble();
    verticalPadding.value = (json['verticalPadding'] ?? 6.0).toDouble();
    horizontalTitleGap.value = (json['horizontalTitleGap'] ?? 12.0).toDouble();
    avatarSize.value = (json['avatarSize'] ?? 40.0).toDouble();
    showAvatar.value = json['showAvatar'] ?? true;
    showSubtitle.value = json['showSubtitle'] ?? true;
    denseMode.value = json['denseMode'] ?? false;
    titleFontSize.value = (json['titleFontSize'] ?? 15.0).toDouble();
    titleFontWeightIndex.value = json['titleFontWeightIndex'] ?? 5;
    titleLineHeight.value = (json['titleLineHeight'] ?? 1.2).toDouble();
    subtitleFontSize.value = (json['subtitleFontSize'] ?? 13.0).toDouble();
    subtitleFontWeightIndex.value = json['subtitleFontWeightIndex'] ?? 4;
    subtitleLineHeight.value = (json['subtitleLineHeight'] ?? 1.2).toDouble();
    showPlatform.value = json['showPlatform'] ?? true;
    platformFontSize.value = (json['platformFontSize'] ?? 11.0).toDouble();
    platformFontWeightIndex.value = json['platformFontWeightIndex'] ?? 5;
    platformBorderRadius.value = (json['platformBorderRadius'] ?? 8.0).toDouble();
    platformHorizontalPadding.value = (json['platformHorizontalPadding'] ?? 8.0).toDouble();
    platformVerticalPadding.value = (json['platformVerticalPadding'] ?? 4.0).toDouble();
    platformBackgroundLight.value = json['platformBackgroundLight'] ?? '';
    platformBackgroundDark.value = json['platformBackgroundDark'] ?? '';
    platformTextLight.value = json['platformTextLight'] ?? '';
    platformTextDark.value = json['platformTextDark'] ?? '';
    showAudience.value = json['showAudience'] ?? true;
    showRecordBadge.value = json['showRecordBadge'] ?? true;
    showLiveBadge.value = json['showLiveBadge'] ?? true;
    chipFontSize.value = (json['chipFontSize'] ?? 13.0).toDouble();
    chipFontWeightIndex.value = json['chipFontWeightIndex'] ?? 5;
    chipBorderRadius.value = (json['chipBorderRadius'] ?? 20.0).toDouble();
    chipHorizontalPadding.value = (json['chipHorizontalPadding'] ?? 12.0).toDouble();
    chipVerticalPadding.value = (json['chipVerticalPadding'] ?? 6.0).toDouble();
    chipBackground.value = json['chipBackground'] ?? '';
    chipText.value = json['chipText'] ?? '';
    metricFontSize.value = (json['metricFontSize'] ?? 12.0).toDouble();
    metricFontWeightIndex.value = json['metricFontWeightIndex'] ?? 6;
    metricHorizontalPadding.value = (json['metricHorizontalPadding'] ?? 8.0).toDouble();
    metricVerticalPadding.value = (json['metricVerticalPadding'] ?? 5.0).toDouble();
    badgeRadius.value = (json['badgeRadius'] ?? 12.0).toDouble();
    badgeOpacity.value = (json['badgeOpacity'] ?? 0.48).toDouble();
    metricBorderWidth.value = (json['metricBorderWidth'] ?? 0.6).toDouble();
    badgeBackground.value = json['badgeBackground'] ?? '';
    badgeForeground.value = json['badgeForeground'] ?? '';
    metricBorderColor.value = json['metricBorderColor'] ?? '';
    showDelete.value = json['showDelete'] ?? true;
    deleteButtonBorderRadius.value = (json['deleteButtonBorderRadius'] ?? 999.0).toDouble();
    deleteButtonSize.value = (json['deleteButtonSize'] ?? 18.0).toDouble();
    deleteButtonPadding.value = (json['deleteButtonPadding'] ?? 6.0).toDouble();
    deleteButtonBackground.value = json['deleteButtonBackground'] ?? '';
    deleteButtonIcon.value = json['deleteButtonIcon'] ?? '';
    showAsListTile.value = json['showAsListTile'] ?? false;
    lightCardColor.value = json['lightCardColor'] ?? '';
    darkCardColor.value = json['darkCardColor'] ?? '';
    lightTitleColor.value = json['lightTitleColor'] ?? '';
    darkTitleColor.value = json['darkTitleColor'] ?? '';
    lightSubtitleColor.value = json['lightSubtitleColor'] ?? '';
    darkSubtitleColor.value = json['darkSubtitleColor'] ?? '';
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    if (rootConfig == null) return {};
    final room = rootConfig['room_card'] as Map<String, dynamic>? ?? {};
    final result = <String, dynamic>{};
    const keys = [
      'preset',
      'cardRadius',
      'cardElevation',
      'enableShadow',
      'coverRadius',
      'coverAspectRatio',
      'coverPositionPadding',
      'cacheCover',
      'coverCacheMinWidth',
      'coverCacheMaxWidth',
      'coverFitIndex',
      'coverFilterQualityIndex',
      'coverPlaceholderColor',
      'coverFallbackColor',
      'horizontalPadding',
      'verticalPadding',
      'horizontalTitleGap',
      'avatarSize',
      'showAvatar',
      'showSubtitle',
      'denseMode',
      'titleFontSize',
      'titleFontWeightIndex',
      'titleLineHeight',
      'subtitleFontSize',
      'subtitleFontWeightIndex',
      'subtitleLineHeight',
      'showPlatform',
      'platformFontSize',
      'platformFontWeightIndex',
      'platformBorderRadius',
      'platformHorizontalPadding',
      'platformVerticalPadding',
      'platformBackgroundLight',
      'platformBackgroundDark',
      'platformTextLight',
      'platformTextDark',
      'showAudience',
      'showRecordBadge',
      'showLiveBadge',
      'chipFontSize',
      'chipFontWeightIndex',
      'chipBorderRadius',
      'chipHorizontalPadding',
      'chipVerticalPadding',
      'chipBackground',
      'chipText',
      'metricFontSize',
      'metricFontWeightIndex',
      'metricHorizontalPadding',
      'metricVerticalPadding',
      'badgeRadius',
      'badgeOpacity',
      'metricBorderWidth',
      'badgeBackground',
      'badgeForeground',
      'metricBorderColor',
      'showDelete',
      'deleteButtonBorderRadius',
      'deleteButtonSize',
      'deleteButtonPadding',
      'deleteButtonBackground',
      'deleteButtonIcon',
      'showAsListTile',
      'lightCardColor',
      'darkCardColor',
      'lightTitleColor',
      'darkTitleColor',
      'lightSubtitleColor',
      'darkSubtitleColor',
    ];
    for (final key in keys) {
      if (room.containsKey(key)) result[key] = room[key];
    }
    return result;
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final room = Map<String, dynamic>.from(rootConfig['room_card'] ?? {});
    updateFields.forEach((k, v) => room[k] = v);
    rootConfig['room_card'] = room;
    return rootConfig;
  }
}
