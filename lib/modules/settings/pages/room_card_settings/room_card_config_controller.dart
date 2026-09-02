import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_model.dart';

class RoomCardConfigController extends GetxController {
  static RoomCardConfigController get to => Get.find();

  // ===== Preset per viewport =====
  final RxString mobilePreset = hiveString('room_card_mobile_preset', RoomCardPreset.normal.key);
  final RxString desktopPreset = hiveString('room_card_desktop_preset', RoomCardPreset.normal.key);

  // ===== Config per viewport =====
  final Rx<Map<String, dynamic>> mobileConfigJson = hiveObject<Map<String, dynamic>>(
    'room_card_mobile_config',
    {},
    fromJson: (json) => json,
    toJson: (value) => value,
  );

  final Rx<Map<String, dynamic>> desktopConfigJson = hiveObject<Map<String, dynamic>>(
    'room_card_desktop_config',
    {},
    fromJson: (json) => json,
    toJson: (value) => value,
  );

  // ============================================================
  // Lifecycle
  // ============================================================
  @override
  void onInit() {
    super.onInit();
    // Initialize mobile config if empty
    if (mobileConfigJson.value.isEmpty) {
      final preset = RoomCardPreset.fromKey(mobilePreset.value);
      final model = preset == RoomCardPreset.custom ? RoomCardModel.custom() : RoomCardModel.fromPreset(preset);
      mobileConfigJson.value = model.toJson();
    }
    // Initialize desktop config if empty
    if (desktopConfigJson.value.isEmpty) {
      final preset = RoomCardPreset.fromKey(desktopPreset.value);
      final model = preset == RoomCardPreset.custom ? RoomCardModel.custom() : RoomCardModel.fromPreset(preset);
      desktopConfigJson.value = model.toJson();
    }
  }

  // ============================================================
  // Viewport
  // ============================================================
  RoomCardViewportPreset get currentViewport {
    return RoomCardViewportPreset.fromWidth(Get.width);
  }

  bool get isMobileViewport => currentViewport == RoomCardViewportPreset.mobile;

  // ============================================================
  // Mobile
  // ============================================================
  RoomCardModel getMobileConfig() {
    if (mobileConfigJson.value.isNotEmpty) {
      return RoomCardModel.fromJson(mobileConfigJson.value);
    }
    return RoomCardModel.fromPreset(RoomCardPreset.fromKey(mobilePreset.value));
  }

  // ===== Calculate card height =====
  double calculateCardHeight({required double itemWidth, bool denseOverride = false, bool smallScreen = false}) {
    final config = isMobileViewport ? getMobileConfig() : getDesktopConfig();
    return config.calculateCardHeight(itemWidth, denseOverride: denseOverride, smallScreen: smallScreen);
  }

  void updateMobile(RoomCardModel Function(RoomCardModel) updater) {
    final newModel = updater(getMobileConfig());
    mobileConfigJson.value = newModel.toJson();
    update();
  }

  void applyMobilePreset(RoomCardPreset preset) {
    final model = preset == RoomCardPreset.custom ? RoomCardModel.custom() : RoomCardModel.fromPreset(preset);
    mobilePreset.value = preset.key;
    mobileConfigJson.value = model.toJson();
    update();
  }

  void switchMobileToCustom() {
    final config = getMobileConfig();
    if (config.preset != RoomCardPreset.custom) {
      applyMobilePreset(RoomCardPreset.custom);
    }
  }

  bool get isMobileCustomMode => getMobileConfig().preset == RoomCardPreset.custom;
  String get mobilePresetLabel => getMobileConfig().preset.label;

