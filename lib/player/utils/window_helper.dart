import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/services/settings/window_size_controller.dart';

enum WindowLayoutMode { normal, pip }

@immutable
class WindowsPipDisplay {
  const WindowsPipDisplay({required this.id, required this.size, this.visiblePosition, this.visibleSize});

  factory WindowsPipDisplay.fromDisplay(Display display) {
    return WindowsPipDisplay(
      id: display.id,
      size: display.size,
      visiblePosition: display.visiblePosition,
      visibleSize: display.visibleSize,
    );
  }

  final String id;
  final Size size;
  final Offset? visiblePosition;
  final Size? visibleSize;
}

@immutable
class WindowsPipPreferences {
  const WindowsPipPreferences({
    required this.rememberPosition,
    required this.alwaysOnTop,
    required this.savedDisplayId,
    this.savedBounds,
  });

  final bool rememberPosition;
  final bool alwaysOnTop;
  final String savedDisplayId;
  final Rect? savedBounds;
}

class WindowsPipHost {
  const WindowsPipHost({
    required this.getSize,
    required this.getPosition,
    required this.isAlwaysOnTop,
    required this.isMinimized,
    required this.isMaximized,
    required this.isFullScreen,
    required this.getDisplays,
    required this.getPrimaryDisplay,
    required this.setAlwaysOnTop,
    required this.setMinimumSize,
    required this.setSize,
    required this.setPosition,
  });

  factory WindowsPipHost.system() {
    return WindowsPipHost(
      getSize: windowManager.getSize,
      getPosition: windowManager.getPosition,
      isAlwaysOnTop: windowManager.isAlwaysOnTop,
      isMinimized: windowManager.isMinimized,
      isMaximized: windowManager.isMaximized,
      isFullScreen: windowManager.isFullScreen,
      getDisplays: () async =>
          (await screenRetriever.getAllDisplays()).map(WindowsPipDisplay.fromDisplay).toList(growable: false),
      getPrimaryDisplay: () async => WindowsPipDisplay.fromDisplay(await screenRetriever.getPrimaryDisplay()),
      setAlwaysOnTop: windowManager.setAlwaysOnTop,
      setMinimumSize: windowManager.setMinimumSize,
      setSize: windowManager.setSize,
      setPosition: windowManager.setPosition,
    );
  }

  final Future<Size> Function() getSize;
  final Future<Offset> Function() getPosition;
  final Future<bool> Function() isAlwaysOnTop;
  final Future<bool> Function() isMinimized;
  final Future<bool> Function() isMaximized;
  final Future<bool> Function() isFullScreen;
  final Future<List<WindowsPipDisplay>> Function() getDisplays;
  final Future<WindowsPipDisplay> Function() getPrimaryDisplay;
  final Future<void> Function(bool value) setAlwaysOnTop;
  final Future<void> Function(Size size) setMinimumSize;
  final Future<void> Function(Size size) setSize;
  final Future<void> Function(Offset position) setPosition;
}

typedef WindowsPipPreferencesReader = WindowsPipPreferences Function();
typedef WindowsPipGeometryWriter = void Function(Size size, Offset position, String displayId);
typedef WindowsNormalWindowSizeWriter = void Function(Size size);

WindowsPipPreferences _readWindowsPipPreferences() {
  final windowSettings = SettingsService.to.window;
  final pip = windowSettings.windowsPip;
  return WindowsPipPreferences(
    rememberPosition: windowSettings.rememberPipPosition.value,
    alwaysOnTop: SettingsService.to.player.windowsPipAlwaysOnTop.value,
    savedDisplayId: pip.displayId.value,
    savedBounds: pip.hasValidBounds
        ? Rect.fromLTWH(
            pip.windowsPipX.value,
            pip.windowsPipY.value,
            pip.windowsPipWidth.value,
            pip.windowsPipHeight.value,
          )
        : null,
  );
}

