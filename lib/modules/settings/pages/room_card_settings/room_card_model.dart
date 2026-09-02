import 'package:pure_live/common/index.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/common/global/platform_utils.dart';

enum RoomCardViewportPreset {
  mobile('mobile', '移动端'),
  desktop('desktop', '桌面端');

  const RoomCardViewportPreset(this.key, this.label);
  final String key;
  final String label;

  static RoomCardViewportPreset fromWidth(double width) {
    return width < 680 && PlatformUtils.isMobile ? RoomCardViewportPreset.mobile : RoomCardViewportPreset.desktop;
  }

  static RoomCardViewportPreset fromKey(String key) {
    return values.firstWhere((e) => e.key == key, orElse: () => RoomCardViewportPreset.mobile);
  }
}

enum RoomCardPreset {
  compact('compact', '简洁'),
  normal('normal', '正常'),
  rich('rich', '丰富'),
  custom('custom', '自定义');

  const RoomCardPreset(this.key, this.label);

  final String key;
  final String label;

  static RoomCardPreset fromKey(String key) {
    return values.firstWhere((e) => e.key == key, orElse: () => RoomCardPreset.normal);
  }
}

class RoomCardModel {
  const RoomCardModel({
    this.preset = RoomCardPreset.normal,
    this.cardBackground,
    this.cardBorderRadius = 20,
    this.cardElevation = 2,
    this.enableShadow = true,
    this.cardMargin = const EdgeInsets.all(0),
    this.coverAspectRatio = 16 / 9,
    this.coverBorderRadius = 20,
    this.coverPlaceholderColor,
    this.coverFallbackColor,
    this.coverFit = BoxFit.cover,
    this.coverFilterQuality = FilterQuality.low,
    this.coverCacheMinWidth = 240,
    this.coverCacheMaxWidth = 720,
    this.cacheCover = true,
    this.coverPositionPadding = 8,
    this.avatarSize = 40,
    this.denseAvatarSize = 40,
    this.showAvatar = true,
    this.contentHorizontalPadding = 12,
    this.denseContentHorizontalPadding = 10,
    this.contentVerticalPadding = 6,
    this.denseContentVerticalPadding = 4,
    this.horizontalTitleGap = 12,
    this.denseHorizontalTitleGap = 8,
    this.titleFontSize = 15,
    this.denseTitleFontSize = 13,
    this.subtitleFontSize = 13,
    this.denseSubtitleFontSize = 12,
    this.titleFontWeight = FontWeight.w600,
    this.subtitleFontWeight = FontWeight.w500,
    this.titleLineHeight = 1.2,
    this.subtitleLineHeight = 1.2,
    this.titleColor,
    this.subtitleColor,
    this.showSubtitle = true,
    this.platformFontSize = 11,
    this.densePlatformFontSize = 10,
    this.platformFontWeight = FontWeight.w600,
    this.platformBackgroundColor,
    this.platformTextColor,
    this.platformBorderRadius = 8,
    this.platformHorizontalPadding = 8,
    this.platformVerticalPadding = 4,
    this.showPlatform = false,
    this.showAudience = true,
    this.chipFontSize = 13,
    this.denseChipFontSize = 12,
    this.chipFontWeight = FontWeight.w600,
    this.chipHorizontalPadding = 12,
    this.denseChipHorizontalPadding = 10,
    this.chipVerticalPadding = 6,
    this.denseChipVerticalPadding = 4,
    this.chipBorderRadius = 20,
    this.chipBackgroundColor,
    this.chipTextColor = Colors.white,
    this.showRecordBadge = true,
    this.showLiveBadge = true,
    this.metricFontSize = 12,
    this.denseMetricFontSize = 11,
    this.metricFontWeight = FontWeight.w700,
    this.metricHorizontalPadding = 8,
    this.denseMetricHorizontalPadding = 6,
    this.metricVerticalPadding = 5,
    this.denseMetricVerticalPadding = 4,
    this.metricBorderRadius = 12,
    this.denseMetricBorderRadius = 10,
    this.metricBackgroundColor,
    this.metricTextColor = Colors.white,
    this.metricBorderColor,
    this.metricBorderWidth = 0.6,
    this.badgeOpacity = 0.48,
    this.showDelete = true,
    this.deleteButtonBackgroundColor,
    this.deleteButtonPadding = 6,
    this.deleteButtonSize = 18,
    this.denseDeleteButtonSize = 16,
    this.deleteButtonIconColor = Colors.white,
    this.deleteButtonBorderRadius = 999,
    this.denseMode = false,
    this.showAsListTile = false,
  });

