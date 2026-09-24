import 'dart:async';

import 'package:tray_manager/tray_manager.dart';

/// Owns the native tray objects for the lifetime of the desktop application.
/// Reusing menu items avoids accumulating native callbacks on every right-click.
class DesktopTrayService {
  static TrayIcon? _icon;
  static Image? _image;
  static Menu? _menu;
  static MenuItem? _windowItem;
  static MenuItem? _exitItem;
  static ListenerId? _iconListener;
  static ListenerId? _windowListener;
  static ListenerId? _exitListener;

  static void initialize({
    required Future<void> Function() onClick,
    required Future<void> Function() onRightClick,
    required Future<void> Function() onWindowAction,
    required Future<void> Function() onExit,
  }) {
    if (_icon != null) return;

    final icon = TrayIcon.create() ?? (throw StateError('Failed to create tray icon'));
    _icon = icon;
    try {
      final image = ImageAsset.fromAsset('assets/icons/icon.png') ??
          (throw StateError('Failed to load tray icon asset'));
      final menu = Menu.create() ?? (throw StateError('Failed to create tray menu'));
      final windowItem = MenuItem.createWithLabelAndType('', MenuItemType.normal) ??
          (throw StateError('Failed to create tray window item'));
      final exitItem = MenuItem.createWithLabelAndType('', MenuItemType.normal) ??
          (throw StateError('Failed to create tray exit item'));

      _image = image;
      _menu = menu;
      _windowItem = windowItem;
      _exitItem = exitItem;
      icon.icon = image;
      icon.setTooltip('PureLive');
      // Refresh the localized menu before showing it, rather than letting
      // nativeapi open the previous menu on button release as well.
      icon.setContextMenuTrigger(ContextMenuTrigger.none);
      _iconListener = icon.addListener((event) {
        if (event is TrayIconClickedEvent) unawaited(onClick());
        if (event is TrayIconRightClickedEvent) unawaited(onRightClick());
      });
      _windowListener = windowItem.addListener((event) {
        if (event is MenuItemClickedEvent) unawaited(onWindowAction());
      });
      _exitListener = exitItem.addListener((event) {
        if (event is MenuItemClickedEvent) unawaited(onExit());
      });
      menu.addItem(windowItem);
      menu.addSeparator();
      menu.addItem(exitItem);
      icon.setContextMenu(menu);
      if (!icon.setVisible(true)) throw StateError('Failed to show tray icon');
    } catch (_) {
      dispose();
      rethrow;
    }
  }

  static void update({
    required String tooltip,
    required String windowLabel,
    required String exitLabel,
  }) {
    final icon = _icon;
    if (icon == null) return;
    icon.setTooltip(tooltip);
    _windowItem?.label = windowLabel;
    _exitItem?.label = exitLabel;
  }

  static void openContextMenu() {
    if (!(_icon?.openContextMenu() ?? false)) {
      throw StateError('Failed to open tray context menu');
    }
  }

  static void dispose() {
    final icon = _icon;
    final windowItem = _windowItem;
    final exitItem = _exitItem;
    if (icon != null && _iconListener != null) icon.removeListener(_iconListener!);
    if (windowItem != null && _windowListener != null) windowItem.removeListener(_windowListener!);
    if (exitItem != null && _exitListener != null) exitItem.removeListener(_exitListener!);
    icon?.setContextMenu(null);
    icon?.setVisible(false);
    icon?.dispose();
    _menu?.dispose();
    windowItem?.dispose();
    exitItem?.dispose();
    _image?.dispose();
    _icon = null;
    _image = null;
    _menu = null;
    _windowItem = null;
    _exitItem = null;
    _iconListener = null;
    _windowListener = null;
    _exitListener = null;
  }
}
