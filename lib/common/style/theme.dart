import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pure_live/common/global/platform_utils.dart';

class MyTheme {
  final Color? primaryColor;
  final ColorScheme? colorScheme;

  MyTheme({this.primaryColor, this.colorScheme})
    : assert(colorScheme == null || primaryColor == null, 'colorScheme 和 primaryColor 不能同时提供');

  String? get _platformFontFamily {
    if (PlatformUtils.isWindows) return 'PingFang';
    if (PlatformUtils.isAndroid) return GoogleFonts.roboto().fontFamily;
    return null;
  }

  ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final String? fontFamily = _platformFontFamily;

    ColorScheme? effectiveColorScheme = colorScheme;
    if (isDark && effectiveColorScheme != null) {
      effectiveColorScheme = effectiveColorScheme.copyWith(error: const Color(0xFFFF6347));
    }

    // 1. Create a typography base matched to the targeted font configuration
    final TextTheme baseTextTheme = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;

    final TextTheme localizedTextTheme = fontFamily != null
        ? baseTextTheme.apply(fontFamily: fontFamily)
        : baseTextTheme;

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily, // 2. Hard-lock root typography scoping for internal elements
      colorSchemeSeed: primaryColor,
      colorScheme: effectiveColorScheme,
      textTheme: localizedTextTheme,
      primaryTextTheme: localizedTextTheme,
    );

    return baseTheme.copyWith(
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarTheme(
        scrolledUnderElevation: 0.0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: localizedTextTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: localizedTextTheme.titleMedium,
        unselectedLabelStyle: localizedTextTheme.bodyMedium,
      ),
    );
  }

  ThemeData get lightThemeData => _buildTheme(Brightness.light);

  ThemeData get darkThemeData => _buildTheme(Brightness.dark);
}
