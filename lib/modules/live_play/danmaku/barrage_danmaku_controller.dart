import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/danmaku_text.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller_panel.dart';
import 'package:pure_live/plugins/barrage.dart';

import 'danmaku_controller_base.dart';

class BarrageDanmakuController extends DanmakuControllerBase {
  static const String type = "Barrage";

  @override
  String getType() => type;

  /// 弹幕
  BarrageWallController danmakuController = BarrageWallController();
  var settings = SettingsService.instance;

  DanmakuSettingOption options = DanmakuSettingOption();

  @override
  void addDanmaku(IDanmakuContentItem item) {
    danmakuController.send([
      Bullet(
        child: DanmakuText(
          item.text,
          fontSize: options.fontSize,
          strokeWidth: options.showStroke ? 2.0 : 0,
          color: item.color,
        ),
      ),
    ]);
  }

  @override
  void clear() {
    danmakuController.reset(0);
  }

  @override
  void pause() {
    danmakuController.disable();
  }

  @override
  void resume() {
    danmakuController.enable();
  }

  @override
  void updateOption(DanmakuSettingOption option) {
    options = option;
  }

  @override
  void dispose() {
    danmakuController.dispose();
  }

  @override
  Widget getWidget({Key? key}) {
    return DanmakuViewer(
      key: key,
      danmakuController: danmakuController,
    );
  }

}
