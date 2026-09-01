import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/common/widgets/common_avatar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_model.dart';

class RoomCardRenderer {
  const RoomCardRenderer({
    required this.room,
    required this.config,
    this.dense = false,
    this.statusPending = false,
    this.statusPendingLabel,
    this.showDelete = false,
    this.onDelete,
    this.onTap,
    this.onLongPress,
    this.debug = false,
  });

  final LiveRoom room;
  final RoomCardModel config;
  final bool dense;
  final bool statusPending;
  final String? statusPendingLabel;
  final bool showDelete;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool debug;

  bool get isDense => dense || config.denseMode;

  bool get isSmallScreen {
    final width = Get.width;
    return width < 680;
  }

  bool get effectiveDense => isDense || isSmallScreen;

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveDense = this.effectiveDense;

    if (config.showAsListTile) {
      return _buildListTileOnly(context, isDark, effectiveDense);
    }

    return Card(
      margin: config.cardMargin,
      elevation: config.enableShadow ? config.cardElevation : 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(config.cardBorderRadius)),
      color: config.cardBackground ?? (isDark ? Colors.grey[900] : Colors.white),
      child: InkWell(
        borderRadius: BorderRadius.circular(config.cardBorderRadius),
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCover(context, isDark, effectiveDense),
            if (config.showAvatar || config.showSubtitle || config.showPlatform)
              _buildInfo(context, isDark, effectiveDense),
          ],
        ),
      ),
    );
  }

  Widget _buildListTileOnly(BuildContext context, bool isDark, bool effectiveDense) {
    final titleStyle = TextStyle(
      fontSize: effectiveDense ? config.denseTitleFontSize : config.titleFontSize,
      fontWeight: config.titleFontWeight,
      color: config.titleColor ?? (isDark ? Colors.white : Colors.black87),
      height: config.titleLineHeight,
    );

    final subtitleStyle = TextStyle(
      fontSize: effectiveDense ? config.denseSubtitleFontSize : config.subtitleFontSize,
      fontWeight: config.subtitleFontWeight,
      color: config.subtitleColor ?? (isDark ? Colors.grey[400] : Colors.grey[700]),
      height: config.subtitleLineHeight,
    );

    return Card(
      margin: config.cardMargin,
      elevation: config.enableShadow ? config.cardElevation : 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(config.cardBorderRadius)),
      color: config.cardBackground ?? (isDark ? Colors.grey[900] : Colors.white),
      child: InkWell(
        borderRadius: BorderRadius.circular(config.cardBorderRadius),
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        child: ListTile(
          dense: effectiveDense,
          minLeadingWidth: config.showAvatar ? (effectiveDense ? config.denseAvatarSize : config.avatarSize) : 0,
          contentPadding: EdgeInsets.symmetric(
            horizontal: effectiveDense ? config.denseContentHorizontalPadding : config.contentHorizontalPadding,
            vertical: effectiveDense ? config.denseContentVerticalPadding : config.contentVerticalPadding,
          ),
          horizontalTitleGap: config.showAvatar
              ? (effectiveDense ? config.denseHorizontalTitleGap : config.horizontalTitleGap)
              : 0,
          leading: config.showAvatar
              ? CommonAvatar(avatarUrl: room.avatar, fallbackName: room.nick, dense: effectiveDense)
              : null,
          title: Text(room.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
          subtitle: config.showSubtitle
              ? Text(room.nick ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: subtitleStyle)
              : null,
          trailing: _buildListTileTrailing(context, isDark, effectiveDense),
        ),
      ),
    );
  }

  Widget _buildListTileTrailing(BuildContext context, bool isDark, bool effectiveDense) {
    if (showDelete && config.showDelete) {
      return GestureDetector(
        onTap: onDelete,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.all(config.deleteButtonPadding),
          decoration: BoxDecoration(
            color: config.deleteButtonBackgroundColor ?? Colors.black.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            RemixIcons.delete_bin_line,
            color: config.deleteButtonIconColor,
            size: effectiveDense ? config.denseDeleteButtonSize : config.deleteButtonSize,
          ),
        ),
      );
    }

    if (statusPending) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: effectiveDense ? 8 : 10, vertical: effectiveDense ? 4 : 6),
        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
            const SizedBox(width: 6),
            Text(
              statusPendingLabel ?? i18n('favorite_status_verifying'),
              style: TextStyle(fontSize: effectiveDense ? 10 : 12, color: Colors.orange, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (room.isLiveNow) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: effectiveDense ? 8 : 10, vertical: effectiveDense ? 4 : 6),
        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              i18n('live'),
              style: TextStyle(fontSize: effectiveDense ? 10 : 12, color: Colors.green, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCover(BuildContext context, bool isDark, bool effectiveDense) {
    final showRecordBadge = room.isRecord == true && config.showRecordBadge;
    final showDeleteButton = showDelete && config.showDelete;
    final showAudienceBadge = room.isLiveNow && config.showLiveBadge && config.showAudience && !statusPending;

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: config.coverAspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(config.coverBorderRadius),
            child: ColoredBox(
              color: config.coverPlaceholderColor ?? (isDark ? Colors.grey[850]! : Colors.grey.shade100),
              child: _buildCoverImage(context, isDark, effectiveDense),
            ),
          ),
        ),
        if (config.showPlatform && room.platform != null && room.platform!.isNotEmpty)
          Positioned(
            left: config.coverPositionPadding,
            top: config.coverPositionPadding,
            child: context.buildPlatformTag(room.platform!, mini: true),
          )
        else if (debug)
          _buildDebugMarker(
            context,
            key: 'platform',
            left: config.coverPositionPadding,
            top: config.coverPositionPadding,
          ),
        if (showRecordBadge)
          Positioned(
            right: showDeleteButton ? config.coverPositionPadding + 32 : config.coverPositionPadding,
            top: config.coverPositionPadding,
            child: CountChip(
              icon: Icons.videocam_rounded,
              count: i18n('replay'),
              dense: effectiveDense,
              color: config.chipBackgroundColor ?? Theme.of(context).primaryColor,
              textColor: config.chipTextColor,
              fontSize: effectiveDense ? config.denseChipFontSize : config.chipFontSize,
              fontWeight: config.chipFontWeight,
              horizontalPadding: effectiveDense ? config.denseChipHorizontalPadding : config.chipHorizontalPadding,
              verticalPadding: effectiveDense ? config.denseChipVerticalPadding : config.chipVerticalPadding,
            ),
          )
        else if (debug && room.isRecord == true)
          _buildDebugMarker(
            context,
            key: 'record',
            right: showDeleteButton ? config.coverPositionPadding + 32 : config.coverPositionPadding,
            top: config.coverPositionPadding,
          ),
        if (showDeleteButton)
          Positioned(
            right: config.coverPositionPadding,
            top: config.coverPositionPadding,
            child: _buildDeleteButton(effectiveDense),
          )
        else if (debug && showDelete)
          _buildDebugMarker(
            context,
            key: 'delete',
            right: config.coverPositionPadding,
            top: config.coverPositionPadding,
          ),
        if (statusPending)
          Positioned(
            right: config.coverPositionPadding,
            bottom: config.coverPositionPadding,
            child: CoverMetricBadge(
              icon: Icons.sync_rounded,
              value: statusPendingLabel ?? i18n('favorite_status_verifying'),
              semanticLabel: statusPendingLabel ?? i18n('favorite_status_verifying'),
              dense: effectiveDense,
              backgroundColor: config.metricBackgroundColor,
              borderColor: config.metricBorderColor,
              borderWidth: config.metricBorderWidth,
              textColor: config.metricTextColor,
              fontSize: effectiveDense ? config.denseMetricFontSize : config.metricFontSize,
              fontWeight: config.metricFontWeight,
              borderRadius: effectiveDense ? config.denseMetricBorderRadius : config.metricBorderRadius,
              horizontalPadding: effectiveDense ? config.denseMetricHorizontalPadding : config.metricHorizontalPadding,
              verticalPadding: effectiveDense ? config.denseMetricVerticalPadding : config.metricVerticalPadding,
            ),
          )
        else if (showAudienceBadge)
          Positioned(
            right: config.coverPositionPadding,
            bottom: config.coverPositionPadding,
            child: _buildAudienceBadge(context, effectiveDense),
          )
        else if (debug && room.isLiveNow)
          _buildDebugMarker(
            context,
            key: 'audience',
            right: config.coverPositionPadding,
            bottom: config.coverPositionPadding,
          ),
      ],
    );
  }

  Widget _buildDebugMarker(
    BuildContext context, {
    required String key,
    double? left,
    double? right,
    double? top,
    double? bottom,
  }) {
    if (!debug) return const SizedBox.shrink();

    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: _DebugFlash(keyName: key),
    );
  }

  Widget _buildCoverImage(BuildContext context, bool isDark, bool effectiveDense) {
    final cover = room.cover ?? '';
    final coverUrl = normalizeNetworkImageUrl(cover);

    if (_isAsset(cover)) {
      return _buildAssetCover(context, cover, isDark, effectiveDense);
    }

    if (coverUrl.isEmpty) {
      return _coverFallback(context, isDark);
    }

    if (config.cacheCover) {
      return _buildCachedCover(context, coverUrl, isDark, effectiveDense);
    }

    return _buildDirectCover(context, coverUrl, isDark, effectiveDense);
  }

  bool _isAsset(String value) {
    return value.startsWith('assets/') ||
        value.startsWith('asset/') ||
        value.endsWith('.png') ||
        value.endsWith('.jpg') ||
        value.endsWith('.jpeg') ||
        value.endsWith('.webp');
  }

  Widget _buildAssetCover(BuildContext context, String asset, bool isDark, bool effectiveDense) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width / 2;

        final cacheWidth = (width * MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(config.coverCacheMinWidth, config.coverCacheMaxWidth)
            .toInt();

        return Image.asset(
          asset,
          fit: config.coverFit,
          filterQuality: config.coverFilterQuality,
          cacheWidth: cacheWidth,
          errorBuilder: (_, _, _) {
            return _coverFallback(context, isDark);
          },
        );
      },
    );
  }

  Widget _buildCachedCover(BuildContext context, String coverUrl, bool isDark, bool effectiveDense) {
    return Obx(() {
      final epoch = SettingsService.to.cache.imageCacheEpoch.value;

      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width / 2;

          final cacheWidth = (width * MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(config.coverCacheMinWidth, config.coverCacheMaxWidth)
              .toInt();

          return CachedNetworkImage(
            imageUrl: coverUrl,
            cacheKey: epoch == 0 ? coverUrl : '$coverUrl#$epoch',
            httpHeaders: networkImageHeaders(coverUrl),
            cacheManager: CustomImageCacheManager.instance,
            fit: config.coverFit,
            filterQuality: config.coverFilterQuality,
            memCacheWidth: cacheWidth,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            useOldImageOnUrlChange: true,
            placeholder: (_, _) {
              return _coverPlaceholder(context, isDark);
            },
            errorWidget: (_, _, _) {
              return _coverFallback(context, isDark);
            },
          );
        },
      );
    });
  }

  Widget _buildDirectCover(BuildContext context, String coverUrl, bool isDark, bool effectiveDense) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width / 2;

        final cacheWidth = (width * MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(config.coverCacheMinWidth, config.coverCacheMaxWidth)
            .toInt();

        return Image.network(
          coverUrl,
          fit: config.coverFit,
          filterQuality: config.coverFilterQuality,
          cacheWidth: cacheWidth,
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }

            return _coverPlaceholder(context, isDark);
          },
          errorBuilder: (_, _, _) {
            return _coverFallback(context, isDark);
          },
        );
      },
    );
  }

  Widget _coverPlaceholder(BuildContext context, bool isDark) {
    return Container(
      color: config.coverPlaceholderColor ?? (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
      child: Center(child: Icon(Icons.live_tv_rounded, size: 24, color: isDark ? Colors.white24 : Colors.black12)),
    );
  }

  Widget _coverFallback(BuildContext context, bool isDark) {
    return Container(
      color: config.coverFallbackColor ?? (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
      child: AppStatusView(type: AppStatusType.error, title: '', subtitle: '', isMini: true),
    );
  }

  Widget _buildAudienceBadge(BuildContext context, bool effectiveDense) {
    return Obx(() {
      final app = SettingsService.to.app;

      final preferReal = app.preferRealOnlineCounts.v;
      final platformEnabled = app.isRealOnlineEnabledFor(room.platform);

      final type = room.audienceType(preferRealOnline: preferReal, platformEnabled: platformEnabled);
      final value = room.audienceValue(preferRealOnline: preferReal, platformEnabled: platformEnabled);

      final labelKey = switch (type) {
        AudienceMetricType.popularity => 'audience_popularity',
        AudienceMetricType.onlineViewers => 'audience_online',
        AudienceMetricType.totalViewers => 'audience_total',
        AudienceMetricType.followers => 'audience_followers',
        AudienceMetricType.unknown => 'audience_count',
      };

      final displayValue = value.isEmpty ? i18n('audience_waiting') : readableCount(value);

      final icon = switch (type) {
        AudienceMetricType.onlineViewers => Icons.people_alt_rounded,
        AudienceMetricType.followers => Icons.favorite_rounded,
        AudienceMetricType.totalViewers => Icons.visibility_rounded,
        _ => Icons.whatshot_rounded,
      };

      return CoverMetricBadge(
        key: const ValueKey('cover-audience-metric'),
        icon: icon,
        value: displayValue,
        semanticLabel: '${i18n(labelKey)} $displayValue',
        dense: effectiveDense,
        backgroundColor: config.metricBackgroundColor,
        borderColor: config.metricBorderColor,
        borderWidth: config.metricBorderWidth,
        textColor: config.metricTextColor,
        fontSize: effectiveDense ? config.denseMetricFontSize : config.metricFontSize,
        fontWeight: config.metricFontWeight,
        borderRadius: effectiveDense ? config.denseMetricBorderRadius : config.metricBorderRadius,
        horizontalPadding: effectiveDense ? config.denseMetricHorizontalPadding : config.metricHorizontalPadding,
        verticalPadding: effectiveDense ? config.denseMetricVerticalPadding : config.metricVerticalPadding,
      );
    });
  }

  Widget _buildDeleteButton(bool effectiveDense) {
    return GestureDetector(
      onTap: onDelete,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(config.deleteButtonPadding),
        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: Icon(
          RemixIcons.delete_bin_line,
          color: config.deleteButtonIconColor,
          size: effectiveDense ? config.denseDeleteButtonSize : config.deleteButtonSize,
        ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context, bool isDark, bool effectiveDense) {
    final titleStyle = TextStyle(
      fontSize: effectiveDense ? config.denseTitleFontSize : config.titleFontSize,
      fontWeight: config.titleFontWeight,
      color: config.titleColor ?? (isDark ? Colors.white : Colors.black87),
      height: config.titleLineHeight,
    );

    final subtitleStyle = TextStyle(
      fontSize: effectiveDense ? config.denseSubtitleFontSize : config.subtitleFontSize,
      fontWeight: config.subtitleFontWeight,
      color: config.subtitleColor ?? (isDark ? Colors.grey[400] : Colors.grey[700]),
      height: config.subtitleLineHeight,
    );

    return ListTile(
      dense: effectiveDense,
      minLeadingWidth: config.showAvatar ? (effectiveDense ? config.denseAvatarSize : config.avatarSize) : 0,
      contentPadding: EdgeInsets.symmetric(
        horizontal: effectiveDense ? config.denseContentHorizontalPadding : config.contentHorizontalPadding,
        vertical: effectiveDense ? config.denseContentVerticalPadding : config.contentVerticalPadding,
      ),
      horizontalTitleGap: config.showAvatar
          ? (effectiveDense ? config.denseHorizontalTitleGap : config.horizontalTitleGap)
          : 0,
      leading: config.showAvatar
          ? CommonAvatar(avatarUrl: room.avatar, fallbackName: room.nick, dense: effectiveDense)
          : null,
      title: Text(room.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
      subtitle: config.showSubtitle
          ? Text(room.nick ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: subtitleStyle)
          : null,
    );
  }
}

class _DebugFlash extends StatefulWidget {
  const _DebugFlash({required this.keyName});

  final String keyName;

  @override
  State<_DebugFlash> createState() => _DebugFlashState();
}

class _DebugFlashState extends State<_DebugFlash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.keyName,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

class CountChip extends StatelessWidget {
  const CountChip({
    super.key,
    required this.icon,
    required this.count,
    required this.color,
    this.dense = false,
    this.textColor = Colors.white,
    this.fontSize,
    this.fontWeight = FontWeight.w600,
    this.horizontalPadding,
    this.verticalPadding,
  });

  final IconData icon;
  final String count;
  final Color color;
  final bool dense;
  final Color textColor;
  final double? fontSize;
  final FontWeight fontWeight;
  final double? horizontalPadding;
  final double? verticalPadding;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: const StadiumBorder(),
      color: color,
      shadowColor: Colors.transparent,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding ?? (dense ? 10 : 12),
          vertical: verticalPadding ?? (dense ? 4 : 6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: dense ? 16 : 18),
            const SizedBox(width: 4),
            Text(
              count,
              style: TextStyle(fontSize: fontSize ?? (dense ? 12 : 13), color: textColor, fontWeight: fontWeight),
            ),
          ],
        ),
      ),
    );
  }
}

