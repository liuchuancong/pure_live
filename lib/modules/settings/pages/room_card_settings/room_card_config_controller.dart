import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_model.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_config_utils.dart';

class RoomCardConfigController extends GetxController {
  static RoomCardConfigController get to => Get.find();

  // ===== Preset [Persistent] =====
  final RxString preset = hiveString('room_card_preset', RoomCardPreset.normal.key);

  // ===== Card Style =====
  final RxDouble cardRadius = hiveDouble('room_card_radius', 20.0);
  final RxDouble cardElevation = hiveDouble('room_card_elevation', 0.0);
  final RxBool enableShadow = hiveBool('room_card_shadow', false);
  final RxDouble cardMargin = hiveDouble('room_card_margin', 0.0); // Added

  // ===== Cover Settings =====
  final RxDouble coverRadius = hiveDouble('room_card_cover_radius', 20.0);
  final RxDouble coverAspectRatio = hiveDouble('room_card_cover_ratio', 16 / 9);
  final RxDouble coverPositionPadding = hiveDouble('room_card_cover_padding', 8.0);
  final RxBool cacheCover = hiveBool('room_card_cache_cover', true);
  final RxInt coverCacheMinWidth = hiveInt('room_card_cover_min_w', 240);
  final RxInt coverCacheMaxWidth = hiveInt('room_card_cover_max_w', 720);
  final RxInt coverFitIndex = hiveInt('room_card_fit_index', 2);
  final RxInt coverFilterQualityIndex = hiveInt('room_card_filter_index', 0);

  // ===== Cover Colors =====
  final RxString coverPlaceholderColor = hiveString('room_card_placeholder_color', '');
  final RxString coverFallbackColor = hiveString('room_card_fallback_color', '');

  // ===== Content Layout =====
  final RxDouble horizontalPadding = hiveDouble('room_card_h_pad', 12.0);
  final RxDouble verticalPadding = hiveDouble('room_card_v_pad', 6.0);
  final RxDouble horizontalTitleGap = hiveDouble('room_card_title_gap', 12.0);
  final RxDouble avatarSize = hiveDouble('room_card_avatar_size', 40.0);
  final RxBool showAvatar = hiveBool('room_card_show_avatar', true);
  final RxBool showSubtitle = hiveBool('room_card_show_subtitle', true);
  final RxBool denseMode = hiveBool('room_card_dense', false);

  // ===== Dense Variants (used when denseMode is true) =====
  final RxDouble denseAvatarSize = hiveDouble('room_card_dense_avatar_size', 40.0);
  final RxDouble denseContentHorizontalPadding = hiveDouble('room_card_dense_h_pad', 10.0);
  final RxDouble denseContentVerticalPadding = hiveDouble('room_card_dense_v_pad', 4.0);
  final RxDouble denseHorizontalTitleGap = hiveDouble('room_card_dense_title_gap', 8.0);
  final RxDouble denseTitleFontSize = hiveDouble('room_card_dense_title_font', 13.0);
  final RxDouble denseSubtitleFontSize = hiveDouble('room_card_dense_sub_font', 12.0);
  final RxDouble densePlatformFontSize = hiveDouble('room_card_dense_platform_font', 10.0);
  final RxDouble denseChipFontSize = hiveDouble('room_card_dense_chip_font', 12.0);
  final RxDouble denseChipHorizontalPadding = hiveDouble('room_card_dense_chip_h', 10.0);
  final RxDouble denseChipVerticalPadding = hiveDouble('room_card_dense_chip_v', 4.0);
  final RxDouble denseMetricFontSize = hiveDouble('room_card_dense_metric_font', 11.0);
  final RxDouble denseMetricHorizontalPadding = hiveDouble('room_card_dense_metric_h', 6.0);
  final RxDouble denseMetricVerticalPadding = hiveDouble('room_card_dense_metric_v', 4.0);
  final RxDouble denseMetricBorderRadius = hiveDouble('room_card_dense_badge_radius', 10.0);
  final RxDouble denseDeleteButtonSize = hiveDouble('room_card_dense_del_size', 16.0);

