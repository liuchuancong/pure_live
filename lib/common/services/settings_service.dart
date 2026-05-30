import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/settings/cache_controller.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';
import 'package:pure_live/common/services/settings/history_controller.dart';
import 'package:pure_live/common/services/settings/web_dav_controller.dart';
import 'package:pure_live/common/services/settings/startup_controller.dart';
import 'package:pure_live/common/services/settings/window_size_controller.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/services/settings/exit_settings_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings/iptv_settings_controller.dart';
import 'package:pure_live/common/services/settings/proxy_settings_controller.dart';
import 'package:pure_live/common/services/settings/theme_settings_controller.dart';
import 'package:pure_live/common/services/settings/player_settings_controller.dart';
import 'package:pure_live/common/services/settings/cookie_settings_controller.dart';
import 'package:pure_live/common/services/settings/volume_settings_controller.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';

class SettingsService extends GetxService {
  static SettingsService get to => Get.find<SettingsService>();

  AppSettingsController get app => Get.find<AppSettingsController>();
  ExitSettingsController get exit => Get.find<ExitSettingsController>();
  StartupController get startup => Get.find<StartupController>();
  PlayerSettingsController get player => Get.find<PlayerSettingsController>();
  DanmakuSettingsController get danmaku => Get.find<DanmakuSettingsController>();
  FontSettingsController get font => Get.find<FontSettingsController>();
  WindowSizeController get window => Get.find<WindowSizeController>();
  FavoriteRoomController get fav => Get.find<FavoriteRoomController>();
  HistoryController get history => Get.find<HistoryController>();
  CacheController get cache => Get.find<CacheController>();
  CookieSettingsController get cookieManager => Get.find<CookieSettingsController>();
  WebDavController get webdav => Get.find<WebDavController>();
  IptvSettingsController get iptv => Get.find<IptvSettingsController>();
  VolumeSettingsController get vol => Get.find<VolumeSettingsController>();
  ThemeSettingsController get theme => Get.find<ThemeSettingsController>();
  ProxySettingsController get proxy => Get.find<ProxySettingsController>();
  BackupController get backup => Get.find<BackupController>();

  @override
  void onInit() {
    super.onInit();
    Get.put(AppSettingsController(), permanent: true);
    Get.put(ExitSettingsController(), permanent: true);
    Get.put(StartupController(), permanent: true);
    Get.put(PlayerSettingsController(), permanent: true);
    Get.put(DanmakuSettingsController(), permanent: true);
    Get.put(FontSettingsController(), permanent: true);
    Get.put(WindowSizeController(), permanent: true);
    Get.put(FavoriteRoomController(), permanent: true);
    Get.put(HistoryController(), permanent: true);
    Get.put(CacheController(), permanent: true);
    Get.put(CookieSettingsController(), permanent: true);
    Get.put(WebDavController(), permanent: true);
    Get.put(IptvSettingsController(), permanent: true);
    Get.put(VolumeSettingsController(), permanent: true);
    Get.put(ThemeSettingsController(), permanent: true);
    Get.put(ProxySettingsController(), permanent: true);
    Get.put(BackupController(), permanent: true);
  }
}
