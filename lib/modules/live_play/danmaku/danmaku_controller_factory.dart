import 'barrage_danmaku_controller.dart';
import 'canvas_danmaku_controller.dart';
import 'danmaku_controller_base.dart';

final class DanmakuControllerfactory {
  /// 获取支持弹幕类型
  static List<String> getDanmakuControllerTypeList() {
    return [
      BarrageDanmakuController.type,
      CanvasDanmakuController.type,
    ];
  }

  /// 获取支持弹幕类型对应对象
  static DanmakuControllerBase getDanmakuController(String type) {
    switch (type) {
      case BarrageDanmakuController.type:
        return BarrageDanmakuController();
      case CanvasDanmakuController.type:
        return CanvasDanmakuController();
      default:
        return BarrageDanmakuController();
    }
  }
}
