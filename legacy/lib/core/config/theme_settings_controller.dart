import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/consts/app_consts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/core/config/font_settings_controller.dart';

class ThemeSettingsController extends GetxController {
  static const String defaultThemeModeName = 'System';
  static const String defaultLanguageName = '简体中文';
  static const double defaultSpacing = 6;
  static const double minSpacing = 0;
  static const double maxSpacing = 64;
  static final String defaultThemeColorHex = Colors.blue.hex;
  static final Set<String> _loadingStyleKeys = AppConsts.loadingStyleKeys.toSet();

  final List<Worker> _workers = [];
  final RxString themeModeName = hiveString('themeMode', defaultThemeModeName);
  final RxBool enableDynamicTheme = hiveBool('enableDynamicTheme', false);
  final RxString themeColorSwitch = hiveString('themeColorSwitch', defaultThemeColorHex);
  final RxString languageName = hiveString('language', defaultLanguageName);
  final RxDouble crossAxisSpacing = hiveDouble('crossAxisSpacing', defaultSpacing);
  final RxDouble mainAxisSpacing = hiveDouble('mainAxisSpacing', defaultSpacing);
  final RxString loadingStyle = hiveString('loadingStyle', AppConsts.defaultLoadingStyleKey);
  final RxString loadingStyleColorSwitch = hiveString('loadingStyleColorSwitch', '');

  String get resolvedThemeModeName => normalizeThemeMode(themeModeName.v);
  ThemeMode get themeMode => AppConsts.themeModes[resolvedThemeModeName]!;
  String get resolvedThemeColorHex => normalizeThemeColor(themeColorSwitch.v);
  Color get themeColor => HexColor(resolvedThemeColorHex);
  String get resolvedLanguageName => normalizeLanguage(languageName.v);
  Locale get language => AppConsts.languages[resolvedLanguageName]!;
  double get resolvedCrossAxisSpacing => normalizeSpacing(crossAxisSpacing.v);
  double get resolvedMainAxisSpacing => normalizeSpacing(mainAxisSpacing.v);
  String get resolvedLoadingStyle => normalizeLoadingStyle(loadingStyle.v);
  String get resolvedLoadingStyleColorHex => normalizeLoadingStyleColor(loadingStyleColorSwitch.v);
  Color? get loadingStyleColor {
    final hex = resolvedLoadingStyleColorHex;
    return hex.isEmpty ? null : HexColor(hex);
  }

  final Map<ColorSwatch<Object>, String> colorsNameMap = AppConsts.themeColors.map(
    (k, v) => MapEntry(ColorTools.createPrimarySwatch(v), k),
  );

  @override
  void onInit() {
    super.onInit();
    _normalizeStoredTheme();
    _workers.addAll([
      ever<String>(themeModeName, (value) => _repairString(themeModeName, value, normalizeThemeMode)),
      ever<String>(themeColorSwitch, (value) => _repairString(themeColorSwitch, value, normalizeThemeColor)),
      ever<String>(languageName, (value) => _repairString(languageName, value, normalizeLanguage)),
      ever<String>(loadingStyle, (value) => _repairString(loadingStyle, value, normalizeLoadingStyle)),
      ever<String>(
        loadingStyleColorSwitch,
        (value) => _repairString(loadingStyleColorSwitch, value, normalizeLoadingStyleColor),
      ),
      everAll([crossAxisSpacing, mainAxisSpacing], (_) => _repairSpacingAndRefreshTheme()),
    ]);
  }

