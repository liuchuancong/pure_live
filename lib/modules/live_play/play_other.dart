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

class _PlayOtherState extends State<PlayOther> with SingleTickerProviderStateMixin {
  late TabController tabController;
  final onlineRooms = <LiveRoom>[].obs;
  final recordingRooms = <LiveRoom>[].obs;
  StreamSubscription<dynamic>? subscription;
  final loadingFinish = false.obs;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    _updateRooms();
    listenFavorite();
  }

  void _updateRooms() {
    var allRooms = SettingsService.to.fav.favoriteRooms.v;

    var liveList = allRooms.where((room) => room.liveStatus == LiveStatus.live && room.isRecord == false).toList();
    for (var room in liveList) {
      if (int.tryParse(room.watching!) == null) {
        room.watching = "0";
      }
    }
    liveList.sort((a, b) => int.parse(b.watching!).compareTo(int.parse(a.watching!)));
    onlineRooms.value = liveList;

    var recordList = allRooms.where((room) => room.liveStatus == LiveStatus.live && room.isRecord == true).toList();
    for (var room in recordList) {
      if (int.tryParse(room.watching!) == null) {
        room.watching = "0";
      }
    }
    recordList.sort((a, b) => int.parse(b.watching!).compareTo(int.parse(a.watching!)));
    recordingRooms.value = recordList;

    loadingFinish.value = true;
  }

  void listenFavorite() {
    subscription = EventBus.instance.listen('refresh_favorite_finish', (data) {
      _updateRooms();
    });
  }

  @override
  void dispose() {
    tabController.dispose();
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16.0),
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 10, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(i18n("live_now"), style: Theme.of(context).textTheme.titleMedium),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            TabBar(
              controller: tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).hintColor,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(text: i18n("online_room_title")),
                Tab(text: i18n("recording_room_title")),
              ],
            ),
            Expanded(
              child: Obx(
                () => loadingFinish.value
                    ? TabBarView(
                        controller: tabController,
                        children: [_buildRoomList(onlineRooms.value), _buildRoomList(recordingRooms.value)],
                      )
                    : AppStatusView(type: AppStatusType.loading, title: "", subtitle: ""),
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
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n("close"))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomList(List<LiveRoom> rooms) {
    if (rooms.isEmpty) {
      return AppStatusView(type: AppStatusType.empty, title: "", subtitle: "");
    }
    return ListView.builder(
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        return EnhancedListTile(room: rooms[index], dense: true, onTap: widget.controller.switchRoom);
      },
    );
  }
}

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
        style: (dense ? AppTextStyles.t13 : AppTextStyles.t15).copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          Text(
            room.nick!,
            style: (dense ? AppTextStyles.t11 : AppTextStyles.t13).copyWith(fontWeight: FontWeight.w500),
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
              style: AppTextStyles.t11.copyWith(fontWeight: FontWeight.w400, color: Colors.white),
            ),
          ),
          if (room.watching != null)
            Text(
              readableCount(room.watching!),
              style: (dense ? AppTextStyles.t12 : AppTextStyles.t14).copyWith(color: Colors.orange.shade700),
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
