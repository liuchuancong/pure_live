import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

enum WindowLayoutMode { normal, pip }

@visibleForTesting
Rect resolveWindowsPipBounds({
  required Size defaultSize,
  required Rect primaryWorkArea,
  required List<Rect> workAreas,
  Rect? savedBounds,
}) {
  final availableAreas = workAreas.where((area) => !area.isEmpty && area.isFinite).toList(growable: false);
  final fallbackArea = primaryWorkArea.isEmpty ? const Rect.fromLTWH(0, 0, 1280, 720) : primaryWorkArea;
  final areas = availableAreas.isEmpty ? <Rect>[fallbackArea] : availableAreas;

  final validSavedBounds = savedBounds != null && savedBounds.isFinite && !savedBounds.isEmpty ? savedBounds : null;
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
  final left = (validSavedBounds?.left ?? defaultLeft).clamp(targetArea.left, targetArea.right - width).toDouble();
  final top = (validSavedBounds?.top ?? defaultTop).clamp(targetArea.top, targetArea.bottom - height).toDouble();
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

    final display = await screenRetriever.getPrimaryDisplay();
    final displays = await screenRetriever.getAllDisplays();
    final safeSize = display.visibleSize ?? display.size;
    final safeOffset = display.visiblePosition ?? Offset.zero;

    double w, h;

    final ratio = videoRatio.isFinite && videoRatio > 0 ? videoRatio : 16 / 9;
    if (ratio > 1.05) {
      double maxSide = 360.0;
      w = maxSide;
      h = maxSide / ratio;
    } else if (ratio < 0.95) {
      double maxSide = 380.0;
      h = maxSide;
      w = h * ratio;
      if (w < 140) {
        w = 140;
        h = w / ratio;
      }
    } else {
      double maxSide = 280.0;
      if (ratio >= 1.0) {
        w = maxSide;
        h = maxSide / ratio;
      } else {
        h = maxSide;
        w = h * ratio;
      }
    }
    final windowSettings = SettingsService.to.window;
    final hasSavedBounds =
        windowSettings.windowsPipWidth.v > 0 &&
        windowSettings.windowsPipHeight.v > 0 &&
        windowSettings.windowsPipX.v.isFinite &&
        windowSettings.windowsPipY.v.isFinite;
    final workAreas = displays
        .map((candidate) {
          final size = candidate.visibleSize ?? candidate.size;
          final position = candidate.visiblePosition ?? Offset.zero;
          return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
        })
        .toList(growable: false);
    final bounds = resolveWindowsPipBounds(
      defaultSize: Size(w, h),
      primaryWorkArea: Rect.fromLTWH(safeOffset.dx, safeOffset.dy, safeSize.width, safeSize.height),
      workAreas: workAreas,
      savedBounds: hasSavedBounds
          ? Rect.fromLTWH(
              windowSettings.windowsPipX.v,
              windowSettings.windowsPipY.v,
              windowSettings.windowsPipWidth.v,
              windowSettings.windowsPipHeight.v,
            )
          : null,
    );

    await windowManager.setAlwaysOnTop(SettingsService.to.player.windowsPipAlwaysOnTop.value);
    await windowManager.setMinimumSize(Size.zero);

    await windowManager.setSize(bounds.size);
    await windowManager.setPosition(bounds.topLeft);
    windowSettings.updateWindowsPipGeometry(bounds.size, bounds.topLeft);
  }

  Future<void> exitPiP() async {
    currentMode = WindowLayoutMode.normal;
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setMinimumSize(const Size(800, 600));
    await windowManager.setSize(_savedSize);
    await windowManager.setPosition(_savedPosition);
  }

  Future<void> setPiPAlwaysOnTop(bool value) async {
    if (!Platform.isWindows || currentMode != WindowLayoutMode.pip) return;
    await windowManager.setAlwaysOnTop(value);
  }

  Future<void> capturePiPGeometry() async {
    if (!Platform.isWindows || currentMode != WindowLayoutMode.pip) return;
    final size = await windowManager.getSize();
    final position = await windowManager.getPosition();
    SettingsService.to.window.updateWindowsPipGeometry(size, position);
  }
}