  final RoomCardPreset preset;
  final Color? cardBackground;
  final double cardBorderRadius;
  final double cardElevation;
  final bool enableShadow;
  final EdgeInsetsGeometry cardMargin;
  final double coverAspectRatio;
  final double coverBorderRadius;
  final Color? coverPlaceholderColor;
  final Color? coverFallbackColor;
  final BoxFit coverFit;
  final FilterQuality coverFilterQuality;
  final int coverCacheMinWidth;
  final int coverCacheMaxWidth;
  final bool cacheCover;
  final double coverPositionPadding;
  final double avatarSize;
  final double denseAvatarSize;
  final bool showAvatar;
  final double contentHorizontalPadding;
  final double denseContentHorizontalPadding;
  final double contentVerticalPadding;
  final double denseContentVerticalPadding;
  final double horizontalTitleGap;
  final double denseHorizontalTitleGap;
  final double titleFontSize;
  final double denseTitleFontSize;
  final double subtitleFontSize;
  final double denseSubtitleFontSize;
  final FontWeight titleFontWeight;
  final FontWeight subtitleFontWeight;
  final double titleLineHeight;
  final double subtitleLineHeight;
  final Color? titleColor;
  final Color? subtitleColor;
  final bool showSubtitle;
  final double platformFontSize;
  final double densePlatformFontSize;
  final FontWeight platformFontWeight;
  final Color? platformBackgroundColor;
  final Color? platformTextColor;
  final double platformBorderRadius;
  final double platformHorizontalPadding;
  final double platformVerticalPadding;
  final bool showPlatform;
  final bool showAudience;
  final double chipFontSize;
  final double denseChipFontSize;
  final FontWeight chipFontWeight;
  final double chipHorizontalPadding;
  final double denseChipHorizontalPadding;
  final double chipVerticalPadding;
  final double denseChipVerticalPadding;
  final double chipBorderRadius;
  final Color? chipBackgroundColor;
  final Color chipTextColor;
  final bool showRecordBadge;
  final bool showLiveBadge;
  final double metricFontSize;
  final double denseMetricFontSize;
  final FontWeight metricFontWeight;
  final double metricHorizontalPadding;
  final double denseMetricHorizontalPadding;
  final double metricVerticalPadding;
  final double denseMetricVerticalPadding;
  final double metricBorderRadius;
  final double denseMetricBorderRadius;
  final Color? metricBackgroundColor;
  final Color metricTextColor;
  final Color? metricBorderColor;
  final double metricBorderWidth;
  final double badgeOpacity;
  final bool showDelete;
  final Color? deleteButtonBackgroundColor;
  final double deleteButtonPadding;
  final double deleteButtonSize;
  final double denseDeleteButtonSize;
  final Color deleteButtonIconColor;
  final double deleteButtonBorderRadius;
  final bool denseMode;
  final bool showAsListTile;

  double calculateCardHeight(double itemWidth, {bool denseOverride = false, bool smallScreen = false}) {
    final actualDense = denseOverride || denseMode || smallScreen;

    final vp = actualDense ? denseContentVerticalPadding : contentVerticalPadding;
    final avatar = actualDense ? denseAvatarSize : avatarSize;
    final titleFs = actualDense ? denseTitleFontSize : titleFontSize;
    final subtitleFs = actualDense ? denseSubtitleFontSize : subtitleFontSize;

    final titleHeight = titleFs * titleLineHeight;
    final subtitleHeight = showSubtitle ? subtitleFs * subtitleLineHeight : 0.0;
    final subtitleGap = showSubtitle ? (actualDense ? 2.0 : 3.0) : 0.0;
    final textHeight = titleHeight + subtitleGap + subtitleHeight;
    final rowHeight = showAvatar && avatar > textHeight ? avatar : textHeight;

    if (showAsListTile) {
      return vp * 2 + rowHeight;
    }

    final aspectRatio = coverAspectRatio > 0 ? coverAspectRatio : 16 / 9;
    final coverHeight = itemWidth / aspectRatio;

    return coverHeight + vp * 2 + rowHeight;
  }

  static RoomCardModel compact() {
    return const RoomCardModel(
      preset: RoomCardPreset.compact,
      cardBackground: Color(0xfff7f7f8),
      cardBorderRadius: 12,
      cardElevation: 2,
      enableShadow: true,
      cardMargin: EdgeInsets.zero,
      coverAspectRatio: 16 / 9,
      coverBorderRadius: 12,
      coverFit: BoxFit.cover,
      coverFilterQuality: FilterQuality.low,
      coverCacheMinWidth: 240,
      coverCacheMaxWidth: 640,
      cacheCover: false,
      coverPositionPadding: 6,
      avatarSize: 56,
      denseAvatarSize: 50,
      showAvatar: true,
      contentHorizontalPadding: 8,
      denseContentHorizontalPadding: 6,
      contentVerticalPadding: 10,
      denseContentVerticalPadding: 8,
      horizontalTitleGap: 8,
      denseHorizontalTitleGap: 6,
      titleFontSize: 16,
      denseTitleFontSize: 14,
      subtitleFontSize: 14,
      denseSubtitleFontSize: 12,
      titleFontWeight: FontWeight.w600,
      subtitleFontWeight: FontWeight.w400,
      titleLineHeight: 1.15,
      subtitleLineHeight: 1.15,
      titleColor: Color(0xff1f1f22),
      subtitleColor: Color(0xff77777d),
      showSubtitle: true,
      platformFontSize: 10,
      densePlatformFontSize: 9,
      platformFontWeight: FontWeight.w600,
      platformBackgroundColor: Color(0xffe9eaed),
      platformTextColor: Color(0xff55565c),
      platformBorderRadius: 6,
      platformHorizontalPadding: 6,
      platformVerticalPadding: 3,
      showPlatform: false,
      showAudience: true,
      chipFontSize: 11,
      denseChipFontSize: 10,
      chipFontWeight: FontWeight.w600,
      chipHorizontalPadding: 8,
      denseChipHorizontalPadding: 6,
      chipVerticalPadding: 4,
      denseChipVerticalPadding: 3,
      chipBorderRadius: 8,
      chipBackgroundColor: Color(0xffef4444),
      chipTextColor: Colors.white,
      showRecordBadge: true,
      showLiveBadge: true,
      metricFontSize: 10,
      denseMetricFontSize: 9,
      metricFontWeight: FontWeight.w600,
      metricHorizontalPadding: 6,
      denseMetricHorizontalPadding: 4,
      metricVerticalPadding: 3,
      denseMetricVerticalPadding: 2,
      metricBorderRadius: 8,
      denseMetricBorderRadius: 6,
      metricBackgroundColor: Color(0xff222226),
      metricTextColor: Colors.white,
      metricBorderColor: null,
      metricBorderWidth: 0.6,
      badgeOpacity: 0.55,
      showDelete: true,
      deleteButtonBackgroundColor: Color(0x66000000),
      deleteButtonPadding: 5,
      deleteButtonSize: 18,
      denseDeleteButtonSize: 16,
      deleteButtonIconColor: Colors.white,
      deleteButtonBorderRadius: 999,
      denseMode: true,
      showAsListTile: true,
    );
  }

