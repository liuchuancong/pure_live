import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/modules/live_play/player_state.dart';
import 'package:pure_live/recorder/services/cache_service.dart';
import 'package:pure_live/routes/route_observer_controller.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';
import 'package:pure_live/core/iptv/services/channel_detail_controller.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';

class InitialServices {
  static void initGlobalServices() {
    Get.put(TagManagementController(), permanent: true);
    Get.put(SettingsService(), permanent: true);
    Get.put(CacheService(), permanent: true);
    Get.put(AuthController(), permanent: true);
    Get.put(RouteObserverController(), permanent: true);
  }

  static void initLazyControllers() {
    Get.lazyPut(() => RecordSettingsController());
    Get.lazyPut(() => RecorderController());
    Get.lazyPut(() => FavoriteController(), fenix: true);
    Get.lazyPut(() => ChannelDetailController(), fenix: true);
    Get.lazyPut(() => PopularController(), fenix: true);
    Get.lazyPut(() => AreasController(), fenix: true);
    Get.lazyPut(() => StreamResolverService(), fenix: true);
    Get.lazyPut(() => GlobalPlayerState(), fenix: true);
  }

  static Future<void> initDb() async {
    final db = DbService();
    await db.init();
    Get.put<DbService>(db, permanent: true);
  }

  static Future<void> init() async {
    initGlobalServices();
    initLazyControllers();
    await initDb();
  }
}
