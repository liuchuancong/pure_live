// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

final class BetterPlayerUtils {
  const BetterPlayerUtils._();

  static String formatBitrate(int bitrate) {
    if (bitrate < 1000) {
      return '$bitrate bit/s';
    }
    if (bitrate < 1000000) {
      final kbit = (bitrate / 1000).floor();
      return '~$kbit KBit/s';
    }
    final mbit = (bitrate / 1000000).floor();
    return '~$mbit MBit/s';
  }

  static String formatDuration(Duration position) {
    final ms = position.inMilliseconds;

    int seconds = ms ~/ 1000;
    final int hours = seconds ~/ 3600;
    seconds = seconds % 3600;
    final minutes = seconds ~/ 60;
    seconds = seconds % 60;

    final hoursString = hours >= 10
        ? '$hours'
        : hours == 0
        ? '00'
        : '0$hours';

    final minutesString = minutes >= 10
        ? '$minutes'
        : minutes == 0
        ? '00'
        : '0$minutes';

    final secondsString = seconds >= 10
        ? '$seconds'
        : seconds == 0
        ? '00'
        : '0$seconds';

    final formattedTime = '${hoursString == '00' ? '' : '$hoursString:'}$minutesString:$secondsString';

    return formattedTime;
  }

  static double calculateAspectRatio(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    return width > height ? width / height : height / width;
  }

  static void log(String logMessage) {
    if (!kReleaseMode) {
      // dart:developer log is not always captured in release; print is intentional here
      // ignore: avoid_print
      print(logMessage);
    }
  }
}