  static RoomCardModel normal() {
    return const RoomCardModel(
      preset: RoomCardPreset.normal,
      cardBackground: Colors.white,
      cardBorderRadius: 18,
      cardElevation: 1,
      enableShadow: true,
      cardMargin: EdgeInsets.zero,
      coverAspectRatio: 16 / 9,
      coverBorderRadius: 18,
      coverFit: BoxFit.cover,
      coverFilterQuality: FilterQuality.low,
      coverCacheMinWidth: 320,
      coverCacheMaxWidth: 720,
      cacheCover: true,
      coverPositionPadding: 8,
      avatarSize: 40,
      denseAvatarSize: 36,
      showAvatar: true,
      contentHorizontalPadding: 12,
      denseContentHorizontalPadding: 10,
      contentVerticalPadding: 7,
      denseContentVerticalPadding: 5,
      horizontalTitleGap: 10,
      denseHorizontalTitleGap: 8,
      titleFontSize: 15,
      denseTitleFontSize: 13,
      subtitleFontSize: 12,
      denseSubtitleFontSize: 11,
      titleFontWeight: FontWeight.w600,
      subtitleFontWeight: FontWeight.w400,
      titleLineHeight: 1.2,
      subtitleLineHeight: 1.2,
      titleColor: Color(0xff1d1d1f),
      subtitleColor: Color(0xff747479),
      showSubtitle: true,
      platformFontSize: 11,
      densePlatformFontSize: 10,
      platformFontWeight: FontWeight.w600,
      platformBackgroundColor: Color(0xffeef2ff),
      platformTextColor: Color(0xff3b5bdb),
      platformBorderRadius: 7,
      platformHorizontalPadding: 7,
      platformVerticalPadding: 3,
      showPlatform: false,
      showAudience: true,
      chipFontSize: 12,
      denseChipFontSize: 11,
      chipFontWeight: FontWeight.w600,
      chipHorizontalPadding: 10,
      denseChipHorizontalPadding: 8,
      chipVerticalPadding: 5,
      denseChipVerticalPadding: 4,
      chipBorderRadius: 10,
      chipBackgroundColor: Color(0xfff03e3e),
      chipTextColor: Colors.white,
      showRecordBadge: true,
      showLiveBadge: true,
      metricFontSize: 11,
      denseMetricFontSize: 10,
      metricFontWeight: FontWeight.w600,
      metricHorizontalPadding: 7,
      denseMetricHorizontalPadding: 5,
      metricVerticalPadding: 4,
      denseMetricVerticalPadding: 3,
      metricBorderRadius: 10,
      denseMetricBorderRadius: 8,
      metricBackgroundColor: Color(0xff000000),
      metricTextColor: Colors.white,
      metricBorderColor: null,
      metricBorderWidth: 0.6,
      badgeOpacity: 0.48,
      showDelete: true,
      deleteButtonBackgroundColor: Color(0x66000000),
      deleteButtonPadding: 6,
      deleteButtonSize: 18,
      denseDeleteButtonSize: 16,
      deleteButtonIconColor: Colors.white,
      deleteButtonBorderRadius: 999,
      denseMode: false,
      showAsListTile: false,
    );
  }

  static RoomCardModel rich() {
    return const RoomCardModel(
      preset: RoomCardPreset.rich,
      cardBackground: Colors.white,
      cardBorderRadius: 22,
      cardElevation: 2,
      enableShadow: true,
      cardMargin: EdgeInsets.zero,
      coverAspectRatio: 16 / 9,
      coverBorderRadius: 22,
      coverFit: BoxFit.cover,
      coverFilterQuality: FilterQuality.medium,
      coverCacheMinWidth: 360,
      coverCacheMaxWidth: 960,
      cacheCover: true,
      coverPositionPadding: 10,
      avatarSize: 44,
      denseAvatarSize: 40,
      showAvatar: true,
      contentHorizontalPadding: 16,
      denseContentHorizontalPadding: 14,
      contentVerticalPadding: 10,
      denseContentVerticalPadding: 8,
      horizontalTitleGap: 12,
      denseHorizontalTitleGap: 10,
      titleFontSize: 15,
      denseTitleFontSize: 13,
      subtitleFontSize: 12,
      denseSubtitleFontSize: 11,
      titleFontWeight: FontWeight.w600,
      subtitleFontWeight: FontWeight.w400,
      titleLineHeight: 1.2,
      subtitleLineHeight: 1.2,
      titleColor: Color(0xff111113),
      subtitleColor: Color(0xff7d7d82),
      showSubtitle: true,
      platformFontSize: 12,
      densePlatformFontSize: 11,
      platformFontWeight: FontWeight.w600,
      platformBackgroundColor: Color(0xffe8f4ff),
      platformTextColor: Color(0xff1677ff),
      platformBorderRadius: 8,
      platformHorizontalPadding: 8,
      platformVerticalPadding: 4,
      showPlatform: true,
      showAudience: true,
      chipFontSize: 13,
      denseChipFontSize: 12,
      chipFontWeight: FontWeight.w600,
      chipHorizontalPadding: 12,
      denseChipHorizontalPadding: 10,
      chipVerticalPadding: 6,
      denseChipVerticalPadding: 5,
      chipBorderRadius: 12,
      chipBackgroundColor: Color(0xffe03131),
      chipTextColor: Colors.white,
      showRecordBadge: true,
      showLiveBadge: true,
      metricFontSize: 12,
      denseMetricFontSize: 11,
      metricFontWeight: FontWeight.w700,
      metricHorizontalPadding: 9,
      denseMetricHorizontalPadding: 7,
      metricVerticalPadding: 5,
      denseMetricVerticalPadding: 4,
      metricBorderRadius: 12,
      denseMetricBorderRadius: 10,
      metricBackgroundColor: Color(0xff151518),
      metricTextColor: Colors.white,
      metricBorderColor: Color(0x33ffffff),
      metricBorderWidth: 0.6,
      badgeOpacity: 0.42,
      showDelete: true,
      deleteButtonBackgroundColor: Color(0x73000000),
      deleteButtonPadding: 7,
      deleteButtonSize: 20,
      denseDeleteButtonSize: 18,
      deleteButtonIconColor: Colors.white,
      deleteButtonBorderRadius: 999,
      denseMode: false,
      showAsListTile: false,
    );
  }

