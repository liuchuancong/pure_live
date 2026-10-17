import 'package:pure_uikit/pure_uikit.dart';
import 'package:window_manager/window_manager.dart' show windowManager;

export 'package:pure_uikit/pure_uikit.dart'
    show PureCaptionMetrics, PureTitleBar, PureTitleBarLabels, WindowChromeActions;

/// The default actions: [windowManager] is the only window this strip drives.
///
/// The strip itself is the core's shared [PureTitleBar]; this file keeps only
/// the windowing half of the seam, the part that cannot live in a package
/// with no windowing dependency.
final class WindowManagerChromeActions implements WindowChromeActions {
  /// The singleton instance; the class is stateless.
  const new();

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> toggleMaximize() async {
    // window_manager exposes no toggle; maximise/restore is the pair.
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();

  @override
  Future<void> close() => windowManager.close();

  @override
  Future<void> startDragging() => windowManager.startDragging();
}
