import 'dart:io';
import 'dart:developer';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/global.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:pure_live/common/global/windows_utils.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/modules/live_play/player_state.dart';
import 'package:pure_live/recorder/services/cache_service.dart';
import 'package:pure_live/common/global/platform/mobile_manager.dart';
import 'package:pure_live/common/global/platform/desktop_manager.dart';
import 'package:pure_live/common/services/bilibili_account_service.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';

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

    final appDir = await getApplicationDocumentsDirectory();
    String path =
        '${appDir.path}${Platform.pathSeparator}pure_live${instanceId.isNotEmpty ? "${Platform.pathSeparator}$instanceId" : ""}';

    try {
      await SupaBaseManager.getInstance().initial();
      await Hive.initFlutter(path);
      await HivePrefUtil.init();
      initService();
    } catch (e) {
      log("Hive Init Error: $e");
      exit(0);
    }
    SmartDialog.config.toast = SmartConfigToast(
      displayTime: const Duration(milliseconds: 3000),
      intervalTime: const Duration(milliseconds: 100),
    );
    MediaKit.ensureInitialized();
    if (PlatformUtils.isDesktop) {
      await DesktopManager.initialize();

      Future.delayed(const Duration(milliseconds: 800), () {
        WindowUtils.markCurrentWindow(instanceId);
      });
    } else if (PlatformUtils.isMobile) {
      await MobileManager.initialize();
    }
    await FFmpegKitExtended.initialize();
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

  void initService() {
    Get.put(SettingsService(), permanent: true);
    Get.put(AuthController(), permanent: true);
    Get.put(CacheService());
    Get.put(RecordSettingsController());
    Get.put(RecorderController());

    Get.lazyPut(() => FavoriteController(), fenix: true);
    Get.lazyPut(() => BiliBiliAccountService(), fenix: true);
    Get.lazyPut(() => PopularController(), fenix: true);
    Get.lazyPut(() => AreasController(), fenix: true);

    Get.lazyPut(() => StreamResolverService(), fenix: true);
    Get.lazyPut(() => GlobalPlayerState(), fenix: true);
  }

  bool get isInitialized => _isInitialized;
}
