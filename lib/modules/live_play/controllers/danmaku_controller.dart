import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

class DanmakuController extends GetxController {
  DanmakuController(this._main);

  final LivePlayController _main;
  late LiveDanmaku liveDanmaku;
  bool _initialized = false;
  Worker? _settingsWorker;

  LivePlayState get _state => _main.state.value;

  @override
  void onInit() {
    super.onInit();
    final settings = SettingsService.to.danmaku;
    _settingsWorker = everAll([
      settings.enableDanmakuDisplay,
      settings.enablePipDanmaku,
    ], (_) => _syncConnectionForSettings());
  }

  void initDanmaku(LiveDanmaku danmaku) {
    if (_initialized) {
      liveDanmaku.stop();
    }
    liveDanmaku = danmaku;
    _initialized = true;
  }

  bool needReconnect(LiveRoom room) {
    if (!_initialized) return true;
    final currentRoomId = _state.danmaku.currentDanmakuRoomId;
    final newRoomId = room.roomId?.toString();

    if (currentRoomId == null) return true;
    if (currentRoomId != newRoomId) return true;
    if (!liveDanmaku.isConnected) return true;

    return false;
  }

  void setupDanmaku() {
    if (!_initialized) return;
    final room = _state.room.detail;
    if (room == null) return;
    final settings = SettingsService.to.danmaku;
    if (!settings.enableDanmakuDisplay.v && !settings.enablePipDanmaku.v) return;

    if (room.isRecord == true) {
      _main.addSystemMessage(i18n('recording_mode_notice'));
    }

    _main.addSystemMessage(i18n('connect_danmaku_server'));

    liveDanmaku.onMessage = (msg) {
      if (msg.type == LiveMessageType.chat) {
        final favorite = SettingsService.to.fav;
        final blockedUser = favorite.blockedDanmakuUsers.any(
          (user) => user.toLowerCase() == msg.userName.trim().toLowerCase(),
        );
        final blockedKeyword = favorite.shieldList.any(
          (keyword) => keyword.isNotEmpty && msg.message.toLowerCase().contains(keyword.toLowerCase()),
        );
        if (!blockedUser && !blockedKeyword) {
          _main.addDanmakuMessage(msg);
          final videoController = _state.player.videoController;
          if (videoController != null) {
            videoController.sendDanmaku(msg);
          }
        }
      } else if (msg.type == LiveMessageType.online) {
        _main.updateRuntimeAudience(msg.data);
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
    if (_initialized) liveDanmaku.stop();
  }

  void _syncConnectionForSettings() {
    if (!_initialized) return;
    final room = _state.room.detail;
    if (room == null) return;
    const except = [Sites.kuaishouSite, Sites.iptvSite, Sites.ccSite];
    if (except.contains(room.platform)) return;

    final settings = SettingsService.to.danmaku;
    if (!settings.enableDanmakuDisplay.v && !settings.enablePipDanmaku.v) {
      stopDanmaku();
      _main.updateDanmakuRoomId(null);
      return;
    }

    if (needReconnect(room)) {
      setupDanmaku();
      liveDanmaku.start(room.danmakuData);
      _main.updateDanmakuRoomId(room.roomId);
    }
  }

  @override
  void onClose() {
    _settingsWorker?.dispose();
    super.onClose();
  }
}
