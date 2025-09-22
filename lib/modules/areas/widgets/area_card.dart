import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/util/site_logo_widget.dart';
import 'package:pure_live/plugins/cache_network.dart';
import 'package:pure_live/routes/app_navigation.dart';

class AreaCard extends StatefulWidget {
  const AreaCard({super.key, required this.category});

  final LiveArea category;

  @override
  State<AreaCard> createState() => _AreaCardState();
}

// id: widget.category.areaId!, siteTitle: widget.category.areaName!, siteUrl: widget.category.areaType!, siteIsHot: 0)
class _AreaCardState extends State<AreaCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(7.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
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
            AppNavigator.toCategoryDetail(
                site: Sites.of(widget.category.platform!),
                category: widget.category);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(children: [
              AspectRatio(
                aspectRatio: 1,
                child: Card(
                  margin: const EdgeInsets.all(0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  clipBehavior: Clip.antiAlias,
                  // color: Colors.white,
                  elevation: 0,
                  child: CacheNetWorkUtils.getCacheImageV2(
                      widget.category.areaPic!, cacheWidth: 300, cacheHeight: 300),
                ),
              ),

              // 平台图标
              Positioned(
                left: 5,
                top: 5,
                child: SiteWidget.getSiteLogeImage(widget.category.platform!)!,
              ),
            ]),
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
                  Text(
                    widget.category.typeName!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
