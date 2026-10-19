import 'dart:async';

import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart';

import 'package:pure_live/l10n/generated/strings.g.dart';

/// The rows of the tray menu (the reference's A16.1 T4): while rooms record,
/// the greyed "正在录制 N 个直播间" and a line first; then the window's own
/// row (hide or show, whichever the window needs), a line and quit.
enum TrayRow {
  /// "正在录制 N 个直播间", a heading, not a target.
  recording,

  /// A line.
  separator,

  /// "隐藏主界面" or "显示主界面", by the window's state at the last fill.
  window,

  /// "退出".
  quit,
}

/// The rows for [recording] rooms.
List<TrayRow> trayMenuRows({required int recording}) => [
  if (recording > 0) ...[TrayRow.recording, TrayRow.separator],
  TrayRow.window,
  TrayRow.separator,
  TrayRow.quit,
];

/// The words of [row]: [visible] is the window's state at the fill, the
/// reference's own two inputs.
List<String> trayRowLabels(TrayRow row, {required bool visible, required int recording}) => switch (row) {
  TrayRow.recording => [t.tray.recordingCount(count: recording)],
  TrayRow.separator => const [''],
  TrayRow.window => [if (visible) t.tray.hide else t.tray.show],
  TrayRow.quit => [t.tray.quit],
};

/// The icon's hint: the app's name, and how many rooms record (T4).
String trayTooltip({required int recording}) =>
    recording > 0 ? t.tray.tooltipRecording(count: recording) : 'Pure Live';

/// The notification-area icon and its menu: the window's hide/show toggle,
/// quit, and the recording count in both the menu and the hint.
///
/// The menu is rebuilt whenever the state it shows changes — a recording
/// starts or ends, the window is shown or hidden — and again best-effort on
/// a right click, because the legacy bridge opens the native menu on the
/// press itself and a late rebuild lands on the next opening. Every icon
/// state maps to the same asset for now — playing and attention get their
/// own art when the states they name exist to show.
final class AppTray {
  /// A tray that shows and hides the window through [onShow] and [onHide],
  /// starts the quit flow through [onQuit], reads the window's state through
  /// [windowVisible] at every fill, and records the creation and every click
  /// through [log] so a dead tray is diagnosable from the log file alone;
  /// [onCreateError] receives the reason a failed creation failed, because a
  /// tray that silently did not appear stays a mystery until the close flow
  /// misbehaves.
  new({
    required this.onShow,
    required this.onHide,
    required this.onQuit,
    required this.windowVisible,
    this.onCreateError,
    LiveLog? log,
  }) : _log = log?.forCategory('tray');

  /// Brings the window back.
  final void Function() onShow;

  /// Takes the window away (the menu's hide row — the tray icon is what
  /// brings it back).
  final void Function() onHide;

  /// Starts the quit flow.
  final void Function() onQuit;

  /// Whether the window is on screen (minimised counts: the reference asks
  /// `isVisible`, and a hidden window answers differently from a shrunken
  /// one).
  final Future<bool> Function() windowVisible;

  /// Reports why [create] failed; null swallows.
  final void Function(Object error)? onCreateError;

  late final TrayManagerHost _host = TrayManagerHost(
    iconAssets: {for (final state in TrayIconState.values) state: 'assets/tray/pure_live.ico'},
  );

  final LiveLog? _log;
  StreamSubscription<String>? _selections;
  StreamSubscription<TrayPointer>? _pointers;
  bool _created = false;
  int _recording = 0;
  bool _lastVisible = true;

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
    await _refresh();
    _selections = _host.selections.listen((id) async {
      _log?.info('tray menu click', fields: {'id': id});
      switch (id) {
        case 'window':
          // The row says what it will do: show when the window is away,
          // hide when it is up. The state may have moved since the fill —
          // act on the fresh answer, not on the label.
          if (await windowVisible()) {
            onHide();
          } else {
            onShow();
          }
        case 'quit':
          onQuit();
      }
    });
    // Left click brings the window back — the same act as the menu's show
    // entry, minus the trip through the menu. Right click is the menu: the
    // shell opens it natively on the press, and the listener's rebuild is
    // what keeps its words honest for the next opening.
    _pointers = _host.pointers.listen((pointer) {
      _log?.info('tray icon click', fields: {'kind': pointer.name});
      switch (pointer) {
        case TrayPointer.click:
          onShow();
        case TrayPointer.rightClick:
          unawaited(_refresh());
        case TrayPointer.doubleClick:
          break;
      }
    });
    return true;
  }

  /// How many rooms record: the hint says so at once, the menu when it is
  /// next filled (the reference's T4 rule).
  Future<void> setRecordingCount(int count) async {
    if (count == _recording) return;
    _recording = count;
    // The state switch is honest even while every state shares one asset:
    // the day the recording art exists, this is the line that starts using
    // it.
    await _host.setIcon(_recording > 0 ? TrayIconState.recording : TrayIconState.idle);
    await _refresh();
  }

  /// The window's state moved (shown, hidden): refill the words that speak
  /// it. The entry calls this from its own transitions, so the menu is
  /// honest without waiting for a right click.
  Future<void> setWindowVisible({required bool visible}) async {
    if (visible == _lastVisible) return;
    _lastVisible = visible;
    await _refresh();
  }

  /// Re-reads the window and rebuilds the menu and the hint (also how a
  /// language change reaches the native objects: the words are re-asked).
  Future<void> relabel() => _refresh();

  Future<void> _refresh() async {
    if (!_created) return;
    final visible = await windowVisible();
    _lastVisible = visible;
    await _host.setTooltip(trayTooltip(recording: _recording));
    await _host.setMenu([
      for (final row in trayMenuRows(recording: _recording))
        switch (row) {
          TrayRow.recording => TrayAction(id: 'recording', label: trayRowLabels(row, visible: visible, recording: _recording).first, enabled: false),
          TrayRow.separator => const TrayDivider(),
          TrayRow.window => TrayAction(id: 'window', label: trayRowLabels(row, visible: visible, recording: _recording).first),
          TrayRow.quit => TrayAction(id: 'quit', label: trayRowLabels(row, visible: visible, recording: _recording).first),
        },
    ]);
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
