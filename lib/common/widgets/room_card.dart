import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/common/widgets/common_avatar.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(room.title!),
        content: Text(
          i18n(
            "room_info_content",
            args: {
              "roomid": room.roomId!,
              "platform": room.platform!,
              "nickname": room.nick!,
              "title": room.title!,
              "livestatus": room.liveStatus!.name,
            },
          ),
        ),
        actions: [FollowButton(room: room)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      elevation: isDark ? 2 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: isDark ? Colors.grey[900] : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
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
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    color: isDark ? Colors.grey[850] : Colors.grey[100],

                    child: room.platform == Sites.iptvSite
                        ? CachedNetworkImage(
                            imageUrl: room.cover!,
                            cacheManager: CustomImageCacheManager.instance,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 250),
                            fadeOutDuration: const Duration(milliseconds: 250),
                            placeholder: (context, url) => Container(
                              color: Theme.of(context).focusColor,
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: AppStatusView(
                                    type: AppStatusType.loading,
                                    title: "",
                                    subtitle: "",
                                    isMini: true,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              return Container(
                                color: Theme.of(context).focusColor,
                                child: Center(
                                  child: Icon(
                                    Icons.broken_image_rounded,
                                    size: dense ? 36 : 60,
                                    color: Theme.of(context).disabledColor,
                                  ),
                                ),
                              );
                            },
                          )
                        : Image.network(
                            room.cover!,
                            fit: BoxFit.cover,
                            gaplessPlayback: false,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: isDark ? Colors.grey[850] : Colors.grey[100],
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: AppStatusView(
                                      type: AppStatusType.loading,
                                      title: "",
                                      subtitle: "",
                                      isMini: true,
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: isDark ? Colors.grey[850] : Colors.grey[100],
                                child: AppStatusView(type: AppStatusType.error, title: "", subtitle: "", isMini: true),
                              );
                            },
                          ),
                  ),
                ),
                if (room.isRecord == true)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: CountChip(
                      icon: Icons.videocam_rounded,
                      count: i18n("replay"),
                      dense: dense,
                      color: Get.theme.primaryColor,
                    ),
                  ),
                if (room.isRecord == false && room.liveStatus == LiveStatus.live)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: CountChip(
                      icon: Icons.whatshot_rounded,
                      count: readableCount(room.watching ?? "0"),
                      dense: dense,
                      color: Get.theme.primaryColor,
                    ),
                  ),
              ],
            ),
            ListTile(
              dense: dense,
              minLeadingWidth: dense ? 34 : 40,
              contentPadding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12, vertical: dense ? 4 : 6),
              horizontalTitleGap: dense ? 8 : 12,
              leading: CommonAvatar(avatarUrl: room.avatar, fallbackName: room.nick, dense: dense),
              title: Text(
                room.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (dense ? AppTextStyles.t13 : AppTextStyles.t15).copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                room.nick ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (dense ? AppTextStyles.t12 : AppTextStyles.t13).copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              trailing: dense
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        room.platform?.toUpperCase() ?? '',
                        style: AppTextStyles.t11.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                      ),
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
        isFavorite ? settings.addRoom(widget.room) : settings.removeRoom(widget.room);
        Navigator.of(Get.context!).pop();
      },
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      child: Text(isFavorite ? i18n("unfollow") : i18n("follow"), style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class CountChip extends StatelessWidget {
  const CountChip({super.key, required this.icon, required this.count, this.dense = false, required this.color});

  final IconData icon;
  final String count;
  final bool dense;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: const StadiumBorder(),
      color: color,
      shadowColor: Colors.transparent,

      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12, vertical: dense ? 4 : 6),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: dense ? 16 : 18),
            const SizedBox(width: 4),
            Text(
              count,
              style: (dense ? AppTextStyles.t12 : AppTextStyles.t13).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
