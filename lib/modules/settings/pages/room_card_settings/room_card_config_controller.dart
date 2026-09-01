import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_model.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_config.dart';

class RoomCardConfigController extends GetxController {
  static RoomCardConfigController get to => Get.find();

  // ===== 预设 =====
  RxString get preset => RoomCardConfig.preset;
  RoomCardPreset get presetValue => RoomCardConfig.presetValue;
  bool get isCustomMode => RoomCardConfig.isCustomMode;

  // ===== 卡片样式 =====
  RxDouble get cardRadius => RoomCardConfig.cardRadius;
  RxDouble get cardElevation => RoomCardConfig.cardElevation;
  RxBool get enableShadow => RoomCardConfig.enableShadow;

  // ===== 封面设置 =====
  RxDouble get coverRadius => RoomCardConfig.coverRadius;
  RxDouble get coverAspectRatio => RoomCardConfig.coverAspectRatio;
  RxDouble get coverPositionPadding => RoomCardConfig.coverPositionPadding;
  RxBool get cacheCover => RoomCardConfig.cacheCover;
  RxInt get coverCacheMinWidth => RoomCardConfig.coverCacheMinWidth;
  RxInt get coverCacheMaxWidth => RoomCardConfig.coverCacheMaxWidth;
  RxInt get coverFitIndex => RoomCardConfig.coverFitIndex;
  RxInt get coverFilterQualityIndex => RoomCardConfig.coverFilterQualityIndex;
  RxString get coverPlaceholderColor => RoomCardConfig.coverPlaceholderColor;
  RxString get coverFallbackColor => RoomCardConfig.coverFallbackColor;

  // ===== 封面颜色值 =====
  Color get coverPlaceholderColorValue => RoomCardConfig.coverPlaceholderColorValue;
  Color get coverFallbackColorValue => RoomCardConfig.coverFallbackColorValue;
  BoxFit get coverFit => RoomCardConfig.coverFit;
  FilterQuality get coverFilterQuality => RoomCardConfig.coverFilterQuality;

  // ===== 内容布局 =====
  RxDouble get horizontalPadding => RoomCardConfig.horizontalPadding;
  RxDouble get verticalPadding => RoomCardConfig.verticalPadding;
  RxDouble get horizontalTitleGap => RoomCardConfig.horizontalTitleGap;
  RxDouble get avatarSize => RoomCardConfig.avatarSize;
  RxBool get showAvatar => RoomCardConfig.showAvatar;
  RxBool get showSubtitle => RoomCardConfig.showSubtitle;
  RxBool get denseMode => RoomCardConfig.denseMode;

  // ===== 文字排版 =====
  RxDouble get titleFontSize => RoomCardConfig.titleFontSize;
  RxDouble get subtitleFontSize => RoomCardConfig.subtitleFontSize;
  RxInt get titleFontWeightIndex => RoomCardConfig.titleFontWeightIndex;
  RxInt get subtitleFontWeightIndex => RoomCardConfig.subtitleFontWeightIndex;
  FontWeight get titleFontWeight => RoomCardConfig.titleFontWeight;
  FontWeight get subtitleFontWeight => RoomCardConfig.subtitleFontWeight;
  RxDouble get titleLineHeight => RoomCardConfig.titleLineHeight;
  RxDouble get subtitleLineHeight => RoomCardConfig.subtitleLineHeight;

  // ===== 平台标签 =====
  RxBool get showPlatform => RoomCardConfig.showPlatform;
  RxDouble get platformFontSize => RoomCardConfig.platformFontSize;
  RxInt get platformFontWeightIndex => RoomCardConfig.platformFontWeightIndex;
  RxDouble get platformBorderRadius => RoomCardConfig.platformBorderRadius;
  RxDouble get platformHorizontalPadding => RoomCardConfig.platformHorizontalPadding;
  RxDouble get platformVerticalPadding => RoomCardConfig.platformVerticalPadding;
  RxString get platformBackgroundLight => RoomCardConfig.platformBackgroundLight;
  RxString get platformBackgroundDark => RoomCardConfig.platformBackgroundDark;
  RxString get platformTextLight => RoomCardConfig.platformTextLight;
  RxString get platformTextDark => RoomCardConfig.platformTextDark;

  // ===== 平台颜色值 =====
  FontWeight get platformFontWeight => RoomCardConfig.platformFontWeight;
  Color get platformBackgroundLightValue => RoomCardConfig.platformBackgroundLightValue;
  Color get platformBackgroundDarkValue => RoomCardConfig.platformBackgroundDarkValue;
  Color get platformTextLightValue => RoomCardConfig.platformTextLightValue;
  Color get platformTextDarkValue => RoomCardConfig.platformTextDarkValue;

  // ===== 观众 =====
  RxBool get showAudience => RoomCardConfig.showAudience;

  // ===== 芯片/录播徽章 =====
  RxBool get showRecordBadge => RoomCardConfig.showRecordBadge;
  RxBool get showLiveBadge => RoomCardConfig.showLiveBadge;
  RxDouble get chipFontSize => RoomCardConfig.chipFontSize;
  RxInt get chipFontWeightIndex => RoomCardConfig.chipFontWeightIndex;
  RxDouble get chipBorderRadius => RoomCardConfig.chipBorderRadius;
  RxDouble get chipHorizontalPadding => RoomCardConfig.chipHorizontalPadding;
  RxDouble get chipVerticalPadding => RoomCardConfig.chipVerticalPadding;
  RxString get chipBackground => RoomCardConfig.chipBackground;
  RxString get chipText => RoomCardConfig.chipText;

