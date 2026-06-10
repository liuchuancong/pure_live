import 'dart:io';
import 'dart:developer';
import 'app_path_manager.dart';
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

  bool get isInitialized => _isInitialized;

  Future<void> initialize(List<String> args) async {
    if (_isInitialized) return;

    WidgetsFlutterBinding.ensureInitialized();
    await EasyLocalization.ensureInitialized();

    final String instanceId = _getInstanceIdFromArgs(args);
    await _initWindowsSingleInstance(args, instanceId);

    await AppPathManager().initialize(instanceId: instanceId);
    final Directory hiveDir = await AppPathManager().getDir(AppPathManager.dirHiveDB);

    await Future.wait([
      Hive.initFlutter(hiveDir.path).then((_) => HivePrefUtil.init()),
      FirebaseManager.getInstance().initial(),
      CustomImageCacheManager.initialize(),
    ]);

    InitialServices.init();
    _initSmartDialog();
    initRefresh();

    if (PlatformUtils.isDesktop) {
      await DesktopManager.initialize();
      if (Platform.isWindows) {
        _initWindowsScreenBrightness();
      }
    } else if (PlatformUtils.isMobile) {
      await MobileManager.initialize();
    }

    if (PlatformUtils.isDesktopNotMac && instanceId.isEmpty) {
      _setupLaunchAtStartupSafe();
    }

    _isInitialized = true;
  }

  String _getInstanceIdFromArgs(List<String> args) {
    for (final arg in args) {
      if (arg.startsWith('--instance=')) {
        final parts = arg.split('=');
        return parts.length > 1 ? parts[1] : '';
      }
    }
    return '';
  }

  Future<void> _initWindowsSingleInstance(List<String> args, String instanceId) async {
    if (!Platform.isWindows) return;
    try {
      final safeId = instanceId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
      await WindowsSingleInstance.ensureSingleInstance(
        args,
        "PureLive_InstanceID_$safeId",
        bringWindowToFront: true,
        exitFunction: () => exit(0),
      );
    } catch (e) {
      log('WindowsSingleInstance initialization failed: $e');
    }
  }

  void _initWindowsScreenBrightness() {
    ScreenBrightness().setAutoReset(false).catchError((e) {
      log('ScreenBrightness error: $e');
    });
  }

  Future<void> _setupLaunchAtStartupSafe() async {
    try {
      await SettingsService.to.startup.setupLaunchAtStartup();
    } catch (e) {
      log('Setup launch at startup failed: $e');
    }
  }

  void _initSmartDialog() {
    SmartDialog.config.toast = SmartConfigToast(
      displayTime: const Duration(milliseconds: 3000),
      intervalTime: const Duration(milliseconds: 100),
    );
  }
}
