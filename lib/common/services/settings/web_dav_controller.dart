import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/modules/web_dav/webdav_config.dart';

class WebDavController extends GetxController {
  final currentWebDavConfig = HiveRx.string('currentWebDavConfig', '');

  final webDavConfigs = HiveRx.object(
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
    webDavConfigs.rx.refresh();
    return true;
  }

  bool removeWebDavConfig(WebDAVConfig config) {
    final result = webDavConfigs.v.remove(config);
    webDavConfigs.rx.refresh();
    return result;
  }

  bool updateWebDavConfig(WebDAVConfig config) {
    final idx = webDavConfigs.v.indexWhere((e) => e.name == config.name);
    if (idx == -1) return false;
    webDavConfigs.v[idx] = config;
    webDavConfigs.rx.refresh();
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

    if (json['webDavConfigs'] != null) {
      webDavConfigs.v = List<WebDAVConfig>.from(
        (json['webDavConfigs'] as List).map((e) => WebDAVConfig.fromJson(Map<String, dynamic>.from(e))),
      );
    }
  }
}
