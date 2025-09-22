import 'package:flutter/material.dart';
import 'package:pure_live/common/utils/index.dart';
import 'package:window_manager/window_manager.dart';

class WindowUtil {
  static String title = '纯粹直播';
  static Future<void> init({required double width, required double height}) async {
    double? windowsWidth = PrefUtil.getDouble('windowsWidth') ?? width;
    double? windowsHeight = PrefUtil.getDouble('windowsHeight') ?? height;
    WindowOptions windowOptions = WindowOptions(size: Size(windowsWidth, windowsHeight), center: false);
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  static Future<void> setTitle() async {
    await windowManager.setTitle(title);
  }

  static Future<void> setWindowsPort() async {
    double? windowsXPosition = PrefUtil.getDouble('windowsXPosition') ?? 0.0;
    double? windowsYPosition = PrefUtil.getDouble('windowsYPosition') ?? 0.0;
    double? windowsWidth = PrefUtil.getDouble('windowsWidth') ?? 900;
    double? windowsHeight = PrefUtil.getDouble('windowsHeight') ?? 535;
    windowsWidth = windowsWidth > 400 ? windowsWidth : 400;
    windowsHeight = windowsHeight > 400 ? windowsHeight : 400;
    await windowManager.setBounds(Rect.fromLTWH(windowsXPosition, windowsYPosition, windowsWidth, windowsHeight));
  }

  static void setPosition() async {
    Offset offset = await windowManager.getPosition();
    Size size = await windowManager.getSize();
    bool isFocused = await windowManager.isFocused();
    if (isFocused) {
      await PrefUtil.setDouble('windowsXPosition', offset.dx);
      await PrefUtil.setDouble('windowsYPosition', offset.dy);
      await PrefUtil.setDouble('windowsWidth', size.width);
      await PrefUtil.setDouble('windowsHeight', size.height);
    }
  }
}
