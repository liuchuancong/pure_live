import 'package:pure_live/get/get.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class ExitSettingsController extends GetxController {
  final RxBool dontAskExit = hiveBool('dontAskExit', false);
  final RxString exitChoose = hiveString('exitChoose', '');
  final RxInt autoShutDownTime = hiveInt('autoShutDownTime', 120);
  final RxBool enableAutoShutDownTime = hiveBool('enableAutoShutDownTime', false);

  final StopWatchTimer _stopWatchTimer = StopWatchTimer(mode: StopWatchMode.countDown);
  StopWatchTimer get stopWatchTimer => _stopWatchTimer;

  @override
  void onInit() {
    super.onInit();

    debounce(enableAutoShutDownTime, (_) {
      if (enableAutoShutDownTime.v) {
        restartShutdownTimer();
      } else {
        stopShutdownTimer();
      }
    }, time: const Duration(milliseconds: 500));

    debounce(autoShutDownTime, (_) {
      if (enableAutoShutDownTime.v) {
        restartShutdownTimer();
      }
    }, time: const Duration(milliseconds: 500));

    _stopWatchTimer.fetchEnded.listen((value) {
      _stopWatchTimer.onStopTimer();
      FlutterExitApp.exitApp();
    });

    onInitShutDown();
  }

  void onInitShutDown() {
    if (enableAutoShutDownTime.v && !_stopWatchTimer.isRunning) {
      _stopWatchTimer.onResetTimer();
      _stopWatchTimer.setPresetMinuteTime(autoShutDownTime.v, add: false);
      _stopWatchTimer.onStartTimer();
    }
  }

  void updateShutDownTime(int minutes) {
    autoShutDownTime.v = minutes;
    autoShutDownTime.refresh();
    if (enableAutoShutDownTime.v) {
      restartShutdownTimer();
    }
  }

  void restartShutdownTimer() {
    _stopWatchTimer.onStopTimer();
    _stopWatchTimer.onResetTimer();
    _stopWatchTimer.setPresetMinuteTime(autoShutDownTime.v, add: false);
    _stopWatchTimer.onStartTimer();
  }

  void stopShutdownTimer() {
    _stopWatchTimer.onStopTimer();
    _stopWatchTimer.onResetTimer();
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

  @override
  void onClose() {
    _stopWatchTimer.dispose();
    super.onClose();
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final exit = rootConfig?['exit'] as Map<String, dynamic>? ?? {};
    return {
      'dontAskExit': exit['dontAskExit'] ?? false,
      'exitChoose': exit['exitChoose'] ?? '',
      'autoShutDownTime': exit['autoShutDownTime'] ?? 120,
      'enableAutoShutDownTime': exit['enableAutoShutDownTime'] ?? false,
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final exit = Map<String, dynamic>.from(rootConfig['exit'] ?? {});
    updateFields.forEach((k, v) => exit[k] = v);
    rootConfig['exit'] = exit;
    return rootConfig;
  }
}
