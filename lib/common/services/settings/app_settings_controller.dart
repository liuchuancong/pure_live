import 'dart:async';
import 'dart:io';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';

class AppSettingsController extends GetxController {
  static const int maxSleepMinutes = 525600;
  static const List<String> defaultRealOnlinePlatforms = ['douyin', 'kuaishou', 'cc', 'twitch'];

  Worker? _highRefreshRateWorker;

  final RxInt autoRefreshTime = hiveInt('autoRefreshTime', 3);
  final RxBool enableDenseFavorites = hiveBool('enableDenseFavorites', true);
  final RxBool enableBackgroundPlay = hiveBool('enableBackgroundPlay', false);
  final RxBool enableAsmrSleepMode = hiveBool('enableAsmrSleepMode', false);
  final RxInt asmrSleepMinutes = hiveInt('asmrSleepMinutes', 60);
  final RxBool enableRotateScreen = hiveBool('enableRotateScreen', false);

  final RxBool enableScreenKeepOn = hiveBool('enableScreenKeepOn', true);

  final RxBool enableAutoCheckUpdate = hiveBool('enableAutoCheckUpdate', true);
  final RxBool useGitHubOriginForUpdates = hiveBool('useGitHubOriginForUpdates', false);
  final RxBool enableFullScreenDefault = hiveBool('enableFullScreenDefault', false);
  final RxBool showSplashPage = hiveBool('showSplashPage', true);
  final RxBool enableHighRefreshRate = hiveBool('enableHighRefreshRate', true);
  final RxBool preferRealOnlineCounts = hiveBool('preferRealOnlineCounts', false);
  late final RxList<String> realOnlinePlatforms = hiveStringList('realOnlinePlatforms', defaultRealOnlinePlatforms);
  final RxInt audienceMetricMigration = hiveInt('audienceMetricMigration', 0);

  late final RxList<String> savedMenuIds = hiveStringList('savedMenuIds', HomeMenu.values.map((e) => e.id).toList());

  @override
  void onInit() {
    super.onInit();
    if (audienceMetricMigration.v < 1) {
      if (!realOnlinePlatforms.contains('twitch')) realOnlinePlatforms.add('twitch');
      audienceMetricMigration.v = 1;
    }
    _removeUnsupportedOnlinePlatforms();
    if (Platform.isAndroid) {
      unawaited(DisplayModeService.setHighRefreshRate(enableHighRefreshRate.v));
      _highRefreshRateWorker = ever<bool>(
        enableHighRefreshRate,
        (enabled) => unawaited(DisplayModeService.setHighRefreshRate(enabled)),
      );
    } else if (Platform.isWindows) {
      // Flutter follows the active Windows monitor's vsync. The native runner
      // reports that monitor's current/supported modes and pushes updates when
      // the window moves between displays or Windows changes display mode.
      unawaited(DisplayModeService.refreshInfo());
    }
  }

  void _removeUnsupportedOnlinePlatforms() {
    final supported = normalizeRealOnlinePlatforms(realOnlinePlatforms);
    if (supported.length != realOnlinePlatforms.length) {
      realOnlinePlatforms.v = supported;
    }
  }

  static List<String> normalizeRealOnlinePlatforms(Iterable<String> platforms) {
    return platforms
        .where((platform) => LiveRoom.audienceCapabilityFor(platform).supportsConcurrentOnline)
        .toSet()
        .toList();
  }

  @override
  void onClose() {
    _highRefreshRateWorker?.dispose();
    _highRefreshRateWorker = null;
    super.onClose();
  }

  void toggleMenuVisibility(HomeMenu menu, bool visible) {
    final ids = List<String>.from(savedMenuIds.v);
    if (visible) {
      if (!ids.contains(menu.id)) ids.add(menu.id);
    } else {
      ids.removeWhere((id) => id == menu.id);
    }
    savedMenuIds.v = ids;
  }

  bool isRealOnlineEnabledFor(String? platform) => realOnlinePlatforms.contains(platform);

  void setRealOnlineEnabledFor(String platform, bool enabled) {
    if (!LiveRoom.audienceCapabilityFor(platform).supportsConcurrentOnline) return;
    final next = List<String>.from(realOnlinePlatforms);
    if (enabled) {
      if (!next.contains(platform)) next.add(platform);
    } else {
      next.remove(platform);
    }
    realOnlinePlatforms.v = next;
  }