  // ===== Typography =====
  final RxDouble titleFontSize = hiveDouble('room_card_title_font', 15.0);
  final RxInt titleFontWeightIndex = hiveInt('room_card_title_weight', 5);
  final RxDouble titleLineHeight = hiveDouble('room_card_title_line', 1.2);
  final RxDouble subtitleFontSize = hiveDouble('room_card_sub_font', 13.0);
  final RxInt subtitleFontWeightIndex = hiveInt('room_card_sub_weight', 4);
  final RxDouble subtitleLineHeight = hiveDouble('room_card_sub_line', 1.2);

  // ===== Platform Label =====
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

  // ===== Audience =====
  final RxBool showAudience = hiveBool('room_card_show_audience', true);

  // ===== Chip / Record Badge =====
  final RxBool showRecordBadge = hiveBool('room_card_show_record', true);
  final RxBool showLiveBadge = hiveBool('room_card_show_live', true);
  final RxDouble chipFontSize = hiveDouble('room_card_chip_font', 13.0);
  final RxInt chipFontWeightIndex = hiveInt('room_card_chip_weight', 5);
  final RxDouble chipBorderRadius = hiveDouble('room_card_chip_radius', 20.0);
  final RxDouble chipHorizontalPadding = hiveDouble('room_card_chip_h', 12.0);
  final RxDouble chipVerticalPadding = hiveDouble('room_card_chip_v', 6.0);
  final RxString chipBackground = hiveString('room_card_chip_bg', '');
  final RxString chipText = hiveString('room_card_chip_txt', '');

  // ===== Metric Badge (viewer count) =====
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

  // ===== Delete Button =====
  final RxBool showDelete = hiveBool('room_card_show_delete', true);
  final RxDouble deleteButtonBorderRadius = hiveDouble('room_card_del_radius', 999.0);
  final RxDouble deleteButtonSize = hiveDouble('room_card_del_size', 18.0);
  final RxDouble deleteButtonPadding = hiveDouble('room_card_del_pad', 6.0);
  final RxString deleteButtonBackground = hiveString('room_card_del_bg', '');
  final RxString deleteButtonIcon = hiveString('room_card_del_icon', '');

  // ===== Display Options =====
  final RxBool showAsListTile = hiveBool('room_card_list_tile', false);

  // ===== Colors =====
  final RxString lightCardColor = hiveString('room_card_light_card', '');
  final RxString darkCardColor = hiveString('room_card_dark_card', '');
  final RxString lightTitleColor = hiveString('room_card_light_title', '');
  final RxString darkTitleColor = hiveString('room_card_dark_title', '');
  final RxString lightSubtitleColor = hiveString('room_card_light_sub', '');
  final RxString darkSubtitleColor = hiveString('room_card_dark_sub', '');

  // ===== Derived Getters (read-only) =====
  RoomCardPreset get presetValue => RoomCardPreset.fromKey(preset.value);
  bool get isCustomMode => presetValue == RoomCardPreset.custom;

  BoxFit get coverFit => RoomCardConfigUtils.coverFit(coverFitIndex.value);
  FilterQuality get coverFilterQuality => RoomCardConfigUtils.coverFilterQuality(coverFilterQualityIndex.value);

  FontWeight get titleFontWeight => RoomCardConfigUtils.getFontWeight(titleFontWeightIndex.value);
  FontWeight get subtitleFontWeight => RoomCardConfigUtils.getFontWeight(subtitleFontWeightIndex.value);
  FontWeight get platformFontWeight => RoomCardConfigUtils.getFontWeight(platformFontWeightIndex.value);
  FontWeight get chipFontWeight => RoomCardConfigUtils.getFontWeight(chipFontWeightIndex.value);
  FontWeight get metricFontWeight => RoomCardConfigUtils.getFontWeight(metricFontWeightIndex.value);