  void resetMobile() {
    final model = RoomCardModel.custom();
    updateMobile((_) => model);
    updateMobile(
      (m) => m.copyWith(
        coverPlaceholderColor: null,
        coverFallbackColor: null,
        platformBackgroundColor: null,
        platformTextColor: null,
        chipBackgroundColor: null,
        chipTextColor: Colors.white,
        metricBackgroundColor: null,
        metricTextColor: Colors.white,
        metricBorderColor: null,
        deleteButtonBackgroundColor: null,
        deleteButtonIconColor: Colors.white,
        cardBackground: null,
        titleColor: null,
        subtitleColor: null,
      ),
    );
    updateMobile(
      (m) => m.copyWith(
        cardBorderRadius: 20,
        cardElevation: 2,
        enableShadow: true,
        cardMargin: EdgeInsets.zero,
        coverAspectRatio: 16 / 9,
        coverBorderRadius: 20,
        coverFit: BoxFit.cover,
        coverFilterQuality: FilterQuality.low,
        coverCacheMinWidth: 240,
        coverCacheMaxWidth: 720,
        cacheCover: true,
        coverPositionPadding: 8,
        avatarSize: 40,
        denseAvatarSize: 40,
        showAvatar: true,
        contentHorizontalPadding: 12,
        denseContentHorizontalPadding: 10,
        contentVerticalPadding: 6,
        denseContentVerticalPadding: 4,
        horizontalTitleGap: 12,
        denseHorizontalTitleGap: 8,
        titleFontSize: 15,
        denseTitleFontSize: 13,
        subtitleFontSize: 13,
        denseSubtitleFontSize: 12,
        titleFontWeight: FontWeight.w600,
        subtitleFontWeight: FontWeight.w500,
        titleLineHeight: 1.2,
        subtitleLineHeight: 1.2,
        showSubtitle: true,
        platformFontSize: 11,
        densePlatformFontSize: 10,
        platformFontWeight: FontWeight.w600,
        platformBorderRadius: 8,
        platformHorizontalPadding: 8,
        platformVerticalPadding: 4,
        showPlatform: false,
        showAudience: true,
        chipFontSize: 13,
        denseChipFontSize: 12,
        chipFontWeight: FontWeight.w600,
        chipHorizontalPadding: 12,
        denseChipHorizontalPadding: 10,
        chipVerticalPadding: 6,
        denseChipVerticalPadding: 4,
        chipBorderRadius: 20,
        chipTextColor: Colors.white,
        showRecordBadge: true,
        showLiveBadge: true,
        metricFontSize: 12,
        denseMetricFontSize: 11,
        metricFontWeight: FontWeight.w700,
        metricHorizontalPadding: 8,
        denseMetricHorizontalPadding: 6,
        metricVerticalPadding: 5,
        denseMetricVerticalPadding: 4,
        metricBorderRadius: 12,
        denseMetricBorderRadius: 10,
        metricTextColor: Colors.white,
        metricBorderWidth: 0.6,
        badgeOpacity: 0.48,
        showDelete: true,
        deleteButtonPadding: 6,
        deleteButtonSize: 18,
        denseDeleteButtonSize: 16,
        deleteButtonIconColor: Colors.white,
        deleteButtonBorderRadius: 999,
        denseMode: false,
        showAsListTile: false,
      ),
    );
    update();
  }

  // ===== Mobile Getters =====
  RoomCardModel get _mobile => getMobileConfig();

