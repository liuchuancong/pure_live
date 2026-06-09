import 'package:logger/logger.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class LogController extends GetxController {
  static LogController get to => Get.find<LogController>();

  final RxBool storedEnableLog = hiveBool('user_enable_log', false);

  static Function(Level, String)? onPrintLog;

  @override
  Future<void> onInit() async {
    super.onInit();
    await Log.init();
    storedEnableLog.listen((value) {
      Log.updateLogStatus();
    });
  }

  @override
  void onClose() {
    Log.dispose();
    super.onClose();
  }

  bool get enableLog => storedEnableLog.v;
}
