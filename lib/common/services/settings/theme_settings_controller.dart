import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';

class ThemeSettingsController extends GetxController {
  final RxString themeModeName = hiveString('themeMode', "System");
  final RxBool enableDynamicTheme = hiveBool('enableDynamicTheme', false);
  final RxString themeColorSwitch = hiveString('themeColorSwitch', Colors.blue.hex);
  final RxString languageName = hiveString('language', "简体中文");
  final RxDouble crossAxisSpacing = hiveDouble('crossAxisSpacing', 6.0);
  final RxDouble mainAxisSpacing = hiveDouble('mainAxisSpacing', 6.0);
  final RxString loadingStyle = hiveString('loadingStyle', AppConsts.defaultLoadingStyleKey);
  final RxString loadingStyleColorSwitch = hiveString('loadingStyleColorSwitch', '');

  ThemeMode get themeMode => AppConsts.themeModes[themeModeName.v]!;
  Locale get language => AppConsts.languages[languageName.v]!;

  final Map<ColorSwatch<Object>, String> colorsNameMap = AppConsts.themeColors.map(
    (k, v) => MapEntry(ColorTools.createPrimarySwatch(v), k),
  );

  @override
  void onInit() {
    super.onInit();
    everAll([crossAxisSpacing, mainAxisSpacing], (_) {
      Get.find<FontSettingsController>().refreshSystemTheme();
    });
  }

  void changeThemeMode(String mode) {
    themeModeName.v = mode;
    Get.changeThemeMode(themeMode);
  }

  void changeThemeColorSwitch(String hex) {
    final color = HexColor(hex);
    final t = MyTheme(primaryColor: color);
    Get.changeTheme(t.lightThemeData);
    Get.changeTheme(t.darkThemeData);
  }

  void changeLanguage(String v) {
    languageName.v = v;
    EasyLocalization.of(Get.context!)!.setLocale(language);
    Get.updateLocale(language);
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeModeName.v,
      'enableDynamicTheme': enableDynamicTheme.v,
      'themeColorSwitch': themeColorSwitch.v,
      'language': languageName.v,
      'crossAxisSpacing': crossAxisSpacing.v,
      'mainAxisSpacing': mainAxisSpacing.v,
      'loadingStyle': loadingStyle.v,
      'loadingStyleColorSwitch': loadingStyleColorSwitch.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    themeModeName.v = json['themeMode'] ?? "System";
    enableDynamicTheme.v = json['enableDynamicTheme'] ?? false;
    themeColorSwitch.v = json['themeColorSwitch'] ?? const Color.fromARGB(255, 218, 70, 12).hex;
    languageName.v = json['language'] ?? "简体中文";
    crossAxisSpacing.v = json['crossAxisSpacing'] ?? 6.0;
    mainAxisSpacing.v = json['mainAxisSpacing'] ?? 6.0;
    loadingStyle.v = json['loadingStyle'] ?? AppConsts.defaultLoadingStyleKey;
    loadingStyleColorSwitch.v = json['loadingStyleColorSwitch'] ?? '';
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final theme = rootConfig?['theme'] as Map<String, dynamic>? ?? {};
    return {
      'themeMode': theme['themeMode'] ?? "System",
      'enableDynamicTheme': theme['enableDynamicTheme'] ?? false,
      'themeColorSwitch': theme['themeColorSwitch'] ?? Colors.blue.hex,
      'language': theme['language'] ?? "简体中文",
      'crossAxisSpacing': (theme['crossAxisSpacing'] ?? 6.0).toDouble(),
      'mainAxisSpacing': (theme['mainAxisSpacing'] ?? 6.0).toDouble(),
      'loadingStyle': theme['loadingStyle'] ?? AppConsts.defaultLoadingStyleKey,
      'loadingStyleColorSwitch': theme['loadingStyleColorSwitch'] ?? '',
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final theme = Map<String, dynamic>.from(rootConfig['theme'] ?? {});
    updateFields.forEach((k, v) => theme[k] = v);
    rootConfig['theme'] = theme;
    return rootConfig;
  }
}
