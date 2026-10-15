import 'dart:async';

import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart';

import 'package:pure_live/l10n/generated/strings.g.dart';

/// The notification-area icon and its menu: show the window, quit.
///
/// Every icon state maps to the same asset for now — playing, recording and
/// attention get their own art when the states they name exist to show.
final class AppTray {
  /// A tray with [onShow] and [onQuit] as its two menu outcomes.
  new({required this.onShow, required this.onQuit});

  /// Brings the window back.
  final void Function() onShow;

  /// Starts the quit flow.
  final void Function() onQuit;

  late final TrayManagerHost _host = TrayManagerHost(
    iconAssets: {for (final state in TrayIconState.values) state: 'assets/tray/pure_live.ico'},
  );

  StreamSubscription<String>? _selections;
  bool _created = false;

  /// Creates the icon and its menu; false when the platform refused (a full
  /// notification area, a missing asset) — the close policy must then keep
  /// the window visible, because nothing could bring it back.
  Future<bool> create() async {
    _created = await _host.create();
    if (!_created) {
      return false;
    }
    await _host.setTooltip('Pure Live');
    await _host.setMenu([TrayAction(id: 'show', label: t.tray.show), TrayAction(id: 'quit', label: t.tray.quit)]);
    _selections = _host.selections.listen((id) {
      switch (id) {
        case 'show':
          onShow();
        case 'quit':
          onQuit();
      }
    });
    return true;
  }

  /// Removes the icon and releases the listener.
  Future<void> dispose() async {
    await _selections?.cancel();
    if (_created) {
      await _host.dispose();
    }
  }
}