  static RoomCardModel custom() {
    return const RoomCardModel(preset: RoomCardPreset.custom);
  }

  static RoomCardModel fromPreset(RoomCardPreset preset) {
    switch (preset) {
      case RoomCardPreset.compact:
        return compact();
      case RoomCardPreset.normal:
        return normal();
      case RoomCardPreset.rich:
        return rich();
      case RoomCardPreset.custom:
        return custom();
    }
  }

  RoomCardModel copyWith({
    RoomCardPreset? preset,
    Color? cardBackground,
    double? cardBorderRadius,
    double? cardElevation,
    bool? enableShadow,
    EdgeInsetsGeometry? cardMargin,
    double? coverAspectRatio,
    double? coverBorderRadius,
    Color? coverPlaceholderColor,
    Color? coverFallbackColor,
    BoxFit? coverFit,
    FilterQuality? coverFilterQuality,
    int? coverCacheMinWidth,
    int? coverCacheMaxWidth,
    bool? cacheCover,
    double? coverPositionPadding,
    double? avatarSize,
    double? denseAvatarSize,
    bool? showAvatar,
    double? contentHorizontalPadding,
    double? denseContentHorizontalPadding,
    double? contentVerticalPadding,
    double? denseContentVerticalPadding,
    double? horizontalTitleGap,
    double? denseHorizontalTitleGap,
    double? titleFontSize,
    double? denseTitleFontSize,
    double? subtitleFontSize,
    double? denseSubtitleFontSize,
    FontWeight? titleFontWeight,
    FontWeight? subtitleFontWeight,
    double? titleLineHeight,
    double? subtitleLineHeight,
    Color? titleColor,
    Color? subtitleColor,
    bool? showSubtitle,
    double? platformFontSize,
    double? densePlatformFontSize,
    FontWeight? platformFontWeight,
    Color? platformBackgroundColor,
    Color? platformTextColor,
    double? platformBorderRadius,
    double? platformHorizontalPadding,
    double? platformVerticalPadding,
    bool? showPlatform,
    bool? showAudience,
    double? chipFontSize,
    double? denseChipFontSize,
    FontWeight? chipFontWeight,
    double? chipHorizontalPadding,
    double? denseChipHorizontalPadding,
    double? chipVerticalPadding,
    double? denseChipVerticalPadding,
    double? chipBorderRadius,
    Color? chipBackgroundColor,
    Color? chipTextColor,
    bool? showRecordBadge,
    bool? showLiveBadge,
    double? metricFontSize,
    double? denseMetricFontSize,
    FontWeight? metricFontWeight,
    double? metricHorizontalPadding,
    double? denseMetricHorizontalPadding,
    double? metricVerticalPadding,
    double? denseMetricVerticalPadding,
    double? metricBorderRadius,
    double? denseMetricBorderRadius,
    Color? metricBackgroundColor,
    Color? metricTextColor,
    Color? metricBorderColor,
    double? metricBorderWidth,
    double? badgeOpacity,
    bool? showDelete,
    Color? deleteButtonBackgroundColor,
    double? deleteButtonPadding,
    double? deleteButtonSize,
    double? denseDeleteButtonSize,
    Color? deleteButtonIconColor,
    double? deleteButtonBorderRadius,
    bool? denseMode,
    bool? showAsListTile,
  }) {
    return RoomCardModel(
      preset: preset ?? this.preset,
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorderRadius: cardBorderRadius ?? this.cardBorderRadius,
      cardElevation: cardElevation ?? this.cardElevation,
      enableShadow: enableShadow ?? this.enableShadow,
      cardMargin: cardMargin ?? this.cardMargin,
      coverAspectRatio: coverAspectRatio ?? this.coverAspectRatio,
      coverBorderRadius: coverBorderRadius ?? this.coverBorderRadius,
      coverPlaceholderColor: coverPlaceholderColor ?? this.coverPlaceholderColor,
      coverFallbackColor: coverFallbackColor ?? this.coverFallbackColor,
      coverFit: coverFit ?? this.coverFit,
      coverFilterQuality: coverFilterQuality ?? this.coverFilterQuality,
      coverCacheMinWidth: coverCacheMinWidth ?? this.coverCacheMinWidth,
      coverCacheMaxWidth: coverCacheMaxWidth ?? this.coverCacheMaxWidth,
      cacheCover: cacheCover ?? this.cacheCover,
      coverPositionPadding: coverPositionPadding ?? this.coverPositionPadding,
      avatarSize: avatarSize ?? this.avatarSize,
      denseAvatarSize: denseAvatarSize ?? this.denseAvatarSize,
      showAvatar: showAvatar ?? this.showAvatar,
      contentHorizontalPadding: contentHorizontalPadding ?? this.contentHorizontalPadding,
      denseContentHorizontalPadding: denseContentHorizontalPadding ?? this.denseContentHorizontalPadding,
      contentVerticalPadding: contentVerticalPadding ?? this.contentVerticalPadding,
      denseContentVerticalPadding: denseContentVerticalPadding ?? this.denseContentVerticalPadding,
      horizontalTitleGap: horizontalTitleGap ?? this.horizontalTitleGap,
      denseHorizontalTitleGap: denseHorizontalTitleGap ?? this.denseHorizontalTitleGap,
      titleFontSize: titleFontSize ?? this.titleFontSize,
      denseTitleFontSize: denseTitleFontSize ?? this.denseTitleFontSize,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      denseSubtitleFontSize: denseSubtitleFontSize ?? this.denseSubtitleFontSize,
      titleFontWeight: titleFontWeight ?? this.titleFontWeight,
      subtitleFontWeight: subtitleFontWeight ?? this.subtitleFontWeight,
      titleLineHeight: titleLineHeight ?? this.titleLineHeight,
      subtitleLineHeight: subtitleLineHeight ?? this.subtitleLineHeight,
      titleColor: titleColor ?? this.titleColor,
      subtitleColor: subtitleColor ?? this.subtitleColor,
      showSubtitle: showSubtitle ?? this.showSubtitle,
      platformFontSize: platformFontSize ?? this.platformFontSize,
      densePlatformFontSize: densePlatformFontSize ?? this.densePlatformFontSize,
      platformFontWeight: platformFontWeight ?? this.platformFontWeight,
      platformBackgroundColor: platformBackgroundColor ?? this.platformBackgroundColor,
      platformTextColor: platformTextColor ?? this.platformTextColor,
      platformBorderRadius: platformBorderRadius ?? this.platformBorderRadius,
      platformHorizontalPadding: platformHorizontalPadding ?? this.platformHorizontalPadding,
      platformVerticalPadding: platformVerticalPadding ?? this.platformVerticalPadding,
      showPlatform: showPlatform ?? this.showPlatform,
      showAudience: showAudience ?? this.showAudience,
      chipFontSize: chipFontSize ?? this.chipFontSize,
      denseChipFontSize: denseChipFontSize ?? this.denseChipFontSize,
      chipFontWeight: chipFontWeight ?? this.chipFontWeight,
      chipHorizontalPadding: chipHorizontalPadding ?? this.chipHorizontalPadding,
      denseChipHorizontalPadding: denseChipHorizontalPadding ?? this.denseChipHorizontalPadding,
      chipVerticalPadding: chipVerticalPadding ?? this.chipVerticalPadding,
      denseChipVerticalPadding: denseChipVerticalPadding ?? this.denseChipVerticalPadding,
      chipBorderRadius: chipBorderRadius ?? this.chipBorderRadius,
      chipBackgroundColor: chipBackgroundColor ?? this.chipBackgroundColor,
      chipTextColor: chipTextColor ?? this.chipTextColor,
      showRecordBadge: showRecordBadge ?? this.showRecordBadge,
      showLiveBadge: showLiveBadge ?? this.showLiveBadge,
      metricFontSize: metricFontSize ?? this.metricFontSize,
      denseMetricFontSize: denseMetricFontSize ?? this.denseMetricFontSize,
      metricFontWeight: metricFontWeight ?? this.metricFontWeight,
      metricHorizontalPadding: metricHorizontalPadding ?? this.metricHorizontalPadding,
      denseMetricHorizontalPadding: denseMetricHorizontalPadding ?? this.denseMetricHorizontalPadding,
      metricVerticalPadding: metricVerticalPadding ?? this.metricVerticalPadding,
      denseMetricVerticalPadding: denseMetricVerticalPadding ?? this.denseMetricVerticalPadding,
      metricBorderRadius: metricBorderRadius ?? this.metricBorderRadius,
      denseMetricBorderRadius: denseMetricBorderRadius ?? this.denseMetricBorderRadius,
      metricBackgroundColor: metricBackgroundColor ?? this.metricBackgroundColor,
      metricTextColor: metricTextColor ?? this.metricTextColor,
      metricBorderColor: metricBorderColor ?? this.metricBorderColor,
      metricBorderWidth: metricBorderWidth ?? this.metricBorderWidth,
      badgeOpacity: badgeOpacity ?? this.badgeOpacity,
      showDelete: showDelete ?? this.showDelete,
      deleteButtonBackgroundColor: deleteButtonBackgroundColor ?? this.deleteButtonBackgroundColor,
      deleteButtonPadding: deleteButtonPadding ?? this.deleteButtonPadding,
      deleteButtonSize: deleteButtonSize ?? this.deleteButtonSize,
      denseDeleteButtonSize: denseDeleteButtonSize ?? this.denseDeleteButtonSize,
      deleteButtonIconColor: deleteButtonIconColor ?? this.deleteButtonIconColor,
      deleteButtonBorderRadius: deleteButtonBorderRadius ?? this.deleteButtonBorderRadius,
      denseMode: denseMode ?? this.denseMode,
      showAsListTile: showAsListTile ?? this.showAsListTile,
    );
  }

