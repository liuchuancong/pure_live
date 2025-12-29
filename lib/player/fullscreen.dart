import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_live/player/win32_window.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:auto_orientation_v2/auto_orientation_v2.dart';

class WindowService {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal();

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
  }
}
