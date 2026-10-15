// This whole file speaks the plugin's declared bridge API: `legacy.dart` is what
// `tray_manager` 0.8 ships for Flutter apps, and the class note below explains
// why it is chosen over the raw native API and what to port when it goes.
// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:live_shell/live_shell.dart';
import 'package:tray_manager/legacy.dart';

/// The tray icon, driven through `tray_manager`.
///
/// Why the legacy facade: `tray_manager` 0.8 moved onto `package:nativeapi` and
/// re-exported its raw FFI types (`TrayIcon`, `Menu`, `MenuItem`, `ListenerId`)
/// from the main library, leaving the previous facade in `legacy.dart` as an
/// explicit bridge. Two things only the bridge does for us: it loads an icon
/// from the Flutter asset bundle, and it accepts a declarative menu with a click
/// callback per item instead of asking the caller to allocate native menu items,
/// track their listener ids and dispose each one by hand. This is one file, so
/// the port is contained when the bridge goes away.
///
/// One thing the bridge costs, recorded here rather than discovered later: the
/// native API's `TrayIcon.createWithIdentifier` is how a macOS status item gets
/// its `autosaveName`, which is what makes the viewer's chosen position in the
/// menu bar survive restarts. The legacy path has no equivalent, so on macOS the
/// icon comes back wherever the system put it. Fixing that means moving this
/// file to `TrayIcon` — and keeping the identifier stable once chosen, because
/// changing it is what resets the position.
final class TrayManagerHost with TrayListener implements TrayHost {
  /// A host that reads its icon assets from [iconAssets], keyed by state.
  new({required this.iconAssets, TrayManager? manager}) : _manager = manager ?? TrayManager.instance;

  /// The asset path for each state the icon can show.
  ///
  /// Two per state where the state is meant to be readable at a glance:
  /// `recording` needs to look different from `idle` in a 16-pixel square, which
  /// a monochrome template image cannot deliver.
  final Map<TrayIconState, String> iconAssets;

  final TrayManager _manager;

  final StreamController<String> _selections = StreamController<String>.broadcast();
  final StreamController<TrayPointer> _pointers = StreamController<TrayPointer>.broadcast();

  List<TrayEntry> _shown = const [];
  bool _created = false;
  Object? _createError;

  @override
  bool get isCreated => _created;

  @override
  Stream<String> get selections => _selections.stream;

  @override
  Stream<TrayPointer> get pointers => _pointers.stream;

  /// Why the last failed [create] failed, null when it succeeded or was never
  /// attempted.
  ///
  /// `create` reports the outcome as a bool because that is what the close
  /// policy consumes; the reason is diagnostics, and swallowing it is how a
  /// missing icon stays a mystery for weeks. A missing asset, a notification
  /// area that is full, a session with no status notifier at all — the caller
  /// decides which of these is worth a log line.
  Object? get createError => _createError;

  @override
  Future<bool> create({TrayIconState state = TrayIconState.idle}) async {
    if (_created) {
      return true;
    }
    try {
      await _manager.setIcon(iconAssets[state] ?? iconAssets.values.first);
    } on Object catch (error) {
      // Reported as false, and the close policy does the rest: it must not
      // hide a window that nothing can bring back. The cause is kept where a
      // caller that logs can reach it instead of dying in this catch.
      _createError = error;
      return false;
    }
    _createError = null;
    _manager.addListener(this);
    _created = true;
    return true;
  }

  @override
  Future<void> dispose() async {
    _manager.removeListener(this);
    _created = false;
    await _manager.destroy();
    await _selections.close();
    await _pointers.close();
  }

  @override
  Future<void> setIcon(TrayIconState state) async {
    final asset = iconAssets[state];
    if (asset == null) {
      return;
    }
    await _manager.setIcon(asset);
  }

  @override
  Future<void> setTooltip(String text) => _manager.setToolTip(text);

  @override
  Future<void> setMenu(List<TrayEntry> entries) async {
    // Rebuilding is destructive: the open menu closes under whoever is pointing
    // at it. An unchanged menu is therefore not an update at all.
    if (!trayMenuNeedsRebuild(_shown, entries)) {
      return;
    }
    await _manager.setContextMenu(Menu(items: _toItems(entries)));
    _shown = entries;
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key;
    if (key != null && !_selections.isClosed) {
      _selections.add(key);
    }
  }

  @override
  void onTrayIconMouseDown() {
    if (!_pointers.isClosed) {
      _pointers.add(TrayPointer.click);
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    if (!_pointers.isClosed) {
      _pointers.add(TrayPointer.rightClick);
    }
  }

  // The bridge reports a double click as two presses and never as its own
  // event, so `TrayPointer.doubleClick` is not produced here. Anything bound to
  // it must not be relied on through this host: bring-the-window-back is bound to
  // `click` precisely because that is what the shells deliver consistently. The
  // native API does expose `TrayIconDoubleClickedEvent`, which is one of the
  // reasons to port this file when the bridge is removed.

  MenuItem _toItem(TrayEntry entry) {
    if (entry is TrayDivider) {
      return MenuItem.separator();
    }
    if (entry is TraySubmenu) {
      return MenuItem.submenu(
        key: entry.id,
        label: entry.label,
        submenu: Menu(items: _toItems(entry.children)),
      );
    }
    final action = entry is TrayAction ? entry : null;
    final label =
        action?.badge ==
            null //
        ? entry.label
        : truncateTrayLabel(entry.label, keepSuffix: action!.badge);
    return MenuItem(
      key: entry.id,
      label: label,
      // A heading is information, not a target: greying it out is the only way
      // a native menu says "read this, do not click it".
      disabled: action == null || !entry.enabled,
      checked: action?.checked,
    );
  }

  List<MenuItem> _toItems(List<TrayEntry> entries) => [for (final entry in entries) _toItem(entry)];
}
