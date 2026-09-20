import 'dart:convert';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/web_dav/webdav_config.dart';
import 'package:pure_live/common/services/utils/backup_migration_util.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:synchronized/synchronized.dart';

class WebDavController extends GetxController {
  static const String _currentConfigKey = 'currentWebDavConfig';
  static const String _configsKey = 'webDavConfigs';

  final Lock _mutationLock = Lock();

  final RxString currentWebDavConfig = hiveString('currentWebDavConfig', '');

  final Rx<List<WebDAVConfig>> webDavConfigs = hiveObject(
    'webDavConfigs',
    <WebDAVConfig>[],
    fromJson: (Map<String, dynamic> json) {
      return List<WebDAVConfig>.from((json['list'] ?? []).map((e) => WebDAVConfig.fromJson(e)));
    },
    toJson: (List<WebDAVConfig> list) {
      return {'list': list.map((e) => e.toJson()).toList()};
    },
  );

  bool isWebDavConfigExist(String name) => webDavConfigs.v.any((e) => e.name == name);

  WebDAVConfig? getWebDavConfigByName(String name) => webDavConfigs.v.firstWhereOrNull((e) => e.name == name);

  bool addWebDavConfig(WebDAVConfig config) {
    if (isWebDavConfigExist(config.name)) return false;
    webDavConfigs.v.add(config);
    webDavConfigs.refresh();
    return true;
  }

  bool removeWebDavConfig(WebDAVConfig config) {
    final result = webDavConfigs.v.remove(config);
    webDavConfigs.refresh();
    return result;
  }

  bool updateWebDavConfig(WebDAVConfig config) {
    final idx = webDavConfigs.v.indexWhere((e) => e.name == config.name);
    if (idx == -1) return false;
    webDavConfigs.v[idx] = config;
    webDavConfigs.refresh();
    return true;
  }

  Future<void> replaceStateDurably({required Iterable<WebDAVConfig> configs, required WebDAVConfig? currentConfig}) {
    final requested = List<WebDAVConfig>.from(configs);
    return _mutationLock.synchronized(() async {
      final beforeConfigs = List<WebDAVConfig>.from(webDavConfigs.v);
      final beforeCurrent = currentWebDavConfig.v;
      final nextConfigs = List<WebDAVConfig>.unmodifiable(requested);
      final selected = currentConfig == null
          ? null
          : nextConfigs.firstWhereOrNull((config) => config.name == currentConfig.name);
      final nextCurrent = selected == null ? '' : jsonEncode(selected.toJson());

      webDavConfigs.v = nextConfigs;
      currentWebDavConfig.v = nextCurrent;
      try {
        await _writeState(configs: nextConfigs, current: nextCurrent);
      } catch (error, stackTrace) {
        webDavConfigs.v = beforeConfigs;
        currentWebDavConfig.v = beforeCurrent;
        try {
          await _writeState(configs: beforeConfigs, current: beforeCurrent);
        } catch (_) {}
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  Future<void> _writeState({required List<WebDAVConfig> configs, required String current}) async {
    await HivePrefUtil.setPrefs({
      _configsKey: jsonEncode({'list': configs.map((config) => config.toJson()).toList(growable: false)}),
      _currentConfigKey: current,
    });
    await HivePrefUtil.flush();
  }

  Map<String, dynamic> toJson() {
    return {
      'currentWebDavConfig': currentWebDavConfig.v,
      'webDavConfigs': webDavConfigs.v.map((e) => e.toJson()).toList(),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    currentWebDavConfig.v = parsed['currentWebDavConfig'];
    webDavConfigs.v = parsed['webDavConfigs'];
  }

  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    return {
      'currentWebDavConfig': (json['currentWebDavConfig'] ?? '') as String,
      'webDavConfigs': BackupMigrationUtil.parseObjectList(json['webDavConfigs'], WebDAVConfig.fromJson, strict: true),
    };
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final webdav = rootConfig?['webdav'] as Map<String, dynamic>? ?? {};
    final list = BackupMigrationUtil.parseObjectList(webdav['webDavConfigs'], WebDAVConfig.fromJson);
    return {
      'currentWebDavConfig': webdav['currentWebDavConfig'] ?? '',
      'webDavConfigs': list.map((e) => e.toJson()).toList(),
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final webdav = Map<String, dynamic>.from(rootConfig['webdav'] ?? {});
    updateFields.forEach((k, v) => webdav[k] = v);
    rootConfig['webdav'] = webdav;
    return rootConfig;
  }
}