void _writeWindowsPipGeometry(Size size, Offset position, String displayId) {
  SettingsService.to.window.windowsPip.update(size, position, displayId);
}

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

  WindowHelper._internal()
    : this._withDependencies(
        WindowsPipHost.system(),
        _readWindowsPipPreferences,
        _writeWindowsPipGeometry,
        Platform.isWindows,
      );

  @visibleForTesting
  factory WindowHelper.test({
    required WindowsPipHost host,
    required WindowsPipPreferencesReader readPreferences,
    WindowsPipGeometryWriter? writeGeometry,
    bool isWindows = true,
  }) {
    return WindowHelper._withDependencies(host, readPreferences, writeGeometry ?? ((_, _, _) {}), isWindows);
  }

  WindowHelper._withDependencies(this._host, this._readPreferences, this._writeGeometry, this._isWindows);

  final WindowsPipHost _host;
  final WindowsPipPreferencesReader _readPreferences;
  final WindowsPipGeometryWriter _writeGeometry;
  final bool _isWindows;

  final Size defaultSize = const Size(1280, 720);

  WindowLayoutMode currentMode = WindowLayoutMode.normal;

  Size _savedSize = const Size(1280, 720);
  Offset _savedPosition = Offset.zero;
  Future<void> _hostQueue = Future<void>.value();
  Future<void>? _pipTransition;

  Future<void> togglePiP(double videoRatio) async {
    if (!_isWindows) return;

    if (currentMode == WindowLayoutMode.normal) {
      await enterPiP(videoRatio);
    } else {
      await exitPiP();
    }
  }

  Future<void> enterPiP(double videoRatio) {
    final activeTransition = _pipTransition;
    if (activeTransition != null) return activeTransition;
    if (currentMode == WindowLayoutMode.pip) return Future<void>.value();

    late final Future<void> transition;
    transition =
        _serializeHostOperation(() async {
          if (currentMode == WindowLayoutMode.pip) return;
          await _enterPiP(videoRatio);
        }).whenComplete(() {
          if (identical(_pipTransition, transition)) _pipTransition = null;
        });
    _pipTransition = transition;
    return transition;
  }

  Future<void> _enterPiP(double videoRatio) async {
    final normalSize = await _host.getSize();
    final normalPosition = await _host.getPosition();
    final normalAlwaysOnTop = await _host.isAlwaysOnTop();

    final displays = await _host.getDisplays();

    final primaryDisplay = await _host.getPrimaryDisplay();

    final currentDisplay = _findDisplayForPosition(displays, normalPosition) ?? primaryDisplay;

    final safeSize = currentDisplay.visibleSize ?? currentDisplay.size;

    final safeOffset = currentDisplay.visiblePosition ?? Offset.zero;

    final ratio = videoRatio.isFinite && videoRatio > 0 ? videoRatio : 16 / 9;

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

    final preferences = _readPreferences();
    final rememberPosition = preferences.rememberPosition;

    Rect? savedBounds;

    final savedDisplayMatches = preferences.savedDisplayId.isEmpty || preferences.savedDisplayId == currentDisplay.id;

    if (rememberPosition && preferences.savedBounds != null && savedDisplayMatches) {
      savedBounds = preferences.savedBounds;
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

    try {
      await _host.setAlwaysOnTop(preferences.alwaysOnTop);
      await _host.setMinimumSize(Size.zero);
      await _host.setSize(bounds.size);
      await _host.setPosition(bounds.topLeft);

      if (rememberPosition) {
        final resolvedDisplay = _findDisplayForPosition(displays, bounds.topLeft) ?? currentDisplay;
        _writeGeometry(bounds.size, bounds.topLeft, resolvedDisplay.id);
      }
    } catch (error, stackTrace) {
      await _restoreHostWindow(
        alwaysOnTop: normalAlwaysOnTop,
        minimumSize: const Size(WindowSizeController.minWindowWidth, WindowSizeController.minWindowHeight),
        size: normalSize,
        position: normalPosition,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }

    _savedSize = normalSize;
    _savedPosition = normalPosition;
    currentMode = WindowLayoutMode.pip;
  }

  Future<void> exitPiP() {
    final activeTransition = _pipTransition;
    if (activeTransition != null) return activeTransition;
    if (currentMode == WindowLayoutMode.normal) return Future<void>.value();

    late final Future<void> transition;
    transition =
        _serializeHostOperation(() async {
          if (currentMode == WindowLayoutMode.normal) return;
          await _exitPiP();
        }).whenComplete(() {
          if (identical(_pipTransition, transition)) _pipTransition = null;
        });
    _pipTransition = transition;
    return transition;
  }

  Future<void> _exitPiP() async {
    final pipSize = await _host.getSize();
    final pipPosition = await _host.getPosition();
    final pipAlwaysOnTop = await _host.isAlwaysOnTop();

    try {
      await _host.setAlwaysOnTop(false);
      await _host.setMinimumSize(const Size(WindowSizeController.minWindowWidth, WindowSizeController.minWindowHeight));
      await _host.setSize(_savedSize);
      await _host.setPosition(_savedPosition);
    } catch (error, stackTrace) {
      await _restoreHostWindow(
        alwaysOnTop: pipAlwaysOnTop,
        minimumSize: Size.zero,
        size: pipSize,
        position: pipPosition,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }

    currentMode = WindowLayoutMode.normal;
  }

  Future<void> setPiPAlwaysOnTop(bool value) {
    if (!_isWindows || currentMode != WindowLayoutMode.pip) {
      return Future<void>.value();
    }

    return _serializeHostOperation(() async {
      if (currentMode != WindowLayoutMode.pip) return;
      await _host.setAlwaysOnTop(value);
    });
  }

  Future<void> capturePiPGeometry() {
    if (!_isWindows || currentMode != WindowLayoutMode.pip) {
      return Future<void>.value();
    }

    return _serializeHostOperation(_capturePiPGeometry);
  }

  Future<void> captureWindowGeometry(WindowsNormalWindowSizeWriter writeNormalSize) {
    if (!_isWindows) return Future<void>.value();

    return _serializeHostOperation(() async {
      if (currentMode == WindowLayoutMode.pip) {
        await _capturePiPGeometry();
        return;
      }

      if (!await _isRestorableNormalWindow()) return;
      final size = await _host.getSize();
      if (currentMode != WindowLayoutMode.normal || !await _isRestorableNormalWindow()) return;
      writeNormalSize(size);
    });
  }

  Future<void> _capturePiPGeometry() async {
    if (currentMode != WindowLayoutMode.pip) return;
    final preferences = _readPreferences();

    if (!preferences.rememberPosition) return;

    final size = await _host.getSize();
    final position = await _host.getPosition();

    final displays = await _host.getDisplays();

    final display = _findDisplayForPosition(displays, position) ?? await _host.getPrimaryDisplay();

    if (currentMode == WindowLayoutMode.pip) {
      _writeGeometry(size, position, display.id);
    }
  }

  Future<bool> _isRestorableNormalWindow() async {
    if (await _host.isMinimized()) return false;
    if (await _host.isMaximized()) return false;
    return !await _host.isFullScreen();
  }

  Future<void> _serializeHostOperation(Future<void> Function() operation) {
    final result = _hostQueue.then((_) => operation());
    _hostQueue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _restoreHostWindow({
    required bool alwaysOnTop,
    required Size minimumSize,
    required Size size,
    required Offset position,
  }) async {
    final restoreOperations = <Future<void> Function()>[
      () => _host.setMinimumSize(minimumSize),
      () => _host.setSize(size),
      () => _host.setPosition(position),
      () => _host.setAlwaysOnTop(alwaysOnTop),
    ];
    for (final restore in restoreOperations) {
      try {
        await restore();
      } catch (error, stackTrace) {
        debugPrint('Windows PiP host rollback step failed: $error\n$stackTrace');
      }
    }
  }

  WindowsPipDisplay? _findDisplayForPosition(List<WindowsPipDisplay> displays, Offset position) {
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
}