  // Color value computation
  Color get coverPlaceholderColorValue => RoomCardConfigUtils.coverPlaceholderColorValue(coverPlaceholderColor.value);
  Color get coverFallbackColorValue => RoomCardConfigUtils.coverFallbackColorValue(coverFallbackColor.value);

  Color get platformBackgroundLightValue =>
      RoomCardConfigUtils.platformBackgroundLightValue(platformBackgroundLight.value);
  Color get platformBackgroundDarkValue =>
      RoomCardConfigUtils.platformBackgroundDarkValue(platformBackgroundDark.value);
  Color get platformTextLightValue => RoomCardConfigUtils.platformTextLightValue(platformTextLight.value);
  Color get platformTextDarkValue => RoomCardConfigUtils.platformTextDarkValue(platformTextDark.value);

  Color get chipBackgroundColorValue => RoomCardConfigUtils.chipBackgroundColorValue(chipBackground.value);
  Color get chipTextColorValue => RoomCardConfigUtils.chipTextColorValue(chipText.value);

  Color get badgeBackgroundValue => RoomCardConfigUtils.badgeBackgroundValue(badgeBackground.value);
  Color get badgeForegroundValue => RoomCardConfigUtils.badgeForegroundValue(badgeForeground.value);
  Color get metricBorderColorValue => RoomCardConfigUtils.metricBorderColorValue(metricBorderColor.value);

  Color get deleteButtonBackgroundColorValue =>
      RoomCardConfigUtils.deleteButtonBackgroundColorValue(deleteButtonBackground.value);
  Color get deleteButtonIconColorValue => RoomCardConfigUtils.deleteButtonIconColorValue(deleteButtonIcon.value);

  Color get lightCardColorValue => RoomCardConfigUtils.lightCardColorValue(lightCardColor.value);
  Color get darkCardColorValue => RoomCardConfigUtils.darkCardColorValue(darkCardColor.value);
  Color get lightTitleColorValue => RoomCardConfigUtils.lightTitleColorValue(lightTitleColor.value);
  Color get darkTitleColorValue => RoomCardConfigUtils.darkTitleColorValue(darkTitleColor.value);
  Color get lightSubtitleColorValue => RoomCardConfigUtils.lightSubtitleColorValue(lightSubtitleColor.value);
  Color get darkSubtitleColorValue => RoomCardConfigUtils.darkSubtitleColorValue(darkSubtitleColor.value);

  Color getCardColor(bool isDark) => isDark ? darkCardColorValue : lightCardColorValue;
  Color getTitleColor(bool isDark) => isDark ? darkTitleColorValue : lightTitleColorValue;
  Color getSubtitleColor(bool isDark) => isDark ? darkSubtitleColorValue : lightSubtitleColorValue;
  Color getPlatformBackground(bool isDark) => isDark ? platformBackgroundDarkValue : platformBackgroundLightValue;
  Color getPlatformText(bool isDark) => isDark ? platformTextDarkValue : platformTextLightValue;

  // ===== Lifecycle initialization =====
  @override
  void onInit() {
    super.onInit();
    // On page open: if not in custom mode, load preset to refresh form UI
    if (!isCustomMode) {
      _loadPresetValue(presetValue);
    }
  }

  // ===== Apply Preset =====
  void applyPreset(RoomCardPreset newPreset) {
    _loadPresetValue(newPreset);
    preset.value = newPreset.key;
    update();
  }

