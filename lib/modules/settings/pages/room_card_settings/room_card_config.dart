import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_model.dart';

class RoomCardConfig {
  // ===== 预设 =====
  static final RxString preset = RoomCardPreset.normal.key.obs;
  static RoomCardPreset get presetValue => RoomCardPreset.fromKey(preset.value);
  static bool get isCustomMode => presetValue == RoomCardPreset.custom;

  // ===== 卡片样式 =====
  static final RxDouble cardRadius = 20.0.obs;
  static final RxDouble cardElevation = 0.0.obs;
  static final RxBool enableShadow = false.obs;

  // ===== 封面设置 =====
  static final RxDouble coverRadius = 20.0.obs;
  static final RxDouble coverAspectRatio = (16 / 9).obs;
  static final RxDouble coverPositionPadding = 8.0.obs;
  static final RxBool cacheCover = true.obs;
  static final RxInt coverCacheMinWidth = 240.obs;
  static final RxInt coverCacheMaxWidth = 720.obs;
  static final RxInt coverFitIndex = 2.obs;
  static final RxInt coverFilterQualityIndex = 0.obs;

  // ===== 封面颜色 =====
  static final RxString coverPlaceholderColor = ''.obs;
  static final RxString coverFallbackColor = ''.obs;

  static Color get coverPlaceholderColorValue {
    if (coverPlaceholderColor.value.isEmpty) {
      final isDark = Get.isDarkMode;
      return isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    }
    return HexColor(coverPlaceholderColor.value);
  }

  static Color get coverFallbackColorValue {
    if (coverFallbackColor.value.isEmpty) {
      final isDark = Get.isDarkMode;
      return isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    }
    return HexColor(coverFallbackColor.value);
  }

  static BoxFit get coverFit {
    switch (coverFitIndex.value) {
      case 0:
        return BoxFit.fill;
      case 1:
        return BoxFit.contain;
      case 2:
        return BoxFit.cover;
      case 3:
        return BoxFit.fitWidth;
      case 4:
        return BoxFit.fitHeight;
      case 5:
        return BoxFit.none;
      case 6:
        return BoxFit.scaleDown;
      default:
        return BoxFit.cover;
    }
  }

  static FilterQuality get coverFilterQuality {
    switch (coverFilterQualityIndex.value) {
      case 0:
        return FilterQuality.low;
      case 1:
        return FilterQuality.medium;
      case 2:
        return FilterQuality.high;
      default:
        return FilterQuality.low;
    }
  }

  // ===== 内容布局 =====
  static final RxDouble horizontalPadding = 12.0.obs;
  static final RxDouble verticalPadding = 6.0.obs;
  static final RxDouble horizontalTitleGap = 12.0.obs;
  static final RxDouble avatarSize = 40.0.obs;
  static final RxBool showAvatar = true.obs;
  static final RxBool showSubtitle = true.obs;
  static final RxBool denseMode = false.obs;

  // ===== 文字排版 =====
  static final RxDouble titleFontSize = 15.0.obs;
  static final RxInt titleFontWeightIndex = 5.obs;
  static final RxDouble titleLineHeight = 1.2.obs;

  static final RxDouble subtitleFontSize = 13.0.obs;
  static final RxInt subtitleFontWeightIndex = 4.obs;
  static final RxDouble subtitleLineHeight = 1.2.obs;

  static FontWeight get titleFontWeight {
    return _getFontWeight(titleFontWeightIndex.value);
  }

  static FontWeight get subtitleFontWeight {
    return _getFontWeight(subtitleFontWeightIndex.value);
  }

  static FontWeight _getFontWeight(int index) {
    switch (index) {
      case 0:
        return FontWeight.w100;
      case 1:
        return FontWeight.w200;
      case 2:
        return FontWeight.w300;
      case 3:
        return FontWeight.w400;
      case 4:
        return FontWeight.w500;
      case 5:
        return FontWeight.w600;
      case 6:
        return FontWeight.w700;
      case 7:
        return FontWeight.w800;
      case 8:
        return FontWeight.w900;
      default:
        return FontWeight.w400;
    }
  }

  static void setTitleFontWeight(FontWeight weight) {
    titleFontWeightIndex.value = _getFontWeightIndex(weight);
  }

  static void setSubtitleFontWeight(FontWeight weight) {
    subtitleFontWeightIndex.value = _getFontWeightIndex(weight);
  }