class CoverMetricBadge extends StatelessWidget {
  const CoverMetricBadge({
    super.key,
    required this.icon,
    required this.value,
    required this.semanticLabel,
    this.dense = false,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0.6,
    this.textColor = Colors.white,
    this.fontSize,
    this.fontWeight = FontWeight.w700,
    this.borderRadius,
    this.horizontalPadding,
    this.verticalPadding,
  });

  final IconData icon;
  final String value;
  final String semanticLabel;
  final bool dense;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final Color textColor;
  final double? fontSize;
  final FontWeight fontWeight;
  final double? borderRadius;
  final double? horizontalPadding;
  final double? verticalPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final background =
        backgroundColor ??
        (theme.brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.58)
            : Colors.black.withValues(alpha: 0.48));

    return Tooltip(
      message: semanticLabel,
      child: Semantics(
        label: semanticLabel,
        container: true,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding ?? (dense ? 6 : 8),
            vertical: verticalPadding ?? (dense ? 4 : 5),
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(borderRadius ?? (dense ? 10 : 12)),
            border: Border.all(color: borderColor ?? theme.primaryColor.withValues(alpha: 0.12), width: borderWidth),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor, size: dense ? 14 : 16),
              SizedBox(width: dense ? 4 : 5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  fontSize: fontSize ?? (dense ? 11 : 12),
                  color: textColor,
                  fontWeight: fontWeight,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
