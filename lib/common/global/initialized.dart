import 'dart:io';
import 'dart:developer';
import 'app_path_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/global.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/global/initial_services.dart';
import 'package:pure_live/modules/auth/utils/firebase_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'package:pure_live/common/global/platform/mobile_manager.dart';
import 'package:pure_live/common/global/platform/desktop_manager.dart';

class AppInitializer {
  static final AppInitializer _instance = AppInitializer._internal();
  bool _isInitialized = false;

  factory AppInitializer() => _instance;
  AppInitializer._internal();

  Future<void> initialize(List<String> args) async {
    if (_isInitialized) return;
    WidgetsFlutterBinding.ensureInitialized();

    String instanceId = getInstanceIdFromArgs(args);

    if (Platform.isWindows && !kDebugMode) {
      await WindowsSingleInstance.ensureSingleInstance(
        args,
        "PureLive_InstanceID_$instanceId",
        bringWindowToFront: false,
        exitFunction: () {
          exit(0);
        },
        onSecondWindow: (arguments) async {
          await windowManager.restore();
          await windowManager.show();
          await windowManager.focus();
        },
      );
    }
    await AppPathManager().initialize(instanceId: instanceId);
    await CustomImageCacheManager.initialize();
    final Directory hiveDir = await AppPathManager().getDir(AppPathManager.dirHiveDB);
    await FirebaseManager.getInstance().initial();
    try {
      await Hive.initFlutter(hiveDir.path);
      await HivePrefUtil.init();
      await InitialServices.init();
    } catch (e) {
      log("Hive Init Error: $e");
      exit(0);
    }
    SmartDialog.config.toast = SmartConfigToast(
      displayTime: const Duration(milliseconds: 3000),
      intervalTime: const Duration(milliseconds: 100),
    );

    if (PlatformUtils.isDesktop) {
      await DesktopManager.initialize();
      if (Platform.isWindows) {
        try {
          await ScreenBrightness().setAutoReset(false);
        } catch (_) {}
      }
    } else if (PlatformUtils.isMobile) {
      await MobileManager.initialize();
    }
    MediaKit.ensureInitialized();
    await EasyLocalization.ensureInitialized();
    initRefresh();
    if (PlatformUtils.isDesktopNotMac) {
      if (instanceId.isEmpty) {
        await SettingsService.to.startup.setupLaunchAtStartup();
      }
    }
    _isInitialized = true;
  }

  String getInstanceIdFromArgs(List<String> args) {
    for (var arg in args) {
      if (arg.startsWith('--instance=')) {
        var parts = arg.split('=');
        return parts.length > 1 ? parts[1] : '';
      }
    }
    return '';
  }

  bool get isInitialized => _isInitialized;
}
