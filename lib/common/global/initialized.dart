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
import 'package:pure_live/common/global/windows_utils.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/global/initial_binding.dart';
import 'package:pure_live/common/global/platform/mobile_manager.dart';
import 'package:pure_live/common/global/platform/desktop_manager.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

class AppInitializer {
  static final AppInitializer _instance = AppInitializer._internal();
  bool _isInitialized = false;

  factory AppInitializer() => _instance;
  AppInitializer._internal();

  Future<void> initialize(List<String> args) async {
    if (_isInitialized) return;
    WidgetsFlutterBinding.ensureInitialized();

    String instanceId = getInstanceIdFromArgs(args);

    if (PlatformUtils.isDesktopNotMac && !kDebugMode) {
      if (WindowUtils.wakeUpByProp(instanceId)) {
        log("Instance [$instanceId] already running. Waking up and exiting.");
        exit(0);
      }
    }
    await AppPathManager().initialize(instanceId: instanceId);
    await CustomImageCacheManager.initialize();
    final Directory hiveDir = await AppPathManager().getDir(AppPathManager.dirHiveDB);
    await SupaBaseManager.getInstance().initial();

    try {
      await Hive.initFlutter(hiveDir.path);
      await HivePrefUtil.init();
      InitialBinding().dependencies();
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

      Future.delayed(const Duration(milliseconds: 800), () {
        WindowUtils.markCurrentWindow(instanceId);
      });
    } else if (PlatformUtils.isMobile) {
      await MobileManager.initialize();
    }
    MediaKit.ensureInitialized();
    await FFmpegKitExtended.initialize();
    await EasyLocalization.ensureInitialized();
    initRefresh();

    if (PlatformUtils.isDesktopNotMac) {
      if (instanceId.isEmpty) {
        await Get.find<SettingsService>().setupLaunchAtStartup();
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

  // void initService() async {
  //   Get.put(SettingsService(), permanent: true);
  //   Get.put(CacheService());
  //   Get.put(AuthController(), permanent: true);
  //   Get.put(RecordSettingsController());
  //   Get.put(RecorderController());
  //   Get.put(BiliBiliAccountService());
  //   Get.put(RouteObserverController(), permanent: true);
  //   Get.put(TagManagementController(), permanent: true);

  //   Get.put(FavoriteController(), permanent: true);
  //   Get.lazyPut<DbService>(() => DbService()..init(), fenix: true);
  //   Get.lazyPut(() => ChannelDetailController(), fenix: true);
  //   Get.lazyPut(() => PopularController(), fenix: true);
  //   Get.lazyPut(() => AreasController(), fenix: true);

  //   Get.lazyPut(() => StreamResolverService(), fenix: true);
  //   Get.lazyPut(() => GlobalPlayerState(), fenix: true);
  // }

  bool get isInitialized => _isInitialized;
}