  double get mobileCardRadius => _mobile.cardBorderRadius;
  double get mobileCardElevation => _mobile.cardElevation;
  bool get mobileEnableShadow => _mobile.enableShadow;
  double get mobileCardMargin => _mobile.cardMargin.horizontal;
  double get mobileCoverRadius => _mobile.coverBorderRadius;
  double get mobileCoverAspectRatio => _mobile.coverAspectRatio;
  double get mobileCoverPositionPadding => _mobile.coverPositionPadding;
  bool get mobileCacheCover => _mobile.cacheCover;
  int get mobileCoverCacheMinWidth => _mobile.coverCacheMinWidth;
  int get mobileCoverCacheMaxWidth => _mobile.coverCacheMaxWidth;
  BoxFit get mobileCoverFit => _mobile.coverFit;
  FilterQuality get mobileCoverFilterQuality => _mobile.coverFilterQuality;
  Color get mobileCoverPlaceholderColor => _mobile.coverPlaceholderColor ?? Colors.grey.shade100;
  Color get mobileCoverFallbackColor => _mobile.coverFallbackColor ?? Colors.grey.shade100;
  double get mobileHorizontalPadding => _mobile.contentHorizontalPadding;
  double get mobileVerticalPadding => _mobile.contentVerticalPadding;
  double get mobileHorizontalTitleGap => _mobile.horizontalTitleGap;
  double get mobileAvatarSize => _mobile.avatarSize;
  bool get mobileShowAvatar => _mobile.showAvatar;
  bool get mobileShowSubtitle => _mobile.showSubtitle;
  bool get mobileDenseMode => _mobile.denseMode;
  double get mobileDenseAvatarSize => _mobile.denseAvatarSize;
  double get mobileDenseContentHorizontalPadding => _mobile.denseContentHorizontalPadding;
  double get mobileDenseContentVerticalPadding => _mobile.denseContentVerticalPadding;
  double get mobileDenseHorizontalTitleGap => _mobile.denseHorizontalTitleGap;
  double get mobileDenseTitleFontSize => _mobile.denseTitleFontSize;
  double get mobileDenseSubtitleFontSize => _mobile.denseSubtitleFontSize;
  double get mobileDensePlatformFontSize => _mobile.densePlatformFontSize;
  double get mobileDenseChipFontSize => _mobile.denseChipFontSize;
  double get mobileDenseChipHorizontalPadding => _mobile.denseChipHorizontalPadding;
  double get mobileDenseChipVerticalPadding => _mobile.denseChipVerticalPadding;
  double get mobileDenseMetricFontSize => _mobile.denseMetricFontSize;
  double get mobileDenseMetricHorizontalPadding => _mobile.denseMetricHorizontalPadding;
  double get mobileDenseMetricVerticalPadding => _mobile.denseMetricVerticalPadding;
  double get mobileDenseMetricBorderRadius => _mobile.denseMetricBorderRadius;
  double get mobileDenseDeleteButtonSize => _mobile.denseDeleteButtonSize;
  double get mobileTitleFontSize => _mobile.titleFontSize;
  FontWeight get mobileTitleFontWeight => _mobile.titleFontWeight;
  double get mobileTitleLineHeight => _mobile.titleLineHeight;
  double get mobileSubtitleFontSize => _mobile.subtitleFontSize;
  FontWeight get mobileSubtitleFontWeight => _mobile.subtitleFontWeight;
  double get mobileSubtitleLineHeight => _mobile.subtitleLineHeight;
  bool get mobileShowPlatform => _mobile.showPlatform;
  double get mobilePlatformFontSize => _mobile.platformFontSize;
  FontWeight get mobilePlatformFontWeight => _mobile.platformFontWeight;
  double get mobilePlatformBorderRadius => _mobile.platformBorderRadius;
  double get mobilePlatformHorizontalPadding => _mobile.platformHorizontalPadding;
  double get mobilePlatformVerticalPadding => _mobile.platformVerticalPadding;
  bool get mobileShowAudience => _mobile.showAudience;
  bool get mobileShowRecordBadge => _mobile.showRecordBadge;
  bool get mobileShowLiveBadge => _mobile.showLiveBadge;
  double get mobileChipFontSize => _mobile.chipFontSize;
  FontWeight get mobileChipFontWeight => _mobile.chipFontWeight;
  double get mobileChipBorderRadius => _mobile.chipBorderRadius;
  double get mobileChipHorizontalPadding => _mobile.chipHorizontalPadding;
  double get mobileChipVerticalPadding => _mobile.chipVerticalPadding;
  double get mobileMetricFontSize => _mobile.metricFontSize;
  FontWeight get mobileMetricFontWeight => _mobile.metricFontWeight;
  double get mobileMetricHorizontalPadding => _mobile.metricHorizontalPadding;
  double get mobileMetricVerticalPadding => _mobile.metricVerticalPadding;
  double get mobileBadgeRadius => _mobile.metricBorderRadius;
  double get mobileBadgeOpacity => _mobile.badgeOpacity;
  double get mobileMetricBorderWidth => _mobile.metricBorderWidth;
  bool get mobileShowDelete => _mobile.showDelete;
  double get mobileDeleteButtonBorderRadius => _mobile.deleteButtonBorderRadius;
  double get mobileDeleteButtonSize => _mobile.deleteButtonSize;
  double get mobileDeleteButtonPadding => _mobile.deleteButtonPadding;
  bool get mobileShowAsListTile => _mobile.showAsListTile;

  // ===== Mobile Colors =====
  Color get mobileLightCardColor => _mobile.cardBackground ?? Colors.white;
  Color get mobileDarkCardColor => _mobile.cardBackground ?? Colors.grey.shade900;
  Color get mobileLightTitleColor => _mobile.titleColor ?? Colors.black87;
  Color get mobileDarkTitleColor => _mobile.titleColor ?? Colors.white;
  Color get mobileLightSubtitleColor => _mobile.subtitleColor ?? Colors.grey.shade700;
  Color get mobileDarkSubtitleColor => _mobile.subtitleColor ?? Colors.grey.shade400;
  Color get mobilePlatformBackgroundLight => _mobile.platformBackgroundColor ?? Colors.grey.shade200;
  Color get mobilePlatformBackgroundDark => _mobile.platformBackgroundColor ?? Colors.grey.shade800;
  Color get mobilePlatformTextLight => _mobile.platformTextColor ?? Colors.black87;
  Color get mobilePlatformTextDark => _mobile.platformTextColor ?? Colors.white;
  Color get mobileChipBackgroundColor => _mobile.chipBackgroundColor ?? Get.theme.primaryColor;
  Color get mobileChipTextColor => _mobile.chipTextColor;
  Color get mobileBadgeBackground => _mobile.metricBackgroundColor ?? Colors.black.withValues(alpha: 0.48);
  Color get mobileBadgeForeground => _mobile.metricTextColor;
  Color get mobileMetricBorderColor => _mobile.metricBorderColor ?? Get.theme.primaryColor.withValues(alpha: 0.12);
  Color get mobileDeleteButtonBackground => _mobile.deleteButtonBackgroundColor ?? Colors.black54;
  Color get mobileDeleteButtonIconColor => _mobile.deleteButtonIconColor;

