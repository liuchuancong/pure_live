import 'package:flutter/painting.dart' show Offset, Rect, Size;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:media_core/media_core.dart' show PresentationLifecycleHooks;
import 'package:media_core_pip/media_core_pip.dart';
import 'package:pure_live/services/settings_service.dart';
import 'package:pure_live/services/settings/window_size_controller.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

final DisplayAwarePipWindow windowsPipWindow = DisplayAwarePipWindow(
  workAreasReader: _readWorkAreas,
  readSavedBounds: _readSavedBounds,
  writeSavedBounds: _writeSavedBounds,
  alwaysOnTop: () => SettingsService.to.player.windowsPipAlwaysOnTop.value,
  normalMinSize: const Size(WindowSizeController.minWindowWidth, WindowSizeController.minWindowHeight),
);

final PipDriver windowsPipDriver = PipDriver(
  desktopWindow: windowsPipWindow,
  // Transition diagnostics: the native restore path is exactly four style/
  // placement calls, and when a viewer reports a broken window after a
  // transition these four lines say which leg never ran.
  lifecycleHooks: PresentationLifecycleHooks(
    beforeEnter: (_) async => CoreLog.i('pip: entering the desktop small window'),
    afterEnter: (_) async {
      CoreLog.i('pip: entered the desktop small window');
      await _logPipGeometry();
    },
    beforeExit: (_) async => CoreLog.i('pip: leaving the desktop small window'),
    afterExit: (_) async => CoreLog.i('pip: left the desktop small window'),
  ),
);

/// Window frame vs the size Flutter is actually laying out at.
///
/// A compact window that keeps rendering the pre-fullscreen scene shows the
/// symptom (a cropped picture) while every style call reports success, and the
/// only way to tell that apart from a fit problem is to compare the two.
Future<void> _logPipGeometry() async {
  try {
    final bounds = await windowManager.getBounds();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final logical = view.physicalSize / view.devicePixelRatio;
    CoreLog.i(
      'pip: geometry window=${bounds.width.round()}x${bounds.height.round()} '
      'view=${logical.width.round()}x${logical.height.round()} '
      'dpr=${view.devicePixelRatio} fullscreen=${await windowManager.isFullScreen()}',
    );
  } catch (error) {
    CoreLog.e('pip: geometry probe failed: $error', StackTrace.current);
  }
}

Future<List<PipWorkArea>> _readWorkAreas() async {
  final displays = await screenRetriever.getAllDisplays();
  final areas = <PipWorkArea>[
    for (final display in displays)
      PipWorkArea(
        id: display.id.toString(),
        area: Rect.fromLTWH(
          (display.visiblePosition ?? Offset.zero).dx,
          (display.visiblePosition ?? Offset.zero).dy,
          (display.visibleSize ?? display.size).width,
          (display.visibleSize ?? display.size).height,
        ),
      ),
  ];
  if (areas.isEmpty) {
    final primary = await screenRetriever.getPrimaryDisplay();
    return [
      PipWorkArea(
        id: primary.id.toString(),
        area: Rect.fromLTWH(
          (primary.visiblePosition ?? Offset.zero).dx,
          (primary.visiblePosition ?? Offset.zero).dy,
          (primary.visibleSize ?? primary.size).width,
          (primary.visibleSize ?? primary.size).height,
        ),
      ),
    ];
  }
  return areas;
}

PipSavedBounds? _readSavedBounds() {
  final windowSettings = SettingsService.to.window;
  final pip = windowSettings.windowsPip;
  if (!windowSettings.rememberPipPosition.value) return null;
  if (!pip.hasValidBounds) return null;
  return PipSavedBounds(
    displayId: pip.displayId.value,
    bounds: Rect.fromLTWH(
      pip.windowsPipX.value,
      pip.windowsPipY.value,
      pip.windowsPipWidth.value,
      pip.windowsPipHeight.value,
    ),
  );
}

void _writeSavedBounds(Size size, Offset position, String displayId) {
  SettingsService.to.window.windowsPip.update(size, position, displayId);
}

Future<void> setWindowsPipAlwaysOnTop(bool value) {
  return windowsPipWindow.setAlwaysOnTop(value);
}

Future<void> captureWindowsWindowGeometry(void Function(Size size) writeNormal) async {
  if (windowsPipWindow.isCompact) {
    await windowsPipWindow.captureGeometry();
    return;
  }
  if (await windowManager.isMinimized() || await windowManager.isMaximized() || await windowManager.isFullScreen()) {
    return;
  }
  writeNormal(await windowManager.getSize());
}
