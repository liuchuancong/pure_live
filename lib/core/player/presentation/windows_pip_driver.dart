import 'package:flutter/painting.dart' show Offset, Rect, Size;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:media_core/media_core.dart' show PresentationLifecycleHooks;
import 'package:media_core_pip/media_core_pip.dart';
import 'package:pure_live/core/player/presentation/compact_source_orientation.dart';
import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/core/config/window_size_controller.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

final DisplayAwarePipWindow windowsPipWindow = DisplayAwarePipWindow(
  workAreasReader: _readWorkAreas,
  readSavedBounds: _readSavedBounds,
  writeSavedBounds: _writeSavedBounds,
  alwaysOnTop: () => SettingsService.to.player.windowsPipAlwaysOnTop.value,
  normalMinSize: const Size(WindowSizeController.minWindowWidth, WindowSizeController.minWindowHeight),
);

PipConfig pipConfigFromSettings() {
  final settings = SettingsService.to.player;
  return PipConfig.defaults.copyWith(
    width: settings.windowsPipBaseSize.value,
    height: settings.windowsPipBaseSize.value * 9 / 16,
    minWidth: settings.windowsPipMinWidth.value,
    minHeight: settings.windowsPipMinHeight.value,
    // 小窗保留任务栏按钮：画中画期间主窗口只是缩小，观众仍要能在任务栏上找到并切回它
    // （隐藏任务栏/Alt-Tab 是企业版画中画的惯例，这里不采用）。
    skipTaskbar: false,
    // 自由比例：不锁定视频形状，用户可以单独压高度或拉宽度（画面按比例适配留黑边）。
    // 默认关闭＝窗口始终等于视频形状。
    lockAspectRatio: !settings.windowsPipFreeAspect.value,
    title: 'Pure Live',
  );
}

final PipDriver windowsPipDriver = PipDriver(
  desktopWindow: windowsPipWindow,
  config: pipConfigFromSettings(),
  // Transition diagnostics: the native restore path is exactly four style/
  // placement calls, and when a viewer reports a broken window after a
  // transition these four lines say which leg never ran.
  lifecycleHooks: PresentationLifecycleHooks(
    // The resolved policy is logged, not just the transition: "the window keeps
    // snapping back to the video shape" and "the floor is not the number I set"
    // are indistinguishable from the outside, and the two settings that decide
    // them live in the driver's config rather than in the request.
    beforeEnter: (_) async {
      final config = windowsPipDriver.config;
      CoreLog.i(
        'pip: entering the desktop small window '
        'lockAspectRatio=${config.lockAspectRatio} '
        'min=${config.minWidth.round()}x${config.minHeight.round()} '
        'base=${config.width.round()}',
      );
    },
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
  // 横竖屏各一套：横屏记住的矩形套到竖屏源上只剩黑边，所以按当前源方向选。
  if (CompactSourceOrientation.isPortrait) {
    if (!pip.portraitHasValidBounds) return null;
    return PipSavedBounds(
      displayId: pip.portraitDisplayId.value,
      bounds: Rect.fromLTWH(
        pip.portraitX.value,
        pip.portraitY.value,
        pip.portraitWidth.value,
        pip.portraitHeight.value,
      ),
    );
  }
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
  final pip = SettingsService.to.window.windowsPip;
  if (CompactSourceOrientation.isPortrait) {
    pip.updatePortrait(size, position, displayId);
    return;
  }
  pip.update(size, position, displayId);
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
