import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';

class AppSettingsController extends GetxController {
  static const int maxSleepMinutes = 525600;
  static const List<String> defaultRealOnlinePlatforms = [
    Sites.douyinSite,
    Sites.kuaishouSite,
    Sites.ccSite,
    Sites.twitchSite,
    Sites.soopSite,
    Sites.acfunSite,
    Sites.picartoSite,
    Sites.twitcastingSite,
    Sites.openrecSite,
    Sites.ttingSite,
  ];

  Worker? _refreshRateModeWorker;
  Worker? _realOnlinePlatformsWorker;

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
  // These entry points existed before they became configurable upstream.
  // Defaulting missing keys to true keeps upgrades feature-compatible while
  // still allowing users to hide either entry explicitly.
  final RxBool enableMultiView = hiveBool('enableMultiView', true);
  final RxBool enableNewWindowPlay = hiveBool('enableNewWindowPlay', true);

  AppRefreshRateMode get refreshRateMode => AppRefreshRateMode.parse(refreshRateModeName.v);

  void setRefreshRateMode(AppRefreshRateMode mode) {
    refreshRateModeName.v = mode.storageValue;
  }

  late final RxList<String> savedMenuIds = hiveStringList('savedMenuIds', HomeMenu.values.map((e) => e.id).toList());