  // ======================
  // 备份/恢复
  // ======================
  Map<String, dynamic> toJson() {
    return {
      'autoRefreshTime': autoRefreshTime.v,
      'enableDenseFavorites': enableDenseFavorites.v,
      'enableBackgroundPlay': enableBackgroundPlay.v,
      'enableAsmrSleepMode': enableAsmrSleepMode.v,
      'asmrSleepMinutes': asmrSleepMinutes.v,
      'enableRotateScreen': enableRotateScreen.v,
      'enableScreenKeepOn': enableScreenKeepOn.v,
      'enableAutoCheckUpdate': enableAutoCheckUpdate.v,
      'useGitHubOriginForUpdates': useGitHubOriginForUpdates.v,
      'enableFullScreenDefault': enableFullScreenDefault.v,
      'showSplashPage': showSplashPage.v,
      'enableHighRefreshRate': enableHighRefreshRate.v,
      'preferRealOnlineCounts': preferRealOnlineCounts.v,
      'realOnlinePlatforms': realOnlinePlatforms.v,
      'savedMenuIds': savedMenuIds.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    autoRefreshTime.v = json['autoRefreshTime'] ?? 3;
    enableDenseFavorites.v = json['enableDenseFavorites'] ?? true;
    enableBackgroundPlay.v = json['enableBackgroundPlay'] ?? false;
    enableAsmrSleepMode.v = json['enableAsmrSleepMode'] ?? false;
    asmrSleepMinutes.v = (((json['asmrSleepMinutes'] as num?)?.toInt() ?? 60).clamp(1, maxSleepMinutes)).toInt();
    enableRotateScreen.v = json['enableRotateScreen'] ?? false;
    enableScreenKeepOn.v = json['enableScreenKeepOn'] ?? true;
    enableAutoCheckUpdate.v = json['enableAutoCheckUpdate'] ?? true;
    useGitHubOriginForUpdates.v = json['useGitHubOriginForUpdates'] ?? false;
    enableFullScreenDefault.v = json['enableFullScreenDefault'] ?? false;
    showSplashPage.v = json['showSplashPage'] ?? true;
    enableHighRefreshRate.v = json['enableHighRefreshRate'] ?? true;
    preferRealOnlineCounts.v = json['preferRealOnlineCounts'] ?? false;
    realOnlinePlatforms.v = List<String>.from(json['realOnlinePlatforms'] ?? defaultRealOnlinePlatforms);
    _removeUnsupportedOnlinePlatforms();
    savedMenuIds.v = List<String>.from(json['savedMenuIds'] ?? HomeMenu.values.map((e) => e.id).toList());
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final app = rootConfig?['app'] as Map<String, dynamic>? ?? {};
    return {
      'autoRefreshTime': app['autoRefreshTime'] ?? 3,
      'enableDenseFavorites': app['enableDenseFavorites'] ?? true,
      'enableBackgroundPlay': app['enableBackgroundPlay'] ?? false,
      'enableAsmrSleepMode': app['enableAsmrSleepMode'] ?? false,
      'asmrSleepMinutes': (((app['asmrSleepMinutes'] as num?)?.toInt() ?? 60).clamp(1, maxSleepMinutes)).toInt(),
      'enableRotateScreen': app['enableRotateScreen'] ?? false,
      'enableScreenKeepOn': app['enableScreenKeepOn'] ?? true,
      'enableAutoCheckUpdate': app['enableAutoCheckUpdate'] ?? true,
      'useGitHubOriginForUpdates': app['useGitHubOriginForUpdates'] ?? false,
      'enableFullScreenDefault': app['enableFullScreenDefault'] ?? false,
      'showSplashPage': app['showSplashPage'] ?? true,
      'enableHighRefreshRate': app['enableHighRefreshRate'] ?? true,
      'preferRealOnlineCounts': app['preferRealOnlineCounts'] ?? false,
      'realOnlinePlatforms': normalizeRealOnlinePlatforms(
        List<String>.from(app['realOnlinePlatforms'] ?? defaultRealOnlinePlatforms),
      ),
      'savedMenuIds': List<String>.from(app['savedMenuIds'] ?? []),
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final app = Map<String, dynamic>.from(rootConfig['app'] ?? {});
    updateFields.forEach((k, v) => app[k] = v);
    rootConfig['app'] = app;
    return rootConfig;
  }
}
