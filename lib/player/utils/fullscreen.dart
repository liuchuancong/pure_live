import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_fullscreen/media_core_fullscreen.dart';
import 'package:pure_live/core/index.dart';

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

final class PureLiveFullscreenWindow implements FullscreenWindow {
  const PureLiveFullscreenWindow();

  @override
  Future<bool> get isFullscreen => windowManager.isFullScreen();

  @override
  Future<Rect> captureBounds() => windowManager.getBounds();

  @override
  Future<void> setFullscreen(bool value, {Rect? restoreBounds}) async {
    if (value) {
      await enterDesktopFullscreen(
        isWindows: Platform.isWindows,
        prepareWindowsFullscreen: () => windowManager.setTitleBarStyle(TitleBarStyle.hidden),
        setFullScreen: windowManager.setFullScreen,
      );
      return;
    }
    await windowManager.setFullScreen(false);
    if (restoreBounds != null) {
      await windowManager.setBounds(restoreBounds);
    }
  }
}

final FullscreenDriver fullscreenDriver = FullscreenDriver(
  // Restoring the pre-fullscreen bounds is load-bearing beyond fullscreen
  // itself: entering picture-in-picture releases fullscreen first, and the
  // PiP backend captures the window state at that moment. Without the
  // restore, that state is the screen-sized window, and both the PiP exit
  // and the next fullscreen exit bring the window back screen-sized.
  config: const FullscreenConfig(restorePreviousBounds: true),
  desktopWindow: const PureLiveFullscreenWindow(),
);

class WindowService {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal();

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
        await doEnterFullScreen();
      }
    } catch (exception, stacktrace) {
      debugPrint(exception.toString());
      debugPrint(stacktrace.toString());
    }
  }

  Future<void> verticalScreen() async {
    if (!_canApplyMobileOrientationLock()) return;
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Future<void> followSystemOrientation() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
  }

  Future<void> doEnterFullScreen() async {
    if (kIsWeb) return;
    // One driver request serves both platform families: the driver performs
    // the desktop window transition (through PureLiveFullscreenWindow, with
    // its frameless guard) and the mobile immersive switch itself.
    await fullscreenDriver.initialize();
    await fullscreenDriver.apply(PlayerId('pure-live'), PresentationRequest.fullscreen());
  }

  Future<void> doExitFullScreen() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // Host-owned policy on mobile: the status bar styling and the
        // orientation release are this app's theming and orientation rules.
        // The system UI mode itself is restored by the driver below.
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light),
        );
        await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
      }
      await fullscreenDriver.initialize();
      await fullscreenDriver.apply(PlayerId('pure-live'), PresentationRequest.normal());
    } catch (exception, stacktrace) {
      debugPrint(exception.toString());
      debugPrint(stacktrace.toString());
    }
  }
}