  // Load all fields from preset model (complete)
  void _loadPresetValue(RoomCardPreset newPreset) {
    final model = RoomCardModel.fromPreset(newPreset);

    cardRadius.value = model.cardBorderRadius;
    cardElevation.value = model.cardElevation;
    enableShadow.value = model.enableShadow;
    cardMargin.value = model.cardMargin.horizontal; // Store as double for persistence

    coverRadius.value = model.coverBorderRadius;
    coverAspectRatio.value = model.coverAspectRatio;
    coverPositionPadding.value = model.coverPositionPadding;
    cacheCover.value = model.cacheCover;
    coverCacheMinWidth.value = model.coverCacheMinWidth;
    coverCacheMaxWidth.value = model.coverCacheMaxWidth;
    coverFitIndex.value = RoomCardConfigUtils.getCoverFitIndex(model.coverFit);
    coverFilterQualityIndex.value = RoomCardConfigUtils.getFilterQualityIndex(model.coverFilterQuality);

    // Dense variants
    denseAvatarSize.value = model.denseAvatarSize;
    denseContentHorizontalPadding.value = model.denseContentHorizontalPadding;
    denseContentVerticalPadding.value = model.denseContentVerticalPadding;
    denseHorizontalTitleGap.value = model.denseHorizontalTitleGap;
    denseTitleFontSize.value = model.denseTitleFontSize;
    denseSubtitleFontSize.value = model.denseSubtitleFontSize;
    densePlatformFontSize.value = model.densePlatformFontSize;
    denseChipFontSize.value = model.denseChipFontSize;
    denseChipHorizontalPadding.value = model.denseChipHorizontalPadding;
    denseChipVerticalPadding.value = model.denseChipVerticalPadding;
    denseMetricFontSize.value = model.denseMetricFontSize;
    denseMetricHorizontalPadding.value = model.denseMetricHorizontalPadding;
    denseMetricVerticalPadding.value = model.denseMetricVerticalPadding;
    denseMetricBorderRadius.value = model.denseMetricBorderRadius;
    denseDeleteButtonSize.value = model.denseDeleteButtonSize;

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
    titleFontWeightIndex.value = RoomCardConfigUtils.getFontWeightIndex(model.titleFontWeight);
    subtitleFontWeightIndex.value = RoomCardConfigUtils.getFontWeightIndex(model.subtitleFontWeight);

    showPlatform.value = model.showPlatform;
    platformFontSize.value = model.platformFontSize;
    platformBorderRadius.value = model.platformBorderRadius;
    platformHorizontalPadding.value = model.platformHorizontalPadding;
    platformVerticalPadding.value = model.platformVerticalPadding;
    platformFontWeightIndex.value = RoomCardConfigUtils.getFontWeightIndex(model.platformFontWeight);

    showAudience.value = model.showAudience;
    showRecordBadge.value = model.showRecordBadge;
    showLiveBadge.value = model.showLiveBadge;

    chipFontSize.value = model.chipFontSize;
    chipBorderRadius.value = model.chipBorderRadius;
    chipHorizontalPadding.value = model.chipHorizontalPadding;
    chipVerticalPadding.value = model.chipVerticalPadding;
    chipFontWeightIndex.value = RoomCardConfigUtils.getFontWeightIndex(model.chipFontWeight);

    metricFontSize.value = model.metricFontSize;
    badgeRadius.value = model.metricBorderRadius;
    badgeOpacity.value = model.badgeOpacity;
    metricHorizontalPadding.value = model.metricHorizontalPadding;
    metricVerticalPadding.value = model.metricVerticalPadding;
    metricBorderWidth.value = model.metricBorderWidth;
    metricFontWeightIndex.value = RoomCardConfigUtils.getFontWeightIndex(model.metricFontWeight);

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
    titleFontWeightIndex.value = RoomCardConfigUtils.getFontWeightIndex(weight);
  }

  void setSubtitleFontWeight(FontWeight weight) {
    subtitleFontWeightIndex.value = RoomCardConfigUtils.getFontWeightIndex(weight);
  }

  void setPlatformFontWeight(FontWeight weight) {
    platformFontWeightIndex.value = RoomCardConfigUtils.getFontWeightIndex(weight);
  }

  void setChipFontWeight(FontWeight weight) {
    chipFontWeightIndex.value = RoomCardConfigUtils.getFontWeightIndex(weight);
  }

