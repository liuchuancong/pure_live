import 'dart:async' show StreamController;

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:flutter/services.dart' show MethodChannel, MissingPluginException;
import 'package:live_shell/live_shell.dart' show WindowEvent, WindowGeometry, WindowHost, WindowRole, WindowState;

/// The runner's channel for a clone's own window.
///
/// Window plugins cannot address a sub-engine's window reliably, so the
/// verbs a clone needs are served by the runner on the thread that created
/// the window.
final class CloneWindowChannel {
  /// A channel registered by the runner's window-created hook.
  new();

  static const MethodChannel _channel = MethodChannel('pure_live/room_window');

  /// The runner's top-level native window handle, where the platform has one
  /// (Windows). The presentation drivers pin this handle: their process-wide
  /// lookup finds the primary window, not this clone's.
  Future<int?> hwnd() async {
    final value = await _call('hwnd');
    return value is num ? value.toInt() : null;
  }

  /// Closes this window without ending the process.
  Future<void> close() => _call('close');

  /// Sets the native caption/taskbar text.
  Future<void> setTitle(String title) => _call('title', title);

  /// Shows or hides the native caption and resize frame.
  Future<void> setChrome({required bool custom}) => _call('chrome', custom);

  /// Starts an OS move loop from the app's own drag band.
  Future<void> startDragging() => _call('startDragging');

  /// Minimises the window.
  Future<void> minimize() => _call('minimize');

  /// Maximises the window.
  Future<void> maximize() => _call('maximize');

  /// Restores the window.
  Future<void> restore() => _call('restore');

  /// Whether the window is maximised.
  Future<bool> isMaximized() async => await _call('isMaximized') == true;

  Future<Object?> _call(String method, [Object? arguments]) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _channel.invokeMethod<Object>(method, arguments);
      } on MissingPluginException {
        if (attempt >= 5) {
          debugPrint('[clone] $method: runner channel missing');
          return null;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      } on Object catch (error) {
        debugPrint('[clone] $method failed: $error');
        return null;
      }
    }
  }
}

/// A clone window's host for the self-drawn chrome.
///
/// The native runner owns the frame; this host translates the layout's
/// window verbs into it and emits the events the title bar reads.
final class CloneWindowHost implements WindowHost {
  /// A host for [role].
  CloneWindowHost({required this.role}) : _channel = CloneWindowChannel();

  final CloneWindowChannel _channel;
  final StreamController<WindowEvent> _events = StreamController<WindowEvent>.broadcast();
  bool _alive = true;

  @override
  final WindowRole role;

  @override
  bool get isAlive => _alive;

  @override
  Stream<WindowEvent> get events => _events.stream;

  @override
  Future<void> show({bool inactive = false}) async {
    // The runner shows a sub-window at creation; raising it is native.
  }

  @override
  Future<void> hide() async {}

  @override
  Future<void> minimize() async {
    await _channel.minimize();
    _events.add(WindowEvent.minimised);
  }

  @override
  Future<void> restore() async {
    await _channel.restore();
    _events.add(WindowEvent.restored);
  }

  @override
  Future<bool> toggleMaximize() async {
    final maximized = await isMaximized();
    if (maximized) {
      await _channel.restore();
      _events.add(WindowEvent.restored);
      return false;
    }
    await _channel.maximize();
    _events.add(WindowEvent.maximised);
    return true;
  }

  @override
  Future<bool> isMaximized() => _channel.isMaximized();

  @override
  Future<void> setPreventClose({required bool enabled}) async {}

  @override
  Future<void> close() async {
    _alive = false;
    _events.add(WindowEvent.closed);
    await _channel.close();
  }

  @override
  Future<void> destroy() => close();

  @override
  Future<WindowGeometry> geometry() async {
    // The clone's window-size row is hidden: its frame belongs to the
    // native caption the runner created, not to a persisted main setting.
    throw UnsupportedError('clone geometry is owned by the runner');
  }

  @override
  Future<void> setGeometry(WindowGeometry geometry) async {}

  @override
  Future<void> center() async {}

  @override
  Future<void> setAlwaysOnTop({required bool value}) async {}

  @override
  Future<void> setResizable({required bool value}) async {}

  @override
  Future<void> setTitle(String value) => _channel.setTitle(value);

  @override
  Future<void> startDragging() => _channel.startDragging();

  @override
  Future<WindowState> snapshot() async {
    throw UnsupportedError('clone state is owned by the runner');
  }
}
