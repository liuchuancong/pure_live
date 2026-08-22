import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:pure_live/common/services/settings_service.dart';

enum WindowLayoutMode { normal, pip }

class WindowHelper {
  static final WindowHelper instance = WindowHelper._internal();

  WindowHelper._internal();

  final Size defaultSize = const Size(1280, 720);

  WindowLayoutMode currentMode = WindowLayoutMode.normal;

  Size _savedSize = const Size(1280, 720);
  Offset _savedPosition = Offset.zero;

  String? _currentDisplayId;

  Future<void> togglePiP(double videoRatio) async {
    if (!Platform.isWindows) {
      return;
    }

    if (currentMode == WindowLayoutMode.normal) {
      await enterPiP(videoRatio);
    } else {
      await exitPiP();
    }
  }

  Future<void> enterPiP(double videoRatio) async {
    currentMode = WindowLayoutMode.pip;

    _savedSize = await windowManager.getSize();
    _savedPosition = await windowManager.getPosition();

    final displays = await screenRetriever.getAllDisplays();
    final currentPosition = _savedPosition;

    final display = _findDisplayForPosition(displays, currentPosition) ?? await screenRetriever.getPrimaryDisplay();

    _currentDisplayId = display.id;

    final safeSize = display.visibleSize ?? display.size;
    final safeOffset = display.visiblePosition ?? Offset.zero;

    double w;
    double h;

    if (videoRatio > 1.05) {
      const maxSide = 360.0;
      w = maxSide;
      h = maxSide / videoRatio;
    } else if (videoRatio < 0.95) {
      const maxSide = 380.0;
      h = maxSide;
      w = h * videoRatio;

      if (w < 140) {
        w = 140;
        h = w / videoRatio;
      }
    } else {
      const maxSide = 280.0;

      if (videoRatio >= 1.0) {
        w = maxSide;
        h = maxSide / videoRatio;
      } else {
        h = maxSide;
        w = h * videoRatio;
      }
    }

    Offset position;

    final settings = SettingsService.to.player;

    if (settings.rememberPipPosition.value) {
      final savedPosition = settings.getPipWindowPosition(display.id);

      if (savedPosition != null && _isPositionValid(savedPosition, Size(w, h), safeOffset, safeSize)) {
        position = savedPosition;
      } else {
        position = _calculateDefaultPosition(safeOffset, safeSize, Size(w, h));
      }
    } else {
      position = _calculateDefaultPosition(safeOffset, safeSize, Size(w, h));
    }

    await windowManager.setAlwaysOnTop(settings.windowsPipAlwaysOnTop.value);

    await windowManager.setMinimumSize(Size.zero);

    await windowManager.setSize(Size(w, h));
    await windowManager.setPosition(position);
  }

  Future<void> exitPiP() async {
    currentMode = WindowLayoutMode.normal;

    await windowManager.setAlwaysOnTop(false);
    await windowManager.setMinimumSize(const Size(800, 600));
    await windowManager.setSize(_savedSize);
    await windowManager.setPosition(_savedPosition);

    _currentDisplayId = null;
  }

  Future<void> saveCurrentPipPosition() async {
    if (!Platform.isWindows ||
        currentMode != WindowLayoutMode.pip ||
        !SettingsService.to.player.rememberPipPosition.value) {
      return;
    }

    final displayId = _currentDisplayId;

    if (displayId == null) {
      return;
    }

    final position = await windowManager.getPosition();

    await SettingsService.to.player.savePipWindowPosition(displayId, position);
  }

  Future<void> setPiPAlwaysOnTop(bool value) async {
    if (!Platform.isWindows || currentMode != WindowLayoutMode.pip) {
      return;
    }

    await windowManager.setAlwaysOnTop(value);
  }

  Display? _findDisplayForPosition(List<Display> displays, Offset position) {
    for (final display in displays) {
      final offset = display.visiblePosition ?? Offset.zero;
      final size = display.visibleSize ?? display.size;

      final right = offset.dx + size.width;
      final bottom = offset.dy + size.height;

      if (position.dx >= offset.dx && position.dx < right && position.dy >= offset.dy && position.dy < bottom) {
        return display;
      }
    }

    for (final display in displays) {
      final offset = display.visiblePosition ?? Offset.zero;
      final size = display.visibleSize ?? display.size;

      final right = offset.dx + size.width;
      final bottom = offset.dy + size.height;

      if (position.dx < right && position.dx + 1 > offset.dx && position.dy < bottom && position.dy + 1 > offset.dy) {
        return display;
      }
    }

    return null;
  }

  Offset _calculateDefaultPosition(Offset safeOffset, Size safeSize, Size windowSize) {
    double x = safeOffset.dx + safeSize.width - windowSize.width - 20;
    double y = safeOffset.dy + safeSize.height - windowSize.height - 20;

    if (x < safeOffset.dx) {
      x = safeOffset.dx + 20;
    }

    if (y < safeOffset.dy) {
      y = safeOffset.dy + 20;
    }

    return Offset(x, y);
  }

  bool _isPositionValid(Offset position, Size windowSize, Offset safeOffset, Size safeSize) {
    final left = safeOffset.dx;
    final top = safeOffset.dy;
    final right = safeOffset.dx + safeSize.width;
    final bottom = safeOffset.dy + safeSize.height;

    final windowRight = position.dx + windowSize.width;
    final windowBottom = position.dy + windowSize.height;

    const minVisible = 50.0;

    final visibleWidth = min(windowRight, right) - max(position.dx, left);

    final visibleHeight = min(windowBottom, bottom) - max(position.dy, top);

    return visibleWidth >= minVisible && visibleHeight >= minVisible;
  }
}
