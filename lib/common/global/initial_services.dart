import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/modules/live_play/player_state.dart';
import 'package:pure_live/recorder/services/cache_service.dart';
import 'package:pure_live/routes/route_observer_controller.dart';
import 'package:pure_live/modules/auth/utils/firebase_manager.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';
import 'package:pure_live/core/iptv/services/channel_detail_controller.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';

class InitialServices {
  static void initGlobalServices() {
    Get.put(SettingsService(), permanent: true);
    Get.put(RouteObserverController(), permanent: true);
  }

  static void initLazyControllers() {
    // 关注
    Get.lazyPut(() => FavoriteController(), fenix: true);
    // iptv频道
    Get.lazyPut(() => ChannelDetailController(), fenix: true);
    // 热门
    Get.lazyPut(() => PopularController(), fenix: true);
    // 分区
    Get.lazyPut(() => AreasController(), fenix: true);
    // 播放器状态
    Get.lazyPut(() => GlobalPlayerState(), fenix: true);
  }

  static Future<void> initDb() async {
    final db = DbService();
    await db.init();
    Get.put<DbService>(db, permanent: true);
  }

  static Future<void> init() async {
    await initDb();
    initGlobalServices();
    initLazyControllers();
    _initHeavyServicesInBackground();
  }

  static void _initHeavyServicesInBackground() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await FirebaseManager.getInstance().initial();
        await Future.delayed(const Duration(seconds: 2));
        Get.put(AuthController(), permanent: true);
      } catch (_) {}
      try {
        await FFmpegKitExtended.initialize();
        await Future.delayed(const Duration(seconds: 2));
        Get.put(CacheService(), permanent: true);
        Get.put(RecordSettingsController(), permanent: true);
        Get.put(RecorderController(), permanent: true);
        Get.lazyPut(() => StreamResolverService(), fenix: true);
      } catch (_) {}
    });
  }
}
