import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

enum WindowLayoutMode { normal, pip }

class WindowHelper {
  static final WindowHelper instance = WindowHelper._internal();
  WindowHelper._internal();

  final Size defaultSize = const Size(1280, 720);
  WindowLayoutMode currentMode = WindowLayoutMode.normal;

  Size _savedSize = const Size(1280, 720);
  Offset _savedPosition = Offset.zero;

  Future<void> togglePiP(double videoRatio) async {
    if (!Platform.isWindows) return;

    if (currentMode == WindowLayoutMode.normal) {
      await _enterPiP(videoRatio);
    } else {
      await _exitPiP();
    }
  }

  Future<void> _enterPiP(double videoRatio) async {
    currentMode = WindowLayoutMode.pip;

    _savedSize = await windowManager.getSize();
    _savedPosition = await windowManager.getPosition();

    Display display = await screenRetriever.getPrimaryDisplay();
    Size safeSize = display.visibleSize ?? display.size;
    Offset safeOffset = display.visiblePosition ?? Offset.zero;

    double w, h;

    if (videoRatio > 1.05) {
      double maxSide = 360.0;
      w = maxSide;
      h = maxSide / videoRatio;
    } else if (videoRatio < 0.95) {
      double maxSide = 380.0;
      h = maxSide;
      w = h * videoRatio;
      if (w < 140) {
        w = 140;
        h = w / videoRatio;
      }
    } else {
      double maxSide = 280.0;
      if (videoRatio >= 1.0) {
        w = maxSide;
        h = maxSide / videoRatio;
      } else {
        h = maxSide;
        w = h * videoRatio;
      }
    }

    double x = (safeOffset.dx + safeSize.width) - w - 20;
    double y = (safeOffset.dy + safeSize.height) - h - 20;

    if (x < safeOffset.dx) x = safeOffset.dx + 20;
    if (y < safeOffset.dy) y = safeOffset.dy + 20;

    await windowManager.setAlwaysOnTop(true);
    await windowManager.setMinimumSize(Size.zero);

    await windowManager.setSize(Size(w, h));
    await windowManager.setPosition(Offset(x, y));
  }

  Future<void> _exitPiP() async {
    currentMode = WindowLayoutMode.normal;
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setMinimumSize(const Size(800, 600));
    await windowManager.setSize(_savedSize);
    await windowManager.setPosition(_savedPosition);
  }
}
