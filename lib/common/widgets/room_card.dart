import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/util/site_logo_widget.dart';
import 'package:pure_live/plugins/cache_network.dart';
import 'package:pure_live/plugins/extension/string_extension.dart';
import 'package:pure_live/routes/app_navigation.dart';

// ignore: must_be_immutable
class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.room,
    this.dense = false,
    this.onTap,
  });

  final LiveRoom room;

  /// 密集
  final bool dense;
  final GestureTapCallback? onTap;

  void defaultOnTap(BuildContext context) async {
    AppNavigator.toLiveRoomDetail(liveRoom: room);
  }

  void onLongPress(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: Text(room.title!),
        content: Text(
          S.current.room_info_content(
            room.roomId!,
            room.platform!,
            room.nick!,
            room.title!,
            room.liveStatus!.name,
          ),
        ),
        actions: [FollowButton(room: room)],
      ),
    );
  }

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
          if (onTap == null) {
            defaultOnTap(context);
          } else {
            onTap!();
          }
        },
        onLongPress: () => onLongPress(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Card(
                    margin: const EdgeInsets.all(0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    clipBehavior: Clip.antiAlias,
                    color: Theme.of(context).focusColor,
                    elevation: 0,
                    child: room.liveStatus == LiveStatus.offline && room.cover!.isNotEmpty
                        ? Center(
                            child: Icon(
                              Icons.tv_off_rounded,
                              size: dense ? 36 : 60,
                            ),
                          )
                        : CacheNetWorkUtils.getCacheImageV2(room.cover!),
                  ),
                ),
                if (room.isRecord == true)
                  // 录播标志
                  Positioned(
                    right: dense ? 0 : 2,
                    top: dense ? 0 : 2,
                    child: CountChip(
                      icon: Icons.videocam_rounded,
                      count: S.current.replay,
                      dense: dense,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                // 平台图标
                Positioned(
                  left: dense ? 5 : 7,
                  top: dense ? 5 : 7,
                  child: SiteWidget.getSiteLogeImage(room.platform!)!,
                ),
                // 人气值
                if (room.liveStatus == LiveStatus.live || room.liveStatus == LiveStatus.replay)
                  Positioned(
                    right: dense ? 0 : 2,
                    bottom: dense ? 0 : 2,
                    child: CountChip(
                      icon: Icons.whatshot_rounded,
                      count: readableCount(readableCountStrToNum(room.watching ?? "0").toString()),
                      dense: dense,
                    ),
                  ),
                // 分类
                if (room.area.isNotNullOrEmpty)
                  Positioned(
                    left: dense ? 0 : 2,
                    bottom: dense ? 0 : 2,
                    child: CountChip(
                      // icon: Icons.snowshoeing_rounded,
                      count: room.area ?? "",
                      dense: dense,
                    ),
                  ),
              ],
            ),
            ListTile(
              dense: dense,
              minLeadingWidth: dense ? 34 : null,
              contentPadding: dense ? const EdgeInsets.only(left: 8, right: 10) : null,
              horizontalTitleGap: dense ? 8 : null,
              leading: CacheNetWorkUtils.getCircleAvatar(room.avatar, radius: 17),
              title: Text(
                room.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: dense ? 12.5 : 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                room.nick ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: dense ? 12 : 14,
                ),
              ),
              trailing: dense
                  ? null
                  : Text(
                      room.platform != null ? Sites.of(room.platform!).name : '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
            )
          ],
        ),
      ),
    );
  }
}

class FollowButton extends StatefulWidget {
  const FollowButton({
    super.key,
    required this.room,
  });

  final LiveRoom room;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  final settings = Get.find<SettingsService>();

  late bool isFavorite = settings.isFavorite(widget.room);

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: () {
        setState(() => isFavorite = !isFavorite);
        if (isFavorite) {
          settings.addRoom(widget.room);
        } else {
          settings.removeRoom(widget.room);
        }
      },
      style: ElevatedButton.styleFrom(),
      child: Text(isFavorite ? S.current.unfollow : S.current.follow),
    );
  }
}

class CountChip extends StatelessWidget {
  const CountChip({
    super.key,
    this.icon,
    required this.count,
    this.dense = false,
    this.color = Colors.black,
    this.size,
  });

  final IconData? icon;
  final String count;
  final bool dense;
  final Color color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    var curSize = size;
    curSize ??= Theme.of(context).textTheme.bodySmall?.fontSize;
    return Card(
      shape: const StadiumBorder(),
      color: color.withValues(alpha: 0.6),
      shadowColor: Colors.transparent,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(dense ? 4 : 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          textDirection: TextDirection.ltr,
          children: [
            if (icon != null)
              Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.8),
                size: size !=null ? size! * 1.2: size,
              ),
            Text(
              count,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: size,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
