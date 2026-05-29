import 'package:pure_live/get/get.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class ExitSettingsController extends GetxController {
  // =========================
  // Exit Settings
  // =========================

  final dontAskExit = HiveRx.bool('dontAskExit', false);

  final exitChoose = HiveRx.string('exitChoose', '');

  // =========================
  // Auto Shutdown
  // =========================

  final autoShutDownTime = HiveRx.int('autoShutDownTime', 120);

  final enableAutoShutDownTime = HiveRx.bool('enableAutoShutDownTime', false);

  // =========================
  // Timer
  // =========================

  final StopWatchTimer _stopWatchTimer = StopWatchTimer(mode: StopWatchMode.countDown);

  StopWatchTimer get stopWatchTimer => _stopWatchTimer;

  // =========================
  // Lifecycle
  // =========================

  @override
  void onInit() {
    super.onInit();

    // 初始化自动关机
    onInitShutDown();

    // 自动关机开关
    debounce(enableAutoShutDownTime.rx, (_) {
      if (enableAutoShutDownTime.v) {
        restartShutdownTimer();
      } else {
        stopShutdownTimer();
      }
    }, time: const Duration(seconds: 1));

    // 自动关机时间
    debounce(autoShutDownTime.rx, (_) {
      if (enableAutoShutDownTime.v) {
        restartShutdownTimer();
      }
    }, time: const Duration(seconds: 1));

    // 倒计时结束
    _stopWatchTimer.fetchEnded.listen((value) {
      _stopWatchTimer.onStopTimer();

      FlutterExitApp.exitApp();
    });
  }

  // =========================
  // Init
  // =========================

  void onInitShutDown() {
    if (enableAutoShutDownTime.v) {
      restartShutdownTimer();
    }
  }

  // =========================
  // Timer Control
  // =========================

  void restartShutdownTimer() {
    _stopWatchTimer.onStopTimer();

    _stopWatchTimer.setPresetMinuteTime(autoShutDownTime.v, add: false);

    _stopWatchTimer.onStartTimer();
  }

  void stopShutdownTimer() {
    _stopWatchTimer.onStopTimer();
  }

  // =========================
  // Public Methods
  // =========================

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
}
