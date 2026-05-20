import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/event_bus.dart';
import 'package:pure_live/common/widgets/common_avatar.dart';
import 'package:pure_live/modules/live_play/live_play_controller.dart';

class PlayOther extends StatefulWidget {
  final LivePlayController controller;
  const PlayOther({required this.controller, super.key});

  @override
  State<PlayOther> createState() => _PlayOtherState();
}

class _PlayOtherState extends State<PlayOther> {
  final onlineRooms = <LiveRoom>[].obs;
  StreamSubscription<dynamic>? subscription;
  final loadingFinish = false.obs;
  @override
  void initState() {
    super.initState();
    var rooms = <LiveRoom>[];
    rooms = widget.controller.settings.favoriteRooms.where((room) => room.liveStatus == LiveStatus.live).toList();
    for (var room in rooms) {
      if (int.tryParse(room.watching!) == null) {
        room.watching = "0";
      }
    }
    rooms.sort((a, b) => int.parse(b.watching!).compareTo(int.parse(a.watching!)));
    onlineRooms.value = rooms;
    loadingFinish.value = true;
    listenFavorite();
  }

  void listenFavorite() {
    // 监听刷新关注页事件
    subscription = EventBus.instance.listen('refresh_favorite_finish', (data) {
      loadingFinish.value = true;
      var rooms = <LiveRoom>[];
      rooms = widget.controller.settings.favoriteRooms.where((room) => room.liveStatus == LiveStatus.live).toList();
      for (var room in rooms) {
        if (int.tryParse(room.watching!) == null) {
          room.watching = "0";
        }
      }
      rooms.sort((a, b) => int.parse(b.watching!).compareTo(int.parse(a.watching!)));
      onlineRooms.value = rooms;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16.0),
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 500, maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 10, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [Text(i18n("live_now"), style: Theme.of(context).textTheme.titleMedium)]),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(
                () => loadingFinish.value
                    ? ListView.builder(
                        itemCount: onlineRooms.value.length,
                        itemBuilder: (context, index) {
                          return EnhancedListTile(
                            room: onlineRooms.value[index],
                            dense: true,
                            onTap: widget.controller.switchRoom,
                          );
                        },
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      loadingFinish.value = false;
                      EventBus.instance.emit('refresh_favorite_rooms', true);
                    },
                    child: Text(i18n("refresh")),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(i18n("close")),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 增强版 ListTile（带观看数、平台标识等）
class EnhancedListTile extends StatelessWidget {
  final LiveRoom room;
  final bool dense;
  final Function(LiveRoom) onTap;
  const EnhancedListTile({super.key, required this.room, this.dense = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: dense,
      leading: CommonAvatar(avatarUrl: room.avatar, fallbackName: room.nick, dense: dense),
      title: Text(
        room.title!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: dense ? 13 : 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          Text(
            room.nick!,
            style: TextStyle(fontSize: dense ? 11 : 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              room.platform?.toUpperCase() ?? '',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w400, color: Colors.white),
            ),
          ),
          if (room.watching != null)
            Text(
              readableCount(room.watching!),
              style: TextStyle(fontSize: dense ? 12 : 14, color: Colors.orange.shade700),
            ),
        ],
      ),
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      onTap: () {
        Navigator.of(context).pop();
        onTap(room);
      },
    );
  }
}