  static RoomCardModel fromController({
    required RoomCardModel config,
    required bool isDark,
    bool dense = false,
    bool showDelete = false,
  }) {
    return RoomCardModel(
      // ===== Card Style =====
      cardBackground: isDark ? config.cardBackground ?? Colors.grey.shade900 : config.cardBackground ?? Colors.white,
      cardBorderRadius: config.cardBorderRadius,
      cardElevation: config.cardElevation,
      enableShadow: config.enableShadow,
      cardMargin: config.cardMargin,

      // ===== Cover Settings =====
      coverAspectRatio: config.coverAspectRatio,
      coverBorderRadius: config.coverBorderRadius,
      coverPlaceholderColor: config.coverPlaceholderColor,
      coverFallbackColor: config.coverFallbackColor,
      coverFit: config.coverFit,
      coverFilterQuality: config.coverFilterQuality,
      coverCacheMinWidth: config.coverCacheMinWidth,
      coverCacheMaxWidth: config.coverCacheMaxWidth,
      cacheCover: config.cacheCover,
      coverPositionPadding: config.coverPositionPadding,

      // ===== Content Layout =====
      avatarSize: config.avatarSize,
      denseAvatarSize: config.denseAvatarSize,
      showAvatar: config.showAvatar,
      contentHorizontalPadding: config.contentHorizontalPadding,
      denseContentHorizontalPadding: config.denseContentHorizontalPadding,
      contentVerticalPadding: config.contentVerticalPadding,
      denseContentVerticalPadding: config.denseContentVerticalPadding,
      horizontalTitleGap: config.horizontalTitleGap,
      denseHorizontalTitleGap: config.denseHorizontalTitleGap,
      showSubtitle: config.showSubtitle,
      denseMode: config.denseMode || dense,

      // ===== Typography =====
      titleFontSize: config.titleFontSize,
      denseTitleFontSize: config.denseTitleFontSize,
      titleFontWeight: config.titleFontWeight,
      titleLineHeight: config.titleLineHeight,
      titleColor: config.titleColor,
      subtitleFontSize: config.subtitleFontSize,
      denseSubtitleFontSize: config.denseSubtitleFontSize,
      subtitleFontWeight: config.subtitleFontWeight,
      subtitleLineHeight: config.subtitleLineHeight,
      subtitleColor: config.subtitleColor,

      // ===== Platform Tag =====
      showPlatform: config.showPlatform,
      platformFontSize: config.platformFontSize,
      densePlatformFontSize: config.densePlatformFontSize,
      platformFontWeight: config.platformFontWeight,
      platformBackgroundColor: config.platformBackgroundColor,
      platformTextColor: config.platformTextColor,
      platformBorderRadius: config.platformBorderRadius,
      platformHorizontalPadding: config.platformHorizontalPadding,
      platformVerticalPadding: config.platformVerticalPadding,

      // ===== Badge Settings =====
      showLiveBadge: config.showLiveBadge,
      showRecordBadge: config.showRecordBadge,
      showAudience: config.showAudience,
      chipFontSize: config.chipFontSize,
      denseChipFontSize: config.denseChipFontSize,
      chipFontWeight: config.chipFontWeight,
      chipBorderRadius: config.chipBorderRadius,
      chipHorizontalPadding: config.chipHorizontalPadding,
      denseChipHorizontalPadding: config.denseChipHorizontalPadding,
      chipVerticalPadding: config.chipVerticalPadding,
      denseChipVerticalPadding: config.denseChipVerticalPadding,
      chipBackgroundColor: config.chipBackgroundColor,
      chipTextColor: config.chipTextColor,

      // ===== Metric Badge =====
      metricFontSize: config.metricFontSize,
      denseMetricFontSize: config.denseMetricFontSize,
      metricFontWeight: config.metricFontWeight,
      metricBorderRadius: config.metricBorderRadius,
      denseMetricBorderRadius: config.denseMetricBorderRadius,
      badgeOpacity: config.badgeOpacity,
      metricBackgroundColor: config.metricBackgroundColor,
      metricTextColor: config.metricTextColor,
      metricBorderColor: config.metricBorderColor,
      metricBorderWidth: config.metricBorderWidth,
      metricHorizontalPadding: config.metricHorizontalPadding,
      denseMetricHorizontalPadding: config.denseMetricHorizontalPadding,
      metricVerticalPadding: config.metricVerticalPadding,
      denseMetricVerticalPadding: config.denseMetricVerticalPadding,

      // ===== Delete Button =====
      showDelete: config.showDelete && showDelete,
      deleteButtonBackgroundColor: config.deleteButtonBackgroundColor,
      deleteButtonPadding: config.deleteButtonPadding,
      deleteButtonSize: config.deleteButtonSize,
      denseDeleteButtonSize: config.denseDeleteButtonSize,
      deleteButtonIconColor: config.deleteButtonIconColor,
      deleteButtonBorderRadius: config.deleteButtonBorderRadius,

      showAsListTile: config.showAsListTile,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preset': preset.key,
      'cardBackground': cardBackground?.hex,
      'cardBorderRadius': cardBorderRadius,
      'cardElevation': cardElevation,
      'enableShadow': enableShadow,
      'cardMarginHorizontal': cardMargin.horizontal,
      'coverAspectRatio': coverAspectRatio,
      'coverBorderRadius': coverBorderRadius,
      'coverPlaceholderColor': coverPlaceholderColor?.hex,
      'coverFallbackColor': coverFallbackColor?.hex,
      'coverFit': coverFit.name,
      'coverFilterQuality': coverFilterQuality.name,
      'coverCacheMinWidth': coverCacheMinWidth,
      'coverCacheMaxWidth': coverCacheMaxWidth,
      'cacheCover': cacheCover,
      'coverPositionPadding': coverPositionPadding,
      'avatarSize': avatarSize,
      'denseAvatarSize': denseAvatarSize,
      'showAvatar': showAvatar,
      'contentHorizontalPadding': contentHorizontalPadding,
      'denseContentHorizontalPadding': denseContentHorizontalPadding,
      'contentVerticalPadding': contentVerticalPadding,
      'denseContentVerticalPadding': denseContentVerticalPadding,
      'horizontalTitleGap': horizontalTitleGap,
      'denseHorizontalTitleGap': denseHorizontalTitleGap,
      'titleFontSize': titleFontSize,
      'denseTitleFontSize': denseTitleFontSize,
      'subtitleFontSize': subtitleFontSize,
      'denseSubtitleFontSize': denseSubtitleFontSize,
      'titleFontWeight': titleFontWeight.value,
      'subtitleFontWeight': subtitleFontWeight.value,
      'titleLineHeight': titleLineHeight,
      'subtitleLineHeight': subtitleLineHeight,
      'titleColor': titleColor?.hex,
      'subtitleColor': subtitleColor?.hex,
      'showSubtitle': showSubtitle,
      'platformFontSize': platformFontSize,
      'densePlatformFontSize': densePlatformFontSize,
      'platformFontWeight': platformFontWeight.value,
      'platformBackgroundColor': platformBackgroundColor?.hex,
      'platformTextColor': platformTextColor?.hex,
      'platformBorderRadius': platformBorderRadius,
      'platformHorizontalPadding': platformHorizontalPadding,
      'platformVerticalPadding': platformVerticalPadding,
      'showPlatform': showPlatform,
      'showAudience': showAudience,
      'chipFontSize': chipFontSize,
      'denseChipFontSize': denseChipFontSize,
      'chipFontWeight': chipFontWeight.value,
      'chipHorizontalPadding': chipHorizontalPadding,
      'denseChipHorizontalPadding': denseChipHorizontalPadding,
      'chipVerticalPadding': chipVerticalPadding,
      'denseChipVerticalPadding': denseChipVerticalPadding,
      'chipBorderRadius': chipBorderRadius,
      'chipBackgroundColor': chipBackgroundColor?.hex,
      'chipTextColor': chipTextColor.hex,
      'showRecordBadge': showRecordBadge,
      'showLiveBadge': showLiveBadge,
      'metricFontSize': metricFontSize,
      'denseMetricFontSize': denseMetricFontSize,
      'metricFontWeight': metricFontWeight.value,
      'metricHorizontalPadding': metricHorizontalPadding,
      'denseMetricHorizontalPadding': denseMetricHorizontalPadding,
      'metricVerticalPadding': metricVerticalPadding,
      'denseMetricVerticalPadding': denseMetricVerticalPadding,
      'metricBorderRadius': metricBorderRadius,
      'denseMetricBorderRadius': denseMetricBorderRadius,
      'metricBackgroundColor': metricBackgroundColor?.hex,
      'metricTextColor': metricTextColor.hex,
      'metricBorderColor': metricBorderColor?.hex,
      'metricBorderWidth': metricBorderWidth,
      'badgeOpacity': badgeOpacity,
      'showDelete': showDelete,
      'deleteButtonBackgroundColor': deleteButtonBackgroundColor?.hex,
      'deleteButtonPadding': deleteButtonPadding,
      'deleteButtonSize': deleteButtonSize,
      'denseDeleteButtonSize': denseDeleteButtonSize,
      'deleteButtonIconColor': deleteButtonIconColor.hex,
      'deleteButtonBorderRadius': deleteButtonBorderRadius,
      'denseMode': denseMode,
      'showAsListTile': showAsListTile,
    };
  }

