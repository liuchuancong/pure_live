import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:pure_live/common/services/settings_service.dart';

class PureLivePipWidget extends StatefulWidget {
  const PureLivePipWidget({super.key, required this.child});

  final Widget child;

  @override
  State<PureLivePipWidget> createState() => _PureLivePipWidgetState();
}

class _PureLivePipWidgetState extends State<PureLivePipWidget> with WindowListener {
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();

    if (Platform.isWindows) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();

    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }

    super.dispose();
  }

  @override
  void onWindowMove() {
    _scheduleSavePosition();
  }

  @override
  void onWindowMoved() {
    _scheduleSavePosition();
  }

  void _scheduleSavePosition() {
    if (!Platform.isWindows) {
      return;
    }

    if (!SettingsService.to.player.rememberPipPosition.value) {
      return;
    }

    _saveTimer?.cancel();

    _saveTimer = Timer(const Duration(milliseconds: 150), _savePosition);
  }

  Future<void> _savePosition() async {
    if (!Platform.isWindows) {
      return;
    }

    if (!SettingsService.to.player.rememberPipPosition.value) {
      return;
    }

    try {
      final position = await windowManager.getPosition();
      final display = await _getDisplayForPosition(position);

      if (display == null) {
        return;
      }

      await SettingsService.to.player.savePipWindowPosition(display.id, position);
    } catch (_) {}
  }

  Future<Display?> _getDisplayForPosition(Offset position) async {
    final displays = await screenRetriever.getAllDisplays();

    if (displays.isEmpty) {
      return null;
    }

    final windowSize = await windowManager.getSize();

    final windowCenter = Offset(position.dx + windowSize.width / 2, position.dy + windowSize.height / 2);

    for (final display in displays) {
      final displayPosition = display.visiblePosition ?? Offset.zero;
      final displaySize = display.visibleSize ?? display.size;

      final rect = Rect.fromLTWH(displayPosition.dx, displayPosition.dy, displaySize.width, displaySize.height);

      if (rect.contains(windowCenter)) {
        return display;
      }
    }

    Display? nearestDisplay;
    double nearestDistance = double.infinity;

    for (final display in displays) {
      final displayPosition = display.visiblePosition ?? Offset.zero;
      final displaySize = display.visibleSize ?? display.size;

      final displayCenter = Offset(
        displayPosition.dx + displaySize.width / 2,
        displayPosition.dy + displaySize.height / 2,
      );

      final dx = windowCenter.dx - displayCenter.dx;
      final dy = windowCenter.dy - displayCenter.dy;
      final distance = dx * dx + dy * dy;

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestDisplay = display;
      }
    }

    return nearestDisplay;
  }

  Future<void> restorePosition() async {
    if (!Platform.isWindows) {
      return;
    }

    if (!SettingsService.to.player.rememberPipPosition.value) {
      return;
    }

    try {
      final position = await windowManager.getPosition();
      final display = await _getDisplayForPosition(position);

      if (display == null) {
        return;
      }

      final savedPosition = SettingsService.to.player.getPipWindowPosition(display.id);

      if (savedPosition == null) {
        return;
      }

      final size = await windowManager.getSize();

      final safePosition = await _clampPositionToDisplay(savedPosition, size, display);

      await windowManager.setPosition(safePosition);
    } catch (_) {}
  }

  Future<Offset> _clampPositionToDisplay(Offset position, Size windowSize, Display display) async {
    final displayPosition = display.visiblePosition ?? Offset.zero;
    final displaySize = display.visibleSize ?? display.size;

    final minX = displayPosition.dx;
    final minY = displayPosition.dy;

    final maxX = displayPosition.dx + displaySize.width - windowSize.width;

    final maxY = displayPosition.dy + displaySize.height - windowSize.height;

    return Offset(
      position.dx.clamp(minX, maxX > minX ? maxX : minX),
      position.dy.clamp(minY, maxY > minY ? maxY : minY),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return widget.child;
    }

    return Stack(
      children: [
        DragToResizeArea(
          child: Container(color: Colors.black, child: widget.child),
        ),
      ],
    );
  }
}
