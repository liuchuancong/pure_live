import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/event_bus.dart';
import 'package:pure_live/common/widgets/common_avatar.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

class PlayOther extends StatefulWidget {
  const PlayOther({required this.controller, super.key});

  final LivePlayController controller;

  @override
  State<PlayOther> createState() => _PlayOtherState();
}

class _PlayOtherState extends State<PlayOther> with SingleTickerProviderStateMixin {
  late final TabController tabController;
  final onlineRooms = <LiveRoom>[].obs;
  final recordingRooms = <LiveRoom>[].obs;
  final historyRooms = <LiveRoom>[].obs;
  final loadingFinish = false.obs;
  StreamSubscription<dynamic>? subscription;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
    _updateRooms();
    subscription = EventBus.instance.listen('refresh_favorite_finish', (_) => _updateRooms());
  }

  void _updateRooms() {
    final allRooms = SettingsService.to.fav.favoriteRooms.v;
    final liveList = allRooms.where((room) => room.liveStatus == LiveStatus.live && room.isRecord == false).toList()
      ..sort((a, b) => _audienceSortValue(b).compareTo(_audienceSortValue(a)));
    final recordList = allRooms.where((room) => room.liveStatus == LiveStatus.live && room.isRecord == true).toList()
      ..sort((a, b) => _audienceSortValue(b).compareTo(_audienceSortValue(a)));
    onlineRooms.assignAll(liveList);
    recordingRooms.assignAll(recordList);
    historyRooms.assignAll(SettingsService.to.history.historyRooms.v);
    loadingFinish.value = true;
  }

  int _audienceSortValue(LiveRoom room) {
    final app = SettingsService.to.app;
    return room.audienceSortValue(
      preferRealOnline: app.preferRealOnlineCounts.v,
      platformEnabled: app.isRealOnlineEnabledFor(room.platform),
    );
  }

  @override
  void dispose() {
    tabController.dispose();
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      key: const ValueKey('fullscreen-room-history-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: (size.width - 48).clamp(300, 820).toDouble(),
        height: (size.height - 48).clamp(260, 560).toDouble(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.video_library_rounded, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(i18n('switch_live_room'), style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            TabBar(
              controller: tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(icon: const Icon(Icons.sensors_rounded, size: 18), text: i18n('online_room_title')),
                Tab(icon: const Icon(Icons.fiber_smart_record_rounded, size: 18), text: i18n('recording_room_title')),
                Tab(icon: const Icon(Icons.history_rounded, size: 18), text: i18n('watch_history')),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: Obx(
                () => loadingFinish.value
                    ? TabBarView(
                        controller: tabController,
                        children: [
                          _buildRoomGrid(onlineRooms, history: false),
                          _buildRoomGrid(recordingRooms, history: false),
                          _buildRoomGrid(historyRooms, history: true),
                        ],
                      )
                    : AppStatusView(type: AppStatusType.loading, title: '', subtitle: ''),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      loadingFinish.value = false;
                      EventBus.instance.emit('refresh_favorite_rooms', true);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(i18n('refresh')),
                  ),
                  const Spacer(),
                  FilledButton.tonal(onPressed: () => Navigator.of(context).pop(), child: Text(i18n('close'))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomGrid(List<LiveRoom> rooms, {required bool history}) {
    if (rooms.isEmpty) return AppStatusView(type: AppStatusType.empty, title: '', subtitle: '');
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 2 : 1;
        return GridView.builder(
          key: ValueKey(history ? 'watch-history-grid' : 'live-room-grid'),
          padding: const EdgeInsets.all(12),
          physics: const PureLiveScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 116,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: rooms.length,
          itemBuilder: (context, index) => _RoomSwitchCard(
            room: rooms[index],
            history: history,
            onTap: () {
              Navigator.of(context).pop();
              widget.controller.switchRoom(rooms[index]);
            },
          ),
        );
      },
    );
  }
}

class _RoomSwitchCard extends StatelessWidget {
  const _RoomSwitchCard({required this.room, required this.history, required this.onTap});

  final LiveRoom room;
  final bool history;
  final VoidCallback onTap;

  String _historyLabel() {
    final value = room.lastWatchedAt;
    if (value == null || value <= 0) return i18n('history_earlier');
    final watched = DateTime.fromMillisecondsSinceEpoch(value);
    final now = DateTime.now();
    final sameDay = watched.year == now.year && watched.month == now.month && watched.day == now.day;
    final hour = watched.hour.toString().padLeft(2, '0');
    final minute = watched.minute.toString().padLeft(2, '0');
    final text = sameDay
        ? '$hour:$minute'
        : '${watched.month.toString().padLeft(2, '0')}-${watched.day.toString().padLeft(2, '0')} $hour:$minute';
    return i18n(sameDay ? 'watched_today_at' : 'watched_at', args: {'time': text});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final audience = room.audienceValue(
      preferRealOnline: SettingsService.to.app.preferRealOnlineCounts.v,
      platformEnabled: SettingsService.to.app.isRealOnlineEnabledFor(room.platform),
    );
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CommonAvatar(avatarUrl: room.avatar, fallbackName: room.nick, dense: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.title?.trim().isNotEmpty == true ? room.title! : i18n('untitled_room'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(room.nick ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            room.platform?.toUpperCase() ?? '',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onPrimaryContainer),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            history
                                ? _historyLabel()
                                : (audience.isEmpty ? i18n('audience_unknown') : readableCount(audience)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
