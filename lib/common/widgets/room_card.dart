import 'dart:developer';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ignore: must_be_immutable
class RoomCard extends StatelessWidget {
  const RoomCard({super.key, required this.room, this.dense = false});
  final LiveRoom room;
  final bool dense;

  void onTap(BuildContext context) async {
    AppNavigator.toLiveRoomDetail(liveRoom: room);
  }

  void onLongPress(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: Text(room.title!),
        content: Text(
          S.of(context).room_info_content(room.roomId!, room.platform!, room.nick!, room.title!, room.liveStatus!.name),
        ),
        actions: [FollowButton(room: room)],
      ),
    );
  }

  ImageProvider? getRoomAvatar(String avatar) {
    try {
      return CachedNetworkImageProvider(
        avatar,
        errorListener: (err) {
          log("CachedNetworkImageProvider: Image failed to load!");
        },
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(7.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15.0),
        onTap: () => onTap(context),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                    clipBehavior: Clip.antiAlias,
                    color: Theme.of(context).focusColor,
                    elevation: 0,
                    child: room.liveStatus == LiveStatus.offline && room.cover!.isNotEmpty
                        ? Center(child: Icon(Icons.tv_off_rounded, size: dense ? 36 : 60))
                        : Image.network(room.cover!, fit: BoxFit.cover),
                  ),
                ),
                if (room.isRecord == true)
                  Positioned(
                    right: dense ? 0 : 2,
                    top: dense ? 0 : 2,
                    child: CountChip(
                      icon: Icons.videocam_rounded,
                      count: S.of(context).replay,
                      dense: dense,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (room.isRecord == false && room.liveStatus == LiveStatus.live)
                  Positioned(
                    right: dense ? 0 : 2,
                    bottom: dense ? 0 : 2,
                    child: CountChip(
                      icon: Icons.whatshot_rounded,
                      count: readableCount(room.watching ?? "0"),
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
              leading: CircleAvatar(
                foregroundImage: room.avatar!.isNotEmpty ? getRoomAvatar(room.avatar!) : null,
                radius: dense ? 17 : null,
                backgroundColor: Theme.of(context).disabledColor,
              ),
              title: Text(
                room.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: dense ? 12.5 : 15, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                room.nick ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: dense ? 12 : 14),
              ),
              trailing: dense
                  ? null
                  : Text(
                      room.platform != null ? room.platform!.toUpperCase() : '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class FollowButton extends StatefulWidget {
  const FollowButton({super.key, required this.room});

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
        Navigator.of(Get.context!).pop();
      },
      style: ElevatedButton.styleFrom(),
      child: Text(isFavorite ? S.of(context).unfollow : S.of(context).follow),
    );
  }
}

class CountChip extends StatelessWidget {
  const CountChip({super.key, required this.icon, required this.count, this.dense = false, this.color = Colors.black});

  final IconData icon;
  final String count;
  final bool dense;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: const StadiumBorder(),
      color: color.withValues(alpha: 0.8),
      shadowColor: Colors.transparent,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(dense ? 4 : 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: dense ? 18 : 20),
            Text(
              count,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.8), fontSize: dense ? 15 : 18),
            ),
          ],
        ),
      ),
    );
  }
}
