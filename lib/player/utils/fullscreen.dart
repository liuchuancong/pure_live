import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/utils/window_helper.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

@visibleForTesting
bool supportsOrientationLockForLogicalDisplay(Size logicalDisplaySize) {
  return logicalDisplaySize.shortestSide < 600;
}

@visibleForTesting
Future<void> enterDesktopFullscreen({
  required bool isWindows,
  required Future<void> Function() prepareWindowsFullscreen,
  required Future<void> Function(bool fullscreen) setFullScreen,
}) async {
  // window_manager 0.5.2 marks a hidden-title-bar window as frameless while
  // initializing it on Windows. Its native SetFullScreen implementation skips
  // every style and bounds update while that flag is set, although it still
  // reports fullscreen=true. Reapplying the same title-bar style clears the
  // stale native guard before the actual transition.
  if (isWindows) {
    await prepareWindowsFullscreen();
  }
  await setFullScreen(true);
}

@immutable
class WindowPresentationSnapshot {
  const WindowPresentationSnapshot({required this.fullscreen, required this.widescreen});

  factory WindowPresentationSnapshot.capture(GlobalPlayerState state) {
    return WindowPresentationSnapshot(fullscreen: state.isFullscreen.value, widescreen: state.isWindowFullscreen.value);
  }

  final bool fullscreen;
  final bool widescreen;
}

typedef WindowPresentationCapture = WindowPresentationSnapshot Function();
typedef WindowPresentationPrepare = Future<void> Function();
typedef WindowPresentationRestore = Future<void> Function(WindowPresentationSnapshot snapshot);

class WindowsPipExitFailure implements Exception {
  const WindowsPipExitFailure({required this.cause, required this.causeStackTrace, required this.hostIsInPip});

  final Object cause;
  final StackTrace causeStackTrace;
  final bool hostIsInPip;

  @override
  String toString() => 'WindowsPipExitFailure(hostIsInPip: $hostIsInPip, cause: $cause)';
}

WindowPresentationSnapshot _captureWindowsPipPresentation() {
  return WindowPresentationSnapshot.capture(GlobalPlayerState.to);
}

Future<void> _prepareWindowsPipPresentation() async {
  final state = GlobalPlayerState.to;
  if (state.isFullscreen.value && Get.isRegistered<LivePlayController>()) {
    final livePlayController = Get.find<LivePlayController>();
    final videoController = livePlayController.state.value.player.videoController;
    await videoController?.toggleFullScreen();
  }
}

Future<void> _restoreWindowsPipPresentation(WindowPresentationSnapshot presentation) async {
  final state = GlobalPlayerState.to;
  // PlayerManager publishes isPipMode only after this whole host and
  // presentation transaction succeeds (or reports a committed host exit).

  if (!Get.isRegistered<LivePlayController>()) {
    state.isFullscreen.value = presentation.fullscreen;
    state.isWindowFullscreen.value = !presentation.fullscreen && presentation.widescreen;
    return;
  }

  final livePlayController = Get.find<LivePlayController>();
  if (presentation.fullscreen) {
    state.isWindowFullscreen.value = false;
    final videoController = livePlayController.state.value.player.videoController;
    if (videoController != null && !state.isFullscreen.value) {
      await videoController.toggleFullScreen();
    } else {
      livePlayController.setFullScreen();
      state.isFullscreen.value = true;
    }
    return;
  }

  state.isFullscreen.value = false;
  if (presentation.widescreen) {
    livePlayController.setWidescreen();
    state.isWindowFullscreen.value = true;
  } else {
    livePlayController.setNormalScreen();
    state.isWindowFullscreen.value = false;
  }
}

class WindowService {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal()
    : this._withDependencies(
        Platform.isWindows,
        WindowHelper.instance.enterPiP,
        WindowHelper.instance.exitPiP,
        _captureWindowsPipPresentation,
        _prepareWindowsPipPresentation,
        _restoreWindowsPipPresentation,
      );

  @visibleForTesting
  factory WindowService.test({
    bool isWindows = true,
    required Future<void> Function(double videoRatio) enterHostPip,
    required Future<void> Function() exitHostPip,
    required WindowPresentationCapture capturePresentation,
    required WindowPresentationPrepare preparePresentation,
    required WindowPresentationRestore restorePresentation,
  }) {
    return WindowService._withDependencies(
      isWindows,
      enterHostPip,
      exitHostPip,
      capturePresentation,
      preparePresentation,
      restorePresentation,
    );
  }

  WindowService._withDependencies(
    this._isWindows,
    this._enterHostPip,
    this._exitHostPip,
    this._capturePresentation,
    this._preparePresentation,
    this._restorePresentation,
  );

  final bool _isWindows;
  final Future<void> Function(double videoRatio) _enterHostPip;
  final Future<void> Function() _exitHostPip;
  final WindowPresentationCapture _capturePresentation;
  final WindowPresentationPrepare _preparePresentation;
  final WindowPresentationRestore _restorePresentation;

