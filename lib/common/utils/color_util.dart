import 'dart:collection';

import 'package:flutter/material.dart';

class ColorUtil {
  static HashMap<int, Color> colorMap = HashMap<int, Color>();

  static Color numberToColor(int intColor) {
    // 透明度
    // if(intColor < 0xFF000000){
    //
    // }
    intColor = intColor | 0xFF000000;
    var color = colorMap.putIfAbsent(intColor, () => Color(intColor));
    return color;
  }

  /// 16进制颜色转换 #FFFFFF
  static Color hexToColor(String colorTxt) {
    var replaceText = colorTxt.replaceAll("#", "");
    var colorValue = int.tryParse(replaceText, radix: 16);
    if (colorValue == null) {
      return Colors.white;
    }
    return numberToColor(colorValue);
  }

  static Color fromARGB(int a, int r, int g, int b) {
    var colorValue = (((a & 0xff) << 24) |
            ((r & 0xff) << 16) |
            ((g & 0xff) << 8) |
            ((b & 0xff) << 0)) &
        0xFFFFFFFF;
    return numberToColor(colorValue);
  }

  static Color fromRGB(int r, int g, int b) {
    return fromARGB(255, r, g, b);
  }
}
