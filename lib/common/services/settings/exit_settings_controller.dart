import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pure_live/get/get.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class ExitSettingsController extends GetxController {
  static const String exitAction = 'exit';
  static const String minimizeAction = 'minimize';
  static const Set<String> supportedExitActions = {exitAction, minimizeAction};
  static const int defaultAutoShutdownMinutes = 120;
  static const int minAutoShutdownMinutes = 1;
  static const int maxAutoShutdownMinutes = 525600;

  static int normalizeAutoShutdownMinutes(int minutes) => minutes.clamp(minAutoShutdownMinutes, maxAutoShutdownMinutes);

  static String normalizeExitAction(Object? action) {
    return action is String && supportedExitActions.contains(action) ? action : exitAction;
  }

  final RxBool dontAskExit = hiveBool('dontAskExit', false);
  final RxString exitChoose = hiveString('exitChoose', exitAction);
  final RxInt autoShutDownTime = hiveInt('autoShutDownTime', defaultAutoShutdownMinutes);
  final RxBool enableAutoShutDownTime = hiveBool('enableAutoShutDownTime', false);

  final StopWatchTimer _stopWatchTimer = StopWatchTimer(mode: StopWatchMode.countDown);
  StopWatchTimer get stopWatchTimer => _stopWatchTimer;
  final List<Worker> _workers = <Worker>[];
  StreamSubscription<dynamic>? _timerEndedSubscription;
  bool? _appliedTimerEnabled;
  int? _appliedTimerMinutes;
  int _timerRestartCount = 0;

  @visibleForTesting
  int get timerRestartCount => _timerRestartCount;

  @override
  void onInit() {
    super.onInit();

    final normalizedExitAction = normalizeExitAction(exitChoose.v);
    if (normalizedExitAction != exitChoose.v) {
      exitChoose.v = normalizedExitAction;
    }

    final normalizedMinutes = normalizeAutoShutdownMinutes(autoShutDownTime.v);
    if (normalizedMinutes != autoShutDownTime.v) {
      autoShutDownTime.v = normalizedMinutes;
    }

    _workers.add(
      debounce(enableAutoShutDownTime, (_) {
        if (enableAutoShutDownTime.v) {
          restartShutdownTimer();
        } else {
          stopShutdownTimer();
        }
      }, time: const Duration(milliseconds: 500)),
    );

    _workers.add(
      debounce(autoShutDownTime, (_) {
        if (enableAutoShutDownTime.v) {
          restartShutdownTimer();
        }
      }, time: const Duration(milliseconds: 500)),
    );

    _timerEndedSubscription = _stopWatchTimer.fetchEnded.listen((value) {
      _stopWatchTimer.onStopTimer();
      FlutterExitApp.exitApp();
    });

    onInitShutDown();
  }

  void onInitShutDown() {
    if (enableAutoShutDownTime.v && !_stopWatchTimer.isRunning) {
      restartShutdownTimer(force: true);
    }
  }

  void updateShutDownTime(int minutes) {
    autoShutDownTime.v = normalizeAutoShutdownMinutes(minutes);
    autoShutDownTime.refresh();
    if (enableAutoShutDownTime.v) {
      restartShutdownTimer(force: true);
    }
  }

  void restartShutdownTimer({bool force = false}) {
    final normalizedMinutes = normalizeAutoShutdownMinutes(autoShutDownTime.v);
    if (normalizedMinutes != autoShutDownTime.v) {
      autoShutDownTime.v = normalizedMinutes;
    }
    if (!force &&
        _appliedTimerEnabled == true &&
        _appliedTimerMinutes == normalizedMinutes &&
        _stopWatchTimer.isRunning) {
      return;
    }
    _appliedTimerEnabled = true;
    _appliedTimerMinutes = normalizedMinutes;
    _timerRestartCount++;
    _stopWatchTimer.onStopTimer();
    _stopWatchTimer.onResetTimer();
    _stopWatchTimer.setPresetMinuteTime(normalizedMinutes, add: false);
    _stopWatchTimer.onStartTimer();
  }

  void stopShutdownTimer() {
    if (_appliedTimerEnabled == false && !_stopWatchTimer.isRunning) return;
    _appliedTimerEnabled = false;
    _appliedTimerMinutes = normalizeAutoShutdownMinutes(autoShutDownTime.v);
    _stopWatchTimer.onStopTimer();
    _stopWatchTimer.onResetTimer();
  }

  void changeShutDownConfig(int minutes, bool enabled) {
    autoShutDownTime.v = normalizeAutoShutdownMinutes(minutes);
    enableAutoShutDownTime.v = enabled;
    if (enabled) {
      restartShutdownTimer(force: true);
    } else {
      stopShutdownTimer();
    }
  }

  void enableAutoShutdown() {
    enableAutoShutDownTime.v = true;
    restartShutdownTimer(force: true);
  }

  void disableAutoShutdown() {
    enableAutoShutDownTime.v = false;
    stopShutdownTimer();
  }

  void setExitAction(String action) {
    exitChoose.v = normalizeExitAction(action);
  }

  void setDontAskExit(bool value) {
    dontAskExit.v = value;
  }

  Map<String, dynamic> toJson() {
    return {
      'dontAskExit': dontAskExit.v,
      'exitChoose': normalizeExitAction(exitChoose.v),
      'autoShutDownTime': normalizeAutoShutdownMinutes(autoShutDownTime.v),
      'enableAutoShutDownTime': enableAutoShutDownTime.v,
    };
  }

  /// Parse the complete section without notifying observers or persisting values.
  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    return {
      'dontAskExit': (json['dontAskExit'] ?? false) as bool,
      'exitChoose': normalizeExitAction(json['exitChoose']),
      'autoShutDownTime': normalizeAutoShutdownMinutes((json['autoShutDownTime'] ?? defaultAutoShutdownMinutes) as int),
      'enableAutoShutDownTime': (json['enableAutoShutDownTime'] ?? false) as bool,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    dontAskExit.v = parsed['dontAskExit'];
    exitChoose.v = parsed['exitChoose'];
    autoShutDownTime.v = parsed['autoShutDownTime'];
    enableAutoShutDownTime.v = parsed['enableAutoShutDownTime'];
  }

  @override
  void onClose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    _workers.clear();
    unawaited(_timerEndedSubscription?.cancel());
    _timerEndedSubscription = null;
    _stopWatchTimer.dispose();
    super.onClose();
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final exit = rootConfig?['exit'] as Map<String, dynamic>? ?? {};
    return {
      'dontAskExit': exit['dontAskExit'] ?? false,
      'exitChoose': normalizeExitAction(exit['exitChoose']),
      'autoShutDownTime': normalizeAutoShutdownMinutes((exit['autoShutDownTime'] ?? defaultAutoShutdownMinutes) as int),
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