  void setMetricFontWeight(FontWeight weight) {
    metricFontWeightIndex.value = RoomCardConfigUtils.getFontWeightIndex(weight);
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

  // ===== Serialization (same style as ThemeSettingsController) =====
  Map<String, dynamic> toJson() {
    return {
      'preset': preset.value,
      'cardRadius': cardRadius.value,
      'cardElevation': cardElevation.value,
      'enableShadow': enableShadow.value,
      'cardMargin': cardMargin.value,
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
      'denseAvatarSize': denseAvatarSize.value,
      'denseContentHorizontalPadding': denseContentHorizontalPadding.value,
      'denseContentVerticalPadding': denseContentVerticalPadding.value,
      'denseHorizontalTitleGap': denseHorizontalTitleGap.value,
      'denseTitleFontSize': denseTitleFontSize.value,
      'denseSubtitleFontSize': denseSubtitleFontSize.value,
      'densePlatformFontSize': densePlatformFontSize.value,
      'denseChipFontSize': denseChipFontSize.value,
      'denseChipHorizontalPadding': denseChipHorizontalPadding.value,
      'denseChipVerticalPadding': denseChipVerticalPadding.value,
      'denseMetricFontSize': denseMetricFontSize.value,
      'denseMetricHorizontalPadding': denseMetricHorizontalPadding.value,
      'denseMetricVerticalPadding': denseMetricVerticalPadding.value,
      'denseMetricBorderRadius': denseMetricBorderRadius.value,
      'denseDeleteButtonSize': denseDeleteButtonSize.value,
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
    cardMargin.value = (json['cardMargin'] ?? 0.0).toDouble();
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
    denseAvatarSize.value = (json['denseAvatarSize'] ?? 40.0).toDouble();
    denseContentHorizontalPadding.value = (json['denseContentHorizontalPadding'] ?? 10.0).toDouble();
    denseContentVerticalPadding.value = (json['denseContentVerticalPadding'] ?? 4.0).toDouble();
    denseHorizontalTitleGap.value = (json['denseHorizontalTitleGap'] ?? 8.0).toDouble();
    denseTitleFontSize.value = (json['denseTitleFontSize'] ?? 13.0).toDouble();
    denseSubtitleFontSize.value = (json['denseSubtitleFontSize'] ?? 12.0).toDouble();
    densePlatformFontSize.value = (json['densePlatformFontSize'] ?? 10.0).toDouble();
    denseChipFontSize.value = (json['denseChipFontSize'] ?? 12.0).toDouble();
    denseChipHorizontalPadding.value = (json['denseChipHorizontalPadding'] ?? 10.0).toDouble();
    denseChipVerticalPadding.value = (json['denseChipVerticalPadding'] ?? 4.0).toDouble();
    denseMetricFontSize.value = (json['denseMetricFontSize'] ?? 11.0).toDouble();
    denseMetricHorizontalPadding.value = (json['denseMetricHorizontalPadding'] ?? 6.0).toDouble();
    denseMetricVerticalPadding.value = (json['denseMetricVerticalPadding'] ?? 4.0).toDouble();
    denseMetricBorderRadius.value = (json['denseMetricBorderRadius'] ?? 10.0).toDouble();
    denseDeleteButtonSize.value = (json['denseDeleteButtonSize'] ?? 16.0).toDouble();
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
      'cardMargin',
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
      'denseAvatarSize',
      'denseContentHorizontalPadding',
      'denseContentVerticalPadding',
      'denseHorizontalTitleGap',
      'denseTitleFontSize',
      'denseSubtitleFontSize',
      'densePlatformFontSize',
      'denseChipFontSize',
      'denseChipHorizontalPadding',
      'denseChipVerticalPadding',
      'denseMetricFontSize',
      'denseMetricHorizontalPadding',
      'denseMetricVerticalPadding',
      'denseMetricBorderRadius',
      'denseDeleteButtonSize',
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
