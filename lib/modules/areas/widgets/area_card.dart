import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/plugins/area_pic_mapper.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      final epoch = SettingsService.to.cache.imageCacheEpoch.v;
      return LayoutBuilder(
        builder: (context, constraints) {
          final logicalWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 160.0;
          final cacheWidth = (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round().clamp(160, 640).toInt();
          return CachedNetworkImage(
            key: ValueKey('$imageUrl#$epoch'),
            cacheKey: imageUrl,
            imageUrl: imageUrl,
            httpHeaders: networkImageHeaders(imageUrl),
            cacheManager: CustomImageCacheManager.instance,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            memCacheWidth: cacheWidth,
            maxWidthDiskCache: 640,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
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
              aspectRatio: 0.9,
              child: Card(
                margin: const EdgeInsets.all(0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                clipBehavior: Clip.antiAlias,
                color: Colors.white,

                child: displayImageUrl.isNotEmpty
                    ? _buildNetworkImage(displayImageUrl)
                    : const Icon(Icons.live_tv_rounded, color: Colors.black, size: 38),
              ),
            ),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              title: Text(
                widget.category.areaName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                widget.category.typeName!,
                style: AppTextStyles.t11.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
