import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

class TimerController extends GetxController {
  TimerController({required this.onEnded});

  final FutureOr<void> Function() onEnded;
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
      unawaited(Future.sync(onEnded));
    });
  }

  void toggleTimer(bool enabled, int minutes) {
    if (enabled) {
      _stopWatchTimer.onStopTimer();
      _stopWatchTimer.onResetTimer();
      _stopWatchTimer.setPresetMinuteTime(minutes.clamp(1, 525600).toInt(), add: false);
      _stopWatchTimer.onStartTimer();
    } else {
      _stopWatchTimer.onStopTimer();
      _stopWatchTimer.onResetTimer();
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