  WindowPresentationSnapshot? _presentationBeforePip;
  Future<void>? _windowsPipTransition;
  bool _windowsPipActive = false;
  double _windowsPipVideoRatio = 16 / 9;

  bool _canApplyMobileOrientationLock() {
    if (!Platform.isAndroid) return true;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return true;
    final display = views.first.display;
    final logicalSize = Size(
      display.size.width / display.devicePixelRatio,
      display.size.height / display.devicePixelRatio,
    );
    return supportsOrientationLockForLogicalDisplay(logicalSize);
  }

  Future<void> enterWinPiP(double videoRatio) {
    if (!_isWindows) return Future<void>.value();
    final activeTransition = _windowsPipTransition;
    if (activeTransition != null) return activeTransition;
    if (_windowsPipActive) return Future<void>.value();

    late final Future<void> transition;
    transition = _enterWindowsPip(videoRatio).whenComplete(() {
      if (identical(_windowsPipTransition, transition)) _windowsPipTransition = null;
    });
    _windowsPipTransition = transition;
    return transition;
  }

  Future<void> _enterWindowsPip(double videoRatio) async {
    final presentation = _presentationBeforePip ?? _capturePresentation();
    _presentationBeforePip = presentation;
    final resolvedRatio = videoRatio.isFinite && videoRatio > 0 ? videoRatio : 16 / 9;
    try {
      await _preparePresentation();
      await _enterHostPip(resolvedRatio);
    } catch (error, stackTrace) {
      if (await _tryRestorePresentation(presentation)) {
        _presentationBeforePip = null;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    _windowsPipVideoRatio = resolvedRatio;
    _windowsPipActive = true;
  }

  Future<void> exitWinPiP() {
    if (!_isWindows) return Future<void>.value();
    final activeTransition = _windowsPipTransition;
    if (activeTransition != null) return activeTransition;
    if (!_windowsPipActive) return Future<void>.value();

    late final Future<void> transition;
    transition = _exitWindowsPip().whenComplete(() {
      if (identical(_windowsPipTransition, transition)) _windowsPipTransition = null;
    });
    _windowsPipTransition = transition;
    return transition;
  }

  Future<void> _exitWindowsPip() async {
    final pipPresentation = _capturePresentation();
    final presentation = _presentationBeforePip ?? pipPresentation;
    await _exitHostPip();

    try {
      await _restorePresentation(presentation);
    } catch (error, stackTrace) {
      await _tryRestorePresentation(pipPresentation);
      if (!await _tryReenterHostPip()) {
        await _tryRestorePresentation(presentation);
        _windowsPipActive = false;
        _presentationBeforePip = null;
        throw WindowsPipExitFailure(cause: error, causeStackTrace: stackTrace, hostIsInPip: false);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    _windowsPipActive = false;
    _presentationBeforePip = null;
  }

  Future<bool> _tryRestorePresentation(WindowPresentationSnapshot presentation) async {
    try {
      await _restorePresentation(presentation);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Windows PiP presentation rollback failed: $error\n$stackTrace');
      return false;
    }
  }

  Future<bool> _tryReenterHostPip() async {
    try {
      await _enterHostPip(_windowsPipVideoRatio);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Windows PiP host re-entry rollback failed: $error\n$stackTrace');
      return false;
    }
  }

  //横屏
  Future<void> landScape() async {
    dynamic document;
    try {
      if (kIsWeb) {
        await document.documentElement?.requestFullscreen();
      } else if (Platform.isAndroid || Platform.isIOS) {
        if (!_canApplyMobileOrientationLock()) return;
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        await doEnterWindowFullScreen();
      }
    } catch (exception, stacktrace) {
      debugPrint(exception.toString());
      debugPrint(stacktrace.toString());
    }
  }

  //竖屏
  Future<void> verticalScreen() async {
    if (!_canApplyMobileOrientationLock()) return;
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Future<void> followSystemOrientation() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
  }

  Future<void> doEnterFullScreen() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await doEnterWindowFullScreen();
    }
  }

  //退出全屏显示
  Future<void> doExitFullScreen() async {
    dynamic document;
    try {
      if (kIsWeb) {
        document.exitFullscreen();
      } else if (Platform.isAndroid || Platform.isIOS) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
        await Future.microtask(() {});
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light),
        );
        await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
      } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        await doExitWindowFullScreen();
      }
    } catch (exception, stacktrace) {
      debugPrint(exception.toString());
      debugPrint(stacktrace.toString());
    }
  }

  Future<void> doExitWindowFullScreen() async {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      await windowManager.setFullScreen(false);
    }
  }

  Future<void> doEnterWindowFullScreen({bool enableEscListener = true, VoidCallback? onEsc}) async {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      await enterDesktopFullscreen(
        isWindows: Platform.isWindows,
        prepareWindowsFullscreen: () => windowManager.setTitleBarStyle(TitleBarStyle.hidden),
        setFullScreen: windowManager.setFullScreen,
      );
    }
  }
}