  static int _getFontWeightIndex(FontWeight weight) {
    if (weight == FontWeight.w100) return 0;
    if (weight == FontWeight.w200) return 1;
    if (weight == FontWeight.w300) return 2;
    if (weight == FontWeight.w400) return 3;
    if (weight == FontWeight.w500) return 4;
    if (weight == FontWeight.w600) return 5;
    if (weight == FontWeight.w700) return 6;
    if (weight == FontWeight.w800) return 7;
    if (weight == FontWeight.w900) return 8;
    return 3;
  }

  // ===== 平台标签 =====
  static final RxBool showPlatform = true.obs;
  static final RxDouble platformFontSize = 11.0.obs;
  static final RxInt platformFontWeightIndex = 5.obs;
  static final RxDouble platformBorderRadius = 8.0.obs;
  static final RxDouble platformHorizontalPadding = 8.0.obs;
  static final RxDouble platformVerticalPadding = 4.0.obs;

  static final RxString platformBackgroundLight = ''.obs;
  static final RxString platformBackgroundDark = ''.obs;
  static final RxString platformTextLight = ''.obs;
  static final RxString platformTextDark = ''.obs;

  static FontWeight get platformFontWeight => _getFontWeight(platformFontWeightIndex.value);

  static Color get platformBackgroundLightValue {
    if (platformBackgroundLight.value.isEmpty) return Colors.grey.shade200;
    return HexColor(platformBackgroundLight.value);
  }

  static Color get platformBackgroundDarkValue {
    if (platformBackgroundDark.value.isEmpty) return Colors.grey.shade800;
    return HexColor(platformBackgroundDark.value);
  }

  static Color get platformTextLightValue {
    if (platformTextLight.value.isEmpty) return Colors.black87;
    return HexColor(platformTextLight.value);
  }

  static Color get platformTextDarkValue {
    if (platformTextDark.value.isEmpty) return Colors.white;
    return HexColor(platformTextDark.value);
  }

  // ===== 观众 =====
  static final RxBool showAudience = true.obs;

  // ===== 芯片/录播徽章 =====
  static final RxBool showRecordBadge = true.obs;
  static final RxBool showLiveBadge = true.obs;
  static final RxDouble chipFontSize = 13.0.obs;
  static final RxInt chipFontWeightIndex = 5.obs;
  static final RxDouble chipBorderRadius = 20.0.obs;
  static final RxDouble chipHorizontalPadding = 12.0.obs;
  static final RxDouble chipVerticalPadding = 6.0.obs;
  static final RxString chipBackground = ''.obs;
  static final RxString chipText = ''.obs;

  static FontWeight get chipFontWeight => _getFontWeight(chipFontWeightIndex.value);

  static Color get chipBackgroundColorValue {
    if (chipBackground.value.isEmpty) {
      return Get.theme.primaryColor;
    }
    return HexColor(chipBackground.value);
  }

  static Color get chipTextColorValue {
    if (chipText.value.isEmpty) return Colors.white;
    return HexColor(chipText.value);
  }

  // ===== 指标徽章（观众数） =====
  static final RxDouble metricFontSize = 12.0.obs;
  static final RxInt metricFontWeightIndex = 6.obs;
  static final RxDouble metricHorizontalPadding = 8.0.obs;
  static final RxDouble metricVerticalPadding = 5.0.obs;
  static final RxDouble badgeRadius = 12.0.obs;
  static final RxDouble badgeOpacity = 0.48.obs;
  static final RxDouble metricBorderWidth = 0.6.obs;
  static final RxString badgeBackground = ''.obs;
  static final RxString badgeForeground = ''.obs;
  static final RxString metricBorderColor = ''.obs;

  static FontWeight get metricFontWeight => _getFontWeight(metricFontWeightIndex.value);

  static Color get badgeBackgroundValue {
    if (badgeBackground.value.isEmpty) {
      final isDark = Get.isDarkMode;
      return isDark ? Colors.black.withValues(alpha: 0.58) : Colors.black.withValues(alpha: 0.48);
    }
    return HexColor(badgeBackground.value);
  }

  static Color get badgeForegroundValue {
    if (badgeForeground.value.isEmpty) return Colors.white;
    return HexColor(badgeForeground.value);
  }

  static Color get metricBorderColorValue {
    if (metricBorderColor.value.isEmpty) {
      return Get.theme.primaryColor.withValues(alpha: 0.12);
    }
    return HexColor(metricBorderColor.value);
  }

  // ===== 删除按钮 =====
  static final RxBool showDelete = true.obs;
  static final RxDouble deleteButtonBorderRadius = 999.0.obs;
  static final RxDouble deleteButtonSize = 18.0.obs;
  static final RxDouble deleteButtonPadding = 6.0.obs;
  static final RxString deleteButtonBackground = ''.obs;
  static final RxString deleteButtonIcon = ''.obs;

