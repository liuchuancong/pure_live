import 'package:pure_live/common/index.dart';

class ProxySettingsController extends GetxController {
  final RxBool enableProxy = hiveBool('enableProxy', false);
  final RxString proxyHost = hiveString('proxyHost', '');
  final RxInt proxyPort = hiveInt('proxyPort', 1080);

  Map<String, dynamic> toJson() {
    return {'enableProxy': enableProxy.v, 'proxyHost': proxyHost.v, 'proxyPort': proxyPort.v};
  }

  void fromJson(Map<String, dynamic> json) {
    enableProxy.v = json['enableProxy'] ?? false;
    proxyHost.v = json['proxyHost'] ?? '';
    proxyPort.v = json['proxyPort'] ?? 1080;
  }
}
