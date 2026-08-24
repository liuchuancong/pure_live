import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/content_first_panel_layout.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/plugins/event_bus.dart';

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
  final refreshing = false.obs;
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
    refreshing.value = false;
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
    final layout = resolveContentFirstPanelLayout(MediaQuery.sizeOf(context), ContentFirstPanelKind.roomHistory);
    return Dialog(
      key: const ValueKey('fullscreen-room-history-dialog'),
      alignment: Alignment.centerRight,
      insetPadding: layout.insetPadding,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: layout.size.width,
        height: layout.size.height,
        child: Column(
          children: [
            SizedBox(
              height: 36,
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 2),
                child: Row(
                  children: [
                    Icon(Icons.video_library_rounded, size: 17, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(i18n('switch_live_room'), style: Theme.of(context).textTheme.titleSmall)),
                    Obx(
                      () => IconButton(
                        tooltip: i18n('refresh'),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                        padding: EdgeInsets.zero,
                        onPressed: refreshing.value
                            ? null
                            : () {
                                refreshing.value = true;
                                EventBus.instance.emit('refresh_favorite_rooms', true);
                              },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                      ),
                    ),
                    IconButton(
                      tooltip: i18n('close'),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 30,
              child: TabBar(
                controller: tabController,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                indicatorSize: TabBarIndicatorSize.label,
                dividerHeight: 0,
                tabs: [
                  _CompactTab(icon: Icons.sensors_rounded, label: i18n('online_room_title')),
                  _CompactTab(icon: Icons.fiber_smart_record_rounded, label: i18n('recording_room_title')),
                  _CompactTab(icon: Icons.history_rounded, label: i18n('watch_history')),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Stack(
                children: [
                  Obx(
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
                  Obx(
                    () => refreshing.value
                        ? const Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            child: LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent),
                          )
                        : const SizedBox.shrink(),
                  ),
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
        final columns = constraints.maxWidth >= 380 ? 2 : 1;
        const padding = 6.0;
        const spacing = 5.0;
        final cardHeight = resolveRoomHistoryCardHeight(
          contentSize: Size(constraints.maxWidth, constraints.maxHeight),
          columns: columns,
          padding: padding,
          spacing: spacing,
        );
        return GridView.builder(
          key: ValueKey(history ? 'watch-history-grid' : 'live-room-grid'),
          padding: const EdgeInsets.all(padding),
          physics: const PureLiveScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: cardHeight,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
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

class _CompactTab extends StatelessWidget {
  const _CompactTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Builder(
          builder: (context) {
            final meta = history
                ? _historyLabel()
                : (audience.isEmpty ? i18n('audience_unknown') : readableCount(audience));
            return Column(
              children: [
                Expanded(
                  child: SizedBox(
                    key: const ValueKey('room-history-cover'),
                    width: double.infinity,
                    child: _RoomSwitchCover(room: room, meta: meta),
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(7, 3, 3, 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.title?.trim().isNotEmpty == true ? room.title! : i18n('untitled_room'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded, size: 12, color: colors.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                room.nick ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, size: 14, color: colors.onSurfaceVariant),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RoomSwitchCover extends StatelessWidget {
  const _RoomSwitchCover({required this.room, required this.meta});

  final LiveRoom room;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final url = normalizeNetworkImageUrl(room.cover);
    final colors = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url.isEmpty)
          ColoredBox(
            color: colors.surfaceContainerHighest,
            child: Icon(Icons.live_tv_rounded, size: 34, color: colors.onSurfaceVariant.withValues(alpha: .35)),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cacheWidth = (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                  .round()
                  .clamp(240, 720)
                  .toInt();
              return CachedNetworkImage(
                imageUrl: url,
                httpHeaders: networkImageHeaders(url),
                cacheManager: CustomImageCacheManager.instance,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                memCacheWidth: cacheWidth,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                useOldImageOnUrlChange: true,
                placeholder: (_, _) => ColoredBox(
                  color: colors.surfaceContainerHighest,
                  child: Icon(Icons.live_tv_rounded, color: colors.onSurfaceVariant.withValues(alpha: .25)),
                ),
                errorWidget: (_, _, _) => ColoredBox(
                  color: colors.surfaceContainerHighest,
                  child: Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant.withValues(alpha: .35)),
                ),
              );
            },
          ),
        Positioned(
          top: 7,
          left: 7,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
            child: Text(
              room.platform?.toUpperCase() ?? '',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 18, 8, 7),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
            child: Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
