import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

class DanmakuController extends GetxController {
  late LiveDanmaku liveDanmaku;

  LivePlayController get _main => Get.find<LivePlayController>();
  LivePlayState get _state => _main.state.value;

  void initDanmaku(LiveDanmaku danmaku) {
    liveDanmaku = danmaku;
  }

  bool needReconnect(LiveRoom room) {
    final currentRoomId = _state.danmaku.currentDanmakuRoomId;
    final newRoomId = room.roomId?.toString();

    if (currentRoomId == null) return true;
    if (currentRoomId != newRoomId) return true;
    if (!liveDanmaku.isConnected) return true;

    return false;
  }

  void setupDanmaku() {
    final room = _state.room.detail;
    if (room == null) return;
    if (!SettingsService.to.danmaku.enableDanmakuDisplay.v) return;

    if (room.isRecord == true) {
      _main.addSystemMessage(i18n('recording_mode_notice'));
    }

    _main.addSystemMessage(i18n('connect_danmaku_server'));

    liveDanmaku.onMessage = (msg) {
      if (msg.type == LiveMessageType.chat) {
        if (SettingsService.to.fav.shieldList.v.every((e) => !msg.message.contains(e))) {
          _main.addDanmakuMessage(msg);
          final videoController = _state.player.videoController;
          if (videoController != null) {
            videoController.sendDanmaku(msg);
          }
        }
      }
    };

    liveDanmaku.onClose = (msg) {
      _main.addSystemMessage(msg);
    };

    liveDanmaku.onReady = () {
      _main.addSystemMessage(i18n('danmaku_connected'));
    };
  }

  void stopDanmaku() {
    liveDanmaku.stop();
  }
}
