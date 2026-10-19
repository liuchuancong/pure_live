import 'dart:async' show unawaited;
import 'dart:ui' show Size;

import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart' show DesktopNotificationCenter;

import 'package:pure_live/app/engine/window_surface_hooks.dart';
import 'package:pure_live/app/navigation/app_navigator_key.dart';
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/providers/app_providers.dart' show DesktopTrayPort;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/desktop/shell/close_prompt.dart';
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart';
import 'package:pure_live/platforms/desktop/tray/app_tray.dart';
import 'package:pure_live/platforms/desktop/windows/desktop_window_setup.dart';
import 'package:window_frame_kit/window_frame_kit.dart';

/// The desktop window's life: set up before the first frame, asked about
/// every close, gone last.
///
/// The close button never closes anything by itself. The first close asks
/// (the close prompt below) and the answer becomes the standing rule when
/// the viewer checks "remember"; an already-remembered [CloseAction] goes
/// straight to [resolveCloseDisposition], which still weighs the tray's
/// health (a hidden window nothing can bring back is a lost window) and an
/// in-flight quit.
final class DesktopEntry with WindowListener implements DesktopTrayPort {
  /// Prepares the desktop window for [kind]; [onQuitRequest] runs the app's
  /// own shutdown (storage, log) before the window goes away. The shell
  /// preferences carry the remembered choices (title-bar mode, close action)
  /// and take the "remember" writes; the app preferences carry the stored
  /// window size this start opens at; the log is where the tray's refusals
  /// land.
  new({
    required this.kind,
    required this.onQuitRequest,
    this._preferences,
    this._appPreferences,
    this._log,
    this._launchArguments = const <String>[],
  });

  /// The desktop platform this window lives on.
  final PlatformKind kind;

  /// Runs the app shutdown; the window is destroyed after it returns.
  final Future<void> Function() onQuitRequest;

  /// The title-bar mode this process actually runs in, decided once in
  /// [prepare] and read from then on.
  ///
  /// It is the *resolved* answer — launch argument, then the stored choice, then
  /// the operating system's default — and NOT the stored preference, because a
  /// change made mid-run is the next window's mode while this one keeps what it
  /// was dressed in. Reading the preference instead is how a window ends up with
  /// a system caption and an app-drawn strip over it, or the reverse and no
  /// caption at all; `main.dart` overrides `windowChromeProvider` with this value
  /// so the widgets and the frame can never disagree.
  late final ShellWindowChrome windowChrome;

  final ShellPreferencesStore? _preferences;
  final AppPreferencesStore? _appPreferences;
  final LiveLog? _log;

  /// This process's command line, read only for the frame mode's development pin
  /// (`--native-frame` / `--custom-frame`).
  final List<String> _launchArguments;

  late final AppTray _tray = AppTray(
    onShow: show,
    onHide: _hide,
    onQuit: () => unawaited(quit()),
    windowVisible: windowManager.isVisible,
    onCreateError: (error) => _log?.warning('tray icon did not appear', fields: {'error': '$error'}),
  );
  final DesktopNotificationCenter _notifications = DesktopNotificationCenter();
  bool _trayUp = false;
  bool _quitting = false;
  bool _closePromptOpen = false;

  /// Sets the window up, creates the tray and starts intercepting closes.
  Future<void> prepare() async {
    final preferences = _appPreferences?.value;
    // Resolved before the window is set up and never re-read: this is the mode
    // the frame is about to get, and everything that draws under it — the strip,
    // the content inset — has to believe the same thing. The stored preference may
    // already name the mode for the *next* start, so it is an input, not the answer.
    windowChrome = resolveWindowChrome(kind: kind, args: _launchArguments, stored: _preferences?.value.windowChrome);
    await setUpDesktopWindow(
      kind: kind,
      title: t.app.title,
      chrome: windowChrome,
      // A launch-pinned solid surface, for telling a material artefact from a
      // frame one; absent, the material is asked for wherever it exists.
      opaqueSurface: launchPinsOpaqueSurface(_launchArguments),
      // The stored window size (general settings); 0 keeps the launch
      // default.
      initialSize: preferences == null || preferences.windowWidth <= 0 || preferences.windowHeight <= 0
          ? null
          : Size(preferences.windowWidth.toDouble(), preferences.windowHeight.toDouble()),
    );
    _trayUp = await _tray.create();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
  }

  /// Brings the window back (the tray's show entry and its left click).
  Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
    await _tray.setWindowVisible(visible: true);
  }

  /// Takes the window away without quitting — the tray's own hide row. The
  /// close-to-hide disposition goes through [_applyClose] and reports here
  /// too, so the menu's next word is always the truth.
  Future<void> _hide() async {
    await windowManager.hide();
    await _tray.setWindowVisible(visible: false);
  }

  @override
  void reportRecordingCount(int count) => unawaited(_tray.setRecordingCount(count));

  @override
  Future<void> notifyTray({required String title, String body = ''}) async {
    // Best effort by contract: a platform with no notification surface, or
    // one that refuses the call, drops the notice — recording results are
    // facts on disk before they are toasts.
    _notifications.show(title: title, body: body);
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
    // 关闭小窗即暂停: the tile's room hands the stream back — window restored,
    // playback paused — before the window goes anywhere, so a closed tile is
    // a stopped tile.
    if (_appPreferences?.value.pauseOnPipClose ?? false) {
      final hook = WindowSurfaceHooks.onTileWindowClose;
      if (hook != null) {
        await hook();
      }
    }
    final disposition = resolveCloseDisposition(
      platform: kind,
      action: action,
      role: WindowRole.main,
      hasTray: _trayUp,
    );
    switch (disposition) {
      case CloseDisposition.hide:
        await _hide();
      case CloseDisposition.minimise:
        await windowManager.minimize();
      case CloseDisposition.destroy:
        await windowManager.destroy();
      case CloseDisposition.quit:
        await quit();
    }
  }
}
