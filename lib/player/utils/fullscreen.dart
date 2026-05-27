import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_live/common/index.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:pure_live/player/utils/window_helper.dart';
import 'package:auto_orientation_v2/auto_orientation_v2.dart';
import 'package:pure_live/modules/live_play/player_state.dart';
import 'package:pure_live/modules/live_play/live_play_controller.dart';

class WindowService {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal();
  Future<void> enterWinPiP(double videoRatio) async {
    if (!Platform.isWindows) return;
    if (GlobalPlayerState.to.isFullscreen.value) {
      final livePlayController = Get.find<LivePlayController>();
      livePlayController.videoController.value!.toggleFullScreen();
    }
    Future.microtask(() {
      WindowHelper.instance.enterPiP(videoRatio);
    });
  }

  Future<void> exitWinPiP() async {
    if (!Platform.isWindows) return;
    WindowHelper.instance.exitPiP();
  }

  //横屏
  Future<void> landScape() async {
    dynamic document;
    try {
      if (kIsWeb) {
        await document.documentElement?.requestFullscreen();
      } else if (Platform.isAndroid || Platform.isIOS) {
        await AutoOrientation.landscapeAutoMode(forceSensor: true);
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
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        await doExitWindowFullScreen();
      }
    } catch (exception, stacktrace) {
      debugPrint(exception.toString());
      debugPrint(stacktrace.toString());
    }
  }

  Future<void> doExitWindowFullScreen() async {
    if (Platform.isWindows) {
      FullScreenWindow.setFullScreen(false);
      return;
    }
    if (Platform.isMacOS || Platform.isLinux) {
      await windowManager.setFullScreen(false);
    }
  }

  Future<void> doEnterWindowFullScreen({bool enableEscListener = true, VoidCallback? onEsc}) async {
    if (Platform.isWindows) {
      FullScreenWindow.setFullScreen(true);
    }
    if (Platform.isMacOS || Platform.isLinux) {
      await windowManager.setFullScreen(true);
    }
  }
}
