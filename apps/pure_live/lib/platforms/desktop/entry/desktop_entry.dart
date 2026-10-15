import 'dart:async' show unawaited;

import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/desktop/tray/app_tray.dart';
import 'package:pure_live/platforms/desktop/windows/desktop_window_setup.dart';
import 'package:window_manager/window_manager.dart';

/// The desktop window's life: set up before the first frame, asked about
/// every close, gone last.
///
/// The close button never closes anything by itself — the answer comes from
/// [resolveCloseDisposition], which weighs the viewer's chosen action
/// against the tray's health (a hidden window nothing can bring back is a
/// lost window). The chosen action is quit until the settings wave adds
/// hide-to-tray as a choice; the machinery is already the disposition's.
final class DesktopEntry with WindowListener {
  /// Prepares the desktop window for [kind]; [onQuitRequest] runs the app's
  /// own shutdown (storage, log) before the window goes away.
  new({required this.kind, required this.onQuitRequest});

  /// The desktop platform this window lives on.
  final PlatformKind kind;

  /// Runs the app shutdown; the window is destroyed after it returns.
  final Future<void> Function() onQuitRequest;

  late final AppTray _tray = AppTray(onShow: show, onQuit: () => unawaited(quit()));
  bool _trayUp = false;
  bool _quitting = false;

  /// Sets the window up, creates the tray and starts intercepting closes.
  Future<void> prepare() async {
    await setUpDesktopWindow(kind: kind, title: t.app.title);
    _trayUp = await _tray.create();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
  }

  /// Brings the window back (the tray's show entry).
  Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// The quit flow: app shutdown first, then tray and window. Idempotent —
  /// the close button and the tray can both ask.
  Future<void> quit() async {
    if (_quitting) {
      return;
    }
    _quitting = true;
    windowManager.removeListener(this);
    await onQuitRequest();
    await _tray.dispose();
    await windowManager.destroy();
  }

  @override
  void onWindowClose() => unawaited(_handleClose());

  Future<void> _handleClose() async {
    final disposition = resolveCloseDisposition(
      platform: kind,
      action: CloseAction.quit,
      role: WindowRole.main,
      hasTray: _trayUp,
    );
    switch (disposition) {
      case CloseDisposition.hide:
        await windowManager.hide();
      case CloseDisposition.minimise:
        await windowManager.minimize();
      case CloseDisposition.destroy:
        await windowManager.destroy();
      case CloseDisposition.quit:
        await quit();
    }
  }
}