  static RoomCardModel fromJson(Map<String, dynamic> json) {
    return RoomCardModel(
      preset: RoomCardPreset.fromKey(json['preset'] as String? ?? RoomCardPreset.normal.key),
      cardBackground: _colorFromJson(json['cardBackground']),
      cardBorderRadius: (json['cardBorderRadius'] as num? ?? 20).toDouble(),
      cardElevation: (json['cardElevation'] as num? ?? 2).toDouble(),
      enableShadow: json['enableShadow'] as bool? ?? true,
      cardMargin: EdgeInsets.all((json['cardMarginHorizontal'] as num? ?? 0).toDouble()),
      coverAspectRatio: (json['coverAspectRatio'] as num? ?? 16 / 9).toDouble(),
      coverBorderRadius: (json['coverBorderRadius'] as num? ?? 20).toDouble(),
      coverPlaceholderColor: _colorFromJson(json['coverPlaceholderColor']),
      coverFallbackColor: _colorFromJson(json['coverFallbackColor']),
      coverFit: _boxFitFromJson(json['coverFit']),
      coverFilterQuality: _filterQualityFromJson(json['coverFilterQuality']),
      coverCacheMinWidth: json['coverCacheMinWidth'] as int? ?? 240,
      coverCacheMaxWidth: json['coverCacheMaxWidth'] as int? ?? 720,
      cacheCover: json['cacheCover'] as bool? ?? true,
      coverPositionPadding: (json['coverPositionPadding'] as num? ?? 8).toDouble(),
      avatarSize: (json['avatarSize'] as num? ?? 40).toDouble(),
      denseAvatarSize: (json['denseAvatarSize'] as num? ?? 40).toDouble(),
      showAvatar: json['showAvatar'] as bool? ?? true,
      contentHorizontalPadding: (json['contentHorizontalPadding'] as num? ?? 12).toDouble(),
      denseContentHorizontalPadding: (json['denseContentHorizontalPadding'] as num? ?? 10).toDouble(),
      contentVerticalPadding: (json['contentVerticalPadding'] as num? ?? 6).toDouble(),
      denseContentVerticalPadding: (json['denseContentVerticalPadding'] as num? ?? 4).toDouble(),
      horizontalTitleGap: (json['horizontalTitleGap'] as num? ?? 12).toDouble(),
      denseHorizontalTitleGap: (json['denseHorizontalTitleGap'] as num? ?? 8).toDouble(),
      titleFontSize: (json['titleFontSize'] as num? ?? 15).toDouble(),
      denseTitleFontSize: (json['denseTitleFontSize'] as num? ?? 13).toDouble(),
      subtitleFontSize: (json['subtitleFontSize'] as num? ?? 13).toDouble(),
      denseSubtitleFontSize: (json['denseSubtitleFontSize'] as num? ?? 12).toDouble(),
      titleFontWeight: _fontWeightFromJson(json['titleFontWeight']),
      subtitleFontWeight: _fontWeightFromJson(json['subtitleFontWeight']),
      titleLineHeight: (json['titleLineHeight'] as num? ?? 1.2).toDouble(),
      subtitleLineHeight: (json['subtitleLineHeight'] as num? ?? 1.2).toDouble(),
      titleColor: _colorFromJson(json['titleColor']),
      subtitleColor: _colorFromJson(json['subtitleColor']),
      showSubtitle: json['showSubtitle'] as bool? ?? true,
      platformFontSize: (json['platformFontSize'] as num? ?? 11).toDouble(),
      densePlatformFontSize: (json['densePlatformFontSize'] as num? ?? 10).toDouble(),
      platformFontWeight: _fontWeightFromJson(json['platformFontWeight']),
      platformBackgroundColor: _colorFromJson(json['platformBackgroundColor']),
      platformTextColor: _colorFromJson(json['platformTextColor']),
      platformBorderRadius: (json['platformBorderRadius'] as num? ?? 8).toDouble(),
      platformHorizontalPadding: (json['platformHorizontalPadding'] as num? ?? 8).toDouble(),
      platformVerticalPadding: (json['platformVerticalPadding'] as num? ?? 4).toDouble(),
      showPlatform: json['showPlatform'] as bool? ?? false,
      showAudience: json['showAudience'] as bool? ?? true,
      chipFontSize: (json['chipFontSize'] as num? ?? 13).toDouble(),
      denseChipFontSize: (json['denseChipFontSize'] as num? ?? 12).toDouble(),
      chipFontWeight: _fontWeightFromJson(json['chipFontWeight']),
      chipHorizontalPadding: (json['chipHorizontalPadding'] as num? ?? 12).toDouble(),
      denseChipHorizontalPadding: (json['denseChipHorizontalPadding'] as num? ?? 10).toDouble(),
      chipVerticalPadding: (json['chipVerticalPadding'] as num? ?? 6).toDouble(),
      denseChipVerticalPadding: (json['denseChipVerticalPadding'] as num? ?? 4).toDouble(),
      chipBorderRadius: (json['chipBorderRadius'] as num? ?? 20).toDouble(),
      chipBackgroundColor: _colorFromJson(json['chipBackgroundColor']),
      chipTextColor: _colorFromJson(json['chipTextColor']) ?? Colors.white,
      showRecordBadge: json['showRecordBadge'] as bool? ?? true,
      showLiveBadge: json['showLiveBadge'] as bool? ?? true,
      metricFontSize: (json['metricFontSize'] as num? ?? 12).toDouble(),
      denseMetricFontSize: (json['denseMetricFontSize'] as num? ?? 11).toDouble(),
      metricFontWeight: _fontWeightFromJson(json['metricFontWeight']),
      metricHorizontalPadding: (json['metricHorizontalPadding'] as num? ?? 8).toDouble(),
      denseMetricHorizontalPadding: (json['denseMetricHorizontalPadding'] as num? ?? 6).toDouble(),
      metricVerticalPadding: (json['metricVerticalPadding'] as num? ?? 5).toDouble(),
      denseMetricVerticalPadding: (json['denseMetricVerticalPadding'] as num? ?? 4).toDouble(),
      metricBorderRadius: (json['metricBorderRadius'] as num? ?? 12).toDouble(),
      denseMetricBorderRadius: (json['denseMetricBorderRadius'] as num? ?? 10).toDouble(),
      metricBackgroundColor: _colorFromJson(json['metricBackgroundColor']),
      metricTextColor: _colorFromJson(json['metricTextColor']) ?? Colors.white,
      metricBorderColor: _colorFromJson(json['metricBorderColor']),
      metricBorderWidth: (json['metricBorderWidth'] as num? ?? 0.6).toDouble(),
      badgeOpacity: (json['badgeOpacity'] as num? ?? 0.48).toDouble(),
      showDelete: json['showDelete'] as bool? ?? true,
      deleteButtonBackgroundColor: _colorFromJson(json['deleteButtonBackgroundColor']),
      deleteButtonPadding: (json['deleteButtonPadding'] as num? ?? 6).toDouble(),
      deleteButtonSize: (json['deleteButtonSize'] as num? ?? 18).toDouble(),
      denseDeleteButtonSize: (json['denseDeleteButtonSize'] as num? ?? 16).toDouble(),
      deleteButtonIconColor: _colorFromJson(json['deleteButtonIconColor']) ?? Colors.white,
      deleteButtonBorderRadius: (json['deleteButtonBorderRadius'] as num? ?? 999).toDouble(),
      denseMode: json['denseMode'] as bool? ?? false,
      showAsListTile: json['showAsListTile'] as bool? ?? false,
    );
  }

  static Color? _colorFromJson(dynamic value) {
    if (value == null) return null;
    if (value is Color) return value;
    if (value is String && value.isNotEmpty) {
      return HexColor(value);
    }
    return null;
  }

  static FontWeight _fontWeightFromJson(dynamic value) {
    if (value == null) return FontWeight.w400;
    if (value is FontWeight) return value;
    if (value is int) {
      return FontWeight.values.firstWhere((e) => e.value == value, orElse: () => FontWeight.w400);
    }
    return FontWeight.w400;
  }

  static BoxFit _boxFitFromJson(String? name) {
    if (name == null) return BoxFit.cover;
    return BoxFit.values.firstWhere((e) => e.name == name, orElse: () => BoxFit.cover);
  }

  static FilterQuality _filterQualityFromJson(String? name) {
    if (name == null) return FilterQuality.low;
    return FilterQuality.values.firstWhere((e) => e.name == name, orElse: () => FilterQuality.low);
  }
}