  // ============================================================
  // Desktop
  // ============================================================
  RoomCardModel getDesktopConfig() {
    if (desktopConfigJson.value.isNotEmpty) {
      return RoomCardModel.fromJson(desktopConfigJson.value);
    }
    return RoomCardModel.fromPreset(RoomCardPreset.fromKey(desktopPreset.value));
  }

  void updateDesktop(RoomCardModel Function(RoomCardModel) updater) {
    final newModel = updater(getDesktopConfig());
    desktopConfigJson.value = newModel.toJson();
    update();
  }

  void applyDesktopPreset(RoomCardPreset preset) {
    final model = preset == RoomCardPreset.custom ? RoomCardModel.custom() : RoomCardModel.fromPreset(preset);
    desktopPreset.value = preset.key;
    desktopConfigJson.value = model.toJson();
    update();
  }

  void switchDesktopToCustom() {
    final config = getDesktopConfig();
    if (config.preset != RoomCardPreset.custom) {
      applyDesktopPreset(RoomCardPreset.custom);
    }
  }

  bool get isDesktopCustomMode => getDesktopConfig().preset == RoomCardPreset.custom;
  String get desktopPresetLabel => getDesktopConfig().preset.label;

  void resetDesktop() {
    final model = RoomCardModel.custom();
    updateDesktop((_) => model);
    updateDesktop(
      (m) => m.copyWith(
        coverPlaceholderColor: null,
        coverFallbackColor: null,
        platformBackgroundColor: null,
        platformTextColor: null,
        chipBackgroundColor: null,
        chipTextColor: Colors.white,
        metricBackgroundColor: null,
        metricTextColor: Colors.white,
        metricBorderColor: null,
        deleteButtonBackgroundColor: null,
        deleteButtonIconColor: Colors.white,
        cardBackground: null,
        titleColor: null,
        subtitleColor: null,
      ),
    );
    updateDesktop(
      (m) => m.copyWith(
        cardBorderRadius: 20,
        cardElevation: 2,
        enableShadow: true,
        cardMargin: EdgeInsets.zero,
        coverAspectRatio: 16 / 9,
        coverBorderRadius: 20,
        coverFit: BoxFit.cover,
        coverFilterQuality: FilterQuality.low,
        coverCacheMinWidth: 240,
        coverCacheMaxWidth: 720,
        cacheCover: true,
        coverPositionPadding: 8,
        avatarSize: 40,
        denseAvatarSize: 40,
        showAvatar: true,
        contentHorizontalPadding: 12,
        denseContentHorizontalPadding: 10,
        contentVerticalPadding: 6,
        denseContentVerticalPadding: 4,
        horizontalTitleGap: 12,
        denseHorizontalTitleGap: 8,
        titleFontSize: 15,
        denseTitleFontSize: 13,
        subtitleFontSize: 13,
        denseSubtitleFontSize: 12,
        titleFontWeight: FontWeight.w600,
        subtitleFontWeight: FontWeight.w500,
        titleLineHeight: 1.2,
        subtitleLineHeight: 1.2,
        showSubtitle: true,
        platformFontSize: 11,
        densePlatformFontSize: 10,
        platformFontWeight: FontWeight.w600,
        platformBorderRadius: 8,
        platformHorizontalPadding: 8,
        platformVerticalPadding: 4,
        showPlatform: false,
        showAudience: true,
        chipFontSize: 13,
        denseChipFontSize: 12,
        chipFontWeight: FontWeight.w600,
        chipHorizontalPadding: 12,
        denseChipHorizontalPadding: 10,
        chipVerticalPadding: 6,
        denseChipVerticalPadding: 4,
        chipBorderRadius: 20,
        chipTextColor: Colors.white,
        showRecordBadge: true,
        showLiveBadge: true,
        metricFontSize: 12,
        denseMetricFontSize: 11,
        metricFontWeight: FontWeight.w700,
        metricHorizontalPadding: 8,
        denseMetricHorizontalPadding: 6,
        metricVerticalPadding: 5,
        denseMetricVerticalPadding: 4,
        metricBorderRadius: 12,
        denseMetricBorderRadius: 10,
        metricTextColor: Colors.white,
        metricBorderWidth: 0.6,
        badgeOpacity: 0.48,
        showDelete: true,
        deleteButtonPadding: 6,
        deleteButtonSize: 18,
        denseDeleteButtonSize: 16,
        deleteButtonIconColor: Colors.white,
        deleteButtonBorderRadius: 999,
        denseMode: false,
        showAsListTile: false,
      ),
    );
    update();
  }

