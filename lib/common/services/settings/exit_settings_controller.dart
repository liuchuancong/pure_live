import 'package:pure_live/get/get.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class ExitSettingsController extends GetxController {
  final HiveRxBool dontAskExit = HiveRxBool('dontAskExit', false);
  final HiveRxString exitChoose = HiveRxString('exitChoose', '');
  final HiveRxInt autoShutDownTime = HiveRxInt('autoShutDownTime', 120);
  final HiveRxBool enableAutoShutDownTime = HiveRxBool('enableAutoShutDownTime', false);

  final StopWatchTimer _stopWatchTimer = StopWatchTimer(mode: StopWatchMode.countDown);
  StopWatchTimer get stopWatchTimer => _stopWatchTimer;

  @override
  void onInit() {
    super.onInit();
    onInitShutDown();

    debounce(enableAutoShutDownTime, (_) {
      if (enableAutoShutDownTime.v) {
        restartShutdownTimer();
      } else {
        stopShutdownTimer();
      }
    }, time: const Duration(seconds: 1));

    debounce(autoShutDownTime, (_) {
      if (enableAutoShutDownTime.v) {
        restartShutdownTimer();
      }
    }, time: const Duration(seconds: 1));

    _stopWatchTimer.fetchEnded.listen((value) {
      _stopWatchTimer.onStopTimer();
      FlutterExitApp.exitApp();
    });
  }

  void onInitShutDown() {
    if (enableAutoShutDownTime.v) {
      restartShutdownTimer();
    }
  }

  void restartShutdownTimer() {
    _stopWatchTimer.onStopTimer();
    _stopWatchTimer.setPresetMinuteTime(autoShutDownTime.v, add: false);
    _stopWatchTimer.onStartTimer();
  }

  void stopShutdownTimer() {
    _stopWatchTimer.onStopTimer();
  }

  void changeShutDownConfig(int minutes, bool enabled) {
    autoShutDownTime.v = minutes;
    enableAutoShutDownTime.v = enabled;
    if (enabled) {
      restartShutdownTimer();
    } else {
      stopShutdownTimer();
    }
  }

  void enableAutoShutdown() {
    enableAutoShutDownTime.v = true;
    restartShutdownTimer();
  }

  void disableAutoShutdown() {
    enableAutoShutDownTime.v = false;
    stopShutdownTimer();
  }

  void setExitAction(String action) {
    exitChoose.v = action;
  }

  void setDontAskExit(bool value) {
    dontAskExit.v = value;
  }

  Map<String, dynamic> toJson() {
    return {
      'dontAskExit': dontAskExit.v,
      'exitChoose': exitChoose.v,
      'autoShutDownTime': autoShutDownTime.v,
      'enableAutoShutDownTime': enableAutoShutDownTime.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    dontAskExit.v = json['dontAskExit'] ?? false;
    exitChoose.v = json['exitChoose'] ?? '';
    autoShutDownTime.v = json['autoShutDownTime'] ?? 120;
    enableAutoShutDownTime.v = json['enableAutoShutDownTime'] ?? false;
  }
}
