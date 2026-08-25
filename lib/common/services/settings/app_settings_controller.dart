import 'dart:io';
import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';

class AppSettingsController extends GetxController {
  static const int maxSleepMinutes = 525600;
  static const List<String> defaultRealOnlinePlatforms = ['douyin', 'kuaishou', 'cc', 'twitch', 'soop'];

  Worker? _refreshRateModeWorker;

  static AppRefreshRateMode _legacyRefreshRateMode(Object? enabled) {
    return enabled == true ? AppRefreshRateMode.balanced : AppRefreshRateMode.powerSaving;
  }

  static AppRefreshRateMode refreshRateModeFromConfig(Map<String, dynamic> json) {
    if (json.containsKey('refreshRateMode')) {
      return AppRefreshRateMode.parse(json['refreshRateMode']);
    }
    return _legacyRefreshRateMode(json['enableHighRefreshRate']);
  }

  static String _initialRefreshRateMode() {
    final stored = HivePrefUtil.getString('refreshRateMode');
    if (stored != null) return AppRefreshRateMode.parse(stored).storageValue;
    return _legacyRefreshRateMode(HivePrefUtil.getBool('enableHighRefreshRate')).storageValue;
  }

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
  late final RxString refreshRateModeName = hiveString('refreshRateMode', _initialRefreshRateMode());
  final RxBool preferRealOnlineCounts = hiveBool('preferRealOnlineCounts', false);
  late final RxList<String> realOnlinePlatforms = hiveStringList('realOnlinePlatforms', defaultRealOnlinePlatforms);
  final RxInt audienceMetricMigration = hiveInt('audienceMetricMigration', 0);

  AppRefreshRateMode get refreshRateMode => AppRefreshRateMode.parse(refreshRateModeName.v);

  void setRefreshRateMode(AppRefreshRateMode mode) {
    refreshRateModeName.v = mode.storageValue;
  }

  late final RxList<String> savedMenuIds = hiveStringList('savedMenuIds', HomeMenu.values.map((e) => e.id).toList());

  @override
  void onInit() {
    super.onInit();
    if (audienceMetricMigration.v < 1) {
      if (!realOnlinePlatforms.contains('twitch')) realOnlinePlatforms.add('twitch');
      audienceMetricMigration.v = 1;
    }
    if (audienceMetricMigration.v < 2) {
      if (!realOnlinePlatforms.contains('soop')) realOnlinePlatforms.add('soop');
      audienceMetricMigration.v = 2;
    }
    _removeUnsupportedOnlinePlatforms();
    if (Platform.isAndroid) {
      // Persist the migrated value once so later upgrades no longer depend on
      // the legacy boolean. Existing `true` maps to balanced; a fresh install
      // starts in power-saving mode.
      if (!HivePrefUtil.containsKey('refreshRateMode')) {
        unawaited(HivePrefUtil.setString('refreshRateMode', refreshRateMode.storageValue));
      }
      AdaptiveRefreshRateController.setMode(refreshRateMode);
      _refreshRateModeWorker = ever<String>(
        refreshRateModeName,
        (value) => AdaptiveRefreshRateController.setMode(AppRefreshRateMode.parse(value)),
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
        .map((platform) => platform.trim().toLowerCase())
        .where((platform) => LiveRoom.audienceCapabilityFor(platform).supportsConcurrentOnline)
        .toSet()
        .toList();
  }

  @override
  void onClose() {
    _refreshRateModeWorker?.dispose();
    _refreshRateModeWorker = null;
    super.onClose();
  }

  void toggleMenuVisibility(HomeMenu menu, bool visible) {
    final current = List<String>.from(savedMenuIds.v);
    if (visible) {
      if (!current.contains(menu.id)) current.add(menu.id);
    } else {
      if (current.length <= 1 && current.contains(menu.id)) {
        return;
      }
      current.removeWhere((id) => id == menu.id);
    }
    savedMenuIds.v = current;
  }

  bool isRealOnlineEnabledFor(String? platform) => realOnlinePlatforms.contains(platform?.trim().toLowerCase());

  void setRealOnlineEnabledFor(String platform, bool enabled) {
    final normalized = platform.trim().toLowerCase();
    if (!LiveRoom.audienceCapabilityFor(normalized).supportsConcurrentOnline) return;
    final next = List<String>.from(realOnlinePlatforms);
    if (enabled) {
      if (!next.contains(normalized)) next.add(normalized);
    } else {
      next.remove(normalized);
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
      'refreshRateMode': refreshRateMode.storageValue,
      // Kept for restoring this backup into older Pure Live builds.
      'enableHighRefreshRate': refreshRateMode != AppRefreshRateMode.powerSaving,
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
    setRefreshRateMode(refreshRateModeFromConfig(json));
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
      'refreshRateMode': refreshRateModeFromConfig(app).storageValue,
      'enableHighRefreshRate': refreshRateModeFromConfig(app) != AppRefreshRateMode.powerSaving,
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
