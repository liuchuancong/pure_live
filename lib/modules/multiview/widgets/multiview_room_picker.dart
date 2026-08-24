import 'package:remixicon/remixicon.dart';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/common_avatar.dart';

/// 选台数据来源。
enum _PickerSource { favorites, history }

/// multiview 选台面板内容。
///
/// 复用本地关注（FavoritesService/FavoriteRoomController）与观看历史
/// 两个现成数据源，不新建任何后端逻辑；宽屏右侧常驻侧板与窄屏底部
/// 弹窗共用同一份内容。点选直播间后通过 [MultiviewRoomPicker.onPicked]
/// 回调交由页面调用控制器分配到目标格。
class MultiviewRoomPicker extends StatefulWidget {
  const MultiviewRoomPicker({super.key, required this.cellIndex, required this.onPicked});

  /// 目标格子下标（0 起），标题中展示为 1 起的序号。
  final int cellIndex;

  /// 点选直播间后的回调；由页面负责调用 assignRoom 并关闭弹层。
  final void Function(LiveRoom room) onPicked;

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
    // 仅展示核心层可解析的受支持平台房间，避免把必然失败的房间送进 assignRoom。
    return raw.where((room) {
      final platform = room.platform?.trim().toLowerCase() ?? '';
      if (!Sites.isSupported(platform)) return false;
      if ((room.roomId?.trim() ?? '').isEmpty) return false;
      if (query.isNotEmpty) {
        final nick = (room.nick ?? '').toLowerCase();
        final title = (room.title ?? '').toLowerCase();
        if (!nick.contains(query) && !title.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rooms = _roomsFor(_source);
      return Column(
        children: [
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
                        leading: _RoomTileLeading(room: room),
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
                        trailing: _LiveStatusBadge(room: room),
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

/// 列表项头像：主播头像 + 右下角平台徽标。
class _RoomTileLeading extends StatelessWidget {
  const _RoomTileLeading({required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final platform = room.platform?.trim().toLowerCase() ?? '';
    final hasLogo = Sites.isSupported(platform);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CommonAvatar(avatarUrl: room.avatar, fallbackName: room.nick, radius: 19),
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

/// 直播状态标识：开播绿点 / 未开播灰字。
class _LiveStatusBadge extends StatelessWidget {
  const _LiveStatusBadge({required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = room.liveStatus == LiveStatus.live;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLive ? const Color(0xFF31C24C) : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          i18n(isLive ? 'live_now' : 'offline'),
          style: AppTextStyles.t11.copyWith(
            color: isLive ? const Color(0xFF31C24C) : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
