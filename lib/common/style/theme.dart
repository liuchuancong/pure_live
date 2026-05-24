import 'package:pure_live/common/index.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pure_live/common/global/platform_utils.dart';

class MyTheme {
  final Color? primaryColor;
  final ColorScheme? colorScheme;

  MyTheme({this.primaryColor, this.colorScheme}) : assert(colorScheme == null || primaryColor == null);

  String? get _platformFontFamily {
    if (PlatformUtils.isWindows) return 'PingFang';
    if (PlatformUtils.isAndroid) return GoogleFonts.roboto().fontFamily;
    return null;
  }

  ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final String? fontFamily = _platformFontFamily;
    final settings = Get.find<SettingsService>();

    ColorScheme? effectiveColorScheme = colorScheme;
    if (isDark && effectiveColorScheme != null) {
      effectiveColorScheme = effectiveColorScheme.copyWith(error: const Color(0xFFFF6347));
    }

    final TextTheme baseTextTheme = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;

    final TextTheme localizedTextTheme = fontFamily != null
        ? baseTextTheme.apply(fontFamily: fontFamily)
        : baseTextTheme;

    final TextTheme customGlobalTextTheme = localizedTextTheme.copyWith(
      displayLarge: localizedTextTheme.displayLarge?.copyWith(
        fontSize: (localizedTextTheme.displayLarge?.fontSize ?? 57) / 12.0 * settings.fontSizeBodySmall.value,
      ),
      displayMedium: localizedTextTheme.displayMedium?.copyWith(
        fontSize: (localizedTextTheme.displayMedium?.fontSize ?? 45) / 12.0 * settings.fontSizeBodySmall.value,
      ),
      displaySmall: localizedTextTheme.displaySmall?.copyWith(
        fontSize: (localizedTextTheme.displaySmall?.fontSize ?? 36) / 12.0 * settings.fontSizeBodySmall.value,
      ),

      headlineLarge: localizedTextTheme.headlineLarge?.copyWith(
        fontSize: (localizedTextTheme.headlineLarge?.fontSize ?? 32) / 20.0 * settings.fontSizeTitleLarge.value,
      ),
      headlineMedium: localizedTextTheme.headlineMedium?.copyWith(
        fontSize: (localizedTextTheme.headlineMedium?.fontSize ?? 28) / 20.0 * settings.fontSizeTitleLarge.value,
      ),
      headlineSmall: localizedTextTheme.headlineSmall?.copyWith(
        fontSize: (localizedTextTheme.headlineSmall?.fontSize ?? 24) / 20.0 * settings.fontSizeTitleLarge.value,
      ),

      titleLarge: localizedTextTheme.titleLarge?.copyWith(fontSize: settings.fontSizeTitleLarge.value),
      titleMedium: localizedTextTheme.titleMedium?.copyWith(fontSize: settings.fontSizeTitleMedium.value),
      titleSmall: localizedTextTheme.titleSmall?.copyWith(fontSize: settings.fontSizeBodyLarge.value),

      bodyLarge: localizedTextTheme.bodyLarge?.copyWith(fontSize: settings.fontSizeBodyLarge.value),
      bodyMedium: localizedTextTheme.bodyMedium?.copyWith(fontSize: settings.fontSizeBodyMedium.value),
      bodySmall: localizedTextTheme.bodySmall?.copyWith(fontSize: settings.fontSizeBodySmall.value),

      labelLarge: localizedTextTheme.labelLarge?.copyWith(fontSize: settings.fontSizeBodyMedium.value),
      labelMedium: localizedTextTheme.labelMedium?.copyWith(fontSize: settings.fontSizeBodySmall.value),
      labelSmall: localizedTextTheme.labelSmall?.copyWith(fontSize: settings.fontSizeBodySmall.value - 1.0),
    );

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorSchemeSeed: primaryColor,
      colorScheme: effectiveColorScheme,
      textTheme: customGlobalTextTheme,
      primaryTextTheme: customGlobalTextTheme,
    );

    return baseTheme.copyWith(
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarTheme(
        scrolledUnderElevation: 0.0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: customGlobalTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: customGlobalTextTheme.titleMedium,
        unselectedLabelStyle: customGlobalTextTheme.bodyMedium,
      ),
    );
  }

  ThemeData get lightThemeData => _buildTheme(Brightness.light);

  ThemeData get darkThemeData => _buildTheme(Brightness.dark);
}
