import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/web_dav/webdav_config.dart';
import 'package:pure_live/common/services/utils/backup_migration_util.dart';

class WebDavController extends GetxController {
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

  Map<String, dynamic> toJson() {
    return {
      'currentWebDavConfig': currentWebDavConfig.v,
      'webDavConfigs': webDavConfigs.v.map((e) => e.toJson()).toList(),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    currentWebDavConfig.v = json['currentWebDavConfig'] ?? '';
    webDavConfigs.v = BackupMigrationUtil.parseObjectList(json['webDavConfigs'], (m) => WebDAVConfig.fromJson(m));
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
