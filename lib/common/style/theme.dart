import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pure_live/common/global/platform_utils.dart';

class MyTheme {
  final Color? primaryColor;
  final ColorScheme? colorScheme;

  MyTheme({this.primaryColor, this.colorScheme})
    : assert(colorScheme == null || primaryColor == null, 'colorScheme 和 primaryColor 不能同时提供');

  /// 获取当前平台的默认字体
  String? get _platformFontFamily {
    if (PlatformUtils.isWindows) return 'PingFang';
    if (PlatformUtils.isAndroid) return GoogleFonts.roboto().fontFamily;
    return null;
  }

  /// 提取通用的组件主题配置 (Flutter 3.38+ 推荐)
  ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final String? fontFamily = _platformFontFamily;
    // 处理暗色模式下的特殊颜色修正
    ColorScheme? effectiveColorScheme = colorScheme;
    if (isDark && effectiveColorScheme != null) {
      effectiveColorScheme = effectiveColorScheme.copyWith(
        error: const Color(0xFFFF6347), // Tomato color
      );
    }
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: primaryColor,
      colorScheme: colorScheme,
    );

    return baseTheme.copyWith(
      brightness: brightness,
      colorScheme: effectiveColorScheme,
      textTheme: fontFamily != null ? baseTheme.textTheme.apply(fontFamily: fontFamily) : baseTheme.textTheme,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: const AppBarTheme(
        scrolledUnderElevation: 0.0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      tabBarTheme: const TabBarThemeData(dividerColor: Colors.transparent, indicatorSize: TabBarIndicatorSize.label),
    );
  }

  ThemeData get lightThemeData => _buildTheme(Brightness.light);

  ThemeData get darkThemeData => _buildTheme(Brightness.dark);
}
