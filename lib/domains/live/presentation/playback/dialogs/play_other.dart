import 'dart:async';
import 'dart:math' as math;

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/utils/event_bus.dart';
import 'package:pure_live/core/widgets/common_avatar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/core/network/image_cache_manager.dart';
import 'package:pure_live/domains/live/data/history_controller.dart';
import 'package:pure_live/domains/live/data/favorite_room_controller.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/live_play_controller.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/content_first_panel_layout.dart';

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

    tabController = TabController(length: 3, vsync: this, animationDuration: pureLiveTabTransitionDuration);

    _updateRooms();

    subscription = EventBus.instance.listen('refresh_favorite_finish', (_) => _updateRooms());
  }

  void _updateRooms() {
    final allRooms = FavoriteRoomController.to.favoriteRooms.v;

    final liveList = allRooms.where((room) => room.isLiveNow && room.isRecord == false).toList()
      ..sort(_compareAudience);
    final recordList = allRooms.where((room) => room.effectiveLiveStatus == LiveStatus.replay).toList()
      ..sort(_compareAudience);
    onlineRooms.assignAll(liveList);
    recordingRooms.assignAll(recordList);
    historyRooms.assignAll(HistoryController.to.historyRooms.v);

    loadingFinish.value = true;
    refreshing.value = false;
  }

  int _compareAudience(LiveRoom left, LiveRoom right) {
    final app = SettingsService.to.app;
    return LiveRoom.compareAudienceRanking(
      left,
      right,
      preferRealOnline: app.preferRealOnlineCounts.v,
      platformEnabled: app.isRealOnlineEnabledFor,
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final textMetrics = resolveRoomHistoryTextMetrics(
      textScaler: MediaQuery.textScalerOf(context),
      headerFontSize: textTheme.titleSmall?.fontSize ?? 14,
      headerLineHeight: textTheme.titleSmall?.height ?? 1.25,
      tabFontSize: textTheme.labelMedium?.fontSize ?? 12,
      tabLineHeight: textTheme.labelMedium?.height ?? 1.33,
      titleFontSize: textTheme.labelMedium?.fontSize ?? 12,
      titleLineHeight: textTheme.labelMedium?.height ?? 1.33,
      detailFontSize: textTheme.labelSmall?.fontSize ?? 11,
      detailLineHeight: textTheme.labelSmall?.height ?? 1.45,
    );

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
              height: textMetrics.headerHeight,
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 2),
                child: Row(
                  children: [
                    Icon(Icons.video_library_rounded, size: 17, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        i18n('switch_live_room'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Obx(
                      () => IconButton(
                        key: const ValueKey('room-history-refresh'),
                        tooltip: i18n('refresh'),
                        visualDensity: VisualDensity.standard,
                        constraints: const BoxConstraints.tightFor(
                          width: contentFirstPanelHeaderActionExtent,
                          height: contentFirstPanelHeaderActionExtent,
                        ),
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
                      key: const ValueKey('room-history-close'),
                      tooltip: i18n('close'),
                      visualDensity: VisualDensity.standard,
                      constraints: const BoxConstraints.tightFor(
                        width: contentFirstPanelHeaderActionExtent,
                        height: contentFirstPanelHeaderActionExtent,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: textMetrics.tabBarHeight,
              child: ScrollableTabBar(
                controller: tabController,
                isScrollable: textMetrics.scrollTabs,
                tabAlignment: textMetrics.scrollTabs ? TabAlignment.start : TabAlignment.fill,
                physics: const PureLiveBoundedScrollPhysics(),
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorSize: TabBarIndicatorSize.label,
                dividerHeight: 0,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                tabs: [
                  _CompactTab(
                    icon: Icons.sensors_rounded,
                    label: i18n('online_room_title'),
                    height: textMetrics.tabBarHeight,
                    shrinkToFit: !textMetrics.scrollTabs,
                  ),
                  _CompactTab(
                    icon: Icons.fiber_smart_record_rounded,
                    label: i18n('recording_room_title'),
                    height: textMetrics.tabBarHeight,
                    shrinkToFit: !textMetrics.scrollTabs,
                  ),
                  _CompactTab(
                    icon: Icons.history_rounded,
                    label: i18n('watch_history'),
                    height: textMetrics.tabBarHeight,
                    shrinkToFit: !textMetrics.scrollTabs,
                  ),
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
                            physics: const PureLiveBoundedScrollPhysics(),
                            children: [
                              _buildRoomGrid(onlineRooms, history: false, textMetrics: textMetrics),
                              _buildRoomGrid(recordingRooms, history: false, textMetrics: textMetrics),
                              _buildRoomGrid(historyRooms, history: true, textMetrics: textMetrics),
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

  Widget _buildRoomGrid(List<LiveRoom> rooms, {required bool history, required RoomHistoryTextMetrics textMetrics}) {
    if (rooms.isEmpty) {
      return AppStatusView(type: AppStatusType.empty);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 10.0;
        const spacing = 8.0;
        // 两种形态按面板内容宽分档，不按"卡片能不能读"分档：手机横屏的右半面板
        // 只有 370~410 宽，塞卡片要么一列太宽、要么两列小到看不清封面，所以
        // 窄面板一行一个主播（头像 + 房间名/主播名），平板与桌面才用封面卡片。
        const cardModeMinimumWidth = 520.0;
        // 底部信息条固定 48；只有无障碍大字号确实需要更高时才让出空间。
        final infoHeight = math.max(48.0, textMetrics.cardFooterHeight);
        // 头像行固定 72；同样只在大字号下长高，避免房间名/主播名被裁。
        final avatarRowHeight = textMetrics.mobileRowHeight;

        final availableWidth = math.max(0.0, constraints.maxWidth - padding * 2);
        final cardMode = availableWidth >= cardModeMinimumWidth;
        final columns = cardMode ? 2 : 1;
        final cardWidth = math.max(0.0, (availableWidth - spacing * (columns - 1)) / columns);
        // 卡片：16:9 封面 + 信息条；头像行：固定行高。极小视口兜一个最小高度，
        // 避免负数进入网格代理。
        final rowExtent = cardMode ? math.max(80.0, cardWidth * 9 / 16 + infoHeight) : avatarRowHeight;

        return GridView.builder(
          key: ValueKey(history ? 'watch-history-grid' : 'live-room-grid'),
          padding: const EdgeInsets.all(padding),
          physics: const PureLiveScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: rowExtent,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
          ),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];

            return _RoomSwitchCard(
              room: room,
              history: history,
              cardMode: cardMode,
              infoHeight: infoHeight,
              onTap: () {
                Navigator.of(context).pop();
                widget.controller.switchRoom(room);
              },
            );
          },
        );
      },
    );
  }
}

class _CompactTab extends StatelessWidget {
  const _CompactTab({required this.icon, required this.label, required this.height, required this.shrinkToFit});

  final IconData icon;
  final String label;
  final double height;
  final bool shrinkToFit;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 3),
        // Flexible causes a layout error here because TabBar may provide unbounded width constraints.
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
    return Tab(
      height: height,
      child: shrinkToFit ? FittedBox(fit: BoxFit.scaleDown, child: content) : content,
    );
  }
}

class _RoomSwitchCard extends StatelessWidget {
  const _RoomSwitchCard({
    required this.room,
    required this.history,
    required this.cardMode,
    required this.infoHeight,
    required this.onTap,
  });

  final LiveRoom room;
  final bool history;

  /// true = 封面卡片（平板/桌面），false = 头像行（窄面板）。
  final bool cardMode;

  /// 卡片底部标题/昵称信息条的固定高度；头像行不使用。
  final double infoHeight;
  final VoidCallback onTap;

  String _historyLabel() {
    final value = room.lastWatchedAt;

    if (value == null || value <= 0) {
      return i18n('history_earlier');
    }

    return i18n('watched_at', args: {'time': formatHistoryWatchedAt(value)});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final audience = room.audienceValue(
      preferRealOnline: SettingsService.to.app.preferRealOnlineCounts.v,
      platformEnabled: SettingsService.to.app.isRealOnlineEnabledFor(room.platform),
    );

    final title = room.title?.trim().isNotEmpty == true ? room.title! : i18n('untitled_room');

    final nick = room.nick?.trim() ?? '';

    final meta = history
        ? _historyLabel()
        : audience.isEmpty
        ? i18n('audience_unknown')
        : readableCount(audience);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: cardMode
                ? _buildCardLayout(context, meta: meta, title: title, nick: nick)
                : _buildAvatarLayout(context, meta: meta, title: title, nick: nick),
          ),
        ),
      ),
    );
  }

  /// 平板/桌面：16:9 封面 + 底部房间名/主播名的封面卡片。
  Widget _buildCardLayout(BuildContext context, {required String meta, required String title, required String nick}) {
    return Column(
      children: [
        Expanded(
          child: _RoomSwitchCover(room: room, meta: meta),
        ),
        RoomSwitchCardDetails(height: infoHeight, title: title, nick: nick.isEmpty ? i18n('unknown') : nick),
      ],
    );
  }

  /// 窄面板（手机横屏的右半屏）：一行一个主播 —— 头像 + 房间名/主播名，
  /// 右侧是平台标签与观众数（历史页签下是观看时间）。
  ///
  /// 这个宽度下封面卡片没有出路：一列太宽、两列小到认不出封面，
  /// 头像行反而一眼能认出是谁在播。
  Widget _buildAvatarLayout(BuildContext context, {required String meta, required String title, required String nick}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final platform = room.platform?.trim().toLowerCase() ?? '';
    final displayNick = nick.isEmpty ? i18n('unknown') : nick;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          CommonAvatar(avatarUrl: room.avatar, fallbackName: nick, dense: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  displayNick,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (platform.isNotEmpty) ...[_PlatformTag(platform: platform), const SizedBox(height: 3)],
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: history ? colors.onSurfaceVariant : Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 头像行右侧的平台标签：站点本地化名称的小胶囊。
class _PlatformTag extends StatelessWidget {
  const _PlatformTag({required this.platform});

  final String platform;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outline.withValues(alpha: .2), width: .5),
      ),
      child: Text(
        i18n('site_$platform'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: colors.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class RoomSwitchCardDetails extends StatelessWidget {
  const RoomSwitchCardDetails({super.key, required this.height, required this.title, required this.nick});

  final double height;
  final String title;
  final String nick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(7, 3, 3, 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 12, color: colors.onSurfaceVariant),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    nick,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 14, color: colors.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
String formatHistoryWatchedAt(int millisecondsSinceEpoch) {
  final watched = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${watched.year.toString().padLeft(4, '0')}-'
      '${twoDigits(watched.month)}-${twoDigits(watched.day)} '
      '${twoDigits(watched.hour)}:${twoDigits(watched.minute)}';
}

class _RoomSwitchCover extends StatelessWidget {
  const _RoomSwitchCover({required this.room, required this.meta});

  final LiveRoom room;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final url = normalizeNetworkImageUrl(room.cover);

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
                cacheManager: AppImageCacheManager.instance,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                memCacheWidth: cacheWidth,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                useOldImageOnUrlChange: true,
                placeholder: (_, _) {
                  return ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: Icon(Icons.live_tv_rounded, color: colors.onSurfaceVariant.withValues(alpha: .25)),
                  );
                },
                errorWidget: (_, _, _) {
                  return ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant.withValues(alpha: .35)),
                  );
                },
              );
            },
          ),
        Positioned(
          top: 7,
          right: 7,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .58),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              i18n('site_${room.platform}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, height: 1),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 22, 8, 8),
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
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
