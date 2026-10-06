typedef DesktopExitAction = Future<void> Function();
typedef DesktopExitDialog = Future<bool> Function();

abstract final class DesktopExitPort {
  static DesktopExitAction? exitApplication;
  static DesktopExitDialog? showExitDialog;

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
