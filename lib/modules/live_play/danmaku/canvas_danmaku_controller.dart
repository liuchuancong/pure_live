// import 'package:canvas_danmaku/canvas_danmaku.dart' as canvas_danmaku;
import 'package:flutter/material.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/plugins/canvas_danmaku/lib/canvas_danmaku.dart';

import 'danmaku_controller_base.dart';

class CanvasDanmakuController extends DanmakuControllerBase {
  static const String type = "Canvas";

  @override
  String getType() => type;

  /// 弹幕
  DanmakuController? danmakuController;
  var settings = SettingsService.instance;

  DanmakuSettingOption options = DanmakuSettingOption();

  @override
  void addDanmaku(IDanmakuContentItem item) {
    danmakuController?.addDanmaku(DanmakuContentItem(
      item.text,
      color: item.color,
      selfSend: item.selfSend,
    ));
  }

  @override
  void clear() {
    danmakuController?.clear();
  }

  @override
  void pause() {
    danmakuController?.pause();
  }

  @override
  void resume() {
    danmakuController?.resume();
  }

  @override
  void updateOption(DanmakuSettingOption option) {
    options = option;
    danmakuController?.updateOption(DanmakuOption(
      fontSize: options.fontSize,
      fontWeight: options.fontWeight,
      duration: options.duration,
      opacity: options.opacity,
      hideBottom: options.hideBottom,
      hideScroll: options.hideScroll,
      hideTop: options.hideTop,
      showStroke: options.showStroke,
      massiveMode: options.massiveMode,
      safeArea: options.safeArea,
    ));
  }

  @override
  void dispose() {
    danmakuController?.clear();
    danmakuController?.pause();
  }

  @override
  Widget getWidget({Key? key}) {
    return DanmakuScreen(
      key: key,
      createdController: (DanmakuController e) {
        danmakuController = e;
      },
      option: DanmakuOption(
        opacity: options.opacity,
        fontSize: options.fontSize,
        fontWeight: options.fontWeight,
        duration: options.duration,
        showStroke: options.showStroke,
        massiveMode: options.massiveMode,
        hideScroll: options.hideScroll,
        hideTop: options.hideTop,
        hideBottom: options.hideBottom,
        safeArea: options.safeArea,
      ),
    );
  }
}
