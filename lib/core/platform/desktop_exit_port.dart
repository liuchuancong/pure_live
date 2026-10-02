/// 桌面退出流程接口。
///
/// 真正的退出流程要落盘设置、清掉 B 站网页登录态、注销托盘、弹退出确认框——
/// 这些已经超出 Core 的平台能力范围，实现留在 App 层的 DesktopExitFlow。
/// App 装配层在启动时绑定，Core 因此不反向 import App。
typedef DesktopExitAction = Future<void> Function();
typedef DesktopExitDialog = Future<bool> Function();

abstract final class DesktopExitPort {
  static DesktopExitAction? exitApplication;
  static DesktopExitDialog? showExitDialog;

  /// 未绑定实现时按「不退出」处理：宁可窗口留着，也不要静默跳过用户的退出意图。
  static Future<void> requestExit() async {
    final action = exitApplication;
    if (action == null) return;
    await action();
  }

  static Future<void> requestExitDialog() async {
    final dialog = showExitDialog;
    if (dialog == null) return;
    await dialog();
  }
}
