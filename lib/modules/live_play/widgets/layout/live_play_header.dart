import 'package:pure_live/common/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/button/record_action_button.dart';
import 'package:pure_live/modules/live_play/widgets/button/live_play_menu_button.dart';
import 'package:pure_live/modules/live_play/widgets/button/favorite_floating_button.dart';

class LivePlayHeader extends StatelessWidget implements PreferredSizeWidget {
  const LivePlayHeader({super.key, required this.controller, this.compactHeader = false});
  final LivePlayController controller;
  final bool compactHeader;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      title: _buildTitle(context),
      actions: [
        _buildFavoriteButton(),
        _buildRecordButton(),
        LivePlayMenuButton(controller: controller),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Row(
      children: [
        Obx(() {
          final avatar = controller.state.value.room.detail?.avatar;
          return CircleAvatar(
            radius: 16,
            foregroundImage: avatar != null && avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
            backgroundColor: Theme.of(context).disabledColor,
          );
        }),
        const SizedBox(width: 8),
        Expanded(
          child: Obx(() {
            final detail = controller.state.value.room.detail;
            if (detail == null) {
              return const SizedBox.shrink();
            }
            final platform = detail.platform?.toUpperCase() ?? '';
            final area = detail.area;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.nick ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  area == null || area.isEmpty ? platform : '$platform / $area',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFavoriteButton() {
    return Obx(() {
      final detail = controller.state.value.room.detail;
      if (detail == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(left: 2, right: 5),
        child: FavoriteFloatingButton(
          key: ValueKey('${detail.platform}:${detail.roomId}'),
          room: detail,
          compact: compactHeader,
        ),
      );
    });
  }

  Widget _buildRecordButton() {
    return Obx(() {
      final room = controller.state.value.room.detail;
      return RecordActionButton(
        room: room,
        recorderController: controller.recorderController,
        onOpenRecordCenter: controller.openRecordCenter,
        compactHeader: compactHeader,
      );
    });
  }
}
