import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/http_client.dart';

class ProxySettingsController extends GetxController {
  final RxBool enableProxy = hiveBool('enableProxy', false);
  final RxString proxyHost = hiveString('proxyHost', '');
  final RxInt proxyPort = hiveInt('proxyPort', 7897);

  // app proxy settings
  final RxBool enableAppProxy = hiveBool('enableAppProxy', false);
  final RxString appProxyHost = hiveString('appProxyHost', '');
  final RxInt appProxyPort = hiveInt('appProxyPort', 7897);
  @override
  void onInit() {
    super.onInit();

    ever<bool>(enableAppProxy, (_) => _refreshDioConnections());
    ever<String>(appProxyHost, (_) => _refreshDioConnections());
    ever<int>(appProxyPort, (_) => _refreshDioConnections());
  }

  void _refreshDioConnections() {
    try {
      HttpClient.instance.rebuildDio();
    } catch (_) {}
  }

  Map<String, dynamic> toJson() {
    return {
      'enableProxy': enableProxy.v,
      'proxyHost': proxyHost.v,
      'proxyPort': proxyPort.v,
      'enableAppProxy': enableAppProxy.v,
      'appProxyHost': appProxyHost.v,
      'appProxyPort': appProxyPort.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    enableProxy.v = json['enableProxy'] ?? false;
    proxyHost.v = json['proxyHost'] ?? '';
    proxyPort.v = json['proxyPort'] ?? 1080;
    enableAppProxy.v = json['enableAppProxy'] ?? false;
    appProxyHost.v = json['appProxyHost'] ?? '';
    appProxyPort.v = json['appProxyPort'] ?? 1080;
  }
}
