import 'package:pure_live/get/get.dart';
import 'package:pure_live/pkg/canvas_danmaku/models/danmaku_option.dart';
import 'package:pure_live/pkg/canvas_danmaku/models/danmaku_content_item.dart';

class DanmakuController extends GetxController {
  void Function(DanmakuContentItem)? _onAddDanmaku;
  void Function(DanmakuOption)? _onUpdateOption;
  void Function()? _onPause;
  void Function()? _onResume;
  void Function()? _onClear;

  bool running = true;
  DanmakuOption option = DanmakuOption();

  DanmakuController();

  set onAddDanmaku(void Function(DanmakuContentItem) callback) => _onAddDanmaku = callback;
  set onUpdateOption(void Function(DanmakuOption) callback) => _onUpdateOption = callback;
  set onPause(void Function() callback) => _onPause = callback;
  set onResume(void Function() callback) => _onResume = callback;
  set onClear(void Function() callback) => _onClear = callback;

  void pause() {
    running = false;
    _onPause?.call();
  }

  void resume() {
    running = true;
    _onResume?.call();
  }

  void clear() {
    _onClear?.call();
  }

  void addDanmaku(DanmakuContentItem item) {
    if (!running) return;
    _onAddDanmaku?.call(item);
  }

  void updateOption(DanmakuOption newOption) {
    option = newOption;
    _onUpdateOption?.call(newOption);
  }

  @override
  void onClose() {
    _onAddDanmaku = null;
    _onUpdateOption = null;
    _onPause = null;
    _onResume = null;
    _onClear = null;
    super.onClose();
  }
}