  // ===== Desktop Getters =====
  RoomCardModel get _desktop => getDesktopConfig();

  double get desktopCardRadius => _desktop.cardBorderRadius;
  double get desktopCardElevation => _desktop.cardElevation;
  bool get desktopEnableShadow => _desktop.enableShadow;
  double get desktopCardMargin => _desktop.cardMargin.horizontal;
  double get desktopCoverRadius => _desktop.coverBorderRadius;
  double get desktopCoverAspectRatio => _desktop.coverAspectRatio;
  double get desktopCoverPositionPadding => _desktop.coverPositionPadding;
  bool get desktopCacheCover => _desktop.cacheCover;
  int get desktopCoverCacheMinWidth => _desktop.coverCacheMinWidth;
  int get desktopCoverCacheMaxWidth => _desktop.coverCacheMaxWidth;
  BoxFit get desktopCoverFit => _desktop.coverFit;
  FilterQuality get desktopCoverFilterQuality => _desktop.coverFilterQuality;
  Color get desktopCoverPlaceholderColor => _desktop.coverPlaceholderColor ?? Colors.grey.shade100;
  Color get desktopCoverFallbackColor => _desktop.coverFallbackColor ?? Colors.grey.shade100;
  double get desktopHorizontalPadding => _desktop.contentHorizontalPadding;
  double get desktopVerticalPadding => _desktop.contentVerticalPadding;
  double get desktopHorizontalTitleGap => _desktop.horizontalTitleGap;
  double get desktopAvatarSize => _desktop.avatarSize;
  bool get desktopShowAvatar => _desktop.showAvatar;
  bool get desktopShowSubtitle => _desktop.showSubtitle;
  bool get desktopDenseMode => _desktop.denseMode;
  double get desktopDenseAvatarSize => _desktop.denseAvatarSize;
  double get desktopDenseContentHorizontalPadding => _desktop.denseContentHorizontalPadding;
  double get desktopDenseContentVerticalPadding => _desktop.denseContentVerticalPadding;
  double get desktopDenseHorizontalTitleGap => _desktop.denseHorizontalTitleGap;
  double get desktopDenseTitleFontSize => _desktop.denseTitleFontSize;
  double get desktopDenseSubtitleFontSize => _desktop.denseSubtitleFontSize;
  double get desktopDensePlatformFontSize => _desktop.densePlatformFontSize;
  double get desktopDenseChipFontSize => _desktop.denseChipFontSize;
  double get desktopDenseChipHorizontalPadding => _desktop.denseChipHorizontalPadding;
  double get desktopDenseChipVerticalPadding => _desktop.denseChipVerticalPadding;
  double get desktopDenseMetricFontSize => _desktop.denseMetricFontSize;
  double get desktopDenseMetricHorizontalPadding => _desktop.denseMetricHorizontalPadding;
  double get desktopDenseMetricVerticalPadding => _desktop.denseMetricVerticalPadding;
  double get desktopDenseMetricBorderRadius => _desktop.denseMetricBorderRadius;
  double get desktopDenseDeleteButtonSize => _desktop.denseDeleteButtonSize;
  double get desktopTitleFontSize => _desktop.titleFontSize;
  FontWeight get desktopTitleFontWeight => _desktop.titleFontWeight;
  double get desktopTitleLineHeight => _desktop.titleLineHeight;
  double get desktopSubtitleFontSize => _desktop.subtitleFontSize;
  FontWeight get desktopSubtitleFontWeight => _desktop.subtitleFontWeight;
  double get desktopSubtitleLineHeight => _desktop.subtitleLineHeight;
  bool get desktopShowPlatform => _desktop.showPlatform;
  double get desktopPlatformFontSize => _desktop.platformFontSize;
  FontWeight get desktopPlatformFontWeight => _desktop.platformFontWeight;
  double get desktopPlatformBorderRadius => _desktop.platformBorderRadius;
  double get desktopPlatformHorizontalPadding => _desktop.platformHorizontalPadding;
  double get desktopPlatformVerticalPadding => _desktop.platformVerticalPadding;
  bool get desktopShowAudience => _desktop.showAudience;
  bool get desktopShowRecordBadge => _desktop.showRecordBadge;
  bool get desktopShowLiveBadge => _desktop.showLiveBadge;
  double get desktopChipFontSize => _desktop.chipFontSize;
  FontWeight get desktopChipFontWeight => _desktop.chipFontWeight;
  double get desktopChipBorderRadius => _desktop.chipBorderRadius;
  double get desktopChipHorizontalPadding => _desktop.chipHorizontalPadding;
  double get desktopChipVerticalPadding => _desktop.chipVerticalPadding;
  double get desktopMetricFontSize => _desktop.metricFontSize;
  FontWeight get desktopMetricFontWeight => _desktop.metricFontWeight;
  double get desktopMetricHorizontalPadding => _desktop.metricHorizontalPadding;
  double get desktopMetricVerticalPadding => _desktop.metricVerticalPadding;
  double get desktopBadgeRadius => _desktop.metricBorderRadius;
  double get desktopBadgeOpacity => _desktop.badgeOpacity;
  double get desktopMetricBorderWidth => _desktop.metricBorderWidth;
  bool get desktopShowDelete => _desktop.showDelete;
  double get desktopDeleteButtonBorderRadius => _desktop.deleteButtonBorderRadius;
  double get desktopDeleteButtonSize => _desktop.deleteButtonSize;
  double get desktopDeleteButtonPadding => _desktop.deleteButtonPadding;
  bool get desktopShowAsListTile => _desktop.showAsListTile;

