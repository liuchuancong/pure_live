import 'package:pure_live/common/l10n/generated/l10n.dart';

/// 时间处理工具类
final class TimeUtil {
  static String minuteValueToStr(int allMinute) {
    int part = 60;
    var hour = allMinute ~/ part;
    var minute = allMinute % part;
    var str = "";
    if (hour > 0) {
      str = "$str$hour${S.current.hour}";
    }
    if (!(minute == 0 && hour > 0)) {
      str = "$str$minute${S.current.minute}";
    }
    return str;
  }

  static String secondValueToStr(int allSecond) {
    int part = 60;
    var hour = allSecond ~/ part ~/ part;
    var minute = allSecond ~/ part % part;
    var second = allSecond % part;
    var str = "";
    if (hour > 0) {
      str = "$str$hour${S.current.hour}";
    }
    if (minute > 0) {
      str = "$str$minute${S.current.minute}";
    }
    if (!(second == 0 && (hour > 0 || minute > 0))) {
      str = "$str$second${S.current.second}";
    }
    return str;
  }
}
