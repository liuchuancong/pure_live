import 'dart:developer' as dev;
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/global/win_auto_start.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class StartupController extends GetxController {
  final RxBool enableStartUp = hiveBool('enableStartUp', true);

  @override
  void onInit() {
    super.onInit();
    ever<bool>(enableStartUp, (_) => setupLaunchAtStartup());
  }

  Future<void> setupLaunchAtStartup() async {
    try {
      final isEnabled = WindowsAutoStart.isEnabled();

      if (enableStartUp.v && !isEnabled) {
        final result = WindowsAutoStart.enable();
        dev.log("Enable startup result: $result");
      } else if (!enableStartUp.v && isEnabled) {
        final result = WindowsAutoStart.disable();
        dev.log("Disable startup result: $result");
      }
    } catch (e) {
      dev.log("Auto-start error: $e");
    }
  }

  void enableStartup() {
    enableStartUp.v = true;
  }

  void disableStartup() {
    enableStartUp.v = false;
  }

  void toggleStartup() {
    enableStartUp.v = !enableStartUp.v;
  }

  Map<String, dynamic> toJson() {
    return {'enableStartUp': enableStartUp.v};
  }

  void fromJson(Map<String, dynamic> json) {
    enableStartUp.v = json['enableStartUp'] ?? true;
  }
}
