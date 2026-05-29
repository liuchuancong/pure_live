import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class DanmakuSettingsController extends GetxController {
  final hideDanmaku = HiveRx.bool('hideDanmaku', false);
  final danmakuTopArea = HiveRx.double('danmakuTopArea', 0.0);
  final danmakuArea = HiveRx.double('danmakuArea', 1.0);
  final danmakuBottomArea = HiveRx.double('danmakuBottomArea', 0.5);
  final danmakuSpeed = HiveRx.double('danmakuSpeed', 8.0);
  final danmakuFontSize = HiveRx.double('danmakuFontSize', 16.0);
  final danmakuFontBorder = HiveRx.double('danmakuFontBorder', 4.0);
  final danmakuOpacity = HiveRx.double('danmakuOpacity', 1.0);
  final enableDanmakuDisplay = HiveRx.bool('enableDanmakuDisplay', true);
  final danmakuFontFamilyName = HiveRx.string('danmakuFontFamilyName', 'Default');

  Rx<bool> get hideDanmakuRx => hideDanmaku.rx as Rx<bool>;
  Rx<double> get danmakuTopAreaRx => danmakuTopArea.rx as Rx<double>;
  Rx<double> get danmakuAreaRx => danmakuArea.rx as Rx<double>;
  Rx<double> get danmakuBottomAreaRx => danmakuBottomArea.rx as Rx<double>;
  Rx<double> get danmakuSpeedRx => danmakuSpeed.rx as Rx<double>;
  Rx<double> get danmakuFontSizeRx => danmakuFontSize.rx as Rx<double>;
  Rx<double> get danmakuFontBorderRx => danmakuFontBorder.rx as Rx<double>;
  Rx<double> get danmakuOpacityRx => danmakuOpacity.rx as Rx<double>;
  Rx<bool> get enableDanmakuDisplayRx => enableDanmakuDisplay.rx as Rx<bool>;
  Rx<String> get danmakuFontFamilyNameRx => danmakuFontFamilyName.rx as Rx<String>;

  Map<String, dynamic> toJson() {
    return {
      'hideDanmaku': hideDanmaku.v,
      'danmakuTopArea': danmakuTopArea.v,
      'danmakuArea': danmakuArea.v,
      'danmakuBottomArea': danmakuBottomArea.v,
      'danmakuSpeed': danmakuSpeed.v,
      'danmakuFontSize': danmakuFontSize.v,
      'danmakuFontBorder': danmakuFontBorder.v,
      'danmakuOpacity': danmakuOpacity.v,
      'enableDanmakuDisplay': enableDanmakuDisplay.v,
      'danmakuFontFamilyName': danmakuFontFamilyName.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    hideDanmaku.v = json['hideDanmaku'] ?? false;
    danmakuTopArea.v = json['danmakuTopArea']?.toDouble() ?? 0.0;
    danmakuArea.v = json['danmakuArea']?.toDouble() ?? 1.0;
    danmakuBottomArea.v = json['danmakuBottomArea']?.toDouble() ?? 0.5;
    danmakuSpeed.v = json['danmakuSpeed']?.toDouble() ?? 8.0;
    danmakuFontSize.v = json['danmakuFontSize']?.toDouble() ?? 16.0;
    danmakuFontBorder.v = json['danmakuFontBorder']?.toDouble() ?? 4.0;
    danmakuOpacity.v = json['danmakuOpacity']?.toDouble() ?? 1.0;
    enableDanmakuDisplay.v = json['enableDanmakuDisplay'] ?? true;
    danmakuFontFamilyName.v = json['danmakuFontFamilyName'] ?? 'Default';
  }
}
