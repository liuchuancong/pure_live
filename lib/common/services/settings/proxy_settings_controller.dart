import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class ProxySettingsController extends GetxController {
  final HiveRx<bool> enableProxy = HiveRx.bool('enableProxy', false);
  final HiveRx<String> proxyHost = HiveRx.string('proxyHost', '');
  final HiveRx<int> proxyPort = HiveRx.int('proxyPort', 1080);

  Map<String, dynamic> toJson() {
    return {'enableProxy': enableProxy.v, 'proxyHost': proxyHost.v, 'proxyPort': proxyPort.v};
  }

  void fromJson(Map<String, dynamic> json) {
    enableProxy.v = json['enableProxy'] ?? false;
    proxyHost.v = json['proxyHost'] ?? '';
    proxyPort.v = json['proxyPort'] ?? 1080;
  }
}
