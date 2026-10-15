import 'dart:async' show unawaited;

import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';

import 'package:pure_live/app/navigation/app_navigator_key.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/desktop/shell/close_prompt.dart';
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart';
import 'package:pure_live/platforms/desktop/tray/app_tray.dart';
import 'package:pure_live/platforms/desktop/windows/desktop_window_setup.dart';
import 'package:window_manager/window_manager.dart';

/// The desktop window's life: set up before the first frame, asked about
/// every close, gone last.
///
/// The close button never closes anything by itself. The first close asks
/// (the close prompt below) and the answer becomes the standing rule when
/// the viewer checks "remember"; an already-remembered [CloseAction] goes
/// straight to [resolveCloseDisposition], which still weighs the tray's
/// health (a hidden window nothing can bring back is a lost window) and an
/// in-flight quit.
final class DesktopEntry with WindowListener {
  /// Prepares the desktop window for [kind]; [onQuitRequest] runs the app's
  /// own shutdown (storage, log) before the window goes away. The shell
  /// preferences carry the remembered choices (title-bar mode, close action)
  /// and take the "remember" writes; the log is where the tray's refusals
  /// land.
  new({required this.kind, required this.onQuitRequest, this._preferences, this._log});

  /// The desktop platform this window lives on.
  final PlatformKind kind;

  /// Runs the app shutdown; the window is destroyed after it returns.
  final Future<void> Function() onQuitRequest;

  final ShellPreferencesStore? _preferences;
  final LiveLog? _log;

  late final AppTray _tray = AppTray(
    onShow: show,
    onQuit: () => unawaited(quit()),
    onCreateError: (error) => _log?.warning('tray icon did not appear', fields: {'error': '$error'}),
  );
  bool _trayUp = false;
  bool _quitting = false;
  bool _closePromptOpen = false;

  /// Sets the window up, creates the tray and starts intercepting closes.
  Future<void> prepare() async {
    await setUpDesktopWindow(
      kind: kind,
      title: t.app.title,
      chrome: _preferences?.value.windowChrome ?? ShellWindowChrome.app,
    );
    _trayUp = await _tray.create();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
  }

  /// Brings the window back (the tray's show entry and its left click).
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
    final remembered = _preferences?.value.closeAction;
    if (remembered != null) {
      await _applyClose(remembered);
      return;
    }
    unawaited(_askThenClose());
  }

  /// The one close per install that asks. A second close arriving while the
  /// prompt is up is ignored — two dialogs for one event is how a viewer
  /// learns to distrust the question.
  Future<void> _askThenClose() async {
    if (_closePromptOpen) {
      return;
    }
    _closePromptOpen = true;
    try {
      final context = appNavigatorKey.currentState?.context;
      if (context == null || !context.mounted) {
        // The window can close before the first frame (a fast alt+F4, a
        // shutdown). Nothing has been asked and nothing is remembered, so
        // the old default stands: quit.
        await _applyClose(CloseAction.quit);
        return;
      }
      final result = await showClosePrompt(context);
      if (result == null) {
        return; // Cancelled: the window stays.
      }
      if (result.remember) {
        await _preferences?.update((preferences) => preferences.copyWith(closeAction: result.action));
      }
      await _applyClose(result.action);
    } finally {
      _closePromptOpen = false;
    }
  }

  /// Runs the close policy for [action] and applies the disposition.
  Future<void> _applyClose(CloseAction action) async {
    final disposition = resolveCloseDisposition(
      platform: kind,
      action: action,
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
