import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class ProxySettingsController extends GetxController {
  final enableProxy = HiveRx.bool('enableProxy', false);
  final proxyHost = HiveRx.string('proxyHost', '');
  final proxyPort = HiveRx.int('proxyPort', 1080);
}
