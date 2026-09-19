import 'dart:math' as math;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/category_artwork.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/plugins/area_pic_mapper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/core/site/cc/cc_catalog.dart';

/// Keeps the fixed category grid tall enough for both one-line labels when
/// accessibility text scaling is enabled.
///
/// The image remains square. Only the details section grows; otherwise a
/// three-column 320 px layout gives [ListTile] 72 px even when its two text
/// lines need more than 100 px at a 3x scale.
double areaCardGridMainAxisExtent(BuildContext context, double itemWidth) {
  final scaler = MediaQuery.textScalerOf(context);
  final titleStyle = AppTextStyles.t12;
  final subtitleStyle = AppTextStyles.t11;
  final titleHeight = scaler.scale(titleStyle.fontSize ?? 12) * (titleStyle.height ?? 1.25);
  final subtitleHeight = scaler.scale(subtitleStyle.fontSize ?? 11) * (subtitleStyle.height ?? 1.25);
  final detailsHeight = math.max(72.0, titleHeight + subtitleHeight + 32);
  return itemWidth + detailsHeight;
}

class AreaCard extends StatefulWidget {
  const AreaCard({super.key, required this.category});
  final LiveArea category;

  @override
  State<AreaCard> createState() => _AreaCardState();
}

class _AreaCardState extends State<AreaCard> {
  String _getFinalUrl() {
    if (widget.category.areaPic != null && widget.category.areaPic!.isNotEmpty) {
      return widget.category.areaPic!;
    }
    return AreaPicMapper.getPic(widget.category.areaName);
  }

  Widget _buildNetworkImage(String imageUrl) {
    return Obx(() {
      final epoch = SettingsService.to.cache.imageCacheEpoch.value;
      return LayoutBuilder(
        builder: (context, constraints) {
          final logicalWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 160.0;
          final cacheWidth = (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round().clamp(160, 512).toInt();
          return CachedNetworkImage(
            cacheKey: epoch == 0 ? imageUrl : '$imageUrl#$epoch',
            imageUrl: imageUrl,
            httpHeaders: networkImageHeaders(imageUrl),
            cacheManager: CustomImageCacheManager.instance,
            fit: BoxFit.cover,
            alignment: categoryArtworkAlignment(imageUrl),
            filterQuality: FilterQuality.low,
            memCacheWidth: cacheWidth,
            // maxWidthDiskCache: 512,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            useOldImageOnUrlChange: true,
            placeholder: (context, url) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Center(
                child: Icon(Icons.live_tv_rounded, color: Theme.of(context).disabledColor.withValues(alpha: 0.3)),
              ),
            ),
            errorWidget: (context, url, error) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Center(child: Icon(Icons.broken_image_rounded, color: Theme.of(context).disabledColor)),
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayImageUrl = normalizeNetworkImageUrl(_getFinalUrl());
    final officialEntry = CCCatalog.isOfficialEntry(widget.category);
    final rawName = widget.category.areaName?.trim() ?? '';
    final displayName = rawName.isEmpty ? i18n('unnamed_area') : rawName;
    final rawTypeName = widget.category.typeName?.trim() ?? '';
    final displayTypeName = rawTypeName.isEmpty ? i18n('no_data') : rawTypeName;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15.0),
        onTap: () {
          if (widget.category.platform == Sites.iptvSite) {
            var roomItem = LiveRoom(
              roomId: widget.category.areaId,
              title: widget.category.typeName,
              cover: '',
              nick: widget.category.areaName,
              watching: '',
              avatar: 'https://img95.699pic.com/xsj/0q/x6/7p.jpg%21/fw/700/watermark/url/L3hzai93YXRlcl9kZXRhaWwyLnBuZw/align/southeast',
              area: '',
              liveStatus: LiveStatus.live,
              status: true,
              platform: 'iptv',
            );
            AppNavigator.toLiveRoomDetail(liveRoom: roomItem);
          } else {
            AppNavigator.toCategoryDetail(site: Sites.of(widget.category.platform!), category: widget.category);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: ColoredBox(
                  color: Colors.white,
                  child: displayImageUrl.isNotEmpty
                      ? _buildNetworkImage(displayImageUrl)
                      : const Icon(Icons.live_tv_rounded, color: Colors.black, size: 38),
                ),
              ),
            ),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              title: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                officialEntry ? i18n('open_in_system_browser') : displayTypeName,
                style: AppTextStyles.t11.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: officialEntry ? const Icon(Icons.open_in_new_rounded, size: 16) : null,
            ),
          ],
        ),
      ),
    );
  }
}