  @override
  void onInit() {
    super.onInit();
    final normalizedMenus = normalizeMenuIds(savedMenuIds.v);
    if (!listEquals(savedMenuIds.v, normalizedMenus)) savedMenuIds.v = normalizedMenus;
    if (audienceMetricMigration.v < 1) {
      if (!realOnlinePlatforms.contains('twitch')) realOnlinePlatforms.add('twitch');
      audienceMetricMigration.v = 1;
    }
    if (audienceMetricMigration.v < 2) {
      if (!realOnlinePlatforms.contains('soop')) realOnlinePlatforms.add('soop');
      audienceMetricMigration.v = 2;
    }
    if (audienceMetricMigration.v < 3) {
      if (!realOnlinePlatforms.contains(Sites.acfunSite)) realOnlinePlatforms.add(Sites.acfunSite);
      audienceMetricMigration.v = 3;
    }
    if (audienceMetricMigration.v < 4) {
      if (!realOnlinePlatforms.contains(Sites.picartoSite)) realOnlinePlatforms.add(Sites.picartoSite);
      audienceMetricMigration.v = 4;
    }
    if (audienceMetricMigration.v < 5) {
      if (!realOnlinePlatforms.contains(Sites.twitcastingSite)) realOnlinePlatforms.add(Sites.twitcastingSite);
      audienceMetricMigration.v = 5;
    }
    if (audienceMetricMigration.v < 6) {
      if (!realOnlinePlatforms.contains(Sites.openrecSite)) realOnlinePlatforms.add(Sites.openrecSite);
      audienceMetricMigration.v = 6;
    }
    if (audienceMetricMigration.v < 7) {
      if (!realOnlinePlatforms.contains(Sites.ttingSite)) realOnlinePlatforms.add(Sites.ttingSite);
      audienceMetricMigration.v = 7;
    }
    _repairRealOnlinePlatforms();
    _realOnlinePlatformsWorker = ever<List<String>>(realOnlinePlatforms, (_) => _repairRealOnlinePlatforms());
    if (Platform.isAndroid || Platform.isWindows) {
      // Persist the migrated value once so later upgrades no longer depend on
      // the legacy boolean. Existing `true` maps to balanced; a fresh install
      // starts in power-saving mode.
      if (!HivePrefUtil.containsKey('refreshRateMode')) {
        unawaited(HivePrefUtil.setString('refreshRateMode', refreshRateMode.storageValue));
      }
    }
    if (Platform.isAndroid) {
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

  List<String> get resolvedRealOnlinePlatforms => normalizeRealOnlinePlatforms(realOnlinePlatforms);

  void _repairRealOnlinePlatforms() {
    final normalized = resolvedRealOnlinePlatforms;
    if (!listEquals(realOnlinePlatforms, normalized)) {
      realOnlinePlatforms.v = normalized;
    }
  }

  static List<String> normalizeRealOnlinePlatforms(Iterable<String> platforms) {
    return platforms
        .map((platform) => platform.trim().toLowerCase())
        .where((platform) => LiveRoom.audienceCapabilityFor(platform).supportsConcurrentOnline)
        .toSet()
        .toList();
  }

  static List<String> normalizeMenuIds(Iterable<String> menuIds) {
    final supported = HomeMenu.values.map((menu) => menu.id).toSet();
    final normalized = <String>[];
    for (final rawId in menuIds) {
      final id = rawId.trim().toLowerCase();
      if (supported.contains(id) && !normalized.contains(id)) normalized.add(id);
    }
    return normalized.isEmpty ? [HomeMenu.favorites.id] : normalized;
  }

  @override
  void onClose() {
    _refreshRateModeWorker?.dispose();
    _refreshRateModeWorker = null;
    _realOnlinePlatformsWorker?.dispose();
    _realOnlinePlatformsWorker = null;
    super.onClose();
  }

  void toggleMenuVisibility(HomeMenu menu, bool visible) {
    final current = normalizeMenuIds(savedMenuIds.v);
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

  bool isRealOnlineEnabledFor(String? platform) => resolvedRealOnlinePlatforms.contains(platform?.trim().toLowerCase());

  void setRealOnlineEnabledFor(String platform, bool enabled) {
    final normalized = platform.trim().toLowerCase();
    if (!LiveRoom.audienceCapabilityFor(normalized).supportsConcurrentOnline) return;
    final next = resolvedRealOnlinePlatforms;
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
      'enableHighRefreshRate': refreshRateMode != AppRefreshRateMode.powerSaving,
      'preferRealOnlineCounts': preferRealOnlineCounts.v,
      'realOnlinePlatforms': resolvedRealOnlinePlatforms,
      'savedMenuIds': savedMenuIds.v,
      'enableMultiView': enableMultiView.v,
      'enableNewWindowPlay': enableNewWindowPlay.v,
    };
  }

  /// Parse the complete section without notifying observers or persisting values.
  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    T typed<T>(dynamic value) => value as T;
    return {
      'refreshRateMode': refreshRateModeFromConfig(json),
      'autoRefreshTime': typed<int>(json['autoRefreshTime'] ?? 3),
      'enableDenseFavorites': typed<bool>(json['enableDenseFavorites'] ?? true),
      'enableBackgroundPlay': typed<bool>(json['enableBackgroundPlay'] ?? false),
      'enableAsmrSleepMode': typed<bool>(json['enableAsmrSleepMode'] ?? false),
      'asmrSleepMinutes': typed<int>(
        (((json['asmrSleepMinutes'] as num?)?.toInt() ?? 60).clamp(1, maxSleepMinutes)).toInt(),
      ),
      'enableRotateScreen': typed<bool>(json['enableRotateScreen'] ?? false),
      'enableScreenKeepOn': typed<bool>(json['enableScreenKeepOn'] ?? true),
      'enableAutoCheckUpdate': typed<bool>(json['enableAutoCheckUpdate'] ?? true),
      'useGitHubOriginForUpdates': typed<bool>(json['useGitHubOriginForUpdates'] ?? false),
      'enableFullScreenDefault': typed<bool>(json['enableFullScreenDefault'] ?? false),
      'showSplashPage': typed<bool>(json['showSplashPage'] ?? true),
      'preferRealOnlineCounts': typed<bool>(json['preferRealOnlineCounts'] ?? false),
      'realOnlinePlatforms': typed<List<String>>(
        normalizeRealOnlinePlatforms(List<String>.from(json['realOnlinePlatforms'] ?? defaultRealOnlinePlatforms)),
      ),
      'savedMenuIds': typed<List<String>>(
        normalizeMenuIds(List<String>.from(json['savedMenuIds'] ?? HomeMenu.values.map((e) => e.id).toList())),
      ),
      'enableMultiView': typed<bool>(json['enableMultiView'] ?? true),
      'enableNewWindowPlay': typed<bool>(json['enableNewWindowPlay'] ?? true),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    autoRefreshTime.v = parsed['autoRefreshTime'];
    enableDenseFavorites.v = parsed['enableDenseFavorites'];
    enableBackgroundPlay.v = parsed['enableBackgroundPlay'];
    enableAsmrSleepMode.v = parsed['enableAsmrSleepMode'];
    asmrSleepMinutes.v = parsed['asmrSleepMinutes'];
    enableRotateScreen.v = parsed['enableRotateScreen'];
    enableScreenKeepOn.v = parsed['enableScreenKeepOn'];
    enableAutoCheckUpdate.v = parsed['enableAutoCheckUpdate'];
    useGitHubOriginForUpdates.v = parsed['useGitHubOriginForUpdates'];
    enableFullScreenDefault.v = parsed['enableFullScreenDefault'];
    showSplashPage.v = parsed['showSplashPage'];
    setRefreshRateMode(parsed['refreshRateMode']);
    preferRealOnlineCounts.v = parsed['preferRealOnlineCounts'];
    realOnlinePlatforms.v = parsed['realOnlinePlatforms'];
    _repairRealOnlinePlatforms();
    savedMenuIds.v = parsed['savedMenuIds'];
    enableMultiView.v = parsed['enableMultiView'];
    enableNewWindowPlay.v = parsed['enableNewWindowPlay'];
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
      'savedMenuIds': normalizeMenuIds(
        List<String>.from(app['savedMenuIds'] ?? HomeMenu.values.map((menu) => menu.id).toList()),
      ),
      'enableMultiView': app['enableMultiView'] ?? true,
      'enableNewWindowPlay': app['enableNewWindowPlay'] ?? true,
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final app = Map<String, dynamic>.from(rootConfig['app'] ?? {});
    updateFields.forEach((k, v) => app[k] = v);
    rootConfig['app'] = app;
    return rootConfig;
  }
}
