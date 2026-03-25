import 'dart:io';
import 'dart:developer';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/global.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:pure_live/common/global/windows_utils.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/modules/live_play/player_state.dart';
import 'package:pure_live/common/global/platform/mobile_manager.dart';
import 'package:pure_live/common/global/platform/desktop_manager.dart';
import 'package:pure_live/common/services/bilibili_account_service.dart';
import 'package:package_info_plus/package_info_plus.dart' show PackageInfo;

class AppInitializer {
  static final AppInitializer _instance = AppInitializer._internal();
  bool _isInitialized = false;

  factory AppInitializer() => _instance;
  AppInitializer._internal();

  Future<void> initialize(List<String> args) async {
    if (_isInitialized) return;
    WidgetsFlutterBinding.ensureInitialized();

    String instanceId = getInstanceIdFromArgs(args);

    if (PlatformUtils.isDesktopNotMac) {
      if (WindowUtils.wakeUpByProp(instanceId)) {
        log("Instance [$instanceId] already running. Waking up and exiting.");
        exit(0);
      }
    }

    if (PlatformUtils.isDesktop) {
      await DesktopManager.initialize();
    } else if (PlatformUtils.isMobile) {
      await MobileManager.initialize();
    }

    final appDir = await getApplicationDocumentsDirectory();
    String path =
        '${appDir.path}${Platform.pathSeparator}pure_live${instanceId.isNotEmpty ? "${Platform.pathSeparator}$instanceId" : ""}';

    PrefUtil.prefs = await SharedPreferences.getInstance();
    initService();

    try {
      await Hive.initFlutter(path);
      await HivePrefUtil.init();
    } catch (e) {
      log("Hive Init Error: $e");
    }

    MediaKit.ensureInitialized();
    await SupaBaseManager.getInstance().initial();

    if (PlatformUtils.isDesktop) {
      await DesktopManager.postInitialize();
      Future.delayed(const Duration(milliseconds: 800), () {
        WindowUtils.markCurrentWindow(instanceId);
      });
    }
    if (PlatformUtils.isDesktopNotMac) {
      // 只有主实例（instanceId 为空）才注册自启，避免多个实例互相覆盖注册表
      if (instanceId.isEmpty) {
        await _setupLaunchAtStartup();
      }
    }

    initRefresh();
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

   Future<void> _setupLaunchAtStartup() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: packageInfo.appName,
      appPath: Platform.resolvedExecutable,
      packageName: 'dev.leanflutter.puretech.pure_live',
    );
    var settings = Get.find<SettingsService>();
    if (settings.enableStartUp.value) {
      bool enabled = await launchAtStartup.isEnabled();
      if (!enabled) {
        await launchAtStartup.enable();
      }
    }
  }

  void initService() {
    Get.put(SettingsService());
    Get.put(AuthController());
    Get.put(FavoriteController());
    Get.put(BiliBiliAccountService());
    Get.put(PopularController());
    Get.put(AreasController());
    Get.put(GlobalPlayerState());
  }

  bool get isInitialized => _isInitialized;
}
