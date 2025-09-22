import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/services/setting_mixin/setting_part.dart';
import 'package:pure_live/common/utils/pref_util.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

/// 自动关闭
mixin AutoShutDownMixin {
  /// 自动关闭时间
  static var autoShutDownTimeKey = "autoShutDownTime";
  static var autoShutDownTimeDefault = 120;
  final autoShutDownTime = (PrefUtil.getInt(autoShutDownTimeKey) ?? autoShutDownTimeDefault).obs;

  /// 是否允许自动关闭
  static var enableAutoShutDownTimeKey = "enableAutoShutDownTime";
  static var enableAutoShutDownTimeDefault = false;
  final enableAutoShutDownTime = (PrefUtil.getBool(enableAutoShutDownTimeKey) ?? enableAutoShutDownTimeDefault).obs;

  StopWatchTimer _stopWatchTimer = StopWatchTimer(mode: StopWatchMode.countDown); // Create instance.
  StopWatchTimer get stopWatchTimer => _stopWatchTimer;

  void handleWatchTimer(){
    if (enableAutoShutDownTime.isTrue) {
      _stopWatchTimer.onStopTimer();
      _stopWatchTimer = StopWatchTimer(mode: StopWatchMode.countDown, refreshTime: autoShutDownTime.value * 60);
      _stopWatchTimer.setPresetMinuteTime(autoShutDownTime.value, add: false);
      _stopWatchTimer.onStartTimer();
    } else {
      _stopWatchTimer.onStopTimer();
    }
  }

  void initAutoShutDown(SettingPartList settingPartList) {
    autoShutDownTime.listen((value) {
      PrefUtil.setInt(autoShutDownTimeKey, value);
      handleWatchTimer();
    });

    enableAutoShutDownTime.listen((value) {
      PrefUtil.setBool(enableAutoShutDownTimeKey, value);
      handleWatchTimer();
    });

    _stopWatchTimer.fetchEnded.listen((value) {
      _stopWatchTimer.onStopTimer();
      FlutterExitApp.exitApp();
    });
    handleWatchTimer();
    settingPartList.fromJsonList.add(fromJsonAutoShutDown);
    settingPartList.toJsonList.add(toJsonAutoShutDown);
    settingPartList.defaultConfigList.add(defaultConfigAutoShutDown);
  }

  void onInitShutDown() {
    handleWatchTimer();
  }

  void changeShutDownConfig(int minutes, bool isAutoShutDown) {
    autoShutDownTime.value = minutes;
    enableAutoShutDownTime.value = isAutoShutDown;
    PrefUtil.setInt(autoShutDownTimeKey, minutes);
    PrefUtil.setBool(enableAutoShutDownTimeKey, isAutoShutDown);
    onInitShutDown();
  }

  //// -------------- 默认
  void fromJsonAutoShutDown(Map<String, dynamic> json) {
    autoShutDownTime.value = json[autoShutDownTimeKey] ?? autoShutDownTimeDefault;
    enableAutoShutDownTime.value = json[enableAutoShutDownTimeKey] ?? enableAutoShutDownTimeDefault;
  }

  void toJsonAutoShutDown(Map<String, dynamic> json) {
    json[autoShutDownTimeKey] = autoShutDownTime.value;
    json[enableAutoShutDownTimeKey] = enableAutoShutDownTime.value;
  }

  void defaultConfigAutoShutDown(Map<String, dynamic> json) {
    json[autoShutDownTimeKey] = autoShutDownTimeDefault;
    json[enableAutoShutDownTimeKey] = enableAutoShutDownTimeDefault;
  }
}