  // ===== Desktop Colors =====
  Color get desktopLightCardColor => _desktop.cardBackground ?? Colors.white;
  Color get desktopDarkCardColor => _desktop.cardBackground ?? Colors.grey.shade900;
  Color get desktopLightTitleColor => _desktop.titleColor ?? Colors.black87;
  Color get desktopDarkTitleColor => _desktop.titleColor ?? Colors.white;
  Color get desktopLightSubtitleColor => _desktop.subtitleColor ?? Colors.grey.shade700;
  Color get desktopDarkSubtitleColor => _desktop.subtitleColor ?? Colors.grey.shade400;
  Color get desktopPlatformBackgroundLight => _desktop.platformBackgroundColor ?? Colors.grey.shade200;
  Color get desktopPlatformBackgroundDark => _desktop.platformBackgroundColor ?? Colors.grey.shade800;
  Color get desktopPlatformTextLight => _desktop.platformTextColor ?? Colors.black87;
  Color get desktopPlatformTextDark => _desktop.platformTextColor ?? Colors.white;
  Color get desktopChipBackgroundColor => _desktop.chipBackgroundColor ?? Get.theme.primaryColor;
  Color get desktopChipTextColor => _desktop.chipTextColor;
  Color get desktopBadgeBackground => _desktop.metricBackgroundColor ?? Colors.black.withValues(alpha: 0.48);
  Color get desktopBadgeForeground => _desktop.metricTextColor;
  Color get desktopMetricBorderColor => _desktop.metricBorderColor ?? Get.theme.primaryColor.withValues(alpha: 0.12);
  Color get desktopDeleteButtonBackground => _desktop.deleteButtonBackgroundColor ?? Colors.black54;
  Color get desktopDeleteButtonIconColor => _desktop.deleteButtonIconColor;

  // ============================================================
  // Serialization
  // ============================================================
  Map<String, dynamic> toJson() {
    return {
      'mobilePreset': mobilePreset.value,
      'desktopPreset': desktopPreset.value,
      'mobileConfig': mobileConfigJson.value,
      'desktopConfig': desktopConfigJson.value,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    mobilePreset.value = json['mobilePreset'] ?? RoomCardPreset.normal.key;
    desktopPreset.value = json['desktopPreset'] ?? RoomCardPreset.normal.key;
    mobileConfigJson.value = json['mobileConfig'] ?? {};
    desktopConfigJson.value = json['desktopConfig'] ?? {};
    update();
  }

  void updateView() {
    update();
  }
}
