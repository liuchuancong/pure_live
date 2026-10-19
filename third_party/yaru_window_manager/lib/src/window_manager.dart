import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_frame_kit/window_frame_kit.dart';
import 'package:yaru_window_platform_interface/yaru_window_platform_interface.dart';

class YaruWindowManager extends YaruWindowPlatform {
  YaruWindowManager([@visibleForTesting this.__wm]);

  static void registerWith() {
    YaruWindowPlatform.instance = YaruWindowManager();
  }

  _YaruWindowStatesListener? __statesListener;
  _YaruWindowStatesListener get _listener =>
      __statesListener ??= _YaruWindowStatesListener(_wm);

  _YaruWindowOnCloseListener? __closeListener;
  _YaruWindowOnCloseListener get _closeListener =>
      __closeListener ??= _YaruWindowOnCloseListener(_wm);

  WindowManager? __wm;
  WindowManager get _wm => __wm ??= WindowManager.instance;

  @override
  Future<void> init(int id) => _wm.invokeMethod(_wm.ensureInitialized);

  @override
  Future<void> close(int id) => _wm.invokeMethod(_wm.close);
  @override
  Future<void> drag(int id) => _wm.invokeMethod(_wm.startDragging);
  @override
  Future<void> fullscreen(int id) => _wm.invokeSetter(_wm.setFullScreen, true);
  @override
  Future<void> hide(int id) => _wm.invokeMethod(_wm.hide);
  @override
  Future<void> hideTitle(int id) =>
      _wm.invokeSetter(_wm.setTitleBarStyle, TitleBarStyle.hidden);
  @override
  Future<void> maximize(int id) => _wm.invokeMethod(_wm.maximize);
  @override
  Future<void> minimize(int id) => _wm.invokeMethod(_wm.minimize);
  @override
  Future<void> restore(int id) async {
    if (await _wm.invokeGetter(_wm.isFullScreen, orElse: false)) {
      return _wm.invokeSetter(_wm.setFullScreen, false);
    } else if (await _wm.invokeGetter(_wm.isMaximized, orElse: false)) {
      return _wm.invokeMethod(_wm.unmaximize);
    } else if (await _wm.invokeGetter(_wm.isMinimized, orElse: false)) {
      return _wm.invokeMethod(_wm.restore);
    }
  }

  @override
  Future<void> show(int id) => _wm.invokeMethod(_wm.show);
  @override
  Future<void> showMenu(int id) => _wm.invokeMethod(_wm.popUpWindowMenu);
  @override
  Future<void> showTitle(int id) =>
      _wm.invokeSetter(_wm.setTitleBarStyle, TitleBarStyle.normal);

  @override
  Future<void> setBackground(int id, Color color) =>
      _wm.invokeSetter(_wm.setBackgroundColor, color);
  @override
  Future<void> setBrightness(int id, Brightness brightness) =>
      _wm.invokeSetter(_wm.setBrightness, brightness);
  @override
  Future<void> setTitle(int id, String title) => _wm
      .invokeSetter(_wm.setTitle, title)
      .then((_) => _listener._updateState());

  @override
  Future<void> setMinimizable(int id, bool minimizable) => _wm
      .invokeSetter(_wm.setMinimizable, minimizable)
      .then((_) => _listener._updateState());

  @override
  Future<void> setMaximizable(int id, bool maximizable) => _wm
      .invokeSetter(_wm.setMaximizable, maximizable)
      .then((_) => _listener._updateState());

  @override
  Future<void> setClosable(int id, bool closable) => _wm
      .invokeSetter(_wm.setClosable, closable)
      .then((_) => _listener._updateState());

  @override
  Future<YaruWindowState> state(int id) => _wm.state();
  @override
  Stream<YaruWindowState> states(int id) => _listener.states();

  @override
  Future<void> onClose(int id, FutureOr<bool> Function() handler) {
    return _closeListener.addCloseHandler(handler);
  }
}

extension _YaruWindowManagerX on WindowManager {
  Future<T> invokeGetter<T>(
    Future<T> Function() getter, {
    required T orElse,
  }) async {
    try {
      return await getter();
    } on MissingPluginException catch (_) {
      return orElse;
    }
  }

  Future<void> invokeSetter<T>(
    Future<void> Function(T value) setter,
    T value,
  ) async {
    try {
      return await setter(value);
    } on MissingPluginException catch (_) {}
  }

  Future<void> invokeMethod(Future<void> Function() method) async {
    try {
      return await method();
    } on MissingPluginException catch (_) {}
  }

  Future<YaruWindowState> state() {
    return Future.wait([
      invokeGetter(isFocused, orElse: true),
      invokeGetter(isClosable, orElse: true),
      invokeGetter(isFullScreen, orElse: false),
      invokeGetter(isMaximizable, orElse: true),
      invokeGetter(isMaximized, orElse: false),
      invokeGetter(isMinimizable, orElse: true),
      invokeGetter(isMinimized, orElse: false),
      invokeGetter(isMovable, orElse: true),
      invokeGetter(getTitle, orElse: ''),
      invokeGetter(isVisible, orElse: true),
    ]).then((values) {
      final active = values[0] as bool;
      final closable = values[1] as bool;
      final fullscreen = values[2] as bool;
      final maximizable = values[3] as bool;
      final maximized = values[4] as bool;
      final minimizable = values[5] as bool;
      final minimized = values[6] as bool;
      final movable = values[7] as bool;
      final title = values[8] as String;
      final visible = values[9] as bool;
      return YaruWindowState(
        isActive: active,
        isClosable: closable,
        isFullscreen: fullscreen,
        isMaximizable: maximizable && !maximized,
        isMaximized: maximized,
        isMinimizable: minimizable && !minimized,
        isMinimized: minimized,
        isMovable: movable && !kIsWeb,
        isRestorable: fullscreen || maximized || minimized,
        title: title,
        isVisible: visible,
      );
    });
  }
}

class _YaruWindowStatesListener extends WindowListener {
  _YaruWindowStatesListener(this._wm);

  final WindowManager _wm;
  StreamController<YaruWindowState>? _controller;

  Stream<YaruWindowState> states() async* {
    _controller ??= StreamController<YaruWindowState>.broadcast(
      onListen: () => _wm.addListener(this),
      onCancel: () => _wm.removeListener(this),
    );
    yield* _controller!.stream;
  }

  Future<void> close() async => await _controller?.close();

  Future<void> _updateState() async {
    _controller?.add(await _wm.state());
  }

  @override
  void onWindowBlur() => _updateState();
  @override
  void onWindowFocus() => _updateState();
  @override
  void onWindowEnterFullScreen() => _updateState();
  @override
  void onWindowLeaveFullScreen() => _updateState();
  @override
  void onWindowMaximize() => _updateState();
  @override
  void onWindowUnmaximize() => _updateState();
  @override
  void onWindowMinimize() => _updateState();
  @override
  void onWindowRestore() => _updateState();
}

class _YaruWindowOnCloseListener extends WindowListener {
  _YaruWindowOnCloseListener(this._wm) {
    _wm.addListener(this);
  }

  final WindowManager _wm;

  @override
  void onWindowClose() => _handleClose();

  final _onCloseHandlers = <FutureOr<bool> Function()>[];

  Future<void> addCloseHandler(FutureOr<bool> Function() handler) {
    _onCloseHandlers.add(handler);
    return _wm.setPreventClose(true);
  }

  Future<void> _handleClose() async {
    for (final handler in _onCloseHandlers) {
      if (!await handler()) {
        return;
      }
    }
    await _wm.setPreventClose(false);
    await _wm.close();
  }
}
