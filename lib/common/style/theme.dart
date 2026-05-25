import 'package:pure_live/common/index.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pure_live/common/global/platform_utils.dart';

class MyTheme {
  final Color? primaryColor;
  final ColorScheme? colorScheme;

  MyTheme({this.primaryColor, this.colorScheme}) : assert(colorScheme == null || primaryColor == null);

  String? _getEffectiveFontFamily(String selectedName, List<String> availableCustomFonts) {
    if (availableCustomFonts.contains(selectedName)) {
      return selectedName;
    }

    if (selectedName == 'Roboto') return GoogleFonts.roboto().fontFamily;
    if (selectedName == 'NotoSans') return GoogleFonts.notoSansSc().fontFamily;
    if (selectedName == 'Monospace') return 'monospace';

    if (PlatformUtils.isWindows) return 'PingFang';
    if (PlatformUtils.isAndroid) return GoogleFonts.roboto().fontFamily;
    return null;
  }

  ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final settings = Get.find<SettingsService>();

    final List<String> customFontIds = settings.fontList.map((e) => e.id).toList();
    final String? fontFamily = _getEffectiveFontFamily(settings.fontFamilyName.value, customFontIds);

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
        tabAlignment: TabAlignment.center,
        labelStyle: customGlobalTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        unselectedLabelStyle: customGlobalTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.normal),
        labelColor: baseTheme.colorScheme.primary,
        unselectedLabelColor: baseTheme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          textStyle: customGlobalTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: customGlobalTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: customGlobalTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle: customGlobalTextTheme.bodyMedium?.copyWith(color: baseTheme.colorScheme.onSurfaceVariant),
        leadingAndTrailingTextStyle: customGlobalTextTheme.labelMedium,
        selectedColor: baseTheme.colorScheme.primary,
        selectedTileColor: baseTheme.colorScheme.primary.withValues(alpha: 0.05),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: baseTheme.colorScheme.surfaceContainerLow, // 智能跟随系统动态肤色
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: customGlobalTextTheme.bodyMedium,
        hintStyle: customGlobalTextTheme.bodyMedium?.copyWith(
          color: baseTheme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: baseTheme.colorScheme.primary, width: 1.5), // 聚焦时展现高亮边框
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: baseTheme.colorScheme.surfaceContainer,
        elevation: 0,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: baseTheme.colorScheme.surfaceContainerHigh,
        elevation: 0,
        titleTextStyle: customGlobalTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        contentTextStyle: customGlobalTextTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  ThemeData get lightThemeData => _buildTheme(Brightness.light);

  ThemeData get darkThemeData => _buildTheme(Brightness.dark);
}
