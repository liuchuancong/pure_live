import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/win32_window.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:auto_orientation_v2/auto_orientation_v2.dart';
import 'package:pure_live/modules/live_play/live_play_controller.dart';

class WindowService {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal();
  Future<void> enterWinPiP(double videoRatio) async {
    if (!Platform.isWindows) return;
    Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
    Size safeSize = primaryDisplay.visibleSize ?? primaryDisplay.size;
    Offset safeOffset = primaryDisplay.visiblePosition ?? Offset.zero;
    double maxSide = 350.0;
    double w, h;
    if (videoRatio >= 1) {
      w = maxSide;
      h = maxSide / videoRatio;
    } else {
      h = maxSide * 1.2;
      w = h * videoRatio;
      if (w < 120) {
        w = 120;
        h = w / videoRatio;
      }
    }
    double x = (safeOffset.dx + safeSize.width) - w - 20;
    double y = (safeOffset.dy + safeSize.height) - h - 20;
    WinFullscreen.enterPipMode(width: w, height: h, x: x, y: y);
  }

  Future<void> exitWinPiP() async {
    if (!Platform.isWindows) return;
    WinFullscreen.exitSpecialMode();
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
    late SystemUiMode mode = SystemUiMode.edgeToEdge;
    try {
      if (kIsWeb) {
        document.exitFullscreen();
      } else if (Platform.isAndroid || Platform.isIOS) {
        if (Platform.isAndroid && (await DeviceInfoPlugin().androidInfo).version.sdkInt < 29) {
          mode = SystemUiMode.manual;
        }
        await SystemChrome.setEnabledSystemUIMode(mode, overlays: SystemUiOverlay.values);
        await SystemChrome.setPreferredOrientations([]);
      } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        await doExitWindowFullScreen();
      }
    } catch (exception, stacktrace) {
      debugPrint(exception.toString());
      debugPrint(stacktrace.toString());
    }
  }

  Future<void> doExitWindowFullScreen() async {
    WinFullscreen.exitFullscreen();
  }

  Future<void> doEnterWindowFullScreen() async {
    WinFullscreen.enterFullscreen();
    final LivePlayController livePlayController = Get.find<LivePlayController>();
    WinFullscreen.startEscListener(() => livePlayController.videoController.value!.toggleFullScreen());
  }
}
