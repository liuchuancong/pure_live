import 'package:logger/logger.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class LogController extends GetxController {
  static LogController get to => Get.find<LogController>();
  final RxString serverAddress = hiveString('user_log_address', '');
  final RxInt serverPort = hiveInt('user_log_port', 0);

  final RxBool storedEnableLog = false.obs;

  static Function(Level, String)? onPrintLog;

  @override
  Future<void> onInit() async {
    super.onInit();

    storedEnableLog.listen((value) {
      Log.updateLogStatus();
    });
  }

  @override
  void onClose() {
    Log.dispose();
    super.onClose();
  }

  void updateServerInfo(String address, int port) {
    serverAddress.value = address;
    serverPort.value = port;
  }

  bool get enableLog => storedEnableLog.v;

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final refresh = rootConfig?['refresh'] as Map<String, dynamic>? ?? {};
    return {
      'serverAddress': refresh['serverAddress'] ?? '',
      'serverPort': refresh['serverPort'] ?? 0,
      'storedEnableLog': refresh['storedEnableLog'] ?? false,
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final refresh = Map<String, dynamic>.from(rootConfig['refresh'] ?? {});
    updateFields.forEach((k, v) => refresh[k] = v);
    rootConfig['refresh'] = refresh;
    return rootConfig;
  }
}
