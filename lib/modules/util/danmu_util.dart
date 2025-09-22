import 'dart:math';

import 'package:flutter/material.dart';

final class DanmuUtil {
  static int toNum(String level) {
    int num = 0;
    try {
      num = int.parse(level);
    } catch (e) {
      num = 0;
    }
    return num;
  }

  /// 用户等级对应颜色
  static Color getUserLevelColor(String level) {
    var num = toNum(level);
    if (num <= 0) {
      return Colors.grey;
    }

    /// 阶层
    int part = 15;
    var classLevel = (num + part - 1) ~/ part;
    var colorList = [
      Color.fromARGB(255, 219, 188, 142),
      Color.fromARGB(255, 133, 213, 136),
      Color.fromARGB(255, 80, 160, 235),
      Color.fromARGB(255, 104, 128, 248),
      Color.fromARGB(255, 182, 85, 243),
      Color.fromARGB(255, 213, 72, 236),
      Color.fromARGB(255, 255, 41, 152),
      Color.fromARGB(255, 255, 67, 66),
      Color.fromARGB(255, 255, 67, 66),
      Color.fromARGB(255, 251, 71, 13),
      Color.fromARGB(255, 241, 23, 81),
    ];
    var index = min(classLevel - 1, colorList.length - 1);
    return colorList[index];
  }

  /// 粉丝等级对应颜色
  static Color getFansLevelColor(String level) {
    var num = toNum(level);
    if (num <= 0) {
      return Colors.grey;
    }

    int part = 5;
    var classLevel = (num + part - 1) ~/ part;
    var colorList = [
      Color.fromARGB(255, 29, 66, 89),
      Color.fromARGB(255, 48, 103, 119),
      Color.fromARGB(255, 163, 155, 51),
      Color.fromARGB(255, 137, 92, 38),
      Color.fromARGB(255, 115, 22, 18),
      Color.fromARGB(255, 46, 15, 65),
    ];
    var index = min(classLevel - 1, colorList.length - 1);
    return colorList[index];
  }
}