  @override
  void onClose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    _workers.clear();
    super.onClose();
  }

  static String normalizeThemeMode(String value) {
    final normalized = value.trim().toLowerCase();
    return AppConsts.themeModes.keys.firstWhere(
      (candidate) => candidate.toLowerCase() == normalized,
      orElse: () => defaultThemeModeName,
    );
  }

  static String normalizeLanguage(String value) {
    final normalized = value.trim().toLowerCase();
    return AppConsts.languages.keys.firstWhere(
      (candidate) => candidate.toLowerCase() == normalized,
      orElse: () => defaultLanguageName,
    );
  }

  static String? _canonicalHex(String value) {
    var normalized = value.trim().toUpperCase();
    if (normalized.startsWith('#')) {
      normalized = normalized.substring(1);
    } else if (normalized.startsWith('0X')) {
      normalized = normalized.substring(2);
    }
    return RegExp(r'^(?:[0-9A-F]{6}|[0-9A-F]{8})$').hasMatch(normalized) ? normalized : null;
  }

  static String normalizeThemeColor(String value) => _canonicalHex(value) ?? defaultThemeColorHex;

  static String normalizeLoadingStyleColor(String value) {
    if (value.trim().isEmpty) return '';
    return _canonicalHex(value) ?? '';
  }

  static String normalizeLoadingStyle(String value) {
    final normalized = value.trim();
    return _loadingStyleKeys.contains(normalized) ? normalized : AppConsts.defaultLoadingStyleKey;
  }

  static double normalizeSpacing(num value) {
    final converted = value.toDouble();
    if (!converted.isFinite) return defaultSpacing;
    return converted.clamp(minSpacing, maxSpacing).toDouble();
  }

  static double _parseSpacing(Object? value) {
    final parsed = ((value ?? defaultSpacing) as num).toDouble();
    if (!parsed.isFinite) throw const FormatException('Theme spacing must be finite');
    return normalizeSpacing(parsed);
  }

  void _normalizeStoredTheme() {
    themeModeName.v = resolvedThemeModeName;
    themeColorSwitch.v = resolvedThemeColorHex;
    languageName.v = resolvedLanguageName;
    crossAxisSpacing.v = resolvedCrossAxisSpacing;
    mainAxisSpacing.v = resolvedMainAxisSpacing;
    loadingStyle.v = resolvedLoadingStyle;
    loadingStyleColorSwitch.v = resolvedLoadingStyleColorHex;
  }

  void _repairString(RxString setting, String value, String Function(String) normalize) {
    final normalized = normalize(value);
    if (normalized != value) setting.v = normalized;
  }

  void _repairSpacingAndRefreshTheme() {
    final cross = resolvedCrossAxisSpacing;
    final main = resolvedMainAxisSpacing;
    if (cross != crossAxisSpacing.v || main != mainAxisSpacing.v) {
      if (cross != crossAxisSpacing.v) crossAxisSpacing.v = cross;
      if (main != mainAxisSpacing.v) mainAxisSpacing.v = main;
      return;
    }
    Get.find<FontSettingsController>().refreshSystemTheme();
  }

  void changeThemeMode(String mode) {
    themeModeName.v = normalizeThemeMode(mode);
    Get.changeThemeMode(themeMode);
  }

  void changeThemeColorSwitch(String hex) {
    themeColorSwitch.v = normalizeThemeColor(hex);
    final color = themeColor;
    final t = MyTheme(primaryColor: color);
    Get.changeTheme(t.lightThemeData);
    Get.changeTheme(t.darkThemeData);
  }

  Future<void> changeLanguage(String v, BuildContext context) async {
    languageName.value = normalizeLanguage(v);
    final locale = language;
    await context.setLocale(locale);
    Get.updateLocale(locale);
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': resolvedThemeModeName,
      'enableDynamicTheme': enableDynamicTheme.v,
      'themeColorSwitch': resolvedThemeColorHex,
      'language': resolvedLanguageName,
      'crossAxisSpacing': resolvedCrossAxisSpacing,
      'mainAxisSpacing': resolvedMainAxisSpacing,
      'loadingStyle': resolvedLoadingStyle,
      'loadingStyleColorSwitch': resolvedLoadingStyleColorHex,
    };
  }

  /// Parse the complete section without notifying observers or persisting values.
  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    return {
      'themeModeName': normalizeThemeMode((json['themeMode'] ?? defaultThemeModeName) as String),
      'enableDynamicTheme': (json['enableDynamicTheme'] ?? false) as bool,
      'themeColorSwitch': normalizeThemeColor((json['themeColorSwitch'] ?? defaultThemeColorHex) as String),
      'languageName': normalizeLanguage((json['language'] ?? json['languageName'] ?? defaultLanguageName) as String),
      'crossAxisSpacing': _parseSpacing(json['crossAxisSpacing']),
      'mainAxisSpacing': _parseSpacing(json['mainAxisSpacing']),
      'loadingStyle': normalizeLoadingStyle((json['loadingStyle'] ?? AppConsts.defaultLoadingStyleKey) as String),
      'loadingStyleColorSwitch': normalizeLoadingStyleColor((json['loadingStyleColorSwitch'] ?? '') as String),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    themeModeName.v = parsed['themeModeName'];
    enableDynamicTheme.v = parsed['enableDynamicTheme'];
    themeColorSwitch.v = parsed['themeColorSwitch'];
    languageName.v = parsed['languageName'];
    crossAxisSpacing.v = parsed['crossAxisSpacing'];
    mainAxisSpacing.v = parsed['mainAxisSpacing'];
    loadingStyle.v = parsed['loadingStyle'];
    loadingStyleColorSwitch.v = parsed['loadingStyleColorSwitch'];
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final theme = rootConfig?['theme'] as Map<String, dynamic>? ?? {};
    final parsed = parseConfig(theme);
    return {
      'themeMode': parsed['themeModeName'],
      'enableDynamicTheme': parsed['enableDynamicTheme'],
      'themeColorSwitch': parsed['themeColorSwitch'],
      'language': parsed['languageName'],
      'crossAxisSpacing': parsed['crossAxisSpacing'],
      'mainAxisSpacing': parsed['mainAxisSpacing'],
      'loadingStyle': parsed['loadingStyle'],
      'loadingStyleColorSwitch': parsed['loadingStyleColorSwitch'],
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final theme = Map<String, dynamic>.from(rootConfig['theme'] ?? {});
    updateFields.forEach((k, v) => theme[k] = v);
    rootConfig['theme'] = theme;
    return rootConfig;
  }
}
