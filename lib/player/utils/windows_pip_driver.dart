import 'package:flutter/painting.dart' show Offset, Rect, Size;
import 'package:media_core/media_core.dart' as mc;
import 'package:media_core_pip/media_core_pip.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/services/settings/window_size_controller.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// Windows 小窗播放：media_core_pip 的 [DisplayAwarePipWindow] 承担全部
/// 几何策略（多显示器、记忆位置、最小尺寸释放、回滚），pure_live 只通过
/// 钩子提供设置持久化（rememberPipPosition / windowsPip 偏好）。
final DisplayAwarePipWindow windowsPipWindow = DisplayAwarePipWindow(
  workAreasReader: _readWorkAreas,
  readSavedBounds: _readSavedBounds,
  writeSavedBounds: _writeSavedBounds,
  alwaysOnTop: () => SettingsService.to.player.windowsPipAlwaysOnTop.value,
  normalMinSize: const Size(WindowSizeController.minWindowWidth, WindowSizeController.minWindowHeight),
);

final PipDriver windowsPipDriver = PipDriver(desktopWindow: windowsPipWindow);

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

Future<void> pipDrivenWindowsPipEnter(double videoRatio) async {
  await windowsPipDriver.initialize();
  final ratio = videoRatio.isFinite && videoRatio > 0 ? videoRatio : 16 / 9;
  windowsPipDriver.onVideoSize((ratio * 1000).round(), 1000);
  await windowsPipDriver.apply(mc.PlayerId('pure-live-windows-pip'), mc.PresentationRequest.pip());
}

Future<void> pipDrivenWindowsPipExit() async {
  await windowsPipDriver.initialize();
  await windowsPipDriver.apply(mc.PlayerId('pure-live-windows-pip'), mc.PresentationRequest.normal());
}

/// PiP 中的置顶设置即时生效；非小窗态无操作。
Future<void> setWindowsPipAlwaysOnTop(bool value) {
  return windowsPipWindow.setAlwaysOnTop(value);
}

/// 窗口几何采集：小窗态持久化小窗几何，正常态交给 [writeNormal]。
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