  static Color get deleteButtonBackgroundColorValue {
    if (deleteButtonBackground.value.isEmpty) return Colors.black54;
    return HexColor(deleteButtonBackground.value);
  }

  static Color get deleteButtonIconColorValue {
    if (deleteButtonIcon.value.isEmpty) return Colors.white;
    return HexColor(deleteButtonIcon.value);
  }

  // ===== 显示选项 =====
  static final RxBool showAsListTile = false.obs;

  // ===== 颜色 =====
  static final RxString lightCardColor = ''.obs;
  static final RxString darkCardColor = ''.obs;
  static final RxString lightTitleColor = ''.obs;
  static final RxString darkTitleColor = ''.obs;
  static final RxString lightSubtitleColor = ''.obs;
  static final RxString darkSubtitleColor = ''.obs;

  static Color get lightCardColorValue {
    if (lightCardColor.value.isEmpty) return Colors.white;
    return HexColor(lightCardColor.value);
  }

  static Color get darkCardColorValue {
    if (darkCardColor.value.isEmpty) return Colors.grey.shade900;
    return HexColor(darkCardColor.value);
  }

  static Color get lightTitleColorValue {
    if (lightTitleColor.value.isEmpty) return Colors.black87;
    return HexColor(lightTitleColor.value);
  }

  static Color get darkTitleColorValue {
    if (darkTitleColor.value.isEmpty) return Colors.white;
    return HexColor(darkTitleColor.value);
  }

  static Color get lightSubtitleColorValue {
    if (lightSubtitleColor.value.isEmpty) return Colors.grey.shade700;
    return HexColor(lightSubtitleColor.value);
  }

  static Color get darkSubtitleColorValue {
    if (darkSubtitleColor.value.isEmpty) return Colors.grey.shade400;
    return HexColor(darkSubtitleColor.value);
  }

  // ===== 主题颜色便捷方法 =====
  static Color getCardColor(bool isDark) => isDark ? darkCardColorValue : lightCardColorValue;
  static Color getTitleColor(bool isDark) => isDark ? darkTitleColorValue : lightTitleColorValue;
  static Color getSubtitleColor(bool isDark) => isDark ? darkSubtitleColorValue : lightSubtitleColorValue;
  static Color getPlatformBackground(bool isDark) =>
      isDark ? platformBackgroundDarkValue : platformBackgroundLightValue;
  static Color getPlatformText(bool isDark) => isDark ? platformTextDarkValue : platformTextLightValue;

  // ===== 应用预设 =====
  static void applyPreset(RoomCardPreset newPreset) {
    final model = RoomCardModel.fromPreset(newPreset);
    preset.value = newPreset.key;

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
    titleFontWeightIndex.value = _getFontWeightIndex(model.titleFontWeight);
    subtitleFontWeightIndex.value = _getFontWeightIndex(model.subtitleFontWeight);

    showPlatform.value = model.showPlatform;
    platformFontSize.value = model.platformFontSize;

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
    deleteButtonSize.value = model.deleteButtonSize;
    deleteButtonPadding.value = model.deleteButtonPadding;

    showAsListTile.value = model.showAsListTile;
  }

  static void switchToCustom() {
    if (presetValue != RoomCardPreset.custom) {
      preset.value = RoomCardPreset.custom.key;
    }
  }

  // ===== 重置 =====
  static Future<void> reset() async {
    applyPreset(RoomCardPreset.normal);
    lightCardColor.value = '';
    darkCardColor.value = '';
    lightTitleColor.value = '';
    darkTitleColor.value = '';
    lightSubtitleColor.value = '';
    darkSubtitleColor.value = '';
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
    coverPlaceholderColor.value = '';
    coverFallbackColor.value = '';
  }

  static void setPlatformFontWeight(FontWeight weight) {
    platformFontWeightIndex.value = _getFontWeightIndex(weight);
  }

  static void setChipFontWeight(FontWeight weight) {
    chipFontWeightIndex.value = _getFontWeightIndex(weight);
  }

  static void setMetricFontWeight(FontWeight weight) {
    metricFontWeightIndex.value = _getFontWeightIndex(weight);
  }

  // ===== 序列化 =====
  static Map<String, dynamic> toJson() {
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

  static void fromJson(Map<String, dynamic> json) {
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
      if (rootConfig.containsKey(key)) {
        result[key] = rootConfig[key];
      }
    }
    return result;
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final result = Map<String, dynamic>.from(rootConfig);
    result.addAll(updateFields);
    return result;
  }
}
