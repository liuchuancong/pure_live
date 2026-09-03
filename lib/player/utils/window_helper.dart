import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:pure_live/common/services/settings_service.dart';

enum WindowLayoutMode { normal, pip }

@visibleForTesting
Rect resolveWindowsPipBounds({
  required Size defaultSize,
  required Rect primaryWorkArea,
  required List<Rect> workAreas,
  Rect? savedBounds,
}) {
  final availableAreas = workAreas
      .where((area) => !area.isEmpty && area.isFinite)
      .toList(growable: false);

  final fallbackArea = primaryWorkArea.isEmpty
      ? const Rect.fromLTWH(0, 0, 1280, 720)
      : primaryWorkArea;

  final areas = availableAreas.isEmpty ? <Rect>[fallbackArea] : availableAreas;

  final validSavedBounds = savedBounds != null && savedBounds.isFinite && !savedBounds.isEmpty
      ? savedBounds
      : null;

  Rect? targetArea;

  if (validSavedBounds != null) {
    for (final area in areas) {
      final overlap = validSavedBounds.intersect(area);

      if (overlap.width >= 48 && overlap.height >= 48) {
        targetArea = area;
        break;
      }
    }
  }

  targetArea ??= areas.firstWhere(
    (area) => area.overlaps(fallbackArea) || area.contains(fallbackArea.center),
    orElse: () => areas.first,
  );

  final requested = validSavedBounds?.size ?? defaultSize;

  final minWidth = targetArea.width < 140 ? targetArea.width : 140.0;
  final minHeight = targetArea.height < 90 ? targetArea.height : 90.0;

  final width = requested.width.clamp(minWidth, targetArea.width).toDouble();

  final height = requested.height.clamp(minHeight, targetArea.height).toDouble();

  final defaultLeft = targetArea.right - width - 20;
  final defaultTop = targetArea.bottom - height - 20;

  final left = (validSavedBounds?.left ?? defaultLeft)
      .clamp(targetArea.left, targetArea.right - width)
      .toDouble();

  final top = (validSavedBounds?.top ?? defaultTop)
      .clamp(targetArea.top, targetArea.bottom - height)
      .toDouble();

  return Rect.fromLTWH(left, top, width, height);
}

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
    final primaryDisplay = await screenRetriever.getPrimaryDisplay();

    final currentDisplay = _findDisplayForPosition(displays, _savedPosition) ?? primaryDisplay;

    final safeSize = currentDisplay.visibleSize ?? currentDisplay.size;
    final safeOffset = currentDisplay.visiblePosition ?? Offset.zero;

    final ratio = videoRatio.isFinite && videoRatio > 0 ? videoRatio : 16 / 9;

    final isPortrait = ratio < 0.95;

    double w;
    double h;

    if (ratio > 1.05) {
      const maxSide = 360.0;

      w = maxSide;
      h = maxSide / ratio;
    } else if (ratio < 0.95) {
      const maxSide = 380.0;

      h = maxSide;
      w = h * ratio;

      if (w < 140) {
        w = 140;
        h = w / ratio;
      }
    } else {
      const maxSide = 280.0;

      if (ratio >= 1.0) {
        w = maxSide;
        h = maxSide / ratio;
      } else {
        h = maxSide;
        w = h * ratio;
      }
    }

    final windowSettings = SettingsService.to.window;
    final pip = windowSettings.windowsPip;
    final rememberPosition = windowSettings.rememberPipPosition.value;

    final savedDisplayId = isPortrait ? pip.portraitDisplayId.value : pip.displayId.value;

    final savedHasValidBounds = isPortrait ? pip.portraitIsValid : pip.isValid;

    final savedWidth = isPortrait ? pip.portraitWidth.value : pip.windowsPipWidth.value;

    final savedHeight = isPortrait ? pip.portraitHeight.value : pip.windowsPipHeight.value;

    final savedX = isPortrait ? pip.portraitX.value : pip.windowsPipX.value;

    final savedY = isPortrait ? pip.portraitY.value : pip.windowsPipY.value;

    Rect? savedBounds;

    final savedDisplayMatches = savedDisplayId.isEmpty || savedDisplayId == currentDisplay.id;

    if (rememberPosition && savedHasValidBounds && savedDisplayMatches) {
      savedBounds = Rect.fromLTWH(savedX, savedY, savedWidth, savedHeight);
    }

    final workAreas = displays
        .map((display) {
          final size = display.visibleSize ?? display.size;

          final position = display.visiblePosition ?? Offset.zero;

          return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
        })
        .toList(growable: false);

    final bounds = resolveWindowsPipBounds(
      defaultSize: Size(w, h),
      primaryWorkArea: Rect.fromLTWH(safeOffset.dx, safeOffset.dy, safeSize.width, safeSize.height),
      workAreas: workAreas,
      savedBounds: savedBounds,
    );

    await windowManager.setAlwaysOnTop(SettingsService.to.player.windowsPipAlwaysOnTop.value);

    await windowManager.setMinimumSize(Size.zero);

    await windowManager.setSize(bounds.size);
    await windowManager.setPosition(bounds.topLeft);

    if (rememberPosition) {
      final resolvedDisplay = _findDisplayForPosition(displays, bounds.topLeft) ?? currentDisplay;

      if (isPortrait) {
        pip.updatePortrait(bounds.size, bounds.topLeft, resolvedDisplay.id);
      } else {
        pip.update(bounds.size, bounds.topLeft, resolvedDisplay.id);
      }
    }
  }

  Future<void> exitPiP() async {
    currentMode = WindowLayoutMode.normal;

    await windowManager.setAlwaysOnTop(false);

    await windowManager.setMinimumSize(const Size(800, 600));

    await windowManager.setSize(_savedSize);
    await windowManager.setPosition(_savedPosition);
  }

  Future<void> setPiPAlwaysOnTop(bool value) async {
    if (!Platform.isWindows || currentMode != WindowLayoutMode.pip) {
      return;
    }

    await windowManager.setAlwaysOnTop(value);
  }

  Future<void> capturePiPGeometry({double? videoRatio}) async {
    if (!Platform.isWindows || currentMode != WindowLayoutMode.pip) {
      return;
    }

    final windowSettings = SettingsService.to.window;

    if (!windowSettings.rememberPipPosition.value) {
      return;
    }

    final size = await windowManager.getSize();
    final position = await windowManager.getPosition();

    final displays = await screenRetriever.getAllDisplays();

    final display =
        _findDisplayForPosition(displays, position) ?? await screenRetriever.getPrimaryDisplay();

    final ratio = videoRatio != null && videoRatio.isFinite && videoRatio > 0
        ? videoRatio
        : size.width / size.height;

    final isPortrait = ratio < 0.95;

    if (isPortrait) {
      windowSettings.windowsPip.updatePortrait(size, position, display.id);
    } else {
      windowSettings.windowsPip.update(size, position, display.id);
    }
  }

  Display? _findDisplayForPosition(List<Display> displays, Offset position) {
    for (final display in displays) {
      final offset = display.visiblePosition ?? Offset.zero;

      final size = display.visibleSize ?? display.size;

      final right = offset.dx + size.width;
      final bottom = offset.dy + size.height;

      if (position.dx >= offset.dx &&
          position.dx < right &&
          position.dy >= offset.dy &&
          position.dy < bottom) {
        return display;
      }
    }

    for (final display in displays) {
      final offset = display.visiblePosition ?? Offset.zero;

      final size = display.visibleSize ?? display.size;

      final right = offset.dx + size.width;
      final bottom = offset.dy + size.height;

      if (position.dx < right &&
          position.dx + 1 > offset.dx &&
          position.dy < bottom &&
          position.dy + 1 > offset.dy) {
        return display;
      }
    }

    return null;
  }
}
