import 'package:pure_live/common/index.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pure_live/common/global/platform_utils.dart';

class MyTheme {
  final Color? primaryColor;
  final ColorScheme? colorScheme;

  MyTheme({this.primaryColor, this.colorScheme}) : assert(colorScheme == null || primaryColor == null);

  // =========================================================
  // Font Weights
  // =========================================================

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // =========================================================
  // Font Family
  // =========================================================

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

  // =========================================================
  // Text Theme
  // =========================================================

  TextTheme _buildTextTheme({required TextTheme base, required SettingsService settings, required String? fontFamily}) {
    final localized = fontFamily != null ? base.apply(fontFamily: fontFamily) : base;

    TextStyle scale(TextStyle? style, double target) {
      return (style ?? const TextStyle()).copyWith(fontSize: target);
    }

    return localized.copyWith(
      // Display
      displayLarge: scale(localized.displayLarge, settings.fontSizeBodySmall.value * 4.75),
      displayMedium: scale(localized.displayMedium, settings.fontSizeBodySmall.value * 3.75),
      displaySmall: scale(localized.displaySmall, settings.fontSizeBodySmall.value * 3.0),

      // Headline
      headlineLarge: scale(localized.headlineLarge, settings.fontSizeTitleLarge.value * 1.6),
      headlineMedium: scale(localized.headlineMedium, settings.fontSizeTitleLarge.value * 1.4),
      headlineSmall: scale(localized.headlineSmall, settings.fontSizeTitleLarge.value * 1.2),

      // Title
      titleLarge: scale(localized.titleLarge, settings.fontSizeTitleLarge.value).copyWith(fontWeight: semiBold),

      titleMedium: scale(localized.titleMedium, settings.fontSizeTitleMedium.value).copyWith(fontWeight: medium),

      titleSmall: scale(localized.titleSmall, settings.fontSizeBodyLarge.value).copyWith(fontWeight: medium),

      // Body
      bodyLarge: scale(localized.bodyLarge, settings.fontSizeBodyLarge.value),
      bodyMedium: scale(localized.bodyMedium, settings.fontSizeBodyMedium.value),
      bodySmall: scale(localized.bodySmall, settings.fontSizeBodySmall.value),

      // Label
      labelLarge: scale(localized.labelLarge, settings.fontSizeBodyMedium.value).copyWith(fontWeight: medium),

      labelMedium: scale(localized.labelMedium, settings.fontSizeBodySmall.value),

      labelSmall: scale(localized.labelSmall, settings.fontSizeBodySmall.value - 1),
    );
  }

  // =========================================================
  // Main Theme
  // =========================================================

  ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final settings = Get.find<SettingsService>();

    final customFonts = settings.fontList.map((e) => e.id).toList();

    final fontFamily = _resolveFontFamily(settings.fontFamilyName.value, customFonts);

    ColorScheme? scheme = colorScheme;

    if (isDark && scheme != null) {
      scheme = scheme.copyWith(error: const Color(0xFFFF6347));
    }

    final baseTextTheme = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;

    final textTheme = _buildTextTheme(base: baseTextTheme, settings: settings, fontFamily: fontFamily);

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

      // =====================================================
      // AppBar
      // =====================================================
      appBarTheme: AppBarTheme(
        elevation: 0.0,
        scrolledUnderElevation: 0.0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: semiBold),
      ),

      // =====================================================
      // TabBar
      // =====================================================
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        tabAlignment: TabAlignment.center,

        labelStyle: textTheme.titleMedium?.copyWith(fontWeight: semiBold),

        unselectedLabelStyle: textTheme.titleMedium?.copyWith(fontWeight: regular),

        labelColor: baseTheme.colorScheme.primary,

        unselectedLabelColor: baseTheme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),

      // =====================================================
      // Card
      // =====================================================
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // =====================================================
      // Elevated Button
      // =====================================================
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: semiBold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // =====================================================
      // Text Button
      // =====================================================
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: medium),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // =====================================================
      // ListTile
      // =====================================================
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

        titleTextStyle: textTheme.bodyLarge?.copyWith(fontWeight: medium),

        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: baseTheme.colorScheme.onSurfaceVariant),

        leadingAndTrailingTextStyle: textTheme.labelMedium,

        selectedColor: baseTheme.colorScheme.primary,

        selectedTileColor: baseTheme.colorScheme.primary.withValues(alpha: 0.06),
      ),

      // =====================================================
      // Input
      // =====================================================
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

      // =====================================================
      // BottomSheet
      // =====================================================
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        showDragHandle: true,
        backgroundColor: baseTheme.colorScheme.surfaceContainer,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),

      // =====================================================
      // Dialog
      // =====================================================
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: baseTheme.colorScheme.surfaceContainerHigh,

        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: semiBold),

        contentTextStyle: textTheme.bodyMedium,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  ThemeData get lightThemeData => _buildTheme(Brightness.light);

  ThemeData get darkThemeData => _buildTheme(Brightness.dark);
}
