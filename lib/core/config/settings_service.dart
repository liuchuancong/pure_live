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

/// Core 平台的设置门面：只暴露 Core 自己拥有的设置 Provider。
///
/// 平台级偏好（主题、字体、窗口、音量、播放内核、弹幕、代理、缓存、日志、
/// 刷新节奏、房间卡片、页面参数、启动/退出行为）属于 Core 基础设施。
///
/// 具体业务域的设置不在这里：关注与历史、标签归 domains/live，账号 Cookie 归
/// domains/account，IPTV 归 domains/iptv，备份与 WebDAV 归 features。它们各自
/// 提供 `XxxController.to`，注册统一在 App 装配层 InitialServices 完成，
/// 这样 Core 不再反向依赖 Domains/Features。
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
