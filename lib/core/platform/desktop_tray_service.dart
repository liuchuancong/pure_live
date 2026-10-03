import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  static bool _handleRecorded = false;

  /// Hot restart replaces the Dart isolate without running its finalizers, so
  /// the previous isolate's native tray icon stays registered with the shell
  /// for as long as the runner process lives. This per-process file carries the
  /// native handle across the restart so the new isolate can release the
  /// orphan before creating its own icon.
  static File get _handleHandshake =>
      File('${Directory.systemTemp.path}/pure_live_tray_$pid.handle');

  static void initialize({
    required Future<void> Function() onClick,
    required Future<void> Function() onRightClick,
    required Future<void> Function() onWindowAction,
    required Future<void> Function() onExit,
  }) {
    if (_icon != null) return;

    _releaseOrphanedIcon();

    final icon = TrayIcon.create() ?? (throw StateError('Failed to create tray icon'));
    _icon = icon;
    _recordHandle(icon);
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

  static void _releaseOrphanedIcon() {
    if (kReleaseMode) return;
    try {
      final handshake = _handleHandshake;
      if (!handshake.existsSync()) return;
      final handle = int.tryParse(handshake.readAsStringSync().trim());
      // Releasing an unknown or already-released handle is a native no-op, so a
      // file left by an earlier process run is harmless here.
      if (handle != null && handle != 0) TrayIcon.borrowed(handle).dispose();
    } catch (e) {
      debugPrint('托盘残留图标清理失败: $e');
    }
  }

  static void _recordHandle(TrayIcon icon) {
    if (kReleaseMode) return;
    try {
      _handleHandshake.writeAsStringSync('${icon.nativeHandle}');
      _handleRecorded = true;
    } catch (e) {
      debugPrint('托盘句柄握手写入失败: $e');
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
    if (_handleRecorded) {
      _handleRecorded = false;
      try {
        _handleHandshake.deleteSync();
      } catch (e) {
        debugPrint('托盘句柄握手清理失败: $e');
      }
    }
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
