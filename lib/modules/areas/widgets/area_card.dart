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

  @override
  Widget build(BuildContext context) {
    final displayImageUrl = _getFinalUrl();

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
              avatar:
                  'https://img95.699pic.com/xsj/0q/x6/7p.jpg%21/fw/700/watermark/url/L3hzai93YXRlcl9kZXRhaWwyLnBuZw/align/southeast',
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
              aspectRatio: 1,
              child: Card(
                margin: const EdgeInsets.all(0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                clipBehavior: Clip.antiAlias,
                color: Colors.white,
                elevation: 0,
                child: displayImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: displayImageUrl,
                        cacheManager: CustomImageCacheManager.instance,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.live_tv_rounded, color: Colors.black, size: 38),
                      )
                    : const Icon(Icons.live_tv_rounded, color: Colors.black, size: 38),
              ),
            ),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              title: Text(
                widget.category.areaName!,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(widget.category.typeName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