  // ===== 芯片颜色值 =====
  FontWeight get chipFontWeight => RoomCardConfig.chipFontWeight;
  Color get chipBackgroundColorValue => RoomCardConfig.chipBackgroundColorValue;
  Color get chipTextColorValue => RoomCardConfig.chipTextColorValue;

  // ===== 指标徽章 =====
  RxDouble get metricFontSize => RoomCardConfig.metricFontSize;
  RxInt get metricFontWeightIndex => RoomCardConfig.metricFontWeightIndex;
  RxDouble get metricHorizontalPadding => RoomCardConfig.metricHorizontalPadding;
  RxDouble get metricVerticalPadding => RoomCardConfig.metricVerticalPadding;
  RxDouble get badgeRadius => RoomCardConfig.badgeRadius;
  RxDouble get badgeOpacity => RoomCardConfig.badgeOpacity;
  RxDouble get metricBorderWidth => RoomCardConfig.metricBorderWidth;
  RxString get badgeBackground => RoomCardConfig.badgeBackground;
  RxString get badgeForeground => RoomCardConfig.badgeForeground;
  RxString get metricBorderColor => RoomCardConfig.metricBorderColor;

  // ===== 指标颜色值 =====
  FontWeight get metricFontWeight => RoomCardConfig.metricFontWeight;
  Color get badgeBackgroundValue => RoomCardConfig.badgeBackgroundValue;
  Color get badgeForegroundValue => RoomCardConfig.badgeForegroundValue;
  Color get metricBorderColorValue => RoomCardConfig.metricBorderColorValue;

  // ===== 删除按钮 =====
  RxBool get showDelete => RoomCardConfig.showDelete;
  RxDouble get deleteButtonBorderRadius => RoomCardConfig.deleteButtonBorderRadius;
  RxDouble get deleteButtonSize => RoomCardConfig.deleteButtonSize;
  RxDouble get deleteButtonPadding => RoomCardConfig.deleteButtonPadding;
  RxString get deleteButtonBackground => RoomCardConfig.deleteButtonBackground;
  RxString get deleteButtonIcon => RoomCardConfig.deleteButtonIcon;

  // ===== 删除按钮颜色值 =====
  Color get deleteButtonBackgroundColorValue => RoomCardConfig.deleteButtonBackgroundColorValue;
  Color get deleteButtonIconColorValue => RoomCardConfig.deleteButtonIconColorValue;

  // ===== 显示选项 =====
  RxBool get showAsListTile => RoomCardConfig.showAsListTile;

  // ===== 颜色 =====
  RxString get lightCardColor => RoomCardConfig.lightCardColor;
  RxString get darkCardColor => RoomCardConfig.darkCardColor;
  RxString get lightTitleColor => RoomCardConfig.lightTitleColor;
  RxString get darkTitleColor => RoomCardConfig.darkTitleColor;
  RxString get lightSubtitleColor => RoomCardConfig.lightSubtitleColor;
  RxString get darkSubtitleColor => RoomCardConfig.darkSubtitleColor;

  // ===== 颜色值 =====
  Color get lightCardColorValue => RoomCardConfig.lightCardColorValue;
  Color get darkCardColorValue => RoomCardConfig.darkCardColorValue;
  Color get lightTitleColorValue => RoomCardConfig.lightTitleColorValue;
  Color get darkTitleColorValue => RoomCardConfig.darkTitleColorValue;
  Color get lightSubtitleColorValue => RoomCardConfig.lightSubtitleColorValue;
  Color get darkSubtitleColorValue => RoomCardConfig.darkSubtitleColorValue;

  // ===== 主题颜色获取 =====
  Color getCardColor(bool isDark) => RoomCardConfig.getCardColor(isDark);
  Color getTitleColor(bool isDark) => RoomCardConfig.getTitleColor(isDark);
  Color getSubtitleColor(bool isDark) => RoomCardConfig.getSubtitleColor(isDark);
  Color getPlatformBackground(bool isDark) => RoomCardConfig.getPlatformBackground(isDark);
  Color getPlatformText(bool isDark) => RoomCardConfig.getPlatformText(isDark);

  // ===== 操作方法 =====
  void applyPreset(RoomCardPreset preset) {
    RoomCardConfig.applyPreset(preset);
  }

  void switchToCustom() {
    RoomCardConfig.switchToCustom();
  }

  void setTitleFontWeight(FontWeight weight) {
    RoomCardConfig.setTitleFontWeight(weight);
  }

  void setSubtitleFontWeight(FontWeight weight) {
    RoomCardConfig.setSubtitleFontWeight(weight);
  }

  void setPlatformFontWeight(FontWeight weight) {
    RoomCardConfig.setPlatformFontWeight(weight);
  }

  void setChipFontWeight(FontWeight weight) {
    RoomCardConfig.setChipFontWeight(weight);
  }

  void setMetricFontWeight(FontWeight weight) {
    RoomCardConfig.setMetricFontWeight(weight);
  }

  Future<void> reset() async {
    await RoomCardConfig.reset();
  }

  // ===== 序列化 =====
  Map<String, dynamic> toJson() => RoomCardConfig.toJson();

  void fromJson(Map<String, dynamic> json) {
    RoomCardConfig.fromJson(json);
  }

  Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    return RoomCardConfig.extractConfig(rootConfig);
  }

  Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    return RoomCardConfig.mergeConfig(rootConfig, updateFields);
  }

  void updateView() {
    update();
  }
}
