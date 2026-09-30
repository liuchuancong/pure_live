import 'package:flutter/painting.dart' show Offset, Size;
import 'package:media_core/media_core.dart' as mc;
import 'package:media_core_pip/media_core_pip.dart';
import 'package:window_manager/window_manager.dart';

import 'window_helper.dart';

/// media_core_pip 的 [PipWindow] 适配层：小窗进出沿用 WindowHelper 既有的
/// 多显示器/记忆位置/最小尺寸几何，PipDriver 只负责快照、状态与恢复契约。
final class WindowsGeometryPipWindow implements PipWindow {
  const WindowsGeometryPipWindow();

  @override
  Future<PipWindowSnapshot> capture() async {
    final bounds = await windowManager.getBounds();
    return PipWindowSnapshot(
      bounds: bounds,
      alwaysOnTop: await windowManager.isAlwaysOnTop(),
      resizable: await windowManager.isResizable(),
      skipTaskbar: await windowManager.isSkipTaskbar(),
      title: await windowManager.getTitle(),
    );
  }

  @override
  Future<void> applySmallWindow({
    required Size size,
    required Offset position,
    required double? aspectRatio,
    required bool alwaysOnTop,
    required bool resizable,
    required bool skipTaskbar,
    required String title,
  }) async {
    await WindowHelper.instance.enterPiP(aspectRatio ?? size.width / size.height);
  }

  @override
  Future<void> restore(PipWindowSnapshot snapshot) async {
    await WindowHelper.instance.exitPiP();
  }
}

final PipDriver windowsPipDriver = PipDriver(desktopWindow: const WindowsGeometryPipWindow());

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
