import 'package:pure_live/common/index.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pure_live/common/global/platform_utils.dart';

class MyTheme {
  final Color? primaryColor;
  final ColorScheme? colorScheme;

  MyTheme({this.primaryColor, this.colorScheme}) : assert(colorScheme == null || primaryColor == null);

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  ThemeData get lightThemeData => _buildTheme(Brightness.light);
  ThemeData get darkThemeData => _buildTheme(Brightness.dark);

  String? _resolveFontFamily(String selectedName, List<String> customFonts) {
    if (customFonts.contains(selectedName)) {
      return selectedName;
    }
    if (PlatformUtils.isWindows) {
      return 'PingFang';
    }
    if (PlatformUtils.isAndroid) {
      return GoogleFonts.roboto().fontFamily;
    }
    return null;
  }

  TextTheme _buildTextTheme({required TextTheme base, required String? fontFamily}) {
    final localized = fontFamily != null ? base.apply(fontFamily: fontFamily) : base;

    TextStyle scale(TextStyle? style, double target) {
      return (style ?? const TextStyle()).copyWith(fontSize: target);
    }

    final font = SettingsService.to.font;

    return localized.copyWith(
      displayLarge: scale(localized.displayLarge, font.fontSizeBodySmall.v * 4.75),
      displayMedium: scale(localized.displayMedium, font.fontSizeBodySmall.v * 3.75),
      displaySmall: scale(localized.displaySmall, font.fontSizeBodySmall.v * 3.0),

      headlineLarge: scale(localized.headlineLarge, font.fontSizeTitleLarge.v * 1.6),
      headlineMedium: scale(localized.headlineMedium, font.fontSizeTitleLarge.v * 1.4),
      headlineSmall: scale(localized.headlineSmall, font.fontSizeTitleLarge.v * 1.2),

      titleLarge: scale(localized.titleLarge, font.fontSizeTitleLarge.v).copyWith(fontWeight: semiBold),
      titleMedium: scale(localized.titleMedium, font.fontSizeTitleMedium.v).copyWith(fontWeight: medium),
      titleSmall: scale(localized.titleSmall, font.fontSizeBodyLarge.v).copyWith(fontWeight: medium),

      bodyLarge: scale(localized.bodyLarge, font.fontSizeBodyLarge.v),
      bodyMedium: scale(localized.bodyMedium, font.fontSizeBodyMedium.v),
      bodySmall: scale(localized.bodySmall, font.fontSizeBodySmall.v),

      labelLarge: scale(localized.labelLarge, font.fontSizeBodyMedium.v).copyWith(fontWeight: medium),
      labelMedium: scale(localized.labelMedium, font.fontSizeBodySmall.v),
      labelSmall: scale(localized.labelSmall, font.fontSizeBodySmall.v - 1),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final customFonts = SettingsService.to.font.fontList.map((e) => e.id).toList();
    final fontFamily = _resolveFontFamily(SettingsService.to.font.fontFamilyName.v, customFonts);

    ColorScheme? scheme = colorScheme;
    if (isDark && scheme != null) {
      scheme = scheme.copyWith(error: const Color(0xFFFF6347));
    }

    final baseTextTheme = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final textTheme = _buildTextTheme(base: baseTextTheme, fontFamily: fontFamily);

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorSchemeSeed: primaryColor,
      colorScheme: scheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
    );

    return baseTheme.copyWith(
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0.0,
        scrolledUnderElevation: 0.0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: semiBold),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        tabAlignment: TabAlignment.center,
        labelStyle: textTheme.titleMedium?.copyWith(fontWeight: semiBold),
        unselectedLabelStyle: textTheme.titleMedium?.copyWith(fontWeight: regular),
        labelColor: baseTheme.colorScheme.primary,
        unselectedLabelColor: baseTheme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: semiBold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: medium),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: textTheme.bodyLarge?.copyWith(fontWeight: medium),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: baseTheme.colorScheme.onSurfaceVariant),
        leadingAndTrailingTextStyle: textTheme.labelMedium,
        selectedColor: baseTheme.colorScheme.primary,
        selectedTileColor: baseTheme.colorScheme.primary.withValues(alpha: 0.06),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: baseTheme.colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: textTheme.bodyMedium,
        hintStyle: textTheme.bodyMedium?.copyWith(color: baseTheme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: baseTheme.colorScheme.primary, width: 1.5),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        showDragHandle: true,
        backgroundColor: baseTheme.colorScheme.surfaceContainer,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: baseTheme.colorScheme.surfaceContainerHigh,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: semiBold),
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
