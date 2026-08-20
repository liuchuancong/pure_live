import 'dart:io';
import 'dart:developer' as developer;

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/common/utils/share_command_handler.dart';
import 'package:pure_live/modules/live_play/dialogs/play_other.dart';
import 'package:pure_live/modules/live_play/dialogs/room_timer_dialog.dart';
import 'package:pure_live/common/utils/windows_multi_instance_launcher.dart';
import 'package:pure_live/modules/live_play/dialogs/room_volume_dialog.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_interaction_sheet.dart';

class LivePlayMenuButton extends StatelessWidget {
  const LivePlayMenuButton({super.key, required this.controller});

  final LivePlayController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: i18n('menu'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      offset: const Offset(12, 0),
      position: PopupMenuPosition.under,
      icon: const Icon(Remix.apps_2_line),
      onOpened: () {
        controller.updateUI(isMenuOpen: true);
      },
      onCanceled: () {
        controller.updateUI(isMenuOpen: false);
      },
      onSelected: (index) {
        _handleSelected(context, index);
      },
      itemBuilder: _buildItems,
    );
  }

  void _handleSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        _openLiveRoom();
        break;

      case 1:
        _switchLiveRoom();
        break;

      case 2:
        _castScreen();
        break;

      case 3:
        _showTimer(context);
        break;

      case 4:
        _showVolume(context);
        break;

      case 5:
        _getDirectLink();
        break;

      case 6:
        _shareRoom();
        break;

      case 7:
        _showLocalInteraction(context);
        break;

      case 8:
        _openNewWindow();
        break;
    }

    controller.updateUI(isMenuOpen: false);
  }

  void _openLiveRoom() {
    controller.openNaviteAPP();
  }

  void _switchLiveRoom() {
    Get.dialog(PlayOther(controller: controller));
  }

  void _castScreen() {
    final detail = controller.state.value.room.detail;

    LiveUrlTool.castPlayUrlByRoomId(roomId: detail?.roomId ?? '', platform: detail?.platform ?? '');
  }

  void _showTimer(BuildContext context) {
    RoomTimerDialog.show(context: context, controller: controller);
  }

  void _showVolume(BuildContext context) {
    RoomVolumeDialog.show(context: context, controller: controller);
  }

  void _getDirectLink() {
    final detail = controller.state.value.room.detail;

    if (detail == null) {
      return;
    }

    LiveUrlTool.getPlayUrlByRoomId(roomId: detail.roomId ?? '', platform: detail.platform ?? '');
  }

  void _shareRoom() {
    final detail = controller.state.value.room.detail;

    if (detail == null) {
      return;
    }

    ShareCommandHandler.instance.onShareRoomPressed(detail);
  }

  void _showLocalInteraction(BuildContext context) {
    if (!controller.localInteractionController.enabled.v) {
      return;
    }

    final detail = controller.state.value.room.detail;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return LocalInteractionSheet(
          controller: controller.localInteractionController,
          platform: detail?.platform ?? controller.site,
          onMessage: (message, showAsDanmaku) {
            controller.emitLocalMessage(message, showAsDanmaku: showAsDanmaku);
          },
        );
      },
    );
  }

  void _openNewWindow() {
    final detail = controller.state.value.room.detail;

    if (detail == null) {
      return;
    }

    WindowsMultiInstanceLauncher.launch(room: detail).catchError((Object error, StackTrace stackTrace) {
      developer.log(
        'Open live room in a new Windows instance failed',
        name: 'LivePlayPage',
        error: error,
        stackTrace: stackTrace,
      );

      ToastUtil.show(i18n('open_new_window_failed'));
    });
  }

  List<PopupMenuEntry<int>> _buildItems(BuildContext context) {
    return [
      _item(value: 0, icon: Icons.open_in_new_rounded, text: i18n('open_live_room')),

      _item(value: 1, icon: Icons.swap_horiz_outlined, text: i18n('switch_live_room')),

      _item(value: 2, icon: Remix.tv_2_line, text: i18n('cast_screen')),

      _item(value: 3, icon: Remix.time_line, text: i18n('sleep_timer')),

      _item(value: 4, icon: Remix.volume_up_line, text: i18n('room_volume')),

      _item(value: 5, icon: Remix.link_m, text: i18n('toolbox_get_direct_link')),

      _item(value: 6, icon: RemixIcons.share_forward_line, text: i18n('share')),

      if (controller.localInteractionController.enabled.v)
        _item(value: 7, icon: Icons.auto_awesome_rounded, text: i18n('local_interaction_title')),

      if (Platform.isWindows) _item(value: 8, icon: Icons.open_in_new_rounded, text: i18n('open_room_in_new_window')),
    ];
  }

  PopupMenuItem<int> _item({required int value, required IconData icon, required String text}) {
    return PopupMenuItem<int>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: MenuListTile(leading: Icon(icon, size: 20), text: text),
    );
  }
}
