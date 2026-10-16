import 'dart:async';

import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart';

import 'package:pure_live/l10n/generated/strings.g.dart';

/// The notification-area icon and its menu: show the window, quit.
///
/// Every icon state maps to the same asset for now — playing, recording and
/// attention get their own art when the states they name exist to show.
final class AppTray {
  /// A tray with [onShow] and [onQuit] as its two menu outcomes; [log]
  /// records the creation and every click so a dead tray is diagnosable
  /// from the log file alone; [onCreateError] receives the reason a failed
  /// creation failed, because a tray that silently did not appear stays a
  /// mystery until the close flow misbehaves.
  new({required this.onShow, required this.onQuit, this.onCreateError, LiveLog? log}) : _log = log?.forCategory('tray');

  /// Brings the window back.
  final void Function() onShow;

  /// Starts the quit flow.
  final void Function() onQuit;

  /// Reports why [create] failed; null swallows.
  final void Function(Object error)? onCreateError;

  late final TrayManagerHost _host = TrayManagerHost(
    iconAssets: {for (final state in TrayIconState.values) state: 'assets/tray/pure_live.ico'},
  );

  final LiveLog? _log;
  StreamSubscription<String>? _selections;
  StreamSubscription<TrayPointer>? _pointers;
  bool _created = false;

  /// Creates the icon and its menu; false when the platform refused (a full
  /// notification area, a missing asset) — the close policy must then keep
  /// the window visible, because nothing could bring it back.
  Future<bool> create() async {
    _created = await _host.create();
    if (!_created) {
      final error = _host.createError;
      if (error != null) {
        onCreateError?.call(error);
      }
      return false;
    }
    await _host.setTooltip('Pure Live');
    await _host.setMenu([TrayAction(id: 'show', label: t.tray.show), TrayAction(id: 'quit', label: t.tray.quit)]);
    _selections = _host.selections.listen((id) {
      _log?.info('tray menu click', fields: {'id': id});
      switch (id) {
        case 'show':
          onShow();
        case 'quit':
          onQuit();
      }
    });
    // Left click brings the window back — the same act as the menu's show
    // entry, minus the trip through the menu. Right click is the menu: the
    // shell opens it natively on the press.
    _pointers = _host.pointers.listen((pointer) {
      _log?.info('tray icon click', fields: {'kind': pointer.name});
      if (pointer == TrayPointer.click) {
        onShow();
      }
    });
    return true;
  }

  /// Removes the icon and releases the listeners.
  Future<void> dispose() async {
    await _selections?.cancel();
    await _pointers?.cancel();
    if (_created) {
      await _host.dispose();
    }
  }
}
