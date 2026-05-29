import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';

class ThemeSettingsController extends GetxController {
  final themeModeName = HiveRx.string('themeMode', "System");
  final enableDynamicTheme = HiveRx.bool('enableDynamicTheme', false);
  final themeColorSwitch = HiveRx.string('themeColorSwitch', Colors.blue.hex);
  final languageName = HiveRx.string('language', "简体中文");
  final crossAxisSpacing = HiveRx.double('crossAxisSpacing', 6.0);
  final mainAxisSpacing = HiveRx.double('mainAxisSpacing', 6.0);
  final loadingStyle = HiveRx.string('loadingStyle', AppConsts.defaultLoadingStyleKey);
  final loadingStyleColorSwitch = HiveRx.string('loadingStyleColorSwitch', '');
  ThemeMode get themeMode => AppConsts.themeModes[themeModeName.v]!;
  Locale get language => AppConsts.languages[languageName.v]!;

  final Map<ColorSwatch<Object>, String> colorsNameMap = AppConsts.themeColors.map(
    (k, v) => MapEntry(ColorTools.createPrimarySwatch(v), k),
  );

  @override
  void onInit() {
    super.onInit();
    everAll([crossAxisSpacing.rx, mainAxisSpacing.rx], (_) {
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
    themeColorSwitch.v = json['themeColorSwitch'] ?? Colors.blue.hex;
    languageName.v = json['language'] ?? "简体中文";
    crossAxisSpacing.v = json['crossAxisSpacing'] ?? 6.0;
    mainAxisSpacing.v = json['mainAxisSpacing'] ?? 6.0;
    loadingStyle.v = json['loadingStyle'] ?? AppConsts.defaultLoadingStyleKey;
    loadingStyleColorSwitch.v = json['loadingStyleColorSwitch'] ?? '';
  }
}
