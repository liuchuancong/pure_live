import 'dart:math';

import 'package:flutter/material.dart';

class ThemeUtils {
  ThemeUtils._();

  static const Color lightBg = Color(0xffededed);
  static const Color darkBg = Color(0xff191919);

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static bool isLight(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light;
  }

  static T select<T>(BuildContext context, {required T light, required T dark}) {
    return isDark(context) ? dark : light;
  }

  static Color backgroundColor(BuildContext context) {
    return select(context, light: lightBg, dark: darkBg);
  }

  /// 获取主题主色（Primary Color）
  static Color primaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  /// 获取次要颜色（Secondary）
  static Color secondaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.secondary;
  }

  /// 获取文本主色（根据亮/暗模式自动切换）
  static Color textColor(BuildContext context) {
    return Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
  }

  /// 获取错误颜色
  static Color errorColor(BuildContext context) {
    return Theme.of(context).colorScheme.error;
  }

  // 获取与背景色对比的文本颜色
  static Color getContrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  // 计算两个颜色的对比度
  static double getContrastRatio(Color color1, Color color2) {
    final double luminance1 = color1.computeLuminance();
    final double luminance2 = color2.computeLuminance();

    // 对比度计算公式 (L1 + 0.05) / (L2 + 0.05)，其中L是较亮颜色的亮度
    return (max(luminance1, luminance2) + 0.05) / (min(luminance1, luminance2) + 0.05);
  }
}
