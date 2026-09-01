import 'package:flutter/material.dart';

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
    this.cardElevation = 0,
    this.enableShadow = false,
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
    this.denseAvatarSize = 34,
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
    this.showPlatform = true,
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

  static RoomCardModel compact() {
    return const RoomCardModel(
      preset: RoomCardPreset.compact,
      cardBorderRadius: 12,
      coverBorderRadius: 12,
      cardElevation: 0,
      enableShadow: false,
      titleFontSize: 13,
      denseTitleFontSize: 11,
      subtitleFontSize: 11,
      denseSubtitleFontSize: 10,
      titleLineHeight: 1.1,
      subtitleLineHeight: 1.1,
      contentHorizontalPadding: 8,
      denseContentHorizontalPadding: 6,
      contentVerticalPadding: 4,
      denseContentVerticalPadding: 3,
      horizontalTitleGap: 8,
      denseHorizontalTitleGap: 6,
      avatarSize: 28,
      denseAvatarSize: 24,
      showAvatar: true,
      platformFontSize: 10,
      densePlatformFontSize: 9,
      showPlatform: true,
      showAudience: true,
      chipFontSize: 11,
      denseChipFontSize: 10,
      chipHorizontalPadding: 8,
      denseChipHorizontalPadding: 6,
      chipVerticalPadding: 4,
      denseChipVerticalPadding: 3,
      showRecordBadge: true,
      showLiveBadge: true,
      metricFontSize: 10,
      denseMetricFontSize: 9,
      metricHorizontalPadding: 4,
      denseMetricHorizontalPadding: 3,
      metricVerticalPadding: 3,
      denseMetricVerticalPadding: 2,
      metricBorderRadius: 8,
      denseMetricBorderRadius: 6,
      badgeOpacity: 0.6,
      showDelete: true,
      showSubtitle: true,
      coverAspectRatio: 16 / 9,
      cacheCover: true,
      denseMode: true,
      showAsListTile: false,
    );
  }

  static RoomCardModel normal() {
    return const RoomCardModel(
      preset: RoomCardPreset.normal,
      cardBorderRadius: 20,
      coverBorderRadius: 20,
      cardElevation: 0,
      enableShadow: false,
      titleFontSize: 15,
      denseTitleFontSize: 13,
      subtitleFontSize: 13,
      denseSubtitleFontSize: 12,
      titleLineHeight: 1.2,
      subtitleLineHeight: 1.2,
      contentHorizontalPadding: 12,
      denseContentHorizontalPadding: 10,
      contentVerticalPadding: 6,
      denseContentVerticalPadding: 4,
      horizontalTitleGap: 12,
      denseHorizontalTitleGap: 8,
      avatarSize: 40,
      denseAvatarSize: 34,
      showAvatar: true,
      platformFontSize: 11,
      densePlatformFontSize: 10,
      showPlatform: true,
      showAudience: true,
      chipFontSize: 13,
      denseChipFontSize: 12,
      chipHorizontalPadding: 12,
      denseChipHorizontalPadding: 10,
      chipVerticalPadding: 6,
      denseChipVerticalPadding: 4,
      showRecordBadge: true,
      showLiveBadge: true,
      metricFontSize: 12,
      denseMetricFontSize: 11,
      metricHorizontalPadding: 8,
      denseMetricHorizontalPadding: 6,
      metricVerticalPadding: 5,
      denseMetricVerticalPadding: 4,
      metricBorderRadius: 12,
      denseMetricBorderRadius: 10,
      badgeOpacity: 0.48,
      showDelete: true,
      showSubtitle: true,
      coverAspectRatio: 16 / 9,
      cacheCover: true,
      denseMode: false,
      showAsListTile: false,
    );
  }

  static RoomCardModel rich() {
    return const RoomCardModel(
      preset: RoomCardPreset.rich,
      cardBorderRadius: 24,
      coverBorderRadius: 24,
      cardElevation: 4,
      enableShadow: true,
      titleFontSize: 17,
      denseTitleFontSize: 15,
      subtitleFontSize: 14,
      denseSubtitleFontSize: 13,
      titleLineHeight: 1.4,
      subtitleLineHeight: 1.3,
      contentHorizontalPadding: 16,
      denseContentHorizontalPadding: 14,
      contentVerticalPadding: 10,
      denseContentVerticalPadding: 8,
      horizontalTitleGap: 14,
      denseHorizontalTitleGap: 12,
      avatarSize: 48,
      denseAvatarSize: 42,
      showAvatar: true,
      platformFontSize: 12,
      densePlatformFontSize: 11,
      showPlatform: true,
      showAudience: true,
      chipFontSize: 14,
      denseChipFontSize: 13,
      chipHorizontalPadding: 14,
      denseChipHorizontalPadding: 12,
      chipVerticalPadding: 8,
      denseChipVerticalPadding: 6,
      showRecordBadge: true,
      showLiveBadge: true,
      metricFontSize: 13,
      denseMetricFontSize: 12,
      metricHorizontalPadding: 10,
      denseMetricHorizontalPadding: 8,
      metricVerticalPadding: 6,
      denseMetricVerticalPadding: 5,
      metricBorderRadius: 14,
      denseMetricBorderRadius: 12,
      badgeOpacity: 0.35,
      showDelete: true,
      showSubtitle: true,
      coverAspectRatio: 16 / 9,
      cacheCover: true,
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
}
