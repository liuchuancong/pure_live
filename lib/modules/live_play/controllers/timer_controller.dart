import 'dart:io';
import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

class TimerController extends GetxController {
  final StopWatchTimer _stopWatchTimer = StopWatchTimer(mode: StopWatchMode.countDown);
  StreamSubscription<dynamic>? _timerEndedSubscription;

  @override
  void onInit() {
    super.onInit();
    _initTimer();
  }

  void _initTimer() {
    _timerEndedSubscription = _stopWatchTimer.fetchEnded.listen((_) {
      _stopWatchTimer.onStopTimer();
      exit(0);
    });
  }

  void toggleTimer(bool enabled, int minutes) {
    if (enabled) {
      _stopWatchTimer.onStopTimer();
      _stopWatchTimer.setPresetMinuteTime(minutes, add: false);
      _stopWatchTimer.onStartTimer();
    } else {
      _stopWatchTimer.onStopTimer();
    }
  }

  @override
  void onClose() {
    _timerEndedSubscription?.cancel();
    _stopWatchTimer.onStopTimer();
    _stopWatchTimer.dispose();
    super.onClose();
  }
}
