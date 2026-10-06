import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/config/app_settings_controller.dart';
import 'package:pure_live/core/config/cache_controller.dart';
import 'package:pure_live/core/config/danmaku_settings_controller.dart';
import 'package:pure_live/core/config/exit_settings_controller.dart';
import 'package:pure_live/core/config/font_settings_controller.dart';
import 'package:pure_live/core/config/log_controller.dart';
import 'package:pure_live/core/config/page_settings_controller.dart';
import 'package:pure_live/core/config/player_settings_controller.dart';
import 'package:pure_live/core/config/proxy_settings_controller.dart';
import 'package:pure_live/core/config/refresh_config_controller.dart';
import 'package:pure_live/core/config/room_card_settings_controller.dart';
import 'package:pure_live/core/config/startup_controller.dart';
import 'package:pure_live/core/config/theme_settings_controller.dart';
import 'package:pure_live/core/config/volume_settings_controller.dart';
import 'package:pure_live/core/config/window_size_controller.dart';

class SettingsService extends GetxService {
  static SettingsService get to => Get.find<SettingsService>();

  AppSettingsController get app => Get.find<AppSettingsController>();
  ExitSettingsController get exit => Get.find<ExitSettingsController>();
  StartupController get startup => Get.find<StartupController>();
  PlayerSettingsController get player => Get.find<PlayerSettingsController>();
  DanmakuSettingsController get danmaku => Get.find<DanmakuSettingsController>();
  FontSettingsController get font => Get.find<FontSettingsController>();
  WindowSizeController get window => Get.find<WindowSizeController>();
  CacheController get cache => Get.find<CacheController>();
  VolumeSettingsController get vol => Get.find<VolumeSettingsController>();
  ThemeSettingsController get theme => Get.find<ThemeSettingsController>();
  RoomCardSettingsController get roomCard => Get.find<RoomCardSettingsController>();
  ProxySettingsController get proxy => Get.find<ProxySettingsController>();
  RefreshConfigController get refreshConfig => Get.find<RefreshConfigController>();
  PageSettingsController get page => Get.find<PageSettingsController>();
  LogController get log => Get.find<LogController>();
}
