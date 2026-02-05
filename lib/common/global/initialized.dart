import 'dart:io';
import 'dart:ffi';
import 'dart:developer';
import 'package:get/get.dart';
import 'package:win32/win32.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/global.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/modules/live_play/player_state.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:pure_live/common/global/platform/mobile_manager.dart';
import 'package:pure_live/common/global/platform/desktop_manager.dart';
import 'package:pure_live/common/services/bilibili_account_service.dart';

class AppInitializer {
  // 单例实例
  static final AppInitializer _instance = AppInitializer._internal();

  // 是否已经初始化
  bool _isInitialized = false;

  // 工厂构造函数，返回单例
  factory AppInitializer() {
    return _instance;
  }

  // 私有构造函数
  AppInitializer._internal();

  // 初始化方法
  Future<void> initialize(List<String> args) async {
    if (_isInitialized) return;

    WidgetsFlutterBinding.ensureInitialized();

    // 👇 从启动参数获取实例 ID
    String instanceId = getInstanceIdFromArgs(args);

    // 👇 每个实例使用独立 Hive 路径
    final appDir = await getApplicationDocumentsDirectory();
    String path = '${appDir.path}${Platform.pathSeparator}pure_live${Platform.pathSeparator}$instanceId';
    if (instanceId.isEmpty) {
      path = '${appDir.path}${Platform.pathSeparator}pure_live';
    }
    if (PlatformUtils.isDesktopNotMac) {
      // Hive 默认锁文件通常叫 'LOCK'，但我们可以自己维护一个实例锁，更加稳定
      final lockFile = File('$path${Platform.pathSeparator}app_instance.lock');

      try {
        if (!lockFile.parent.existsSync()) lockFile.parent.createSync(recursive: true);
        final raf = lockFile.openSync(mode: FileMode.write);
        raf.lockSync();
      } catch (e) {
        log("检测到实例 [$instanceId] 文件夹已被锁定，正在唤醒已有窗口...");
        final hwnd = FindWindow(nullptr, TEXT('纯粹直播'));
        if (hwnd != 0) {
          if (IsIconic(hwnd) != 0) ShowWindow(hwnd, SW_RESTORE);
          SetForegroundWindow(hwnd);
        }
        exit(0);
      }
    }
    if (PlatformUtils.isDesktop) {
      await DesktopManager.initialize();
    } else if (PlatformUtils.isMobile) {
      await MobileManager.initialize();
    }

    PrefUtil.prefs = await SharedPreferences.getInstance();
    try {
      await Hive.initFlutter(path);
      await HivePrefUtil.init();
    } catch (e) {
      log(e.toString(), name: 'Hive');
      exit(0);
    }
    MediaKit.ensureInitialized();
    await SupaBaseManager.getInstance().initial();

    if (PlatformUtils.isDesktop) {
      await DesktopManager.postInitialize();
    }

    initRefresh();
    initService();

    if (PlatformUtils.isDesktopNotMac) {
      if (!await FlutterSingleInstance().isFirstInstance()) {
        log("Default instance is already running");
        exit(0);
      }
      await _setupLaunchAtStartup();
    }
    _isInitialized = true;
  }

  // 提取 launchAtStartup 设置
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

  // 工具方法：解析 instanceId
  String getInstanceIdFromArgs(List<String> args) {
    for (var arg in args) {
      if (arg.startsWith('--instance=')) {
        return arg.split('=')[1];
      }
      return '';
    }
    return '';
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

  // 检查是否已初始化
  bool get isInitialized => _isInitialized;
}
