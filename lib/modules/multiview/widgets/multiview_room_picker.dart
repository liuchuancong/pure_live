import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/common_avatar.dart';

/// 选台数据来源。
enum _PickerSource { favorites, history }

@visibleForTesting
int compareMultiviewRooms(
  LiveRoom a,
  LiveRoom b, {
  bool preferRealOnline = false,
  bool Function(String? platform)? platformEnabled,
}) {
  var result = (b.isPlayableNow ? 1 : 0).compareTo(a.isPlayableNow ? 1 : 0);
  if (result != 0) return result;
  return LiveRoom.compareAudienceRanking(
    a,
    b,
    preferRealOnline: preferRealOnline,
    platformEnabled: platformEnabled ?? (_) => false,
  );
}

/// multiview 选台面板内容。
///
/// 复用本地关注（FavoritesService/FavoriteRoomController）与观看历史
/// 两个现成数据源，不新建任何后端逻辑；宽屏右侧常驻侧板与窄屏底部
/// 弹窗共用同一份内容。点选直播间后通过 [MultiviewRoomPicker.onPicked]
/// 回调交由页面调用控制器分配到目标格。
class MultiviewRoomPicker extends StatefulWidget {
  const MultiviewRoomPicker({
    super.key,
    required this.cellIndex,
    required this.onPicked,
    this.onSearch,
    this.showHeader = true,
  });

  /// 目标格子下标（0 起），标题中展示为 1 起的序号。
  final int cellIndex;

  /// 点选直播间后的回调；由页面负责调用 assignRoom 并关闭弹层。
  final void Function(LiveRoom room) onPicked;

  /// 打开跨平台搜索面板；为 null 时不显示入口（本面板只有收藏/历史两个本地源）。
  final VoidCallback? onSearch;

  /// 是否显示面板头部（目标格标题 + 搜索按钮）。嵌入桌面侧板时侧板外层
  /// 已有同义标题行，传 false 隐藏内部头部避免重复；移动端弹窗保持默认。
  final bool showHeader;

  @override
  State<MultiviewRoomPicker> createState() => _MultiviewRoomPickerState();
}

class _MultiviewRoomPickerState extends State<MultiviewRoomPicker> {
  _PickerSource _source = _PickerSource.favorites;
  String _query = '';

  List<LiveRoom> _roomsFor(_PickerSource source) {
    final raw = switch (source) {
      _PickerSource.favorites => SettingsService.to.fav.favoriteRooms.v,
      _PickerSource.history => SettingsService.to.history.historyRooms.v,
    };

    final query = _query.trim().toLowerCase();

    final rooms = raw.where((room) {
      final platform = room.platform?.trim().toLowerCase() ?? '';
      if (!Sites.isSupported(platform)) return false;
      if ((room.roomId?.trim() ?? '').isEmpty) return false;

      if (query.isNotEmpty) {
        final nick = (room.nick ?? '').toLowerCase();
        final title = (room.title ?? '').toLowerCase();

        if (!nick.contains(query) && !title.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    final app = SettingsService.to.app;
    rooms.sort(
      (left, right) => compareMultiviewRooms(
        left,
        right,
        preferRealOnline: app.preferRealOnlineCounts.v,
        platformEnabled: app.isRealOnlineEnabledFor,
      ),
    );

    return rooms;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rooms = _roomsFor(_source);
      return Column(
        children: [
          if (widget.showHeader && widget.onSearch != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      i18n('multiview_pick_for_cell', args: {'index': '${widget.cellIndex + 1}'}),
                      style: AppTextStyles.t13Medium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onSearch,
                    icon: const Icon(Remix.search_line, size: 16),
                    label: Text(i18n('multiview_search_rooms'), style: AppTextStyles.t12),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              style: AppTextStyles.t13,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Remix.search_line, size: 20),
                hintText: i18n('multiview_search_hint'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<_PickerSource>(
              showSelectedIcon: false,
              selected: {_source},
              onSelectionChanged: (selection) => setState(() => _source = selection.first),
              segments: [
                ButtonSegment(value: _PickerSource.favorites, label: Text(i18n('favorites_title'))),
                ButtonSegment(value: _PickerSource.history, label: Text(i18n('history'))),
              ],
            ),
          ),
          Expanded(
            child: rooms.isEmpty
                ? AppStatusView(
                    type: AppStatusType.empty,
                    icon: Remix.tv_2_line,
                    title: i18n('multiview_no_rooms_title'),
                    subtitle: i18n('multiview_no_rooms_subtitle'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    itemCount: rooms.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return ListTile(
                        leading: MultiviewRoomTileLeading(room: room),
                        title: Text(
                          room.nick ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.t14Medium,
                        ),
                        subtitle: Text(
                          room.title ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.t12Muted,
                        ),
                        trailing: MultiviewLiveStatusBadge(room: room),
                        onTap: () => widget.onPicked(room),
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }
}

/// 列表项头像：主播头像 + 右下角平台徽标。选台面板与搜索面板共用。
class MultiviewRoomTileLeading extends StatelessWidget {
  const MultiviewRoomTileLeading({super.key, required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final platform = room.platform?.trim().toLowerCase() ?? '';
    final hasLogo = Sites.isSupported(platform);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CommonAvatar(avatarUrl: room.avatar, fallbackName: room.nick, size: 40),
        if (hasLogo)
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                shape: BoxShape.circle,
              ),
              child: Image.asset(Sites.of(platform).logo, width: 14, height: 14),
            ),
          ),
      ],
    );
  }
}

/// 直播状态标识：开播绿点 / 未开播灰字。选台面板与搜索面板共用。
class MultiviewLiveStatusBadge extends StatelessWidget {
  const MultiviewLiveStatusBadge({super.key, required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = room.effectiveLiveStatus;
    final isLive = status == LiveStatus.live;
    final isReplay = status == LiveStatus.replay;
    final isPending = status == LiveStatus.unknown;
    final color = isLive
        ? const Color(0xFF31C24C)
        : isReplay
        ? theme.colorScheme.tertiary
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: isPending ? 0.5 : 0.35);
    final labelKey = isLive
        ? 'live_now'
        : isReplay
        ? 'replay'
        : isPending
        ? 'favorite_status_unknown'
        : 'offline';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          i18n(labelKey),
          style: AppTextStyles.t11.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
